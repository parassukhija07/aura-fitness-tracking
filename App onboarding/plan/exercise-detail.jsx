/* ── Exercise Detail — Overview + History ────────────────────── */
const { useState: useStateXD } = React;

function levelFor(ex) {
  const m={Bodyweight:'Beginner',Machine:'Beginner',Smith:'Beginner',Dumbbell:'Intermediate',Cable:'Intermediate',Barbell:'Advanced'};
  return m[ex.equip]||'Intermediate';
}

/* ── Seed data ───────────────────────────────────────────────── */
const XD_INFO = {
  bbar:  { desc:'The barbell bench press is the foundation of upper-body strength. Pressing a loaded bar from chest to lockout trains the pecs, anterior delts, and triceps in one powerful movement.', primary:['Chest'], secondary:['Triceps','Shoulders'], activation:[{m:'Chest',p:82},{m:'Triceps',p:55},{m:'Shoulders',p:38}], tips:['Retract and depress shoulder blades before unracking','Lower bar to mid-chest — not your neck','Drive feet into the floor throughout','Keep elbows at 45–75° to protect the shoulder'] },
  cfly:  { desc:'Cable flies maintain constant tension on the pecs through the full range, making them ideal for isolating the chest after heavier compound work.', primary:['Chest'], secondary:['Shoulders'], activation:[{m:'Chest',p:90},{m:'Shoulders',p:35}], tips:['Lead with pinkies and squeeze at the midline','Think "hugging a tree" — keep a soft elbow bend','Control the eccentric; don\'t let cables yank you back','Slight forward lean increases chest activation'] },
  idb:   { desc:'Incline dumbbell press shifts emphasis to the upper (clavicular) portion of the pecs while allowing a natural wrist path and greater stretch at the bottom.', primary:['Chest'], secondary:['Shoulders','Triceps'], activation:[{m:'Chest',p:78},{m:'Shoulders',p:48},{m:'Triceps',p:35}], tips:['Set bench to 30–45° — higher angles shift load to delts','Allow a deep stretch at bottom without losing tension','Neutral or semi-supinated grip reduces shoulder impingement','Keep wrists stacked directly over elbows'] },
  brow:  { desc:'The barbell row is the premier back-builder for thickness. Hinging at the hips and rowing the bar to the lower chest trains the entire posterior chain.', primary:['Back'], secondary:['Biceps'], activation:[{m:'Back',p:80},{m:'Biceps',p:50},{m:'Rear Delts',p:30}], tips:['Hinge to ~45° and keep a neutral spine throughout','Row to your lower chest/upper abdomen, not your hips','Lead with your elbows — don\'t curl the weight','Squeeze the lats at the top for a full contraction'] },
  pull:  { desc:'Pull-ups are the ultimate bodyweight back exercise, developing lat width, grip strength, and scapular stability simultaneously.', primary:['Back'], secondary:['Biceps'], activation:[{m:'Back',p:85},{m:'Biceps',p:45},{m:'Core',p:25}], tips:['Start from a dead hang to maximise range of motion','Initiate by depressing your shoulder blades first','Pull elbows toward your hips, not just downward','Cross ankles and brace core to reduce swinging'] },
  ohp:   { desc:'The overhead press builds boulder shoulders and full-body stability. Pressing overhead demands core bracing and scapular coordination throughout the lift.', primary:['Shoulders'], secondary:['Triceps'], activation:[{m:'Shoulders',p:78},{m:'Triceps',p:52},{m:'Upper Chest',p:22}], tips:['Start bar just above clavicles, not on chest','Push your head through the window at lockout','Brace and maintain a neutral spine — avoid lumbar hyperextension','Slightly wider than shoulder-width grip balances pressing strength'] },
  latdb: { desc:'Lateral raises isolate the medial deltoid — the muscle responsible for shoulder width. Light weight and strict form beat heavy cheating every time.', primary:['Shoulders'], secondary:[], activation:[{m:'Shoulders',p:85},{m:'Traps',p:30}], tips:['Lead with your elbows, not your hands','Stop at shoulder height — going higher recruits traps excessively','Slight forward lean shifts load to medial delt','Control the descent; the eccentric builds more muscle'] },
  squat: { desc:'The barbell squat is the king of lower-body exercises, loading the entire lower body and core while demanding significant mobility and stability.', primary:['Legs'], secondary:['Core'], activation:[{m:'Quads',p:85},{m:'Glutes',p:55},{m:'Hamstrings',p:35},{m:'Core',p:40}], tips:['High-bar: more upright torso and quad dominant','Break at hips and knees simultaneously on the descent','Knees track in line with toes throughout','Brace your core like you\'re about to take a punch'] },
  bcurl: { desc:'The barbell curl allows maximum loading for bicep development. The supinated grip fully engages both heads of the biceps brachii.', primary:['Biceps'], secondary:[], activation:[{m:'Biceps',p:88},{m:'Forearms',p:30}], tips:['Keep elbows pinned at your sides throughout','Don\'t swing — momentum kills bicep tension','Full extension at the bottom for complete range','Supinate wrists slightly at the top for peak contraction'] },
  tpush: { desc:'Cable pushdowns isolate the triceps with constant tension through the full range. The cable angle keeps resistance where free weights would lose it at lockout.', primary:['Triceps'], secondary:[], activation:[{m:'Triceps',p:87},{m:'Anconeus',p:25}], tips:['Keep elbows pinned at your sides — they are the pivot','Fully extend to lockout on every rep','Vary grip (rope vs straight bar) to hit different heads','Hinge slightly at hips to stabilise the torso'] },
};

