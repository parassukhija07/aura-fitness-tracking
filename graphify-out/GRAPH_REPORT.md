# Graph Report - Aura Fitness Tracker  (2026-07-21)

## Corpus Check
- 163 files · ~297,022 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2135 nodes · 4964 edges · 130 communities (121 shown, 9 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 367 edges (avg confidence: 0.75)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `13b1dad7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Exercise
- .secondary
- WorkoutEditorView
- support.js
- app.jsx
- AuraTab
- Foundation
- UnitFormatter
- .persist
- MyPlansView
- WorkoutSessionState
- LogSheetsView
- String
- AppState
- PlanComponents.swift
- View
- ExerciseDatabase
- ProfileSheet
- PlanDay
- ProgramEditorView
- Workout
- store.jsx
- AuraComponents.swift
- PlanWorkoutEditorView
- .jakarta
- ToastCenter
- .row
- DataImportService
- .scheduleRestComplete
- Color
- .parse
- .importJSONArchive
- SwiftUI
- SupersetView
- QuickLogExercise
- LogSheet
- UserPlanDatabase
- Table
- PlanLibExercise
- PlanEditorExercise
- WorkoutModal
- ExerciseEntryDetailView
- WorkoutExerciseOption
- ToastCenter
- DarkModePreference
- PlanExerciseDetail
- PlanProgramsBody
- tweaks-panel.jsx
- ui.jsx
- .editableLogCard
- AuthService
- .programRow
- DayOverride
- NutritionView
- HealthKitService
- PersistenceRoundTripTests
- IMPLEMENTATION SPEC
- WorkoutEditorComponents.swift
- WeeklyVolumeView
- WorkoutOverviewView
- PlanProgramEditorView
- Aura Fitness — Manual Steps Required
- DayState
- BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage
- BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change
- BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only)
- BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure
- IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker
- IMPLEMENTATION SPEC: YouTube Tap-to-Play + Remote Exercise Images
- AuraColors.swift
- .syncDiff
- ResumeBanner
- CI Build Failure — Root Cause & Fix
- BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection
- IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign
- IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar
- IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming
- IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity
- IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity
- IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources
- IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast
- Aura Fitness Tracker — Audit Report v2 (Fix Verification)
- AuraScreenScroll
- IMPLEMENTATION SPEC
- BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC
- BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit
- BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only
- IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity
- IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate
- IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity
- IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets
- SessionState
- AuraSpacing.swift
- .editableLogCard
- MeasurementsView
- BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup
- IMPLEMENTATION SUMMARY
- IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes
- IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity
- Aura Fitness — Developer Handover
- .editableLogCard
- AuraAxisChart
- Aura Fitness — Remaining Build: Phase Index
- TEST EXECUTION REPORT
- PlanBodyMap
- LogMeasurementSheet
- Foundation
- DataArchive
- IMPLEMENTATION SUMMARY
- FINAL ARCHITECTURE REVIEW
- TEST EXECUTION REPORT
- FINAL ARCHITECTURE REVIEW
- SaveEditScopeSheet
- data.jsx
- EndWorkoutSheet
- AuraToggleStyle
- icons.js
- 00-INDEX.md
- push_changes.sh
- index.ts
- CSVRoundTripTests.swift

## God Nodes (most connected - your core abstractions)
1. `AppState` - 135 edges
2. `Workout` - 76 edges
3. `Exercise` - 69 edges
4. `SwiftUI` - 68 edges
5. `WorkoutSessionState` - 66 edges
6. `Color` - 65 edges
7. `LogSheetsView` - 51 edges
8. `SupabaseSyncService` - 32 edges
9. `WorkoutEditorView` - 31 edges
10. `WorkoutSet` - 30 edges

## Surprising Connections (you probably didn't know these)
- `AuthFormView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `AwaitingConfirmationView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `AuraShadowToken` --calls--> `Color`  [INFERRED]
  AuraFitness/DesignSystem/AuraSpacing.swift → AuraFitness/DesignSystem/AuraColors.swift
- `AccountDetailsView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Profile/AccountDetailsView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `ProfileTabView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Profile/ProfileTabView.swift → AuraFitness/DesignSystem/AuraComponents.swift

## Import Cycles
- None detected.

## Communities (130 total, 9 thin omitted)

### Community 0 - "Exercise"
Cohesion: 0.08
Nodes (38): ActiveWorkoutSeed, ExerciseLoggingView, Bool, Double, Int, String, SetRowView, SetTypeMenuSheet (+30 more)

### Community 1 - ".secondary"
Cohesion: 0.18
Nodes (13): CSVArchiveBuilder, Bool, Date, Double, ExerciseEntry, Int, Measurement, Program (+5 more)

### Community 2 - "WorkoutEditorView"
Cohesion: 0.05
Nodes (39): EditorExercisePicker, EditorPickerMode, addAfter, substitute, supersetNew, Bool, ExerciseEntry, String (+31 more)

### Community 3 - "support.js"
Cohesion: 0.08
Nodes (42): boot(), collectProps(), compileAttr(), compileTemplate(), createComponentFactory(), createExternalModules(), createHelmetManager(), createPseudoSheet() (+34 more)

### Community 4 - "app.jsx"
Cohesion: 0.07
Nodes (45): AddPlanSheet(), App(), AssignSheet(), DayMenuSheet(), ExercisePicker(), ExercisesView(), MyPlansView(), ProgramDetailView() (+37 more)

### Community 5 - "AuraTab"
Cohesion: 0.07
Nodes (31): ContentView, AuraQuickAction, logMeasurement, progressPhoto, startWorkout, AuraTab, log, plan (+23 more)

### Community 6 - "Foundation"
Cohesion: 0.28
Nodes (7): Date, Double, Int, String, WorkoutLog, WeeklyVolumeView, WeekPoint

### Community 7 - "UnitFormatter"
Cohesion: 0.08
Nodes (24): ArraySlice, Double, String, UnitFormatter, MeasurementsView, Date, Double, Int (+16 more)

### Community 8 - ".persist"
Cohesion: 0.16
Nodes (11): programs, workouts, Bool, IndexSet, Int, String, UserPlan, UUID (+3 more)

### Community 9 - "MyPlansView"
Cohesion: 0.12
Nodes (16): CreatePlanView, CreateWorkoutIcon, MyPlanSheet, addPlan, addWorkout, assign, createWorkout, dayMenu (+8 more)

### Community 10 - "WorkoutSessionState"
Cohesion: 0.12
Nodes (10): CelebrationData, Bool, CGPoint, Date, Double, Int, String, WorkoutSessionState (+2 more)

### Community 11 - "LogSheetsView"
Cohesion: 0.14
Nodes (11): LogSheetsView, Bool, Date, ExerciseEntry, PresentationDetent, Program, Set, String (+3 more)

### Community 12 - "String"
Cohesion: 0.06
Nodes (28): Keys, SavedExercise, SavedWorkout, Bool, CGPoint, Date, Int, String (+20 more)

### Community 13 - "AppState"
Cohesion: 0.07
Nodes (18): App, AuraFitnessApp, AppState, DarkModePreference, auto, off, on, RemotePrefs (+10 more)

### Community 14 - "PlanComponents.swift"
Cohesion: 0.13
Nodes (3): ProgramDatabase, Program, ObservableObject

### Community 15 - "View"
Cohesion: 0.33
Nodes (4): ProgramDetailView, Bool, Program, String

### Community 16 - "ExerciseDatabase"
Cohesion: 0.18
Nodes (11): ExerciseDatabase, ExerciseEntry, ExerciseWarmupProtocol, GymExerciseJSON, Bool, Int, String, WarmupProtocolJSON (+3 more)

### Community 17 - "ProfileSheet"
Cohesion: 0.10
Nodes (27): AvatarCircle, fmtRest(), ProfileScreen, account, connected, general, notifications, support (+19 more)

### Community 18 - "PlanDay"
Cohesion: 0.16
Nodes (15): AnyView, PlanLibraryCard, Trailing, IdString, PlanExercisesBody, PlanProgramsBody, PlanWorkoutsBody, ProgFilter (+7 more)

### Community 19 - "ProgramEditorView"
Cohesion: 0.13
Nodes (14): IntBox, Mode, create, edit, ProgramEditorView, Binding, Bool, Int (+6 more)

### Community 20 - "Workout"
Cohesion: 0.13
Nodes (10): SeedData, Program, Workout, Void, WorkoutLibraryPickerView, Int, String, Void (+2 more)

### Community 21 - "store.jsx"
Cohesion: 0.10
Nodes (13): addDays(), DOW, EXERCISES, freshState(), iso(), MONTHS, PROGRAMS, Store (+5 more)

### Community 22 - "AuraComponents.swift"
Cohesion: 0.15
Nodes (25): AuraChip, AuraDangerButton, AuraListRow, AuraPrimaryButton, AuraSectionLabel, AuraSegmentedPicker, AuraSheetModifier, AuraStepper (+17 more)

### Community 23 - "PlanWorkoutEditorView"
Cohesion: 0.21
Nodes (12): exercises, EditorSheet, menu, ssPick, ExDetailRoute, PickerRoute, PlanWorkoutEditorView, CGFloat (+4 more)

### Community 24 - ".jakarta"
Cohesion: 0.17
Nodes (11): AuthService, SessionState, awaitingEmailConfirmation, guest, loading, signedIn, signedOut, Bool (+3 more)

### Community 25 - "ToastCenter"
Cohesion: 0.13
Nodes (18): ToastCenter, ConnectedAppsView, GeneralSettingsView, NotificationsSettingsView, OptionalToast, ProfileConfirmSheet, SettingsScreenScaffold, SupportView (+10 more)

### Community 26 - ".row"
Cohesion: 0.16
Nodes (8): UUID, CSVError, malformed, CSVParser, Int, String, CSVRoundTripTests, Error

### Community 27 - "DataImportService"
Cohesion: 0.28
Nodes (8): DataImportService, Bool, Date, Double, Int, Set, String, UUID

### Community 28 - ".scheduleRestComplete"
Cohesion: 0.16
Nodes (7): NotificationScheduler, Bool, Int, String, RestPillView, CGSize, GeometryProxy

### Community 29 - "Color"
Cohesion: 0.08
Nodes (22): CalendarDayIcon, LogSheet, add, buildFromLibrary, calendar, edit, editLog, logPast (+14 more)

### Community 30 - ".parse"
Cohesion: 0.08
Nodes (41): BodyStats, MacroTargets, Measurement, NutritionConstants, PersonalRecord, ProgressPhoto, Bool, ClosedRange (+33 more)

### Community 31 - ".importJSONArchive"
Cohesion: 0.33
Nodes (10): HistSession, HistSet, PBs, PlanExerciseDetail, planNum(), Double, Int, String (+2 more)

### Community 32 - "SwiftUI"
Cohesion: 0.11
Nodes (10): CelebrationOverlay, CGFloat, WorkoutSummaryView, WorkoutLibraryView, Binding, String, WorkoutSettingsView, BodyView (+2 more)

### Community 33 - "SupersetView"
Cohesion: 0.21
Nodes (8): SupersetSetRow, SupersetView, Binding, Bool, Double, Int, String, Void

### Community 34 - "QuickLogExercise"
Cohesion: 0.09
Nodes (23): CodingKeys, durationMinutes, exercises, time, DayOverride, Kind, added, edited (+15 more)

### Community 35 - "LogSheet"
Cohesion: 0.23
Nodes (10): Int, String, Void, WorkoutModal, addExercise, createSuperset, removeSuperset, substitute (+2 more)

### Community 36 - "UserPlanDatabase"
Cohesion: 0.13
Nodes (14): String, AuraCard, AuraProgressBar, Comparable, ExerciseTrendPicker, StatsView, Bool, ClosedRange (+6 more)

### Community 37 - "Table"
Cohesion: 0.11
Nodes (13): AuraTabBar, LogTabView, Bool, Date, Int, String, PlanScheduleEditorView, Bool (+5 more)

### Community 38 - "PlanLibExercise"
Cohesion: 0.18
Nodes (17): AddRoute, pickWorkout, targetWorkout, PlanExerciseDetailView, PlanHistoryTab, PlanWorkoutCtx, PlanWorkoutTab, Bool (+9 more)

### Community 39 - "PlanEditorExercise"
Cohesion: 0.17
Nodes (13): PlanData, PlanEditorExercise, PlanMusclePalette, PlanProgram, planWkIcon(), planWkStyle(), PlanWorkout, PlanWorkoutStyle (+5 more)

### Community 40 - "WorkoutModal"
Cohesion: 0.25
Nodes (8): ActiveWorkoutData, MuscleGroupOption, String, WorkoutExerciseOption, EmptyOverviewView, Bool, String, Void

### Community 41 - "ExerciseEntryDetailView"
Cohesion: 0.19
Nodes (11): AddToPlanSheet, ExerciseDetailView, ExerciseEntry, ExerciseEntryDetailView, Binding, Bool, ExerciseEntry, Int (+3 more)

### Community 42 - "WorkoutExerciseOption"
Cohesion: 0.23
Nodes (9): NutritionView, Binding, Bool, ClosedRange, Date, Double, Int, String (+1 more)

### Community 43 - "ToastCenter"
Cohesion: 0.18
Nodes (6): DayInfo, Date, PersonalRecord, UUID, WorkoutLog, dayOverrides

### Community 44 - "DarkModePreference"
Cohesion: 0.12
Nodes (16): Keys, PlanSubtabTarget, ProgressDeepLink, measurements, photos, DayState, done, emptyToday (+8 more)

### Community 45 - "PlanExerciseDetail"
Cohesion: 0.17
Nodes (10): AuthFormView, AuthGateView, AwaitingConfirmationView, Mode, login, signUp, Binding, String (+2 more)

### Community 46 - "PlanProgramsBody"
Cohesion: 0.18
Nodes (19): PlanCatalogGrid, PlanEmptyState, PlanFilterChip, PlanIconButton, PlanList, PlanNavbar, PlanRow, PlanSearchField (+11 more)

### Community 48 - "ui.jsx"
Cohesion: 0.21
Nodes (8): Icon(), Nav, NavBar(), Row(), Search(), Sheet(), TabBar(), useNav()

### Community 49 - ".editableLogCard"
Cohesion: 0.20
Nodes (10): Coordinator, ExerciseVideoView, Bool, CGFloat, String, YouTubePlayerView, Context, UIViewRepresentable (+2 more)

### Community 50 - "AuthService"
Cohesion: 0.19
Nodes (9): SupersetPickSheet, String, Void, AccountDetailsView, Binding, Date, Double, String (+1 more)

### Community 51 - ".programRow"
Cohesion: 0.19
Nodes (8): AuraBadge, ExerciseLibraryTabView, ExerciseEntry, String, ProgramLibraryView, Bool, Program, String

### Community 52 - "DayOverride"
Cohesion: 0.12
Nodes (23): AnyJSON, QueueAction, delete, upsert, QueueOp, RemoteRow, SupabaseSyncService, Date (+15 more)

### Community 53 - "NutritionView"
Cohesion: 0.17
Nodes (12): Col, ImportSummary, MinimalZipReader, Data, URL, ZipError, malformed, unsupportedCompression (+4 more)

### Community 54 - "HealthKitService"
Cohesion: 0.18
Nodes (8): HealthKitService, Bool, Date, Double, Int, HealthKit, HKObjectType, HKQuantityType

### Community 55 - "PersistenceRoundTripTests"
Cohesion: 0.22
Nodes (5): PersistenceRoundTripTests, String, T, UserDefaults, XCTestCase

### Community 56 - "IMPLEMENTATION SPEC"
Cohesion: 0.14
Nodes (13): 🏗️ ARCHITECTURE & PATTERNS, ASSUMPTIONS (defaults chosen — safe to proceed), `AuraFitness/Plan/PlanTabView.swift`, `AuraFitness/Plan/SaveEditScopeSheet.swift`, `AuraFitness.xcodeproj/project.pbxproj`  — register 10 files (9 orphans + `SaveEditScopeSheet.swift`), 🛡️ EDGE CASES TO HANDLE, 📄 FILES TO CREATE, 🗑️ FILES TO DELETE (+5 more)

### Community 57 - "WorkoutEditorComponents.swift"
Cohesion: 0.29
Nodes (10): ExerciseEditCard, ExerciseEditMenuSheet, nearestLadderIndex(), restLabel(), RestLadderPicker, SupersetConnector, Bool, Int (+2 more)

### Community 59 - "WorkoutOverviewView"
Cohesion: 0.23
Nodes (10): ExerciseMenuSheet, ExercisePickerSheet, IndexWrapper, Bool, Double, Int, String, Void (+2 more)

### Community 60 - "PlanProgramEditorView"
Cohesion: 0.24
Nodes (9): AddMode, library, pick, PlanProgramDetailView, PlanProgramEditorView, Bool, Int, String (+1 more)

### Community 61 - "Aura Fitness — Manual Steps Required"
Cohesion: 0.17
Nodes (11): Aura Fitness — Manual Steps Required, Quick checklist, Step 1 — Create the Supabase project (≈10 min), Step 2 — Apply the database schema (≈5 min), Step 3 — Wire the secrets into Xcode (≈10 min, needs your Mac), Step 4 — Deploy the delete-account Edge Function (≈5 min, needs Supabase CLI), Step 5 — Add the HealthKit capability in Xcode (≈3 min), Step 6 — Bundle the exercise library JSON (≈2 min) (+3 more)

### Community 62 - "DayState"
Cohesion: 0.29
Nodes (4): AuraFont, CGFloat, Font, String

### Community 63 - "BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ProgressModels.swift` + photo store (where `progressPhotos` persists in `AppState`), `AuraFitness/Progress/ProgressPhotosView.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS (+2 more)

### Community 64 - "BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change"
Cohesion: 0.18
Nodes (10): `AuraFitness/AuraFitnessApp.swift`, `AuraFitness/Auth/AuthGateView.swift`, `AuraFitness/Auth/AuthService.swift`, `AuraFitness/Profile/AccountDetailsView.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change, 📄 FILES TO CREATE, 📝 FILES TO MODIFY (+2 more)

### Community 65 - "BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only)"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only), 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0007_exercise_catalog.sql` (+2 more)

### Community 66 - "BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ExerciseDatabase.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0008_exercise_media_bucket.sql`, `supabase/seed/exercise-media/README.md` (+2 more)

### Community 67 - "IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker"
Cohesion: 0.18
Nodes (10): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/EditorExercisePicker.swift`, `AuraFitness/Plan/SupersetPickSheet.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker (+2 more)

### Community 68 - "IMPLEMENTATION SPEC: YouTube Tap-to-Play + Remote Exercise Images"
Cohesion: 0.18
Nodes (10): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift`, `AuraFitness/DesignSystem/RemoteExerciseImage.swift`, `AuraFitness/Plan/ExerciseDetailView.swift`, `AuraFitness/Plan/PlanSubtabViews.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY (+2 more)

### Community 69 - "AuraColors.swift"
Cohesion: 0.44
Nodes (7): AuraColorNamespace, Color, dyn(), dynA(), CGFloat, String, UIColor

### Community 70 - ".syncDiff"
Cohesion: 0.27
Nodes (8): PickerMode, add, ssNew, sub, PlanExercisePickerView, Bool, String, Void

### Community 72 - "CI Build Failure — Root Cause & Fix"
Cohesion: 0.20
Nodes (9): 1. `LogDayModel.swift` / `ResumeBanner.swift` shared the same UUID in `project.pbxproj`, 1. Push and re-run CI (no local action needed beyond that), 2. HealthKit capability (carried over from the earlier audit-fix session, still open), 2. Xcode 15.4's compiler can't build `xctest-dynamic-overlay` (a transitive dependency), 3. Nothing else is currently known to block CI, CI Build Failure — Root Cause & Fix, What broke it, What's committed (+1 more)

### Community 73 - "BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection"
Cohesion: 0.20
Nodes (9): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0002_pull_changes_rpc.sql`, `supabase/migrations/0003_deletions_tombstones.sql` (+1 more)

### Community 74 - "IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/WorkoutEditorComponents.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign, ⚠️ OPEN QUESTIONS (+1 more)

### Community 75 - "IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ExerciseDetailView.swift` (struct `ExerciseEntryDetailView`), `AuraFitness/Plan/PlanTabView.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar (+1 more)

### Community 76 - "IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/MyPlansView.swift`, `AuraFitness/Plan/PlanComponents.swift`, `AuraFitness/Plan/PlanSubtabViews.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming (+1 more)

### Community 77 - "IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/DesignSystem/AuraComponents.swift` — ADD `AuraAxisChart`, `AuraFitness/Progress/PersonalRecordsView.swift`, `AuraFitness/Progress/StatsView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity (+1 more)

### Community 78 - "IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/ProfileSettingsScreens.swift` (General, Notifications), `AuraFitness/Profile/ProfileTabView.swift` (root hub), `AuraFitness/Profile/WorkoutSettingsView.swift` (Workout), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity (+1 more)

### Community 79 - "IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness.xcodeproj/project.pbxproj`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, `gym_exercise_library.json` → move to `AuraFitness/Resources/gym_exercise_library.json`, IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources (+1 more)

### Community 80 - "IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ProgramEditorView.swift` (audit L5) — and any other `deleteProgram` call site, `AuraFitness/Progress/ConsistencyHeatmapView.swift` + `AuraFitness/Log/LogSheetsView.swift` (audit L8), Dead-code candidates (verify each, then delete file + pbxproj entries), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast (+1 more)

### Community 81 - "Aura Fitness Tracker — Audit Report v2 (Fix Verification)"
Cohesion: 0.22
Nodes (8): Aura Fitness Tracker — Audit Report v2 (Fix Verification), CI / GitHub Actions status, Critical, High, Low, Medium, New findings (this verification pass), Recommended fix order for what remains

### Community 82 - "AuraScreenScroll"
Cohesion: 0.28
Nodes (6): AuraScreenScroll, ScrollOffsetKey, CGFloat, Content, String, PreferenceKey

### Community 83 - "IMPLEMENTATION SPEC"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, 🛡️ EDGE CASES TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC, ⚠️ OPEN QUESTIONS, `path/to/existing/file.js`, `path/to/new/file.js`

### Community 84 - "BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC"
Cohesion: 0.22
Nodes (8): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0002_pull_changes_rpc.sql`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 85 - "BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit"
Cohesion: 0.22
Nodes (8): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0005_payload_guardrails.sql`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 86 - "BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only"
Cohesion: 0.22
Nodes (8): `AuraFitness/Models/ProgramDatabase.swift` + `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 87 - "IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ProgramDetailView.swift`, `AuraFitness/Plan/ProgramEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity, ⚠️ OPEN QUESTIONS

### Community 88 - "IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/ProfileSettingsScreens.swift`, `AuraFitness/Progress/StatsView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate, ⚠️ OPEN QUESTIONS

### Community 89 - "IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/MeasurementsView.swift`, `AuraFitness/Progress/ProgressPhotosView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity, ⚠️ OPEN QUESTIONS

### Community 90 - "IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/AccountDetailsView.swift`, `AuraFitness/Profile/ProfileSettingsScreens.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets, ⚠️ OPEN QUESTIONS

### Community 92 - "SessionState"
Cohesion: 0.40
Nodes (5): ActiveWorkoutScreen, exercise, overview, summary, superset

### Community 93 - "AuraSpacing.swift"
Cohesion: 0.36
Nodes (5): AuraRadius, AuraShadowToken, AuraSpacing, CGFloat, View

### Community 94 - ".editableLogCard"
Cohesion: 0.29
Nodes (5): Face, SectionLabelStyle, Content, View, View

### Community 95 - "MeasurementsView"
Cohesion: 0.10
Nodes (18): PlanDay, fri, mon, sat, sun, thu, tue, wed (+10 more)

### Community 96 - "BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup"
Cohesion: 0.25
Nodes (7): 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/functions/delete-account/index.ts`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 97 - "IMPLEMENTATION SUMMARY"
Cohesion: 0.25
Nodes (7): ⚠️ DEVIATION FROM SPEC (coordinator-approved), IMPLEMENTATION SUMMARY, 📁 MODIFIED FILES, 🆕 NEW FILES, ✅ PBXPROJ VALIDATION CHECKLIST — ALL PASSED, 🎯 TESTER FOCUS AREAS, 🔄 WHAT CHANGED

### Community 98 - "IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes"
Cohesion: 0.25
Nodes (7): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/ConsistencyHeatmapView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes, ⚠️ OPEN QUESTIONS

### Community 99 - "IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity"
Cohesion: 0.25
Nodes (7): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/NutritionView.swift` (and the `NutritionConstants` definition file), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity, ⚠️ OPEN QUESTIONS

### Community 101 - "Aura Fitness — Developer Handover"
Cohesion: 0.29
Nodes (6): Aura Fitness — Developer Handover, Chapters, Fidelity, How to use this, Source files (in `../`), Target stack notes

### Community 102 - ".editableLogCard"
Cohesion: 0.36
Nodes (3): Binding, Int, View

### Community 103 - "AuraAxisChart"
Cohesion: 0.60
Nodes (4): AuraAxisChart, AuraLineChart, CGFloat, Double

### Community 104 - "Aura Fitness — Remaining Build: Phase Index"
Cohesion: 0.29
Nodes (6): Aura Fitness — Remaining Build: Phase Index, Out of scope for specs (owner-manual steps, from `MANUAL_STEPS.md`), Phase 3 — Plan tab completion (design ch. 4, largest chapter), Phase 4 — Progress tab fidelity (design ch. 6), Phase 5 — Profile tab fidelity (design ch. 7), Phase 6 — Data & platform completion

### Community 105 - "TEST EXECUTION REPORT"
Cohesion: 0.29
Nodes (6): 🛑 BLOCKERS (If Failed), 📝 EXECUTION LOG, Notes (non-blocking, informational only), 📊 STATUS, TEST EXECUTION REPORT, 🧪 TESTS IMPLEMENTED

### Community 106 - "PlanBodyMap"
Cohesion: 0.40
Nodes (4): PlanBodyMap, CGFloat, Double, String

### Community 107 - "LogMeasurementSheet"
Cohesion: 0.40
Nodes (3): LogMeasurementSheet, Binding, String

### Community 108 - "Foundation"
Cohesion: 0.14
Nodes (12): DataArchive, DataArchiveBuilder, Date, ExerciseEntry, Measurement, PersonalRecord, Program, ProgressPhoto (+4 more)

### Community 109 - "DataArchive"
Cohesion: 0.53
Nodes (3): ExerciseDropDelegate, Bool, DropInfo

### Community 110 - "IMPLEMENTATION SUMMARY"
Cohesion: 0.33
Nodes (5): IMPLEMENTATION SUMMARY, 📁 MODIFIED FILES, 🆕 NEW FILES, 🎯 TESTER FOCUS AREAS, 🔄 WHAT CHANGED

### Community 111 - "FINAL ARCHITECTURE REVIEW"
Cohesion: 0.33
Nodes (5): 🛠️ ACTION ITEMS (If NEEDS WORK or BLOCK), 🔍 DIFF ANALYSIS, FINAL ARCHITECTURE REVIEW, 🛡️ QUALITY & SECURITY AUDIT, ⚖️ VERDICT

### Community 112 - "TEST EXECUTION REPORT"
Cohesion: 0.33
Nodes (5): 🛑 BLOCKERS (If Failed), 📝 EXECUTION LOG, 📊 STATUS, TEST EXECUTION REPORT, 🧪 TESTS IMPLEMENTED

### Community 113 - "FINAL ARCHITECTURE REVIEW"
Cohesion: 0.33
Nodes (5): 🛠️ ACTION ITEMS, 🔍 DIFF ANALYSIS, FINAL ARCHITECTURE REVIEW, 🛡️ QUALITY & SECURITY AUDIT, ⚖️ VERDICT

### Community 115 - "data.jsx"
Cohesion: 0.40
Nodes (4): ADD_OPTIONS, SET_TYPES, SUB_OPTIONS, WORKOUT

### Community 117 - "EndWorkoutSheet"
Cohesion: 0.50
Nodes (3): ActiveWorkoutView, EndWorkoutSheet, Bool

### Community 118 - "AuraToggleStyle"
Cohesion: 0.50
Nodes (3): AuraToggleStyle, Configuration, ToggleStyle

## Knowledge Gaps
- **387 isolated node(s):** `TODAY`, `DOW`, `MONTHS`, `EXERCISES`, `WORKOUTS` (+382 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppState` connect `AppState` to `Exercise`, `.secondary`, `AuraTab`, `Foundation`, `UnitFormatter`, `MyPlansView`, `WorkoutSessionState`, `LogSheetsView`, `String`, `PlanComponents.swift`, `View`, `ExerciseDatabase`, `ProfileSheet`, `ProgramEditorView`, `ToastCenter`, `.row`, `DataImportService`, `.parse`, `SwiftUI`, `SupersetView`, `QuickLogExercise`, `UserPlanDatabase`, `Table`, `PlanLibExercise`, `WorkoutModal`, `ExerciseEntryDetailView`, `WorkoutExerciseOption`, `ToastCenter`, `DarkModePreference`, `AuthService`, `.programRow`, `DayOverride`, `NutritionView`, `HealthKitService`, `WeeklyVolumeView`, `WorkoutOverviewView`, `MeasurementsView`, `LogMeasurementSheet`, `Foundation`, `EndWorkoutSheet`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `Workout` connect `Workout` to `Exercise`, `WorkoutEditorView`, `.persist`, `MyPlansView`, `WorkoutSessionState`, `LogSheetsView`, `String`, `AppState`, `PlanComponents.swift`, `PlanDay`, `ProgramEditorView`, `.row`, `DataImportService`, `.parse`, `SwiftUI`, `UserPlanDatabase`, `Table`, `PlanEditorExercise`, `ExerciseEntryDetailView`, `ToastCenter`, `DayOverride`, `MeasurementsView`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Why does `WorkoutSessionState` connect `WorkoutSessionState` to `SwiftUI`, `Exercise`, `SupersetView`, `LogSheet`, `WorkoutModal`, `ToastCenter`, `AppState`, `PlanComponents.swift`, `SessionState`, `Workout`, `EndWorkoutSheet`, `WorkoutOverviewView`, `.scheduleRestComplete`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `AppState` (e.g. with `.confirmBuildFromLibrary()` and `.loadForm()`) actually correct?**
  _`AppState` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `Workout` (e.g. with `.importCustomWorkouts()` and `.importPrograms()`) actually correct?**
  _`Workout` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `Exercise` (e.g. with `.importCustomWorkouts()` and `.importPrograms()`) actually correct?**
  _`Exercise` has 5 INFERRED edges - model-reasoned connections that need verification._
- **What connects `TODAY`, `DOW`, `MONTHS` to the rest of the system?**
  _387 weakly-connected nodes found - possible documentation gaps or missing edges._