# IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign

## ⚠️ OPEN QUESTIONS
None. All behaviours below are fully specified. Persistence semantics are already correct in the current file — this is a visual/interaction rebuild that must NOT change any save/delete logic.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness is a SwiftUI iOS app (four tabs: Log / Plan / Progress / Profile). The Plan tab's workout editor (`WorkoutEditorView`) currently renders a stock `List`/`.insetGrouped` form. The app's design requires a fully custom card-based editor: an editable name field, two "rest ladder" stepper cards, and custom exercise cards with a per-exercise ⋯ action menu. This spec rebuilds the editor UI to that design while preserving the existing data-commit paths untouched.
- **Existing Patterns to Match:**
  - `AuraFitness/DesignSystem/AuraComponents.swift` — `AuraCard`, `AuraChip`, `AuraBadge`, `AuraSectionLabel`, `AuraPrimaryButton`, `AuraGrayButton`, `AuraTintedButton`. Use these; do not invent parallel components.
  - `AuraFitness/DesignSystem/AuraColors.swift` (`Color.aura.*` tokens), `AuraTypography.swift` (`AuraFont.*`), `AuraSpacing.swift` (`AuraSpacing.*`). Never hardcode hex colors or system fonts.
  - `AuraFitness/ActiveWorkout/WorkoutOverviewView.swift` — canonical example of a custom card list with per-row menus in this codebase; mirror its card/backdrop styling idioms.
  - `AuraFitness/Plan/MyPlansView.swift` — canonical Plan-tab screen structure (custom header row + `ScrollView` body on `Color.aura.bg`).
