# Handoff: Aura Fitness Tracker (iOS)

## Overview
Aura is a personalized workout-tracking iOS app: it serves training programs and an advanced live workout tracker. The app is organized into **four tabs** — **Log**, **Plan**, **Progress**, **Profile** — plus a full-screen **Active Workout** flow that takes over when a session is running.

This package contains the complete screen set (26 screens) and one fully interactive prototype (the Active Workout flow).

## About the design files
The files in this bundle are **design references created in HTML/CSS/JS** — prototypes showing the intended look, structure, and behavior. **They are not production code to copy.** The task is to **recreate these designs in the target codebase** using its established patterns. For a native iOS build this means **SwiftUI** (recommended — the design follows Apple HIG: SF-style nav bars, tab bar, bottom sheets, segmented controls). If a cross-platform stack is already in place (React Native / Expo, Flutter), recreate them there using that stack's components.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, and component styling are specified below and in `styles/aura.css` (the single source of truth for tokens). Recreate pixel-faithfully, then swap the placeholder type ramp for the platform system font if desired (see Typography).

---

## Design tokens
All tokens live in **`styles/aura.css`** under `:root` (light) and `[data-theme="dark"]` (dark). Colors are authored in **OKLCH** — convert to your platform's color space, or use the sRGB hex approximations below.

### Color — light / dark
| Token | Role | Light | Dark |
|---|---|---|---|
| `--accent` | Primary (amber) | `oklch(0.70 0.17 60)` ≈ `#E07A1F` | `oklch(0.76 0.17 65)` ≈ `#F59331` |
| `--accent-press` | Pressed accent | `oklch(0.64 0.17 60)` | `oklch(0.70 0.17 65)` |
| `--green` | Success / done | `oklch(0.70 0.15 150)` ≈ `#2DA66A` | same |
| `--red` | Destructive | `oklch(0.64 0.19 25)` ≈ `#D8432E` | same |
| `--blue` | Info accent | `oklch(0.66 0.14 250)` ≈ `#3E83D4` | same |
| `--purple` | Accent (drop sets) | `oklch(0.62 0.15 300)` ≈ `#9354C9` | same |
| `--bg` | Screen background | `oklch(0.985 0.004 80)` ≈ `#FCFBFA` | `oklch(0.155 0.005 70)` ≈ `#1E1C1A` |
| `--bg-grouped` | Grouped/list background | `oklch(0.965 0.005 80)` ≈ `#F5F3F1` | `oklch(0.125 0.005 70)` ≈ `#181614` |
| `--surface` | Cards, rows | `#FFFFFF` | `oklch(0.205 0.006 70)` ≈ `#2A2724` |
| `--surface-2` | Inset fields | `oklch(0.975 0.004 80)` | `oklch(0.235 0.006 70)` |
| `--text` | Primary text | `oklch(0.20 0.012 70)` ≈ `#2E2A26` | `oklch(0.97 0.004 80)` ≈ `#F7F5F3` |
| `--text-2` | Secondary text | `oklch(0.52 0.012 70)` ≈ `#7C746C` | `oklch(0.70 0.012 75)` |
| `--text-3` | Tertiary / placeholder | `oklch(0.66 0.010 70)` ≈ `#A39A91` | `oklch(0.55 0.012 75)` |
| `--separator` | Dividers | `oklch(0.90 0.005 70)` | `oklch(0.32 0.006 70)` |
| `--fill` | Neutral fill (chips, icon bg) | `oklch(0.72 0.01 70 / .12)` | `oklch(0.75 0.01 75 / .16)` |

Semantic accents (`green/red/blue/purple`) intentionally **share chroma & lightness, varying only hue**, so they read as one family.

### Typography
- **UI / display:** `Plus Jakarta Sans` (Google Fonts), weights 400/500/600/700/800. Geometric, clean. For a native build, you may substitute the **system font (SF Pro)** — the layouts were designed to tolerate it.
- **Numerals / mono labels:** `JetBrains Mono` for placeholder captions and code-like tags only.
- **Numeric data** (weights, timers, stats) uses the display font with `font-variant-numeric: tabular-nums` and `letter-spacing: -0.03em` (`.stat-num`).

