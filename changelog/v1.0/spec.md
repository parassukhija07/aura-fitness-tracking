# IMPLEMENTATION SPEC

## ⚠️ OPEN QUESTIONS
None.

## 🏗️ ARCHITECTURE & PATTERNS

- **Existing Patterns to Match:** `.pipeline/design_extract/styles/aura.css` (design tokens), `.pipeline/design_extract/workout/data.jsx` (data model), `.pipeline/design_extract/combined/log.jsx` (Log tab behavior), `.pipeline/design_extract/workout/app.jsx` (Active Workout flow), `.pipeline/design_extract/handoff/README.md` (complete screen inventory)
- **Core Strategy:** Build a native SwiftUI iOS app (iOS 17+) with 4 tabs (Log, Plan, Progress, Profile) plus a full-screen Active Workout overlay. Use SwiftData for persistence. Map every design token from `aura.css` to a Swift `Color`/`CGFloat` extension. Recreate all 26 screens faithfully from the design reference. The Active Workout flow is the hero feature and must implement all interactions specified in the handoff README exactly.

---

## 📄 FILES TO CREATE

### Project Structure
```
AuraFitness/
├── AuraFitnessApp.swift
├── ContentView.swift
├── DesignSystem/
│   ├── AuraColors.swift
│   ├── AuraTypography.swift
│   ├── AuraSpacing.swift
│   └── AuraComponents.swift
├── Models/
│   ├── AppState.swift
│   ├── WorkoutModels.swift
│   ├── SeedData.swift
│   └── ProgressModels.swift
├── Log/
│   ├── LogTabView.swift
│   ├── WeekBarView.swift
│   ├── PlannedWorkoutCardView.swift
│   ├── RestDayView.swift
│   ├── EmptyDayView.swift
│   ├── CalendarSheetView.swift
│   ├── AddWorkoutSourceSheet.swift
│   ├── SwitchWorkoutSheet.swift
│   └── LogPastWorkoutSheet.swift
├── ActiveWorkout/
│   ├── ActiveWorkoutView.swift
│   ├── WorkoutOverviewView.swift
│   ├── ExerciseLoggingView.swift
│   ├── SupersetView.swift
│   ├── WorkoutSummaryView.swift
│   ├── RestPillView.swift
│   ├── CelebrationOverlay.swift
│   ├── SetRowView.swift
│   └── WorkoutSessionState.swift
├── Plan/
│   ├── PlanTabView.swift
│   ├── MyPlansView.swift
│   ├── ProgramLibraryView.swift
│   ├── ProgramDetailView.swift
│   ├── WorkoutLibraryView.swift
│   ├── WorkoutEditorView.swift
│   ├── ExerciseLibraryView.swift
│   ├── ExerciseDetailView.swift
│   ├── CreateExerciseView.swift
│   └── SaveEditScopeSheet.swift
├── Progress/
│   ├── ProgressTabView.swift
│   ├── StatsView.swift
│   ├── ConsistencyHeatmapView.swift
│   ├── PersonalRecordsView.swift
│   ├── BodyView.swift
│   ├── MeasurementsView.swift
│   ├── LogMeasurementSheet.swift
│   ├── ProgressPhotosView.swift
│   └── NutritionView.swift
└── Profile/
    ├── ProfileTabView.swift
    ├── WorkoutSettingsView.swift
    ├── AccountDetailsView.swift
    └── PreferencesView.swift
```

---

## 🎨 DESIGN TOKENS — `AuraColors.swift`

Define a `Color` extension with `.aura` namespace. Light/dark adaptive via `UIColor(dynamicProvider:)`:

