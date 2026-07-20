# IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar

## ⚠️ OPEN QUESTIONS
None. Tab composition is pre-decided: design tabs are Workout (contextual) / Overview / History; the existing detail's Tips content merges INTO Overview, and the existing Warmup tab stays as a trailing tab. Do not drop warmup content.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). `ExerciseEntryDetailView` (in `AuraFitness/Plan/ExerciseDetailView.swift` — file name ≠ struct name) is the library exercise detail with tabs Overview / Tips / Warmup. Design requires: a **History** tab (personal bests + past sessions from real logs, Epley 1RM), an optional leading **Workout** tab (only when opened from the workout editor; inline sets/reps/rest editing with write-back), and a bottom **action bar** (only when opened from the Exercises library): "Add to Today's Workout" + "Add to a Plan".
- **Existing Patterns to Match:**
  - `AuraFitness/Plan/ExerciseDetailView.swift` — current hero/tab switcher/Overview/Tips/Warmup; extend, don't rewrite.
  - `AuraFitness/Models/AppState.swift` — `workoutLogs`, `personalRecords` (append-only), `setOverride(_:for:)` (line ~910), `todayWorkout()` (line ~749), `iso(...)`. Compute History from these — never seed fake sessions.
  - `AuraFitness/Models/LogDayModel.swift` — `DayOverride.editedExercises: [Exercise]?`; the Log tab's edit flow in `AuraFitness/Log/LogSheetsView.swift` shows how overrides are built/stamped. Mirror for "Add to Today's Workout".
  - `RestLadderPicker` from `AuraFitness/Plan/WorkoutEditorComponents.swift` (built in 03-01).
  - `AuraFitness/Models/UnitFormatter.swift` for all weight display.
- **Core Strategy:** Add two optional entry contexts via init params defaulting to absent (existing call sites compile unchanged): `workoutCtx` and `showActions`. Tab row: `[Workout iff workoutCtx] · Overview · History · Warmup`. History computed on demand from `AppState`.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/ExerciseDetailView.swift` (struct `ExerciseEntryDetailView`)
- **New init params:** `var workoutCtx: WorkoutEditCtx? = nil` where `struct WorkoutEditCtx { var sets: Int; var repRange: String; var restSeconds: Int; var isSuperset: Bool; var partnerEntry: ExerciseEntry?; var onSave: (Int, String, Int) -> Void }`; and `var showActions: Bool = false`.
- **Tab row:** "Workout" first iff `workoutCtx != nil` (and becomes default selection); add "History" between Overview and Warmup; remove "Tips" tab and fold its content into Overview as: an accent-tinted **"Pro tip"** card (`entry.proTips.first`, skip if empty) + a numbered **"Key takeaways"** list of remaining `proTips` (skip if none), below the existing Overview content.
- **Workout tab body:** hero block, Sets stepper (1...10) seeded `workoutCtx.sets`, Rep-range text field seeded `workoutCtx.repRange`, `RestLadderPicker` with ladder `[30,45,60,75,90,120,150,180,240,300]` seeded `workoutCtx.restSeconds`, then `AuraPrimaryButton("Save Changes")` → `workoutCtx.onSave(sets, repRange, rest)` + dismiss.
- **A/B superset toggle:** when `workoutCtx?.isSuperset == true && partnerEntry != nil`, a 2-segment "A / B" control ABOVE the tab row; B swaps hero + all tabs to `partnerEntry`. Key all content off a computed `var activeEntry: ExerciseEntry`.
- **History tab body:**
  1. **Personal bests card** — 4 tiles: Est. 1RM · Max Weight · Max Reps · Max Volume. Source: scan `appState.workoutLogs` for exercises whose name equals `activeEntry.name` (case-insensitive, trimmed); over DONE sets only compute best Epley e1RM, max weight, max reps, max single-set volume (weight×reps). **Epley (exact):** `e1RM = weight × (1 + reps/30)` rounded to nearest 0.25; `reps <= 1` → `e1RM = weight`. Nil/0 weight displays `"BW"`.
  2. **Sessions list** — most recent first, max 10; row = date + set count + top-set summary, expandable to per-set table (Set · Weight · Reps · Est-1RM). Weights via `UnitFormatter`.
  3. **Empty state:** dumbbell glyph + "No logged sessions yet" + "Sessions appear here after you log this exercise." in `.aura.text2`.
- **Action bar** (iff `showActions`): bottom safe-area inset bar:
  - `AuraPrimaryButton("Add to Today's Workout")`: build `Exercise` from `activeEntry` (reuse the `ExerciseEntry → Exercise` conversion used by `ExercisePickerSheet` in `AuraFitness/ActiveWorkout/WorkoutOverviewView.swift`), append to `appState.todayWorkout()?.exercises ?? []`, stamp via `appState.setOverride(...)` for today's ISO exactly like the Log tab's edit-workout flow in `LogSheetsView.swift` (same `DayOverride` kind + `editedExercises` payload). Confirm with the codebase's toast/flash pattern, or a 1.8s overlay capsule "Added to today" if none exists.
  - `AuraGrayButton("Add to a Plan")`: sheet listing the default plan's workouts (`UserPlanDatabase.shared`; fall back to all plans), then a second sheet: "Add as new exercise" (append) vs "Replace one" (lists that workout's exercises filtered to `activeEntry`'s primary muscle; substitution carries over `plannedSets`/`repRange`). Persist via the `updateCustomWorkout`/`updateWorkout` APIs as used in `AuraFitness/Plan/WorkoutEditorView.swift`.
### `AuraFitness/Plan/PlanTabView.swift`
- Exercises-subtab presentation of `ExerciseEntryDetailView(entry:)` → pass `showActions: true`.
### `AuraFitness/Plan/WorkoutEditorView.swift`
- `ExerciseEditCard.onTapName` (03-01) presents `ExerciseEntryDetailView` with `workoutCtx`: `sets = exercise.plannedSets`, `repRange = exercise.repRange`, `restSeconds = workout.restBetweenSets`, `isSuperset`/`partnerEntry` from pair state (03-02), `onSave` writes the three values back (rest onto `workout.restBetweenSets`). Resolve `ExerciseEntry` by case-insensitive name lookup in `ExerciseDatabase.shared`; if no match (custom exercise), show an alert "This custom exercise has no library page" — never crash.

## 📄 FILES TO CREATE
None normally. If `ExerciseDetailView.swift` exceeds ~700 lines after edits, extract the History tab into `AuraFitness/Plan/ExerciseHistoryTab.swift` and register it in `AuraFitness.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + Plan group child + Sources entry, fresh non-colliding 24-hex UUIDs, copy neighbouring formatting).

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Sets not `done` or with nil weight/reps are excluded from PB math; a session with zero qualifying sets still lists with "— no completed sets".
- e1RM rounding to 0.25 happens in canonical kg BEFORE `UnitFormatter` conversion.
- The legacy `struct ExerciseDetailView` (same file, used by Active Workout) must remain untouched and compiling.
- If both `showActions` and `workoutCtx` are passed, `workoutCtx` wins; hide the action bar.
- "Add to Today's Workout" when today has no planned workout: stamp an override whose `editedExercises` contains only the new exercise — `AppState.dayInfo`'s placeholder synthesis already renders this as a "Custom Workout" day (existing verified behaviour).
