# Aura Fitness — Backend Roadmap (Supabase), Phase-Matched to Frontend

Backend stack: **Supabase** (Postgres + RLS, Auth, Edge Functions/Deno, Storage). No custom Node server exists or is planned.
Existing baseline (verified): `supabase/migrations/0001_init_schema.sql` (12 `aura_*` tables — `id`/`user_id`/`payload jsonb`/`updated_at`, owner-only RLS, LWW `updated_at` trigger), `supabase/functions/delete-account/index.ts`, client sync layer `AuraFitness/Sync/SupabaseSyncService.swift` (write-through push + offline queue + full-table `pullAll` with LWW merge) and `AuraFitness/Auth/AuthService.swift` (email sign-up/sign-in/restore only).

Frontend phase alignment (frontend specs live in `.pipeline/phases/`):

| Backend phase | Supports frontend | Theme |
|---|---|---|
| B1 | FE Phases 1–2 (Log, Active Workout — shipped) | Sync engine hardening: delta pull, tombstones, payload guardrails |
| B2 | FE Phase 3 (Plan tab) | Content sync policy: stop per-user duplication of predefined programs |
| B3 | FE Phase 4 (Progress tab) | Progress photos → Supabase Storage; delete-account storage cleanup |
| B4 | FE Phase 5 (Profile tab) | Auth flows completion: password reset, email change |
| B5 | FE Phase 6 (platform: library JSON, remote images) | Global exercise catalog table + public exercise-media bucket |

| Spec | Feature |
|---|---|
| `phase1-01-delta-pull-rpc.md` | One-call incremental sync: `pull_changes(since)` RPC |
| `phase1-02-sync-tombstones.md` | Deletion tombstones — stop deleted-row resurrection |
| `phase1-03-payload-guardrails.md` | JSONB size/shape constraints, index audit |
| `phase2-01-predefined-content-sync-policy.md` | Sync only user-owned content; purge duplicated seeds |
| `phase3-01-progress-photos-storage.md` | `progress-photos` private bucket + client migration off base64 |
| `phase3-02-delete-account-storage-cleanup.md` | Edge Function: also wipe Storage objects |
| `phase4-01-auth-flows-completion.md` | Password reset + email change |
| `phase5-01-exercise-catalog-table.md` | Versioned global `aura_exercise_catalog` (read-only) |
| `phase5-02-exercise-media-bucket.md` | Public `exercise-media` bucket + seeding procedure |

Owner-manual steps (cannot be automated from repo; see `MANUAL_STEPS.md`): Supabase project link, `Secrets.xcconfig`, `supabase db push`, `supabase functions deploy`, Storage bucket creation confirmations, Auth email template/redirect config.
Execution order: B1 → B5 sequential; within a phase, files in listed order.
