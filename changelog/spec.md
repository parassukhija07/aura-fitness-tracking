# IMPLEMENTATION SPEC — Log-tab UI polish (7 fixes)

Target project: Aura Fitness Tracker (SwiftUI, iOS).
These are surgical polish fixes. Do NOT refactor surrounding code. Keep every other line identical.

Reference design source (read-only, for intent): `.design-import/combined/log.jsx` and `.design-import/combined/ui.jsx`.

Confirmed design-system constants (already exist in `AuraFitness/DesignSystem/AuraSpacing.swift`):
- `AuraRadius.md = 16`, `AuraRadius.lg = 22`, `AuraRadius.xl = 28`, `AuraRadius.pill = 999`
- `AuraSpacing.s2 = 8`, `AuraSpacing.tabBarClearance = 110`
- `Color.aura.separator`, `Color.aura.accent` exist and are used throughout.

---

## FIX 1 — Week bar: add a border to each (non-selected) day cell

**File:** `AuraFitness/Log/LogTabView.swift`
**Location:** `private func dayCell(_ d: Date)` — the `Button { ... } label: { VStack { ... } ... }` chain (currently lines ~197–215).

**Current (old) code** — the modifier tail of the `VStack` inside the button label (lines ~209–212):
```swift
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(sel ? Color.aura.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
```

**New code** — add an `.overlay` border that is hidden on the selected cell (selected cell keeps only its accent fill, no border):
```swift
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(sel ? Color.aura.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .strokeBorder(Color.aura.separator.opacity(0.5), lineWidth: 1)
                    .opacity(sel ? 0 : 1)
            )
```

**Notes:**
- Use `.strokeBorder` (not `.stroke`) so the 1pt line draws inside the rounded rect and does not get clipped.
- The `.overlay` MUST come after `.clipShape` so the border traces the same rounded shape.
- Do not change the selected-cell appearance other than suppressing the border via `.opacity(sel ? 0 : 1)`.

---

## FIX 2 — Today's/planned workout exercise list: cap at ~3 rows, then scroll

**File:** `AuraFitness/Log/LogTabView.swift`
**Location:** `private func exerciseRows(_ exercises: [Exercise], dim: Bool)` (currently lines ~461–485).

Design reference: `.design-import/combined/log.jsx` `ExRows` uses `maxHeight: 168` with `overflowY: auto` and `gap: 11`. We mirror this with a fixed-height inner `ScrollView`.

**Current (old) code:**
```swift
    @ViewBuilder
    private func exerciseRows(_ exercises: [Exercise], dim: Bool) -> some View {
        VStack(spacing: 11) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { i, e in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.aura.text2)
                        .frame(width: 22, height: 22)
                        .background(Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.aura.text)
                        Text("\(e.plannedSets) sets · \(e.repRange) reps")
                            .font(.system(size: 12.5))
                            .foregroundColor(.aura.text2)
                    }
                    Spacer()
                }
            }
        }
        .opacity(dim ? 0.55 : 1)
    }
```

**New code** — wrap the existing `VStack` in a `ScrollView` with a capped `maxHeight`. Only add the wrapper + a conditional frame; keep the row contents byte-for-byte identical:
```swift
    @ViewBuilder
    private func exerciseRows(_ exercises: [Exercise], dim: Bool) -> some View {
        // Show ~3 rows; scroll for the rest (mirrors log.jsx ExRows maxHeight: 168).
        let capHeight: CGFloat = 168
        let scrollable = exercises.count > 3

        ScrollView(.vertical, showsIndicators: scrollable) {
            VStack(spacing: 11) {
                ForEach(Array(exercises.enumerated()), id: \.offset) { i, e in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.aura.text2)
                            .frame(width: 22, height: 22)
                            .background(Color.aura.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.aura.text)
                            Text("\(e.plannedSets) sets · \(e.repRange) reps")
                                .font(.system(size: 12.5))
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.trailing, 2) // matches paddingRight: 2 in ExRows so the scrollbar doesn't overlap text
        }
        .frame(maxHeight: scrollable ? capHeight : nil)
        .scrollBounceBehavior(.basedOnSize)
        .opacity(dim ? 0.55 : 1)
    }
```

