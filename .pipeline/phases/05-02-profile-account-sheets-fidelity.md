# IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets

## ⚠️ OPEN QUESTIONS
None. Audit-and-fix. The heavy lifting (real export, reset, delete-account, HealthKit) already exists and is correct — this spec is about exact UI composition and copy.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). Profile sub-screens: Account Details (`AuraFitness/Profile/AccountDetailsView.swift`), Units & Measurements + Connected Apps + Support (in `ProfileSettingsScreens.swift`), backed by real services: `DataArchive.swift`/`CSVArchive.swift` (export), `DataResetService.swift` (reset/delete), `HealthKitService.swift` (Apple Health), `AuthService.swift` (auth). Four confirm sheets exist around export/reset/delete/logout.
- **Existing Patterns to Match:**
  - `AuraFitness/Profile/AccountDetailsView.swift` — field editing + `syncBodyAndProfile` onChange wiring (keep).
  - `AuraFitness/Log/LogSheetsView.swift` — bottom-sheet composition idiom (header + rows + cancel).
  - `SettingsGroup` / `SettingsControlRow` from `ProfileTabView.swift`.
  - Services listed above — call them; never reimplement their logic.
- **Core Strategy:** Verify each screen/sheet against its checklist; minimal diffs; copy strings exact.

## 📝 FILES TO MODIFY
### `AuraFitness/Profile/AccountDetailsView.swift`
1. Avatar + "Change photo" (existing photo-picker or stub toast — keep whichever exists).
2. Editable fields in order: First name, Last name, Email, Phone, Birthday (date picker), Gender (menu/select), Height, Country, City, State. Birthday/gender changes keep firing the existing Body-sync `onChange`.
3. **Data section:** "Export Data" row → export sheet; "Reset Data" row → reset sheet; "Delete Account" row in `.aura.red` → delete sheet.
4. "Save Changes" button returns to the hub with a brief confirmation flash.
### `AuraFitness/Profile/ProfileSettingsScreens.swift`
- **Units & Measurements:** two segmented rows — Weight unit (Kilograms / Pounds), Length unit (Centimeters / Inches); changes propagate app-wide instantly via the existing `UnitFormatter`-backed settings.
- **Connected Apps:** Apple Health toggle with live "Connected"/"Not connected" sub-text driven by the REAL `HealthKitService` state (existing behaviour — verify the sub-text, don't fake the state). Include the info card: "Aura syncs workouts and body weight two-way with Apple Health." Do NOT re-add Google Health (removed by audit M11 on iOS).
- **Support:** rows "User Guides & FAQ", "Contact Us", "Feature Request" (stub actions/toasts acceptable), then version footer exactly "Aura Fitness · v{CFBundleShortVersionString}" in `.aura.text3` (read the real bundle version — no hardcoded number).
- **Four confirm sheets** (shared renderer welcome):
  1. **Export:** title "Export Data", body "CSV + JSON archive of all your data.", primary "Export Archive" → existing `DataArchive`/ShareLink flow.
  2. **Reset:** title "Reset Data", TWO options — "Reset workout data only" (keeps profile) and "Reset everything" (red) → `DataResetService.resetAll(workoutOnly:alsoRemote:)` with matching flags; each option confirms before executing.
  3. **Delete:** title "Delete account?", body "This cannot be undone.", red destructive confirm → existing delete-account Edge-Function flow in `DataResetService`/`AuthService`.
  4. **Logout:** title "Log out?", body "You can log back in anytime.", primary confirm → `AuthService` sign-out. (Presented from the hub — coordinate with 05-01; if 05-01 already added it, just verify.)

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Delete account with no network: surface the service's error (alert) and do NOT wipe local data — local wipe only on confirmed remote success (existing H8 behaviour; do not regress).
- Reset "workout only" must leave profile fields, units, and measurements intact — verify against `DataResetService`'s key list.
- Email field: basic format validation before Save (non-blocking for other fields).
- Every sub-screen needs a working back-to-Profile header (no dead ends).
- Export on a device with nothing to export: still produces a valid (mostly empty) archive rather than failing.
