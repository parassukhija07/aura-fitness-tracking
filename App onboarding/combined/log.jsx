/* Aura — interactive Log tab. Built from screens/Log.html, fully wired. */
(function () {
const AuraTabBar = window.AuraTabBar;
const { useState } = React;

/* ── date helpers ─────────────────────────────────────────────── */
const LOG_TODAY = (() => { const d = new Date(); d.setHours(0,0,0,0); return d; })();
const D0 = d => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x; };
const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
const isoOf = d => { const x = D0(d); return x.getFullYear() + '-' + String(x.getMonth() + 1).padStart(2, '0') + '-' + String(x.getDate()).padStart(2, '0'); };
const weekStartSun = d => addDays(D0(d), -D0(d).getDay());
const weekStartMon = d => addDays(D0(d), -((D0(d).getDay() + 6) % 7));
const weekStart = (d, calStart) => calStart === 'Mon' ? weekStartMon(d) : weekStartSun(d);
const DOW_L = ['S','M','T','W','T','F','S']; // indexed by getDay() — Sun=0, Mon=1, ...
const DOW_FULL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MON_S = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MON_F = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const sameDay = (a, b) => isoOf(a) === isoOf(b);

/* ── program / workout data ───────────────────────────────────── */
const PROGRAM_NAME = 'Push · Pull · Legs';
const PLAN_BY_DOW = { 0: null, 1: 'pull-a', 2: 'leg-a', 3: null, 4: 'push-a', 5: 'pull-b', 6: null };
const SEED_MISSED = new Set(['2026-06-23', '2026-06-17', '2026-06-11']);

const WK_DETAIL = {
  'push-a': { name: 'Push Day A', muscles: 'Chest, Shoulders, Triceps', duration: 58, ex: [['Barbell Bench Press', 4, '6–8'], ['Incline Dumbbell Press', 3, '8–10'], ['Cable Fly', 3, '12–15'], ['Overhead Press', 4, '6–8'], ['Lateral Raises', 3, '12–15'], ['Tricep Pushdown', 3, '10–12']] },
  'pull-a': { name: 'Pull Day A', muscles: 'Back, Biceps', duration: 52, ex: [['Barbell Row', 4, '6–8'], ['Pull-ups', 3, '8–10'], ['Seated Cable Row', 3, '10–12'], ['Face Pulls', 3, '15'], ['Barbell Curl', 3, '10–12']] },
  'leg-a': { name: 'Leg Day A', muscles: 'Quads, Hamstrings', duration: 55, ex: [['Barbell Squat', 4, '5–8'], ['Romanian Deadlift', 3, '8–10'], ['Leg Press', 3, '10–12'], ['Leg Curl', 3, '12–15'], ['Leg Extension', 3, '15']] },
  'push-b': { name: 'Push Day B', muscles: 'Shoulders focus', duration: 55, ex: [['Overhead Press', 4, '6–8'], ['DB Lateral Raise', 4, '12–15'], ['Incline DB Press', 3, '8–10'], ['Cable Lateral Raise', 3, '15–20'], ['Skull Crushers', 3, '10–12'], ['Tricep Dips', 3, '10–15']] },
  'pull-b': { name: 'Pull Day B', muscles: 'Back, Biceps', duration: 52, ex: [['Deadlift', 4, '4–6'], ['Weighted Pull-ups', 3, '6–8'], ['Seated Cable Row', 3, '10–12'], ['Face Pulls', 3, '15'], ['Hammer Curl', 3, '12']] },
};
const ALL_WK = ['push-a', 'pull-a', 'leg-a', 'push-b', 'pull-b'];
Object.assign(WK_DETAIL, {
  'hiit-full':  { name: 'Full Body HIIT',  muscles: 'Full Body',               duration: 40, ex: [['Burpees', 4, '15'], ['Jump Squats', 3, '20'], ['Mountain Climbers', 3, '30s'], ['Box Jumps', 3, '12']] },
  'hiit-upper': { name: 'Upper HIIT',      muscles: 'Chest, Shoulders, Arms',   duration: 35, ex: [['Push-up Burpees', 3, '12'], ['Battle Ropes', 3, '30s'], ['DB Snatches', 3, '10']] },
  '5x5-a':      { name: 'Workout A',       muscles: 'Chest · Back · Legs',      duration: 55, ex: [['Squat', 5, '5'], ['Bench Press', 5, '5'], ['Barbell Row', 5, '5']] },
  '5x5-b':      { name: 'Workout B',       muscles: 'Shoulders · Back · Legs',  duration: 50, ex: [['Squat', 5, '5'], ['Overhead Press', 5, '5'], ['Deadlift', 1, '5']] },
});
const OTHER_PLANS = [
  { id: 'hiit',     name: 'HIIT Cardio',    wids: ['hiit-full', 'hiit-upper'] },
  { id: 'strength', name: '5×5 Strength',   wids: ['5x5-a', '5x5-b'] },
];
const exList = (info) => {
  if (info.ov && info.ov.type === 'edit' && info.ov.exercises) return info.ov.exercises;
  const d = WK_DETAIL[info.workoutId];
  return d ? d.ex.map(e => ({ name: e[0], sets: e[1], reps: e[2] })) : [];
};
const wkMeta = (id) => WK_DETAIL[id] || { name: '', muscles: '', duration: 0, ex: [] };

/* ── small components ─────────────────────────────────────────── */
function Sheet({ onClose, max, title, sub, children }) {
  return (
    <div className="sheet">
      <div className="scrim" onClick={onClose}></div>
      <div className="sheet-card" style={{ maxHeight: max || '74%' }}>
        <div className="grabber"></div>
        {title && (
          <div className="between pad" style={{ paddingBottom: 8 }}>
            <div>
              <div className="nav-title">{title}</div>
              {sub && <div className="tiny muted" style={{ marginTop: 2 }}>{sub}</div>}
            </div>
            <button className="nav-icon-btn" onClick={onClose}><Icon name="x" size={18} /></button>
          </div>
        )}
        <div className="pad" style={{ overflow: 'auto', paddingBottom: 28 }}>{children}</div>
      </div>
    </div>
  );
}
function MenuRow({ icon, bg, label, sub, onClick, danger, chevron }) {
  return (
    <button className="row" style={{ width: '100%', background: 'var(--surface)', border: 0, textAlign: 'left', cursor: 'pointer' }} onClick={onClick}>
      <div className="row-ic" style={{ background: bg }}><Icon name={icon} size={17} /></div>
      <div className="row-main">
        <div className="row-title" style={{ color: danger ? 'var(--red)' : 'var(--text)' }}>{label}</div>
        {sub && <div className="row-sub">{sub}</div>}
      </div>
      {chevron && <Icon name="chevron-right" size={18} color="var(--text-3)" />}
    </button>
  );
}
function SrcCard({ icon, bg, color, t, s, onClick }) {
  return (
    <button className="src-card" style={{ cursor: 'pointer' }} onClick={onClick}>
      <div className="src-ic" style={{ background: bg, color }}><Icon name={icon} size={22} /></div>
      <div className="grow" style={{ textAlign: 'left' }}>
        <div className="src-t">{t}</div>
        <div className="src-s">{s}</div>
      </div>
      <Icon name="chevron-right" size={18} color="var(--text-3)" />
    </button>
  );
}
function ExRows({ items, dim, chevron }) {
  return (
    <div style={{ overflowY: 'auto', maxHeight: 168, display: 'flex', flexDirection: 'column', gap: 11, paddingRight: 2, opacity: dim ? 0.55 : 1 }}>
      {items.map((e, i) => (
        <div className="ex-line" key={i}>
          <span className="ex-n">{i + 1}</span>
          <div className="grow"><div className="ex-t">{e.name}</div><div className="ex-s">{e.sets} sets · {e.reps} reps</div></div>
          {chevron && <Icon name="chevron-right" size={18} color="var(--text-3)" />}
        </div>
      ))}
    </div>
  );
}

/* ── main ─────────────────────────────────────────────────────── */
function LogTab(props) {
  props = props || {};
  const [selected, setSelected] = useState(LOG_TODAY);
  const [overrides, setOverrides] = useState({});
  const [sheet, setSheet] = useState(null);
  const [calMonth, setCalMonth] = useState(new Date(2026, 5, 1));
  const [toast, setToast] = useState(null);
  const [workoutLogs, setWorkoutLogs] = useState({});

  const fmtTime = d => String(d.getHours()).padStart(2,'0') + ':' + String(d.getMinutes()).padStart(2,'0');
  const openLogQuick = (iso, exItems) => setSheet({
    kind: 'log-quick', iso,
    time: fmtTime(new Date()),
    exercises: exItems.map(e => ({ name: e.name, sets: Array.from({ length: e.sets }, () => ({ weight: '', reps: '' })) }))
  });

  const setOv = (iso, val) => setOverrides(o => ({ ...o, [iso]: val }));
  const clearOv = (iso) => setOverrides(o => { const n = { ...o }; delete n[iso]; return n; });
  const flash = (msg) => { setToast(msg); setTimeout(() => setToast(t => t === msg ? null : t), 1900); };

  function dayInfo(date) {
    const iso = isoOf(date), dow = date.getDay();
    const dd = D0(date).getTime(), today = D0(LOG_TODAY).getTime();
    const ov = overrides[iso] || null;
    let workoutId = PLAN_BY_DOW[dow];
    if (ov && (ov.type === 'switch' || ov.type === 'added' || ov.type === 'logged')) workoutId = ov.workoutId;
    if (ov && (ov.type === 'rest' || ov.type === 'removed')) workoutId = null;
    const rel = dd < today ? 'past' : dd > today ? 'future' : 'today';
    let kind;
    if (!workoutId) kind = rel === 'today' ? 'rest-today' : (ov && ov.type === 'removed' && rel === 'today' ? 'empty-today' : 'rest');
    else if (ov && ov.type === 'logged') kind = 'done';
    else if (rel === 'today') kind = 'today';
    else if (rel === 'future') kind = 'future';
    else kind = (ov && ov.type === 'added') ? 'done' : (SEED_MISSED.has(iso) ? 'missed' : 'done');
    return { iso, dow, date: new Date(date), rel, workoutId, kind, ov };
  }

  const cs = props.calStart || 'Sun';
  const wkStart = weekStart(selected, cs);
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(wkStart, i));
  const info = dayInfo(selected);
  const isToday = sameDay(selected, LOG_TODAY);
  const meta = wkMeta(info.workoutId);
  const items = exList(info);

  const dotClass = (k) => k === 'done' ? 'done' : (k === 'today' || k === 'future') ? 'plan' : k === 'rest' || k === 'rest-today' ? 'rest' : '';

  /* range label */
  const rngEnd = addDays(wkStart, 6);
  const rangeLabel = MON_S[wkStart.getMonth()] + ' ' + wkStart.getDate() + ' – ' +
    (wkStart.getMonth() === rngEnd.getMonth() ? '' : MON_S[rngEnd.getMonth()] + ' ') + rngEnd.getDate();
  const isCurrentWeek = weekStart(selected, cs).getTime() === weekStart(LOG_TODAY, cs).getTime();

  /* ── actions ─────────────────────────────────────────────────── */
  const startWorkout = () => props.onStartWorkout && props.onStartWorkout(meta.name || 'Workout', false);
  const pickAssign = (mode, date) => setSheet({ kind: 'pick', mode, date: date || info.iso });
  const assignWorkout = (wid, mode, dateIso) => {
    const iso = dateIso || info.iso;
    const di = dayInfo(new Date(iso + 'T12:00'));
    const type = mode === 'logpast' ? 'logged' : (di.rel === 'past' ? 'logged' : 'added');
    setOv(iso, { type, workoutId: wid });
    setSelected(new Date(iso + 'T12:00'));
    setSheet(null);
    flash(mode === 'logpast' ? 'Past workout logged' : 'Workout added');
  };

  /* ── sheets ──────────────────────────────────────────────────── */
  function workoutPicker(titleTxt, subTxt, mode, dateIso) {
    return (
      <Sheet onClose={() => setSheet(null)} title={titleTxt} sub={subTxt} max="80%">
        <div className="col" style={{ gap: 10 }}>
          {ALL_WK.map(id => {
            const w = WK_DETAIL[id];
            return (
              <button key={id} className="src-card" style={{ cursor: 'pointer' }} onClick={() => assignWorkout(id, mode, dateIso)}>
                <div className="ph lib-thumb" style={{ width: 44, height: 44, borderRadius: 'var(--r-md)', flex: '0 0 auto' }}></div>
                <div className="grow" style={{ textAlign: 'left' }}>
                  <div className="src-t">{w.name}</div>
                  <div className="src-s">{w.ex.length} exercises · {w.muscles}</div>
                </div>
                <Icon name="chevron-right" size={18} color="var(--text-3)" />
              </button>
            );
          })}
        </div>
      </Sheet>
    );
  }

  function sheetEl() {
    if (!sheet) return null;

    if (sheet.kind === 'menu') {
      return (
        <Sheet onClose={() => setSheet(null)} max="70%">
          <div className="center" style={{ margin: '6px 0 16px' }}>
            <div style={{ fontWeight: 700, fontSize: '15px' }}>{meta.name}</div>
            <div className="tiny muted">Planned for today</div>
          </div>
          <div className="list">
            <MenuRow icon="edit" bg="var(--accent)" label="Edit Workout" sub="Today's session only · won't change your program" chevron onClick={() => setSheet({ kind: 'edit', exercises: items.map(e => ({ ...e })) })} />
            <MenuRow icon="calendar-day" bg="var(--purple)" label="Move to Another Day" sub="Today only · your program stays unchanged" chevron onClick={() => setSheet({ kind: 'move' })} />
            <MenuRow icon="swap" bg="var(--blue)" label="Switch Workout" sub="For today only · your program stays unchanged" chevron onClick={() => setSheet({ kind: 'switch-v2', planId: null })} />
            <MenuRow icon="moon" bg="oklch(0.52 0.06 260)" label="Make it a Rest Day" onClick={() => { setOv(info.iso, { type: 'rest' }); setSheet(null); flash('Marked as rest day'); }} />
            <MenuRow icon="trash" bg="var(--red)" label="Remove from Today" danger onClick={() => { setOv(info.iso, { type: 'removed' }); setSheet(null); flash('Removed from today'); }} />
          </div>
          <button className="btn btn-gray" style={{ marginTop: 14 }} onClick={() => setSheet(null)}>Cancel</button>
          <div className="tiny muted" style={{ textAlign: 'center', marginTop: 12, lineHeight: 1.5, padding: '0 8px' }}>All changes apply to today only and won't affect your program.</div>
        </Sheet>
      );
    }

    if (sheet.kind === 'switch-v2') {
      if (sheet.planId) {
        const plan = OTHER_PLANS.find(p => p.id === sheet.planId);
        return (
          <Sheet onClose={() => setSheet(null)} max="82%">
            <div className="between" style={{ marginBottom: 14 }}>
              <button className="nav-btn" style={{ paddingLeft: 0 }} onClick={() => setSheet(s => ({ ...s, planId: null }))}>
                <Icon name="chevron-left" size={18} /> Back
              </button>
              <div className="nav-title">{plan.name}</div>
              <button className="nav-icon-btn" onClick={() => setSheet(null)}><Icon name="x" size={18} /></button>
            </div>
            <div className="col" style={{ gap: 10 }}>
              {plan.wids.map(wid => {
                const w = WK_DETAIL[wid];
                return (
                  <button key={wid} className="src-card" onClick={() => assignWorkout(wid, 'switch')}>
                    <div className="ph lib-thumb" style={{ width: 44, height: 44, borderRadius: 'var(--r-md)', flex: '0 0 auto' }}></div>
                    <div className="grow" style={{ textAlign: 'left' }}>
                      <div className="src-t">{w.name}</div>
                      <div className="src-s">{w.ex.length} exercises · {w.muscles}</div>
                    </div>
                    <Icon name="chevron-right" size={18} color="var(--text-3)" />
                  </button>
                );
              })}
            </div>
            <button className="btn btn-gray" style={{ marginTop: 14 }} onClick={() => setSheet(null)}>Cancel</button>
          </Sheet>
        );
      }
      return (
        <Sheet onClose={() => setSheet(null)} title="Switch Workout" sub="For today only · your program stays unchanged" max="92%">
          <div className="sec-label" style={{ marginTop: 0, marginBottom: 8 }}>{PROGRAM_NAME} (Active)</div>
          <div className="col" style={{ gap: 10 }}>
            {ALL_WK.map(id => {
              const w = WK_DETAIL[id];
              return (
                <button key={id} className="src-card" onClick={() => assignWorkout(id, 'switch')}>
                  <div className="ph lib-thumb" style={{ width: 44, height: 44, borderRadius: 'var(--r-md)', flex: '0 0 auto' }}></div>
                  <div className="grow" style={{ textAlign: 'left' }}>
                    <div className="src-t">{w.name}</div>
                    <div className="src-s">{w.ex.length} exercises · {w.muscles}</div>
                  </div>
                  <Icon name="chevron-right" size={18} color="var(--text-3)" />
                </button>
              );
            })}
          </div>
          <div className="sec-label">Other Plans</div>
          <div className="col" style={{ gap: 10 }}>
            {OTHER_PLANS.map(plan => (
              <button key={plan.id} className="src-card" onClick={() => setSheet(s => ({ ...s, planId: plan.id }))}>
                <div className="src-ic" style={{ background: 'var(--fill)', color: 'var(--text-2)' }}><Icon name="dumbbell" size={20} /></div>
                <div className="grow" style={{ textAlign: 'left' }}>
                  <div className="src-t">{plan.name}</div>
                  <div className="src-s">{plan.wids.length} workouts</div>
                </div>
                <Icon name="chevron-right" size={18} color="var(--text-3)" />
              </button>
            ))}
          </div>
          <div className="sec-label">Workout Library</div>
          <SrcCard icon="search" bg="color-mix(in oklab,var(--green) 16%,transparent)" color="var(--green)" t="Browse Library" s="Pick exercises from scratch" onClick={() => flash('Opening workout library…')} />
          <button className="btn btn-gray" style={{ marginTop: 14 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }

    if (sheet.kind === 'move') {
      return (
        <Sheet onClose={() => setSheet(null)} title="Move to Another Day" sub="Today only · your program stays unchanged" max="74%">
          <div className="list">
            {weekDays.map(d => {
              const di = dayInfo(d); const m = wkMeta(di.workoutId);
              const isSel = sameDay(d, selected);
              return (
                <button key={di.iso} className="row" style={{ width: '100%', background: 'var(--surface)', border: 0, textAlign: 'left', cursor: isSel ? 'default' : 'pointer', opacity: isSel ? 0.45 : 1 }}
                  disabled={isSel}
                  onClick={() => {
                    setOv(info.iso, { type: 'removed' });
                    setOv(di.iso, { type: 'added', workoutId: info.workoutId });
                    setSheet(null); flash('Moved to ' + DOW_FULL[di.dow]);
                  }}>
                  <div className="ex-n" style={{ width: 38, height: 38, borderRadius: 11, background: 'var(--fill)' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1 }}>
                      <span style={{ fontSize: 9, fontWeight: 800, color: 'var(--text-3)' }}>{DOW_L[di.dow]}</span>
                      <b style={{ fontSize: 13 }}>{d.getDate()}</b>
                    </div>
                  </div>
                  <div className="row-main">
                    <div className="row-title">{DOW_FULL[di.dow]}{isSel ? ' (today)' : ''}</div>
                    <div className="row-sub">{di.workoutId ? m.name : 'Rest day'}</div>
                  </div>
                  {!isSel && <Icon name="chevron-right" size={18} color="var(--text-3)" />}
                </button>
              );
            })}
          </div>
          <button className="btn btn-gray" style={{ marginTop: 14 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }

    if (sheet.kind === 'edit') {
      const exs = sheet.exercises;
      const mut = fn => setSheet(s => { const a = s.exercises.map(e => ({ ...e })); fn(a); return { ...s, exercises: a }; });
      return (
        <Sheet onClose={() => setSheet(null)} title="Edit Workout" sub="Changes apply to today only" max="84%">
          <div className="col" style={{ gap: 9 }}>
            {exs.map((e, i) => (
              <div className="card card-pad" key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 13px' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 14.5, letterSpacing: '-.01em' }}>{e.name}</div>
                  <div className="tiny muted" style={{ marginTop: 2 }}>{e.reps} reps</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: '0 0 auto' }}>
                  <button className="nav-icon-btn" style={{ width: 30, height: 30 }} onClick={() => mut(a => { a[i].sets = Math.max(1, a[i].sets - 1); })}><Icon name="minus" size={15} /></button>
                  <div style={{ fontWeight: 800, fontSize: 15, minWidth: 38, textAlign: 'center' }}>{e.sets}<span className="tiny muted" style={{ fontWeight: 600 }}> set</span></div>
                  <button className="nav-icon-btn" style={{ width: 30, height: 30, background: 'var(--accent-soft)', color: 'var(--accent)' }} onClick={() => mut(a => { a[i].sets = a[i].sets + 1; })}><Icon name="plus" size={15} /></button>
                  <button className="nav-icon-btn" style={{ width: 30, height: 30, color: 'var(--red)' }} onClick={() => mut(a => a.splice(i, 1))}><Icon name="trash" size={14} /></button>
                </div>
              </div>
            ))}
          </div>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => { setOv(info.iso, { ...(info.ov || {}), type: info.ov && info.ov.type === 'logged' ? 'logged' : (info.ov && info.ov.workoutId ? info.ov.type : 'edit'), workoutId: info.workoutId, exercises: exs }); setSheet(null); flash('Workout updated for today'); }}>Save for Today</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }

    if (sheet.kind === 'add') {
      return (
        <Sheet onClose={() => setSheet(null)} title="Add a Workout" max="74%">
          <div className="tiny muted" style={{ margin: '2px 4px 14px' }}>Where should this workout come from?</div>
          <div className="col" style={{ gap: 12 }}>
            <SrcCard icon="sparkle" bg="var(--accent-soft)" color="var(--accent)" t="From your programs" s="Your active PPL plan & saved programs" onClick={() => setSheet({ kind: 'pick', mode: 'add' })} />
            <SrcCard icon="search" bg="color-mix(in oklab,var(--green) 16%,transparent)" color="var(--green)" t="From Workout Library" s="Pick exercises from scratch" onClick={() => setSheet({ kind: 'pick', mode: 'add' })} />
            <SrcCard icon="plus" bg="var(--fill)" color="var(--text-2)" t="Empty Workout" s="Start blank, add as you go" onClick={() => { setSheet(null); props.onStartWorkout && props.onStartWorkout('My Workout', true); }} />
          </div>
        </Sheet>
      );
    }

    if (sheet.kind === 'logpast') {
      const dOpt = sheet.date || isoOf(addDays(LOG_TODAY, -1));
      const optDates = [addDays(LOG_TODAY, -1), addDays(LOG_TODAY, -2)];
      return (
        <Sheet onClose={() => setSheet(null)} title="Log a Past Workout" max="84%">
          <div className="tiny muted" style={{ margin: '0 4px 10px', fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase', fontSize: 11 }}>When did you train?</div>
          <div className="col" style={{ gap: 0, borderRadius: 'var(--r-md)', overflow: 'hidden', border: '1px solid var(--separator-2)' }}>
            {sheet.showToday && (
              <button className="row" style={{ borderRadius: 0, border: 0, borderBottom: '1px solid var(--separator-2)', width: '100%', background: 'color-mix(in oklab,var(--accent) 6%,var(--surface))', textAlign: 'left', cursor: 'pointer' }}
                onClick={() => openLogQuick(info.iso, items)}>
                <div className="row-ic" style={{ background: 'var(--accent-soft)', color: 'var(--accent)' }}><Icon name="bolt" size={17} /></div>
                <div className="row-main">
                  <div className="row-title" style={{ color: 'var(--accent)', fontWeight: 700 }}>Log Today's Workout</div>
                  <div className="row-sub">Set time · enter your sets</div>
                </div>
                <Icon name="chevron-right" size={18} color="var(--accent)" />
              </button>
            )}
            {optDates.map((d, i) => {
              const iso = isoOf(d); const on = dOpt === iso;
              return (
                <button key={iso} className="row" style={{ borderRadius: 0, border: 0, borderBottom: '1px solid var(--separator-2)', width: '100%', background: 'var(--surface)', textAlign: 'left', cursor: 'pointer' }} onClick={() => setSheet(s => ({ ...s, date: iso }))}>
                  <div className="row-main"><div className="row-title">{i === 0 ? 'Yesterday' : i + ' days ago'}</div><div className="row-sub">{DOW_FULL[d.getDay()].slice(0, 3)}, {MON_S[d.getMonth()]} {d.getDate()}</div></div>
                  {on ? <div style={{ width: 20, height: 20, borderRadius: '50%', background: 'var(--accent)', display: 'grid', placeItems: 'center', flex: '0 0 auto' }}><Icon name="check" size={12} color="#fff" /></div>
                      : <div style={{ width: 20, height: 20, borderRadius: '50%', border: '1.5px solid var(--separator)', flex: '0 0 auto' }}></div>}
                </button>
              );
            })}
            <button className="row" style={{ borderRadius: 0, border: 0, width: '100%', background: 'var(--surface)', textAlign: 'left', cursor: 'pointer' }} onClick={() => { setCalMonth(new Date(LOG_TODAY.getFullYear(), LOG_TODAY.getMonth(), 1)); setSheet({ kind: 'cal', forLogPast: true }); }}>
              <div className="row-main"><div className="row-title">Pick a date</div></div>
              <Icon name="chevron-right" size={18} color="var(--text-3)" />
            </button>
          </div>
          <div className="tiny muted" style={{ margin: '18px 4px 10px', fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase', fontSize: 11 }}>Which workout?</div>
          <div className="col" style={{ gap: 10 }}>
            <SrcCard icon="sparkle" bg="var(--accent-soft)" color="var(--accent)" t="From a Program" s="Your active PPL plan & saved programs" onClick={() => setSheet({ kind: 'pick', mode: 'logpast', date: dOpt })} />
            <SrcCard icon="dumbbell" bg="color-mix(in oklab,var(--blue) 16%,transparent)" color="var(--blue)" t="A Saved Workout" s="Custom & predefined workouts" onClick={() => setSheet({ kind: 'pick', mode: 'logpast', date: dOpt })} />
            <SrcCard icon="search" bg="color-mix(in oklab,var(--green) 16%,transparent)" color="var(--green)" t="Build from Library" s="Pick exercises from scratch" onClick={() => setSheet({ kind: 'pick', mode: 'logpast', date: dOpt })} />
          </div>
        </Sheet>
      );
    }

    if (sheet.kind === 'pick') {
      const titleTxt = sheet.mode === 'logpast' ? 'Pick a Workout' : 'Pick a Workout';
      const subTxt = sheet.mode === 'logpast' ? 'Logging to ' + (() => { const d = new Date(sheet.date + 'T12:00'); return DOW_FULL[d.getDay()].slice(0, 3) + ', ' + MON_S[d.getMonth()] + ' ' + d.getDate(); })() : 'Added to ' + (isToday ? 'today' : DOW_FULL[selected.getDay()]);
      return workoutPicker(titleTxt, subTxt, sheet.mode, sheet.date);
    }

    if (sheet.kind === 'cal') {
      const first = new Date(calMonth.getFullYear(), calMonth.getMonth(), 1);
      const startPad = first.getDay();
      const dim = new Date(calMonth.getFullYear(), calMonth.getMonth() + 1, 0).getDate();
      const cells = [];
      for (let i = 0; i < startPad; i++) cells.push(null);
      for (let d = 1; d <= dim; d++) cells.push(new Date(calMonth.getFullYear(), calMonth.getMonth(), d));
      const canGoNextMonth = calMonth.getFullYear() < LOG_TODAY.getFullYear() ||
        (calMonth.getFullYear() === LOG_TODAY.getFullYear() && calMonth.getMonth() < LOG_TODAY.getMonth());
      return (
        <Sheet onClose={() => setSheet(null)} max="80%">
          <div className="between" style={{ marginBottom: 14 }}>
            <div className="nav-title">{MON_F[calMonth.getMonth()] + ' ' + calMonth.getFullYear()}</div>
            <div className="flex" style={{ gap: 6, alignItems: 'center' }}>
              <button className="nav-icon-btn" onClick={() => setCalMonth(new Date(calMonth.getFullYear(), calMonth.getMonth() - 1, 1))}><Icon name="chevron-left" size={18} /></button>
              <button className="nav-icon-btn" style={{ opacity: canGoNextMonth ? 1 : 0.28, pointerEvents: canGoNextMonth ? 'auto' : 'none' }} disabled={!canGoNextMonth} onClick={() => { if (canGoNextMonth) setCalMonth(new Date(calMonth.getFullYear(), calMonth.getMonth() + 1, 1)); }}><Icon name="chevron-right" size={18} /></button>
              <button className="nav-icon-btn" onClick={() => setSheet(null)}><Icon name="x" size={18} /></button>
            </div>
          </div>
          <div className="cal-grid head"><span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span></div>
          <div className="cal-grid">
            {cells.map((d, i) => {
              if (!d) return <span key={i} className="cal-d off"></span>;
              const di = dayInfo(d); const today = sameDay(d, LOG_TODAY); const sel = sameDay(d, selected);
              const isFuture = D0(d).getTime() > D0(LOG_TODAY).getTime();
              return (
                <span key={i}
                  className={'cal-d' + (today ? ' today' : '') + (sel && !today ? ' seld' : '')}
                  style={{ cursor: isFuture ? 'default' : 'pointer', opacity: isFuture && !today ? 0.28 : 1 }}
                  onClick={() => { if (isFuture) return; if (sheet.forLogPast) { setSheet({ kind: 'logpast', date: di.iso }); } else { setSelected(d); setSheet(null); } }}>
                  {d.getDate()}
                  {dotClass(di.kind) && !isFuture && <i className={'dot ' + dotClass(di.kind)}></i>}
                </span>
              );
            })}
          </div>
          <div className="flex gap4" style={{ margin: '16px 4px 8px', fontSize: 12 }}>
            <span className="leg"><i className="dot done"></i> Completed</span>
            <span className="leg"><i className="dot plan"></i> Planned</span>
            <span className="leg"><i className="dot rest"></i> Rest</span>
          </div>
          {!sheet.forLogPast && <button className="btn btn-primary" style={{ marginTop: 8 }} onClick={() => { setSelected(LOG_TODAY); setSheet(null); }}>Go to Today</button>}
        </Sheet>
      );
    }
    if (sheet.kind === 'view-log') {
      const log = workoutLogs[info.iso];
      const logExs = log ? log.exercises : items.map(e => ({ name: e.name, sets: Array.from({ length: e.sets }, () => ({ weight: '—', reps: e.reps })) }));
      const logTime = log ? log.time : null;
      return (
        <Sheet onClose={() => setSheet(null)} title="Workout Log" sub={meta.name + (logTime ? '  ·  ' + logTime : '')} max="88%">
          <div className="col" style={{ gap: 12 }}>
            {logExs.map((ex, i) => (
              <div className="card card-pad" key={i} style={{ padding: '12px 14px' }}>
                <div style={{ fontWeight: 700, fontSize: 14.5, letterSpacing: '-.01em', marginBottom: 10 }}>{ex.name}</div>
                <div style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr', gap: '4px 10px', fontSize: 11, fontWeight: 700, color: 'var(--text-3)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '.04em' }}>
                  <span>Set</span><span>Weight</span><span>Reps</span>
                </div>
                {ex.sets.map((s, j) => (
                  <div key={j} style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr', gap: '4px 10px', fontSize: 15, fontWeight: 600, padding: '7px 0', borderTop: '1px solid var(--separator-2)' }}>
                    <span style={{ color: 'var(--text-3)', fontSize: 13, fontWeight: 700 }}>{j + 1}</span>
                    <span>{s.weight || '—'}</span>
                    <span>{s.reps || '—'}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
          <button className="btn btn-gray" style={{ marginTop: 16 }} onClick={() => {
            const log2 = workoutLogs[info.iso];
            const exs = log2 ? log2.exercises.map(e => ({ ...e, sets: e.sets.map(s => ({ ...s })) })) : items.map(e => ({ name: e.name, sets: Array.from({ length: e.sets }, () => ({ weight: '', reps: '' })) }));
            setSheet({ kind: 'edit-log', exercises: exs });
          }}><Icon name="edit" size={17} /> Edit Log</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Close</button>
        </Sheet>
      );
    }

    if (sheet.kind === 'edit-log') {
      const exs = sheet.exercises;
      const mutEx = fn => setSheet(s => { const a = s.exercises.map(e => ({ ...e, sets: e.sets.map(ss => ({ ...ss })) })); fn(a); return { ...s, exercises: a }; });
      return (
        <Sheet onClose={() => setSheet(null)} title="Edit Log" sub={meta.name} max="92%">
          <div className="col" style={{ gap: 14 }}>
            {exs.map((ex, i) => (
              <div className="card card-pad" key={i} style={{ padding: '12px 14px' }}>
                <div style={{ fontWeight: 700, fontSize: 14.5, letterSpacing: '-.01em', marginBottom: 10 }}>{ex.name}</div>
                <div style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 32px', gap: '4px 8px', fontSize: 11, fontWeight: 700, color: 'var(--text-3)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '.04em' }}>
                  <span>Set</span><span>Weight</span><span>Reps</span><span></span>
                </div>
                {ex.sets.map((s, j) => (
                  <div key={j} style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 32px', gap: '4px 8px', alignItems: 'center', padding: '5px 0', borderTop: '1px solid var(--separator-2)' }}>
                    <span style={{ color: 'var(--text-3)', fontSize: 12, fontWeight: 700 }}>{j + 1}</span>
                    <input style={{ background: 'var(--fill)', border: 'none', borderRadius: 8, padding: '7px 10px', fontSize: 15, fontWeight: 700, color: 'var(--text)', fontFamily: 'var(--font)', width: '100%', outline: 'none', textAlign: 'center' }}
                      placeholder="—" value={s.weight} onChange={ev => mutEx(a => { a[i].sets[j].weight = ev.target.value; })} />
                    <input style={{ background: 'var(--fill)', border: 'none', borderRadius: 8, padding: '7px 10px', fontSize: 15, fontWeight: 700, color: 'var(--text)', fontFamily: 'var(--font)', width: '100%', outline: 'none', textAlign: 'center' }}
                      placeholder="—" value={s.reps} onChange={ev => mutEx(a => { a[i].sets[j].reps = ev.target.value; })} />
                    <button style={{ width: 28, height: 28, background: 'none', border: 'none', color: 'var(--red)', cursor: 'pointer', display: 'grid', placeItems: 'center', borderRadius: 6 }}
                      onClick={() => mutEx(a => a[i].sets.splice(j, 1))}><Icon name="minus-c" size={15} /></button>
                  </div>
                ))}
                <button style={{ marginTop: 10, background: 'var(--accent-soft)', border: 'none', borderRadius: 8, padding: '7px 12px', fontSize: 13, fontWeight: 700, color: 'var(--accent)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5 }}
                  onClick={() => mutEx(a => a[i].sets.push({ weight: '', reps: '' }))}>
                  <Icon name="plus" size={14} /> Add Set
                </button>
              </div>
            ))}
          </div>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => {
            setWorkoutLogs(l => ({ ...l, [info.iso]: { ...(workoutLogs[info.iso] || {}), exercises: exs } }));
            setOv(info.iso, { ...(info.ov || {}), type: 'logged', workoutId: info.workoutId });
            setSheet(null); flash('Log saved');
          }}>Save Log</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }

    if (sheet.kind === 'log-quick') {
      const qIso = sheet.iso || info.iso;
      const exs = sheet.exercises || [];
      const mutEx = fn => setSheet(s => { const a = (s.exercises || []).map(e => ({ ...e, sets: e.sets.map(ss => ({ ...ss })) })); fn(a); return { ...s, exercises: a }; });
      return (
        <Sheet onClose={() => setSheet(null)} title="Log Workout" sub={meta.name} max="93%">
          <div className="card card-pad" style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--accent-soft)', display: 'grid', placeItems: 'center', color: 'var(--accent)', flex: '0 0 auto' }}>
              <Icon name="clock" size={18} />
            </div>
            <div className="grow">
              <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: '.05em', textTransform: 'uppercase' }}>Workout Time</div>
              <div style={{ fontSize: 13, color: 'var(--text-2)', marginTop: 2 }}>When did you train?</div>
            </div>
            <input type="time" value={sheet.time}
              style={{ background: 'var(--fill)', border: 'none', borderRadius: 10, padding: '8px 12px', fontSize: 16, fontWeight: 700, color: 'var(--text)', fontFamily: 'var(--font)', outline: 'none', flex: '0 0 auto' }}
              onChange={ev => setSheet(s => ({ ...s, time: ev.target.value }))} />
          </div>
          <div className="col" style={{ gap: 14 }}>
            {exs.map((ex, i) => (
              <div className="card card-pad" key={i} style={{ padding: '12px 14px' }}>
                <div style={{ fontWeight: 700, fontSize: 14.5, letterSpacing: '-.01em', marginBottom: 10 }}>{ex.name}</div>
                <div style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 32px', gap: '4px 8px', fontSize: 11, fontWeight: 700, color: 'var(--text-3)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '.04em' }}>
                  <span>Set</span><span>Weight</span><span>Reps</span><span></span>
                </div>
                {ex.sets.map((s, j) => (
                  <div key={j} style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 32px', gap: '4px 8px', alignItems: 'center', padding: '5px 0', borderTop: '1px solid var(--separator-2)' }}>
                    <span style={{ color: 'var(--text-3)', fontSize: 12, fontWeight: 700 }}>{j + 1}</span>
                    <input style={{ background: 'var(--fill)', border: 'none', borderRadius: 8, padding: '7px 10px', fontSize: 15, fontWeight: 700, color: 'var(--text)', fontFamily: 'var(--font)', width: '100%', outline: 'none', textAlign: 'center' }}
                      placeholder="kg" value={s.weight} onChange={ev => mutEx(a => { a[i].sets[j].weight = ev.target.value; })} />
                    <input style={{ background: 'var(--fill)', border: 'none', borderRadius: 8, padding: '7px 10px', fontSize: 15, fontWeight: 700, color: 'var(--text)', fontFamily: 'var(--font)', width: '100%', outline: 'none', textAlign: 'center' }}
                      placeholder="reps" value={s.reps} onChange={ev => mutEx(a => { a[i].sets[j].reps = ev.target.value; })} />
                    <button style={{ width: 28, height: 28, background: 'none', border: 'none', color: 'var(--red)', cursor: 'pointer', display: 'grid', placeItems: 'center', borderRadius: 6 }}
                      onClick={() => mutEx(a => a[i].sets.splice(j, 1))}><Icon name="minus-c" size={15} /></button>
                  </div>
                ))}
                <button style={{ marginTop: 10, background: 'var(--accent-soft)', border: 'none', borderRadius: 8, padding: '7px 12px', fontSize: 13, fontWeight: 700, color: 'var(--accent)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5 }}
                  onClick={() => mutEx(a => a[i].sets.push({ weight: '', reps: '' }))}>
                  <Icon name="plus" size={14} /> Add Set
                </button>
              </div>
            ))}
          </div>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => {
            const dow = new Date(qIso + 'T12:00').getDay();
            const wid = (overrides[qIso] || {}).workoutId || PLAN_BY_DOW[dow];
            setWorkoutLogs(l => ({ ...l, [qIso]: { time: sheet.time, exercises: exs } }));
            setOv(qIso, { ...(overrides[qIso] || {}), type: 'logged', workoutId: wid });
            setSheet(null); flash('Workout logged!');
          }}>Save Workout</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }

    return null;
  }

  /* ── body by day state ───────────────────────────────────────── */
  function body() {
    const k = info.kind;

    if (k === 'rest' || k === 'rest-today' || k === 'empty-today') {
      const empty = k === 'empty-today';
      return (
        <div className="screen-body pad pad-b">
          <div className="card card-pad center" style={{ borderRadius: 'var(--r-xl)', padding: '38px 24px', marginTop: 8, borderStyle: empty ? 'dashed' : 'solid' }}>
            <div style={{ width: 64, height: 64, borderRadius: '50%', background: empty ? 'var(--accent-soft)' : 'var(--fill)', display: 'grid', placeItems: 'center', margin: '0 auto 16px', color: empty ? 'var(--accent)' : 'var(--text-2)' }}>
              <Icon name={empty ? 'plus' : 'moon'} size={30} />
            </div>
            <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-.02em' }}>{empty ? 'Nothing planned' : 'Rest Day'}</div>
            <div className="tiny muted" style={{ marginTop: 6, lineHeight: 1.5, maxWidth: 250, marginInline: 'auto' }}>
              {empty ? 'No workout scheduled. Start something fresh or log a session you already did.' : 'Recovery is where the gains happen. Nothing scheduled' + (isToday ? ' today' : '') + '.'}
            </div>
          </div>
          {info.rel !== 'future' && <>
            <div className="sec-label">{empty ? '\u00a0' : 'Did you train' + (isToday ? '' : ' that day') + ' anyway?'}</div>
            <div className="col" style={{ gap: 10 }}>
              <button className="btn btn-tinted"
                onClick={() => isToday ? setSheet({ kind: 'add' }) : setSheet({ kind: 'pick', mode: 'logpast', date: info.iso })}>
                <Icon name="plus" size={18} /> {isToday ? 'Add a Workout' : 'Log a Workout'}
              </button>
              {isToday && <button className="btn btn-gray" onClick={() => setSheet({ kind: 'logpast', date: isoOf(addDays(LOG_TODAY, -1)), showToday: false })}><Icon name="clock" size={17} /> Log a Past Workout</button>}
            </div>
          </>}
          {info.rel === 'future' && <div className="hint-card" style={{ marginTop: 14 }}><Icon name="info" size={18} color="var(--text-2)" /><div className="tiny" style={{ lineHeight: 1.5, color: 'var(--text-2)' }}>Scheduled rest day. Enjoy the recovery — your next session is just around the corner.</div></div>}
        </div>
      );
    }

    /* a card-based state (today / done / missed / future) */
    const head = {
      today: { badges: [['accent', 'sparkle', PROGRAM_NAME]], right: 'menu' },
      done: { badges: [['accent', 'sparkle', PROGRAM_NAME], ['green', 'check', 'Completed']], right: 'done' },
      missed: { badges: [['accent', 'sparkle', PROGRAM_NAME], ['red', 'x', 'Missed']], right: 'missed' },
      future: { badges: [['accent', 'sparkle', PROGRAM_NAME]], right: 'viewonly' },
    }[k];

    return (
      <div className="screen-body pad pad-b">
        <div className="flex" style={{ gap: 8, flexWrap: 'wrap', margin: '4px 0 10px' }}>
          {head.badges.map((b, i) => i === 0
            ? <div key={i} className="badge badge-accent"><Icon name={b[1]} size={13} /> {b[2]}</div>
            : <div key={i} className="badge" style={{ background: 'color-mix(in oklab,var(--' + b[0] + ') 13%,transparent)', color: 'var(--' + b[0] + ')' }}><Icon name={b[1]} size={12} /> {b[2]}</div>)}
        </div>
        <div className="card card-pad" style={{ borderRadius: 'var(--r-xl)' }}>
          <div className="between">
            <div>
              <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-.02em' }}>{meta.name}</div>
              <div className="tiny muted" style={{ marginTop: 2 }}>{items.length} exercises · {meta.muscles}</div>
            </div>
            {head.right === 'menu' && <button className="nav-icon-btn" onClick={() => setSheet({ kind: 'menu' })}><Icon name="ellipsis" size={20} /></button>}
            {head.right === 'done' && <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'color-mix(in oklab,var(--green) 14%,transparent)', display: 'grid', placeItems: 'center', color: 'var(--green)', flex: '0 0 auto' }}><Icon name="check-c" size={18} /></div>}
            {head.right === 'missed' && <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'color-mix(in oklab,var(--red) 12%,transparent)', display: 'grid', placeItems: 'center', color: 'var(--red)', flex: '0 0 auto' }}><Icon name="x-c" size={18} /></div>}
            {head.right === 'viewonly' && <div className="badge" style={{ fontSize: 11, background: 'var(--fill)', color: 'var(--text-3)', padding: '5px 9px' }}>View only</div>}
          </div>
          <div className="divider" style={{ margin: '14px 0' }}></div>
          <ExRows items={items} dim={k === 'missed' || k === 'future'} />
        </div>

        {k === 'today' && (
          <div className="col" style={{ gap: 10, marginTop: 16 }}>
            <button className="btn btn-primary" onClick={startWorkout}><Icon name="play" size={18} /> Start Workout</button>
            <div className="flex gap3">
              <button className="btn btn-gray btn-sm grow" style={{ width: 'auto' }} onClick={() => setSheet({ kind: 'logpast', date: isoOf(addDays(LOG_TODAY, -1)), showToday: true })}><Icon name="clock" size={17} /> Log past</button>
              <button className="btn btn-gray btn-sm grow" style={{ width: 'auto' }} onClick={() => setSheet({ kind: 'switch-v2', planId: null })}><Icon name="swap" size={17} /> Switch</button>
            </div>
          </div>
        )}
        {k === 'done' && (
          <div className="col" style={{ gap: 10, marginTop: 16 }}>
            <button className="btn btn-primary" onClick={() => setSheet({ kind: 'view-log' })}><Icon name="note" size={18} /> View Log</button>
            <button className="btn btn-gray" onClick={() => {
              const log = workoutLogs[info.iso];
              const exs = log ? log.exercises.map(e => ({ ...e, sets: e.sets.map(s => ({ ...s })) })) : items.map(e => ({ name: e.name, sets: Array.from({ length: e.sets }, () => ({ weight: '', reps: '' })) }));
              setSheet({ kind: 'edit-log', exercises: exs });
            }}><Icon name="edit" size={17} /> Edit Log</button>
          </div>
        )}
        {k === 'missed' && (
          <div className="col" style={{ gap: 10, marginTop: 16 }}>
            <button className="btn btn-primary" onClick={() => setSheet({ kind: 'pick', mode: 'logpast', date: info.iso })}><Icon name="clock" size={18} /> Log Workout</button>
            <button className="btn btn-gray" onClick={() => { setOv(info.iso, { type: 'rest' }); flash('Marked as rest day'); }}><Icon name="moon" size={17} /> Mark as Rest Day</button>
          </div>
        )}
        {k === 'future' && (
          <>
            <div className="col" style={{ gap: 10, marginTop: 16 }}>
              <button className="btn btn-gray" onClick={() => flash('Read-only preview')}><Icon name="note" size={18} /> View Workout</button>
            </div>
            <div className="card" style={{ marginTop: 12, padding: '14px 16px', background: 'color-mix(in oklab,var(--accent) 8%,transparent)', borderColor: 'color-mix(in oklab,var(--accent) 22%,transparent)', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
              <Icon name="info" size={18} color="var(--accent)" style={{ flex: '0 0 auto', marginTop: 1 }} />
              <div>
                <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: '-.01em' }}>Future workouts are read-only</div>
                <div className="tiny muted" style={{ marginTop: 3, lineHeight: 1.5 }}>To change this workout, edit your program in the Plans tab.</div>
                <button className="btn-ghost" style={{ fontSize: 13, fontWeight: 700, color: 'var(--accent)', padding: '6px 0 0', background: 'none', border: 0, cursor: 'pointer' }} onClick={() => props.onTab && props.onTab('plan')}>Go to Plans →</button>
              </div>
            </div>
          </>
        )}
      </div>
    );
  }

  /* ── shell ───────────────────────────────────────────────────── */
  const navTitle = isToday ? 'Today' : DOW_FULL[selected.getDay()];
  const navSub = DOW_FULL[selected.getDay()].toUpperCase() + ', ' + MON_S[selected.getMonth()].toUpperCase() + ' ' + selected.getDate();

  return (
    <div className="phone" data-theme={props.dark ? 'dark' : 'light'}>
      <div className="dynamic-island"></div>
      <div className="statusbar auto"></div>
      <div className="navbar">
        <div className="navbar-row">
          <div>
            <div className="tiny muted" style={{ fontWeight: 700, letterSpacing: '.02em' }}>{navSub}</div>
            <div className="nav-title-lg">{navTitle}</div>
          </div>
          <button className="nav-icon-btn" onClick={() => { setCalMonth(new Date(selected.getFullYear(), selected.getMonth(), 1)); setSheet({ kind: 'cal' }); }}><Icon name="calendar-day" size={19} /></button>
        </div>
      </div>

      {/* week bar */}
      <div style={{ padding: '6px 14px 12px', flex: '0 0 auto' }}>
        <div className="between" style={{ padding: '0 2px 8px' }}>
          <div className="flex" style={{ gap: 6, alignItems: 'center' }}>
            <button className="nav-icon-btn" style={{ width: 28, height: 28 }} onClick={() => setSelected(addDays(selected, -7))}><Icon name="chevron-left" size={17} /></button>
            <div style={{ fontSize: 14, fontWeight: 700, whiteSpace: 'nowrap' }}>{rangeLabel}</div>
            <button className="nav-icon-btn" style={{ width: 28, height: 28, opacity: isCurrentWeek ? 0.28 : 1, pointerEvents: isCurrentWeek ? 'none' : 'auto' }} disabled={isCurrentWeek} onClick={() => setSelected(addDays(selected, 7))}><Icon name="chevron-right" size={17} /></button>
          </div>
          {!sameDay(weekStart(selected,cs), weekStart(LOG_TODAY,cs)) || !isToday
            ? <button className="btn-ghost tiny" style={{ fontWeight: 700 }} onClick={() => setSelected(LOG_TODAY)}>Today ›</button>
            : <span></span>}
        </div>
        <div className="flex" style={{ gap: 6 }}>
          {weekDays.map(d => {
            const di = dayInfo(d); const sel = sameDay(d, selected);
            const dc = dotClass(di.kind);
            const missed = di.kind === 'missed';
            return (
              <button key={di.iso} className={'wk' + (sel ? ' sel' : '')} style={{ border: 0, background: sel ? 'var(--accent)' : 'transparent', fontFamily: 'var(--font)' }} onClick={() => setSelected(new Date(d))}>
                <span>{DOW_L[di.dow]}</span><b>{d.getDate()}</b>
                {missed ? <i className="dot" style={{ background: sel ? '#fff' : 'color-mix(in oklab,var(--red) 75%,transparent)' }}></i>
                  : dc ? <i className={'dot ' + dc}></i> : <i className="dot" style={{ background: 'transparent' }}></i>}
              </button>
            );
          })}
        </div>
      </div>

      {body()}
      {sheetEl()}

      {toast && <div style={{ position: 'absolute', bottom: 100, left: '50%', transform: 'translateX(-50%)', background: 'var(--text)', color: 'var(--bg)', fontSize: 13, fontWeight: 600, padding: '9px 16px', borderRadius: 999, zIndex: 90, boxShadow: '0 8px 24px rgba(0,0,0,.22)', whiteSpace: 'nowrap' }}>{toast}</div>}

      {props.inProgress && (
        <button onClick={startWorkout} style={{ position: 'absolute', bottom: 96, left: 14, right: 14, background: 'var(--accent)', borderRadius: 'var(--r-lg)', padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12, color: '#fff', boxShadow: '0 8px 32px rgba(0,0,0,.2)', zIndex: 70, border: 0, cursor: 'pointer', fontFamily: 'var(--font)', textAlign: 'left' }}>
          <Icon name="bolt" size={20} style={{ flex: '0 0 auto' }} />
          <div className="grow">
            <div style={{ fontWeight: 800, fontSize: 15 }}>Workout in progress</div>
            <div style={{ fontSize: 13, opacity: .85 }}>Tap to resume your session</div>
          </div>
          <span style={{ background: 'rgba(255,255,255,.2)', borderRadius: 'var(--r-sm)', padding: '7px 14px', fontSize: 14, fontWeight: 700, flex: '0 0 auto' }}>Resume</span>
        </button>
      )}

      <AuraTabBar active={props.tab||'log'} onTab={props.onTab}
        onAction={k => {
          if (k==='workout') setSheet({ kind:'add' });
          else props.onTab && props.onTab('progress');
        }} />
      <div className="home-indicator"></div>
    </div>
  );
}

window.LogTab = LogTab;
})();
