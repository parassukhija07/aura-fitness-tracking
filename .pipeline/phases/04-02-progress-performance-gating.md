# IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate

## ⚠️ OPEN QUESTIONS
None.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Profile tab's General settings screen has a "Show on progress" choice persisted in `AppState.logDisplayMode` (UserDefaults key `aura_logstat`, values exactly `"Strength Score"`, `"Strength Balance"`, or `"Both"` — see `AuraFitness/Models/AppState.swift` around lines 33/94/107). The Progress tab's Stats subtab renders Strength Score and Strength Balance cards (`AuraFitness/Progress/StatsView.swift`) but currently IGNORES this setting — there are zero references to `logDisplayMode` in `AuraFitness/Progress/`. The design requires the cards to obey it: Score-only, Balance-only, or both side-by-side.
- **Existing Patterns to Match:**
  - `AuraFitness/Progress/StatsView.swift` — existing Strength Score / Strength Balance card implementations and their derivation logic (already computed from real user data; do NOT change the math).
  - `AuraFitness/Models/AppState.swift` — read via `@EnvironmentObject var appState: AppState` (already present in `StatsView`).
  - `AuraFitness/Profile/ProfileSettingsScreens.swift` — the writer side of the setting; verify the segmented control writes exactly the three string values above (fix the strings if they drifted — the persistence key comment in `AppState` is the source of truth).
- **Core Strategy:** Pure conditional rendering keyed off `appState.logDisplayMode`. No math changes, no new state.

## 📝 FILES TO MODIFY
### `AuraFitness/Progress/StatsView.swift`
- Locate where the Strength Score card and Strength Balance card render (the "Performance" area).
- Replace unconditional rendering with:
  - `"Strength Score"` → ONLY the Strength Score card (full width).
  - `"Strength Balance"` → ONLY the Strength Balance card (full width).
  - `"Both"` or any unrecognized/legacy value → BOTH cards side-by-side in an `HStack(spacing: AuraSpacing.s3)` with equal widths (`.frame(maxWidth: .infinity)` each). If the cards' internals don't fit side-by-side, use existing compact variants or stack inner content vertically WITHIN each half — but two-cards-in-one-row is the design requirement for "Both".
- The section header stays visible in all three modes.
### `AuraFitness/Profile/ProfileSettingsScreens.swift`
- Verify the "Show on progress" segmented control's options write exactly `"Strength Score"` / `"Strength Balance"` / `"Both"` to `appState.logDisplayMode`. Fix mismatched strings; do not migrate the key.

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Unknown persisted value (old build, corrupted default) must behave as `"Both"` — implement via `switch` with `default:` falling to both.
- Reactivity: flipping the setting in Profile then returning to Progress updates without relaunch (guaranteed by `@EnvironmentObject` + `@Published`; do not cache into local `@State`).
- Side-by-side mode on narrow devices (320 pt): big numbers get `.minimumScaleFactor(0.8)`; content must never overflow the card.
- Do not alter the Strength Score/Balance computation, only presentation.
