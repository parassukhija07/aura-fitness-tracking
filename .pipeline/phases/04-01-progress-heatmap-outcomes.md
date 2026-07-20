# IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes

## ⚠️ OPEN QUESTIONS
None. The outcome-derivation rules below are pre-decided; implement them exactly.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Progress tab's Stats subtab shows a GitHub-style consistency heatmap (`AuraFitness/Progress/ConsistencyHeatmapView.swift`). It currently colours days on a binary "has log" check. The design requires FIVE intensity levels per day — Rest · Partial · Swapped · Completed · PR day — derived from real session outcomes, plus a legend and clamped month navigation.
- **Existing Patterns to Match:**
  - `AuraFitness/Progress/ConsistencyHeatmapView.swift` — current month grid, ‹/› nav, day-cell rendering; keep the grid geometry, change the colouring engine.
  - `AuraFitness/Models/AppState.swift` — `workoutLogs` (persisted session log; inspect the `WorkoutLog` type in `AuraFitness/Models/` for its exercises/sets fields), `personalRecords` (append-only, each record carries a date), `hasLog(for:)`, the day-override store used by `dayInfo(for:)` (`DayOverride` in `AuraFitness/Models/LogDayModel.swift` with `kind` and `workoutId`), and `iso(...)` for date keys.
  - `AuraFitness/Progress/StatsView.swift` — hosts the heatmap card; match its section styling.
- **Core Strategy:** Add one pure function mapping an ISO date → outcome level, then colour cells and render a legend from a single source-of-truth enumeration.

## 📝 FILES TO MODIFY
### `AuraFitness/Progress/ConsistencyHeatmapView.swift`
- **Add** `enum DayOutcome: Int, CaseIterable { case rest = 0, partial, swapped, completed, prDay }` with `var label: String` → "Rest" / "Partial" / "Swapped" / "Completed" / "PR day" and `var color: Color`:
  - rest → `Color.aura.text3.opacity(0.15)` (near-invisible base cell)
  - partial → `.aura.accent.opacity(0.35)`
  - swapped → `.aura.blue.opacity(0.6)`
  - completed → `.aura.accent.opacity(0.75)`
  - prDay → `.aura.accent` (full)
  (If the file already colours via tokens, keep the token approach but preserve this 5-step visual ramp.)
- **Add** `func outcome(for iso: String) -> DayOutcome` with EXACT precedence (first match wins):
  1. **prDay** — any `appState.personalRecords` entry whose date matches the day.
  2. No `WorkoutLog` for the day → **rest**.
  3. **swapped** — a log exists AND the day has a `DayOverride` whose `kind` indicates a switched/substituted workout (inspect `DayOverride.kind` cases; use the case(s) the Log tab writes when the user switches today's workout).
  4. **completed** — a log exists and every exercise in it has all its sets done (derive from the log's exercise/set fields; if the model stores only completed sets, treat "≥ planned set count per exercise" as done).
  5. Otherwise (log exists but not fully done) → **partial**.
- **Legend:** below the grid, one row of 5 items (small rounded square in the outcome colour + label in `AuraFont.secondary()`, `.aura.text2`), iterating `DayOutcome.allCases` — never a hand-maintained parallel list.
- **Month navigation:** ‹/› clamps between (a) the month of the EARLIEST `workoutLogs` entry (or the current month when no logs) and (b) the current month. Buttons at the clamp edge render disabled/dimmed (`.aura.text3`), not hidden.
- **Day-label header row:** if it uses `ForEach(..., id: \.self)` over repeated letters ("S", "T"), switch to `Array(labels.enumerated())` with `id: \.offset` (audit finding L8).

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Future days in the displayed month render as empty/rest at reduced opacity and are excluded from any counts.
- Multiple logs on one day: the cell takes the "best" outcome (highest raw value).
- PR precedence: a partially-completed session that still set a PR shows **prDay** (rule 1 outranks completeness).
- Timezone/calendar: all date-key math through `AppState.iso(...)` (Gregorian-pinned — audit L1); never ad-hoc `DateFormatter` in the view.
- Performance: `outcome(for:)` runs ~35× per render — precompute a `[String: DayOutcome]` dictionary for the visible month in one pass over `workoutLogs`/`personalRecords`; don't scan per cell.