function getXDInfo(ex) {
  if (XD_INFO[ex.id]) return XD_INFO[ex.id];
  const def = {
    Chest:    { primary:['Chest'],     secondary:['Triceps','Shoulders'], activation:[{m:'Chest',p:80},{m:'Triceps',p:42},{m:'Shoulders',p:30}] },
    Back:     { primary:['Back'],      secondary:['Biceps'],              activation:[{m:'Back',p:78},{m:'Biceps',p:44}] },
    Shoulders:{ primary:['Shoulders'], secondary:['Triceps'],             activation:[{m:'Shoulders',p:76},{m:'Triceps',p:40}] },
    Biceps:   { primary:['Biceps'],    secondary:[],                      activation:[{m:'Biceps',p:85},{m:'Forearms',p:28}] },
    Triceps:  { primary:['Triceps'],   secondary:[],                      activation:[{m:'Triceps',p:86}] },
    Legs:     { primary:['Legs'],      secondary:['Core'],                activation:[{m:'Quads',p:82},{m:'Glutes',p:50},{m:'Hamstrings',p:32}] },
    Core:     { primary:['Core'],      secondary:['Shoulders'],           activation:[{m:'Core',p:84},{m:'Shoulders',p:24}] },
  };
  const d = def[ex.muscle] || def.Chest;
  return { ...d, desc:`${ex.name} is a targeted ${ex.equip.toLowerCase()} exercise focusing on the ${ex.muscle.toLowerCase()}.`, tips:['Maintain full range of motion on every rep','Control the eccentric phase — don\'t drop the weight','Focus on the mind-muscle connection with the target muscle','Progressive overload is key: add weight or reps each session'] };
}

/* ── History seed ─────────────────────────────────────────────── */
function genHistory(ex) {
  const BASE = { 'Barbell Bench Press':80,'Incline DB Press':30,'Cable Fly':15,'Pec Deck':40,'Barbell Row':72.5,'Pull-ups':0,'Cable Row':55,'Lat Pulldown':52,'Overhead Press':52.5,'Lateral Raise':12,'Barbell Squat':90,'Romanian Deadlift':75,'Leg Press':120,'Leg Curl':45,'Leg Extension':50,'Barbell Curl':35,'Hammer Curl':18,'Tricep Pushdown':25,'Skull Crushers':35 };
  const base = BASE[ex.name] || 40;
  const isPw = base === 0; // bodyweight
  const sessions = [];
  const days = [2,7,12,19,26];
  for (let i = 0; i < 5; i++) {
    const d = new Date('2026-06-26');
    d.setDate(d.getDate() - days[i]);
    const w = isPw ? 0 : Math.round((base - i * 2.5) / 1.25) * 1.25;
    const numSets = i === 0 ? 4 : 3;
    const sets = Array.from({ length: numSets }, (_, s) => ({
      weight: w,
      reps: s === 0 ? (isPw ? 10 : 8) : s === 1 ? (isPw ? 9 : 7) : (isPw ? 8 : 6),
    }));
    sessions.push({ date: d.toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}), sets });
  }
  return sessions;
}

/* ── PBs ─────────────────────────────────────────────────────── */
function epley(w, r) { return r <= 1 ? w : Math.round(w * (1 + r / 30) * 4) / 4; }
function calcPBs(sessions) {
  let maxE1rm = 0, maxW = 0, maxR = 0, maxVol = 0;
  sessions.forEach(s => {
    let sv = 0;
    s.sets.forEach(({ weight: w, reps: r }) => {
      const e = epley(w || 0, r);
      if (e > maxE1rm) maxE1rm = e;
      if (w > maxW) maxW = w;
      if (r > maxR) maxR = r;
      sv += (w || 0) * r;
    });
    if (sv > maxVol) maxVol = sv;
  });
  return { e1rm: maxE1rm, maxW, maxR, maxVol: Math.round(maxVol) };
}