| Swift name | Light hex | Dark hex |
|---|---|---|
| `.aura.accent` | `#E07A1F` | `#F59331` |
| `.aura.accentSoft` | accent @ 12% | accent @ 18% |
| `.aura.green` | `#2DA66A` | `#2DA66A` |
| `.aura.red` | `#D8432E` | `#D8432E` |
| `.aura.blue` | `#3E83D4` | `#3E83D4` |
| `.aura.purple` | `#9354C9` | `#9354C9` |
| `.aura.bg` | `#FCFBFA` | `#1E1C1A` |
| `.aura.bgGrouped` | `#F5F3F1` | `#181614` |
| `.aura.surface` | `#FFFFFF` | `#2A2724` |
| `.aura.surface2` | `#F8F7F6` | `#302D2A` |
| `.aura.text` | `#2E2A26` | `#F7F5F3` |
| `.aura.text2` | `#7C746C` | `#AEA89F` |
| `.aura.text3` | `#A39A91` | `#706860` |
| `.aura.separator` | `#E5E2DF` | `#4A4540` |
| `.aura.fill` | text @ 12% opacity | text @ 16% opacity |
| `.aura.track` | `#DED9D4` | `#3D3833` |

### `AuraSpacing.swift`
```swift
enum AuraRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}
enum AuraSpacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40
    static let screenPad: CGFloat = 20
}
```

### `AuraTypography.swift`
Use system font (SF Pro) with these weights/sizes:
```swift
enum AuraFont {
    static func largeTitleStyle() -> Font { .system(size: 30, weight: .heavy, design: .default) }
    static func navTitle() -> Font { .system(size: 17, weight: .bold) }
    static func cardTitle() -> Font { .system(size: 22, weight: .heavy) }
    static func body() -> Font { .system(size: 16, weight: .medium) }
    static func secondary() -> Font { .system(size: 13, weight: .medium) }
    static func sectionLabel() -> Font { .system(size: 13, weight: .bold) }
    static func statNum(size: CGFloat = 24) -> Font { .system(size: size, weight: .heavy, design: .default).monospacedDigit() }
}
```

### `AuraComponents.swift` — shared views to implement:
- `AuraCard` — white/surface bg, r-lg, shadow-sm, border separator-2
- `AuraPrimaryButton(label:icon:action:)` — accent bg, white text, full width, 15pt h
- `AuraTintedButton` — accentSoft bg, accent text
- `AuraGrayButton` — fill bg, text color
- `AuraDangerButton` — red @ 14% bg, red text
- `AuraChip(label:active:)` — pill shape, fill/accent bg
- `AuraSegmentedPicker` — fill bg, surface active tab, shadow-sm
- `AuraBadge(label:color:)` — pill, 12pt bold
- `AuraSectionLabel` — uppercase, 13pt bold, text3 color, 22pt top margin
- `AuraSheet` — bottom sheet with grabber, scrim, r-28 top corners
- `AuraProgressBar(value:)` — 8pt height, accent fill, track bg
- `AuraToggle` — 51×31 pill, green when on, white thumb
- `AuraListRow` — 48pt min height, icon cell, title, subtitle, chevron

---

## 🗂️ DATA MODELS — `WorkoutModels.swift`

```swift
// SetType
enum SetType: String, CaseIterable, Codable {
    case normal, drop, restPause, failure, partials
    var label: String
    var shortLabel: String  // "", "D", "R", "F", "P"
    var color: Color        // text2, purple, blue, red, green
}

// WorkoutSet
struct WorkoutSet: Identifiable, Codable {
    var id = UUID()
    var weight: Double?     // nil = empty
    var reps: Int?          // nil = empty
    var done: Bool = false
    var type: SetType = .normal
    var note: String = ""
}

// WarmupSet
struct WarmupSet: Codable {
    var reps: Int
    var label: String
}

// PRRecord
struct PRRecord: Codable {
    var weight: Double; var reps: Int; var date: String
}

// TargetRecord  
struct TargetRecord: Codable {
    var weight: Double; var reps: Int; var note: String
}

// Exercise (library item + in-workout item)
struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var primaryMuscle: String
    var muscleGroups: [String]
    var equipment: String
    var difficulty: String
    var isCable: Bool
    var pulley: String = "single"   // "single" | "double"
    var repRange: String = "8–12"
    var plannedSets: Int = 3
    var lastPR: PRRecord?
    var target: TargetRecord?
    var warmup: [WarmupSet] = []
    var hint: String = ""
    var imageURL: String?
    var youtubeURL: String?
    var sets: [WorkoutSet] = []
    var completed: Bool = false
    var superset: Bool = false
    var note: String = ""
}

// Workout
struct Workout: Identifiable, Codable {
    var id = UUID()
    var name: String
    var primaryMuscles: String
    var estimatedMinutes: Int
    var exercises: [Exercise]
}

// Program
struct Program: Identifiable, Codable {
    var id = UUID()
    var name: String
    var daysPerWeek: Int
    var level: String
    var style: String
    var description: String
    var workouts: [Workout]
    var isPredefined: Bool = true
}

// UserPlan
struct UserPlan: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isDefault: Bool = false
    var sourceProgramID: UUID?
    var weekSchedule: [Int: UUID?] = [:]  // 0=Sun..6=Sat → Workout.id
    var customWorkouts: [Workout] = []
}
```

