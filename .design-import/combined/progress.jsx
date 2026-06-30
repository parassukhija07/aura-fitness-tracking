/* Aura — Progress tab: Stats + Body (Measurements / Nutrition). Fully interactive. */
(function () {
const { useState } = React;
const Seg = window.AuraSeg, LineChart = window.LineChart, TabBar = window.AuraTabBar;

/* ── local sheet ──────────────────────────────────────────────── */
function Sheet({ onClose, max, title, sub, children }) {
  return (
    <div className="sheet">
      <div className="scrim" onClick={onClose}></div>
      <div className="sheet-card" style={{ maxHeight: max || '78%' }}>
        <div className="grabber"></div>
        {title && (
          <div className="between pad" style={{ paddingBottom: 8 }}>
            <div><div className="nav-title">{title}</div>{sub && <div className="tiny muted" style={{ marginTop: 2 }}>{sub}</div>}</div>
            <button className="nav-icon-btn" onClick={onClose}><Icon name="x" size={18} /></button>
          </div>
        )}
        <div className="pad" style={{ overflow: 'auto', paddingBottom: 28 }}>{children}</div>
      </div>
    </div>
  );
}

/* ── seed data ────────────────────────────────────────────────── */
const MON_F = ['January', 'February', 'March', 'April', 'May', 'June'];
const HEAT_BG = ['var(--fill)', 'color-mix(in oklab,var(--green) 26%,var(--surface))', 'color-mix(in oklab,var(--accent) 42%,var(--surface))', 'color-mix(in oklab,var(--green) 62%,var(--surface))', 'var(--green)'];
const HEAT_LABEL = ['Rest', 'Partial', 'Swapped', 'Completed', 'PR day'];
function genMonth(y, m) {
  const first = new Date(y, m, 1).getDay();
  const dim = new Date(y, m + 1, 0).getDate();
  let seed = (y * 12 + m) * 97 + 13;
  const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  const days = [];
  for (let d = 1; d <= dim; d++) {
    const r = rnd();
    days.push(r < 0.32 ? 0 : r < 0.45 ? 1 : r < 0.55 ? 2 : r < 0.9 ? 3 : 4);
  }
  return { first, days };
}

const PR_DATA = {
  Chest: [['Barbell Bench Press', '82.5 kg', '6', 'May 28'], ['Incline DB Press', '34 kg', '9', 'May 21'], ['Cable Fly', '17.5 kg', '14', 'Jun 4'], ['Weighted Dips', '25 kg', '10', 'Jun 18']],
  Back: [['Deadlift', '180 kg', '3', 'Jun 11'], ['Barbell Row', '100 kg', '6', 'May 30'], ['Pull-ups', '20 kg', '8', 'Jun 7'], ['Lat Pulldown', '82 kg', '10', 'Jun 14']],
  Legs: [['Barbell Squat', '140 kg', '5', 'Jun 4'], ['Romanian Deadlift', '120 kg', '8', 'May 28'], ['Leg Press', '300 kg', '10', 'Jun 12']],
  Shoulders: [['Overhead Press', '60 kg', '6', 'Jun 1'], ['Lateral Raise', '14 kg', '15', 'Jun 9'], ['Arnold Press', '24 kg', '10', 'May 25']],
  Arms: [['Barbell Curl', '45 kg', '8', 'Jun 6'], ['Hammer Curl', '24 kg', '10', 'Jun 13'], ['Skull Crushers', '40 kg', '9', 'May 27'], ['Tricep Pushdown', '40 kg', '12', 'Jun 16']],
};
const PR_CATS = Object.keys(PR_DATA);

const WEEKLY_VOL = [21.4, 24.8, 22.1, 26.5, 25.2, 28.9, 27.4, 31.2];
const WEEKLY_SETS = [62, 71, 64, 78, 74, 84, 80, 91];
const SPLIT = [['Chest', 92], ['Back', 78], ['Legs', 64], ['Shoulders', 56], ['Arms', 48], ['Core', 30]];

const M_DEFS = [
  { k: 'weight', label: 'Weight', unit: 'kg' }, { k: 'bodyFat', label: 'Body fat', unit: '%' },
  { k: 'chest', label: 'Chest', unit: 'cm' }, { k: 'waist', label: 'Waist', unit: 'cm' },
  { k: 'arms', label: 'Arms', unit: 'cm' }, { k: 'thighs', label: 'Thighs', unit: 'cm' },
  { k: 'shoulders', label: 'Shoulders', unit: 'cm' }, { k: 'neck', label: 'Neck', unit: 'cm' }, { k: 'hips', label: 'Hips', unit: 'cm' },
];
const SEED_SERIES = {
  weight: [76.2, 76.8, 77.1, 77.6, 77.9, 78.0, 78.2, 78.4], bodyFat: [18.1, 17.8, 17.4, 17.0, 16.8, 16.5, 16.3, 16.2],
  chest: [101, 101.5, 102, 102.5, 103, 103.5, 103.8, 104], waist: [84, 83.6, 83.2, 82.8, 82.5, 82.3, 82.1, 82],
  arms: [37, 37.3, 37.6, 37.9, 38.1, 38.3, 38.4, 38.5], thighs: [57, 57.4, 57.8, 58.2, 58.5, 58.7, 58.9, 59],
  shoulders: [119, 119.6, 120.2, 120.8, 121.2, 121.6, 121.8, 122], neck: [38.4, 38.5, 38.6, 38.7, 38.8, 38.9, 39, 39], hips: [97, 96.8, 96.6, 96.4, 96.2, 96.1, 96, 96],
};
const HOW_TO = [
  ['Chest', 'Around the fullest part, under the armpits, arms relaxed.'],
  ['Waist', 'At the narrowest point, usually just above the navel.'],
  ['Arms', 'Flexed bicep at its peak, mid-upper arm.'],
  ['Thighs', 'Around the largest part of the upper thigh.'],
  ['Shoulders', 'Around the widest part, over the deltoids.'],
  ['Neck', 'At the middle, just below the Adam\u2019s apple.'],
];
const ACT = { Sedentary: 1.2, Light: 1.375, Moderate: 1.55, Active: 1.725, Athlete: 1.9 };
const GOAL_ADJ = { 'Lose fat': -500, 'Maintain': 0, 'Lean gain': 200, 'Gain muscle': 400 };
const MACRO_SPLIT = { Balanced: [30, 40, 30], 'High carb': [25, 55, 20], 'High protein': [40, 35, 25], Keto: [30, 8, 62] };

/* ── Exercise trend seed data ─────────────────────────────── */
const EX_NAMES = ['Barbell Bench Press','Barbell Squat','Deadlift','Barbell Row','Overhead Press','Barbell Curl','Pull-ups','Romanian Deadlift','Leg Press','Lateral Raise','Cable Fly','Incline DB Press'];
const EX_META = {
  'Barbell Bench Press': { muscle:'Chest',     equip:'Barbell' },
  'Barbell Squat':       { muscle:'Legs',      equip:'Barbell' },
  'Deadlift':            { muscle:'Back',      equip:'Barbell' },
  'Barbell Row':         { muscle:'Back',      equip:'Barbell' },
  'Overhead Press':      { muscle:'Shoulders', equip:'Barbell' },
  'Barbell Curl':        { muscle:'Arms',      equip:'Barbell' },
  'Pull-ups':            { muscle:'Back',      equip:'Bodyweight' },
  'Romanian Deadlift':   { muscle:'Legs',      equip:'Barbell' },
  'Leg Press':           { muscle:'Legs',      equip:'Machine' },
  'Lateral Raise':       { muscle:'Shoulders', equip:'Dumbbell' },
  'Cable Fly':           { muscle:'Chest',     equip:'Cable' },
  'Incline DB Press':    { muscle:'Chest',     equip:'Dumbbell' },
};
const EX_MUSCLE_COLOR = {
  Chest:    { soft:'oklch(0.93 0.05 58)',  tx:'oklch(0.46 0.18 54)',  active:'oklch(0.54 0.18 54)' },
  Back:     { soft:'oklch(0.93 0.04 248)', tx:'oklch(0.44 0.13 248)', active:'oklch(0.50 0.14 248)' },
  Shoulders:{ soft:'oklch(0.93 0.04 284)', tx:'oklch(0.44 0.12 283)', active:'oklch(0.50 0.13 283)' },
  Arms:     { soft:'oklch(0.93 0.05 151)', tx:'oklch(0.44 0.14 149)', active:'oklch(0.50 0.15 149)' },
  Legs:     { soft:'oklch(0.93 0.05 31)',  tx:'oklch(0.44 0.13 27)',  active:'oklch(0.50 0.14 27)' },
  Core:     { soft:'oklch(0.93 0.04 19)',  tx:'oklch(0.44 0.13 17)',  active:'oklch(0.50 0.14 17)' },
};
function _genEx(b1, bW, bR, bV) {
  const n = 12;
  return {
    '1rm':    Array.from({length:n},(_,i)=>+(b1  + i*(b1*0.020)).toFixed(1)),
    'weight': Array.from({length:n},(_,i)=>+(bW  + i*(bW*0.014)).toFixed(1)),
    'reps':   Array.from({length:n},(_,i)=>Math.min(15, bR + Math.floor(i*0.35))),
    'volume': Array.from({length:n},(_,i)=>Math.round(bV + i*(bV*0.028))),
  };
}
const EX_DATA = {
  'Barbell Bench Press': _genEx(70,62,5,1400),
  'Barbell Squat':       _genEx(120,100,5,2000),
  'Deadlift':            _genEx(160,140,3,2100),
  'Barbell Row':         _genEx(90,78,6,1440),
  'Overhead Press':      _genEx(52,45,5,900),
  'Barbell Curl':        _genEx(42,37,7,780),
  'Pull-ups':            _genEx(22,15,5,450),
  'Romanian Deadlift':   _genEx(110,95,7,1995),
  'Leg Press':           _genEx(220,185,8,5920),
  'Lateral Raise':       _genEx(18,14,12,504),
  'Cable Fly':           _genEx(28,22,13,858),
  'Incline DB Press':    _genEx(58,48,8,1152),
};
const EX_XLABELS = {
  '1y': ['Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'],
  '6m': ['Jan','Feb','Mar','Apr','May','Jun'],
  '3m': ['Apr','May','Jun'],
  '1m': ['W1','W2','W3','W4'],
};
const EX_METRIC_META = {
  '1rm':    { label:'1 Rep Max',   unit:'kg' },
  'weight': { label:'Max Weight',  unit:'kg' },
  'reps':   { label:'Max Reps',    unit:''   },
  'volume': { label:'Max Volume',  unit:'kg' },
};
function sliceEx(name, metric, range) {
  const all = (EX_DATA[name] || EX_DATA['Barbell Bench Press'])[metric];
  if (range==='1y') return all;
  if (range==='6m') return all.slice(6);
  if (range==='3m') return all.slice(9);
  // 1m: interpolate last month into 4 weekly points
  const last = all[all.length-1], prev = all[all.length-2];
  return [+(prev*0.88+last*0.12).toFixed(1),+(prev*0.60+last*0.40).toFixed(1),+(prev*0.28+last*0.72).toFixed(1),+last.toFixed(1)];
}

/* ── Axis chart (with X/Y labels + grid) ─────────────────── */
function AxisChart({ data, xLabels, unit, color='var(--accent)', h=160 }) {
  const W=300, H=h, pL=48, pB=24, pT=10, pR=8;
  const n = data.length;
  if (!n) return null;
  const rawMax = Math.max(...data), rawMin = Math.min(...data);
  // Always produce exactly 4 clean Y ticks
  function niceStep(range) {
    if (!range || !isFinite(range)) return 1;
    // Find magnitude then snap to 1/2/5 multiples — always round UP for wider intervals
    const mag = Math.pow(10, Math.floor(Math.log10(range / 3)));
    const norm = range / 3 / mag;
    return (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag;
  }
  const rng = rawMax - rawMin || Math.abs(rawMin) * 0.2 || 2;
  const step = niceStep(rng);
  const yMin = Math.floor(rawMin / step) * step;
  const yMax = yMin + step * 4; // exactly 4 intervals = 5 lines max
  // Build 4-5 grid lines
  const gridLines = [yMin, yMin+step, yMin+step*2, yMin+step*3, yMin+step*4]
    .filter(y => y <= rawMax + step * 0.5 + 1e-9);
  const xS = i => pL + (n <= 1 ? (W-pL-pR)/2 : i*(W-pL-pR)/(n-1));
  const yS = v => H - pB - (v - yMin) / (yMax - yMin) * (H - pT - pB);
  const pts = data.map((v,i) => [xS(i), yS(v)]);
  const linePath = pts.map((p,i) => (i?'L':'M')+p[0].toFixed(1)+' '+p[1].toFixed(1)).join(' ');
  const areaPath = linePath+' L'+pts[n-1][0].toFixed(1)+' '+(H-pB)+' L'+pts[0][0].toFixed(1)+' '+(H-pB)+' Z';
  const gid = 'ax'+(Math.round(rawMin*7)+n*13);
  function fmtY(v) {
    const abs = Math.abs(v);
    if (abs >= 10000) return Math.round(v/1000)+'k'+(unit||'');
    if (abs >= 1000)  return (v/1000).toFixed(1).replace(/\.0$/,'')+'k'+(unit||'');
    if (step >= 10)   return Math.round(v)+(unit||'');
    if (step >= 1)    return v.toFixed(0)+(unit||'');
    if (step >= 0.1)  return v.toFixed(1)+(unit||'');
    return v.toFixed(2)+(unit||'');
  }
  const xl = xLabels || [];
  return (
    <svg viewBox={'0 0 '+W+' '+H} style={{width:'100%',height:H,display:'block',overflow:'visible'}}>
      <defs>
        <linearGradient id={gid} x1='0' y1='0' x2='0' y2='1'>
          <stop offset='0%' stopColor={color} stopOpacity='0.18'/>
          <stop offset='100%' stopColor={color} stopOpacity='0'/>
        </linearGradient>
      </defs>
      {gridLines.map((yv, gi) => {
        const yp = yS(yv);
        if (yp < pT - 4 || yp > H - pB + 4) return null;
        return (
          <g key={gi}>
            <line x1={pL} y1={yp} x2={W-pR} y2={yp} stroke='var(--separator-2)' strokeWidth='1'/>
            <text x={pL-5} y={yp+3.5} textAnchor='end' fontSize='9' fill='var(--text-3)' fontFamily='system-ui,sans-serif'>{fmtY(yv)}</text>
          </g>
        );
      })}
      {xl.map((l, i) => {
        const xi = Math.round(i * (n-1) / Math.max(xl.length-1, 1));
        return <text key={i} x={xS(xi)} y={H-4} textAnchor='middle' fontSize='9' fill='var(--text-3)' fontFamily='system-ui,sans-serif'>{l}</text>;
      })}
      <path d={areaPath} fill={'url(#'+gid+')'}/>
      <path d={linePath} fill='none' stroke={color} strokeWidth='2.2' strokeLinejoin='round' strokeLinecap='round'/>
      <circle cx={pts[n-1][0]} cy={pts[n-1][1]} r='4' fill={color}/>
    </svg>
  );
}

/* ════════════════════════════════════════════════════════════ */
function ProgressTab(props) {
  props = props || {};
  const [sub, setSub] = useState('stats');
  const [bodySub, setBodySub] = useState('measurements');
  const [heat, setHeat] = useState(5);           // month index 0..5
  const [trend, setTrend] = useState('volume');
  const [prCat, setPrCat] = useState('Chest');
  const [metric, setMetric] = useState('weight');
  const [measure, setMeasure] = useState({ weight: 78.4, bodyFat: 16.2, chest: 104, waist: 82, arms: 38.5, thighs: 59, shoulders: 122, neck: 39, hips: 96 });
  const [series, setSeries] = useState(() => JSON.parse(JSON.stringify(SEED_SERIES)));
  const [history, setHistory] = useState([
    { date: 'Jun 18', note: 'Weight 78.2 · Waist 82.1' }, { date: 'Jun 11', note: 'Weight 78.0 · Arms 38.4' }, { date: 'Jun 4', note: 'Weight 77.9 · Chest 103.5' },
  ]);
  const [photoLayout, setPhotoLayout] = useState('side');
  const [nut, setNut] = useState({ height: 178, weight: 78.4, age: 28, sex: 'Male', activity: 'Moderate', target: 80, goal: 'Lean gain', macro: 'Balanced' });
  const [exName, setExName]     = useState('Barbell Bench Press');
  const [exMetric, setExMetric] = useState('1rm');
  const [exRange, setExRange]   = useState('6m');
  const [mRange, setMRange]     = useState('6m');
  const [exSearch, setExSearch] = useState(false);
  const [exQuery, setExQuery]   = useState('');
  const [exMuscle, setExMuscle] = useState('All');
  const [exEquip, setExEquip]   = useState('All');
  const [sheet, setSheet] = useState(null);
  const [toast, setToast] = useState(null);
  const flash = m => { setToast(m); setTimeout(() => setToast(t => t === m ? null : t), 1800); };

  const theme = props.dark ? 'dark' : 'light';

  /* nutrition compute */
  const bmr = 10 * nut.weight + 6.25 * nut.height - 5 * nut.age + (nut.sex === 'Male' ? 5 : -161);
  const tdee = Math.round(bmr * ACT[nut.activity]);
  const cal = Math.max(1200, tdee + GOAL_ADJ[nut.goal]);
  const bmi = nut.weight / Math.pow(nut.height / 100, 2);
  const sp = MACRO_SPLIT[nut.macro];
  const macros = { protein: Math.round(cal * sp[0] / 100 / 4), carbs: Math.round(cal * sp[1] / 100 / 4), fats: Math.round(cal * sp[2] / 100 / 9), fiber: Math.round(cal / 1000 * 14) };
  const bmiCat = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Healthy' : bmi < 30 ? 'Overweight' : 'Obese';

  /* ── STATS ─────────────────────────────────────────────────── */
  function statsView() {
    const mh = genMonth(2026, heat);
    const cur = WEEKLY_VOL[WEEKLY_VOL.length - 1], prev = WEEKLY_VOL[WEEKLY_VOL.length - 2];
    return (
      <div className="screen-body pad pad-b">
        <div className="sec-label" style={{ marginTop: 10 }}>Consistency</div>
        <div className="card card-pad">
          <div className="between" style={{ marginBottom: 12 }}>
            <button className="nav-icon-btn" style={{ width: 30, height: 30 }} disabled={heat === 0} onClick={() => setHeat(h => Math.max(0, h - 1))}><Icon name="chevron-left" size={17} /></button>
            <div style={{ fontWeight: 700, fontSize: 15 }}>{MON_F[heat]} 2026</div>
            <button className="nav-icon-btn" style={{ width: 30, height: 30 }} disabled={heat === 5} onClick={() => setHeat(h => Math.min(5, h + 1))}><Icon name="chevron-right" size={17} /></button>
          </div>
          <div className="cal-grid head"><span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span></div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4 }}>
            {Array.from({ length: mh.first }).map((_, i) => <div key={'p' + i}></div>)}
            {mh.days.map((v, i) => <div key={i} title={HEAT_LABEL[v]} style={{ aspectRatio: '1', borderRadius: 6, background: HEAT_BG[v], display: 'grid', placeItems: 'center', fontSize: 10, fontWeight: 700, color: v >= 3 ? '#fff' : 'var(--text-3)' }}>{i + 1}</div>)}
          </div>
          <div className="flex" style={{ justifyContent: 'space-between', alignItems: 'center', marginTop: 14, flexWrap: 'wrap', gap: 6 }}>
            {HEAT_LABEL.map((l, i) => <span key={i} className="tiny muted" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 11, height: 11, borderRadius: 3, background: HEAT_BG[i] }}></span>{l}</span>)}
          </div>
        </div>

        <div className="sec-label">Lifetime</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
          {[['142', 'Sessions'], ['3,480', 'Sets'], ['418k', 'Volume kg'], ['37', 'PRs'], ['184', 'Hours'], ['18', 'Week streak']].map(s => (
            <div key={s[1]} className="card card-pad" style={{ padding: 13 }}><div className="stat-num" style={{ fontSize: 21 }}>{s[0]}</div><div className="tiny muted" style={{ marginTop: 2, fontSize: 11 }}>{s[1]}</div></div>
          ))}
        </div>

        {(props.logStat === 'Score' || props.logStat === 'Balance' || props.logStat === 'Both' || !props.logStat) && <div className="sec-label">Performance</div>}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 4 }}>
          {/* Strength Score */}
          {(props.logStat === 'Score' || props.logStat === 'Both' || !props.logStat) && (() => {
            const SCORE = 265;
            const LEVELS = [{min:100,max:200,l:'Beginner'},{min:200,max:300,l:'Intermediate'},{min:300,max:400,l:'Advanced'},{min:400,max:500,l:'Expert'},{min:500,max:600,l:'Elite'}];
            const lv = LEVELS.find(l => SCORE >= l.min && SCORE < l.max) || LEVELS[1];
            const pct = (SCORE - lv.min) / (lv.max - lv.min);
            const MUSCLES_S = [['Legs',290,'31'],['Chest',280,'58'],['Back',260,'248'],['Arms',255,'149'],['Shoulders',240,'283']];
            return (
              <div className="card card-pad" style={{ padding: 13 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: '.05em', textTransform: 'uppercase', marginBottom: 2 }}>Strength Score</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                  <div className="stat-num" style={{ fontSize: 32, letterSpacing: '-.03em' }}>{SCORE}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 10, marginTop: 1 }}>
                  <span style={{ fontSize: 10, fontWeight: 700, background: 'var(--accent-soft)', color: 'var(--accent)', padding: '2px 7px', borderRadius: 999 }}>{lv.l}</span>
                  <span className="tiny muted" style={{ fontSize: 10 }}>{Math.round(pct * 100)}% to {lv.max}</span>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                  {MUSCLES_S.map(([m, s, hue]) => (
                    <div key={m}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}>
                        <span style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-2)' }}>{m}</span>
                        <span style={{ fontSize: 10, fontWeight: 700, color: `oklch(0.46 0.15 ${hue})` }}>{s}</span>
                      </div>
                      <div style={{ height: 3, borderRadius: 999, background: 'var(--fill)' }}>
                        <div style={{ height: 3, borderRadius: 999, width: ((s-100)/500*100)+'%', background: `oklch(0.60 0.14 ${hue})` }}></div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })()}
          {/* Strength Balance */}
          {(props.logStat === 'Balance' || props.logStat === 'Both' || !props.logStat) && (() => {
            const BALANCE = 70;
            const MUSCLES_B = [['Legs',88,'31'],['Chest',82,'58'],['Back',75,'248'],['Arms',72,'149'],['Shoulders',58,'283']];
            return (
              <div className="card card-pad" style={{ padding: 13 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: '.05em', textTransform: 'uppercase', marginBottom: 2 }}>Strength Balance</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
                  <div className="stat-num" style={{ fontSize: 32, letterSpacing: '-.03em' }}>{BALANCE}</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-3)' }}>%</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 10, marginTop: 1 }}>
                  <span style={{ fontSize: 10, fontWeight: 700, background: 'color-mix(in oklab,var(--blue) 13%,transparent)', color: 'var(--blue)', padding: '2px 7px', borderRadius: 999 }}>Shoulders weakest</span>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                  {MUSCLES_B.map(([m, b, hue]) => (
                    <div key={m}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}>
                        <span style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-2)' }}>{m}</span>
                        <span style={{ fontSize: 10, fontWeight: 700, color: `oklch(0.46 0.15 ${hue})` }}>{b}%</span>
                      </div>
                      <div style={{ height: 3, borderRadius: 999, background: 'var(--fill)' }}>
                        <div style={{ height: 3, borderRadius: 999, width: b+'%', background: `oklch(0.60 0.14 ${hue})` }}></div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })()}
        </div>

        <div className="sec-label">This week · volume by muscle</div>
        <div className="card card-pad" style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
          {SPLIT.map(s => (
            <div key={s[0]}>
              <div className="between" style={{ marginBottom: 5 }}><span style={{ fontSize: 13, fontWeight: 600 }}>{s[0]}</span><span className="tiny muted">{s[1]}%</span></div>
              <div className="bar"><i style={{ width: s[1] + '%' }}></i></div>
            </div>
          ))}
        </div>

        <div className="sec-label">Exercise Trends</div>
        <div className="card card-pad">
          {/* Exercise selector */}
          <div className="between" style={{ marginBottom: 14 }}>
            <div style={{ fontWeight: 800, fontSize: 15, letterSpacing: '-.01em' }}>{exName}</div>
            <button className="nav-icon-btn" style={{ width: 30, height: 30, background: 'var(--accent-soft)', color: 'var(--accent)' }} onClick={() => { setExSearch(true); setExQuery(''); }}>
              <Icon name="swap" size={16} />
            </button>
          </div>
          {/* Metric chips */}
          <div style={{ display: 'flex', gap: 6, marginBottom: 14 }}>
            {Object.entries(EX_METRIC_META).map(([k, m]) => (
              <button key={k} onClick={() => setExMetric(k)} style={{
                flex: 1, padding: '7px 0', borderRadius: 'var(--r-sm)', border: 0, cursor: 'pointer', fontSize: 11, fontWeight: 700,
                background: exMetric === k ? 'var(--accent)' : 'var(--fill)',
                color: exMetric === k ? '#fff' : 'var(--text-2)',
                transition: 'all .15s'
              }}>{m.label}</button>
            ))}
          </div>
          {/* Chart */}
          {(() => {
            const d = sliceEx(exName, exMetric, exRange);
            const meta = EX_METRIC_META[exMetric];
            const cur = d[d.length-1], prev = d[0];
            const delta = (cur - prev).toFixed(meta.unit === 'kg' ? 1 : 0);
            const up = cur >= prev;
            return (
              <>
                <div className="between" style={{ marginBottom: 8 }}>
                  <div>
                    <div className="stat-num" style={{ fontSize: 26 }}>{cur}<span style={{ fontSize: 14, color: 'var(--text-3)' }}> {meta.unit || 'reps'}</span></div>
                    <div className="tiny muted">{meta.label}</div>
                  </div>
                  <div className="badge" style={{ background: 'color-mix(in oklab,var(--' + (up?'green':'blue') + ') 13%,transparent)', color: 'var(--' + (up?'green':'blue') + ')' }}>
                    <Icon name="arrow-up" size={12} /> {up?'+':''}{delta} {meta.unit||'reps'}
                  </div>
                </div>
                <AxisChart data={d} xLabels={EX_XLABELS[exRange]} unit={meta.unit} />
              </>
            );
          })()}
          {/* Range selector */}
          <div style={{ display: 'flex', gap: 5, marginTop: 12, background: 'var(--fill)', borderRadius: 'var(--r-sm)', padding: 3 }}>
            {['1m','3m','6m','1y'].map(r => (
              <button key={r} onClick={() => setExRange(r)} style={{
                flex: 1, padding: '6px 0', borderRadius: 6, border: 0, cursor: 'pointer',
                fontSize: 12, fontWeight: 700, transition: 'all .15s',
                background: exRange === r ? 'var(--surface)' : 'transparent',
                color: exRange === r ? 'var(--text)' : 'var(--text-3)',
                boxShadow: exRange === r ? '0 1px 4px rgba(0,0,0,0.08)' : 'none'
              }}>{r.toUpperCase()}</button>
            ))}
          </div>
        </div>

        {/* Exercise search sheet */}
        {exSearch && (() => {
          const MUSCLES = ['All','Chest','Back','Shoulders','Arms','Legs','Core'];
          const EQUIPS  = ['All','Barbell','Dumbbell','Cable','Machine','Bodyweight'];
          const filtered = EX_NAMES.filter(n => {
            const m = EX_META[n] || {};
            const q = exQuery.toLowerCase();
            return (!q || n.toLowerCase().includes(q))
              && (exMuscle === 'All' || m.muscle === exMuscle)
              && (exEquip  === 'All' || m.equip  === exEquip);
          });
          return (
            <div className="sheet">
              <div className="scrim" onClick={() => setExSearch(false)}></div>
              <div className="sheet-card" style={{ maxHeight: '82%' }}>
                <div className="grabber"></div>
                <div className="between pad" style={{ paddingBottom: 8 }}>
                  <div className="nav-title">Choose Exercise</div>
                  <button className="nav-icon-btn" onClick={() => setExSearch(false)}><Icon name="x" size={18} /></button>
                </div>
                <div style={{ padding: '0 14px 6px' }}>
                  <div className="search" style={{ marginBottom: 8 }}>
                    <Icon name="search" size={18} />
                    <input placeholder="Search exercises…" value={exQuery} onChange={e => setExQuery(e.target.value)}
                      style={{ flex:1, border:0, background:'none', fontFamily:'var(--font)', fontSize:15, color:'var(--text)', outline:'none' }} />
                  </div>
                  {/* Muscle filter */}
                  <div style={{ display:'flex', gap:6, overflowX:'auto', scrollbarWidth:'none', paddingBottom:6 }}>
                    {MUSCLES.map(m => {
                      const cc = EX_MUSCLE_COLOR[m];
                      const active = exMuscle === m;
                      return (
                        <button key={m} onClick={() => setExMuscle(m)} style={{
                          flexShrink:0, padding:'5px 11px', borderRadius:999, border:0, cursor:'pointer',
                          fontSize:12, fontWeight:700, transition:'all .12s',
                          background: cc ? (active ? cc.active : cc.soft) : (active ? 'var(--text)' : 'var(--fill)'),
                          color: cc ? (active ? '#fff' : cc.tx) : (active ? 'var(--bg)' : 'var(--text-2)')
                        }}>{m}</button>
                      );
                    })}
                  </div>
                  {/* Equipment filter */}
                  <div style={{ display:'flex', gap:6, overflowX:'auto', scrollbarWidth:'none', paddingBottom:4 }}>
                    {EQUIPS.map(e => (
                      <button key={e} onClick={() => setExEquip(e)} style={{
                        flexShrink:0, padding:'5px 11px', borderRadius:999, border:0, cursor:'pointer',
                        fontSize:12, fontWeight:700, transition:'all .12s',
                        background: exEquip === e ? 'var(--text)' : 'var(--fill)',
                        color:      exEquip === e ? 'var(--bg)'   : 'var(--text-2)'
                      }}>{e}</button>
                    ))}
                  </div>
                </div>
                <div style={{ overflow:'auto', paddingBottom:28, paddingTop:8 }}>
                  <div className="list" style={{ margin: '0 14px' }}>
                    {filtered.map(n => {
                      const m = EX_META[n] || {};
                      const cc = EX_MUSCLE_COLOR[m.muscle];
                      return (
                        <button key={n} className="row" style={{ width:'100%', background:'var(--surface)', border:0, textAlign:'left', cursor:'pointer' }}
                          onClick={() => { setExName(n); setExSearch(false); }}>
                          <div className="row-ic" style={{ background: cc ? cc.soft : 'var(--fill)', color: cc ? cc.tx : 'var(--text-3)' }}>
                            <Icon name="dumbbell" size={16} />
                          </div>
                          <div className="row-main">
                            <div className="row-title">{n}</div>
                            <div className="row-sub">{m.muscle} · {m.equip}</div>
                          </div>
                          {exName === n && <Icon name="check" size={18} color="var(--accent)" />}
                        </button>
                      );
                    })}
                    {filtered.length === 0 && <div style={{ padding:'24px 14px', textAlign:'center', color:'var(--text-3)', fontSize:13, fontWeight:600 }}>No exercises found</div>}
                  </div>
                </div>
              </div>
            </div>
          );
        })()}

        <div className="sec-label">Personal records</div>
        <div className="filters" style={{ marginBottom: 10 }}>
          {PR_CATS.map(c => <button key={c} className={'chip' + (prCat === c ? ' active' : '')} onClick={() => setPrCat(c)}>{c}</button>)}
        </div>
        <div className="list">
          {PR_DATA[prCat].map((p, i) => (
            <div className="row" key={i}>
              <div className="row-ic" style={{ background: 'var(--accent-soft)', color: 'var(--accent)' }}><Icon name="trophy" size={16} /></div>
              <div className="row-main"><div className="row-title" style={{ fontWeight: 600 }}>{p[0]}</div><div className="row-sub">{p[3]}</div></div>
              <div style={{ textAlign: 'right' }}><div className="stat-num" style={{ fontSize: 16 }}>{p[1]}</div><div className="tiny muted">{p[2]} reps</div></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  /* ── MEASUREMENTS ──────────────────────────────────────────── */
  function measurementsView() {
    const def = M_DEFS.find(d => d.k === metric);
    const ser = series[metric] || [measure[metric]];
    const cur = measure[metric], first = ser[0];
    const delta = (cur - first).toFixed(1);
    const up = cur >= first;
    return (
      <div className="screen-body pad pad-b">
        <div className="filters" style={{ marginTop: 8, marginBottom: 10 }}>
          {M_DEFS.slice(0, 7).map(d => <button key={d.k} className={'chip' + (metric === d.k ? ' active' : '')} onClick={() => setMetric(d.k)}>{d.label}</button>)}
        </div>
        <div className="card card-pad">
          <div className="between">
            <div>
              <div className="tiny muted" style={{ fontWeight: 700 }}>{def.label}</div>
              <div className="stat-num" style={{ fontSize: 30, marginTop: 2 }}>{cur}<span style={{ fontSize: 15, color: 'var(--text-3)' }}> {def.unit}</span></div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <button className="nav-icon-btn" style={{ width: 30, height: 30 }} onClick={() => setSheet({ kind: 'howto' })}><Icon name="info" size={16} /></button>
              <div className="badge" style={{ marginTop: 8, background: 'color-mix(in oklab,var(--' + (up ? 'green' : 'blue') + ') 13%,transparent)', color: 'var(--' + (up ? 'green' : 'blue') + ')' }}>{up ? '+' : ''}{delta} {def.unit}</div>
            </div>
          </div>
          <div style={{ marginTop: 10 }}>
            {(() => {
              const full = series[metric] || [measure[metric]];
              const MLABELS = { '1y': ['Aug','Sep','Oct','Nov','Dec','Jan','Feb'], '6m': ['Jan','Feb','Mar','Apr','May','Jun'], '3m': ['Apr','May','Jun'], '1m': ['W1','W2','W3','W4'] };
              const sliceN = { '1y': full.length, '6m': Math.min(6, full.length), '3m': Math.min(3, full.length), '1m': Math.min(2, full.length) };
              const d = full.slice(-sliceN[mRange]);
              const xl = MLABELS[mRange].slice(-d.length);
              return <AxisChart data={d} xLabels={xl} unit={def.unit} />;
            })()}
          </div>
          <div style={{ display: 'flex', gap: 5, marginTop: 10, background: 'var(--fill)', borderRadius: 'var(--r-sm)', padding: 3 }}>
            {['1m','3m','6m','1y'].map(r => (
              <button key={r} onClick={() => setMRange(r)} style={{
                flex: 1, padding: '6px 0', borderRadius: 6, border: 0, cursor: 'pointer',
                fontSize: 12, fontWeight: 700, transition: 'all .15s',
                background: mRange === r ? 'var(--surface)' : 'transparent',
                color: mRange === r ? 'var(--text)' : 'var(--text-3)',
                boxShadow: mRange === r ? '0 1px 4px rgba(0,0,0,0.08)' : 'none'
              }}>{r.toUpperCase()}</button>
            ))}
          </div>
        </div>

        <div className="sec-label">Current measurements</div>
        <div className="card card-pad" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px 18px' }}>
          {M_DEFS.map(d => (
            <button key={d.k} onClick={() => setMetric(d.k)} style={{ background: 'none', border: 0, textAlign: 'left', cursor: 'pointer', padding: 0, opacity: measure[d.k] == null ? 0.5 : 1 }}>
              <div className="tiny muted">{d.label}</div>
              <div className="stat-num" style={{ fontSize: 18, marginTop: 1 }}>{measure[d.k] == null ? '—' : measure[d.k]}<span style={{ fontSize: 12, color: 'var(--text-3)', fontWeight: 600 }}> {d.unit}</span></div>
            </button>
          ))}
        </div>

        <button className="btn btn-tinted" style={{ marginTop: 16 }} onClick={() => setSheet({ kind: 'logm', vals: {} })}><Icon name="plus" size={18} /> Log Measurements</button>

        <div className="between" style={{ margin: '24px 4px 8px' }}>
          <div className="sec-label" style={{ margin: 0 }}>History</div>
        </div>
        <div className="list">
          {history.map((h, i) => (
            <div className="row" key={i}>
              <div className="row-ic" style={{ background: 'var(--fill)', color: 'var(--text-2)' }}><Icon name="calendar-day" size={15} /></div>
              <div className="row-main"><div className="row-title" style={{ fontWeight: 600, fontSize: 15 }}>{h.date}</div><div className="row-sub">{h.note}</div></div>
            </div>
          ))}
        </div>

        <div className="sec-label">Photo progress</div>
        <div className="card card-pad">
          <Seg options={[{ v: 'side', l: 'Side by side' }, { v: 'stack', l: 'Up / down' }]} value={photoLayout} onChange={setPhotoLayout} />
          <div style={{ display: photoLayout === 'side' ? 'grid' : 'block', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 12 }}>
            {[['May 1', '76.2 kg'], ['Jun 25', '78.4 kg']].map((p, i) => (
              <div key={i} className="ph rounded" style={{ aspectRatio: photoLayout === 'side' ? '3/4' : '16/10', marginBottom: photoLayout === 'stack' && i === 0 ? 10 : 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, color: 'var(--text-3)' }}>
                <Icon name="person" size={26} />
                <div style={{ fontFamily: 'var(--mono)', fontSize: 11 }}>{p[0]} · {p[1]}</div>
              </div>
            ))}
          </div>
          <button className="btn btn-gray" style={{ marginTop: 12 }} onClick={() => flash('Photo comparison saved')}><Icon name="plus" size={17} /> Add comparison photo</button>
        </div>
      </div>
    );
  }

  /* ── NUTRITION ─────────────────────────────────────────────── */
  const WEIGHT_TREND = [76.2, 76.8, 77.1, 77.6, 77.9, 78.0, 78.2, 78.4];
  function nutritionView() {
    return (
      <div className="screen-body pad pad-b">
        <div className="card card-pad" style={{ marginTop: 8 }}>
          <div className="between">
            <div><div className="tiny muted" style={{ fontWeight: 700 }}>Body weight</div><div className="stat-num" style={{ fontSize: 28, marginTop: 2 }}>{nut.weight}<span style={{ fontSize: 14, color: 'var(--text-3)' }}> kg</span></div></div>
            <div className="badge badge-accent">Target {nut.target} kg</div>
          </div>
          <div style={{ marginTop: 8 }}><LineChart data={WEIGHT_TREND} h={110} /></div>
        </div>

        <div className="between" style={{ margin: '22px 4px 8px' }}>
          <div className="sec-label" style={{ margin: 0 }}>Your details</div>
          <button className="btn-ghost tiny" style={{ fontWeight: 700 }} onClick={() => setSheet({ kind: 'details' })}>Edit</button>
        </div>
        <div className="card card-pad" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '14px 10px' }}>
          {[['Height', nut.height + ' cm'], ['Weight', nut.weight + ' kg'], ['Age', nut.age], ['Sex', nut.sex], ['Activity', nut.activity], ['Target', nut.target + ' kg']].map(d => (
            <div key={d[0]}><div className="tiny muted">{d[0]}</div><div style={{ fontWeight: 700, fontSize: 15, marginTop: 1 }}>{d[1]}</div></div>
          ))}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 12 }}>
          <div className="card card-pad"><div className="tiny muted" style={{ fontWeight: 700 }}>BMI</div><div className="stat-num" style={{ fontSize: 26, marginTop: 2 }}>{bmi.toFixed(1)}</div><div className="badge" style={{ marginTop: 6, background: 'color-mix(in oklab,var(--green) 13%,transparent)', color: 'var(--green)' }}>{bmiCat}</div></div>
          <div className="card card-pad"><div className="tiny muted" style={{ fontWeight: 700 }}>TDEE</div><div className="stat-num" style={{ fontSize: 26, marginTop: 2 }}>{tdee.toLocaleString()}</div><div className="tiny muted" style={{ marginTop: 6 }}>kcal / day maint.</div></div>
        </div>

        <div className="sec-label">Goal</div>
        <Seg options={['Lose fat', 'Maintain', 'Lean gain', 'Gain muscle'].map(g => ({ v: g, l: g }))} value={nut.goal} onChange={v => setNut(n => ({ ...n, goal: v }))} />

        <div className="sec-label">Macro split</div>
        <div className="filters" style={{ marginBottom: 10 }}>
          {Object.keys(MACRO_SPLIT).map(m => <button key={m} className={'chip' + (nut.macro === m ? ' active' : '')} onClick={() => setNut(n => ({ ...n, macro: m }))}>{m}</button>)}
        </div>

        <div className="card card-pad" style={{ background: 'linear-gradient(155deg,var(--accent),oklch(0.64 0.16 42))', color: '#fff', border: 0 }}>
          <div className="between"><div style={{ fontWeight: 700, fontSize: 15 }}>Daily target</div><div className="stat-num" style={{ fontSize: 22 }}>{cal.toLocaleString()}<span style={{ fontSize: 13, opacity: .8 }}> kcal</span></div></div>
          <div style={{ display: 'flex', gap: 6, marginTop: 14, height: 8, borderRadius: 999, overflow: 'hidden' }}>
            <div style={{ flex: sp[0], background: 'rgba(255,255,255,.95)' }}></div>
            <div style={{ flex: sp[1], background: 'rgba(255,255,255,.6)' }}></div>
            <div style={{ flex: sp[2], background: 'rgba(255,255,255,.32)' }}></div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 8, marginTop: 16 }}>
            {[['Protein', macros.protein], ['Carbs', macros.carbs], ['Fats', macros.fats], ['Fiber', macros.fiber]].map(m => (
              <div key={m[0]}><div className="stat-num" style={{ fontSize: 20 }}>{m[1]}<span style={{ fontSize: 12, opacity: .8 }}>g</span></div><div className="tiny" style={{ opacity: .85, marginTop: 1 }}>{m[0]}</div></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  /* ── sheets ────────────────────────────────────────────────── */
  function sheetEl() {
    if (!sheet) return null;
    if (sheet.kind === 'howto') {
      return (
        <Sheet onClose={() => setSheet(null)} title="How to measure" max="76%">
          <div className="col" style={{ gap: 12 }}>
            {HOW_TO.map(h => (
              <div key={h[0]} className="hint-card" style={{ alignItems: 'flex-start' }}>
                <div className="row-ic" style={{ background: 'var(--accent-soft)', color: 'var(--accent)', width: 30, height: 30, borderRadius: 8, flex: '0 0 auto' }}><Icon name="target" size={15} /></div>
                <div><div style={{ fontWeight: 700, fontSize: 14 }}>{h[0]}</div><div className="tiny muted" style={{ marginTop: 2, lineHeight: 1.5 }}>{h[1]}</div></div>
              </div>
            ))}
          </div>
        </Sheet>
      );
    }
    if (sheet.kind === 'logm') {
      const vals = sheet.vals;
      const setV = (k, v) => setSheet(s => ({ ...s, vals: { ...s.vals, [k]: v.replace(/[^0-9.]/g, '') } }));
      const save = () => {
        const changed = [];
        const nm = { ...measure }; const nser = JSON.parse(JSON.stringify(series));
        M_DEFS.forEach(d => { if (vals[d.k] !== undefined && vals[d.k] !== '') { const num = parseFloat(vals[d.k]); nm[d.k] = num; (nser[d.k] = nser[d.k] || []).push(num); if (nser[d.k].length > 8) nser[d.k].shift(); changed.push(d.label + ' ' + num); } });
        if (changed.length) { setMeasure(nm); setSeries(nser); setHistory(h => [{ date: 'Jun 25', note: changed.slice(0, 3).join(' · ') }, ...h]); flash('Measurements logged'); }
        setSheet(null);
      };
      return (
        <Sheet onClose={() => setSheet(null)} title="Log Measurements" sub="Fill only what you measured today" max="86%">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {M_DEFS.map(d => (
              <div className="field" key={d.k} style={{ marginBottom: 0 }}>
                <label>{d.label} <span style={{ color: 'var(--text-3)' }}>({d.unit})</span></label>
                <input inputMode="decimal" placeholder={String(measure[d.k] == null ? '—' : measure[d.k])} value={vals[d.k] || ''} onChange={e => setV(d.k, e.target.value)} />
              </div>
            ))}
          </div>
          <button className="btn btn-primary" style={{ marginTop: 18 }} onClick={save}>Save Measurements</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }
    if (sheet.kind === 'details') {
      const upd = (k, v) => setNut(n => ({ ...n, [k]: v }));
      return (
        <Sheet onClose={() => setSheet(null)} title="Your Details" max="86%">
          <div className="list">
            <div className="row"><div className="row-main"><div className="row-title">Height</div></div><window.Stepper value={nut.height} min={120} max={220} onChange={v => upd('height', v)} fmt={v => v + ' cm'} /></div>
            <div className="row"><div className="row-main"><div className="row-title">Weight</div></div><window.Stepper value={nut.weight} min={40} max={200} step={0.5} onChange={v => upd('weight', v)} fmt={v => v + ' kg'} /></div>
            <div className="row"><div className="row-main"><div className="row-title">Age</div></div><window.Stepper value={nut.age} min={14} max={90} onChange={v => upd('age', v)} /></div>
            <div className="row"><div className="row-main"><div className="row-title">Target weight</div></div><window.Stepper value={nut.target} min={40} max={200} step={0.5} onChange={v => upd('target', v)} fmt={v => v + ' kg'} /></div>
          </div>
          <div className="sec-label">Sex</div>
          <Seg options={['Male', 'Female']} value={nut.sex} onChange={v => upd('sex', v)} />
          <div className="sec-label">Activity level</div>
          <div className="filters">
            {Object.keys(ACT).map(a => <button key={a} className={'chip' + (nut.activity === a ? ' active' : '')} onClick={() => upd('activity', a)}>{a}</button>)}
          </div>
          <button className="btn btn-primary" style={{ marginTop: 18 }} onClick={() => { setSheet(null); flash('Details updated'); }}>Done</button>
        </Sheet>
      );
    }
    return null;
  }

  return (
    <div className="phone" data-theme={theme}>
      <div className="dynamic-island"></div>
      <div className="statusbar auto"></div>
      <div className="navbar">
        <div className="navbar-row"><div className="nav-title-lg">Progress</div></div>
        <div className="subtabs">
          {[['stats', 'Stats'], ['body', 'Body']].map(s => <button key={s[0]} className={'subtab' + (sub === s[0] ? ' active' : '')} onClick={() => setSub(s[0])}>{s[1]}</button>)}
        </div>
      </div>

      {sub === 'stats' ? statsView() : (
        <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 auto', minHeight: 0 }}>
          <div style={{ padding: '12px 20px 0', flex: '0 0 auto' }}>
            <Seg options={[{ v: 'measurements', l: 'Measurements' }, { v: 'nutrition', l: 'Nutrition' }]} value={bodySub} onChange={setBodySub} />
          </div>
          {bodySub === 'measurements' ? measurementsView() : nutritionView()}
        </div>
      )}

      {sheetEl()}
      {toast && <div style={{ position: 'absolute', bottom: 100, left: '50%', transform: 'translateX(-50%)', background: 'var(--text)', color: 'var(--bg)', fontSize: 13, fontWeight: 600, padding: '9px 16px', borderRadius: 999, zIndex: 90, boxShadow: '0 8px 24px rgba(0,0,0,.22)', whiteSpace: 'nowrap' }}>{toast}</div>}
      <TabBar active='progress' onTab={props.onTab} onAction={k => props.onTab && props.onTab('log')} />
      <div className="home-indicator"></div>
    </div>
  );
}

window.ProgressTab = ProgressTab;
})();