**Notes:**
- `.frame(maxHeight: scrollable ? capHeight : nil)` means: when there are 3 or fewer exercises the card hugs its content (no empty space, no scroll); with 4+ it caps at 168pt and scrolls.
- `.scrollBounceBehavior(.basedOnSize)` (iOS 16.4+) prevents rubber-band bounce when content fits. If the project's minimum deployment target is below iOS 16.4, OMIT that single line — everything else still works.
- This inner `ScrollView` lives inside the outer `AuraScreenScroll`. That is acceptable because the inner one has a fixed height; do not change the outer scroll.

---

## FIX 3 — "⋯" menu sheet (and other short sheets) must size to content, not full screen

**File:** `AuraFitness/Log/LogSheetsView.swift`
**Location:** `var body: some View` — the `.presentationDetents([.large])` applied to the whole `Group` (currently line ~44).

**Root cause:** A single `.presentationDetents([.large])` is applied to ALL Log sheets. The menu, move, and add sheets have little content, so `.large` leaves an empty bottom half. Tall sheets (switch, edit, log forms, calendar) legitimately need height.

**Current (old) code** (lines ~28–45):
```swift
    var body: some View {
        Group {
            switch sheet {
            case .menu:                          menuSheet
            case .switchWorkout:                 switchSheet
            case .move:                          moveSheet
            case .edit:                          editSheet
            case .add:                           addSheet
            case .logPast(let date, let show):   logPastSheet(date: date, showToday: show)
            case .pick(let mode, let date):      pickSheet(mode: mode, date: date)
            case .calendar(let forLogPast):      calendarSheet(forLogPast: forLogPast)
            case .viewLog:                       viewLogSheet
            case .editLog:                       editLogSheet
            case .logQuick(let iso):             logQuickSheet(iso: iso)
            }
        }
        .presentationDetents([.large])
    }
```

**New code** — replace the single fixed detent with a per-sheet computed set. Add a computed property `detents` and apply it:
```swift
    var body: some View {
        Group {
            switch sheet {
            case .menu:                          menuSheet
            case .switchWorkout:                 switchSheet
            case .move:                          moveSheet
            case .edit:                          editSheet
            case .add:                           addSheet
            case .logPast(let date, let show):   logPastSheet(date: date, showToday: show)
            case .pick(let mode, let date):      pickSheet(mode: mode, date: date)
            case .calendar(let forLogPast):      calendarSheet(forLogPast: forLogPast)
            case .viewLog:                       viewLogSheet
            case .editLog:                       editLogSheet
            case .logQuick(let iso):             logQuickSheet(iso: iso)
            }
        }
        .presentationDetents(detents)
    }

    /// Per-sheet detents: compact sheets fit their content; tall/scrolling sheets get full height.
    private var detents: Set<PresentationDetent> {
        switch sheet {
        case .menu:
            // Compact bottom sheet — sized to the 5-row menu, not full screen.
            return [.fraction(0.55)]
        case .move, .add:
            return [.medium, .large]
        default:
            return [.large]
        }
    }
```

**Notes:**
- The return type MUST be `Set<PresentationDetent>` (matches `.presentationDetents(_:)`).
- The menu has exactly 5 rows + header + footer text. `.fraction(0.55)` fits it with no empty half on standard iPhone sizes. If during testing it still clips the last row, bump to `.fraction(0.6)`; if it shows empty space, lower to `.fraction(0.5)`. Do not use `.medium` alone for the menu — on tall devices `.medium` is ~half but the menu reads better slightly taller; `.fraction` is the chosen approach.
- `.move` and `.add` get `[.medium, .large]` so they open compact but can be dragged up.
- All other sheets keep `.large`.
- The drag indicator is supplied by the caller in `LogTabView.logSheet` via `.presentationDragIndicator(.visible)` — do NOT add it here.

---

## FIX 4 — Glass tab bar sliding indicator: width/position must match each tab slot

**File:** `AuraFitness/DesignSystem/AuraTabBar.swift`
**Location:** `private var glassPill: some View` — the `GeometryReader` slot math and the indicator `RoundedRectangle` (currently lines ~116–131).

