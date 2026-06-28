# FIX SPEC — Aura Fitness Tracker Build Errors

## ARCHITECTURE

The build fails on a macOS runner (Xcode 15.4 / Swift 5.9). Five distinct problems, all with deterministic fixes:

1. **Naming collision (root cause of the largest error cascade).** There are TWO types literally named `ActiveWorkoutView`:
   - `AuraFitness/ActiveWorkout/ActiveWorkoutView.swift:3` — `struct ActiveWorkoutView: View` (the SwiftUI screen).
   - `AuraFitness/ActiveWorkout/WorkoutSessionState.swift:4` — `enum ActiveWorkoutView` (the navigation-state enum).
   The `WorkoutSessionState.activeView` property is typed as the enum (`WorkoutSessionState.swift:22`). Because the struct shadows the enum, the compiler reports "invalid redeclaration" and then "ambiguous for type lookup", which cascades into every file that reads/writes `session.activeView` (the `.overview`/`.summary`/`.exercise`/`.superset` member lookups and the property-wrapper subscript errors). FIX: rename the ENUM (and only the enum + the property's type annotation) to `ActiveWorkoutScreen`. All `.overview`, `.exercise(index:)`, `.superset(index:)`, `.summary` call sites infer their base from the property type, so they do NOT need editing once the enum is renamed and the property annotation updated. The only two by-name references to the enum are its declaration and the property annotation — both inside `WorkoutSessionState.swift`. Do NOT rename the `struct ActiveWorkoutView` (it is instantiated in `ContentView.swift:39`).

2. **`Color` does not conform to `Hashable` for `navigationDestination(item:)`.** `WorkoutLibraryView.swift:50` uses `.navigationDestination(item: $selectedWorkout)` where `selectedWorkout` is a `Workout?`. `navigationDestination(item:destination:)` requires the item to be `Hashable`. The `Workout` struct (`AuraFitness/Models/WorkoutModels.swift:104`) is `Identifiable, Codable` but NOT `Hashable`. FIX: add `Hashable` conformance to `Workout`. All of `Workout`'s stored properties are already `Hashable` (`UUID`, `String`, `Int`, `[Exercise]`, `String?`), so a synthesized conformance works — provided `Exercise` is also `Hashable`. SEE OPEN QUESTIONS / note below: confirm `Exercise` already conforms to `Hashable`; the spec includes the conditional step.

3. **`specifier:` string-interpolation argument was removed in Swift 5.9.** Two files use `"\(value, specifier: "%.1f")"`-style interpolation. Replace each with `String(format:)`.

4. **Deprecated `onChange(of:perform:)`.** `SetRowView.swift:43` and `:64` use the single-parameter iOS-16 closure form. Update to the two-parameter iOS-17 form.

---

## FILES TO MODIFY

### 1. `AuraFitness/ActiveWorkout/WorkoutSessionState.swift`

**Change A — rename the enum (line 4).**

OLD:
```swift
enum ActiveWorkoutView {
    case overview
    case exercise(index: Int)
    case superset(index: Int)
    case summary
}
```
NEW:
```swift
enum ActiveWorkoutScreen {
    case overview
    case exercise(index: Int)
    case superset(index: Int)
    case summary
}
```

**Change B — update the property's type annotation (line 22).**

OLD:
```swift
    @Published var activeView: ActiveWorkoutView = .overview
```
NEW:
```swift
    @Published var activeView: ActiveWorkoutScreen = .overview
```

Do NOT change anything else in this file. The `.overview` / `.summary` / `.exercise` / `.superset` references (lines 68, 196, etc.) stay exactly as they are — they resolve through the property's type.

---

### 2. `AuraFitness/Models/WorkoutModels.swift`

**Change — add `Hashable` to `Workout` (line 104).**

OLD:
```swift
struct Workout: Identifiable, Codable {
```
NEW:
```swift
struct Workout: Identifiable, Codable, Hashable {
```

IMPORTANT PRECONDITION: Swift can synthesize `Hashable` for `Workout` only if its property type `Exercise` (and any nested types it contains) also conforms to `Hashable`. Before finishing, the Coder MUST check the `struct Exercise` declaration in this same file (`AuraFitness/Models/WorkoutModels.swift`).
- If `Exercise` already declares `Hashable` (directly or transitively), no further change is needed.
- If `Exercise` does NOT conform to `Hashable`, add `Hashable` to its declaration line as well (e.g. change `struct Exercise: Identifiable, Codable {` to `struct Exercise: Identifiable, Codable, Hashable {`). Apply the same rule to any further nested custom types `Exercise` contains (e.g. `WorkoutSet`, `SetType`, PR/target structs) until the build resolves — every stored-property custom type in the `Workout` graph must be `Hashable`. Enums with no associated values and structs of all-`Hashable` stored properties get synthesized conformance for free; just add `, Hashable` to each declaration.

Do not add manual `==` / `hash(into:)` implementations — rely on synthesized conformance.

---

### 3. `AuraFitness/Plan/WorkoutLibraryView.swift`

No change required IF the `Workout: Hashable` change in file #2 is made. Line 50 (`.navigationDestination(item: $selectedWorkout)`) will compile once `Workout` is `Hashable`. Leave this file as-is.

---

### 4. `AuraFitness/Progress/MeasurementsView.swift`

Replace every `specifier:` interpolation. There are FOUR occurrences.

**Change A — line 32.**

OLD:
```swift
                                    Text("\(abs(trend), specifier: "%.1f") \(appState.weightUnit)")
```
NEW:
```swift
                                    Text("\(String(format: "%.1f", abs(trend))) \(appState.weightUnit)")
```

**Change B — line 45.**

OLD:
```swift
                                Text("\(w, specifier: "%.1f")")
```
NEW:
```swift
                                Text(String(format: "%.1f", w))
```

**Change C — line 73.**

OLD:
```swift
                    measureTile("Body Fat", value: latestMeasurement?.bodyFatPct.map { "\($0, specifier: "%.1f")%" })
```
NEW:
```swift
                    measureTile("Body Fat", value: latestMeasurement?.bodyFatPct.map { String(format: "%.1f%%", $0) })
```

**Change D — line 77.**

OLD:
```swift
                        return "\(w * (1 - bf/100), specifier: "%.1f") kg"
```
NEW:
```swift
                        return "\(String(format: "%.1f", w * (1 - bf/100))) kg"
```

**Change E — line 103.**

OLD:
```swift
                                    Text("\(v, specifier: "%.1f") \(appState.lengthUnit)")
```
NEW:
```swift
                                    Text("\(String(format: "%.1f", v)) \(appState.lengthUnit)")
```

(Note: occurrences span lines 32, 45, 73, 77, 103 — five total. Apply all five.)

---

### 5. `AuraFitness/Progress/NutritionView.swift`

Two `specifier:` occurrences.

**Change A — line 57.**

OLD:
```swift
                            Text("\(stats.weight, specifier: "%.0f") kg")
```
NEW:
```swift
                            Text("\(String(format: "%.0f", stats.weight)) kg")
```

**Change B — line 89.**

OLD:
```swift
                    StatTile(value: "\(stats.bmi, specifier: "%.1f")", label: "BMI", color: bmiColor)
```
NEW:
```swift
                    StatTile(value: String(format: "%.1f", stats.bmi), label: "BMI", color: bmiColor)
```

---

### 6. `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift`

Two `specifier:` occurrences (these were not in the original error list but are the same Swift 5.9 removal and WILL fail the build once Group 2 is fixed — fix them now).

**Change A — line 96.**

OLD:
```swift
                                Text("\(pr.weight, specifier: "%.1f") kg × \(pr.reps)")
```
NEW:
```swift
                                Text("\(String(format: "%.1f", pr.weight)) kg × \(pr.reps)")
```

**Change B — line 114.**

OLD:
```swift
                                Text("\(t.weight, specifier: "%.1f") kg × \(t.reps)")
```
NEW:
```swift
                                Text("\(String(format: "%.1f", t.weight)) kg × \(t.reps)")
```

---

### 7. `AuraFitness/ActiveWorkout/AuraComponents.swift` — CORRECTION: file is `AuraFitness/DesignSystem/AuraComponents.swift`

**Change — fix the ternary type mismatch (lines 160–165).**

The problem: the `true` branch returns `Color.aura.surface.shadow(...)` which is `some ShapeStyle`, while the `false` branch returns `Color.clear` which is `Color`. The two branches of a ternary must be the same type. FIX: give both branches an explicit shadow so both are the same `ShapeStyle` type, OR wrap the styled `Color` in `AnyShapeStyle`. Use `AnyShapeStyle` on both branches — deterministic and compiles cleanly.

OLD (lines 160–165):
```swift
                        .background(
                            selection == opt
                                ? Color.aura.surface
                                    .shadow(.drop(color: .black.opacity(0.08), radius: 1, y: 1))
                                : Color.clear
                        )
```
NEW:
```swift
                        .background(
                            selection == opt
                                ? AnyShapeStyle(Color.aura.surface
                                    .shadow(.drop(color: .black.opacity(0.08), radius: 1, y: 1)))
                                : AnyShapeStyle(Color.clear)
                        )
```

(`AnyShapeStyle` is available in iOS 16+/Swift 5.7+ and erases both branches to the same type, resolving the "mismatching types 'some ShapeStyle' and 'Color'" error.)

---

### 8. `AuraFitness/ActiveWorkout/SetRowView.swift`

Update both deprecated `onChange` calls to the iOS-17 two-parameter form.

**Change A — line 43.**

OLD:
```swift
                    .onChange(of: weightText) { newVal in
                        set.weight = Double(newVal)
                        autoFinishIfReady()
                    }
```
NEW:
```swift
                    .onChange(of: weightText) { _, newVal in
                        set.weight = Double(newVal)
                        autoFinishIfReady()
                    }
```

**Change B — line 64.**

OLD:
```swift
                    .onChange(of: repsText) { newVal in
                        set.reps = Int(newVal)
                        autoFinishIfReady()
                    }
```
NEW:
```swift
                    .onChange(of: repsText) { _, newVal in
                        set.reps = Int(newVal)
                        autoFinishIfReady()
                    }
```

---

## OPEN QUESTIONS

None that block implementation. One conditional verification step is folded into FILE #2: the Coder must confirm whether `Exercise` (and its nested custom types in `AuraFitness/Models/WorkoutModels.swift`) already conform to `Hashable`, and if not, add `, Hashable` to each declaration in the `Workout` property graph. This is deterministic — add `, Hashable` until the synthesized conformance resolves; never write manual `==`/`hash(into:)`.

---

## DEFINITION OF DONE

- `xcodebuild` / GitHub Actions build produces ZERO errors.
- The `onChange(of:perform:)` deprecation warnings in `SetRowView.swift` are gone (fixed to two-parameter form).
- No new manual `Equatable`/`Hashable` boilerplate added — only synthesized conformance via `, Hashable` on declarations.
- The struct `ActiveWorkoutView` (the View) is unchanged and still used by `ContentView.swift`; only the enum was renamed to `ActiveWorkoutScreen`.
- Remaining (non-`onChange`) warnings are acceptable.
