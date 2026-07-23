# IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources

## ⚠️ OPEN QUESTIONS
None.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The full exercise catalog lives at the repo root as `gym_exercise_library.json` (~145 KB), and `ExerciseDatabase` (`AuraFitness/Models/ExerciseDatabase.swift`) is written to load it from the app bundle — but the file is NOT registered in the Xcode project (grep of `AuraFitness.xcodeproj/project.pbxproj` for `gym_exercise_library` returns 0 matches), so the database silently falls back to its ~11 hardcoded exercises (audit finding N4). This spec bundles the JSON properly.
- **Existing Patterns to Match:**
  - `AuraFitness.xcodeproj/project.pbxproj` — the `Assets.xcassets` registration (commit `a9fa7bf`) shows a working Resources-phase entry: one `PBXBuildFile`, one `PBXFileReference`, group membership, and one entry in the target's `PBXResourcesBuildPhase`. Mirror that exact shape for the JSON.
  - `AuraFitness/Models/ExerciseDatabase.swift` — the bundle-loading path (find the `Bundle.main.url(forResource:...)` or equivalent) and the hardcoded fallback list.
- **Core Strategy:** Move the JSON inside the app folder, register it in the pbxproj Resources phase, and verify the loader actually parses it (decode against `ExerciseEntry`'s `Codable` shape) with the fallback retained for corrupt/missing data.

## 📝 FILES TO MODIFY
### `gym_exercise_library.json` → move to `AuraFitness/Resources/gym_exercise_library.json`
- Create the `AuraFitness/Resources/` folder; `git mv` the file (keep the exact filename the loader expects — check `ExerciseDatabase.swift` first; if the loader expects a different resource name, the LOADER's name wins and the file is renamed to match it).
### `AuraFitness.xcodeproj/project.pbxproj`
- Add: one `PBXFileReference` for the JSON (`lastKnownFileType = text.json`), a `Resources` `PBXGroup` (or add to an existing group mirroring the folder), one `PBXBuildFile`, and one entry in the app target's `PBXResourcesBuildPhase` `files` list (the phase already exists — it contains `Assets.xcassets`). Fresh 24-hex UUIDs, verified non-colliding via grep before use. Comment text must match the real filename.
### `AuraFitness/Models/ExerciseDatabase.swift`
- Verify the load path: on init it must (1) try the bundled JSON, (2) decode into `[ExerciseEntry]` (fields per the struct at the top of the file: name, category, equipment, musclesTargeted, type, difficulty, repRange, youtubeURL, imageURL, proTips, warmupProtocol, …), (3) merge with any user-created custom exercises from persistence WITHOUT duplicating them, and (4) fall back to the hardcoded list ONLY when the resource is missing or fails to decode. Add a one-line os_log/`print` warning on fallback so dev/CI catches silent failures. If the JSON's field names don't match the `Codable` keys, add `CodingKeys` on the DECODER side — do not edit the JSON's schema.

## 📄 FILES TO CREATE
None beyond the moved file.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- User-created exercises (`isCustom == true`) persisted from earlier runs must survive: bundled entries and persisted customs merge by id/name without wiping either.
- Malformed entries inside the JSON: skip bad records individually (lossy array decode — `try?` per element wrapper) rather than discarding the whole library.
- After bundling, the Exercises library jumps from ~11 to hundreds of entries; verify library grid, pickers, and search stay responsive (LazyVGrid already used; no eager image loading — images are a separate feature).
- Validate the JSON parses BEFORE committing (`python -c "import json; json.load(open('gym_exercise_library.json'))"` or equivalent).
- Do not leave a duplicate copy at the repo root — single source inside `AuraFitness/Resources/`.
