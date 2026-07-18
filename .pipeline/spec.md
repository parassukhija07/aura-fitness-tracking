# IMPLEMENTATION SPEC

Feature: H7 — Wire existing unit preferences (`weightUnit`/`lengthUnit`) through every hardcoded kg/cm/lb/in display and input site via a central `UnitFormatter`.

## ⚠️ OPEN QUESTIONS

None. Both prior open questions are resolved below.

### RESOLVED — R1: Input conversion IS in scope (bidirectional).
Confirmed by requester: H7 includes input→metric conversion, not display-only. Implement every `[INPUT-CONVERSION]` site in this spec. The three live-workout write sites convert typed `lb` → canonical `kg` before assigning `WorkoutSet.weight: Double?`:
- `AuraFitness/ActiveWorkout/SetRowView.swift:37` → `set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)`
- `AuraFitness/ActiveWorkout/SetRowView.swift:147` (`toggleDone`) → same
- `AuraFitness/ActiveWorkout/SupersetView.swift:339` → same

`WorkoutSet.weight` (`AuraFitness/Models/WorkoutModels.swift:41`) stays canonical kg; PR computation (`AppState.saveWorkout`), volume totals, and persisted `WorkoutLog`s remain unchanged and correct. Do NOT leave any `// TODO(H7)` markers.

### RESOLVED — R2: `SetHistory.weight` vs `QuickLogSet.weight` — two DIFFERENT handlings.

Investigation performed (construction sites + model defs):

- **`SetHistory.weight` (`AuraFitness/Models/WorkoutModels.swift:56`, type `String`) = canonical-kg NUMERIC string. CONVERT via `Double(str)`.**
  Evidence:
  - Dynamic build at `AuraFitness/Models/AppState.swift:346-350`: `let wStr = s.weight.map { String($0) } ?? "0"` — sourced from `WorkoutSet.weight: Double?` (canonical kg), so it is always a bare numeric string like `"82.5"` or the fallback `"0"`. Never carries a unit suffix or locale formatting.
  - Seed data confirms bare numerics: `SeedData.swift:13,21,28,88,94` and `ActiveWorkoutSeed.swift:50-174` all use `SetHistory(weight: "80", …)`, `"77.5"`, `"28"`, etc.
  - **Decision:** these are assumed-metric-kg numeric strings. Display via `Double(h.weight)` parse then convert. Guard the parse (fallback to showing the raw string with the pref suffix if `Double(...)` is nil, which should not occur in practice but must not crash).

- **`QuickLogSet.weight` (`AuraFitness/Models/LogDayModel.swift:26`, type `String`, default `""`) = FREE-TEXT. DO NOT convert numerically. Label/placeholder swap only.**
  Evidence:
  - Bound directly to a raw `TextField` at `AuraFitness/Log/LogSheetsView.swift:839` (`TextField("kg", text: bindingWeight(i, j))`) — user types arbitrary text; no numeric contract, no canonical unit.
  - Seeded with the non-numeric sentinel `"—"` at `LogSheetsView.swift:725` (`QuickLogSet(weight: "—", reps: "")`) and empty `""` at lines 847/871; test data uses `"100"` (`AuraFitnessTests/PersistenceRoundTripTests.swift:105-106`).
  - Because values are free-text (may be `"—"`, `""`, or non-numeric) and there is no stored-canonical guarantee, converting would corrupt data. **Decision:** treat as free-text. Only the placeholder `"kg"` at line 839 (and the `"WEIGHT"` column header at line 832 — leave header text as-is) may show `appState.weightUnit` as a placeholder hint. No parse, no conversion, no save/load transform for QuickLogSet.

## 🏗️ ARCHITECTURE & PATTERNS

