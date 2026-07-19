# IMPLEMENTATION SPEC

Audit finding **N2 (HIGH)** — Plan tab is a non-functional prototype mirror. This spec routes the real DB-backed Plan views into the live UI, defines the one missing type (`SaveEditScopeSheet`), and registers the orphaned files into the Xcode build target.

## ⚠️ OPEN QUESTIONS

None that block implementation. Two decisions were made with documented defaults (see ASSUMPTIONS). If the product owner disagrees with either, only the noted lines change.

### ASSUMPTIONS (defaults chosen — safe to proceed)
1. **Chosen direction = Option (a), executed as a low-risk hybrid.** We route `PlanTabView`'s four sub-tabs to the DB-backed views and register the 9 orphan files. We do **NOT** delete the mock `Plan*`-prefixed files in this pass. Reason: several mock files (`PlanModels.swift`, `PlanComponents.swift`, `PlanBodyMap.swift`, `PlanExerciseDetailData.swift`, `PlanSubtabViews.swift`, `PlanSheets.swift`, `PlanProgramViews.swift`, `PlanWorkoutEditorView.swift`, `PlanExerciseDetailView.swift`, `PlanExercisePickerView.swift`) are mutually interdependent and already in the build target; deleting them on a branch that has **no working local Xcode toolchain for verification** is high-risk. Instead we gut `PlanTabView.swift` so it renders the DB views, leaving the unused mock helper files compiling but unreferenced. Cleanup of the now-dead mock files is filed as a FOLLOW-UP below, not done here.
2. **`SaveEditScopeSheet` "Add to My Plans" behavior:** In read-only `WorkoutEditorView` (context `.view`), tapping "Add to My Plans" opens `SaveEditScopeSheet`. Its `onJustToday` is passed `nil` by the caller (already the case at `WorkoutEditorView.swift:98`), so the sheet must render ONLY the "Permanently" branch when `onJustToday == nil`. The `onPermanently` closure currently calls `saveWorkout()`, which for `.view` context is a no-op (`WorkoutEditorView.swift:156-157`). That is acceptable for this pass — the button will dismiss without error. Making "Add to My Plans" actually copy the workout into the default plan is filed as a FOLLOW-UP (it requires product input on which plan to target). Do NOT change `WorkoutEditorView.saveWorkout()` behavior in this pass.

## 🏗️ ARCHITECTURE & PATTERNS

