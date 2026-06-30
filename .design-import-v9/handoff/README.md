# Aura Fitness — Developer Handover

A complete, screen-by-screen, scenario-by-scenario spec for rebuilding **Aura** (a workout-tracking iOS app) natively. The source of truth is the working prototype **`../Aura App.html`** — a React app with four tabs plus a full-screen Active Workout flow. The HTML/JS files are **design references, not production code**: recreate the *behaviour* in your target stack (SwiftUI recommended; React Native / Flutter if already in place).

> **Start here:** open **`Handoff.html`** in a browser for the navigable version of this index. Then read the chapters in order — each is a self-contained HTML page documenting purpose → layout → every interactive element → all states/scenarios → edge cases.

---

## Chapters

| # | File | Covers |
|---|------|--------|
| 1 | `01-foundation.html` | Tokens, type scale, device frame, icon set, shared components (Seg/Toggle/Stepper/LineChart/SetRow), theming & persistence model |
| 2 | `02-shell-nav.html` | `AuraRoot` routing, Active Workout overlay, resume banner, the glass tab bar (sliding indicator, collapse-on-scroll, swipe), FAB quick-actions |
| 3 | `03-log.html` | The 6 day-states + 11 sheets; `dayInfo()` derivation; override types; week bar & calendar |
| 4 | `04-plan.html` | 4 sub-tabs (My Plans / Programs / Workouts / Exercises), program & workout editors, supersets, 3-tab exercise detail |
| 5 | `05-active-workout.html` | The hero flow: 6 views, set logging, auto-rest rules, celebrations, rest pill, supersets, summary, minimise |
| 6 | `06-progress.html` | Stats (heatmap, strength score/balance, exercise trends, PRs) + Body (measurements, photos, nutrition calculator) |
| 7 | `07-profile.html` | Identity card + 7-screen settings tree + confirm sheets; cross-tab sync bridge |
| 8 | `08-data-models.html` | Consolidated state shapes, seed datasets, localStorage keys, and all computed formulas |

---

## How to use this

1. Read **Chapter 1 (Foundation)** first — it defines tokens, shared components and the global state/persistence model every screen depends on.
2. Then **Chapter 2 (Shell)** — the frame everything renders inside.
3. Work **tab by tab** (Ch. 3–7). Within a chapter, build screens top-to-bottom; the **Scenario checklist** at the end of each is your QA list.
4. Keep **Chapter 8** open as a reference while wiring data.
5. Treat every `SCREEN-ID` badge as a discrete unit of work, and every **warn / EDGE** callout as an easy-to-miss behaviour to implement deliberately.

`../styles/aura.css` is the **single source of truth for design tokens** — read it before writing any UI.

---

## Source files (in `../`)

| File | Role |
|------|------|
| `Aura App.html` | Entry point — loads all modules, scales the 393×852 frame |
| `styles/aura.css` | Design tokens + component CSS · **source of truth** |
| `combined/shell.jsx` | `AuraRoot` — tab routing + cross-tab settings |
| `combined/ui.jsx` | Shared primitives: TabBar, Seg, Toggle, Stepper, LineChart, SetRow |
| `combined/log.jsx` | Log tab (all day-states + sheets) |
| `plan/app.jsx` · `plan/data.jsx` · `plan/exercise-detail.jsx` | Plan tab + libraries + editors + exercise detail |
| `workout/app.jsx` · `exercise.jsx` · `superset.jsx` · `data.jsx` | Active Workout flow + seed |
| `combined/progress.jsx` · `combined/profile.jsx` | Progress & Profile tabs |
| `workout/icons.jsx` · `styles/icons.js` | Icon set |

---

## Target stack notes

- Design follows Apple HIG (large titles, grouped lists, bottom sheets, segmented controls, floating tab bar) → **SwiftUI recommended** for iOS.
- **Map icons to SF Symbols** where equivalents exist (prototype ships a custom 24px stroke set, weight 1.7, round caps).
- **System font (SF Pro)** may substitute for Plus Jakarta Sans — layouts tolerate it. Keep **tabular numerals** on all stats/timers.
- **All imagery is placeholder** (striped boxes / muscle-tinted thumbs). Replace with real exercise demos, body maps, progress photos, program art.

---

## Fidelity

**High.** Final colours, type, spacing, motion and interaction are all specified in the chapters and in `styles/aura.css`. Recreate faithfully, then swap placeholders for real assets and persist everything the prototype only holds in memory (workout logs, day overrides, all of Profile `cfg`).