| Style | Size / weight | Use |
|---|---|---|
| Large title | 30px / 800 / −.02em | Tab top titles ("Today", "Plan") |
| Nav title | 17px / 700 | Pushed screen titles |
| Card title | 22–24px / 800 / −.02em | Workout name, exercise name |
| Body | 15–16px / 500–600 | Rows, list items |
| Secondary | 12.5–13px / 500 | Meta, subtitles (`--text-2`) |
| Section label | 13px / 700 / UPPERCASE / +.02em | `.sec-label` (`--text-3`) |
| Stat number | 18–30px / 800 / tabular | Timers, weights, totals |

### Spacing — base-4 scale
`4, 8, 12, 16, 20, 24, 32, 40` px (`--s1`…`--s10`). Screen horizontal padding = **20px** (`.pad`).

### Radius
`--r-xs 8 · --r-sm 12 · --r-md 16 · --r-lg 22 · --r-xl 28 · --r-pill 999`. Cards use `lg`/`xl`; lists & fields `md`/`sm`; pills/toggles `pill`.

### Shadow
- `--shadow-sm`: `0 1px 2px rgba(64,40,20,.08)` — cards, rows.
- `--shadow`: `0 1px 3px …, 0 8px 24px …` — elevated / hover.

### Device frame
iPhone 393×852. Status bar 54px (time left, signal/wifi/battery right, Dynamic Island centered). Tab bar 84px (49pt bar + 34px home-indicator safe area). Home indicator pill 134×5.

---

## Screens / Views

### Tab bar (persistent)
4 items, icon + 10px label, active tint = `--accent`: **Log** (calendar/list), **Plan** (dumbbell), **Progress** (bar chart), **Profile** (person). Blurred translucent background.

### LOG  — `screens/Log.html`
1. **LOG-01 Today · planned** — Large "Today" title + date. Horizontal **week bar**: 7 day cells (S–S, date, status dot: green=done, amber=planned, gray=rest); selected cell = solid accent. Below: program badge + **planned workout card** (name, "6 exercises · ~58 min · muscles", numbered exercise rows, "+N more"), then **Start Workout** (primary), **Log past** / **Switch** (gray, half-width).
2. **LOG-02 Rest day** — Centered moon glyph card "Rest Day"; "Add a Workout" (tinted) + "Convert to training day" row.
3. **LOG-03 Unplanned/empty** — Dashed empty-state card; "Add a Workout" + "Log a Past Workout".
4. **LOG-04 Calendar sheet** — Bottom sheet month grid; status dots per day; "Go to Today". Month nav arrows.
5. **LOG-05 Add workout · source picker** — Sheet, 4 source cards: From a Program / A Saved Workout / Build from Library / Empty Workout.
6. **LOG-06 Switch / manage today** — Sheet: Switch to another workout · Make it a Rest Day · Remove (red).

### PLAN — `screens/Plan.html`
Sub-tab pill bar: **My Plans · Programs · Workouts · Exercises**.
1. **PLAN-01 My Plans** — Horizontal plan cards (gradient, max 3; one "Default" badge) + dashed Add. Default plan drives the Log tab. Weekday assignment cards (Sun-start), Create Custom Plan.
2. **PLAN-02 Program Library** — Search + filter chips + program list cards (days/wk · level · style). "Added" badge on plans already in My Plans.
3. **PLAN-03 Program detail** — Hero image, description, chips, ordered workout list. Info note: predefined programs must be added to My Plans before editing.
4. **PLAN-04 Workout Library** — Search + filters (Push/Pull/Legs…) + workout cards (exercises · duration · muscles).
5. **PLAN-05 Workout editor** — Name field, rest-between-sets / rest-between-exercises fields, draggable exercise cards (sets & rep-range chips, ⋯ menu), Add Exercise.
6. **PLAN-06 Exercise Library** — Search + **two filter rows** (row 1 body part, row 2 equipment: Cable/Barbell/Dumbbell/Smith/Machine/Bodyweight) + **2-up catalog grid** (image, name, muscle · equipment).
7. **PLAN-07 Create exercise** — Form: name, category, equipment, difficulty, primary muscle, form tips (opt), image URL (opt), YouTube URL (opt), Create.
8. **PLAN-08 Save-edit scope dialog** — Sheet asking "Just for today" vs "Permanently" (updates My Plans copy, never the predefined program).

