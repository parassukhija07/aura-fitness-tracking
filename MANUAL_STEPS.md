# Aura Fitness — Manual Steps Required

These are the steps that **only you** can perform (they need your Supabase account, your Mac with Xcode, or your Apple Developer account). Everything code-side is already committed. Work through them in order — later steps depend on earlier ones.

Estimated total time: ~45–60 minutes.

---

## Step 1 — Create the Supabase project (≈10 min)

The app's login, signup, and cloud sync all talk to Supabase. Without this, the app builds fine but every auth/sync call fails at runtime.

1. Go to <https://supabase.com> and sign in (create a free account if needed).
2. Click **New project**.
   - Organization: your personal org is fine.
   - Name: `aura-fitness` (any name works).
   - Database password: generate a strong one and **save it somewhere safe** (you'll rarely need it, but losing it is painful).
   - Region: pick the one closest to you (e.g. `ap-south-1` Mumbai).
3. Wait ~2 minutes for provisioning to finish.
4. Once the dashboard opens, go to **Project Settings → API** and copy two values:
   - **Project URL** — looks like `https://abcdefghijk.supabase.co`
   - **anon / public key** — a long JWT string starting with `eyJ...`

   Keep this tab open — you need both values in Step 3.

> ⚠️ Never copy the `service_role` key into the app. The app only ever uses the **anon** key. The service role key is used automatically by the Edge Function runtime (Step 4) — you never paste it anywhere.

---

## Step 2 — Apply the database schema (≈5 min)

The repo ships the full schema at `supabase/migrations/0001_init_schema.sql` — 12 tables (`aura_workout_logs`, `aura_programs`, `aura_plans`, …), each with an `updated_at` trigger and owner-only Row Level Security. Two ways to apply it; the Dashboard way is simpler:

**Option A — Dashboard (recommended, no CLI needed):**

1. In the Supabase dashboard, open **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `supabase/migrations/0001_init_schema.sql` from this repo in any text editor, copy its **entire** contents, paste into the SQL editor.
4. Click **Run**. You should see "Success. No rows returned".
5. Verify: go to **Table Editor** — you should see 12 tables all prefixed `aura_`.

**Option B — CLI (if you have the Supabase CLI installed):**

```bash
supabase login
supabase link --project-ref <your-project-ref>   # the abcdefghijk part of your URL
supabase db push
```

---

## Step 3 — Wire the secrets into Xcode (≈10 min, needs your Mac)

The app reads the Supabase URL + anon key from `Secrets.xcconfig`, which is git-ignored (so secrets never land in the repo). You must create it locally and tell Xcode about it.

1. On your Mac, in the repo folder, copy the template:

   ```bash
   cd AuraFitness
   cp Secrets.xcconfig.template Secrets.xcconfig
   ```

2. Open `AuraFitness/Secrets.xcconfig` in any editor and fill in the two values from Step 1:

   ```
   SUPABASE_URL = https://abcdefghijk.supabase.co
   SUPABASE_ANON_KEY = eyJhbGciOi...your-anon-key...
   ```

3. Open `AuraFitness.xcodeproj` in Xcode.
4. In the Project navigator, click the **blue project icon** (top-most "AuraFitness").
5. Make sure the **project** (not the target) is selected in the editor's sidebar, then open the **Info** tab.
6. Under **Configurations**, expand both **Debug** and **Release**.
7. For the `AuraFitness` **target row** under each configuration, click the dropdown in the "Based on Configuration File" column and select **Secrets.xcconfig**.
8. Build & run once on the simulator. If the config is wrong, a DEBUG build crashes immediately with a descriptive `fatalError` telling you exactly which of these sub-steps was missed — that's intentional.

> Why this works: the target's build settings contain `INFOPLIST_KEY_SUPABASE_URL = $(SUPABASE_URL)` (and the anon-key twin). Xcode lifts any `INFOPLIST_KEY_*` setting into the generated Info.plist, where `AuthConfig.swift` reads it at launch.

---

## Step 4 — Deploy the delete-account Edge Function (≈5 min, needs Supabase CLI)

"Delete Account" in the app calls a privileged server function (an anon client can't delete an auth user). The function code is already in the repo at `supabase/functions/delete-account/index.ts`.

1. Install the Supabase CLI if you don't have it:
   - macOS: `brew install supabase/tap/supabase`
   - Windows: `scoop install supabase` (or download from GitHub releases)
2. From the repo root:

   ```bash
   supabase login                                   # opens browser, one-time
   supabase link --project-ref <your-project-ref>
   supabase functions deploy delete-account
   ```

3. Verify: in the Supabase dashboard → **Edge Functions**, `delete-account` should be listed as deployed.

The function automatically receives `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ANON_KEY` from the project runtime — you do **not** set any secrets for it.

Because every `aura_*` table has `on delete cascade` foreign keys to `auth.users`, deleting the user wipes all their rows automatically.

> Until this is deployed, everything else works; only the "Delete Account" button will show "Something went wrong".

---

## Step 5 — Add the HealthKit capability in Xcode (≈3 min)

`AuraFitness/AuraFitness.entitlements` is already in the repo, but the entitlement only takes effect once the capability is registered with your signing setup. Without it, the "Apple Health" toggle in Connected Apps silently fails to turn on (runtime failure only — CI is unaffected because CI builds unsigned).

1. In Xcode, select the **AuraFitness target** → **Signing & Capabilities** tab.
2. Ensure your Team is selected under Signing (personal team is fine for device testing).
3. Click **+ Capability** (top-left of the pane) → search **HealthKit** → double-click to add.
4. Xcode will link the existing `AuraFitness.entitlements`. If it instead generates a *second* entitlements file, delete the older one and keep Xcode's — two entitlement files fighting over one build setting causes confusing signing errors.
5. If Xcode complains about the App ID, let it "Register" / auto-fix — it usually offers a one-click resolution.

---

## Step 6 — Bundle the exercise library JSON (≈2 min)

`gym_exercise_library.json` (repo root) holds the full exercise library, but it is **not currently part of the app bundle** — so the app silently falls back to an 11-exercise hardcoded list. To ship the full library:

1. In Xcode's Project navigator, right-click the `AuraFitness` group (yellow folder) → **Add Files to "AuraFitness"…**
2. Navigate up one level to the repo root and select `gym_exercise_library.json`.
3. In the dialog, make sure:
   - ✅ **Copy items if needed** is checked
   - ✅ **AuraFitness** target is checked under "Add to targets"
4. Click **Add**.
5. Verify: target → **Build Phases** → **Copy Bundle Resources** now lists `gym_exercise_library.json`.
6. Commit the resulting `project.pbxproj` change (and the copied file if Xcode moved it into the `AuraFitness/` folder).

> Important: if you had already run the app before this step, the 11-exercise fallback is persisted in UserDefaults. Delete the app from the simulator/device once (or use Profile → Reset Data) so `ExerciseDatabase` re-seeds from the JSON.

---

## Step 7 — Confirm email settings in Supabase Auth (≈3 min)

Sign-up in the app requires email confirmation (the app shows a "Check your email" screen and refuses login until confirmed).

1. Supabase dashboard → **Authentication → Providers → Email**: confirm **Email** is enabled and "Confirm email" is ON (it is by default).
2. **Authentication → URL Configuration**: the defaults are fine for now (the confirmation link opens in a browser; the user then returns to the app and logs in).
3. Optional but recommended before real users: **Authentication → Email Templates** — the default sender is Supabase's shared SMTP with tight rate limits (~3 emails/hour). For anything beyond your own testing, configure custom SMTP under **Project Settings → Auth → SMTP**.

**Quick end-to-end test after Steps 1–4:**
1. Run the app in the simulator → Sign Up with a real email you control.
2. App shows "Check your email" → click the link in the mail → return to app → **Back to Login** → log in.
3. Log a workout, then check the Supabase **Table Editor** → `aura_workout_logs` — a row should appear within seconds.

---

## Step 8 — Verify CI is green (≈2 min)

A fix was pushed as commit `58c8ebd` ("add 4 missing Swift files to Xcode target Sources phase") which should resolve all 36 compile errors from the last failed run.

1. Open <https://github.com/parassukhija07/aura-fitness-tracking/actions>.
2. Find the newest **CI** run on `fix/c1-merge-corruption` (triggered by `58c8ebd`).
3. If it's green: done — the run's **Artifacts** section contains `AuraFitness-unsigned-<n>.ipa`.
4. If it's red: open the failed **Build** step and look at the first `❌` line. Most likely candidate would be a "compiler unable to type-check this expression in reasonable time" in `AppState.swift` or `LogSheetsView.swift` — paste the log into a Claude session and it can split the offending expression.

---

## Step 9 (optional but recommended) — Pin SPM dependency versions

CI currently re-resolves all Swift Package versions on every run (no `Package.resolved` is committed). This already broke the build once when a transitive dependency published a version requiring a newer compiler.

1. On your Mac, open the project in Xcode and let packages resolve (File → Packages → Resolve Package Versions).
2. Commit the generated file:

   ```bash
   git add AuraFitness.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
   git commit -m "chore: pin SPM dependency versions for reproducible CI"
   git push
   ```

---

## Quick checklist

| # | Step | Needs | Blocks |
|---|------|-------|--------|
| 1 | Create Supabase project | Browser | All auth + sync |
| 2 | Apply DB schema | Browser (SQL editor) | All sync |
| 3 | Secrets.xcconfig + Xcode wiring | Mac + Xcode | App launch (DEBUG crashes without it) |
| 4 | Deploy delete-account function | Supabase CLI | Delete Account button only |
| 5 | HealthKit capability | Mac + Xcode | Apple Health toggle only |
| 6 | Bundle exercise JSON | Mac + Xcode | Full exercise library (falls back to 11) |
| 7 | Auth email settings + E2E test | Browser | Sign-up flow quality |
| 8 | Verify CI green | Browser | Release artifact |
| 9 | Pin Package.resolved | Mac + Xcode | CI reproducibility (optional) |
