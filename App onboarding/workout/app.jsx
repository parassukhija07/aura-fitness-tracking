/* Active Workout — main app: overview, rest pill, modals, summary, celebration. */
(function(){
const { useState, useEffect, useRef } = React;
const clone = o => JSON.parse(JSON.stringify(o));
const fmt = s => `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
const num = v => v === '' || v == null ? 0 : Number(v);

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "startView": "superset",
  "darkMode": false,
  "showHistory": true,
  "restDuration": 90
}/*EDITMODE-END*/;

function lookupWkEx(ex) {
  return { id: ex.id, name: ex.name, muscle: ex.muscle||(ex.groups&&ex.groups[0])||'Unknown', equip: ex.equipment||'Unknown' };
}

function App(props) {
  props = props || {};
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  window.__wkTweaks = t;
  const [wk, setWk] = useState(() => {
    if (props.emptyMode) return { version: WORKOUT.version, name: props.workoutName || 'My Workout', program: 'Free Workout', exercises: [] };
    const base = clone(WORKOUT);
    try {
      const saved = localStorage.getItem('aura_wk');
      if (saved) {
        const s = JSON.parse(saved);
        // Only restore if schema version matches — otherwise clear and use fresh data
        if (s.version !== WORKOUT.version) { try { localStorage.removeItem('aura_wk'); } catch(e){} }
        if (s.version === WORKOUT.version) {
          base.exercises.forEach((e, i) => {
            if (s.exercises && s.exercises[i] && s.exercises[i].id === e.id) {
              const sv = s.exercises[i];
              e.sets = sv.sets || e.sets;
              if (sv.completed !== undefined) e.completed = sv.completed;
              if (sv.note !== undefined) e.note = sv.note;
              if (sv.pulley !== undefined) e.pulley = sv.pulley;
            }
          });
        }
      }
    } catch(err) {}
    return base;
  });
  const [view, setView] = useState(() => {
    if (t.startView === 'superset') return 'superset';
    if (t.startView === 'exercise') return 'exercise';
    return 'overview';
  });
  const [idx, setIdx] = useState(0);
  const [ssIdx, setSsIdx] = useState(() => t.startView === 'superset' ? 3 : 0);
  const [dragIdx, setDragIdx] = useState(null);
  const [elapsed, setElapsed] = useState(() => Number(localStorage.getItem('aura_elapsed')||1487));
  const [rest, setRest] = useState({ active:false, total:60, left:60, running:true });
  const [pos, setPos] = useState(() => JSON.parse(localStorage.getItem('aura_pill')||'null') || { x: 96, y: 690 });
  const [modal, setModal] = useState(null);
  const [celeb, setCeleb] = useState(null);
  const [activeMuscle, setActiveMuscle] = useState(null);
  const [activeEquip, setActiveEquip] = useState('All');
  const [exDetail, setExDetail] = useState(null);
  const drag = useRef(null);
  // Apply dark/light to all phone elements when theme or view changes
  useEffect(() => {
    document.querySelectorAll('.phone').forEach(el =>
      el.setAttribute('data-theme', t.darkMode ? 'dark' : 'light')
    );
  }, [t.darkMode, view]);

  // persist
  useEffect(()=>{ localStorage.setItem('aura_wk', JSON.stringify(wk)); }, [wk]);
  useEffect(()=>{ localStorage.setItem('aura_elapsed', elapsed); }, [elapsed]);
  useEffect(()=>{ localStorage.setItem('aura_pill', JSON.stringify(pos)); }, [pos]);

  // workout timer
  useEffect(()=>{ if(view==='summary')return; const t=setInterval(()=>setElapsed(e=>e+1),1000); return ()=>clearInterval(t); },[view]);
  // rest timer
  useEffect(()=>{
    if(!rest.active||!rest.running) return;
    const t=setInterval(()=>setRest(r=>{ if(r.left<=1){clearInterval(t);return{...r,active:false,left:0};} return{...r,left:r.left-1};}),1000);
    return ()=>clearInterval(t);
  },[rest.active,rest.running]);

  // celebration auto-dismiss
  useEffect(()=>{ if(celeb){ const t=setTimeout(()=>setCeleb(null),2400); return ()=>clearTimeout(t);} },[celeb]);

  function startRest(total){ setRest({active:true,total,left:total,running:true}); }

  function mutate(fn){ setWk(prev=>{ const w=clone(prev); fn(w); return w; }); }

  // ---- set handlers ----
  const onChange=(setIdx,field,val)=>mutate(w=>{ w.exercises[idx].sets[setIdx][field]=val; });
  const onToggle=(setIdx,done)=>{
    const ex=wk.exercises[idx]; const s=ex.sets[setIdx];
    mutate(w=>{ w.exercises[idx].sets[setIdx].done=done; });
    if(done){
      // celebration checks
      if(num(s.weight)>ex.lastPR.weight) setCeleb({emoji:'\uD83C\uDFC6',title:'New PR!',msg:`${s.weight} kg beats your ${ex.lastPR.weight} kg best.`});
      else if(num(s.reps)>ex.target.reps && num(s.weight)>=ex.target.weight) setCeleb({emoji:'\uD83D\uDD25',title:'Extra reps!',msg:`${s.reps} reps — above today\u2019s target. Keep it up.`});
      // rest unless final set
      if(setIdx < ex.sets.length-1) startRest(t.restDuration);
    }
  };
  const onAddSet=()=>{ const ex=wk.exercises[idx]; const last=ex.sets[ex.sets.length-1]||{type:'normal'};
    mutate(w=>{ w.exercises[idx].sets.push({weight:'',reps:'',done:false,type:'normal'}); });
    startRest(t.restDuration); };
  const onDelete=(setIdx)=>mutate(w=>{ w.exercises[idx].sets.splice(setIdx,1); });
  const onSetNote=(setIdx,val)=>mutate(w=>{ w.exercises[idx].sets[setIdx].note=val; });
  const onPulley=(p)=>mutate(w=>{ w.exercises[idx].pulley=p; });
  const onExNote=(val)=>mutate(w=>{ w.exercises[idx].note=val; });
  const setType=(setIdx,type)=>{ mutate(w=>{ w.exercises[idx].sets[setIdx].type=type; }); setModal(null); };

  const onComplete=()=>{
    const ex=wk.exercises[idx];
    mutate(w=>{ const e=w.exercises[idx];
      e.sets = e.sets.filter(s=>!(s.weight===''&&s.reps===''&&!s.done));
      e.sets.forEach(s=>{ if(s.weight!==''&&s.reps!=='') s.done=true; });
      e.completed=true;
    });
    const doneSets=ex.sets.filter(s=>s.weight!==''&&s.reps!=='').length;
    setCeleb({emoji:'\uD83D\uDCAA',title:'Exercise done',msg:`${doneSets} solid sets logged. On to the next.`});
    startRest(90);
    setView('overview');
  };

  // ---- exercise handlers ----
  const substitute=(opt)=>{ const ei=modal.exIdx; mutate(w=>{ const e=w.exercises[ei];
    e.name=opt.name; e.equipment=opt.equipment; e.isCable=opt.equipment==='Cable'; }); setModal(null); };
  const removeEx=(ei)=>{ mutate(w=>{ w.exercises.splice(ei,1); }); setModal(null); };
  const addEx=(opt)=>{ mutate(w=>{ w.exercises.push({ id:'x'+Date.now(),name:opt.name,muscle:opt.muscle,groups:[opt.muscle],
    equipment:opt.equipment,isCable:opt.equipment==='Cable',repRange:'8–12',planned:3,
    lastPR:{weight:0,reps:0,date:'—'},target:{weight:0,reps:10,note:'First time'},history:[],warmup:[],hint:'Focus on controlled form.',pulley:'single',
    sets:[{weight:'',reps:'',done:false,type:'normal'},{weight:'',reps:'',done:false,type:'normal'},{weight:'',reps:'',done:false,type:'normal'}] }); }); setModal(null); };
  const makeSuperset=(ei)=>{ mutate(w=>{ if(w.exercises[ei+1]) w.exercises[ei].superset=true; }); setModal(null); };
  const createSuperset=(srcIdx,tgtIdx)=>{
    mutate(w=>{
      // clear all existing superset flags
      w.exercises.forEach(e=>{ e.superset=false; });
      // move target adjacent to source (right after)
      const exs=w.exercises;
      const tgt=exs.splice(tgtIdx,1)[0];
      const insertAt=tgtIdx>srcIdx?srcIdx+1:srcIdx;
      exs.splice(insertAt,0,tgt);
      exs[insertAt-1>-1?insertAt-1:0].superset=false;
      exs[insertAt].superset=false;
      exs[srcIdx<insertAt?srcIdx:insertAt].superset=true;
    });
    setModal(null);
  };

  // ---- pill drag ----
  const onPillDown=(e)=>{ const r=e.currentTarget.getBoundingClientRect(); drag.current={dx:e.clientX-r.left,dy:e.clientY-r.top}; e.currentTarget.setPointerCapture(e.pointerId); };
  const onPillMove=(e)=>{ if(!drag.current)return; const phone=e.currentTarget.closest('.phone').getBoundingClientRect();
    let x=e.clientX-phone.left-drag.current.dx, y=e.clientY-phone.top-drag.current.dy;
    x=Math.max(8,Math.min(x,393-200)); y=Math.max(60,Math.min(y,852-70)); setPos({x,y}); };
  const onPillUp=()=>{ drag.current=null; };

  // computed
  const totalSets=wk.exercises.reduce((a,e)=>a+e.sets.length,0);
  const doneSets=wk.exercises.reduce((a,e)=>a+e.sets.filter(s=>s.done).length,0);
  const volume=wk.exercises.reduce((a,e)=>a+e.sets.filter(s=>s.done).reduce((b,s)=>b+num(s.weight)*num(s.reps),0),0);

  function tweaksEl() {
    return React.createElement(TweaksPanel, null,
      React.createElement(TweakSection, { label: 'Starting screen' }),
      React.createElement(TweakRadio, { label: 'Open on', value: t.startView,
        options: ['overview','superset','exercise'],
        onChange: v => { setTweak('startView', v); if(v==='superset'){setSsIdx(3);setView('superset');}else if(v==='exercise'){setIdx(0);setView('exercise');}else setView('overview'); } }),
      React.createElement(TweakSection, { label: 'Theme' }),
      React.createElement(TweakToggle, { label: 'Dark mode', value: t.darkMode, onChange: v => setTweak('darkMode', v) }),
      React.createElement(TweakSection, { label: 'Sets' }),
      React.createElement(TweakToggle, { label: 'Show history', value: t.showHistory, onChange: v => setTweak('showHistory', v) }),
      React.createElement(TweakSection, { label: 'Rest timer' }),
      React.createElement(TweakSlider, { label: 'Default rest (s)', value: t.restDuration, min: 30, max: 180, step: 15, onChange: v => setTweak('restDuration', v) })
    );
  }
    // ================= RENDER =================
  if(exDetail) return React.createElement(React.Fragment,null,
    React.createElement(ExerciseDetail,{exercise:exDetail,onBack:()=>setExDetail(null)}),
    tweaksEl()
  );
  if(view==='exercise'){
    const ei=idx; const ex=wk.exercises[ei];
    if(!ex){setView('overview');return null;}
    const onChgEx=(si,f,v)=>mutate(w=>{w.exercises[ei].sets[si][f]=v;});
    const onTglEx=(si,done)=>{
      const s=ex.sets[si];
      mutate(w=>{w.exercises[ei].sets[si].done=done;});
      if(done){
        if(num(s.weight)>ex.lastPR.weight) setCeleb({emoji:'\uD83C\uDFC6',title:'New PR!',msg:`${s.weight}\u202fkg beats your ${ex.lastPR.weight}\u202fkg best.`});
        else if(num(s.reps)>ex.target.reps&&num(s.weight)>=ex.target.weight) setCeleb({emoji:'\uD83D\uDD25',title:'Extra reps!',msg:`${s.reps} reps \u2014 above today\u2019s target.`});
        if(si<ex.sets.length-1) startRest(t.restDuration);
      }
    };
    const onAddEx=()=>{mutate(w=>{w.exercises[ei].sets.push({weight:'',reps:'',done:false,type:'normal'});});startRest(t.restDuration);};
    const onDelEx=(si)=>mutate(w=>{w.exercises[ei].sets.splice(si,1);});
    const onSetNoteEx=(si,v)=>mutate(w=>{w.exercises[ei].sets[si].note=v;});
    const onPulleyEx=(p)=>mutate(w=>{w.exercises[ei].pulley=p;});
    const onExNoteEx=(v)=>mutate(w=>{w.exercises[ei].note=v;});
    const onSetTypeEx=(si,type)=>{mutate(w=>{w.exercises[ei].sets[si].type=type;});setModal(null);};
    return React.createElement(React.Fragment,null,
      React.createElement(ExerciseView,{ ex, exIdx:ei, onBack:()=>setView('overview'),
        onChange:onChgEx, onToggle:onTglEx, onAddSet:onAddEx, onDelete:onDelEx,
        onSetNote:onSetNoteEx, onPulley:onPulleyEx, onComplete, onExNote:onExNoteEx,
        onOpenType:(si)=>setModal({kind:'type',setIdx:si,onSetType:onSetTypeEx}),
        onOpenMenu:(mei)=>setModal({kind:'menu',exIdx:mei}),
        onExerciseDetail:()=>setExDetail(lookupWkEx(ex)) }),
      restPill(), modalEl(), celebEl(), tweaksEl()
    );
  }
  if(view==='superset'){
    if(!wk.exercises[ssIdx]||!wk.exercises[ssIdx+1]){setView('overview');return null;}
    if(!wk.exercises[ssIdx].superset){setView('overview');return null;}
    const exA=wk.exercises[ssIdx]; const exB=wk.exercises[ssIdx+1];
    const onChangeA=(si,f,v)=>mutate(w=>{w.exercises[ssIdx].sets[si][f]=v.replace(/[^0-9.]/g,'');});
    const onToggleA=(si,done)=>{mutate(w=>{w.exercises[ssIdx].sets[si].done=done;});if(done)startRest(60);};
    const onDeleteA=(si)=>mutate(w=>{w.exercises[ssIdx].sets.splice(si,1);});
    const onChangeB=(si,f,v)=>mutate(w=>{w.exercises[ssIdx+1].sets[si][f]=v.replace(/[^0-9.]/g,'');});
    const onToggleB=(si,done)=>{mutate(w=>{w.exercises[ssIdx+1].sets[si].done=done;});if(done)startRest(60);};
    const onDeleteB=(si)=>mutate(w=>{w.exercises[ssIdx+1].sets.splice(si,1);});
    const onAddRound=()=>mutate(w=>{
      w.exercises[ssIdx].sets.push({weight:'',reps:'',done:false,type:'normal'});
      w.exercises[ssIdx+1].sets.push({weight:'',reps:'',done:false,type:'normal'});
    });
    const onSSComplete=()=>{
      mutate(w=>{[ssIdx,ssIdx+1].forEach(ei=>{const e=w.exercises[ei];
        e.sets=e.sets.filter(s=>!(s.weight===''&&s.reps===''&&!s.done));
        e.sets.forEach(s=>{if(s.weight!==''&&s.reps!=='')s.done=true;}); e.completed=true;
      });});
      setCeleb({emoji:'\uD83D\uDCAA',title:'Superset done',msg:'Both exercises logged. Keep going.'});
      startRest(t.restDuration); setView('overview');
    };
    return React.createElement(React.Fragment,null,
      React.createElement(SupersetView,{exA,exB,onBack:()=>setView('overview'),
        onChangeA,onToggleA,onDeleteA,onChangeB,onToggleB,onDeleteB,onAddRound,
        onComplete:onSSComplete,onOpenMenu:()=>setModal({kind:'menu',exIdx:ssIdx}),
        onExNoteA:(val)=>mutate(w=>{w.exercises[ssIdx].note=val;}),
        onExNoteB:(val)=>mutate(w=>{w.exercises[ssIdx+1].note=val;}),
        onExerciseDetailA:()=>setExDetail(lookupWkEx(wk.exercises[ssIdx])),
        onExerciseDetailB:()=>setExDetail(lookupWkEx(wk.exercises[ssIdx+1]))
      }),restPill(),modalEl(),celebEl(),tweaksEl());
  }
  if(view==='minimized'){
    return React.createElement(React.Fragment,null,
    React.createElement('div',{className:'phone','data-theme':'light'},
      React.createElement('div',{className:'dynamic-island'}),
      React.createElement('div',{className:'statusbar auto'}),
      React.createElement('div',{className:'navbar'},
        React.createElement('div',{className:'navbar-row'},
          React.createElement('div',null,
            React.createElement('div',{className:'tiny muted',style:{fontWeight:700,letterSpacing:'.02em'}},new Date().toLocaleDateString('en-US',{weekday:'long',month:'short',day:'numeric'}).toUpperCase()),
            React.createElement('div',{style:{fontWeight:800,fontSize:'26px',letterSpacing:'-.02em'}},'Today')
          ),
          React.createElement('button',{className:'nav-icon-btn'},React.createElement(Icon,{name:'calendar-day',size:19}))
        )
      ),
      React.createElement('div',{className:'screen-body pad',style:{paddingBottom:'120px',opacity:.35,pointerEvents:'none'}},
        React.createElement('div',{className:'tiny muted',style:{fontWeight:700,letterSpacing:'.06em',textTransform:'uppercase',marginBottom:'10px'}},'Today’s Workout'),
        React.createElement('div',{className:'card card-pad',style:{borderRadius:'var(--r-xl)'}},
          React.createElement('div',{style:{fontSize:'20px',fontWeight:800,letterSpacing:'-.02em'}},wk.name),
          React.createElement('div',{className:'tiny muted',style:{marginTop:4}},wk.exercises.length+' exercises')
        )
      ),
      React.createElement('div',{
        style:{position:'absolute',bottom:88,left:14,right:14,
          background:'var(--accent)',borderRadius:'var(--r-lg)',padding:'13px 16px',
          display:'flex',alignItems:'center',gap:12,color:'#fff',
          boxShadow:'0 8px 32px rgba(0,0,0,.18)'},
        },
        React.createElement('button',{style:{display:'contents',cursor:'pointer',border:'none',background:'none',color:'inherit',fontFamily:'var(--font)',textAlign:'left',flex:1,gap:12,display:'flex',alignItems:'center'},onClick:()=>setView('overview')},
          React.createElement(Icon,{name:'bolt',size:20,style:{flexShrink:0}}),
          React.createElement('div',{style:{flex:1,textAlign:'left'}},
            React.createElement('div',{style:{fontWeight:800,fontSize:'15px'}},wk.name),
            React.createElement('div',{style:{fontSize:'13px',opacity:.85}},fmt(elapsed)+' · Tap to resume')
          )
        ),
        React.createElement('button',{
          style:{background:'rgba(255,255,255,.18)',border:'none',borderRadius:'var(--r-sm)',width:34,height:34,display:'grid',placeItems:'center',flexShrink:0,cursor:'pointer',color:'#fff'},
          onClick:(ev)=>{ev.stopPropagation();setModal({kind:'end'});}},
          React.createElement(Icon,{name:'x',size:17})
        )
      ),
      React.createElement('div',{className:'tabbar'},
        React.createElement('button',{className:'tab active'},React.createElement(Icon,{name:'log',size:25}),React.createElement('span',null,'Log')),
        React.createElement('button',{className:'tab'},React.createElement(Icon,{name:'dumbbell',size:25}),React.createElement('span',null,'Plan')),
        React.createElement('button',{className:'tab'},React.createElement(Icon,{name:'chart',size:25}),React.createElement('span',null,'Progress')),
        React.createElement('button',{className:'tab'},React.createElement(Icon,{name:'person',size:25}),React.createElement('span',null,'Profile'))
      ),
      React.createElement('div',{className:'home-indicator'}),
      tweaksEl()
    ),
    modalEl(), celebEl()
    );
  }
  if(view==='summary') return React.createElement(React.Fragment,null, summaryEl(), celebEl(), tweaksEl());

  // ── EMPTY OVERVIEW ─────────────────────────────────────────────
  function emptyOverview() {
    const MG = [
      { label:'Chest',     color:'var(--accent)',        exs:[['Barbell Bench Press','Barbell'],['Incline DB Press','Dumbbell'],['Cable Fly','Cable'],['Push-Up','Bodyweight']] },
      { label:'Back',      color:'var(--blue)',          exs:[['Barbell Row','Barbell'],['Pull-Up','Bodyweight'],['Lat Pulldown','Cable'],['Seated Row','Cable']] },
      { label:'Legs',      color:'var(--red)',           exs:[['Barbell Squat','Barbell'],['Romanian Deadlift','Barbell'],['Leg Press','Machine'],['Leg Curl','Machine']] },
      { label:'Shoulders', color:'var(--purple)',        exs:[['Overhead Press','Barbell'],['Lateral Raise','Dumbbell'],['Face Pulls','Cable'],['Arnold Press','Dumbbell']] },
      { label:'Arms',      color:'var(--green)',         exs:[['Barbell Curl','Barbell'],['Tricep Pushdown','Cable'],['Hammer Curl','Dumbbell'],['Skull Crushers','Barbell']] },
      { label:'Core',      color:'oklch(0.60 0.10 50)', exs:[['Plank','Bodyweight'],['Cable Crunch','Cable'],['Ab Wheel','Bodyweight'],['Hanging Leg Raise','Bodyweight']] },
    ];
    const EQUIPS = ['All','Barbell','Dumbbell','Cable','Machine','Bodyweight'];
    const THUMB = {
      Chest:    { bg:'linear-gradient(145deg,oklch(0.90 0.07 58),oklch(0.82 0.13 52))',   tx:'oklch(0.44 0.18 54)'  },
      Back:     { bg:'linear-gradient(145deg,oklch(0.90 0.05 248),oklch(0.82 0.10 244))', tx:'oklch(0.42 0.13 248)' },
      Shoulders:{ bg:'linear-gradient(145deg,oklch(0.90 0.05 284),oklch(0.82 0.09 279))', tx:'oklch(0.42 0.12 283)' },
      Arms:     { bg:'linear-gradient(145deg,oklch(0.90 0.06 151),oklch(0.82 0.11 147))', tx:'oklch(0.42 0.14 149)' },
      Legs:     { bg:'linear-gradient(145deg,oklch(0.90 0.06 31),oklch(0.82 0.11 25))',   tx:'oklch(0.42 0.13 27)'  },
      Core:     { bg:'linear-gradient(145deg,oklch(0.90 0.05 19),oklch(0.82 0.10 13))',   tx:'oklch(0.42 0.13 17)'  },
    };
    const activeMg = MG.find(m => m.label === activeMuscle);
    const suggestions = [
      { name:'Barbell Squat',   muscle:'Legs',      equip:'Barbell'  },
      { name:'Overhead Press',  muscle:'Shoulders', equip:'Barbell'  },
      { name:'Barbell Row',     muscle:'Back',      equip:'Barbell'  },
      { name:'Dumbbell Curl',   muscle:'Arms',      equip:'Dumbbell' },
      { name:'Bench Press',     muscle:'Chest',     equip:'Barbell'  },
      { name:'Cable Crunch',    muscle:'Core',      equip:'Cable'    },
    ];

    // filter active muscle list by equipment
    const filteredMgExs = activeMg
      ? activeMg.exs.filter(([,eq]) => activeEquip === 'All' || eq === activeEquip)
      : [];

    // add exercise and immediately start workout on that exercise screen
    const addExAndStart = opt => {
      const newIdx = wk.exercises.length;
      addEx(opt);
      setIdx(newIdx);
      setView('exercise');
    };

    const CatCard = ({ name, muscle, equip }) => {
      const th = THUMB[muscle] || { bg:'var(--fill)', tx:'var(--text-3)' };
      return React.createElement('button', {
        className: 'cat-item',
        style: { border:0, textAlign:'left', cursor:'pointer', background:'var(--surface)' },
        onClick: () => addExAndStart({ name, muscle, equipment: equip })
      },
        React.createElement('div', { className:'cat-thumb ph',
          style:{ background:th.bg, display:'flex', alignItems:'center', justifyContent:'center', border:'none' } },
          React.createElement('span', { style:{
            fontSize:'11px', fontWeight:800, color:th.tx,
            letterSpacing:'.06em', textTransform:'uppercase',
            textAlign:'center', padding:'0 6px', lineHeight:1.3
          } }, muscle)
        ),
        React.createElement('div', { className:'cat-name' }, name),
        React.createElement('div', { className:'cat-meta' }, muscle + ' · ' + equip)
      );
    };

    return React.createElement('div', { className:'phone', 'data-theme':'light' },
      React.createElement('div', { className:'dynamic-island' }),
      React.createElement('div', { className:'statusbar auto' }),
      React.createElement('div', { className:'navbar bordered' },
        React.createElement('div', { className:'navbar-row' },
          React.createElement('button', { className:'nav-btn', style:{color:'var(--red)'}, onClick:()=>setModal({kind:'end'}) }, 'End'),
          React.createElement('div', { className:'col', style:{alignItems:'center'} },
            React.createElement('div', { className:'tiny muted', style:{fontWeight:700} }, wk.name),
            React.createElement('div', { className:'stat-num', style:{fontSize:'19px',color:'var(--accent)'} }, fmt(elapsed))
          ),
          React.createElement('button', { className:'nav-icon-btn', onClick:()=>props.onMinimize?props.onMinimize():setView('minimized') },
            React.createElement(Icon, { name:'minus', size:22 }))
        )
      ),
      React.createElement('div', { className:'screen-body pad pad-b' },
        // Hero
        React.createElement('div', { style:{ textAlign:'center', padding:'30px 16px 24px' } },
          React.createElement('div', { style:{ width:72, height:72, borderRadius:'50%', background:'var(--accent-soft)', display:'grid', placeItems:'center', margin:'0 auto 14px', color:'var(--accent)' } },
            React.createElement(Icon, { name:'dumbbell', size:32 })
          ),
          React.createElement('div', { style:{ fontSize:22, fontWeight:800, letterSpacing:'-.02em' } }, 'Build your workout'),
          React.createElement('div', { style:{ fontSize:14, color:'var(--text-2)', lineHeight:1.55, maxWidth:250, margin:'6px auto 0' } },
            'Add exercises as you go — everything is saved automatically.'
          )
        ),
        // Search bar
        React.createElement('button', {
          style:{ display:'flex', alignItems:'center', gap:10, width:'100%', background:'var(--fill)', borderRadius:'var(--r-sm)', padding:'12px 14px', border:'none', cursor:'pointer', fontFamily:'var(--font)', textAlign:'left', marginBottom:2 },
          onClick:()=>setModal({kind:'add'})
        },
          React.createElement(Icon, { name:'search', size:17, color:'var(--text-3)' }),
          React.createElement('span', { style:{ flex:1, color:'var(--text-3)', fontSize:15 } }, 'Search exercise library…')
        ),
        // Muscle chips
        React.createElement('div', { className:'sec-label' }, 'Quick add by muscle'),
        React.createElement('div', { style:{ display:'flex', overflowX:'auto', gap:8, paddingBottom:4, WebkitOverflowScrolling:'touch', scrollbarWidth:'none', msOverflowStyle:'none' } },
          ...MG.map(mg =>
            React.createElement('button', {
              key: mg.label,
              onClick: () => setActiveMuscle(activeMuscle === mg.label ? null : mg.label),
              style:{
                display:'flex', alignItems:'center', gap:7,
                padding:'8px 14px', borderRadius:999,
                background: activeMuscle === mg.label ? mg.color : 'var(--fill)',
                color: activeMuscle === mg.label ? '#fff' : 'var(--text)',
                border:'none', cursor:'pointer', fontFamily:'var(--font)',
                fontSize:13, fontWeight:700, letterSpacing:'-.01em',
                transition:'background .15s, color .15s',
              }
            },
              React.createElement('div', { style:{ width:7, height:7, borderRadius:'50%', background: activeMuscle === mg.label ? 'rgba(255,255,255,.6)' : mg.color, flexShrink:0 } }),
              mg.label
            )
          )
        ),
        // Equipment chips
        React.createElement('div', { className:'sec-label', style:{ marginTop:14 } }, 'Filter by equipment'),
        React.createElement('div', { style:{ display:'flex', overflowX:'auto', gap:8, paddingBottom:4, marginBottom:4, WebkitOverflowScrolling:'touch', scrollbarWidth:'none', msOverflowStyle:'none' } },
          ...EQUIPS.map(eq =>
            React.createElement('button', {
              key: eq,
              onClick: () => setActiveEquip(activeEquip === eq ? 'All' : eq),
              style:{
                padding:'7px 14px', borderRadius:999,
                background: activeEquip === eq ? 'var(--text)' : 'var(--fill)',
                color: activeEquip === eq ? 'var(--bg)' : 'var(--text)',
                border:'none', cursor:'pointer', fontFamily:'var(--font)',
                fontSize:13, fontWeight:700, letterSpacing:'-.01em',
                transition:'background .15s, color .15s',
              }
            }, eq)
          )
        ),
        // Catalog — muscle filtered or suggestions
        activeMg
          ? React.createElement('div', { style:{ marginTop:16 } },
              React.createElement('div', { className:'sec-label' }, activeMg.label),
              filteredMgExs.length === 0
                ? React.createElement('div', { style:{ color:'var(--text-3)', fontSize:13, padding:'12px 0' } }, 'No ' + activeMg.label + ' exercises for this equipment.')
                : React.createElement('div', { className:'catalog' },
                    ...filteredMgExs.map(([exName, exEquip], i) =>
                      React.createElement(CatCard, { key:i, name:exName, muscle:activeMg.label, equip:exEquip })
                    )
                  )
            )
          : React.createElement('div', { style:{ marginTop:16 } },
              React.createElement('div', { className:'sec-label' }, 'Suggested'),
              React.createElement('div', { className:'catalog' },
                ...suggestions
                  .filter(s => activeEquip === 'All' || s.equip === activeEquip)
                  .map((ex, i) =>
                    React.createElement(CatCard, { key:i, name:ex.name, muscle:ex.muscle, equip:ex.equip })
                  )
              )
            )
      ),
      React.createElement('div', { className:'home-indicator' })
    );
  }

  // ---- OVERVIEW ----
  function overview(){
    if (wk.exercises.length === 0) return emptyOverview();
    return React.createElement('div',{className:'phone','data-theme':'light'},
      React.createElement('div',{className:'dynamic-island'}),
      React.createElement('div',{className:'statusbar auto'}),
      React.createElement('div',{className:'navbar bordered'},
        React.createElement('div',{className:'navbar-row'},
          React.createElement('button',{className:'nav-btn',style:{color:'var(--red)'},onClick:()=>setModal({kind:'end'})},'End'),
          React.createElement('div',{className:'col',style:{alignItems:'center'}},
            React.createElement('div',{className:'tiny muted',style:{fontWeight:700}},wk.name),
            React.createElement('div',{className:'stat-num',style:{fontSize:'19px',color:'var(--accent)'}},fmt(elapsed))),
          React.createElement('button',{className:'nav-icon-btn',onClick:()=> props.onMinimize ? props.onMinimize() : setView('minimized'),title:'Minimize'},
            React.createElement(Icon,{name:'minus',size:22}))
        )
      ),
      React.createElement('div',{className:'screen-body pad pad-b'},
        React.createElement('div',{className:'between',style:{margin:'14px 4px 4px'}},
          React.createElement('div',{style:{fontWeight:800,fontSize:'15px'}},`${doneSets}/${totalSets} sets`),
          React.createElement('div',{className:'tiny muted'},wk.program)),
        React.createElement('div',{className:'bar',style:{marginBottom:'16px'}},
          React.createElement('i',{style:{width:`${totalSets?doneSets/totalSets*100:0}%`}})),
        (()=>{
          const els=[];
          wk.exercises.forEach((e,i)=>{
            const d=e.sets.filter(s=>s.done).length;
            const allDone=e.completed||d===e.sets.length&&d>0;
            const isSSFirst=e.superset===true;
            const isSSSecond=i>0&&wk.exercises[i-1].superset===true;
            if(isSSSecond){
              els.push(React.createElement('div',{key:'ss-conn-'+i,style:{display:'flex',alignItems:'center',gap:'8px',margin:'-2px 0',padding:'0 10px'}},
                React.createElement('div',{style:{flex:1,height:'2px',background:'var(--accent-soft)',borderRadius:'999px'}}),
                React.createElement('span',{style:{fontSize:'10px',fontWeight:800,color:'var(--accent)',background:'var(--accent-soft)',padding:'3px 9px',borderRadius:'999px',letterSpacing:'.04em',whiteSpace:'nowrap',display:'flex',alignItems:'center',gap:'3px'}},
                  React.createElement(Icon,{name:'bolt',size:11}),' SUPERSET'),
                React.createElement('div',{style:{flex:1,height:'2px',background:'var(--accent-soft)',borderRadius:'999px'}})
              ));
            }
            els.push(React.createElement('div',{key:e.id,
              draggable:true,
              className:'ex-card'+(allDone?' done':'')+(dragIdx===i?' dragging':''),
              style:{...((isSSFirst||isSSSecond)?{borderColor:'color-mix(in oklab,var(--accent) 30%,transparent)'}:{}),cursor:'pointer',
                ...(dragIdx!==null&&dragIdx!==i?{borderStyle:'dashed',opacity:.7}:{})},
              onDragStart:(ev)=>{
                if(!ev.target.closest('.ex-grip')){ev.preventDefault();return;}
                setDragIdx(i); ev.dataTransfer.effectAllowed='move';
              },
              onDragOver:(ev)=>{ ev.preventDefault(); ev.dataTransfer.dropEffect='move'; },
              onDrop:(ev)=>{
                ev.preventDefault();
                if(dragIdx===null||dragIdx===i){setDragIdx(null);return;}
                mutate(w=>{ const exs=w.exercises; const [moved]=exs.splice(dragIdx,1); exs.splice(dragIdx<i?i-1:i,0,moved); });
                setDragIdx(null);
              },
              onDragEnd:()=>setDragIdx(null),
              onClick:(ev)=>{
                if(ev.target.closest('.ex-more-btn'))return;
                if(isSSFirst||isSSSecond){setSsIdx(isSSFirst?i:i-1);setView('superset');}
                else{setIdx(i);setView('exercise');}
              }},
              React.createElement('span',{className:'ex-grip',style:{cursor:'grab',touchAction:'none'}},React.createElement(Icon,{name:'grip',size:18,color:'var(--text-3)'})),
              React.createElement('div',{className:'grow',style:{textAlign:'left'}},
                React.createElement('div',{className:'between'},
                  React.createElement('button',{style:{fontWeight:700,fontSize:'16px',letterSpacing:'-.01em',background:'none',border:0,padding:0,cursor:'pointer',color:'var(--text)',textAlign:'left',fontFamily:'var(--font)'},onClick:(ev)=>{ev.stopPropagation();setExDetail(lookupWkEx(e));}},e.name),
                  allDone&&React.createElement(Icon,{name:'check-c',size:20,color:'var(--green)'})),
                React.createElement('div',{className:'tiny muted',style:{marginTop:'2px'}},
                  `${e.sets.length} sets · ${e.repRange} reps · ${e.equipment}`,
                  isSSFirst&&React.createElement('span',{className:'badge badge-accent',style:{marginLeft:'8px',fontSize:'10px',padding:'2px 7px'}},React.createElement(Icon,{name:'bolt',size:10}),' SS')),
                React.createElement('div',{className:'mini-bar'},React.createElement('i',{style:{width:`${d/e.sets.length*100}%`}}))
              ),
              React.createElement('button',{className:'ex-more-btn nav-icon-btn',style:{flexShrink:0},
                onClick:(ev)=>{ev.stopPropagation();setModal({kind:'ex-menu-ov',exIdx:i});}},
                React.createElement(Icon,{name:'ellipsis',size:20}))));
          });
          return els;
        })(),
        React.createElement('button',{className:'btn btn-tinted',style:{marginTop:'14px'},onClick:()=>setModal({kind:'add'})},
          React.createElement(Icon,{name:'plus',size:18}),' Add Exercise'),
        React.createElement('button',{className:'btn btn-primary',style:{marginTop:'10px'},onClick:()=>setView('summary')},
          React.createElement(Icon,{name:'check',size:19}),' Finish Workout')
      ),
      React.createElement('div',{className:'home-indicator'})
    );
  }

  // ---- REST PILL ----
  function restPill(){
    if(!rest.active) return null;
    const pct=rest.left/rest.total*100;
    return React.createElement('div',{className:'rest-pill',style:{left:pos.x+'px',top:pos.y+'px'},
      onPointerDown:onPillDown,onPointerMove:onPillMove,onPointerUp:onPillUp},
      React.createElement('div',{className:'rest-ring',style:{background:`conic-gradient(var(--accent) ${pct}%, var(--track) 0)`}},
        React.createElement(Icon,{name:'timer',size:16,color:'var(--accent)'})),
      React.createElement('div',{className:'col',style:{lineHeight:1.05}},
        React.createElement('div',{className:'tiny muted',style:{fontWeight:700,fontSize:'10px'}},'REST'),
        React.createElement('div',{className:'stat-num',style:{fontSize:'18px'}},fmt(rest.left))),
      React.createElement('button',{className:'rest-mini',onClick:()=>setRest(r=>({...r,left:r.left+15}))},'+15'),
      React.createElement('button',{className:'rest-mini',onClick:()=>setRest(r=>({...r,running:!r.running}))},
        React.createElement(Icon,{name:rest.running?'pause':'play',size:14})),
      React.createElement('button',{className:'rest-mini',onClick:()=>setRest(r=>({...r,active:false}))},
        React.createElement(Icon,{name:'x',size:14}))
    );
  }

  // ---- CELEBRATION ----
  function celebEl(){ if(!celeb)return null;
    return React.createElement('div',{className:'celeb'},
      React.createElement('div',{className:'celeb-card'},
        React.createElement('div',{style:{fontSize:'46px'}},celeb.emoji),
        React.createElement('div',{style:{fontWeight:800,fontSize:'20px',marginTop:'4px'}},celeb.title),
        React.createElement('div',{className:'tiny muted',style:{marginTop:'4px',maxWidth:'220px',lineHeight:1.4}},celeb.msg)));
  }

  // ---- MODALS ----

  const muscleColor=(m)=>{
    if(!m) return 'var(--text-2)';
    const ml=m.toLowerCase();
    if(ml.includes('chest')) return 'var(--accent)';
    if(ml.includes('back')||ml.includes('bicep')||ml.includes('pull')) return 'var(--blue)';
    if(ml.includes('delt')||ml.includes('shoulder')) return 'var(--purple)';
    if(ml.includes('tricep')) return 'var(--green)';
    if(ml.includes('leg')||ml.includes('glute')||ml.includes('hamstring')) return 'var(--red)';
    return 'var(--text-2)';
  };
  const muscleInitial=(m)=>(m||'?').split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase();

  function sheet(title, body, max){
    return React.createElement('div',{className:'sheet'},
      React.createElement('div',{className:'scrim',onClick:()=>setModal(null)}),
      React.createElement('div',{className:'sheet-card',style:{maxHeight:max||'70%'}},
        React.createElement('div',{className:'grabber'}),
        title&&React.createElement('div',{className:'between pad',style:{paddingBottom:'8px'}},
          React.createElement('div',{className:'nav-title'},title),
          React.createElement('button',{className:'nav-icon-btn',onClick:()=>setModal(null)},React.createElement(Icon,{name:'x',size:18}))),
        React.createElement('div',{className:'pad',style:{overflow:'auto',paddingBottom:'26px'}},body)));
  }
  function modalEl(){
    if(!modal) return null;
    if(modal.kind==='type'){
      const applyType = modal.onSetType || ((si,type)=>{mutate(w=>{w.exercises[idx].sets[si].type=type;});setModal(null);});
      return sheet('Set type', React.createElement('div',{className:'list'},
        Object.entries(SET_TYPES).filter(([k])=>k!=='warmup').map(([k,v])=>
          React.createElement('button',{key:k,className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick:()=>applyType(modal.setIdx,k)},
            React.createElement('div',{className:'row-ic',style:{background:v.color,width:'28px',height:'28px',fontSize:'12px',fontWeight:800}},v.short||'N'),
            React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title'},v.label)),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})))), '58%');
    }
    if(modal.kind==='menu'){
      const ei=modal.exIdx; const me=wk.exercises[ei];
      const isSSed=me&&(me.superset===true||(ei>0&&wk.exercises[ei-1].superset===true));
      return sheet(null, React.createElement('div',null,
        React.createElement('div',{className:'list'},
          row('swap','var(--blue)','Substitute exercise',()=>setModal({kind:'sub',exIdx:ei})),
          row('bolt','var(--accent)',isSSed?'Remove Superset Pairing':'Create Superset…',()=>{
            if(isSSed) setModal({kind:'remove-ss',exIdx:ei});
            else setModal({kind:'ss-pick',exIdx:ei});
          }),
          row('plus-c','var(--green)','Add exercise after',()=>setModal({kind:'add'}))),
        React.createElement('div',{className:'list',style:{marginTop:'12px'}},
          row('trash','var(--red)','Remove exercise',()=>removeEx(ei),'var(--red)')),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'12px'},onClick:()=>setModal(null)},'Cancel')), '64%');
    }
    if(modal.kind==='sub'){
      const ei=modal.exIdx; const cur=wk.exercises[ei];
      return sheet(null, React.createElement('div',null,
        React.createElement('div',{className:'center',style:{margin:'4px 0 12px'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'15px'}},'Substitute Exercise'),
          React.createElement('div',{className:'tiny muted',style:{marginTop:3}},`Replacing: ${cur?cur.name:''}`)),
        React.createElement('div',{className:'list'},
          SUB_OPTIONS.map((o,i)=>React.createElement('button',{key:i,className:'row',
            style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},
            onClick:()=>substitute(o)},
            React.createElement('div',{className:'row-ic',style:{background:muscleColor(o.muscle)}},
              React.createElement('span',{style:{fontSize:'10px',fontWeight:800,color:'#fff'}},muscleInitial(o.muscle))),
            React.createElement('div',{className:'row-main'},
              React.createElement('div',{className:'row-title'},o.name),
              React.createElement('div',{className:'row-sub'},`${o.muscle} · ${o.equipment}`)),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})))
        ),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'12px'},onClick:()=>setModal(null)},'Cancel')), '72%');
    }
    if(modal.kind==='add'||modal.kind==='add-for-ss'){
      const forSS=modal.kind==='add-for-ss';
      return sheet(null, React.createElement('div',null,
        React.createElement('div',{className:'center',style:{margin:'4px 0 12px'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'15px'}},forSS?'Add Exercise to Superset':'Add Exercise'),
          React.createElement('div',{className:'tiny muted',style:{marginTop:3}},forSS?'Position in list determines A/B order':'Added to end of workout')),
        React.createElement('div',{className:'search-box',style:{marginBottom:'12px'}},
          React.createElement(Icon,{name:'search',size:17,color:'var(--text-3)'}),
          React.createElement('input',{placeholder:'Search exercise library…',autoFocus:true})),
        React.createElement('div',{className:'tiny muted',style:{margin:'0 4px 8px',fontWeight:700,letterSpacing:'.05em',textTransform:'uppercase',fontSize:'11px'}},'Suggested'),
        React.createElement('div',{className:'list'},
          ADD_OPTIONS.map((o,i)=>React.createElement('button',{key:i,className:'row',
            style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},
            onClick:()=>{ addEx(o); if(forSS&&modal.exIdx!=null) setTimeout(()=>{ mutate(w=>{ const last=w.exercises.length-1; const src=modal.exIdx; w.exercises.forEach(e=>e.superset=false); const moved=w.exercises.splice(last,1)[0]; w.exercises.splice(src+1,0,moved); w.exercises[src].superset=true; }); },0); }},
            React.createElement('div',{className:'row-ic',style:{background:muscleColor(o.muscle)}},
              React.createElement('span',{style:{fontSize:'10px',fontWeight:800,color:'#fff'}},muscleInitial(o.muscle))),
            React.createElement('div',{className:'row-main'},
              React.createElement('div',{className:'row-title'},o.name),
              React.createElement('div',{className:'row-sub'},`${o.muscle} · ${o.equipment}`)),
            React.createElement(Icon,{name:'plus-c',size:20,color:'var(--accent)'})))
        ),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'12px'},onClick:()=>setModal(null)},'Cancel')), '78%');
    }
    if(modal.kind==='end'){
      return sheet(null, React.createElement('div',null,
        React.createElement('div',{className:'center',style:{margin:'4px 0 16px'}},
          React.createElement('div',{style:{fontWeight:800,fontSize:'18px'}},'End this workout?'),
          React.createElement('div',{className:'tiny muted',style:{marginTop:'4px'}},`${doneSets} of ${totalSets} sets completed · ${fmt(elapsed)}`)),
        React.createElement('button',{className:'btn btn-primary',onClick:()=>{setModal(null);setView('summary');}},'Finish & Save'),
        React.createElement('button',{className:'btn btn-danger',style:{marginTop:'10px'},onClick:()=>{setModal(null);resetAll();}},'Discard Workout'),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'10px'},onClick:()=>setModal(null)},'Continue Workout')), '52%');
    }
    if(modal.kind==='ex-menu-ov'){
      const ei=modal.exIdx; const e=wk.exercises[ei];
      const isSSed=e.superset===true||(ei>0&&wk.exercises[ei-1].superset===true);
      return sheet(null,React.createElement('div',null,
        React.createElement('div',{className:'center',style:{margin:'4px 0 14px'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'15px'}},e.name),
          React.createElement('div',{className:'tiny muted'},`Exercise ${ei+1} of ${wk.exercises.length}`)),
        React.createElement('div',{className:'list'},
          row('swap','var(--blue)','Substitute Exercise',()=>setModal({kind:'sub',exIdx:ei})),
          row('bolt','var(--accent)',isSSed?'Remove Superset Pairing':'Create Superset…',()=>{
            if(isSSed) setModal({kind:'remove-ss',exIdx:ei});
            else setModal({kind:'ss-pick',exIdx:ei});
          }),
          row('plus-c','var(--green)','Add Exercise After',()=>setModal({kind:'add'}))),
        React.createElement('div',{className:'list',style:{marginTop:'12px'}},
          row('trash','var(--red)','Remove Exercise',()=>removeEx(ei),'var(--red)')),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'12px'},onClick:()=>setModal(null)},'Cancel')),'68%');
    }
    if(modal.kind==='ss-pick'){
      const ei=modal.exIdx; const src=wk.exercises[ei];
      const others=wk.exercises.map((e,i)=>({e,i})).filter(({i})=>i!==ei);
      return sheet('Create Superset', React.createElement('div',null,
        React.createElement('div',{style:{background:'var(--accent-soft)',borderRadius:'var(--r-md)',padding:'10px 12px',marginBottom:'14px',display:'flex',alignItems:'center',gap:'10px'}},
          React.createElement('span',{style:{width:26,height:26,borderRadius:6,background:'var(--accent)',color:'#fff',fontSize:11,fontWeight:800,display:'grid',placeItems:'center',flexShrink:0}},'A'),
          React.createElement('span',{style:{fontWeight:700,fontSize:'14px'}},''+src.name)
        ),
        React.createElement('div',{className:'tiny muted',style:{margin:'0 4px 10px',fontWeight:700,letterSpacing:'.04em',textTransform:'uppercase',fontSize:'11px'}},'Pair with (B)'),
        React.createElement('div',{className:'list'},
          ...others.map(({e,i})=>React.createElement('button',{key:e.id,className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},
            onClick:()=>createSuperset(ei,i)},
            React.createElement('div',{className:'row-ic',style:{background:'var(--blue)',width:26,height:26,borderRadius:6,fontSize:11,fontWeight:800}},'B'),
            React.createElement('div',{className:'row-main'},
              React.createElement('div',{className:'row-title'},e.name),
              React.createElement('div',{className:'row-sub'},e.equipment+' · '+e.repRange+' reps')),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})))
        ),
        React.createElement('div',{className:'tiny muted',style:{margin:'14px 4px 8px',fontWeight:700,letterSpacing:'.04em',textTransform:'uppercase',fontSize:'11px'}},'Or add new'),
        React.createElement('button',{className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick:()=>setModal({kind:'add-for-ss',exIdx:ei})},
          React.createElement('div',{className:'row-ic',style:{background:'var(--green)'}},React.createElement(Icon,{name:'plus-c',size:17})),
          React.createElement('div',{className:'row-main'},
            React.createElement('div',{className:'row-title'},'Add new exercise'),
            React.createElement('div',{className:'row-sub'},'Pick from library — position in list sets A/B order')),
          React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
        ),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'12px'},onClick:()=>setModal(null)},'Cancel')), '82%');
    }
    if(modal.kind==='remove-ss'){
      const ei=modal.exIdx;
      const exA=wk.exercises[ei]; 
      const exB=wk.exercises[ei+1];
      return sheet(null, React.createElement('div',null,
        React.createElement('div',{className:'center',style:{margin:'4px 0 16px'}},
          React.createElement('div',{style:{width:48,height:48,borderRadius:'50%',background:'color-mix(in oklab,var(--red) 12%,transparent)',display:'grid',placeItems:'center',color:'var(--red)',margin:'0 auto 12px'}},
            React.createElement(Icon,{name:'bolt',size:24})),
          React.createElement('div',{style:{fontWeight:800,fontSize:'17px',letterSpacing:'-.01em'}},'Remove Superset?'),
          React.createElement('div',{className:'tiny muted',style:{marginTop:6,lineHeight:1.6,maxWidth:260,margin:'6px auto 0'}},'This will split the pair into two individual exercises. All logged sets and weights are kept.')
        ),
        React.createElement('div',{className:'card',style:{padding:'12px 14px',marginBottom:'14px',display:'flex',gap:'10px',alignItems:'center'}},
          React.createElement('div',{style:{display:'flex',flexDirection:'column',gap:'8px',flex:1}},
            React.createElement('div',{style:{display:'flex',alignItems:'center',gap:'7px'}},
              React.createElement('span',{style:{width:18,height:18,borderRadius:4,background:'var(--accent)',color:'#fff',fontSize:9,fontWeight:800,display:'grid',placeItems:'center',flexShrink:0}},'A'),
              React.createElement('span',{style:{fontWeight:600,fontSize:'13px',flex:1}},exA&&exA.name),
              exA&&React.createElement('span',{className:'badge',style:{background:'color-mix(in oklab,var(--green) 12%,transparent)',color:'var(--green)',fontSize:'11px',fontWeight:700}},
                `${exA.sets.filter(s=>s.done).length}/${exA.sets.length} sets logged`)
            ),
            React.createElement('div',{style:{display:'flex',alignItems:'center',gap:'7px'}},
              React.createElement('span',{style:{width:18,height:18,borderRadius:4,background:'var(--blue)',color:'#fff',fontSize:9,fontWeight:800,display:'grid',placeItems:'center',flexShrink:0}},'B'),
              React.createElement('span',{style:{fontWeight:600,fontSize:'13px',flex:1}},exB&&exB.name),
              exB&&React.createElement('span',{className:'badge',style:{background:'color-mix(in oklab,var(--green) 12%,transparent)',color:'var(--green)',fontSize:'11px',fontWeight:700}},
                `${exB.sets.filter(s=>s.done).length}/${exB.sets.length} sets logged`)
            )
          )
        ),
        React.createElement('button',{className:'btn btn-danger',onClick:()=>{
          mutate(w=>{w.exercises.forEach(ex=>{ex.superset=false;});});
          setCeleb({emoji:'✂️',title:'Superset split',msg:'Both exercises continue as individual items.'});
          setModal(null);
          if(view==='superset') setView('overview');
        }},'Split into individual exercises'),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:'10px'},onClick:()=>setModal(null)},'Keep superset')
      ),'54%');
    }
    return null;
  }
  function row(ic,color,label,onClick,textColor){
    return React.createElement('button',{className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick},
      React.createElement('div',{className:'row-ic',style:{background:color}},React.createElement(Icon,{name:ic,size:17})),
      React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title',style:{color:textColor||'var(--text)'}},label)));
  }

  function resetAll(){ localStorage.removeItem('aura_wk'); localStorage.removeItem('aura_elapsed');
    if(props.onExit){ props.onExit(); return; }
    setWk(clone(WORKOUT)); setElapsed(0); setView('overview'); setIdx(0); setRest({active:false,total:60,left:60,running:true}); }

  // ---- SUMMARY ----
  function summaryEl(){
    const prs=wk.exercises.filter(e=>e.sets.some(s=>num(s.weight)>e.lastPR.weight)).length;
    return React.createElement('div',{className:'phone','data-theme':'light'},
      React.createElement('div',{className:'dynamic-island'}),
      React.createElement('div',{className:'statusbar auto'}),
      React.createElement('div',{className:'screen-body',style:{paddingBottom:'24px'}},
        React.createElement('div',{className:'summary-hero'},
          React.createElement('div',{style:{fontSize:'46px'}},'\uD83D\uDD25'),
          React.createElement('div',{style:{fontWeight:800,fontSize:'26px',letterSpacing:'-.02em',marginTop:'6px'}},'Workout Complete'),
          React.createElement('div',{className:'tiny',style:{opacity:.85,marginTop:'4px'}},`${wk.name} · ${wk.program}`)),
        React.createElement('div',{className:'pad',style:{marginTop:'-26px'}},
          React.createElement('div',{className:'card card-pad',style:{borderRadius:'var(--r-xl)'}},
            React.createElement('div',{className:'sum-grid'},
              stat(fmt(elapsed),'Duration'),stat(doneSets,'Sets'),
              stat(Math.round(volume).toLocaleString(),'Volume (kg)'),stat(prs,'New PRs'))),
          prs>0&&React.createElement('div',{className:'hint-card',style:{marginTop:'14px',background:'var(--accent-soft)',border:'1px solid var(--accent)'}},
            React.createElement(Icon,{name:'trophy',size:20,color:'var(--accent)'}),
            React.createElement('div',null,React.createElement('div',{style:{fontWeight:700,fontSize:'14px'}},`${prs} new personal record${prs>1?'s':''}!`),
              React.createElement('div',{className:'tiny muted'},'Logged to your Progress tab.'))),
          React.createElement('div',{className:'sec-label'},'Exercises'),
          React.createElement('div',{className:'list'},
            wk.exercises.map((e,i)=>{const d=e.sets.filter(s=>s.done).length;
              return React.createElement('div',{key:i,className:'row'},
                React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title',style:{fontWeight:600}},e.name),
                  React.createElement('div',{className:'row-sub'},`${d} sets · ${Math.round(e.sets.filter(s=>s.done).reduce((b,s)=>b+num(s.weight)*num(s.reps),0)).toLocaleString()} kg`)),
                React.createElement(Icon,{name:'check-c',size:20,color:'var(--green)'}));})),
          React.createElement('div',{className:'sec-label'},'Session notes'),
          React.createElement('textarea',{className:'notes-area',placeholder:'How did it feel? Anything to remember for next time…'}),
          React.createElement('button',{className:'btn btn-primary',style:{marginTop:'16px'},onClick:resetAll},'Save Workout'),
          React.createElement('button',{className:'btn btn-gray',style:{marginTop:'10px'},onClick:()=>setView('overview')},'Back to workout')
        )),
      React.createElement('div',{className:'home-indicator'}));
  }
  function stat(v,l){ return React.createElement('div',{className:'sum-stat'},
    React.createElement('div',{className:'stat-num',style:{fontSize:'24px'}},v),
    React.createElement('div',{className:'tiny muted',style:{marginTop:'2px'}},l)); }

  return React.createElement(React.Fragment,null, overview(), restPill(), modalEl(), celebEl(), tweaksEl());
}
window.WorkoutApp = App;
if (!window.__AURA_EMBED) ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(App));
})();
