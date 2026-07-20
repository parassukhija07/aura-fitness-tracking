# BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
One owner-manual dependency (not a code blocker): Supabase Dashboard → Auth → URL Configuration must register the redirect URL `aurafitness://auth-callback`, and the app target must declare that custom URL scheme. Code assumes the scheme; document both steps in code comments and `MANUAL_STEPS.md`.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). `AuraFitness/Auth/AuthService.swift` implements ONLY `signUp(email:password:)`, `signIn(email:password:)`, and session restore. Users who forget a password are locked out permanently, and the Profile → Account screen's email field cannot actually change the login email. This feature adds both flows via Supabase Auth built-ins (no server code — Supabase hosts the endpoints). Unblocks frontend Phase 5 (Profile tab, spec `05-02` Account screen).
- **Existing Patterns to Match:**
  - `AuraFitness/Auth/AuthService.swift` — `@MainActor` service, `async -> Bool` + published error-message pattern of `signIn`/`signUp`; follow exactly for new methods.
  - `AuraFitness/Auth/AuthGateView.swift` — form/section styling for the new "Forgot password?" UI.
  - `AuraFitness/Profile/AccountDetailsView.swift` — email field location; email-change entry point.
- **Data Schemas / Type Definitions:** none new (Supabase `auth.users` managed).
- **API Request/Response Contracts:** (all served by Supabase Auth — client calls via supabase-swift SDK)
  - **Endpoint:** `POST /auth/v1/recover` (SDK: `client.auth.resetPasswordForEmail(email, redirectTo: URL("aurafitness://auth-callback"))`)
    - **Payload:** `{"email":"user@example.com"}` → **Success (200):** `{}` (email sent). **Errors:** 429 `{"error_code":"over_email_send_rate_limit","msg":"For security purposes, you can only request this once every 60 seconds"}`; unknown email ALSO returns 200 (no user enumeration — show the SAME neutral UI message either way).
  - **Endpoint:** `PUT /auth/v1/user` — new password after user returns via deep link (SDK: `client.auth.update(user: UserAttributes(password: newPassword))` inside the recovery session established from the callback URL via `client.auth.session(from: url)`).
    - **Errors:** 422 `{"error_code":"weak_password","msg":"Password should be at least 6 characters"}`; 401 expired link `{"error_code":"otp_expired","msg":"Email link is invalid or has expired"}`.
  - **Endpoint:** `PUT /auth/v1/user` — email change (SDK: `client.auth.update(user: UserAttributes(email: newEmail))`)
    - **Success (200):** user object with `new_email` pending; Supabase sends confirmation link(s); email flips only after confirmation. **Errors:** 422 `{"error_code":"email_exists","msg":"A user with this email address has already been registered"}`.

## 📝 FILES TO MODIFY
### `AuraFitness/Auth/AuthService.swift`
- Add, matching existing method style:
  - `func requestPasswordReset(email: String) async -> Bool`
  - `func completePasswordReset(newPassword: String) async -> Bool` (valid only in a recovery session)
  - `func handleAuthCallback(url: URL) async -> Bool` — feeds `client.auth.session(from: url)`; returns whether a recovery session is active (drives the "set new password" sheet)
  - `func requestEmailChange(to newEmail: String) async -> Bool`
- Published `var isRecoverySession: Bool` for the UI gate.
### `AuraFitness/AuraFitnessApp.swift`
- `.onOpenURL { url in Task { await <authService>.handleAuthCallback(url: url) } }` — adapt to how the service is actually held (env object vs singleton; match existing wiring).
### `AuraFitness/Auth/AuthGateView.swift`
- "Forgot password?" link under the sign-in form → email-entry sheet → `requestPasswordReset`; neutral confirmation copy: "If an account exists for that email, a reset link is on its way."
- When `isRecoverySession` turns true: present "Set new password" sheet (new password + confirm, min 6 chars) → `completePasswordReset` → normal signed-in flow.
### `AuraFitness/Profile/AccountDetailsView.swift`
- Email Save path: when the entered email differs from the session's email, call `requestEmailChange`; on success show "Confirm the change from the link sent to your new address." Display email updates only after the session reflects it (listen to auth state refresh).

## 📄 FILES TO CREATE
None.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- No user enumeration: identical neutral message for existing and unknown emails; never branch UI on 200-vs-error beyond rate-limit messaging.
- Rate limit (429): "Please wait a minute before requesting another link." — no auto-retry.
- Recovery deep link while another user is signed in: `session(from:)` replaces the session — acceptable (standard Supabase behaviour), but sync must pull for the new uid afterward (route recovery completion through the existing post-sign-in hook).
- Email-change double-confirmation is Supabase default — copy must not promise instant change.
- Passwords never logged; client mirrors server minimum length (6) to save a round-trip.