- **Existing patterns to match:**
  - Unit prefs are plain `String`s on `AppState`: `weightUnit` ∈ {`"kg"`,`"lb"`}, `lengthUnit` ∈ {`"cm"`,`"in"`} — see `AuraFitness/Models/AppState.swift:241-246`. Changed via `ProfileSettingsScreens.swift:140-150`.
  - Views already read `appState.weightUnit`/`lengthUnit` for the *label only* in `LogMeasurementSheet.swift:31,34`, `ProgressPhotosView.swift:255`, `MeasurementsView.swift:103,119,288`, `ProfileTabView.swift:48,50` — these show the unit string but never convert the number.
  - `@EnvironmentObject var appState: AppState` is the standard injection in all views. `WorkoutSessionState` holds `private weak var appState: AppState?` (`WorkoutSessionState.swift:69`).
  - All weight Doubles are canonical **kg**; all length/circumference Doubles are canonical **cm** (confirmed: `BodyStats.weight` line 79 `// kg`, `.height` line 78 `// cm`, `.targetWeight` line 83 `// kg`; `WorkoutSet.weight`, `PRRecord.weight`, `TargetRecord.weight`, `Measurement.*` all raw Doubles with no conversion anywhere). **No data migration is required** — storage stays metric; this is purely a display/input transform layer.

- **Core strategy:** Add a stateless `UnitFormatter` utility with static functions that take the canonical metric `Double` plus the unit string (`appState.weightUnit`/`lengthUnit`) and return a formatted display string (or parse a typed string back to metric). Replace every hardcoded `"kg"`/`"cm"` literal and every raw `String(format:)`/interpolation of a metric value with a `UnitFormatter` call passing `appState`'s current unit.

## 📄 FILES TO CREATE

### `AuraFitness/Models/UnitFormatter.swift`
- **Purpose:** Central, stateless conversion + formatting utility. No new settings, no state — reads unit as a passed-in `String`.
- **Constants:**
  - `kgPerLb = 0.45359237`
  - `cmPerInch = 2.54`
- **Signatures/Interfaces (implement exactly):**
  ```
  enum UnitFormatter {
      // ---- WEIGHT (canonical = kg) ----
      /// Convert canonical kg to the display unit's numeric value.
      static func weightValue(_ kg: Double, unit: String) -> Double
          // unit == "lb" → kg / 0.45359237 ; else kg

      /// Formatted number only (no unit suffix). Precision: 1 decimal, trimmed if whole.
      /// e.g. 100.0 -> "100", 100.5 -> "100.5"
      static func weightNumber(_ kg: Double, unit: String) -> String

      /// Formatted "<number> <unit>" e.g. "220 lb" / "100 kg".
      static func weight(_ kg: Double, unit: String) -> String

      /// Parse a user-typed string in `unit` back to canonical kg. Returns nil on empty/invalid.
      static func parseWeightToKg(_ text: String, unit: String) -> Double?
          // Double(text) then, if unit == "lb", * 0.45359237

      // ---- LENGTH (canonical = cm) ----
      static func lengthValue(_ cm: Double, unit: String) -> Double   // "in" → cm / 2.54
      static func lengthNumber(_ cm: Double, unit: String) -> String  // 1 decimal, trimmed
      static func length(_ cm: Double, unit: String) -> String        // "<n> <unit>"
      static func parseLengthToCm(_ text: String, unit: String) -> Double?

      /// Bare display suffix, echoing the pref (used where only the label is needed).
      static func weightSuffix(_ unit: String) -> String   // returns unit as-is ("kg"/"lb")
      static func lengthSuffix(_ unit: String) -> String    // returns unit as-is ("cm"/"in")
  }
  ```
- **Rounding rule:** weight → 1 decimal place, drop trailing `.0`. length/circumference → 1 decimal place, drop trailing `.0`. Whole-number formatting helper: format with `%.1f`, then strip a trailing `".0"`.

## 📝 FILES TO MODIFY

Each site below currently hardcodes a metric literal and/or a raw number. Replace the number with a `UnitFormatter` call and the literal with the pref. All views listed already have (or must add) `@EnvironmentObject var appState: AppState`.