Design reference: `.design-import/combined/ui.jsx` `TabBarEl` computes (note the pill has `padding: 6px 3px`, i.e. **3px horizontal inset**):
```
indicatorW = calc((100% - 8px) / 4)
indicatorX = calc(4px + targetIdx * (100% - 8px) / 4)
```
i.e. the slot width is `(totalWidth - 2*4) / 4` and the indicator left edge is `4 + idx * slot`. The Swift code already does exactly this with `inset = 4` and `slot = (width - inset*2)/count`. The remaining bug is in how the indicator is positioned/clamped: it uses `.offset` on a leading-aligned shape and re-derives `indicatorX` separately from the clamp, which can drift, and the indicator height/inset is not symmetric with the slot inset.

**Current (old) code** (lines ~116–131):
```swift
    private var glassPill: some View {
        GeometryReader { geo in
            let count = CGFloat(AuraTab.allCases.count)
            let inset: CGFloat = 4
            let slot = (geo.size.width - inset * 2) / count
            let indicatorX = inset + CGFloat(selection.rawValue) * slot + dragOffset

            ZStack(alignment: .leading) {
                // Sliding accent indicator
                RoundedRectangle(cornerRadius: AuraRadius.pill)
                    .fill(Color.aura.accent)
                    .frame(width: slot, height: geo.size.height - inset * 2)
                    .offset(x: max(inset, min(indicatorX, inset + (count - 1) * slot)),
                            y: inset)
                    .shadow(color: Color.aura.accent.opacity(0.5), radius: 7, x: 0, y: 2)
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: selection)
```

**New code** — make the indicator exactly one slot wide and clamp the SAME `indicatorX` value that is drawn (so position and clamp can never disagree). Keep `inset = 4`:
```swift
    private var glassPill: some View {
        GeometryReader { geo in
            let count = CGFloat(AuraTab.allCases.count)
            let inset: CGFloat = 4
            let slot = (geo.size.width - inset * 2) / count
            // Left edge of the indicator for the current selection, plus the live drag follow,
            // clamped to the first/last slot so it always lines up with a tab.
            let rawX = inset + CGFloat(selection.rawValue) * slot + dragOffset
            let indicatorX = min(max(rawX, inset), inset + (count - 1) * slot)

            ZStack(alignment: .leading) {
                // Sliding accent indicator — exactly one slot wide, inset symmetrically top/bottom.
                RoundedRectangle(cornerRadius: AuraRadius.pill)
                    .fill(Color.aura.accent)
                    .frame(width: slot, height: geo.size.height - inset * 2)
                    .offset(x: indicatorX, y: inset)
                    .shadow(color: Color.aura.accent.opacity(0.5), radius: 7, x: 0, y: 2)
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: selection)
```

**Critical requirement for slot alignment:** the tab buttons MUST occupy the same insets as the indicator. The button `HStack` (currently lines ~133–154) sits inside the `ZStack` with NO horizontal padding, so each button is `geo.size.width / 4` wide, but the indicator slot is `(geo.size.width - 8) / 4`. That 8pt difference is the visible mismatch. Add horizontal padding equal to `inset` to the button row so the four buttons span the same region as the four slots.

**Current (old) code** — the button `HStack` opening + its close (lines ~133 and ~154):
```swift
                HStack(spacing: 0) {
                    ForEach(AuraTab.allCases) { tab in
                        Button {
                            ...
                        }
                        .buttonStyle(.plain)
                    }
                }
```

**New code** — add `.padding(.horizontal, inset)` to that `HStack` (do not change anything inside it):
```swift
                HStack(spacing: 0) {
                    ForEach(AuraTab.allCases) { tab in
                        Button {
                            ...
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, inset)
```

**Notes:**
- Only two edits inside `glassPill`: (a) the `indicatorX` derivation + `.offset` shown above, (b) adding `.padding(.horizontal, inset)` to the button `HStack`. Leave `count`, `slot`, `inset`, the shadow, the material background, the stroke, and the swipe gesture untouched.
- After this change, each button's center sits at `inset + (idx + 0.5) * slot`, exactly matching the indicator center. Verify by tapping each tab: the pill must fully cover the icon+label of the active tab with equal margins.

---

## FIX 5 — Glass tab bar + FAB sit too high; move them closer to the bottom

There are two contributing paddings. Fix the one inside `AuraTabBar`; `ContentView` already pins the bar to the bottom via `Spacer()` and does not need changes.

