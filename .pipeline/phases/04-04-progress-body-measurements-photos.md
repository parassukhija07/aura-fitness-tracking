# IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity

## ⚠️ OPEN QUESTIONS
None. Audit-and-fix: much of this screen already works (partial logging, how-to sheet, history, photo compare modes) — verify each checklist item and change only deviations.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). Progress → Body → Measurements (`AuraFitness/Progress/MeasurementsView.swift`) tracks 9 body metrics with partial-save logging (`LogMeasurementSheet.swift`) and a history list; Photos (`ProgressPhotosView.swift`) offers Side-by-Side / Top-Bottom comparison. This spec upgrades the measurement hero card to the design's labelled trend chart with range toggle and delta badge, and tightens the metric-selection UX.
- **Existing Patterns to Match:**
  - `AuraFitness/Progress/MeasurementsView.swift` — current structure, `AuraLineChart` usage, how-to sheet (6 guides), history list. Partial-save behaviour in `LogMeasurementSheet.swift` is CORRECT — do not change it.
  - `AuraAxisChart` in `AuraFitness/DesignSystem/AuraComponents.swift` — the labelled chart component built by feature 04-03 (points, xLabels, valueFormatter, nice-ticks Y axis). If it does not exist yet, BUILD IT THERE FIRST exactly per its doc comment in that file's spec, then use it (04-03 and this spec share it).
  - `AuraFitness/Models/UnitFormatter.swift` — weight kg/lb, length cm/in conversions.
  - `AuraFitness/Models/ProgressModels.swift` — the measurement model/keys (9 metrics: weight, body fat, chest, waist, arms, thighs, shoulders, neck, hips).
- **Core Strategy:** Reorganize the top of `MeasurementsView` into: metric chips → hero card (value + delta + info + labelled chart + range toggle) → current-measurements grid → log button → history. Reuse `AuraAxisChart`; no data-model changes.

## 📝 FILES TO MODIFY
### `AuraFitness/Progress/MeasurementsView.swift`
1. **Metric chips row:** horizontal scroll of chips for the FIRST 7 of the 9 metric definitions (design rule) selecting the active metric (`@State`); active chip accent-tinted.
2. **Hero card** for the active metric:
   - Current value, large (existing hero style), formatted by metric type (weight via `UnitFormatter` weight, lengths via `UnitFormatter` length, body fat as "%").
   - **Delta-from-first badge:** current − FIRST recorded value of that metric's series. For waist / body fat / hips a NEGATIVE delta renders green (improvement downward), positive red; for all other metrics positive = green, negative = red; gray "±0" when equal. Hidden when < 2 data points.
   - Info (`?`) button → the existing "How to Measure" sheet.
   - `AuraAxisChart` of the metric's series (chronological), replacing the plain `AuraLineChart` here.
   - **Range toggle:** `1M · 3M · 6M · 1Y` chips filtering the series by entry date; default 6M.
3. **Current measurements grid:** all 9 metrics as tappable tiles (value, or "—" dimmed `.aura.text3` when never logged); tapping a tile switches the active metric — INCLUDING the 2 metrics not present in the chips row.
4. **Log Measurements button + History list:** keep existing behaviour; verify history rows summarise only the fields changed in that entry.
### `AuraFitness/Progress/ProgressPhotosView.swift`
- Verify against design: segmented "Side by Side" / "Top / Bottom" toggle (exists), two photo slots each labelled with date · weight caption when available, and an "Add comparison photo" affordance. Fix deviations only; keep `PhotosPicker` wiring as-is.

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Metric with 0 entries: hero shows "—", chart area shows the existing "Log more measurements to see trend" empty state, delta hidden, range toggle disabled/dimmed.
- Range with no entries inside it (e.g. 1M selected but last log was 3 months ago): show the empty-trend state for that range — never a crash or a fake flat line.
- Unit switching (kg↔lb, cm↔in) must reformat hero value, chart axis labels, grid tiles, and history live — canonical metric units stored, conversion only at display (existing convention; verify no regression).
- The partial-save contract is sacred: the log sheet saves ONLY filled fields; untouched fields keep prior value and series. Do not prefill or overwrite.
- Photo data is stored as JPEG blobs in UserDefaults today (known tech debt, audit C3) — do NOT migrate storage in this feature.