- **Existing Patterns to Match:**
  - `AuraFitness/Plan/MyPlansView.swift` — self-contained DB-backed view; owns its own sheets, uses `@StateObject private var planDB = UserPlanDatabase.shared`. This is the canonical style for the new subtab views.
  - `AuraFitness/Plan/WorkoutEditorView.swift` — shows the exact `SaveEditScopeSheet(...)` call site to satisfy (lines 96-103).
  - `AuraFitness/DesignSystem/AuraComponents.swift` — `AuraPrimaryButton`, `AuraTintedButton`, `AuraGrayButton`, `AuraCard`, `AuraChip`, `AuraBadge`, `AuraSectionLabel`, `AuraProgressBar`, `AuraListRow` all already exist and are in the build; reuse them, do NOT create new components.
  - `AuraFitness.xcodeproj/project.pbxproj` — file registration format (three sync'd sections). Copy the shape of the existing Plan entries verbatim (lines 54-64, 129-139, 269-279, 466-476).
  - `AuraFitness/ContentView.swift:50` — `case .plan: PlanTabView()` is the single mount point; leave it unchanged.

- **Core Strategy:** Keep `PlanTabView` as the tab shell (title bar + four filter chips). Replace each mock subtab body with the corresponding real DB-backed view. All four DB-backed subtab roots already read/write `ProgramDatabase.shared` / `UserPlanDatabase.shared` / `ExerciseDatabase.shared` (which are seeded on boot and Supabase-synced), so no data wiring is required beyond mounting them. Add the single missing `SaveEditScopeSheet` type so `WorkoutEditorView` compiles, then register all orphan files in the pbxproj.

## 🔎 GROUND-TRUTH FACTS (verified in current tree @ 05df5f4)

- The 9 orphaned DB-backed files exist on disk in `AuraFitness/Plan/` and are **NOT** in the pbxproj target:
  | File on disk | Public struct(s) it defines |
  |---|---|
  | `MyPlansView.swift` | `MyPlansView`, `CreatePlanView`, `PlanScheduleEditorView` |
  | `ProgramLibraryView.swift` | `ProgramLibraryView` |
  | `ProgramDetailView.swift` | `ProgramDetailView` |
  | `ProgramEditorView.swift` | `ProgramEditorView` (with `.Mode` = `.create` / `.edit(Program)`) |
  | `WorkoutLibraryView.swift` | `WorkoutLibraryView` |
  | `WorkoutEditorView.swift` | `WorkoutEditorView`, `enum WorkoutEditorContext` |
  | `ExerciseLibraryView.swift` | `ExerciseLibraryTabView` (⚠️ struct name ≠ file name) |
  | `ExerciseDetailView.swift` | `ExerciseEntryDetailView`, `ExerciseDetailView` (⚠️ two structs; struct name ≠ file name) |
  | `CreateExerciseView.swift` | `CreateExerciseView` |
- The pbxproj currently registers ONLY the 11 mock `Plan*` files. The `Plan` PBXGroup id is `ACGRP060000000000000000A` (children list ends at project.pbxproj line 279; group closes line 280).
- The Sources build phase `files` list for the app target contains the Plan entries ending at project.pbxproj line 476.
- `SaveEditScopeSheet` is **referenced but undefined** anywhere in the repo. Only call site: `WorkoutEditorView.swift:96-103`.
- `ExercisePickerSheet` (used by `WorkoutEditorView.swift:91`) **already exists** and is in the build at `AuraFitness/ActiveWorkout/WorkoutOverviewView.swift:360`. Do not redefine it.
- All model fields referenced by the orphan views exist in `AuraFitness/Models/WorkoutModels.swift` (`Program.style/.level/.daysPerWeek`, `Workout.primaryMuscles/.estimatedMinutes/.restBetweenSets/.restBetweenExercises`, `UserPlan.weekSchedule: [Int: UUID?]`, `ExerciseEntry` in `Models/ExerciseDatabase.swift`).
- `syncPush` extensions on `Program`/`UserPlan`/`ExerciseEntry` exist in `AuraFitness/Sync/Syncable.swift` (already in build).
- **Net conclusion:** once `SaveEditScopeSheet` exists and the 9 files are added to the target, every symbol the orphan files reference resolves. No other missing types.

## 📄 FILES TO CREATE

### `AuraFitness/Plan/SaveEditScopeSheet.swift`
- **Purpose:** Minimal reusable confirmation sheet asking the user the SCOPE of an edit/add: "just today" vs "permanently". Must satisfy the exact call at `WorkoutEditorView.swift:96-103`.
- **Exact required initializer contract (do not deviate — the call site is fixed):**
  ```
  SaveEditScopeSheet(
      onJustToday: (() -> Void)?,      // optional; when nil, hide the "Just Today" button
      onPermanently: @escaping () -> Void
  )
  ```
- **Required behavior:**
  - `struct SaveEditScopeSheet: View` with stored properties:
    - `let onJustToday: (() -> Void)?`
    - `let onPermanently: () -> Void`
    - `@Environment(\.dismiss) private var dismiss`
  - Body: a `VStack` (NOT wrapped in its own NavigationStack — the call site applies `.presentationDetents([.fraction(0.45)])`), containing:
    - A title `Text("Apply changes")` using `AuraFont.cardTitle()` and `.foregroundColor(.aura.text)`.
    - A subtitle `Text("Choose how to save this change.")` using `AuraFont.secondary()` and `.foregroundColor(.aura.text2)`.
    - IF `onJustToday != nil`: an `AuraTintedButton(label: "Just for Today")` whose action calls `onJustToday?()` then `dismiss()`.
    - An `AuraPrimaryButton(label: "Save Permanently", icon: "checkmark")` whose action calls `onPermanently()` then `dismiss()`.
    - An `AuraGrayButton(label: "Cancel")` whose action calls `dismiss()`.
  - Layout: `.padding(AuraSpacing.screenPad)`, `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`, `.background(Color.aura.bgGrouped)`.
- **Constraints:** Use ONLY existing design-system components (`AuraPrimaryButton`, `AuraTintedButton`, `AuraGrayButton`) and existing tokens (`Color.aura.*`, `AuraFont.*`, `AuraSpacing.*`). Do not add new dependencies. Keep it under ~50 lines.

## 📝 FILES TO MODIFY

### `AuraFitness/Plan/PlanTabView.swift`
Goal: keep the tab shell (title + four filter chips) but render the DB-backed views in each subtab. Do this with the **smallest possible diff** so the mock helper types stay compiling.

- **KEEP unchanged:** the `import SwiftUI`, `struct PlanTabView`, `@EnvironmentObject var appState`, the `private enum Subtab` (myplans/programs/workouts/exercises + `.label`), `@State private var subtab: Subtab = .myplans`, and the `navbar` computed property (the title row + filter-chip `ScrollView`). The `PlanIconButton`/`PlanFilterChip` used by `navbar` live in the mock files and remain in the build, so `navbar` still compiles.
- **DELETE these `@State` properties** (they backed the mock router and mock data and are no longer used): `schedule`, `workouts`, `modal`, `editingWk`, `viewingProg`, `editingProg`, `viewingEx`. Also delete `private var calStartSun`.
- **REPLACE the entire `var body`** so it no longer does mock routing. New body:
  ```
  var body: some View {
      VStack(spacing: 0) {
          navbar
          Group {
              switch subtab {
              case .myplans:   MyPlansView()
              case .programs:  ProgramLibraryView()
              case .workouts:  NavigationStack { WorkoutLibraryView() }
              case .exercises: NavigationStack { ExerciseLibraryTabView() }
              }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .background(Color.aura.bg)
  }
  ```
  Rationale for the per-case `NavigationStack` wrappers:
  - `MyPlansView` and `ProgramLibraryView` **already contain their own `NavigationStack`** — do NOT wrap them (double nav bars). Mount bare.
  - `WorkoutLibraryView` and `ExerciseLibraryTabView` use `.toolbar { ToolbarItem(.navigationBarTrailing) { + } }` and (for WorkoutLibraryView) `.navigationDestination(...)` but do **NOT** provide their own `NavigationStack` — they MUST be wrapped, or the toolbar `+` and push navigation silently do nothing.
- **DELETE the now-unused shell/body/modal machinery** from `PlanTabView`: the `shell` computed property, `myPlansBody`, the `assignDay`/`makeRest`/`deleteWorkout` mutation funcs, and the `modalView(_:)` builder. These reference deleted `@State` and mock sheets (`AddPlanSheet`, `AssignSheet`, etc.); they must be removed so the file compiles.
- **KEEP `navbar`.** After edits, `PlanTabView.swift` should contain only: imports, the struct, `appState`, `Subtab`, `subtab` state, `body`, and `navbar`. Nothing else.
- **VERIFY after edit:** the only symbols `PlanTabView` now references outside itself are `MyPlansView`, `ProgramLibraryView`, `WorkoutLibraryView`, `ExerciseLibraryTabView`, `PlanIconButton`, `PlanFilterChip`, `Color.aura.bg`, `AuraFont`, `AuraSpacing`. `PlanIconButton`/`PlanFilterChip` are defined in the mock files that remain in the target.

> Do NOT modify any of the 9 orphan files. Do NOT modify `ContentView.swift`. Do NOT modify `WorkoutEditorView.swift` (its `SaveEditScopeSheet` call becomes valid once the new file exists).

### `AuraFitness.xcodeproj/project.pbxproj`  — register 10 files (9 orphans + `SaveEditScopeSheet.swift`)

This project's build phases are **manually maintained** (no local Xcode). Static correctness is critical: each file needs THREE synchronized entries with matching 24-hex-uppercase UUIDs, and every UUID must be unique across the whole file. Use the exact UUIDs below (pre-generated, verified not to collide with existing ids in the file). Each file uses a distinct `buildID` (PBXBuildFile) and `fileID` (PBXFileReference) pair.

**UUID table (use verbatim):**
| File | fileID (PBXFileReference) | buildID (PBXBuildFile) |
|---|---|---|
| MyPlansView.swift | `CA01000000000000000A0001` | `CB01000000000000000A0001` |
| ProgramLibraryView.swift | `CA01000000000000000A0002` | `CB01000000000000000A0002` |
| ProgramDetailView.swift | `CA01000000000000000A0003` | `CB01000000000000000A0003` |
| ProgramEditorView.swift | `CA01000000000000000A0004` | `CB01000000000000000A0004` |
| WorkoutLibraryView.swift | `CA01000000000000000A0005` | `CB01000000000000000A0005` |
| WorkoutEditorView.swift | `CA01000000000000000A0006` | `CB01000000000000000A0006` |
| ExerciseLibraryView.swift | `CA01000000000000000A0007` | `CB01000000000000000A0007` |
| ExerciseDetailView.swift | `CA01000000000000000A0008` | `CB01000000000000000A0008` |
| CreateExerciseView.swift | `CA01000000000000000A0009` | `CB01000000000000000A0009` |
| SaveEditScopeSheet.swift | `CA01000000000000000A0010` | `CB01000000000000000A0010` |

**Step 1 — PBXBuildFile section.** Immediately AFTER project.pbxproj line 64 (the `PlanBodyMap.swift in Sources` build-file entry), insert these 10 lines (keep the leading two-tab indentation used by neighbors):
```
		CB01000000000000000A0001 /* MyPlansView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0001 /* MyPlansView.swift */; };
		CB01000000000000000A0002 /* ProgramLibraryView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0002 /* ProgramLibraryView.swift */; };
		CB01000000000000000A0003 /* ProgramDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0003 /* ProgramDetailView.swift */; };
		CB01000000000000000A0004 /* ProgramEditorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0004 /* ProgramEditorView.swift */; };
		CB01000000000000000A0005 /* WorkoutLibraryView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0005 /* WorkoutLibraryView.swift */; };
		CB01000000000000000A0006 /* WorkoutEditorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0006 /* WorkoutEditorView.swift */; };
		CB01000000000000000A0007 /* ExerciseLibraryView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0007 /* ExerciseLibraryView.swift */; };
		CB01000000000000000A0008 /* ExerciseDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0008 /* ExerciseDetailView.swift */; };
		CB01000000000000000A0009 /* CreateExerciseView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0009 /* CreateExerciseView.swift */; };
		CB01000000000000000A0010 /* SaveEditScopeSheet.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA01000000000000000A0010 /* SaveEditScopeSheet.swift */; };
```

**Step 2 — PBXFileReference section.** Immediately AFTER project.pbxproj line 139 (the `PlanBodyMap.swift` file-reference entry), insert these 10 lines:
```
		CA01000000000000000A0001 /* MyPlansView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MyPlansView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0002 /* ProgramLibraryView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProgramLibraryView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0003 /* ProgramDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProgramDetailView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0004 /* ProgramEditorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProgramEditorView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0005 /* WorkoutLibraryView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WorkoutLibraryView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0006 /* WorkoutEditorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WorkoutEditorView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0007 /* ExerciseLibraryView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ExerciseLibraryView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0008 /* ExerciseDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ExerciseDetailView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0009 /* CreateExerciseView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CreateExerciseView.swift; sourceTree = "<group>"; };
		CA01000000000000000A0010 /* SaveEditScopeSheet.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SaveEditScopeSheet.swift; sourceTree = "<group>"; };
```
> Note: `path = <bareFileName>.swift` (no directory prefix) because the `Plan` group's `sourceTree` is `"<group>"` and its own `path = Plan` (project.pbxproj line 281). This matches every existing Plan entry. All 10 new files live in `AuraFitness/Plan/`, same folder as the existing Plan group members, so no per-file path prefix is needed.

**Step 3 — `Plan` PBXGroup children.** Inside group `ACGRP060000000000000000A /* Plan */`, immediately AFTER project.pbxproj line 279 (`FF6B6FD2015947908E6EE16B /* PlanBodyMap.swift */,`) and BEFORE the closing `);` on line 280, insert these 10 lines:
```
				CA01000000000000000A0001 /* MyPlansView.swift */,
				CA01000000000000000A0002 /* ProgramLibraryView.swift */,
				CA01000000000000000A0003 /* ProgramDetailView.swift */,
				CA01000000000000000A0004 /* ProgramEditorView.swift */,
				CA01000000000000000A0005 /* WorkoutLibraryView.swift */,
				CA01000000000000000A0006 /* WorkoutEditorView.swift */,
				CA01000000000000000A0007 /* ExerciseLibraryView.swift */,
				CA01000000000000000A0008 /* ExerciseDetailView.swift */,
				CA01000000000000000A0009 /* CreateExerciseView.swift */,
				CA01000000000000000A0010 /* SaveEditScopeSheet.swift */,
```
(Use three-tab indentation to match the existing children on lines 269-279.)

**Step 4 — Sources build phase `files` list.** Immediately AFTER project.pbxproj line 476 (`D1E6081F805C44EA80D37561 /* PlanBodyMap.swift in Sources */,`), insert these 10 lines (four-tab indentation to match neighbors):
```
				CB01000000000000000A0001 /* MyPlansView.swift in Sources */,
				CB01000000000000000A0002 /* ProgramLibraryView.swift in Sources */,
				CB01000000000000000A0003 /* ProgramDetailView.swift in Sources */,
				CB01000000000000000A0004 /* ProgramEditorView.swift in Sources */,
				CB01000000000000000A0005 /* WorkoutLibraryView.swift in Sources */,
				CB01000000000000000A0006 /* WorkoutEditorView.swift in Sources */,
				CB01000000000000000A0007 /* ExerciseLibraryView.swift in Sources */,
				CB01000000000000000A0008 /* ExerciseDetailView.swift in Sources */,
				CB01000000000000000A0009 /* CreateExerciseView.swift in Sources */,
				CB01000000000000000A0010 /* SaveEditScopeSheet.swift in Sources */,
```

**pbxproj validation checklist (do all before finishing):**
- [ ] Exactly 10 new lines added in EACH of the 4 sections (40 lines total). If any section has ≠10, stop.
- [ ] Every `CA0100...` id appears exactly TWICE (PBXFileReference def + one of: group child OR build-file `fileRef=`), and every `CB0100...` id appears exactly TWICE (PBXBuildFile def + Sources phase). Concretely: each `CA` id appears in Step 2 and Step 3 and is referenced by its `CB` twin in Step 1; each `CB` id appears in Step 1 and Step 4.
- [ ] No pre-existing UUID in the file equals any `CA0100...`/`CB0100...` value (they were chosen to avoid the existing `AA..`, `AB..`, `AC..`, `DA..`, and random-hex ids — but grep to confirm).
- [ ] Comment text between `/* */` exactly matches the real filename (e.g. `ExerciseLibraryView.swift`, NOT the struct name `ExerciseLibraryTabView`). Xcode ignores comments but a human reviewer relies on them.
- [ ] Braces/commas balanced; the closing `);` of the Plan group and of the Sources `files` list are still present after your inserts.

## 🗑️ FILES TO DELETE

None in this pass. (See FOLLOW-UP.)

## 🛡️ EDGE CASES TO HANDLE

- **Missing NavigationStack → dead toolbar buttons.** `WorkoutLibraryView` and `ExerciseLibraryTabView` place a `+` button in `.toolbar` and (WorkoutLibraryView) use `.navigationDestination`. If mounted WITHOUT a `NavigationStack`, the `+` and row taps silently no-op. The spec's per-case wrapping in `PlanTabView.body` handles this. Do not add a NavigationStack around `MyPlansView`/`ProgramLibraryView` (they bring their own → double nav bar / stacked title bars).
- **Empty plan state.** `UserPlanDatabase.load()` seeds a default plan from the first `SeedData.programs` entry on first launch, and `ProgramDatabase`/`ExerciseDatabase` seed themselves too — so all four subtabs render real content immediately, and `MyPlansView.defaultPlan` is non-nil. No empty-state crash. If `planDB.plans` is somehow empty, `MyPlansView` still renders (the `if let plan = planDB.defaultPlan` guard simply hides the week strip). No code change needed; just do not assume the list is non-empty anywhere new.
- **`SaveEditScopeSheet` with `onJustToday == nil`.** The only current caller passes `nil`. The sheet MUST conditionally omit the "Just for Today" button (guard `if let onJustToday`), otherwise it would render a button that force-unwraps/does nothing. The "Permanently" and "Cancel" buttons must always render. Sheet must dismiss itself after either action (it owns `@Environment(\.dismiss)`).
- **pbxproj UUID collision / desync (build-breaking, no local Xcode to catch it).** A duplicate UUID or a `fileRef`/`buildID` mismatch corrupts the project and fails CI opaquely. Follow the UUID table verbatim and run the validation checklist. This is the single highest-risk step.
- **Struct-name vs file-name mismatch.** `ExerciseLibraryView.swift` defines `ExerciseLibraryTabView`; `ExerciseDetailView.swift` defines `ExerciseEntryDetailView` (+ legacy `ExerciseDetailView`). In `PlanTabView` reference the STRUCT name `ExerciseLibraryTabView`; in the pbxproj reference the FILE name `ExerciseLibraryView.swift`. Do not conflate them.

## 🔁 FOLLOW-UPS (out of scope — file as separate tickets, do NOT do here)
1. Delete the dead mock mirror files (`PlanModels.swift`, `PlanComponents.swift`, `PlanSubtabViews.swift`, `PlanSheets.swift`, `PlanProgramViews.swift`, `PlanExercisePickerView.swift`, `PlanWorkoutEditorView.swift`, `PlanExerciseDetailView.swift`, `PlanExerciseDetailData.swift`, `PlanBodyMap.swift`) and their pbxproj entries, once `PlanTabView` no longer references `PlanIconButton`/`PlanFilterChip` (extract those two into a small kept file first). Requires a separate compile-verification pass.
2. Make `SaveEditScopeSheet` "Add to My Plans" actually copy the read-only workout into a chosen plan (needs product decision on target plan + `WorkoutEditorView.saveWorkout()` `.view` branch).
