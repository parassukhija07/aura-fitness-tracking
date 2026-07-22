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

The repo ships the schema as numbered files in `supabase/migrations/`. `0001_init_schema.sql` creates 12 tables (`aura_workout_logs`, `aura_programs`, `aura_plans`, …), each with an `updated_at` trigger and owner-only Row Level Security; later files add the delta-pull RPC, deletion tombstones, payload guardrails, photo storage, and function hardening. **Run every file, in numeric order** — they build on each other. Two ways to apply them; the Dashboard way is simpler:

**Option A — Dashboard (recommended, no CLI needed):**

1. In the Supabase dashboard, open **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `supabase/migrations/0001_init_schema.sql` from this repo in any text editor, copy its **entire** contents, paste into the SQL editor.
4. Click **Run**. You should see "Success. No rows returned".
5. Repeat 2–4 for each remaining file **in order**: `0002_pull_changes_rpc.sql`, `0003_deletions_tombstones.sql`, `0004_pull_changes_v2.sql`, `0005_payload_guardrails.sql`, `0006_progress_photos_storage.sql`, `0007_function_hardening.sql`, `0008_exercise_catalog.sql`, `0009_exercise_media_bucket.sql`.
6. Verify: go to **Table Editor** — you should see 12 tables all prefixed `aura_`, plus `aura_deletions`, `aura_exercise_catalog`, and `aura_catalog_meta`.

> `0007_function_hardening.sql` is what clears the four warnings the **Database → Linter** page reports (`function_search_path_mutable` ×2, `*_security_definer_function_executable` ×2). It also takes `purge_old_deletions()` off the public REST API — it was callable by anyone holding the anon key. If you ever re-run `0003` on its own, re-run `0007` after it: `0003` would otherwise put `record_deletion()` back to `security invoker`, which combined with the revoke makes roughly one delete in a thousand fail. The file's header explains why.

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

Storage is **not** covered by that cascade — there is no foreign key from a storage object to `auth.users` — so the function also empties the user's `progress-photos/<user-id>/` folder before deleting the account. Storage is purged first and the auth user last on purpose: if the purge fails the account still exists and the user can retry, whereas the reverse order would strand photos nobody could ever authenticate to delete.

> **Re-run `supabase functions deploy delete-account` after pulling changes to this function.** A deployed function is a snapshot — editing the file in the repo does nothing until it is redeployed. An older deployment still deletes the account correctly; it just leaves the photos behind.

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
2. **Authentication → URL Configuration** → **Site URL**: change the default `http://localhost:3000` to:

   ```
   aurafitness://auth-callback
   ```

   Site URL is the fallback target for any link that does not carry its own `redirect_to` — which is the case for the **sign-up confirmation** email (`signUp` deliberately sends none). Left at `localhost:3000`, confirming a new account still works (GoTrue marks the email confirmed *before* redirecting) but dumps the user on a dead browser page they have to back out of by hand. Pointed at the callback, the link deep-links into the app and `handleAuthCallback` signs them in. Wildcards are not allowed in this field, and none are needed.

3. Same screen → **Redirect URLs** → add BOTH of these:
   - `aurafitness://auth-callback`
   - `aurafitness://auth-callback**`

   The second (glob) entry is not optional: the password-reset link IS sent with an explicit `redirect_to=aurafitness://auth-callback?flow=recovery`, and the plain entry does not match a URL carrying query parameters. Without it Supabase refuses the redirect and the reset mail dead-ends. See `AuthService.passwordResetRedirectURL` for why the marker exists.
4. **Authentication → Email Templates** is locked ("Set up custom SMTP to edit templates") until you configure your own sender — that is fine and **blocks nothing here**. The default `Reset Password` template already uses `{{ .ConfirmationURL }}`, which honours the `redirect_to` the app sends, so the deep link works untouched.

   Custom SMTP is still worth doing before you test seriously, for two reasons that have nothing to do with editing templates:
   - Supabase's **default sender only delivers to members of your Supabase organisation**. A reset link sent to any other address is dropped silently — the app shows "a reset link is on its way" (it must, to avoid user enumeration) and no mail ever arrives.
   - The default sender is rate-limited to roughly **2 emails per hour**, which you will hit quickly while testing sign-up + reset together.

   Configure it under **Project Settings → Auth → SMTP**. Free tiers that work: Resend, Brevo, Mailgun.

---

## Step 7b — Declare the `aurafitness` URL scheme in Xcode (≈2 min)

Password reset and login-email change both send the user out to their mailbox and back into the app via a deep link. iOS only delivers that link if the app declares the scheme — **this cannot be committed for you**, because the target uses `GENERATE_INFOPLIST_FILE = YES` and `CFBundleURLTypes` is an array of dictionaries, which the `INFOPLIST_KEY_…` build-setting passthrough (the trick `AuthConfig` relies on) cannot express.

1. Open the project in Xcode → select the **AuraFitness** target → **Info** tab.
2. Expand **URL Types** → click **+**.
   - **Identifier**: `com.aurafitness.app`
   - **URL Schemes**: `aurafitness`
   - **Role**: `Editor`
3. Xcode will materialise an `Info.plist` for the target and point `INFOPLIST_FILE` at it. That is expected — `GENERATE_INFOPLIST_FILE` stays `YES` and the existing `INFOPLIST_KEY_SUPABASE_*` values keep merging in, so **do not** remove them.
4. Build once and confirm the app still launches (a broken Info.plist wiring shows up as the DEBUG `fatalError` in `AuthConfig`).
5. Commit the resulting `Info.plist` and `project.pbxproj` change.

