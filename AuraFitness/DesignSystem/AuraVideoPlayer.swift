import SwiftUI
import WebKit

/// Minimal YouTube embed backed by `WKWebView`.
///
/// The app stores tutorial links as plain YouTube URLs, so this extracts the
/// video id and loads the privacy-preserving `youtube-nocookie` player rather
/// than pulling in a third-party SDK.
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    /// Start playing (muted, looping) as soon as the view appears.
    var autoplay: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        /// Guards against `updateUIView` reloading the page — and restarting
        /// playback — on every unrelated SwiftUI re-render.
        var loadedKey: String?
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Autoplay only succeeds if playback is exempt from the gesture
        // requirement; when autoplay is off keep the standard tap-to-play.
        config.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : .all
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let key = "\(videoID)-\(autoplay)"
        guard context.coordinator.loadedKey != key else { return }
        context.coordinator.loadedKey = key

        // `loop` only takes effect alongside a single-video `playlist`.
        // Autoplay must be muted — iOS blocks unmuted unattended playback.
        var params = ["playsinline=1", "rel=0", "modestbranding=1"]
        if autoplay {
            params += ["autoplay=1", "mute=1", "loop=1", "playlist=\(videoID)"]
        }
        let src = "https://www.youtube-nocookie.com/embed/\(videoID)?\(params.joined(separator: "&"))"
        let html = """
        <!doctype html><html><head><meta name="viewport" \
        content="width=device-width, initial-scale=1, maximum-scale=1"> \
        <style>html,body{margin:0;padding:0;background:transparent;height:100%}\
        iframe{border:0;width:100%;height:100%}</style></head> \
        <body><iframe src="\(src)" allow="autoplay; encrypted-media; picture-in-picture" \
        allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }

    /// Pulls the id out of `watch?v=`, `youtu.be/` and `embed/` forms. Returns
    /// nil for anything unrecognised so callers can fall back to a non-video
    /// placeholder instead of loading a broken player.
    ///
    /// Takes an OPTIONAL string because that is what the callers actually
    /// hold: `Exercise.youtubeURL` is `String?` (only the bundled
    /// `ExerciseEntry` guarantees one). "No URL" and "unparseable URL" mean
    /// the same thing to every caller — no video — so nil is absorbed here
    /// instead of being unwrapped identically at each call site.
    static func videoID(from urlString: String?) -> String? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let v = items.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") {
            let id = url.lastPathComponent
            return id.isEmpty || id == "/" ? nil : id
        }
        if url.pathComponents.contains("embed") {
            let id = url.lastPathComponent
            return id.isEmpty || id == "embed" ? nil : id
        }
        return nil
    }
}

/// Exercise demo surface: honours the "Auto-play video" preference by either
/// starting the clip immediately or showing the thumbnail behind a Play
/// overlay that loads the player on tap.
struct ExerciseVideoView: View {
    /// Optional for the same reason `videoID(from:)` is — `Exercise.youtubeURL`
    /// is `String?`, and a nil URL renders exactly like an unparseable one.
    let youtubeURL: String?
    let autoplay: Bool
    var height: CGFloat = 180

    @State private var started = false

    var body: some View {
        if let id = YouTubePlayerView.videoID(from: youtubeURL) {
            Group {
                if autoplay || started {
                    YouTubePlayerView(videoID: id, autoplay: autoplay)
                } else {
                    thumbnail(id: id)
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    private func thumbnail(id: String) -> some View {
        Button { started = true } label: {
            ZStack {
                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.aura.fill
                    }
                }
                Color.black.opacity(0.22)
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 56, height: 56)
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(AuraFont.jakarta(22))
                    }
                    Text("Watch Demo")
                        .font(AuraFont.secondary())
                        .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