### `AuraFitness/Progress/NutritionView.swift`
- Line **49 + 53**: `Text("\(String(format: "%.1f", stats.weight))")` + `Text(" kg")` → number becomes `UnitFormatter.weightNumber(stats.weight, unit: appState.weightUnit)`, suffix becomes `" \(appState.weightUnit)"`. (View needs `appState` — confirm it is injected; add `@EnvironmentObject var appState: AppState` if absent.)
- Line **58**: `Text("Target \(String(format: "%.0f", stats.targetWeight)) kg")` → `Text("Target \(UnitFormatter.weight(stats.targetWeight, unit: appState.weightUnit))")`.
- Line **95**: `detailCol("Height", "\(Int(stats.height)) cm")` → `detailCol("Height", UnitFormatter.length(stats.height, unit: appState.lengthUnit))`.
- Line **97**: `detailCol("Weight", "\(String(format: "%.1f", stats.weight)) kg")` → `detailCol("Weight", UnitFormatter.weight(stats.weight, unit: appState.weightUnit))`.

### `AuraFitness/ActiveWorkout/WorkoutSessionState.swift`
- Line **231** (celebration message): `message: "\(w) kg beats your \(pr.weight) kg best."` → use `appState?.weightUnit ?? "kg"` and `UnitFormatter.weight(...)`:
  `let u = appState?.weightUnit ?? "kg"` then `message: "\(UnitFormatter.weight(w, unit: u)) beats your \(UnitFormatter.weight(pr.weight, unit: u)) best."`
  (`appState` is already a member here, `WorkoutSessionState.swift:69`.)

### `AuraFitness/ActiveWorkout/SetRowView.swift`  — needs `@EnvironmentObject var appState: AppState` added
- Line **36**: `label: "kg"` → `label: appState.weightUnit`.
- Line **76**: `Text("\(h.weight) kg")` — `h.weight` is a canonical-kg NUMERIC String (see R2). CONVERT: `Text(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit))`. If `Double(h.weight)` is nil (should not occur), the `?? 0` guard prevents a crash.
- Line **92** (`onAppear`): `weightText = set.weight.map { formatWeight($0) }` → seed the field in the DISPLAY unit: `set.weight.map { UnitFormatter.weightNumber($0, unit: appState.weightUnit) }`.
- `[INPUT-CONVERSION]` Line **37**: `set.weight = Double(weightText)` → `set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)`.
- `[INPUT-CONVERSION]` Line **147** (`toggleDone`): `set.weight = Double(weightText)` → `set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)`.

### `AuraFitness/ActiveWorkout/SupersetView.swift` (the set-row struct) — needs `@EnvironmentObject var appState: AppState` added
- Line **338**: `label: "kg"` → `label: appState.weightUnit`.
- Line **362**: `Text("\(h.weight) kg")` — `h.weight` is a canonical-kg NUMERIC String (R2). CONVERT: `Text(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit))`.
- Line **370** (`onAppear`): seed field via `UnitFormatter.weightNumber($0, unit: appState.weightUnit)`.
- `[INPUT-CONVERSION]` Line **339**: `set.weight = Double(weightText)` → `set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)`.
- Lines **166 & 171** (`fmt($0.weight)) kg`): `fmt` produces the kg number; replace `"\(fmt($0.weight)) kg"` with `UnitFormatter.weight($0.weight, unit: appState.weightUnit)`.

### `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift` — verify `appState` injected
- Lines **188 & 193**: `"\(fmt($0.weight)) kg × \($0.reps)"` → `"\(UnitFormatter.weight($0.weight, unit: appState.weightUnit)) × \($0.reps)"`.
- Line **350**: `"Set …: \(h.weight) kg × \(h.reps) reps"` — `h.weight` is a canonical-kg NUMERIC String (R2). CONVERT: `"…: \(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit)) × \(h.reps) reps"`.