- **Core Strategy:** Rewrite `WorkoutEditorView.body` from `List` to a `ScrollView` + `VStack` of custom cards. Extract new reusable subviews into a new file `WorkoutEditorComponents.swift`. Keep `WorkoutEditorContext`, `saveWorkout()`, `deleteWorkout()`, the `SaveEditScopeSheet` flow, and the `ExercisePickerSheet` add flow identical in behaviour (they may move within the file but their logic must not change). Register the new file in the Xcode project.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/WorkoutEditorView.swift`
- **Keep unchanged (logic):** `enum WorkoutEditorContext` (all 6 cases), `isReadOnly`, `title`, `saveWorkout()`, `deleteWorkout()`, the `.sheet(isPresented: $showExLibrary)` → `ExercisePickerSheet` append flow, the `.sheet(isPresented: $showSaveScope)` → `SaveEditScopeSheet` flow, and the delete `.alert`.
- **Replace `body`:** `ScrollView` containing, in order, on `Color.aura.bg`:
  1. **Name field card**: when `isReadOnly`, a large non-editable `Text(workout.name)` in `AuraFont.title()`; otherwise a borderless `TextField("Workout Name", text: $workout.name)` styled with `AuraFont.title()`, inside an `AuraCard`. Below it (same card) the `TextField("Primary Muscles", ...)` and the duration `Stepper` from the current implementation, restyled with `AuraFont.body()` / `.aura.text2`.
  2. **Two `RestLadderPicker` cards** (new component, below): "Between sets" bound to `$workout.restBetweenSets` and "After exercise" bound to `$workout.restBetweenExercises`. Hidden entirely when `isReadOnly`.
  3. **Exercise list**: `AuraSectionLabel(title: "Exercises (\(workout.exercises.count))")`, then one `ExerciseEditCard` (new component) per element of `workout.exercises`, iterated with `ForEach(Array(workout.exercises.enumerated()), id: \.element.id)`.
  4. **Add Exercise** row: `AuraTintedButton` labelled `"Add Exercise"` with a plus icon → sets `showExLibrary = true`. Hidden when `isReadOnly`.
  5. **"Add to My Plans"** button for `.view` context — keep current behaviour (opens `showSaveScope`), restyle as `AuraPrimaryButton`.
- **Reorder:** replace `List.onMove` with drag-to-reorder on the custom cards using `onDrag`/`onDrop` over the `ForEach` with an `@State private var draggingID: UUID?`. While a card is being dragged, all OTHER cards get `.opacity(0.5)` and an overlay `RoundedRectangle` stroked with a dashed `Color.aura.text3` line (this "dim others, dashed" effect is a hard design requirement). Reordering must be disabled when `isReadOnly`.
- **Toolbar:** keep the Save button (trailing, disabled when `workout.name.isEmpty`, `.aura.accent`) and the destructive bottom-bar delete for `.editInProgram`. Remove `EditButton()` (no longer meaningful without `List`).

## 📄 FILES TO CREATE
### `AuraFitness/Plan/WorkoutEditorComponents.swift`
- **Purpose:** Reusable pieces for the workout editor: the rest ladder picker, the exercise edit card, and the per-exercise action menu sheet.
- **Signatures/Interfaces:**
  - `let restLadder: [Int] = [15, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]` (file-scope constant, internal access).
  - `func restLabel(_ seconds: Int) -> String` — returns `"45s"` style for values < 60, else `"m:ss"` (90 → `"1:30"`, 120 → `"2:00"`).
  - `struct RestLadderPicker: View` with `let title: String`, `@Binding var seconds: Int`. Renders an `AuraCard` with: title (`AuraFont.secondary()`, `.aura.text2`), the formatted current value (`AuraFont.cardTitle()`, `.aura.text`), minus/plus circular buttons that step to the previous/next ladder entry (clamped at both ends; if the bound value is not in the ladder, snap to nearest), and a row of small dots — one per ladder entry — where the active entry's dot is `.aura.accent` and the rest `.aura.text3.opacity(0.4)`.
  - `struct ExerciseEditCard: View` with `let exercise: Exercise`, `let index: Int`, `let isReadOnly: Bool`, `let isSupersetLeader: Bool`, `let onTapName: () -> Void`, `let onMenu: () -> Void`. Layout: HStack of [drag grip `line.3.horizontal` glyph in `.aura.text3`, hidden when read-only] · [VStack: exercise name (`AuraFont.body()`, `.aura.text`, tappable → `onTapName`) over a chip row: `AuraBadge` "\(exercise.plannedSets) sets", `AuraBadge` "\(exercise.repRange) reps", and — only when `isSupersetLeader` — an accent-coloured `AuraBadge` "SS"] · [Spacer] · [⋯ button (`ellipsis` glyph, `.aura.text2`) → `onMenu`, hidden when read-only]. Wrapped in `AuraCard`.
  - `struct ExerciseEditMenuSheet: View` with `@Binding var exercise: Exercise`, plus closures `let onSubstitute: (() -> Void)?`, `let onSuperset: (() -> Void)?`, `let onAddAfter: (() -> Void)?`, `let onRemove: () -> Void`. Presented via `.sheet` + `.presentationDetents([.medium])`. Contents top-to-bottom:
    1. Inline **Sets stepper**: minus/plus around `Text("\(exercise.plannedSets) sets")`; clamped 1...10. Edits write straight into the binding (live).
    2. Inline **Rep range** text field bound to `exercise.repRange` (live).
    3. Action rows (tappable rows in the style of `AuraListRow` from `AuraComponents.swift`): "Substitute Exercise" (rendered only when `onSubstitute != nil`), "Create Superset" (only when `onSuperset != nil`), "Add Exercise After" (only when `onAddAfter != nil`), and "Remove Exercise" in `.aura.red` (always). Each row fires its closure then dismisses the sheet.
  - **In this spec, wire only `onRemove`** (removes the exercise from `workout.exercises` by matching `id`). Pass `nil` for `onSubstitute` / `onSuperset` / `onAddAfter` — a follow-up feature (03-02) supplies them. The nil-hiding contract is what makes that follow-up a pure addition.
### Xcode project registration (required or CI fails)
- Add `WorkoutEditorComponents.swift` to `AuraFitness.xcodeproj/project.pbxproj` exactly the way existing `Plan/` files are registered: one `PBXBuildFile` entry, one `PBXFileReference` entry, one child in the `Plan` `PBXGroup`, one entry in the app target's Sources build phase. Generate fresh 24-hex-char UUIDs that do not collide with any existing id in the file (grep the file for your chosen ids first). Copy the formatting of the neighbouring `SaveEditScopeSheet.swift` entries verbatim.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- `workout.restBetweenSets` / `restBetweenExercises` may hold values not present in the ladder (legacy persisted data, e.g. 65). The picker must snap to the nearest ladder entry on first interaction rather than crash or loop.
- Empty exercise list: show a dashed-border placeholder card reading "No exercises yet — add one below" instead of rendering nothing.
- Removing an exercise while its menu sheet is open must not crash: dismiss the sheet before mutating, and resolve the target by `id` (never by a stale integer index).
- Rep-range field: accept free text (e.g. "8–12"); if the user clears it, restore the default `"8–12"` on commit rather than persisting an empty string.
- Read-only (`.view`) context must show name/muscles/duration as plain text, no grips, no ⋯ buttons, no rest pickers, no Add Exercise — but still render the exercise cards and the "Add to My Plans" button.
- Do not modify `SaveEditScopeSheet.swift`, `ExercisePickerSheet`, or any database singleton. Verify the touched files with `swiftc -parse` if no Xcode toolchain is available (this repo builds on CI, not locally).
