# IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast

## ⚠️ OPEN QUESTIONS
None. Deletion is evidence-gated: a file is deleted ONLY when the reference-check procedure below proves it unreferenced. If any listed file turns out to be referenced, it is kept and reported instead.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Plan tab was originally built as a mock-data prototype mirror; a real DB-backed layer has since replaced it (`PlanTabView` now mounts `MyPlansView` / `PlanProgramsBody` / `PlanWorkoutsBody` / `PlanExercisesBody`). Several legacy mock files likely remain compiled-but-unreferenced. Separately, two audit leftovers need fixing: duplicate day-letter `ForEach(id: \.self)` rows (finding L8) and a silent no-op when deleting predefined programs (finding L5).
- **Existing Patterns to Match:**
  - `AuraFitness.xcodeproj/project.pbxproj` — file DE-registration mirrors registration: remove the file's `PBXBuildFile`, `PBXFileReference`, group child, and Sources-phase entries (all 4 places, matching UUIDs).
  - Reference-check procedure (run per candidate symbol): `grep -rn "<TypeName>" AuraFitness/ --include="*.swift"` — a type is DEAD only when its only occurrences are inside its own definition file. Check EVERY public type in a candidate file before deleting the file.
- **Core Strategy:** Three independent cleanups in one pass: (1) verified deletion of dead mock Plan files + their pbxproj entries; (2) ForEach id hygiene; (3) delete-program feedback toast.

## 📝 FILES TO MODIFY
### Dead-code candidates (verify each, then delete file + pbxproj entries)
Candidates in `AuraFitness/Plan/`: `PlanModels.swift`, `PlanSheets.swift`, `PlanProgramViews.swift`, `PlanWorkoutEditorView.swift`, `PlanExerciseDetailView.swift`, `PlanExercisePickerView.swift`, `PlanExerciseDetailData.swift`, `PlanBodyMap.swift`.
- ⚠️ KNOWN LIVE (do NOT delete): `PlanComponents.swift` (defines `PlanIconButton`/`PlanFilterChip` used by `PlanTabView.navbar`, plus the `workoutTheme` helper if feature 03-05 landed) and `PlanSubtabViews.swift` (the live subtab bodies).
- ⚠️ `PlanBodyMap.swift` / `PlanExerciseDetailData.swift` may be referenced by the live `ExerciseEntryDetailView` (muscle-activation body map + curated activation data) — the most likely FALSE positives; check `ExerciseDetailView.swift` references before judging.
- For each file whose every type is proven dead: `git rm` the file AND remove its 4 pbxproj entry classes. After ALL deletions: every remaining `.swift` file passes `swiftc -parse`, and grep the pbxproj to confirm no entry references a deleted filename.
### `AuraFitness/Progress/ConsistencyHeatmapView.swift` + `AuraFitness/Log/LogSheetsView.swift` (audit L8)
- Locate static day-letter header rows using `ForEach(["S","M","T","W","T","F","S"], id: \.self)` (duplicate "S"/"T" elements collide). Replace with `ForEach(Array(labels.enumerated()), id: \.offset)`. (Skip the heatmap file if feature 04-01 already fixed it — verify first.)
### `AuraFitness/Plan/ProgramEditorView.swift` (audit L5) — and any other `deleteProgram` call site
- `ProgramDatabase.deleteProgram` returns `Bool` (false for predefined programs). Find every call site discarding the result (`grep -rn "deleteProgram" AuraFitness/`). On `false`, show feedback: an alert or toast with copy "Predefined programs can't be deleted. Add it to My Plans to customise it." — use the codebase's existing toast/flash pattern if one exists, else a standard `.alert`.

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- pbxproj integrity after deletions: balanced braces/parens, no orphaned UUID references — grep each removed UUID to confirm 0 remaining occurrences.
- A candidate file with ONE live type and the rest dead: keep the file; optionally strip only clearly-dead private types — do not split files in this pass.
- Do NOT touch `SaveEditScopeSheet.swift`, `MyPlansView.swift`, `ProgramLibraryView.swift`, `WorkoutLibraryView.swift`, `ExerciseLibraryView.swift`, `ProgramDetailView.swift`, `ProgramEditorView.swift` (except the L5 toast), `WorkoutEditorView.swift`, `CreateExerciseView.swift`, `ExerciseDetailView.swift` — all live.
- Commit deletions as their own commit separate from the L8/L5 fixes so a revert is surgical.
