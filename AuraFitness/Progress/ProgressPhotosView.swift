import SwiftUI
import PhotosUI

struct ProgressPhotosView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var compareMode = "Side by Side"
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var compareBeforeItem: PhotosPickerItem? = nil
    @State private var compareAfterItem: PhotosPickerItem? = nil

    // Ad-hoc images picked straight into a compare slot — never persisted.
    @State private var beforeImage: UIImage? = nil
    @State private var afterImage: UIImage? = nil
    /// The oldest/newest library photos, resolved through
    /// `ProgressPhotoStorage` (cache, inline bytes, or a Storage download).
    /// Held in state because a stored photo's bytes are no longer guaranteed
    /// to be in memory — since phase3-01 they may need fetching.
    @State private var libraryBefore: UIImage? = nil
    @State private var libraryAfter: UIImage? = nil
    @State private var showAddSheet = false
    @State private var newPhotoImage: UIImage? = nil
    @State private var newPhotoWeight = ""
    @State private var newPhotoNote = ""

    private var photos: [ProgressPhoto] { appState.progressPhotos.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Compare mode picker
                    AuraSegmentedPicker(
                        options: ["Side by Side", "Top / Bottom"],
                        selection: $compareMode
                    )
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.top, AuraSpacing.s2)

                    // Before / After compare slots
                    compareSlots

                    // Delta card
                    if let first = photos.last, let latest = photos.first,
                       first.id != latest.id {
                        deltaCard(first: first, latest: latest)
                            .padding(.horizontal, AuraSpacing.screenPad)
                    }

                    // Library grid
                    AuraSectionLabel(title: "Library")
                        .padding(.horizontal, AuraSpacing.screenPad)

                    if photos.isEmpty {
                        VStack(spacing: AuraSpacing.s3) {
                            Image(systemName: "photo.stack")
                                .font(AuraFont.jakarta(40))
                                .foregroundColor(.aura.text3)
                            Text("No photos yet")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuraSpacing.s5)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 2
                        ) {
                            ForEach(photos) { photo in
                                PhotoTile(photo: photo)
                            }
                        }
                        .padding(.horizontal, AuraSpacing.screenPad)
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.aura.accent)
                    }
                }
            }
            .onChange(of: photosPickerItem) { _, item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    newPhotoImage = img
                    showAddSheet = true
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addPhotoSheet
            }
            .onChange(of: compareBeforeItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    beforeImage = UIImage(data: data)
                }
            }
            .onChange(of: compareAfterItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    afterImage = UIImage(data: data)
                }
            }
            // Keyed on the photo id so adding/removing a photo re-resolves the
            // slot. This is the ON-DEMAND download the sync layer deliberately
            // does not do: a pulled row carries a path, and only the screen
            // that shows it pays for the bytes.
            .task(id: photos.last?.id) {
                libraryBefore = await ProgressPhotoStorage.shared.loadImage(for: photos.last)
            }
            .task(id: photos.first?.id) {
                libraryAfter = await ProgressPhotoStorage.shared.loadImage(for: photos.first)
            }
        }
    }

    // MARK: Compare slots
    @ViewBuilder
    private var compareSlots: some View {
        let isVertical = compareMode == "Top / Bottom"
        Group {
            if isVertical {
                VStack(spacing: AuraSpacing.s3) {
                    compareSlot(image: firstPhoto, caption: firstCaption, label: "Before", pickerItem: $compareBeforeItem)
                    compareSlot(image: lastPhoto, caption: lastCaption, label: "After", pickerItem: $compareAfterItem)
                }
            } else {
                HStack(spacing: AuraSpacing.s3) {
                    compareSlot(image: firstPhoto, caption: firstCaption, label: "Before", pickerItem: $compareBeforeItem)
                    compareSlot(image: lastPhoto, caption: lastCaption, label: "After", pickerItem: $compareAfterItem)
                }
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
    }

    private var firstPhoto: UIImage? { beforeImage ?? libraryBefore }
    private var lastPhoto: UIImage? { afterImage ?? libraryAfter }

    /// Captions only exist for library photos — an ad-hoc image picked
    /// straight into a compare slot carries no date or weight.
    private var firstCaption: String? {
        beforeImage == nil ? photos.last.map(caption) : nil
    }
    private var lastCaption: String? {
        afterImage == nil ? photos.first.map(caption) : nil
    }

    private func caption(_ photo: ProgressPhoto) -> String {
        let date = photo.date.formatted(date: .abbreviated, time: .omitted)
        guard let w = photo.weight else { return date }
        return "\(date) · \(UnitFormatter.weight(w, unit: appState.weightUnit))"
    }

    @ViewBuilder
    private func compareSlot(image: UIImage?, caption: String?, label: String, pickerItem: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: pickerItem, matching: .images) {
            ZStack(alignment: .bottom) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                } else {
                    RoundedRectangle(cornerRadius: AuraRadius.lg)
                        .fill(Color.aura.surface)
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: AuraRadius.lg)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(.aura.separator)
                        )
                    VStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "plus.circle")
                            .font(AuraFont.jakarta(28))
                            .foregroundColor(.aura.text3)
                        Text(label)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                        Text("Add comparison photo")
                            .font(AuraFont.jakarta(10, .semibold))
                            .foregroundColor(.aura.text3)
                            .multilineTextAlignment(.center)
                    }
                }

                // Label pill at bottom, with date · weight when the slot is
                // showing a library photo.
                if image != nil {
                    VStack(spacing: 1) {
                        Text(label)
                            .font(AuraFont.jakarta(11, .bold))
                            .foregroundColor(.white)
                        if let caption {
                            Text(caption)
                                .font(AuraFont.jakarta(9, .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Delta card
    private func deltaCard(first: ProgressPhoto, latest: ProgressPhoto) -> some View {
        AuraCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(weeksDiff(first.date, latest.date))
                        .font(AuraFont.jakarta(15, .bold))
                        .foregroundColor(.aura.text)
                    if let fw = first.weight, let lw = latest.weight {
                        let delta = lw - fw
                        let d = UnitFormatter.weightValue(delta, unit: appState.weightUnit)
                        Text("\(d >= 0 ? "+" : "")\(String(format: "%.1f", d)) \(appState.weightUnit) · body change")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                Button {
                    shareCompare()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AuraFont.jakarta(13))
                        Text("Share")
                            .font(AuraFont.secondary())
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.aura.accentSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: Add photo sheet
    private var addPhotoSheet: some View {
        NavigationStack {
            Form {
                if let img = newPhotoImage {
                    Section {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }
                }
                Section("Details") {
                    HStack {
                        Text("Weight (\(appState.weightUnit))")
                        Spacer()
                        TextField("Optional", text: $newPhotoWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.aura.accent)
                    }
                    TextField("Note (optional)", text: $newPhotoNote)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPhotoImage = nil
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePhoto()
                        showAddSheet = false
                    }
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }

    // MARK: Helpers
    /// Budget for the encoded JPEG. The bytes now go to the `progress-photos`
    /// Storage bucket (phase3-01), where 1 MB is the target the spec sets — it
    /// keeps uploads cheap on cellular and stays far under the bucket's own
    /// size limit. It ALSO has to keep working for the legacy fallback: if the
    /// upload is permanently rejected (bucket missing), the photo is pushed
    /// base64 inside the `aura_progress_photos` payload instead, which
    /// 0005_payload_guardrails.sql caps at 3 MB — and base64 inflates by 4/3,
    /// so 1 MB of JPEG lands around 1.33 MB with room to spare.
    private static let jpegByteBudget = 1_000_000
    /// Long edge, in pixels. Well beyond what the compare/thumbnail UI shows.
    private static let maxPhotoDimension: CGFloat = 1600

    /// Downscales, then steps quality down until the JPEG fits the budget.
    /// The last attempt is returned even if it still doesn't fit — a photo
    /// saved locally but rejected by the server beats silently saving nothing.
    /// Both rejection paths keep the local row: `ProgressPhotoStorage` retries
    /// an oversized upload once at lower quality before giving up, and the sync
    /// layer drops a permanently-rejected queued push rather than the photo.
    private func encodedPhotoData(_ img: UIImage) -> Data? {
        let scaled = Self.downscaled(img, maxDimension: Self.maxPhotoDimension)
        var last: Data? = nil
        for quality: CGFloat in [0.75, 0.6, 0.45, 0.3] {
            guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
            last = data
            if data.count <= Self.jpegByteBudget { return data }
        }
        return last
    }

    /// Aspect-preserving resize of the long edge. `format.scale = 1` is
    /// load-bearing: the renderer defaults to the screen scale, which would
    /// hand back an image 2–3x larger in pixels than asked for.
    private static func downscaled(_ img: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(img.size.width, img.size.height)
        guard longest > maxDimension, longest > 0 else { return img }
        let ratio = maxDimension / longest
        let target = CGSize(width: img.size.width * ratio, height: img.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private func savePhoto() {
        guard let img = newPhotoImage,
              let data = encodedPhotoData(img) else { return }
        let photo = ProgressPhoto(
            date: Date(),
            imageData: data,
            weight: UnitFormatter.parseWeightToKg(newPhotoWeight, unit: appState.weightUnit),
            note: newPhotoNote
        )
        appState.progressPhotos.append(photo)
        newPhotoImage = nil
        newPhotoWeight = ""
        newPhotoNote = ""
    }

    private func weeksDiff(_ a: Date, _ b: Date) -> String {
        let days = abs(Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0)
        let weeks = days / 7
        return weeks > 0 ? "\(weeks) weeks apart" : "\(days) days apart"
    }

    private func shareCompare() {
        // UIActivityViewController requires UIKit – launch from SwiftUI via UIApplication
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let root = window.rootViewController else { return }
        let items: [Any] = [firstPhoto, lastPhoto].compactMap { $0 }
        guard !items.isEmpty else { return }
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(av, animated: true)
    }
}

/// One library-grid cell. Its own view (rather than an inline `if let`) so each
/// tile owns the async resolve of its image — inside a `LazyVGrid` that makes
/// the Storage download happen per-tile, as it scrolls into view, instead of
/// all at once. A tile whose bytes are neither cached nor reachable shows the
/// placeholder and retries the next time it appears.
private struct PhotoTile: View {
    let photo: ProgressPhoto

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.aura.surface)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(AuraFont.jakarta(18))
                            .foregroundColor(.aura.text3)
                    )
            }
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(AuraFont.jakarta(9, .bold))
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.45))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: photo.id) {
            image = await ProgressPhotoStorage.shared.loadImage(for: photo)
        }
    }
}
