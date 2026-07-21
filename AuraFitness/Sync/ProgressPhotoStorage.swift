import Foundation
import Supabase
import UIKit

/// Progress-photo BYTES in the private `progress-photos` Storage bucket;
/// `aura_progress_photos` rows keep metadata + a `storagePath` only.
///
/// Owns four things, all fire-and-forget in the same spirit as
/// `SupabaseSyncService` — nothing here ever throws into the UI and a photo is
/// never lost to a failed upload:
///
///  1. **Upload queue.** New photos (and legacy base64 rows pulled from a
///     pre-phase3-01 client) are queued, uploaded at most
///     `maxConcurrentUploads` at a time, and only THEN stripped of their
///     inline bytes. The queue is persisted, so an interrupted migration
///     resumes on the next launch.
///  2. **Push deferral.** While a photo is queued, `AppState` withholds its
///     metadata row push (see `isUploadPending`) — otherwise every new photo
///     would ship its full base64 payload to Postgres seconds before the
///     Storage upload made that payload obsolete.
///  3. **On-demand reads.** `loadImage(for:)` resolves memory cache -> inline
///     bytes -> on-disk cache -> Storage download. Sync never downloads
///     eagerly; the view asks for the photos it actually shows.
///  4. **Deletes.** Removing a photo locally removes its object and cache file.
///
/// The path convention (`{uid}/{photo_uuid}.jpg`) is load-bearing: the policies
/// in 0006_progress_photos_storage.sql key on the first segment being
/// `auth.uid()`. Paths are built from `AuthService.shared.userID` and the
/// photo's own UUID — never from anything the user typed.
@MainActor
final class ProgressPhotoStorage: ObservableObject {
    static let shared = ProgressPhotoStorage()

    /// Must match the bucket created by the owner (see the migration header).
    static let bucket = "progress-photos"

    /// Bucket-RELATIVE object path — what the SDK's upload/download/remove
    /// calls take, and what `ProgressPhoto.storagePath` stores. The absolute
    /// form (`progress-photos/{uid}/{uuid}.jpg`) only ever appears in the
    /// upload response's `Key`.
    static func objectPath(uid: String, photoID: UUID) -> String {
        "\(uid)/\(photoID.uuidString.lowercased()).jpg"
    }

    private let client: SupabaseClient
    private var userID: String? { AuthService.shared.userID }

    /// Queued for upload — bytes are still inline, the metadata push is held.
    private var pending: Set<UUID> = []
    /// Subset of `pending` with a live upload task.
    private var inFlight: Set<UUID> = []
    /// Photos this launch has given up on (bucket missing, too large even
    /// after recompression, RLS rejection). Deliberately NOT persisted: the
    /// commonest cause is a bucket the owner has not created yet, and a
    /// relaunch after they do should quietly migrate everything.
    private var permanentlyFailed: Set<UUID> = []
    /// De-dupes concurrent `loadImage` calls for the same photo (the grid and
    /// a compare slot routinely ask for the same one).
    private var downloads: [UUID: Task<UIImage?, Never>] = [:]

    private let memoryCache = NSCache<NSString, UIImage>()

    /// Survives relaunch so an interrupted migration resumes. Holds ids only —
    /// the bytes are already in `AppState.progressPhotos`.
    private static let pendingKey = "aura_photo_upload_pending_v1"
    private static let maxConcurrentUploads = 3

    /// Target for the re-compression retry after a 413. The view's initial
    /// encode already aims well under this; halving the long edge is the
    /// last resort before giving up and keeping the photo local.
    private static let retryMaxDimension: CGFloat = 800
    private static let retryQuality: CGFloat = 0.4

    private init() {
        client = AuthService.shared.client
        pending = Self.loadPending()
    }

    // MARK: - Push deferral

    /// True while this photo's bytes have not reached Storage yet, so its row
    /// must not be pushed — it would carry the full base64 blob that the
    /// pending upload exists to eliminate. Cleared on success (the row is then
    /// pushed metadata-only) and on permanent failure (the row is then pushed
    /// WITH its base64, the legacy fallback).
    func isUploadPending(_ id: UUID) -> Bool { pending.contains(id) }

    // MARK: - Local store hook

    /// Called from `AppState.progressPhotos.didSet`. Enqueues anything still
    /// carrying inline bytes (new photo, guest photo, legacy row just pulled)
    /// and cleans up after removals.
    ///
    /// `isApplyingRemote` gates ONLY the remote-object delete: a row removed by
    /// a tombstone was already deleted — object included — by whichever device
    /// performed the delete, and a local-only data reset must not reach out and
    /// destroy bytes the remote rows still reference. Enqueueing is not gated:
    /// a legacy row arriving from an old client is exactly the lazy migration
    /// this feature exists to perform.
    func photosDidChange(old: [ProgressPhoto], new: [ProgressPhoto], isApplyingRemote: Bool) {
        let newByID = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        for photo in new where photo.storagePath == nil && photo.imageData != nil {
            guard !permanentlyFailed.contains(photo.id) else { continue }
            pending.insert(photo.id)
        }

        for photo in old where newByID[photo.id] == nil {
            pending.remove(photo.id)
            memoryCache.removeObject(forKey: photo.id.uuidString as NSString)
            try? FileManager.default.removeItem(at: Self.cacheFile(photo.id))
            guard !isApplyingRemote, let path = photo.storagePath else { continue }
            removeObject(at: path)
        }

        savePending()
        drainQueue()
    }