### `AuraFitness/ActiveWorkout/WorkoutSummaryView.swift` — verify `appState` injected
- Line **84**: `"\(d) sets · \(Int(vol).formatted()) kg"` — `vol` is canonical kg volume. Convert: `"\(d) sets · \(UnitFormatter.weight(vol, unit: appState.weightUnit))"`.

### `AuraFitness/Progress/WeeklyVolumeView.swift` — verify `appState` injected
- Line **97**: `Text(metric == "Volume" ? "kg this week" : "sets this week")` → `"\(appState.weightUnit) this week"`.
- Line **150**: `"\(top.sets) sets · \(formatVolume(top.volume)) kg"` → `"\(top.sets) sets · \(UnitFormatter.weight(top.volume, unit: appState.weightUnit))"`.

### `AuraFitness/Progress/ProgressPhotosView.swift`
- Line **214**: `"\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta)) kg · body change"` — `delta` is a kg difference. Convert the magnitude: `let d = UnitFormatter.weightValue(delta, unit: appState.weightUnit)` then format with sign + `" \(appState.weightUnit) · body change"`.
- Line **255**: `Text("Weight (\(appState.weightUnit))")` — already dynamic label; no change unless the paired input value needs conversion (check the weight entry field in this view and apply `parseWeightToKg`/`weightNumber` if it binds to a canonical Double). `[INPUT-CONVERSION]` if that field writes a stored kg Double.

### `AuraFitness/Progress/StatsView.swift` — verify `appState` injected
- Line **128**: `Text("kg")` → `Text(appState.weightUnit)`. Also convert the paired numeric value at its call site (locate the metric Double rendered next to this label and wrap with `UnitFormatter.weightNumber`).

### `AuraFitness/Progress/PersonalRecordsView.swift` — verify `appState` injected
- Line **110**: `"1RM est. \(Int(pr.estimated1RM)) kg"` → `"1RM est. \(UnitFormatter.weight(pr.estimated1RM, unit: appState.weightUnit))"`.
- Line **129**: `"1RM ≈ \(Int(pr.estimated1RM)) kg"` → `"1RM ≈ \(UnitFormatter.weight(pr.estimated1RM, unit: appState.weightUnit))"`.
- Also scan this view for any `pr.weight` display (raw kg) and convert.

### `AuraFitness/Progress/MeasurementsView.swift`
- Line **14**: `let measurementUnits = ["kg", "%", "cm", …]` — this static array must become dynamic. Replace with a computed function that returns `appState.weightUnit` for the weight row, `"%"` for body fat, and `appState.lengthUnit` for all circumference rows. Every consumer of `measurementUnits[i]` must switch to this computed lookup.
- Line **103**: `Text(appState.weightUnit)` — already dynamic; ensure paired numeric weight value uses `UnitFormatter.weightNumber`.
- Line **119**: `String(format: "%.1f %@ / 30d", abs(delta), appState.weightUnit)` — `delta` is kg; convert: `abs(UnitFormatter.weightValue(delta, unit: appState.weightUnit))` for the number.
- Line **288**: `String(format: "%.1f \(appState.lengthUnit)", v)` — `v` is a canonical cm circumference; convert: `UnitFormatter.lengthNumber(v, unit: appState.lengthUnit)` + suffix.
- Scan the weight/circumference chart + card numbers (`weightDelta30`, `weightChartData`, `weightCard`) and wrap displayed values in `UnitFormatter.weightValue`/`lengthValue` so the trend numbers match the label.