/* ── Body map SVG ─────────────────────────────────────────────── */
function BodyMap({ primary = [], secondary = [] }) {
  const hasMuscle = (regions, m) => regions.some(r => r.toLowerCase() === m.toLowerCase());
  const fill = (muscle) => {
    if (!muscle) return null;
    if (primary.some(p => p === muscle)) return 'var(--accent)';
    if (secondary.some(s => s === muscle)) return 'var(--blue)';
    return null;
  };
  const S = (muscle) => ({ fill: fill(muscle) || 'var(--fill)', opacity: fill(muscle) ? 0.92 : 0.35 });
  const BASE = { fill:'var(--fill)', opacity:0.35 };

  return React.createElement('svg', { viewBox:'0 0 130 158', width:115, height:140, style:{flexShrink:0} },
    /* front label */ React.createElement('text',{x:32,y:156,textAnchor:'middle',fontSize:7,fill:'var(--text-3)',fontWeight:700,letterSpacing:.6},'FRONT'),
    /* back label  */ React.createElement('text',{x:98,y:156,textAnchor:'middle',fontSize:7,fill:'var(--text-3)',fontWeight:700,letterSpacing:.6},'BACK'),
    /* divider     */ React.createElement('line',{x1:65,y1:4,x2:65,y2:150,stroke:'var(--separator-2)',strokeWidth:.7}),

    /* ── FRONT ── */
    React.createElement('circle',{cx:32,cy:11,r:8,...BASE}),
    React.createElement('rect',{x:29,y:19,width:6,height:6,rx:2,...BASE}),
    React.createElement('ellipse',{cx:18,cy:29,rx:9,ry:7,...S('Shoulders')}),
    React.createElement('ellipse',{cx:46,cy:29,rx:9,ry:7,...S('Shoulders')}),
    React.createElement('path',{d:'M22,23 Q32,20 42,23 L43,52 Q32,55 21,52 Z',...S('Chest')}),
    React.createElement('rect',{x:10,y:24,width:9,height:26,rx:4,...S('Biceps')}),
    React.createElement('rect',{x:43,y:24,width:9,height:26,rx:4,...S('Biceps')}),
    React.createElement('rect',{x:9,y:50,width:8,height:20,rx:4,...BASE}),
    React.createElement('rect',{x:45,y:50,width:8,height:20,rx:4,...BASE}),
    React.createElement('rect',{x:25,y:52,width:14,height:26,rx:3,...S('Core')}),
    React.createElement('path',{d:'M22,78 Q32,82 42,78 L43,88 Q32,90 21,88 Z',...BASE}),
    React.createElement('rect',{x:22,y:88,width:11,height:32,rx:5,...S('Legs')}),
    React.createElement('rect',{x:35,y:88,width:11,height:32,rx:5,...S('Legs')}),
    React.createElement('rect',{x:22,y:122,width:10,height:24,rx:4,...BASE}),
    React.createElement('rect',{x:35,y:122,width:10,height:24,rx:4,...BASE}),

    /* ── BACK ── */
    React.createElement('circle',{cx:98,cy:11,r:8,...BASE}),
    React.createElement('rect',{x:95,y:19,width:6,height:6,rx:2,...BASE}),
    React.createElement('ellipse',{cx:84,cy:29,rx:9,ry:7,...S('Shoulders')}),
    React.createElement('ellipse',{cx:112,cy:29,rx:9,ry:7,...S('Shoulders')}),
    React.createElement('rect',{x:86,y:22,width:24,height:16,rx:4,...S('Back')}),
    React.createElement('path',{d:'M86,26 L79,36 L78,60 L86,66 Z',...S('Back')}),
    React.createElement('path',{d:'M110,26 L117,36 L118,60 L110,66 Z',...S('Back')}),
    React.createElement('rect',{x:76,y:24,width:9,height:26,rx:4,...S('Triceps')}),
    React.createElement('rect',{x:111,y:24,width:9,height:26,rx:4,...S('Triceps')}),
    React.createElement('rect',{x:75,y:50,width:8,height:20,rx:4,...BASE}),
    React.createElement('rect',{x:113,y:50,width:8,height:20,rx:4,...BASE}),
    React.createElement('rect',{x:91,y:50,width:14,height:22,rx:3,...S('Back')}),
    React.createElement('ellipse',{cx:94,cy:86,rx:9,ry:10,...S('Legs')}),
    React.createElement('ellipse',{cx:104,cy:86,rx:9,ry:10,...S('Legs')}),
    React.createElement('rect',{x:89,y:94,width:11,height:32,rx:5,...S('Legs')}),
    React.createElement('rect',{x:102,y:94,width:11,height:32,rx:5,...S('Legs')}),
    React.createElement('rect',{x:89,y:128,width:10,height:22,rx:4,...BASE}),
    React.createElement('rect',{x:102,y:128,width:10,height:22,rx:4,...BASE})
  );
}