    /// Re-scans for un-migrated photos and restarts the queue. Called after
    /// sign-in, which is both "first launch of the migration" and "the guest's
    /// local-only photos finally have somewhere to go".
    func resumePendingUploads() {
        guard let appState = AppStateBridge.shared else { return }
        for photo in appState.progressPhotos where photo.storagePath == nil && photo.imageData != nil {
            pending.insert(photo.id)
        }
        savePending()
        drainQueue()
    }

    /// Full data reset ONLY: forget every queued upload and drop the on-disk
    /// cache. Sign-out deliberately does not call this — it leaves the photo
    /// rows in `AppState` untouched, and a migrated row whose cache file was
    /// deleted would render as a blank tile with no way to refill it. Only the
    /// reset that removes the rows themselves may remove their bytes.
    func resetLocalState() {
        pending.removeAll()
        permanentlyFailed.removeAll()
        downloads.values.forEach { $0.cancel() }
        downloads.removeAll()
        memoryCache.removeAllObjects()
        UserDefaults.standard.removeObject(forKey: Self.pendingKey)
        try? FileManager.default.removeItem(at: Self.cacheDirectory)
    }

    // MARK: - Read path

    /// Resolves a photo's image, cheapest source first: memory cache, inline
    /// bytes, on-disk cache, then a Storage download. Returns nil when the
    /// bytes are only in the bucket and the download fails (offline) — the
    /// caller shows a placeholder and the next appearance retries.
    func loadImage(for photo: ProgressPhoto?) async -> UIImage? {
        guard let photo else { return nil }
        let key = photo.id.uuidString as NSString

        if let cached = memoryCache.object(forKey: key) { return cached }
        if let data = photo.imageData, let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            return image
        }
        if let data = try? Data(contentsOf: Self.cacheFile(photo.id)), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            return image
        }
        guard let path = photo.storagePath else { return nil }
        if let existing = downloads[photo.id] { return await existing.value }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            do {
                let data = try await self.client.storage.from(Self.bucket).download(path: path)
                guard let image = UIImage(data: data) else { return nil }
                self.writeCache(id: photo.id, data: data)
                self.memoryCache.setObject(image, forKey: key)
                return image
            } catch {
                return nil
            }
        }
        downloads[photo.id] = task
        let image = await task.value
        downloads[photo.id] = nil
        return image
    }

    /// Refills `imageData` from the on-disk cache for migrated photos so a
    /// local export still contains its images. Strictly offline: a photo whose
    /// bytes are only in the bucket exports as metadata.
    func hydratedForExport(_ photos: [ProgressPhoto]) -> [ProgressPhoto] {
        photos.map { photo in
            guard photo.imageData == nil, photo.storagePath != nil else { return photo }
            var hydrated = photo
            hydrated.imageData = try? Data(contentsOf: Self.cacheFile(photo.id))
            return hydrated
        }
    }

    // MARK: - Upload queue

    private func drainQueue() {
        guard userID != nil, let appState = AppStateBridge.shared else { return }
        // Sorted so the iteration order is stable rather than Set-hash order —
        // an interrupted migration then resumes predictably.
        for id in pending.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard inFlight.count < Self.maxConcurrentUploads else { break }
            guard !inFlight.contains(id) else { continue }
            // The photo (or its bytes) disappeared under us — nothing to send.
            guard let photo = appState.progressPhotos.first(where: { $0.id == id }),
                  let data = photo.imageData else {
                pending.remove(id)
                continue
            }
            inFlight.insert(id)
            Task { await upload(id: id, data: data) }
        }
        savePending()
    }

    /// One photo, one object. On success the bytes are durable server-side, so
    /// the row can safely drop its base64 — that mutation is what pushes the
    /// metadata-only row (`AppState.attachProgressPhotoStoragePath`).
    private func upload(id: UUID, data: Data) async {
        defer {
            inFlight.remove(id)
            drainQueue()
        }
        // Signed out mid-flight: leave it queued for the next sign-in.
        guard let uid = userID else { return }
        let path = Self.objectPath(uid: uid, photoID: id)
        var payload = data

        do {
            try await putObject(path: path, data: payload)
        } catch {
            if Self.isPayloadTooLarge(error) {
                // Recompress harder exactly once, per the spec — then stop, so
                // an image that simply cannot fit doesn't retry forever.
                guard let smaller = Self.recompressed(payload), smaller.count < payload.count else {
                    markPermanentFailure(id, error: error)
                    return
                }
                payload = smaller
                do {
                    try await putObject(path: path, data: payload)
                } catch {
                    markPermanentFailure(id, error: error)
                    return
                }
            } else if Self.isPermanentUploadFailure(error) {
                markPermanentFailure(id, error: error)
                return
            } else {
                // Offline / 5xx / timeout — stays queued, retried on the next
                // drain (another photo finishing, or the next sign-in).
                return
            }
        }

        writeCache(id: id, data: payload)
        pending.remove(id)
        savePending()
        AppStateBridge.shared?.attachProgressPhotoStoragePath(path, photoID: id)
    }

    private func putObject(path: String, data: Data) async throws {
        // `upsert: true` because two devices can migrate the SAME legacy photo
        // concurrently — they compute the identical path, and the second write
        // must overwrite rather than 409.
        _ = try await client.storage.from(Self.bucket).upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
    }

    /// Wholesale object delete for a full reset that also wipes the remote
    /// tables (`DataResetService.resetAll(alsoRemote: true)`). Kept separate
    /// from `photosDidChange`'s per-row cleanup because that path deliberately
    /// leaves Storage alone when the local removal came from a tombstone or a
    /// local-only reset. Best-effort; orphans fall to phase3-02's sweep.
    func wipeRemoteObjects(paths: [String]) {
        guard !paths.isEmpty else { return }
        Task {
            _ = try? await client.storage.from(Self.bucket).remove(paths: paths)
        }
    }

    /// Best-effort object delete. A failure leaves an orphan, which phase3-02's
    /// storage sweep is the backstop for — the row is already gone, so there is
    /// nothing to retry against locally.
    private func removeObject(at path: String) {
        Task {
            _ = try? await client.storage.from(Self.bucket).remove(paths: [path])
        }
    }

    /// Gives up on this photo for the rest of the launch and releases the
    /// withheld push, so the row still reaches Supabase — carrying its base64,
    /// exactly as it did before phase3-01. Nothing is lost; the photo simply
    /// stays on the legacy path until the cause (usually a bucket the owner
    /// has not created yet) is fixed and a relaunch re-queues it.
    private func markPermanentFailure(_ id: UUID, error: Error) {
        pending.remove(id)
        permanentlyFailed.insert(id)
        savePending()
        print("⚠️ ProgressPhotoStorage: upload of photo \(id) permanently rejected — keeping the inline base64 fallback. \(error)")
        AppStateBridge.shared?.pushProgressPhotoRow(id: id)
    }

    // MARK: - Failure classification
    //
    // Mirrors `SupabaseSyncService.isPermanentWriteFailure`: an allow-list of
    // known-hopeless conditions, everything else stays queued. Storage errors
    // surface as `StorageError` without a stable typed status, so match text —
    // the same compromise made for the PostgREST errors.

    private static func isPayloadTooLarge(_ error: Error) -> Bool {
        let text = "\(error)".lowercased()
        return text.contains("413") || text.contains("payload too large")
            || text.contains("maximum allowed size") || text.contains("entity too large")
    }

    private static func isPermanentUploadFailure(_ error: Error) -> Bool {
        let text = "\(error)".lowercased()
        // An expired JWT looks like a 401/403 but a refresh fixes it — always
        // transient, never dropped.
        guard !text.contains("jwt"), !text.contains("expired"), !text.contains("401") else { return false }
        // Bucket not created yet: the row keeps its base64 until it exists.
        if text.contains("bucket not found") || text.contains("404") { return true }
        // Path uid != auth uid. That is a client bug, not a network condition —
        // retrying re-sends the identical, identically-rejected request.
        return text.contains("row-level security") || text.contains("403")
    }

    /// Last-resort shrink for a 413: halve the long edge and drop quality.
    private static func recompressed(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let ratio = min(1, retryMaxDimension / longest)
        let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return scaled.jpegData(compressionQuality: retryQuality)
    }

    // MARK: - On-disk cache (Caches/ProgressPhotos/{uuid}.jpg)
    //
    // Caches is evictable by design, and that is fine HERE and only here: a
    // file is written only after its bytes are safely in the bucket, so losing
    // one costs a re-download. Bytes not yet uploaded live in `imageData`,
    // which persists with the rest of AppState.

    private static let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ProgressPhotos", isDirectory: true)
    }()

    private static func cacheFile(_ id: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(id.uuidString.lowercased()).jpg")
    }

    private func writeCache(id: UUID, data: Data) {
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheFile(id), options: .atomic)
    }

    // MARK: - Queue persistence

    private static func loadPending() -> Set<UUID> {
        let raw = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    private func savePending() {
        UserDefaults.standard.set(pending.map(\.uuidString), forKey: Self.pendingKey)
    }
}