### `ProgressModels.swift`
```swift
struct WorkoutLog: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var workoutName: String
    var exercises: [Exercise]
    var durationSeconds: Int
    var sessionNotes: String = ""
}

struct Measurement: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var weight: Double?
    var bodyFatPct: Double?
    var neck, chest, waist, hips, arms, thighs, shoulders: Double?
}

struct BodyStats: Codable {
    var height: Double      // cm
    var weight: Double
    var age: Int
    var sex: String         // "Male" | "Female"
    var activityLevel: String
    var targetWeight: Double?
    var goalType: String    // "loseFat" | "leanGain" | "gainMuscle" | "maintain"
    var macroSplit: String  // "balanced" | "highCarb" | "highProtein" | "keto"
}

struct PersonalRecord: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var muscle: String
    var weight: Double
    var reps: Int
    var date: Date
    var estimated1RM: Double   // Epley formula: w * (1 + r/30)
}
```

### `AppState.swift`
```swift
@MainActor
class AppState: ObservableObject {
    @Published var darkModePreference: DarkModePreference = .auto  // off/auto/on
    @Published var calendarStartDay: Int = 0        // 0=Sun, 1=Mon
    @Published var logDisplayMode: String = "Both"  // "Strength Score" | "Strength Balance" | "Both"
    @Published var activeWorkoutSession: WorkoutSessionState? = nil
    @Published var userPlans: [UserPlan] = []
    @Published var workoutLogs: [WorkoutLog] = []
    @Published var measurements: [Measurement] = []
    @Published var bodyStats: BodyStats = BodyStats(...)
    @Published var personalRecords: [PersonalRecord] = []
    @Published var userProfile: UserProfile = UserProfile(...)
    
    // Workout preferences
    @Published var defaultSets: Int = 3
    @Published var defaultRepRange: String = "6–10"
    @Published var defaultRestBetweenSets: Int = 60
    @Published var defaultRestBetweenExercises: Int = 90
    @Published var autoRestTimer: Bool = true
    @Published var autoPlayVideo: Bool = false
    @Published var showPRsDuringWorkout: Bool = true
    @Published var showRepsFirst: Bool = true
    @Published var weightUnit: String = "kg"
    @Published var lengthUnit: String = "cm"
    
    var defaultPlan: UserPlan? { userPlans.first(where: { $0.isDefault }) }
}
```

---

## 🌱 SEED DATA — `SeedData.swift`

Seed these programs with full exercise lists (minimum 8 exercises per workout):

1. **Push · Pull · Legs** (PPL, 6-day, Intermediate)
   - Push Day A: Barbell Bench Press, Incline DB Press, Cable Fly, Seated Shoulder Press, Cable Lateral Raise, Triceps Rope Pushdown
   - Pull Day A: Barbell Row, Pull-Ups, Seated Cable Row, Face Pulls, Barbell Curl
   - Leg Day A: Barbell Squat, Romanian Deadlift, Leg Press, Leg Curl, Leg Extension, Calf Raises
   - Push Day B: Overhead Press, DB Lateral Raise, Incline DB Press, Cable Lateral Raise, Skull Crushers, Tricep Dips
   - Pull Day B: Deadlift, Weighted Pull-Ups, Seated Cable Row, Face Pulls, Hammer Curl
   - Leg Day B: Front Squat, Sumo Deadlift, Walking Lunges, Leg Press, Seated Calf Raise

