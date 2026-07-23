# IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker

## ⚠️ OPEN QUESTIONS
None. One deliberate divergence from the original prototype is pre-decided: the prototype allowed only ONE superset pair per workout; this codebase's Active Workout already supports MULTIPLE pairs via `supersetGroupID` (see `AuraFitness/ActiveWorkout/WorkoutSessionState.swift`, `createSuperset`). The Plan editor must follow the codebase convention: multiple pairs allowed, each pair = exactly 2 adjacent exercises sharing one `supersetGroupID`.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). Spec 03-01 rebuilt the Plan tab's `WorkoutEditorView` into custom cards with a per-exercise ⋯ menu (`ExerciseEditMenuSheet` in `AuraFitness/Plan/WorkoutEditorComponents.swift`) whose `onSubstitute` / `onSuperset` / `onAddAfter` closures were intentionally left `nil`. This spec supplies those three actions: an exercise picker that operates in three modes, plus superset creation/removal with the design's connector-bar rendering.
- **Existing Patterns to Match:**
  - `AuraFitness/ActiveWorkout/WorkoutOverviewView.swift` — contains `ExercisePickerSheet`, the existing library-backed picker (search + list over `ExerciseDatabase.shared.entries`, returns a built `Exercise`). Reuse its entry→`Exercise` conversion logic; do NOT modify that struct itself (Active Workout depends on it).
  - `AuraFitness/ActiveWorkout/SupersetView.swift` + `WorkoutSessionState.createSuperset` — the superset pairing/rendering conventions to mirror.
  - `AuraFitness/Models/WorkoutModels.swift` — `Exercise.supersetGroupID: UUID?` already exists; no model change needed.
  - Design tokens: `Color.aura.*`, `AuraFont.*`, `AuraSpacing.*`, components from `AuraFitness/DesignSystem/AuraComponents.swift`.
  - ⚠️ Naming: a struct named `PlanExercisePickerView` already exists (`AuraFitness/Plan/PlanExercisePickerView.swift`, legacy mock layer). Do NOT reuse or touch that name — the new picker is `EditorExercisePicker`.
