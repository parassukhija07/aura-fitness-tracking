# IMPLEMENTATION SPEC: YouTube Tap-to-Play + Remote Exercise Images

## ⚠️ OPEN QUESTIONS
None. Playback approach is pre-decided: open the YouTube URL via the environment `openURL` action (no embedded player SDK, no new dependencies).

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). Exercise models carry media fields — `ExerciseEntry.youtubeURL`/`imageURL` (`AuraFitness/Models/ExerciseDatabase.swift`) and `Exercise.youtubeURL`/`imageURL` (`AuraFitness/Models/WorkoutModels.swift`) — but NOTHING plays or displays them: there are zero `openURL` calls in the app and no remote-image loading (audit finding M12). Every exercise "hero" block currently renders a muscle-tinted gradient placeholder with a play glyph. This spec wires play buttons to the URLs and adds cached remote thumbnails, with the gradient placeholder retained as the universal fallback.
- **Existing Patterns to Match:**
  - Hero/thumbnail render sites: `AuraFitness/Plan/ExerciseDetailView.swift` (library detail hero — struct `ExerciseEntryDetailView`, plus legacy `ExerciseDetailView` used by the Active Workout), `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift` (logger thumb w/ play button), `AuraFitness/Plan/PlanSubtabViews.swift` (`PlanExercisesBody` 2-up grid cells).
  - `@Environment(\.openURL)` is the SwiftUI-idiomatic launcher; use it uniformly.
  - Play-button styling: circular `.aura.accent` fill with a white triangle glyph centered on the thumbnail (already exists on placeholder heroes — keep it).
- **Core Strategy:** (1) One `RemoteExerciseImage` component wrapping async image loading with an in-memory `NSCache` layer and the gradient placeholder as loading/failure fallback; (2) play buttons call `openURL` when a valid YouTube URL exists, and the play affordance hides when none does.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/ExerciseDetailView.swift`
- `ExerciseEntryDetailView` hero: render `RemoteExerciseImage(urlString: entry.imageURL, ...)` behind the existing overlay; the play button calls `openURL` with `entry.youtubeURL` when non-empty AND parseable as a URL; otherwise the play button is not rendered.
- Legacy `ExerciseDetailView` (Active Workout variant, same file): same treatment using the `Exercise`'s `youtubeURL`/`imageURL`.
### `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift`
- The exercise thumbnail's play affordance opens `exercise.youtubeURL` via `openURL`. Additionally honour the Profile "Auto-play video" setting: when the auto-play setting in `AppState` is ON and the logger appears for an exercise with a valid URL, open it once automatically on that exercise's first appearance in the session (guard with a per-exercise-id session flag so it cannot loop).
### `AuraFitness/Plan/PlanSubtabViews.swift`
- `PlanExercisesBody` grid cells: replace the pure gradient thumb with `RemoteExerciseImage` (gradient remains the placeholder/fallback). NO play button in grid cells (tap already opens detail).

## 📄 FILES TO CREATE
### `AuraFitness/DesignSystem/RemoteExerciseImage.swift`
- **Purpose:** Cached remote image with graceful fallback, reused by all exercise thumbnails/heroes.
- **Signatures/Interfaces:**
  - `final class ImageMemoryCache { static let shared = ImageMemoryCache(); private let cache = NSCache<NSString, UIImage>(); func image(for key: String) -> UIImage?; func insert(_ image: UIImage, for key: String) }` — `cache.totalCostLimit` ≈ 50 MB, cost = pixel bytes.
  - `struct RemoteExerciseImage: View` with `let urlString: String?`, `let fallbackMuscle: String` (drives the gradient tint via the same muscle-colour mapping the grid uses today), `var contentMode: ContentMode = .fill`. Behaviour: empty/nil/invalid URL → gradient placeholder immediately (no network); cache hit → immediate `Image(uiImage:)`; miss → `URLSession` load with the gradient shown while loading, insert into cache on success, gradient on failure. Downsample large images to display size before caching (ImageIO thumbnail API) so grid scrolling stays smooth.
- **Xcode registration:** add to `AuraFitness.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + `DesignSystem` group child + Sources-phase entry, fresh non-colliding 24-hex UUIDs, copy neighbouring formatting).

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- URL validation: trim whitespace; require http(s) scheme; a malformed string behaves exactly like "no URL" (no crash, no dead button).
- Offline/airplane mode: loads fail silently to the gradient placeholder; no error UI; no auto-retry beyond once per appearance.
- Auto-play fires at most once per exercise per session and NEVER when the setting is off or the URL is missing.
- Grid cell reuse: async loads must cancel or ignore stale results when a cell is recycled (capture the URL and compare before applying).
- No new SPM dependencies; plain `AsyncImage` alone is insufficient (no cache) — the `NSCache` layer is required.
- App Transport Security: YouTube/image hosts are https — do not add ATS exceptions.
