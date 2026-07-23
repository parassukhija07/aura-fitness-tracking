import SwiftUI
import ImageIO
import UIKit

// MARK: - In-memory image cache
//
// A process-lifetime `NSCache` of decoded `UIImage`s keyed by absolute URL.
// `AsyncImage` alone re-fetches on every appearance; this layer keeps grid
// scrolling and re-entering a detail screen instant after the first load.
final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // ~50 MB of decoded pixels; NSCache evicts under memory pressure too.
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        // Cost = decoded pixel bytes (w × h × scale² × 4 bytes/pixel).
        let px = image.size.width * image.scale * image.size.height * image.scale
        cache.setObject(image, forKey: key as NSString, cost: Int(px) * 4)
    }
}

// MARK: - RemoteExerciseImage
//
// Cached remote thumbnail/hero for exercises. Behaviour:
//   • empty / nil / non-http(s) URL → muscle-tinted gradient immediately, no
//     network hit and no dead spinner;
//   • cache hit → the decoded image with no async work;
//   • miss → `URLSession` load with the gradient shown meanwhile, downsampled
//     to display size (ImageIO) and cached on success, gradient on failure.
// The gradient is always the loading + failure fallback, so offline degrades
// silently with no error UI.
struct RemoteExerciseImage: View {
    let urlString: String?
    /// Drives the fallback gradient tint (exercise category / primary muscle).
    let fallbackMuscle: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    /// Latches after a failed/invalid load so we don't retry every re-render
    /// (spec: no auto-retry beyond once per appearance).
    @State private var didFail = false

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    gradientPlaceholder
                        // Re-runs when the row is recycled onto a new URL.
                        .task(id: urlString) { await load(targetSize: geo.size) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    // Muscle-tinted gradient mirroring the exercise-detail hero palette.
    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: [tint.opacity(0.32), tint.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tint: Color {
        switch fallbackMuscle.lowercased() {
        case let m where m.contains("chest") || m.contains("pec"):                    return .aura.accent
        case let m where m.contains("back") || m.contains("lat"):                     return .aura.blue
        case let m where m.contains("shoulder") || m.contains("delt"):                return .aura.purple
        case let m where m.contains("arm") || m.contains("bicep") || m.contains("tricep"): return .aura.green
        case let m where m.contains("leg") || m.contains("quad") || m.contains("glut") || m.contains("ham") || m.contains("calf"): return .aura.red
        case let m where m.contains("core") || m.contains("abs") || m.contains("oblique"): return .aura.accent
        default:                                                                      return .aura.text2
        }
    }

    // MARK: Loading

    private func load(targetSize: CGSize) async {
        guard image == nil, !didFail else { return }
        // Empty/invalid/non-http(s) behaves exactly like "no image": gradient
        // stays, no network.
        guard let url = Self.validURL(urlString) else { return }
        let key = url.absoluteString

        if let cached = ImageMemoryCache.shared.image(for: key) {
            image = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // Cell may have been recycled onto a different URL mid-flight.
            guard Self.validURL(urlString)?.absoluteString == key else { return }
            let httpOK = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? true
            guard httpOK, let decoded = Self.downsample(data, to: targetSize) ?? UIImage(data: data) else {
                didFail = true
                return
            }
            ImageMemoryCache.shared.insert(decoded, for: key)
            // Apply only if this view still wants this URL.
            if Self.validURL(urlString)?.absoluteString == key {
                image = decoded
            }
        } catch {
            // Offline / cancelled / transport error → keep the gradient.
            didFail = true
        }
    }

    // MARK: Helpers

    /// http(s)-only, whitespace-trimmed URL; anything else is treated as absent.
    static func validURL(_ string: String?) -> URL? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    /// Decode + downsample to ~display size so multi-thousand-pixel source
    /// photos don't sit in memory at full resolution while scrolling a grid.
    static func downsample(_ data: Data, to size: CGSize) -> UIImage? {
        let maxDimension = max(size.width, size.height) * UIScreen.main.scale
        guard maxDimension > 0,
              let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return UIImage(data: data) }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }
}