### EXERCISE DETAIL — `screens/Exercise.html`
1. **EX-01** — Demo video thumbnail w/ centered play button (opens YouTube), name, 3-column category/equipment/level strip, Pro tip card, **Muscle activation** card (horizontal % bars + body-map placeholder), "Add to Today's Workout" / "Add to a Plan".
2. **EX-02** — Sheet: choose workout from default plan.
3. **EX-03** — Sheet: "Add as new exercise" or replace one of the existing exercises (Replace badge per row).

### PROGRESS — `screens/Progress.html`
Top segmented: **Stats · Body**. Body has a second segmented: **Measurements · Nutrition**.
1. **PROG-01 Stats overview** — Month-nav **consistency heatmap** (GitHub-style; intensity by completion, hatched = rest), this-week muscle-focus bars, lifetime tiles (Sessions / Sets / Volume / PRs).
2. **PROG-02 Weekly trend** — Big number + ▲%, Volume/Sets segmented, **area+line chart** (6 weeks), top muscle card, session tiles.
3. **PROG-03 Personal records** — Category filter chips; PR list (icon, name, date / 1RM est., weight × reps).
4. **BODY-01 Measurements** — Weight card w/ trend chart + ▼badge, Body Fat / Lean Mass tiles, measurements list (chest/waist/arms/thighs/shoulders), Log / History buttons, Progress Photos.
5. **BODY-02 Log measurement** — Form; "fill only what you measured" note; weight, body fat, circumferences — partial saves allowed.
6. **BODY-03 Progress photos** — Side-by-side / up-down compare of two photos, delta card, Share, library grid.
7. **BODY-04 Nutrition** — Profile card (height/weight/age/sex/activity) → BMI & TDEE tiles, Goal chips (lose fat / lean gain / gain muscle / maintain), Macro-split chips (balanced / high-protein / high-carb / keto), **Daily targets** card (calories + protein/carbs/fats/fiber bars, color-coded).

### PROFILE — `screens/Profile.html`
1. **PROF-01 Home** — Identity card (photo, name, age/height/weight/sex synced w/ Body) + 3 stats (Sessions / PRs / Streak); settings list groups; Log Out (red).
2. **PROF-02 Workout** — Display toggles (reps-first / weight-first / show PRs); Exercise targets (default sets 3, rep range 6–10, rest 1 min / 1 min 30 s); Automation (auto rest timer, auto-play video).
3. **PROF-03 Account** — Photo, first/last name, email, phone, birthday, gender, height, location; Export data, Reset workout data, Delete account (red).
4. **PROF-04 Preferences** — General (dark mode Off/Auto/On, start week Sun/Mon, log display), Notifications (enable, rest sound Ding/Alarm), Units (weight kg/lb, length cm/in).
5. **PROF-05 Connected & Support** — Apple/Google Health toggles; User guides & FAQ, Contact us, Request a feature; version footer.

---

## Active Workout — interactive flow  (`Active Workout.html`)
The hero experience, **fully built** in React. Recreate this behavior natively. Source: `workout/app.jsx` (controller + overview + rest pill + modals + summary), `workout/exercise.jsx` (set-logging view), `workout/data.jsx` (seed model), `workout/icons.jsx`.

