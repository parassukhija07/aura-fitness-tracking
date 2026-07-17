# IMPLEMENTATION SPEC

## ⚠️ OPEN QUESTIONS

1. **PRD warm-up shape is qualitative, not numeric.** PRD.md §2.14 says only: "first exercise full warm-up protocol and second just 2 sets of warm up protocols." It does NOT define the exact percentages or rep counts. This spec adopts the percentage ladder already used by the demo seed (`ActiveWorkoutSeed.bench()` / `incline()`) as the canonical shape, since it is the only concrete reference in the codebase:
   - **Exercise index 0 (full protocol, 4 sets):** `12 reps @ "Empty bar"`, `8 reps @ "40%"`, `5 reps @ "60%"`, `3 reps @ "80%"`.
   - **Exercise index 1 (2 sets):** `10 reps @ "50%"`, `6 reps @ "75%"`.
   - **Exercise index ≥ 2:** no warm-up (empty array).
   Confirm this ladder is acceptable; if product wants computed absolute loads (e.g. "40%" → literal kg), flag before implementation — see next question.

2. **`WarmupSet.label` is a display cue, not a computed weight.** The existing UI (`ExerciseLoggingView.swift:255`) renders `w.label` verbatim (e.g. "40%", "Empty bar"). The demo seed never puts an absolute kg value there. Therefore this fix stores the **percentage label only** and does NOT synthesize an absolute weight, matching current rendering. The task description says "synthesize warm-up sets (percent of working weight)" — this spec interprets "percent of working weight" as the percentage *label* (which the UI already presents against the working set), NOT a pre-multiplied kg number. If an absolute kg value is required in the label, that is a UI/format change beyond this fix and must be flagged.

   > Note: A "start workout from my plan" real path **does exist** (`AppState.startWorkout` → `buildSession`), so the scope concern raised in the task does not apply — no guessing about missing session-build path was needed.

## 🏗️ ARCHITECTURE & PATTERNS

- **Existing Patterns to Match:**
  - `AuraFitness/Models/AppState.swift` → `buildSession(from:)` (lines 304–346). This is the **real** (non-demo) session build point. It already enriches `lastPR`, `history`, and `target` from `personalRecords` / `workoutLogs`. Warm-up synthesis must be added here, in the same per-exercise loop, following the same "purely additive, never overwrite existing data" convention noted at line 303.
  - `AuraFitness/ActiveWorkout/ActiveWorkoutSeed.swift` → `bench()` (warmup lines 49–54) and `incline()` (warmup lines 80–83) define the canonical warm-up ladder shape to replicate.
  - `AuraFitness/Models/WorkoutModels.swift` → `WarmupSet` struct (lines 48–52): `var reps: Int`, `var label: String`. Do not change this struct.
- **Core Strategy:** Add a private warm-up synthesis helper to `AppState` and call it inside `buildSession`'s existing per-exercise loop, gated on exercise index (0 → full, 1 → 2-set, ≥2 → none), and only when `warmup` is currently empty (additive, never clobber a warm-up that already came from the plan/exercise database). No new files, no model changes, no UI changes.

## 📝 FILES TO MODIFY

### `AuraFitness/Models/AppState.swift`

- **Change 1 — Add warm-up synthesis inside `buildSession(from:)` (in the loop, lines 306–344).**
  Inside the existing `for i in w.exercises.indices` loop, after the `target` derivation block (after line 343), add a warm-up enrichment block:
  - Only act when the exercise's current warm-up is empty:
    ```
    if w.exercises[i].warmup.isEmpty {
        w.exercises[i].warmup = Self.synthesizedWarmup(forExerciseIndex: i)
    }
    ```
  - This preserves any warm-up already attached to the exercise (e.g. from the exercise database via `ExerciseDatabase.swift:116`), matching the additive convention.

- **Change 2 — Add a private static helper `synthesizedWarmup(forExerciseIndex:)` to `AppState`.**
  Place it near `prDateFormatter` (around line 295–299), as a `private static func`.
  - **Signature:**
    ```
    private static func synthesizedWarmup(forExerciseIndex index: Int) -> [WarmupSet]
    ```
  - **Behavior (exact return values):**
    - `index == 0` → full protocol:
      ```
      [ WarmupSet(reps: 12, label: "Empty bar"),
        WarmupSet(reps: 8,  label: "40%"),
        WarmupSet(reps: 5,  label: "60%"),
        WarmupSet(reps: 3,  label: "80%") ]
      ```
    - `index == 1` → 2-set protocol:
      ```
      [ WarmupSet(reps: 10, label: "50%"),
        WarmupSet(reps: 6,  label: "75%") ]
      ```
    - `index >= 2` (and any negative/out-of-range guard) → `[]` (empty array).
  - Implement as a `switch index` with `case 0`, `case 1`, `default: []`.

- **Do NOT touch:** the demo path (`debugStartPushDayDemo`, line 350), `saveWorkout`, PR update logic, or any `#if DEBUG` block. The demo seed (`ActiveWorkoutSeed`) keeps its own hardcoded warm-ups and is unaffected.

## 📄 FILES TO CREATE

None. This fix is confined to `AppState.buildSession` and one private helper in the same file.

## 🛡️ EDGE CASES TO HANDLE

- **Warm-up already present from the plan/exercise DB:** Exercises pulled through `ExerciseDatabase` may already carry a `warmup` array. The `if w.exercises[i].warmup.isEmpty` guard ensures synthesis is skipped in that case, so a richer, exercise-specific warm-up is never overwritten by the generic percentage ladder.
- **Fewer than 2 exercises in the workout:** A workout with only 1 exercise gets a full protocol on index 0 and no index-1 exercise exists — the loop simply never reaches index 1. A 0-exercise workout (empty-mode path) never calls `buildSession` at all (`startWorkout` branches on `emptyMode` at line 283), so no warm-ups are synthesized there. No extra guard needed beyond the `switch default`.
- **Substituted exercise mid-session:** `WorkoutSessionState.substituteExercise` (line 304) intentionally keeps existing warm-up/PR/history in place. Warm-up synthesis happens once at build time only; substitution correctly does not re-synthesize. No change required — do not add warm-up recomputation to substitution.