**File:** `AuraFitness/DesignSystem/AuraTabBar.swift`
**Location:** `var body` — the `HStack(spacing:) { glassPill; fab }` modifiers (currently lines ~104–110).

**Current (old) code:**
```swift
            HStack(spacing: collapsed ? 6 : 10) {
                glassPill
                fab
            }
            .padding(.horizontal, collapsed ? 8 : 10)
            .padding(.bottom, collapsed ? 30 : 38)
```

**New code** — reduce the bottom padding so the bar rides just above the home indicator. The bar is inside a `VStack { Spacer(); AuraTabBar }` in `ContentView` that does NOT ignore the bottom safe area, so the system already reserves the home-indicator inset; this padding is the extra gap above it:
```swift
            HStack(spacing: collapsed ? 6 : 10) {
                glassPill
                fab
            }
            .padding(.horizontal, collapsed ? 8 : 10)
            .padding(.bottom, collapsed ? 8 : 12)
```

**Notes:**
- Concrete values: expanded `12`, collapsed `8` (was `38` / `30`). This drops the bar by ~26pt so it floats just above the home indicator instead of mid-screen.
- Do NOT touch `ContentView.swift`. Its `VStack { Spacer(); AuraTabBar(...) }.ignoresSafeArea(.keyboard)` is correct — it must keep respecting the bottom safe area so the reduced padding lands above the home indicator, not under it.
- `AuraSpacing.tabBarClearance` (110) is the scroll-content bottom inset used by tab screens. Leave it unchanged — content already clears the bar, and reducing the bar's own bottom padding does not require touching clearance.
- The FAB shares this `HStack`, so it moves down together with the pill automatically. No separate FAB edit needed.

---

## FIX 6 — View-log → Edit-log transition should be smooth

**File:** `AuraFitness/Log/LogSheetsView.swift`
**Location:** `var body` `Group { switch sheet { ... } }` (lines ~28–43). The sheet content is swapped by reassigning `parentSheet` (e.g. `viewLogSheet` button sets `parentSheet = .editLog` at line ~620). Because all Log sheets render inside the same `.sheet(item:)` host, changing `parentSheet` swaps the inner content instantly with no animation — that is the abrupt swap.

**Fix:** Give the swapped content a cross-fade + slide transition keyed on the sheet identity, and animate the change.

**Step 6a — animate the transition trigger.** In `viewLogSheet`, the "Edit Log" button currently does:
```swift
                AuraGrayButton(label: "Edit Log", icon: "pencil") { parentSheet = .editLog }
                    .padding(.horizontal, AuraSpacing.screenPad)
```
**Change to** (wrap the state change in an animation):
```swift
                AuraGrayButton(label: "Edit Log", icon: "pencil") {
                    withAnimation(.easeInOut(duration: 0.28)) { parentSheet = .editLog }
                }
                    .padding(.horizontal, AuraSpacing.screenPad)
```

**Step 6b — add a transition to the content `Group` in `body`.** Apply an `.id` and a `.transition` to the switch result so SwiftUI animates the content replacement:

**Current (old) code** (lines ~28–45):
```swift
    var body: some View {
        Group {
            switch sheet {
            case .menu:                          menuSheet
            ...
            case .logQuick(let iso):             logQuickSheet(iso: iso)
            }
        }
        .presentationDetents(detents)
    }
```

**New code** (note: `.presentationDetents(detents)` is from FIX 3 — keep it; add `.id` + `.transition` + `.animation` to the `Group`):
```swift
    var body: some View {
        Group {
            switch sheet {
            case .menu:                          menuSheet
            ...
            case .logQuick(let iso):             logQuickSheet(iso: iso)
            }
        }
        .id(sheet.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.28), value: sheet.id)
        .presentationDetents(detents)
    }
```

**Notes:**
- `sheet.id` is the existing `String` id on the `LogSheet` enum (`LogTabView.swift`, `var id: String`). `viewLog` → `editLog` produces ids `"viewlog"` → `"editlog"`, so `.id(sheet.id)` changes, driving the transition.
- The `.transition` gives a horizontal push-style cross-fade (View Log slides out left, Edit Log slides in from the right) — a forward-navigation feel appropriate for view → edit.
- Keep the existing `.presentationDragIndicator(.visible)` on the caller side (`LogTabView.logSheet`) untouched.
- IMPORTANT ordering: `.presentationDetents(detents)` and `.presentationDragIndicator` are presentation modifiers on the sheet host — they may stay where they are. The `.transition`/`.animation` operate on the inner `Group` content and are independent.
- The `withAnimation` in 6a is required: `.animation(..., value:)` alone animates value-driven changes, but wrapping the explicit `parentSheet` mutation guarantees the transition fires even if SwiftUI batches the update.