/* ── Overview tab ────────────────────────────────────────────── */
function SSSubTabs({ ctx }) {
  if (!ctx) return null;
  return React.createElement('div', { style:{ padding:'8px 14px 2px' } },
    React.createElement('div', { style:{ display:'flex', background:'color-mix(in oklab,var(--accent) 14%,transparent)', borderRadius:999, padding:3 } },
      [['a', ctx.exA], ['b', ctx.exB]].map(([key, ex]) =>
        React.createElement('button', {
          key, onClick:()=>ctx.setActive(key),
          style:{ flex:1, padding:'6px 10px', borderRadius:999, border:0, cursor:'pointer', fontFamily:'var(--font)',
            fontWeight:700, fontSize:'12px', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
            background: ctx.active===key ? 'var(--accent)' : 'transparent',
            color: ctx.active===key ? '#fff' : 'var(--accent)',
            transition:'all .18s' }
        }, (ctx.active===key?'\u25cf ':'')+(ex?ex.name.split(' ').slice(0,2).join(' '):'Exercise'))
      )
    )
  );
}

function WorkoutTab({ exercise, ctx, onSave }) {
  const [sets,setSW]=useStateXD(ctx&&ctx.sets||3);
  const [reps,setRW]=useStateXD(ctx&&ctx.reps||'8\u201312');
  const [rest,setRest]=useStateXD(ctx&&ctx.restTime||90);
  const STEPS=[30,45,60,75,90,120,150,180,240,300];
  const fmtR=s=>s<60?`${s}s`:`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
  const ri=Math.max(0,STEPS.indexOf(rest)<0?4:STEPS.indexOf(rest));
  return React.createElement('div',{style:{padding:'0 0 28px'}},
    React.createElement('div',{style:{position:'relative',margin:'0 14px 14px'}},
      React.createElement('div',{className:'ph rounded',style:{aspectRatio:'16/10',borderRadius:'var(--r-lg)'}},'exercise demo'),
      React.createElement('div',{style:{position:'absolute',top:'50%',left:'50%',transform:'translate(-50%,-50%)',width:48,height:48,borderRadius:'50%',background:'#fff',display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 4px 16px #0004'}},React.createElement(Icon,{name:'play',size:20}))
    ),
    React.createElement('div',{style:{fontSize:'22px',fontWeight:800,letterSpacing:'-.02em',padding:'0 14px',marginBottom:16}},exercise.name),
    React.createElement('div',{style:{padding:'0 14px',display:'flex',flexDirection:'column',gap:10}},
      React.createElement('div',{className:'card card-pad'},
        React.createElement('div',{className:'between'},
          React.createElement('div',{style:{fontWeight:600,fontSize:'14px'}},'Sets'),
          React.createElement('div',{style:{display:'flex',alignItems:'center',gap:10}},
            React.createElement('button',{className:'nav-icon-btn',style:{width:32,height:32},onClick:()=>setSW(Math.max(1,sets-1))},React.createElement(Icon,{name:'minus',size:16})),
            React.createElement('div',{style:{fontWeight:800,fontSize:'17px',minWidth:24,textAlign:'center'}},sets),
            React.createElement('button',{className:'nav-icon-btn',style:{width:32,height:32,background:'var(--accent-soft)',color:'var(--accent)'},onClick:()=>setSW(sets+1)},React.createElement(Icon,{name:'plus',size:16}))
          )
        )
      ),
      React.createElement('div',{className:'card card-pad'},
        React.createElement('div',{className:'between'},
          React.createElement('div',{style:{fontWeight:600,fontSize:'14px'}},'Rep range'),
          React.createElement('input',{value:reps,onChange:e=>setRW(e.target.value),style:{width:80,background:'var(--fill)',border:'1px solid var(--separator-2)',borderRadius:'var(--r-sm)',padding:'6px 10px',fontFamily:'var(--font)',fontSize:'15px',fontWeight:700,color:'var(--text)',textAlign:'center',outline:'none'}})
        )
      ),
      React.createElement('div',{className:'card card-pad'},
        React.createElement('div',{style:{fontSize:'11px',fontWeight:700,color:'var(--text-2)',letterSpacing:'.05em',textTransform:'uppercase',marginBottom:10}},'Rest between sets'),
        React.createElement('div',{style:{display:'flex',alignItems:'center',gap:8}},
          React.createElement('button',{className:'nav-icon-btn',style:{width:34,height:34},onClick:()=>ri>0&&setRest(STEPS[ri-1])},React.createElement(Icon,{name:'minus',size:17})),
          React.createElement('div',{style:{flex:1,textAlign:'center',fontSize:'26px',fontWeight:800,letterSpacing:'-.03em',color:'var(--accent)',fontVariantNumeric:'tabular-nums'}},fmtR(rest)),
          React.createElement('button',{className:'nav-icon-btn',style:{width:34,height:34,background:'var(--accent-soft)',color:'var(--accent)'},onClick:()=>ri<STEPS.length-1&&setRest(STEPS[ri+1])},React.createElement(Icon,{name:'plus',size:17}))
        ),
        React.createElement('div',{style:{display:'flex',justifyContent:'center',gap:4,marginTop:10}},
          STEPS.map(s=>React.createElement('div',{key:s,style:{width:s===rest?14:5,height:4,borderRadius:999,background:s===rest?'var(--accent)':'var(--separator-2)',transition:'width .2s'}}))
        )
      ),
      React.createElement('button',{className:'btn btn-primary',style:{marginTop:8},onClick:()=>onSave&&onSave(sets,reps,rest)},React.createElement(Icon,{name:'check',size:18}),' Save Changes')
    )
  );
}

function OverviewTab({ ex, info, ssCtx }) {
  return React.createElement('div', { style:{ padding:'0 0 28px' } },
    ssCtx && React.createElement(SSSubTabs, { ctx: ssCtx }),
    /* stats pill */
    React.createElement('div', { style:{ display:'flex', gap:0, margin:'8px 14px 14px', border:'1px solid var(--separator-2)', borderRadius:'var(--r-md)', overflow:'hidden' } },
      React.createElement('div', { style:{ flex:1, textAlign:'center', padding:'11px 8px' } },
        React.createElement('div', { className:'tiny muted', style:{ fontWeight:700 } }, 'CATEGORY'),
        React.createElement('div', { style:{ fontWeight:700, fontSize:'14px', marginTop:2 } }, ex.muscle)
      ),
      React.createElement('div', { style:{ width:1, background:'var(--separator-2)', flexShrink:0 } }),
      React.createElement('div', { style:{ flex:1, textAlign:'center', padding:'11px 8px' } },
        React.createElement('div', { className:'tiny muted', style:{ fontWeight:700 } }, 'EQUIPMENT'),
        React.createElement('div', { style:{ fontWeight:700, fontSize:'14px', marginTop:2 } }, ex.equip)
      ),
      React.createElement('div', { style:{ width:1, background:'var(--separator-2)', flexShrink:0 } }),
      React.createElement('div', { style:{ flex:1, textAlign:'center', padding:'11px 8px' } },
        React.createElement('div', { className:'tiny muted', style:{ fontWeight:700 } }, 'LEVEL'),
        React.createElement('div', { style:{ fontWeight:700, fontSize:'14px', marginTop:2 } }, levelFor(ex))
      )
    ),
    /* video */
    React.createElement('div', { style:{ position:'relative', margin:'0 14px 18px' } },
      React.createElement('div', { className:'ph rounded', style:{ aspectRatio:'16/10', borderRadius:'var(--r-lg)' } }, 'exercise demo'),
      React.createElement('div', { style:{ position:'absolute', top:'50%', left:'50%', transform:'translate(-50%,-50%)', width:48, height:48, borderRadius:'50%', background:'#fff', display:'flex', alignItems:'center', justifyContent:'center', boxShadow:'0 4px 16px #0004' } },
        React.createElement(Icon, { name:'play', size:20 })
      )
    ),
    /* description */
    React.createElement('div', { style:{ padding:'0 14px', fontSize:'14px', lineHeight:1.65, color:'var(--text-2)', marginBottom:18 } }, info.desc),
    /* pro tip */
    React.createElement('div', { style:{ display:'flex', gap:11, background:'var(--accent-soft)', border:'1px solid color-mix(in oklab,var(--accent) 20%,transparent)', borderRadius:'var(--r-md)', padding:'13px 14px', margin:'0 14px 18px', alignItems:'flex-start' } },
      React.createElement('span', { style:{ flexShrink:0, marginTop:1, display:'flex' } }, React.createElement(Icon, { name:'bulb', size:18, color:'var(--accent)' })),
      React.createElement('div', null,
        React.createElement('div', { style:{ fontWeight:700, fontSize:'13px', color:'var(--accent)', marginBottom:3 } }, 'Pro tip'),
        React.createElement('div', { className:'tiny', style:{ lineHeight:1.5, color:'var(--text-2)' } }, info.tips[0]||'')
      )
    ),
    /* muscles */
    React.createElement('div', { className:'sec-label', style:{ padding:'0 14px' } }, 'Muscle activation'),
    React.createElement('div', { style:{ margin:'0 14px 18px', background:'var(--surface)', border:'1px solid var(--separator-2)', borderRadius:'var(--r-lg)', padding:'14px' } },
      React.createElement('div', { style:{ display:'flex', gap:14, alignItems:'flex-start' } },
        React.createElement('div', { style:{ flex:1 } },
          React.createElement('div', { style:{ display:'flex', gap:8, marginBottom:10 } },
            React.createElement('div', { style:{ display:'flex', alignItems:'center', gap:5, fontSize:'11px', fontWeight:700, color:'var(--accent)' } },
              React.createElement('div', { style:{ width:10, height:10, borderRadius:3, background:'var(--accent)' } }), 'Primary'),
            React.createElement('div', { style:{ display:'flex', alignItems:'center', gap:5, fontSize:'11px', fontWeight:700, color:'var(--blue)' } },
              React.createElement('div', { style:{ width:10, height:10, borderRadius:3, background:'var(--blue)' } }), 'Secondary')
          ),
          info.activation.map(({ m, p }) =>
            React.createElement('div', { key:m, style:{ marginBottom:7 } },
              React.createElement('div', { style:{ display:'flex', justifyContent:'space-between', fontSize:'12px', fontWeight:700, marginBottom:3 } },
                React.createElement('span', null, m),
                React.createElement('span', { style:{ color:'var(--text-2)' } }, p + '%')
              ),
              React.createElement('div', { style:{ height:5, borderRadius:999, background:'var(--track)', overflow:'hidden' } },
                React.createElement('div', { style:{ width: p + '%', height:'100%', background: info.primary.some(pr => pr === m || m.includes(pr)) ? 'var(--accent)' : 'var(--blue)', borderRadius:999, transition:'width .6s ease' } })
              )
            )
          )
        ),
        React.createElement(BodyMap, { primary: info.primary, secondary: info.secondary })
      )
    ),
    /* key takeaways */
    React.createElement('div', { className:'sec-label', style:{ padding:'0 14px' } }, 'Key takeaways'),
    React.createElement('div', { style:{ padding:'0 14px', display:'flex', flexDirection:'column', gap:8 } },
      info.tips.map((tip, i) =>
        React.createElement('div', { key:i, style:{ display:'flex', gap:10, background:'var(--surface)', border:'1px solid var(--separator-2)', borderRadius:'var(--r-md)', padding:'11px 13px', alignItems:'flex-start' } },
          React.createElement('div', { style:{ width:20, height:20, borderRadius:6, background:'var(--accent-soft)', color:'var(--accent)', display:'grid', placeItems:'center', fontSize:'10px', fontWeight:900, flexShrink:0, marginTop:1 } }, i + 1),
          React.createElement('div', { style:{ fontSize:'13px', lineHeight:1.55, color:'var(--text)' } }, tip)
        )
      )
    )
  );
}

/* ── History tab ─────────────────────────────────────────────── */
function HistoryTab({ ex, ssCtx }) {
  const history = genHistory(ex);
  const pbs = calcPBs(history);
  const [open, setOpen] = useStateXD(null);
  const fmt = (v, unit) => v > 0 ? v + (unit || 'kg') : 'BW';

  const pbCards = [
    { label:'Est. 1RM',   value: fmt(pbs.e1rm), sub:'Epley formula' },
    { label:'Max Weight', value: fmt(pbs.maxW),  sub:'Single set' },
    { label:'Max Reps',   value: pbs.maxR,        sub:'Single set', unit:'reps' },
    { label:'Max Volume', value: pbs.maxVol > 0 ? pbs.maxVol + 'kg' : 'BW', sub:'Per session' },
  ];

  return React.createElement('div', { style:{ padding:'0 14px 28px' } },
    ssCtx && React.createElement(SSSubTabs, { ctx: ssCtx }),
    React.createElement('div', { className:'sec-label' }, 'Personal best'),
    React.createElement('div', { style:{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:8, marginBottom:4 } },
      pbCards.map(c =>
        React.createElement('div', { key:c.label, style:{ background:'var(--surface)', border:'1px solid var(--separator-2)', borderRadius:'var(--r-md)', padding:'12px 13px' } },
          React.createElement('div', { style:{ fontSize:'11px', fontWeight:700, color:'var(--text-2)', letterSpacing:'.03em', marginBottom:5 } }, c.label.toUpperCase()),
          React.createElement('div', { style:{ fontSize:'22px', fontWeight:800, letterSpacing:'-.02em', color:'var(--accent)', fontVariantNumeric:'tabular-nums' } }, c.value),
          React.createElement('div', { style:{ fontSize:'11px', color:'var(--text-3)', marginTop:2 } }, c.sub)
        )
      )
    ),
    React.createElement('div', { className:'sec-label', style:{ marginTop:18 } }, 'Session history'),
    React.createElement('div', { style:{ display:'flex', flexDirection:'column', gap:8 } },
      history.map((s, i) =>
        React.createElement('div', { key:i, style:{ background:'var(--surface)', border:'1px solid var(--separator-2)', borderRadius:'var(--r-md)', overflow:'hidden' } },
          React.createElement('button', { style:{ width:'100%', display:'flex', alignItems:'center', justifyContent:'space-between', padding:'11px 14px', background:'none', border:0, cursor:'pointer', textAlign:'left' }, onClick:()=>setOpen(open===i?null:i) },
            React.createElement('div', null,
              React.createElement('div', { style:{ fontWeight:700, fontSize:'14px' } }, s.date),
              React.createElement('div', { style:{ fontSize:'12px', color:'var(--text-2)', marginTop:2 } }, s.sets.length + ' sets · ' + (s.sets[0].weight > 0 ? 'top ' + s.sets[0].weight + 'kg' : 'bodyweight'))
            ),
            React.createElement(Icon, { name: open===i ? 'chevron-up' : 'chevron-right', size:16, color:'var(--text-3)' })
          ),
          open === i && React.createElement('div', { style:{ borderTop:'1px solid var(--separator-2)', padding:'8px 14px 12px' } },
            React.createElement('div', { style:{ display:'flex', gap:6, marginBottom:6 } },
              React.createElement('div', { style:{ flex:'.5', fontSize:'11px', fontWeight:700, color:'var(--text-3)' } }, 'SET'),
              React.createElement('div', { style:{ flex:1, fontSize:'11px', fontWeight:700, color:'var(--text-3)' } }, 'WEIGHT'),
              React.createElement('div', { style:{ flex:1, fontSize:'11px', fontWeight:700, color:'var(--text-3)' } }, 'REPS'),
              React.createElement('div', { style:{ flex:1, fontSize:'11px', fontWeight:700, color:'var(--text-3)' } }, 'EST 1RM')
            ),
            s.sets.map((st, si) =>
              React.createElement('div', { key:si, style:{ display:'flex', gap:6, padding:'5px 0', borderTop: si>0?'1px solid var(--separator-2)':0 } },
                React.createElement('div', { style:{ flex:'.5', fontWeight:700, fontSize:'13px', color:'var(--text-3)' } }, si+1),
                React.createElement('div', { style:{ flex:1, fontWeight:600, fontSize:'13px' } }, st.weight > 0 ? st.weight+'kg' : 'BW'),
                React.createElement('div', { style:{ flex:1, fontWeight:600, fontSize:'13px' } }, st.reps),
                React.createElement('div', { style:{ flex:1, fontWeight:700, fontSize:'13px', color:'var(--accent)' } }, epley(st.weight||0, st.reps)+'kg')
              )
            )
          )
        )
      )
    )
  );
}

/* ── Main ────────────────────────────────────────────────────── */
function ExerciseDetail({ exercise, onBack, showActions, workoutCtx, onSave }) {
  const [tab,setTab]=useStateXD(workoutCtx?'workout':'overview');
  const [addSheet,setAddSheet]=useStateXD(null);
  const [ssSubTab,setSsSubTab]=useStateXD('a');
  const isSuperset=!!(workoutCtx&&workoutCtx.isSuperset);
  const activeEx=isSuperset&&ssSubTab==='b'&&workoutCtx.partner?workoutCtx.partner:exercise;
  const info=getXDInfo(activeEx);
  const ssCtx=isSuperset?{active:ssSubTab,setActive:setSsSubTab,exA:exercise,exB:workoutCtx.partner}:null;
  const TABS=workoutCtx?['workout','overview','history']:['overview','history'];
  const TLBL={workout:'Workout',overview:'Overview',history:'History'};
  return React.createElement('div',{className:'phone','data-theme':'light'},
    React.createElement('div',{className:'dynamic-island'}),
    React.createElement('div',{className:'statusbar auto'}),
    React.createElement('div',{className:'navbar bordered'},
      React.createElement('div',{className:'navbar-row'},
        React.createElement('button',{className:'nav-btn',onClick:onBack},React.createElement(Icon,{name:'chevron-left',size:22}),'Back'),
        React.createElement('button',{className:'nav-icon-btn'},React.createElement(Icon,{name:'heart',size:18}))
      ),
      React.createElement('div',{style:{padding:'4px 14px 8px'}},
        React.createElement('div',{style:{fontWeight:800,fontSize:'20px',letterSpacing:'-.02em'}},exercise.name)
      ),
      React.createElement('div',{style:{padding:'8px 14px 10px',borderTop:'1px solid var(--separator-2)'}},
        React.createElement('div',{style:{display:'flex',background:'var(--fill)',borderRadius:999,padding:3}},
          TABS.map(t=>React.createElement('button',{
            key:t,onClick:()=>setTab(t),
            style:{flex:1,padding:'8px 0',borderRadius:999,border:0,cursor:'pointer',fontFamily:'var(--font)',
              fontWeight:700,fontSize:'14px',
              background:tab===t?'var(--surface)':'transparent',
              color:tab===t?'var(--text)':'var(--text-2)',
              boxShadow:tab===t?'var(--shadow-sm)':'none',
              transition:'background .18s,color .18s,box-shadow .18s'}
          },TLBL[t]))
        )
      )
    ),
    React.createElement('div',{className:'screen-body',style:{paddingTop:8}},
      tab==='workout'
        ?React.createElement(WorkoutTab,{exercise,ctx:workoutCtx,onSave})
        :tab==='overview'
          ?React.createElement(OverviewTab,{ex:activeEx,info,ssCtx})
          :React.createElement(HistoryTab,{ex:activeEx,ssCtx})
    ),
    showActions&&React.createElement('div',{style:{flex:'0 0 auto',padding:'10px 14px 0',borderTop:'1px solid var(--separator-2)',display:'flex',flexDirection:'column',gap:8}},
      React.createElement('button',{className:'btn btn-primary',onClick:()=>{}},React.createElement(Icon,{name:'plus',size:18}),' Add to Today\u2019s Workout'),
      React.createElement('button',{className:'btn btn-tinted',onClick:()=>setAddSheet('workouts')},React.createElement(Icon,{name:'dumbbell',size:17}),' Add to a Plan')
    ),
    addSheet==='workouts'&&React.createElement('div',{className:'sheet'},
      React.createElement('div',{className:'scrim',onClick:()=>setAddSheet(null)}),
      React.createElement('div',{className:'sheet-card',style:{maxHeight:'62%'}},
        React.createElement('div',{className:'grabber'}),
        React.createElement('div',{className:'between pad',style:{paddingBottom:6}},
          React.createElement('div',{className:'nav-title'},'Add to which workout?'),
          React.createElement('button',{className:'nav-icon-btn',onClick:()=>setAddSheet(null)},React.createElement(Icon,{name:'x',size:18}))
        ),
        React.createElement('div',{className:'pad',style:{paddingBottom:24,overflowY:'auto'}},
          React.createElement('div',{className:'tiny muted',style:{margin:'2px 4px 12px'}},'From your active plan \u00b7 Push Pull Legs'),
          React.createElement('div',{className:'list'},
            PLAN_WORKOUTS.map(w=>React.createElement('button',{key:w.id,className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick:()=>setAddSheet({workout:w})},
              React.createElement('div',{className:'ex-n',style:{background:'var(--accent-soft)',color:'var(--accent)'}},w.name[0]),
              React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title'},w.name),React.createElement('div',{className:'row-sub'},w.exCount+' exercises')),
              React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
            ))
          )
        )
      )
    ),
    addSheet&&addSheet.workout&&React.createElement('div',{className:'sheet'},
      React.createElement('div',{className:'scrim',onClick:()=>setAddSheet(null)}),
      React.createElement('div',{className:'sheet-card',style:{maxHeight:'76%'}},
        React.createElement('div',{className:'grabber'}),
        React.createElement('div',{className:'between pad',style:{paddingBottom:6}},
          React.createElement('div',{className:'nav-title'},exercise.name+' \u2192 '+addSheet.workout.name),
          React.createElement('button',{className:'nav-icon-btn',onClick:()=>setAddSheet(null)},React.createElement(Icon,{name:'x',size:18}))
        ),
        React.createElement('div',{className:'pad',style:{overflowY:'auto',paddingBottom:24}},
          React.createElement('button',{className:'btn btn-primary',style:{margin:'8px 0 14px'},onClick:()=>setAddSheet(null)},React.createElement(Icon,{name:'plus',size:18}),' Add as new exercise'),
          React.createElement('div',{className:'sec-label',style:{marginTop:4}},'Or replace one'),
          React.createElement('div',{className:'col',style:{gap:9}},
            PLAN_EXERCISES_LIB.filter(e=>e.muscle===exercise.muscle&&e.name!==exercise.name).slice(0,4).map(e=>
              React.createElement('div',{key:e.id,className:'lib-card',style:{padding:'12px 14px'}},
                React.createElement('div',{className:'grow'},React.createElement('div',{className:'lib-title',style:{fontSize:'15px'}},e.name),React.createElement('div',{className:'lib-meta'},'3 sets \u00b7 8\u201312 reps')),
                React.createElement('button',{className:'badge badge-gray',style:{cursor:'pointer',border:0,display:'inline-flex',alignItems:'center',gap:5},onClick:()=>setAddSheet(null)},React.createElement(Icon,{name:'swap',size:13}),' Replace')
              )
            )
          )
        )
      )
    ),
    React.createElement('div',{className:'home-indicator'})
  );
}

window.ExerciseDetail = ExerciseDetail;
