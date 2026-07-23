# IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity

## ⚠️ OPEN QUESTIONS
None. This is an audit-and-fix task against a fixed checklist: for each requirement below, verify the current implementation and change it only where it deviates. Where the current file already matches, leave it byte-identical.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Plan tab pushes two full-screen surfaces for programs: `ProgramDetailView` (predefined program preview) and `ProgramEditorView` (build-a-program-from-scratch). Both exist and are DB-wired (`ProgramDatabase.shared`, `UserPlanDatabase.shared`) but were built before the final design pass. This spec brings both to the exact design.
- **Existing Patterns to Match:**
  - `AuraFitness/Plan/MyPlansView.swift` — canonical Plan screen structure; ALSO contains the week-strip UI (`PlanScheduleEditorView` / week day tiles) that the Program editor must reuse rather than reimplement.
  - `AuraFitness/Plan/PlanSubtabViews.swift` — `PlanProgramsBody` card styling (thumb, name, meta line) for visual consistency.
  - Design tokens/components: `Color.aura.*`, `AuraFont.*`, `AuraSpacing.*`, `AuraCard`, `AuraChip`, `AuraBadge`, `AuraPrimaryButton`, `AuraGrayButton`, `AuraSectionLabel` from `AuraFitness/DesignSystem/`.
  - `AuraFitness/Models/AppState.swift` — `addPlan(from:program:startDay:)` is the existing, correct "Add to My Plans" mutation; `calendarStartDay` is the week-start setting.
- **Core Strategy:** Audit both files against the checklists below; apply minimal diffs to reach exact parity. No data-layer changes.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/ProgramDetailView.swift`
Required final state (top-to-bottom):
1. **Hero:** 16:9 placeholder block (program-tinted gradient, matching the gradient style used for program cards in `PlanProgramsBody`), then program name in `AuraFont.title()`.
2. **Generated description** line: exactly `"A {daysPerWeek}-day {style} split. {level} level."` in `.aura.text2` (use the program's real fields).
3. **Chips row:** three chips: `"{daysPerWeek} days/wk"`, `"{level}"`, `"{style}"`.
4. **"Workouts in this program"** section: numbered rows (1., 2., …) for the program's workouts — row = number badge · workout name · muscle sub-line · chevron; tap pushes `WorkoutEditorView(workout: w, context: .view)`. Only the program's real workouts (no fake fill).
5. **Info card:** accent-tinted card with info icon and copy: "Predefined programs must be added to My Plans before editing. Edits live on your copy." (skip when `program.isPredefined == false`).
6. **Bottom sticky `AuraPrimaryButton("Add to My Plans")`** → calls the existing `AppState.addPlan(from:program:startDay: appState.calendarStartDay)` API, then dismisses. If the 3-plan cap makes it return failure, surface an alert: "My Plans is full — remove a plan first." The button flips to a disabled "Added ✓" state when `UserPlanDatabase.shared.plans` already contains a plan with `sourceProgramID == program.id`.
### `AuraFitness/Plan/ProgramEditorView.swift`
Required final state:
1. **Name field:** large, auto-focused (`@FocusState`, focus on appear) text field, placeholder "Program name".
2. **Difficulty segmented control (optional value):** segments Beginner / Intermediate / Advanced tinted green / accent / red; tapping the ACTIVE segment again clears the selection (difficulty optional). Store into the program's `level` ("" when cleared).
3. **Week strip:** reuse the week-strip component from `MyPlansView.swift` (extract to a shared struct if currently private — extraction allowed; never duplicate the code). Day order follows `appState.calendarStartDay`. Tapping a day while zero workouts exist must NOT open assign — instead flash an accent inline warning banner "Add workouts below before assigning days" auto-dismissing after 2.5 s. With workouts present, tapping a day opens the same assign flow `MyPlansView` uses.
4. **Workouts section:** empty state = two `AuraTintedButton`s "Add from Workout Library" and "Create your own workout"; populated = one row per workout (inline editable name, chevron → `WorkoutEditorView(workout:, context: .createInProgram/.editInProgram(programID:))`, red trash delete). Section-header `+` opens a chooser (library list vs create-own).
5. **Sticky footer `AuraPrimaryButton("Save Program")`:** disabled + dimmed while the name is empty. Saving persists via `ProgramDatabase.addProgram` (create) / `updateProgram` (edit) — keep existing wiring; verify it fires and dismisses.

## 📄 FILES TO CREATE
None, unless the week-strip extraction requires a new file — then create `AuraFitness/Plan/WeekStrip.swift` with the extracted shared struct and register it in `AuraFitness.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + Plan group child + Sources entry, fresh non-colliding 24-hex UUIDs, copy neighbouring formatting).

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Program with zero workouts: detail renders the section header with "No workouts in this program yet" (no numbered rows); Add to My Plans still works.
- 3-plan cap: `UserPlanDatabase.maxPlans = 3` is enforced in the DB layer — the UI must handle the `false` return with the alert copy above, never silently no-op.
- Deleting a workout in the program editor must also null any week-strip day pointing at it (mirror `MyPlansView`'s delete behaviour).
- Week-start: strip order must flip correctly for Sunday-start and Monday-start without duplicate-label ForEach issues (stable ids, not `id: \.self` on repeated day letters).
- Do not alter `ProgramDatabase`/`UserPlanDatabase` method signatures; UI-only changes plus the optional week-strip extraction.