---

## FIX 7 — "Remove from Today" should make the day a Rest Day (not empty)

**File:** `AuraFitness/Log/LogSheetsView.swift`
**Location:** `menuSheet` — the "Remove from Today" `menuRow` action (currently lines ~173–175).

**Background (verified in `AuraFitness/Models/AppState.swift` `dayInfo`):**
- Override kind `.removed` → `workout == nil` → for today yields `state = .emptyToday` (the "Nothing planned" empty state). This is the current, unwanted behavior.
- Override kind `.rest` → `workout == nil` → for today yields `state = .restToday` (the "Rest Day" UI). This is the desired behavior.

So the fix is to change the override kind from `.removed` to `.rest`.

**Current (old) code:**
```swift
                    menuRow(icon: "trash", bg: .aura.red, label: "Remove from Today", danger: true) {
                        appState.setOverride(DayOverride(kind: .removed), for: info.iso); parentSheet = nil; flash("Removed from today")
                    }
```

**New code** (change `.removed` → `.rest`; update the toast to reflect the new outcome):
```swift
                    menuRow(icon: "trash", bg: .aura.red, label: "Remove from Today", danger: true) {
                        appState.setOverride(DayOverride(kind: .rest), for: info.iso); parentSheet = nil; flash("Set to rest day")
                    }
```

**Notes:**
- Only change this one closure. Do NOT change the `.move` sheet's use of `.removed` (line ~230 `appState.setOverride(DayOverride(kind: .removed), for: info.iso)` — that one is the "vacate the source day after moving" semantic and must stay `.removed`).
- Do NOT delete the `.removed` case from `DayOverride.Kind` or its handling in `AppState.dayInfo` — it is still used by the move flow.
- The toast text change from "Removed from today" to "Set to rest day" keeps the message truthful. If you prefer to keep the original copy, that is acceptable, but the override kind change is mandatory.
- Label/icon stay the same ("Remove from Today", trash icon, danger styling) per the request — only the resulting state changes.

---

## DEFINITION OF DONE

1. **Week bar:** Every non-selected day cell shows a 1pt `Color.aura.separator.opacity(0.5)` rounded border (`AuraRadius.md`); the selected cell shows the accent fill with NO border. Border is not clipped at the corners.
2. **Exercise list:** A workout with ≤3 exercises renders with no scroll and no empty space; a workout with ≥4 exercises shows ~3 rows in a fixed ~168pt-tall inner `ScrollView` and scrolls to reveal the rest. No layout break inside `AuraCard` / outer `AuraScreenScroll`.
3. **⋯ menu sheet:** Opens as a compact bottom sheet sized to its 5 rows (no empty bottom half). Move/Add sheets open at medium and can expand; all other Log sheets remain full height.
4. **Tab bar indicator:** The orange sliding pill is exactly one slot wide and is perfectly centered over each tab's icon+label when that tab is selected, for all four tabs, in both expanded and collapsed states. No 8pt drift.
5. **Tab bar position:** The glass pill + FAB sit just above the home indicator (bottom padding 12 expanded / 8 collapsed), not floating mid-screen. They still respect the bottom safe area (not clipped by the home indicator). `ContentView.swift` unchanged.
6. **View→Edit log:** Tapping "Edit Log" in the View Log sheet animates a smooth horizontal cross-fade (out-left / in-right, ~0.28s) instead of an instant content swap. Drag indicator and sheet height behavior remain correct.
7. **Remove from Today:** Tapping "Remove from Today" sets the day to the Rest Day state (`.restToday`, moon icon / "Rest Day" UI), NOT the "Nothing planned" empty state. The Move flow's source-day clearing still uses `.removed`.
8. **No regressions:** Project compiles. No other files changed except `AuraFitness/Log/LogTabView.swift`, `AuraFitness/Log/LogSheetsView.swift`, and `AuraFitness/DesignSystem/AuraTabBar.swift`.
