# IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming

## ⚠️ OPEN QUESTIONS
None. Audit-and-fix against fixed checklists; leave already-conforming code untouched.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Plan tab's My Plans subtab (`AuraFitness/Plan/MyPlansView.swift`) owns a set of bottom sheets for plan/workout management. The design specifies five sheets (add-plan, assign, day-menu, add-workout, create-workout), a 12-icon picker grid inside create-workout, and a keyword-driven colour/icon theming rule for workout tiles used across My Plans, the libraries, and the week strip.
- **Existing Patterns to Match:**
  - `AuraFitness/Plan/MyPlansView.swift` — existing sheets (`CreatePlanView`, `PlanScheduleEditorView`, add flows); extend in place.
  - `AuraFitness/Log/LogSheetsView.swift` — the canonical bottom-sheet composition style (header + rows + cancel footer, `.presentationDetents`).
  - Tokens/components: `Color.aura.*` (accent, blue, green, purple, red, text/text2/text3), `AuraFont.*`, `AuraCard`, `AuraTintedButton`, `AuraGrayButton`.
- **Core Strategy:** (1) Introduce one shared theming helper and apply it everywhere workout tiles render; (2) verify/complete the five sheets to the exact row lists below; (3) build the create-workout sheet's 12-icon grid and its "Continue → Add Exercises" handoff into the workout editor.

## 📝 FILES TO MODIFY
### `AuraFitness/Plan/PlanComponents.swift`
- Add the shared theming helper (this file already holds shared Plan UI helpers):
  - `struct WorkoutTheme { let color: Color; let icon: String }`
  - `func workoutTheme(for name: String) -> WorkoutTheme` — lowercase the name, then first keyword match wins: contains "push" → (`.aura.accent`, flame icon); "pull" → (`.aura.blue`, bolt icon); "leg" → (`.aura.green`, trophy icon); "upper" → (`.aura.purple`, arrow-up icon); anything else → (`.aura.accent`, dumbbell icon). Use the app's existing icon approach (SF Symbols or `AuraTabIcon`-style paths — match whatever the current tiles use).
### `AuraFitness/Plan/MyPlansView.swift`
- Apply `workoutTheme(for:)` to: plan-workout list row icon tiles, week-strip training-day tiles, and any workout thumbnails — replacing ad-hoc per-row colour logic.
- **Sheet checklist (verify each; fix deviations):**
  1. **add-plan** ("Add to My Plans"): three source rows — "Browse programs" (switches to Programs subtab), "Build from scratch" (opens `ProgramEditorView(mode: .create)`), "Duplicate active plan" (copies the default plan under name "{name} copy", then closes). Opened by the carousel "New" dashed tile.
  2. **assign** (assign workout to a day): lists the plan's workouts; the currently-assigned one highlighted with an accent ring + check; picking writes the schedule day. Footer: "Create new workout" source card + "Keep as Rest Day" (closes without assigning).
  3. **day-menu** (training-day actions): "Edit workout" (→ workout editor), "Change workout" (→ assign sheet), "Make it a rest day", "Remove from program" (red). Both of the last two null the day.
  4. **add-workout**: two rows — "From Workout Library" (→ Workouts subtab) and "Create custom workout" (→ create-workout sheet).
  5. **create-workout**: name field + **12-icon picker grid** (4 columns × 3 rows), labels in exact order: Push, Pull, Legs, Upper, Weights, Full Body, Core, Strength, Cardio, Cable, Hypertrophy, Recovery — each a selectable tile (accent border/tint when selected, default = first). Footer `AuraPrimaryButton("Continue → Add Exercises")` disabled until the name is non-empty; on tap it creates the workout (name + icon choice; colour from `workoutTheme(for:)`) and IMMEDIATELY opens `WorkoutEditorView` on it in the appropriate create context (`.createInPlan(planID:)` from My Plans).
### `AuraFitness/Plan/PlanSubtabViews.swift`
- `PlanWorkoutsBody` cards: use `workoutTheme(for:)` for tile colour/icon. Also align the filter chips to the design list: `All · Push · Pull · Legs · Upper · Chest · Back` (replace the current list if it differs; matching stays case-insensitive against name or muscles).

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- A custom workout named e.g. "Chest Day" matches no keyword → MUST fall back to accent + dumbbell (the fallback is part of the design, not an error).
- Keyword priority when multiple match (e.g. "Push Pull"): first match in the order push → pull → leg → upper wins.
- "Duplicate active plan" when no default plan exists: disable the row (dimmed) rather than crash.
- create-workout: trim whitespace — a name of only spaces counts as empty (button stays disabled).
- Assign sheet must reflect live schedule state if opened twice in a row (no stale highlighted row).
- Do not change `UserPlanDatabase`/`ProgramDatabase` signatures; all persistence through existing APIs.
