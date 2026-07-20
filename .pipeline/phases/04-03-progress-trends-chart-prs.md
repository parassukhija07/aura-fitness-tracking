# IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity

## ⚠️ OPEN QUESTIONS
None.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Progress → Stats subtab has an "Exercise Trends" card (`AuraFitness/Progress/StatsView.swift` — see `exerciseTrendsCard()` ~line 412, `trendValues` ~line 118, `ExerciseTrendPicker` ~line 557) already computing per-exercise series from real `workoutLogs`. The design requires the chart to be a LABELLED axis chart with a "nice-ticks" Y axis, a time-range selector with special 1-month handling, and a delta badge; plus category-chip filtering on the Personal Records card (`AuraFitness/Progress/PersonalRecordsView.swift`).
- **Existing Patterns to Match:**
  - `AuraFitness/DesignSystem/AuraComponents.swift` — `AuraLineChart` (the current unlabeled Path chart) shows the codebase's custom-chart idiom (pure SwiftUI `Path`, no external libs). The new chart follows the same idiom.
  - `AuraFitness/Progress/StatsView.swift` — metric options (1RM / Max Weight / Max Reps / Max Volume) and the picker sheet already exist; keep their data plumbing.
  - `AuraFitness/Models/UnitFormatter.swift` — all weight axis labels/values through it.
- **Core Strategy:** Build one reusable `AuraAxisChart` in the design system (it will ALSO be reused by the Measurements screen in a later feature — design for reuse now), swap it into the trends card, add the range selector + 1M interpolation + delta badge polish, and add chips to the PR card.

## 📝 FILES TO MODIFY
### `AuraFitness/DesignSystem/AuraComponents.swift` — ADD `AuraAxisChart`
- `struct AuraAxisChart: View` with: `let points: [Double]`, `let xLabels: [String]` (same count or fewer; spread evenly), `let valueFormatter: (Double) -> String`.
- Rendering: gradient area fill under a line + a dot on the LAST point (accent token colours, matching `AuraLineChart`'s visual language); horizontal gridlines at each Y tick with the tick label left-aligned in `.aura.text3` `AuraFont.secondary()`; X labels along the bottom.
- **Nice-ticks algorithm (exact):** target EXACTLY 4 intervals (5 gridlines). `rawStep = (max - min) / 4`; snap `step` to the nearest value of form `1×10ⁿ`, `2×10ⁿ`, or `5×10ⁿ` that is ≥ rawStep; `axisMin = floor(min/step)*step`, `axisMax = axisMin + 4*step` (if that fails to cover max, recompute with the next snap up). Degenerate flat series (max == min): use `step = max(1, |max| * 0.1)` centred on the value.
### `AuraFitness/Progress/StatsView.swift`
- Replace the trends card's current chart body with `AuraAxisChart`.
- **Range selector:** 4 chips `1M · 3M · 6M · 1Y` (`@State var trendRange`, default 6M) filtering the series by session date cutoff (now − 30/90/180/365 days).
- **1M special rule (exact):** for 1M, bucket the window into 4 consecutive weekly buckets; each bucket's value = the metric of its most recent session; a bucket with no sessions carries the previous bucket's value forward; leading empty buckets drop. X labels "W1"…"W4". Other ranges: one point per session, X labels = short month names spread across the window.
- **Delta badge:** big current value + a badge comparing LAST vs FIRST point of the visible window: green tinted "+X" when up, red "−X" when down, gray "±0" when equal; formatted by the metric's formatter (`trendValueLabel`).
- Keep the swap-exercise button + `ExerciseTrendPicker` sheet, but verify the picker offers BOTH muscle-group and equipment filter rows over the full exercise list (add whichever row is missing, styled like the Exercises library chips in `AuraFitness/Plan/PlanSubtabViews.swift`).
### `AuraFitness/Progress/PersonalRecordsView.swift`
- Ensure a horizontal category chip row: `Chest · Back · Legs · Shoulders · Arms` (+ `Core` only if PR data actually contains it) filtering the list; active chip accent-tinted. Row = trophy icon · exercise name · date sub-line · right-aligned "{weight} × {reps}" (weight via `UnitFormatter`).
- Empty filtered state: "No PRs in this category yet" in `.aura.text2`.

## 📄 FILES TO CREATE
None (the new chart lives in `AuraComponents.swift`).

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Series with 0 points → keep the existing empty-state copy; 1 point → render dot + axis, no line, delta badge hidden.
- Reps metric: axis labels must be integers (formatter drops decimals); weight metrics honour the kg/lb unit setting live.
- 1M window with all sessions in one week: the final bucket has data; chart renders 4 points via carry-forward without NaN.
- Do not regress existing empty states ("Log workouts to see per-exercise trends here." / "Log more sessions to draw a trend").
- `AuraLineChart` call sites elsewhere must remain untouched and compiling.