2. **StrongLifts 5×5** (3-day, Beginner)
3. **Upper / Lower** (4-day, Intermediate)
4. **Full Body 3x** (3-day, Beginner)
5. **HIIT Cardio** (3-day)

Seed exercise library with 80+ exercises across all muscle groups and equipment types. For each exercise include: name, primaryMuscle, muscleGroups, equipment, difficulty, isCable, repRange, hint (form tip), warmup sets (for compound exercises).

---

## 🏃 ACTIVE WORKOUT — Critical Interaction Rules

Implement in `WorkoutSessionState.swift`:

```swift
func onSetCompleted(exerciseIndex ei: Int, setIndex si: Int) {
    let ex = workout.exercises[ei]
    // Auto-complete check (weight + reps filled)
    workout.exercises[ei].sets[si].done = true
    
    // Celebration
    if let w = ex.sets[si].weight, let pr = ex.lastPR, w > pr.weight {
        triggerCelebration(emoji: "🏆", title: "New PR!", message: "\(w) kg beats your \(pr.weight) kg best.")
    } else if let r = ex.sets[si].reps, let t = ex.target, r > t.reps,
              let w = ex.sets[si].weight, w >= t.weight {
        triggerCelebration(emoji: "🔥", title: "Extra reps!", message: "\(r) reps — above today's target.")
    }
    
    // Rest timer — NOT after final set
    if si < ex.sets.count - 1 {
        startRest(duration: TimeInterval(appState.defaultRestBetweenSets))
    }
}

func onAddSet(to exerciseIndex: Int) {
    workout.exercises[exerciseIndex].sets.append(WorkoutSet())
    startRest(duration: TimeInterval(appState.defaultRestBetweenSets))
}

func onCompleteExercise(at exerciseIndex: Int) {
    // Strip empty sets
    workout.exercises[exerciseIndex].sets.removeAll { s in
        s.weight == nil && s.reps == nil && !s.done
    }
    // Mark remaining filled sets done
    for i in workout.exercises[exerciseIndex].sets.indices {
        let s = workout.exercises[exerciseIndex].sets[i]
        if s.weight != nil && s.reps != nil { workout.exercises[exerciseIndex].sets[i].done = true }
    }
    workout.exercises[exerciseIndex].completed = true
    
    let doneSets = workout.exercises[exerciseIndex].sets.filter { $0.done }.count
    triggerCelebration(emoji: "💪", title: "Exercise done",
        message: "\(doneSets) solid sets logged. On to the next.")
    startRest(duration: 90)
    activeView = .overview
}
```

### Rest Pill — `RestPillView.swift`
```swift
// Use .gesture(DragGesture()) to update pillPosition in WorkoutSessionState
// Clamp: x in 8...(screenWidth - 200), y in 60...(screenHeight - 70)
// Show: ring (conic gradient), REST label, mm:ss countdown, +15s button, pause/play, dismiss X
```

### Auto-finish set (in `SetRowView.swift`)
```swift
// When weight TextField loses focus (onSubmit or .onChange):
//   if weight != nil && reps != nil { sessionState.onSetCompleted(...) }
```

---

## 🛡️ EDGE CASES TO HANDLE

1. **Draft state isolation:** All in-workout edits live only in `WorkoutSessionState`. Navigation pushes/pops within the workout must NOT commit to `AppState.workoutLogs`. Only "Save Workout" on the Summary screen commits.

2. **Empty set cleanup on Complete Exercise:** Silently remove sets where both `weight == nil` AND `reps == nil` AND `done == false`. No confirmation needed.

3. **Rest timer final-set exception:** `startRest` must check `setIndex < exercise.sets.count - 1`. If user adds a new set (making count go from 3→4 after completing set 3 which was previously the last), immediately fire rest on the `onAddSet` call.

4. **Predefined program protection:** `SeedData.programs` is a `let` constant — immutable. User edits via "Save Permanently" scope dialog mutate only the `UserPlan.customWorkouts` copy in `AppState`, never the seed.

5. **Dark mode triple-state:** `AppState.darkModePreference` drives `.preferredColorScheme()` on the root `ContentView`: `.none` for Auto, `.light` for Off, `.dark` for On.
