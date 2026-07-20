# Aura Fitness — Remaining Build: Phase Index

Design source of truth: `App onboarding (10).zip` (claude.ai design bundle — handoff chapters 1–8).
Phases 1 (Log shell/icon/fonts, commit `a9fa7bf`) and 2 (Active Workout fidelity, commit `a623c63`) are DONE.
Log tab behaviour updates (LOG-01b/c/d/e, past/future day states) are DONE and verified in `AuraFitness/Log/`.
The flat 4-icon tab bar (no FAB, no glass pill) is a SETTLED product decision from Phase 1 — do not re-add FAB.

Each spec below is fully self-contained and handed to the implementing agent alone.
Order within a phase matters; phases are sequential.

## Phase 3 — Plan tab completion (design ch. 4, largest chapter)
| Spec | Feature |
|---|---|
| `03-01-plan-workout-editor-redesign.md` | Design-faithful workout editor (cards, rest ladder pickers, ⋯ menu, reorder) |
| `03-02-plan-supersets-exercise-picker.md` | Supersets in editor + 3-mode exercise picker (substitute / add-after / superset-new) |
| `03-03-plan-exercise-detail-parity.md` | Exercise detail: History tab (Epley PBs), Workout tab (editor context), action bar |
| `03-04-plan-program-detail-editor-fidelity.md` | Program detail + program editor to exact design |
| `03-05-plan-sheets-create-workout-theming.md` | 5 plan sheets, create-workout 12-icon grid, keyword colour/icon theming |

## Phase 4 — Progress tab fidelity (design ch. 6)
| Spec | Feature |
|---|---|
| `04-01-progress-heatmap-outcomes.md` | 5-level heatmap intensities from real session outcomes + legend + month nav |
| `04-02-progress-performance-gating.md` | Strength Score/Balance cards gated by Profile "Show on progress" setting |
| `04-03-progress-trends-chart-prs.md` | Labelled axis chart (nice ticks), ranges w/ 1M weekly interpolation, delta badge, PR chips |
| `04-04-progress-body-measurements-photos.md` | Measurements hero card + labelled trend chart + range toggle + metric chips grid |
| `04-05-progress-nutrition-fidelity.md` | Nutrition calculator exact-formula verification + design layout parity |

## Phase 5 — Profile tab fidelity (design ch. 7)
| Spec | Feature |
|---|---|
| `05-01-profile-hub-settings-fidelity.md` | Root hub, General / Workout / Notifications screens exact-match |
| `05-02-profile-account-sheets-fidelity.md` | Account / Units / Connected / Support screens + 4 confirm sheets |

## Phase 6 — Data & platform completion
| Spec | Feature |
|---|---|
| `06-01-bundle-exercise-library-json.md` | Bundle `gym_exercise_library.json` into app Resources (audit N4) |
| `06-02-youtube-playback-remote-images.md` | Wire YouTube tap-to-play + remote exercise images w/ caching (audit M12) |
| `06-03-cleanup-dead-code-foreach-ids.md` | Remove dead mock Plan layer, ForEach id fixes (L8), delete-program toast (L5) |

## Out of scope for specs (owner-manual steps, from `MANUAL_STEPS.md`)
Supabase project setup / `Secrets.xcconfig` / Edge Function deploy / HealthKit capability / committing `Package.resolved` after a local resolve.