**Test the reset flow end to end** (needs Steps 1–3 and 7):
1. Run the app → **Forgot password?** → enter an email you control → you should see "If an account exists for that email, a reset link is on its way." (that copy is deliberately identical for unknown addresses — no user enumeration).
2. Open the mail on the same device/simulator → tap the link → the app should foreground with a **Set a new password** sheet.
3. Enter a new password twice (min 6 chars) → **Save password** → you land signed in.
4. Tapping the same link a second time should now show "That link has expired. Request a new one."

**Login-email change**: Profile → Account Details → edit **Email** → **Save Changes** → confirm the alert. Supabase's default is double confirmation (a link to the old address *and* the new one); the app says "Confirm the change from the link sent to your new address" and keeps showing the OLD address until the change actually lands. If you want single confirmation, turn OFF **Authentication → Providers → Email → "Secure email change"**.

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

## Step 10 (optional) — Seed the global exercise catalog (≈3 min)

Step 2's `0008_exercise_catalog.sql` created two empty tables: `aura_exercise_catalog` (the exercise library, world-readable) and `aura_catalog_meta` (a single `catalog_version` row). Seeding them lets you fix a typo, replace a dead tutorial link, or add an exercise **without shipping an App Store release** — the app pulls the new catalog at its next launch.

Skipping this is safe. With the tables empty the app reads no version marker and keeps the library bundled in the binary, exactly as it behaves today.

1. In **SQL Editor**, click **New query**.
2. Open `supabase/seed/seed_exercise_catalog.sql` from this repo, copy its **entire** contents (it is ~150 KB — make sure you get all of it), paste, **Run**.
3. Verify: **Table Editor** → `aura_exercise_catalog` shows 137 rows, and `aura_catalog_meta` shows one row, `catalog_version` = `1`.
4. Confirm it is genuinely read-only: in **SQL Editor**, run
   ```sql
   set role anon;
   delete from aura_exercise_catalog;
   ```
   This must fail with `42501` / "new row violates row-level security policy". Then run `reset role;`. If the delete SUCCEEDS, stop and re-run `0008_exercise_catalog.sql`.

**To ship a catalog update later:** edit `AuraFitness/Resources/gym_exercise_library.json`, bump `CATALOG_VERSION` in `supabase/seed/generate_seed.py`, run `python supabase/seed/generate_seed.py`, commit the regenerated SQL, and repeat steps 1–3 above. Apps notice the changed version on their next launch and pull the whole catalog. Never rename an exercise expecting the old row to follow it — ids are derived from the name, so a rename creates a new row and the old one stays put for older clients.

---

## Step 11 (optional) — Host exercise images yourself (≈5 min)

Every exercise's thumbnail currently points at an unsplash.com URL baked into the bundled library JSON. Those are third-party links: they can rot, rate-limit, or vanish, and each one leaks a request off-platform every time a grid scrolls. This step moves the imagery into a **public** Supabase Storage bucket you control.

Skipping this is safe and changes nothing — the app keeps using the existing URLs, and any exercise with no image at all already falls back to a muscle-tinted gradient.

1. Create the bucket. In **Storage** → **New bucket**, name it `exercise-media` and turn **Public** ON. (CLI equivalent: `supabase storage buckets create exercise-media --public`.) The bucket cannot be created from SQL, which is why Step 2's `0009_exercise_media_bucket.sql` only adds the read policy.
2. Drop your images into `supabase/seed/exercise-media/` in this repo, named after the exercise — lowercase, spaces as `-`, e.g. `barbell-bench-press.jpg`. Read that folder's `README.md` first: it covers the 200 KB budget, the aspect ratio, and the licensing requirement (the images are re-hosted publicly with no attribution surface, so the licence must permit redistribution).
3. Regenerate, with your project ref (the subdomain of your Supabase URL):
   ```bash
   python supabase/seed/generate_seed.py --project-ref <your-project-ref>
   ```
   Read the WARNING lines — a filename that matches no exercise is skipped, and that is how a typo silently costs one exercise its picture.
4. Upload the images (the script is generated by step 3, one `supabase storage cp` per image):
   ```bash
   supabase link --project-ref <your-project-ref>
   bash supabase/seed/upload_media.sh
   ```
5. Apply the regenerated `supabase/seed/seed_exercise_catalog.sql` exactly as in Step 10 — the rows now carry your bucket's URLs.
6. Confirm the bucket is read-only to everyone else: with the **anon** key configured, try `supabase storage cp ./any.jpg ss:///exercise-media/probe.jpg`. It must FAIL with 403. If it succeeds, a write policy leaked in and any user can overwrite your imagery — stop and re-run `0009_exercise_media_bucket.sql`.

**Never put user content in this bucket.** It is world-readable with no auth check at all. Progress photos live in `progress-photos`, which is private and owner-only (Step 2's `0006`). For the same reason `exercise-media` is deliberately absent from the delete-account function's purge list: it is shared, so wiping it on one account's deletion would destroy every other user's imagery.

Steps 4 and 5 must both run. Uploading without re-seeding leaves rows on the old URLs; re-seeding without uploading points them at objects that 404 (harmless — the gradient covers it — but you get no pictures).

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
| 7 | Auth email settings + redirect URLs | Browser | Sign-up + password reset |
| 7b | Declare `aurafitness://` URL scheme | Mac + Xcode | Password reset + email change |
| 8 | Verify CI green | Browser | Release artifact |
| 9 | Pin Package.resolved | Mac + Xcode | CI reproducibility (optional) |
| 10 | Seed exercise catalog | Browser (SQL editor) | Over-the-air library updates (optional) |
| 11 | Create `exercise-media` bucket + upload images | Browser + Supabase CLI | First-party exercise imagery (optional) |