- **Core Strategy:** Add a mode-driven picker (`EditorExercisePicker`) and a superset partner sheet (`SupersetPickSheet`) in new files. Wire the three nil closures in `WorkoutEditorView` to present them, mutate `workout.exercises` in place, and render paired cards with the connector bar. All mutations stay inside the editor's local `@State var workout` — the existing Save path persists them unchanged.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/WorkoutEditorView.swift`
- Add `@State private var pickerMode: PickerMode?` where `enum PickerMode: Identifiable { case substitute(index: Int), addAfter(index: Int), supersetNew(leaderIndex: Int) }` (make `id` a stable String like `"sub-3"`).
- Add `@State private var supersetPickIndex: Int?` (leader index for the partner-choice sheet).
- In the `ExerciseEditMenuSheet` call, replace the `nil` closures:
  - `onSubstitute` → `pickerMode = .substitute(index: i)`
  - `onAddAfter` → `pickerMode = .addAfter(index: i)`
  - `onSuperset` → if the exercise at `i` already has `supersetGroupID != nil`, dissolve that pair immediately (set both members' `supersetGroupID = nil`); else `supersetPickIndex = i`. The menu row label must read "Remove Superset" instead of "Create Superset" when the exercise is already paired (pass a boolean into the sheet for the label).
- Present `.sheet(item: $pickerMode)` → `EditorExercisePicker(mode:onPick:)` and a sheet for `SupersetPickSheet` (wrap the Int leader index in an `Identifiable` box).
- Apply-pick logic (one function `applyPick(_ ex: Exercise)` switching on the active mode):
  - `.substitute(i)`: replace `workout.exercises[i]` with the picked exercise, carrying over the OLD exercise's `plannedSets`, `repRange`, and `supersetGroupID` onto the replacement.
  - `.addAfter(i)`: insert picked exercise at `i + 1` with `supersetGroupID = nil`.
  - `.supersetNew(leader)`: generate `let gid = UUID()`, set it on the leader, insert the picked exercise at `leader + 1` with the same `gid`.
- Superset with an EXISTING exercise (from `SupersetPickSheet`): dissolve any group either party already belongs to, generate a fresh `gid`, set it on both, then move the partner so it sits immediately after the leader (recompute the leader's index after removal when the partner originally sat before the leader — off-by-one guard).
- **Pair rendering** in the exercise list: an exercise is a "leader" when it has a non-nil `supersetGroupID` and the NEXT exercise shares it; the follower is that next one. Between leader and follower cards render `SupersetConnector` (new component). Both paired cards get an accent-tinted border overlay (`RoundedRectangle` stroked `Color.aura.accent.opacity(0.5)`). Pass `isSupersetLeader` into `ExerciseEditCard` (parameter exists from 03-01) so the accent "SS" badge shows on the leader only.

## 📄 FILES TO CREATE
### `AuraFitness/Plan/EditorExercisePicker.swift`
- **Purpose:** Sheet-presented exercise picker for the workout editor: search, muscle filter chips, equipment filter chips, 2-column catalog grid; behaviour varies by mode.
- **Signatures/Interfaces:**
  - `enum EditorPickerMode { case substitute(replacingName: String), addAfter, supersetNew }` — display variant only (the editor holds the indices).
  - `struct EditorExercisePicker: View` with `let mode: EditorPickerMode`, `let onPick: (ExerciseEntry) -> Void`. Internally: `@StateObject private var db = ExerciseDatabase.shared`, `@State var search: String`, `@State var muscle: String?`, `@State var equip: String?`.
  - Header title by mode: "Substitute" (plus a sub-line "Replacing {replacingName}" in `.aura.text2`), "Add Exercise", "Pick Exercise B".
  - Filter rows: muscle chips built from `db.categories` PLUS the design rule that a chip labelled **"Arms"** matches entries whose category is "Biceps" OR "Triceps" (copy the existing "Arms" mapping if present in `AuraFitness/Plan/PlanSubtabViews.swift`). Equipment chips from `db.equipment`. Both filters combine with case-insensitive name search.
  - Grid: `LazyVGrid` 2 columns; each cell = muscle-tinted gradient thumbnail block with the muscle name overlaid, exercise name, and sub-line "{category} · {equipment}" — copy the exact cell styling from the Exercises library grid in `AuraFitness/Plan/PlanSubtabViews.swift` (`PlanExercisesBody`) so the two grids are visually identical.
  - Empty state: centered "No exercises found" in `.aura.text2`.
  - Selecting a cell calls `onPick(entry)` and dismisses. The editor converts `ExerciseEntry → Exercise` reusing the same conversion used by `ExercisePickerSheet` in `WorkoutOverviewView.swift`; if that conversion is inline there, extract it into a shared helper (e.g. `Exercise.init(entry: ExerciseEntry)` in `AuraFitness/Models/WorkoutModels.swift`) and make BOTH call sites use it.
### `AuraFitness/Plan/SupersetPickSheet.swift`
- **Purpose:** The "create superset" partner chooser for a given leader exercise.
- **Signatures/Interfaces:**
  - `struct SupersetPickSheet: View` with `let leader: Exercise`, `let candidates: [Exercise]` (all other exercises in the workout not already in a superset), `let onPickExisting: (Exercise) -> Void`, `let onPickFromLibrary: () -> Void`.
  - Layout: header "Create Superset"; a row showing the leader with a circled **"A"** badge (`.aura.accent`); section label "Pair with existing"; one row per candidate with a circled **"B"** badge (tap → `onPickExisting`); footer row "Pick from library" with chevron (tap → `onPickFromLibrary`, which the editor routes into `EditorExercisePicker` `.supersetNew` mode). If `candidates` is empty, show only the library option plus a muted line "No other exercises available to pair".
- Also ADD to `AuraFitness/Plan/WorkoutEditorComponents.swift`: `struct SupersetConnector: View` — an HStack of two 1-pt `Color.aura.accent` rules flanking a pill containing a bolt icon + text "SUPERSET" (`AuraFont.sectionLabel()`, `.aura.accent`, accent-tinted capsule background).
### Xcode project registration (required or CI fails)
- Register BOTH new files in `AuraFitness.xcodeproj/project.pbxproj`: one PBXBuildFile + one PBXFileReference + one `Plan` group child + one Sources-phase entry each, with fresh 24-hex UUIDs verified non-colliding (grep the file first). Copy the formatting of neighbouring Plan entries verbatim.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Adjacency invariant: after ANY mutation (substitute, add, remove, drag-reorder from 03-01), a pair whose members are no longer adjacent must be auto-dissolved (clear both `supersetGroupID`s). Implement as a single `normalizeSupersets()` pass run after every mutation of `workout.exercises`.
- Removing one member of a pair clears the surviving member's `supersetGroupID`.
- No chains: a follower must never itself be a leader — candidates already carrying a `supersetGroupID` are filtered out of `SupersetPickSheet.candidates`.
- Substitute on a pair follower keeps the pair intact (the carried-over `supersetGroupID` rule guarantees this — verify by test).
- Off-by-one when moving an earlier-positioned partner behind a later leader: removal shifts the leader's index down by 1; recompute before inserting.
- Read-only (`.view`) editor context: ⋯ menus are hidden (03-01), so these flows can't trigger — but connector bars and SS badges must still RENDER for workouts already containing pairs.
