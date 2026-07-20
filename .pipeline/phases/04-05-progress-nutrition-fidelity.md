# IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity

## ⚠️ OPEN QUESTIONS
None. The formulas below are the specification — where current constants differ, the constants below WIN and must be corrected.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). Progress → Body → Nutrition (`AuraFitness/Progress/NutritionView.swift`) is a live TDEE/macro calculator driven by `appState.bodyStats` and a `NutritionConstants` table (referenced at the top of the view). Every derived number must recompute reactively from inputs. This spec pins the exact math and the exact screen composition.
- **Existing Patterns to Match:**
  - `AuraFitness/Progress/NutritionView.swift` — current sections (goal chips exist, details card, weight trend); keep structure where it matches.
  - `NutritionConstants` (locate its defining file via grep) — single source of truth for activity multipliers, goal adjustments, macro splits. Correct values IN the constants table, not inline in the view.
  - `AuraAxisChart` from `AuraFitness/DesignSystem/AuraComponents.swift` (built in 04-03) for the weight mini-chart; `UnitFormatter` for weight display; `AuraSeg`-style segmented controls and `AuraChip` rows as used elsewhere in Progress.
  - Profile↔Body sync: `syncBodyAndProfile()` / `syncProfileFromBodyStats()` in `AppState` — the details sheet must keep firing the existing `onChange` sync (do not remove).
- **Core Strategy:** Verify/correct the math against the exact table below; then verify/correct the screen composition order. Minimal diffs.

## 📝 FILES TO MODIFY
### `AuraFitness/Progress/NutritionView.swift` (and the `NutritionConstants` definition file)
- **Exact math (source of truth):**
  - BMR (Mifflin-St Jeor): `10×weightKg + 6.25×heightCm − 5×age + (male ? +5 : −161)`
  - Activity multipliers: Sedentary 1.2 · Light 1.375 · Moderate 1.55 · Active 1.725 · Athlete 1.9; `TDEE = round(BMR × multiplier)`
  - Goal adjustments: Lose fat −500 · Maintain 0 · Lean gain +200 · Gain muscle +400; `targetCalories = max(1200, TDEE + adjustment)` — the 1200 floor is mandatory.
  - BMI: `weightKg / (heightCm/100)²`; categories: `<18.5` Underweight · `<25` Normal · `<30` Overweight · else Obese.
  - Macros from `targetCalories` by split percentages (protein/carbs at 4 kcal/g, fats at 9 kcal/g); `fiber = targetCalories/1000 × 14` g. Macro splits (protein/carbs/fats %): Balanced 30/40/30 · High carb 25/50/25 · High protein 40/30/30 · Keto 30/10/60. If the existing `NutritionConstants` table defines different split percentages, replace them with these.
- **Screen composition (top-to-bottom):**
  1. Weight-trend mini chart (`AuraAxisChart` over the weight measurement series) + a target-weight badge.
  2. "Your details" card: height · weight · age · sex · activity · target weight, with an Edit button → details sheet (steppers for height/weight/age/target, segmented Sex, segmented/list Activity). Sheet close recomputes everything (automatic when values live in `appState.bodyStats`).
  3. BMI tile + TDEE tile side-by-side (value + category/sub-label).
  4. **Goal** section: 4 chips (Lose fat / Maintain / Lean gain / Gain muscle) — single-select, accent when active.
  5. **Macro split** section: 4 chips (Balanced / High carb / High protein / Keto) — single-select.
  6. **Daily target card** (accent-tinted): total kcal large; a single horizontal bar proportionally segmented protein/carbs/fats (three distinct token colours); four gram values below: Protein · Carbs · Fats · Fiber.
- All displayed numbers `round`ed to integers except BMI (1 decimal).

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Zero/unset height or weight: show "—" in BMI/TDEE/target tiles and a muted prompt "Complete your details to calculate targets"; never divide by zero.
- Extreme inputs: clamp steppers to age 13–100, height 100–250 cm, weight 30–300 kg.
- The 1200-kcal floor must visibly apply — verify with test case 160 cm / 45 kg / age 60 / Sedentary / Lose fat.
- Weight display follows the kg/lb unit setting; calculations ALWAYS in kg internally.
- Changing sex/age here must keep round-tripping to Profile's birthday/gender via the existing sync functions — regression-test that flow.
