# IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity

## ⚠️ OPEN QUESTIONS
None. Audit-and-fix against the checklists; leave conforming code untouched.

## 🏗️ ARCHITECTURE & PATTERNS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS). The Profile tab (`AuraFitness/Profile/ProfileTabView.swift`) is a root hub (identity card + stat tiles + grouped setting rows) pushing sub-screens defined in `ProfileSettingsScreens.swift` and `WorkoutSettingsView.swift`. Three settings are cross-tab writers: theme (dark mode), week-start, and "show on progress" — all persisted in `AppState`. Most of this is built; this spec pins the exact design details.
- **Existing Patterns to Match:**
  - `AuraFitness/Profile/ProfileTabView.swift` — `AvatarCircle`, `SettingsGroup`, `SettingsRowLabel`, `SettingsControlRow`, derived stats (`totalSessions`, `streak`); keep these components.
  - `AuraFitness/Models/AppState.swift` — `darkModePreference`, `calendarStartDay`, `logDisplayMode`, and the workout-default settings (default sets / rep range / rest values / auto-rest / auto-video / show-first / show-PRs) with their persistence.
  - `AuraFitness/Profile/WorkoutSettingsView.swift` + `ProfileSettingsScreens.swift` — the push-screen implementations to audit.
  - `NotificationScheduler` (`AuraFitness/ActiveWorkout/NotificationScheduler.swift`) — authorization + rest-notification wiring (audit M10, already correct).
- **Core Strategy:** Walk each checklist; minimal diffs. No persistence-key changes, no new screens.

## 📝 FILES TO MODIFY
### `AuraFitness/Profile/ProfileTabView.swift` (root hub)
1. **Identity card** (tap → Account Details): gradient initials avatar, "{first} {last}", sub-line exactly "{age} · {height} · {weight} · {gender}" with height/weight through `UnitFormatter` and any unset field dropped (no "nil", no double separators). Verify tap routes to the same Account screen as the Account row.
2. **Three stat tiles:** Sessions (real `workoutLogs.count`) · PRs (real distinct-PR count, consistent with the Progress tab's number) · Week streak (existing `streak` derivation). No hardcoded numbers.
3. **Setting groups** in exact order: Group 1: General · Workout · Notifications; Group 2: Account Details · Units & Measurements · Connected Apps; Group 3: Support. The Units row shows a LIVE sub-text of current units (e.g. "kg · cm"); the Connected Apps row shows "Apple Health connected" / "Not connected" live.
4. **Log Out** row (red) → confirm sheet: title "Log out?", sub-line "You can log back in anytime.", primary confirm + cancel. Wire to the existing `AuthService` sign-out.
### `AuraFitness/Profile/ProfileSettingsScreens.swift` (General, Notifications)
- **General:** Dark Mode toggle (sub-line "Applies across the app") → `darkModePreference`; "Start week on" Sun/Mon segmented → `calendarStartDay` (drives Log + Plan week strips — verify both react); "Show on progress" segmented Strength score / Balance / Both → `logDisplayMode` (exact strings "Strength Score" / "Strength Balance" / "Both").
- **Notifications:** Enable-notifications toggle (requests authorization on enable via `NotificationScheduler`); below it a "Rest timer sound" list with two options **Ding** and **Alarm clock**, the selected one check-marked. When notifications are OFF the whole sound list renders dimmed (`.opacity(0.45)`) and non-interactive (`.disabled(true)`) — not hidden.
### `AuraFitness/Profile/WorkoutSettingsView.swift` (Workout)
- **Display section:** "Show first" segmented Reps·time / Weight; "Show PRs during workout" toggle.
- **Exercise targets:** Default sets stepper (1–10); Default rep range as TWO interlocked steppers — low's maximum capped at current high, high's minimum capped at current low (crossing impossible); "Rest between sets" and "Rest between exercises" steppers 15–300 s in steps of 15, displayed "1 min 30 s" style (values < 60 → "45 s").
- **Automation:** "Auto rest timer" and "Auto-play video" toggles.
- All bound to the existing `AppState` published settings — verify each persists AND is read by the Active Workout session builder (`buildSession` uses default sets/reps/rest; auto-rest gates `startRest(automatic: true)`).

## 📄 FILES TO CREATE
None.

## 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE
- Rep-range interlock: from low==high it must allow raising high and lowering low, but never low>high.
- Notification permission DENIED at OS level: the enable toggle snaps back off and shows an alert directing to Settings (check `UNUserNotificationCenter` authorization status on toggle).
- Sub-text liveness: changing units on the Units screen then popping back must update the hub row immediately (no stale cache).
- Dark-mode toggle must not flash/reset scroll position (apply via the existing `preferredColorScheme` binding in `ContentView`).
- Do not rename any persisted UserDefaults keys.