### Views
- **Overview** — Top bar: **End** (red, opens end sheet) · centered workout name + running **duration timer** (mm:ss, amber) · **+** add exercise. Progress bar (done/total sets). Exercise cards (drag grip, name, "sets · reps · equipment", per-card progress bar, ✓ when complete; completed cards dim to 62%). Add Exercise + **Finish Workout**.
- **Exercise (logging)** — Back, "Exercise N", ⋯ menu. Demo video w/ play. Name + equipment/muscle chips. **Cable exercises**: single/double **pulley** segmented. **Last PR** + **Today's target** mini-cards (target is highlighted amber, computed from history). **Warm-up protocol** (collapsible) — *only the first two exercises*: exercise 1 gets the full ramp, exercise 2 gets 2 sets. **Form tip** card. **Working sets**: per-row tappable set-number (opens **set-type** picker: Normal/Drop/Rest-pause/To-failure/Partials, color-coded), `kg` input, `reps` input, ✓ toggle, note button (reveals per-set note + delete). Progression bar (done/total). **Add set** + **Complete Exercise**.
- **Summary** — Gradient hero "Workout Complete", stat grid (Duration / Sets / Volume / New PRs), PR banner if any, per-exercise recap, **session notes** textarea, **Save Workout** (resets) / Back.

### Interactions & rules (implement exactly)
- **Auto-finish set:** when both `kg` & `reps` are filled and the field blurs, the set auto-marks done.
- **Auto rest timer:** completing a set starts a **60s** rest **unless it's the final set** of the exercise. Completing the whole exercise starts a **90s** rest. Adding a new (empty) set also starts the rest timer.
- **Rest pill:** floating, **draggable anywhere** within the screen (position persists), shows ring countdown + mm:ss, **+15s**, pause/play, dismiss.
- **Complete Exercise:** removes any empty sets, marks filled sets done, fires a celebration, starts 90s rest, returns to overview.
- **Celebrations (toast overlay, ~2.4s):** weight > last PR → "New PR!"; reps > target (at ≥ target weight) → "Extra reps!"; on complete → encouragement; on finish → summary hero.
- **Edits not committed until Save** — state is held live (persisted to `localStorage` in the prototype) and the **PLAN-08 scope dialog** decides today-only vs permanent (My Plans copy; never the predefined program).
- **Substitute / Add / Remove / Superset** via the exercise ⋯ menu; substitute swaps name + equipment, superset links with the next exercise.
- **End sheet:** Finish & Save · Discard Workout (red) · Continue Workout. Cancel anywhere returns to the in-progress state.

### State model
`workout { name, program, exercises[] }`; `exercise { id, name, muscle, groups[], equipment, isCable, pulley, repRange, planned, lastPR{weight,reps,date}, target{weight,reps,note}, warmup[], hint, sets[] }`; `set { weight, reps, done, type, note }`. App state: `view`, `activeExerciseIndex`, `elapsed`, `rest{active,total,left,running}`, `pillPosition{x,y}`, `modal`, `celebration`. See `workout/data.jsx`.

---

## Assets
- **Icons:** custom 24px stroke set (1.7 weight, round caps) in `styles/icons.js` (and `workout/icons.jsx`). Map to **SF Symbols** on iOS where equivalents exist.
- **Imagery:** all photos/video thumbnails are striped **placeholders** labelled in monospace (e.g. "exercise demo", "body map", "photo · drop in"). Replace with: exercise demo stills + YouTube embeds, body-muscle diagram, user progress photos, program cover art.
- **Fonts:** Plus Jakarta Sans + JetBrains Mono (Google Fonts) — or system font on native.

## Files
- `Aura Fitness.html` — index / navigation hub.
- `Active Workout.html` + `workout/*.jsx` — interactive prototype.
- `screens/Log.html · Plan.html · Exercise.html · Progress.html · Profile.html` — static screen galleries (each has a light/dark viewer toggle).
- `styles/aura.css` — **design tokens + component CSS (source of truth)**.
- `styles/gallery.css` — viewer chrome + reusable screen sub-components.
- `styles/icons.js` — icon set + auto status-bar renderer.

> Tip for Claude Code: start from **`styles/aura.css`** (tokens) and the **Active Workout** behavior spec above; build the design system / component primitives first, then assemble screens tab by tab.