### `AuraFitness/Progress/LogMeasurementSheet.swift`
- Lines **31 & 34**: labels already dynamic — no change.
- `[INPUT-CONVERSION]` `save()` (lines 73-86): `weight` is typed in `appState.weightUnit`; circumferences (`neck…shoulders`) typed in `appState.lengthUnit`. Convert before storing canonical:
  - `weight: UnitFormatter.parseWeightToKg(weight, unit: appState.weightUnit)`
  - each circumference: `UnitFormatter.parseLengthToCm(neck, unit: appState.lengthUnit)` etc.
  - `bodyFat` stays `Double(bodyFat)` (percentage, unit-agnostic).

### `AuraFitness/Profile/ProfileTabView.swift`
- Line **48**: `"\(age) · \(h) cm · \(w) kg · \(profile.gender)"` — `h`/`w` are canonical cm/kg. Convert: `"…· \(UnitFormatter.length(h, unit: appState.lengthUnit)) · \(UnitFormatter.weight(w, unit: appState.weightUnit)) · …"`. Confirm `h`/`w` are Doubles at this line; if they are pre-formatted strings, trace back to their source and convert there instead.
- Line **50** (`unitsSubtitle`): already just echoes the two pref strings — no change.

### `AuraFitness/Log/LogSheetsView.swift`
- Line **832**: `Text("WEIGHT")` column header — LEAVE AS-IS (generic header, not a unit label).
- Line **839**: `TextField("kg", text: bindingWeight(i, j))` → placeholder becomes `appState.weightUnit`: `TextField(appState.weightUnit, text: bindingWeight(i, j))`. This is a PLACEHOLDER-ONLY change. `bindingWeight` maps to `QuickLogSet.weight`, which is FREE-TEXT (see R2): do NOT parse or convert it, do NOT add any save/load transform. The stored string is written verbatim as typed. View needs `@EnvironmentObject var appState: AppState` — confirm injected.

### `AuraFitness/Plan/PlanExerciseDetailView.swift`
- Lines **475, 488, 510, 530, 532**: all render `"\(planNum(v))kg"` from canonical-kg Doubles (`pbs.maxVol`, `st.weight`, Epley 1RM). This view lacks `appState` — add `@EnvironmentObject var appState: AppState`. Replace each `"…kg"` with `UnitFormatter.weight(v, unit: appState.weightUnit)` (or `weightNumber` + `appState.weightUnit` suffix where the layout appends the unit separately). `planNum`/`fmt` helpers stay for the number-shaping but feed the converted value, OR are replaced by `UnitFormatter.weightNumber`. Keep the `"BW"`/bodyweight branch unchanged.

## 🛡️ EDGE CASES TO HANDLE

- **Invalid / empty typed input:** `parseWeightToKg`/`parseLengthToCm` must return `nil` (not 0) on empty or non-numeric text so `set.weight = nil` clears correctly and the auto-finish/PR logic still treats the set as unfilled. Do not coerce empty to `0`.
- **Round-trip precision drift:** seeding an input field from a converted value then re-parsing must not silently mutate stored kg on every keystroke. Only write back to the stored Double on the existing blur/onChange callbacks (already the case), and use 1-decimal display precision so `100 kg → 220.5 lb → 100.0006 kg` drift stays sub-display. Do not re-normalize stored values on load.
- **History strings vs free-text strings (RESOLVED, R2):** `SetHistory.weight` is a canonical-kg numeric string — parse with `Double(h.weight) ?? 0` then convert for display (SetRowView:76, SupersetView:362, ExerciseLoggingView:350). `QuickLogSet.weight` is arbitrary free-text (may be `"—"`, `""`, or non-numeric) — NEVER parse or convert; only swap the placeholder at LogSheetsView:839. Mixing these up will corrupt quick-log data or crash on `"—"`.
- **Missing `appState` injection:** several display views (`PlanExerciseDetailView`, possibly `StatsView`/`WeeklyVolumeView`/`WorkoutSummaryView`/`PersonalRecordsView`) may not currently hold `@EnvironmentObject var appState`. Adding it is safe (AppState is app-root injected) but the Coder must add the property to each and verify the view is instantiated within the AppState environment.
