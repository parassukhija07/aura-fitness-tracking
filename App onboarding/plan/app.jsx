/* Plan Tab — interactive prototype */
(function(){
const { useState, useRef, useEffect } = React;
const clone = o => JSON.parse(JSON.stringify(o));
const DAYS = ['MON','TUE','WED','THU','FRI','SAT','SUN'];

function WorkoutById(id) { return PLAN_WORKOUTS.find(w => w.id === id) || null; }

/* ── Sheet wrapper ─────────────────────────────────────────────── */
function Sheet({ onClose, height, title, subtitle, children }) {
  return React.createElement('div', { className:'sheet' },
    React.createElement('div', { className:'scrim', onClick: onClose }),
    React.createElement('div', { className:'sheet-card', style:{ maxHeight: height || '72%' } },
      React.createElement('div', { className:'grabber' }),
      title && React.createElement('div', { className:'between pad', style:{ paddingBottom:8 } },
        React.createElement('div', null,
          React.createElement('div', { style:{ fontWeight:700, fontSize:'15px' } }, title),
          subtitle && React.createElement('div', { className:'tiny muted', style:{ marginTop:2 } }, subtitle)
        ),
        React.createElement('button', { className:'nav-icon-btn', onClick: onClose },
          React.createElement(Icon, { name:'x', size:18 }))
      ),
      React.createElement('div', { style:{ overflowY:'auto', padding:'0 14px 28px' } }, children)
    )
  );
}

/* ── Row helper ─────────────────────────────────────────────────── */
function Row({ icon, color, label, sub, onTap, textColor, chevron=true }) {
  return React.createElement('button', {
    className:'row', style:{ width:'100%', background:'var(--surface)', border:0, textAlign:'left' }, onClick: onTap },
    React.createElement('div', { className:'row-ic', style:{ background: color } },
      React.createElement(Icon, { name: icon, size:17 })),
    React.createElement('div', { className:'row-main' },
      React.createElement('div', { className:'row-title', style:{ color: textColor || 'var(--text)' } }, label),
      sub && React.createElement('div', { className:'row-sub' }, sub)
    ),
    chevron && React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
  );
}

/* ── Workout picker (assign sheet) ─────────────────────────────── */
function AssignSheet({ day, current, workouts, onAssign, onRest, onClose }) {
  return React.createElement(Sheet, { onClose, title:`Assign to ${day}`, subtitle:'Choose from workouts in this program', height:'74%' },
    React.createElement('div', { className:'col', style:{ gap:8 } },
      workouts.map(w =>
        React.createElement('button', { key: w.id,
          className:'card card-pad',
          style:{ width:'100%', border: current===w.id ? '1.5px solid var(--accent)' : '', background: current===w.id ? 'var(--accent-soft)' : '', textAlign:'left', cursor:'pointer' },
          onClick: () => onAssign(w.id) },
          React.createElement('div', { className:'between' },
            React.createElement('div', null,
              React.createElement('div', { style:{ fontWeight:700, fontSize:'15px', color: current===w.id ? 'var(--accent)' : '' } }, w.name),
              React.createElement('div', { className:'tiny muted', style:{ marginTop:2 } }, `${w.exCount} ex · ${w.muscles}`)
            ),
            current === w.id
              ? React.createElement(Icon, { name:'check-c', size:20, color:'var(--accent)' })
              : React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
          )
        )
      )
    ),
    React.createElement('div', { className:'divider', style:{ margin:'14px 0' } }),
    React.createElement('button', { className:'src-card', onClick: onClose },
      React.createElement('div', { className:'src-ic', style:{ background:'var(--accent-soft)', color:'var(--accent)' } },
        React.createElement(Icon, { name:'plus-c', size:22 })),
      React.createElement('div', { className:'grow', style:{ textAlign:'left' } },
        React.createElement('div', { className:'src-t' }, 'Create new workout'),
        React.createElement('div', { className:'src-s' }, 'Build from scratch and add to program')),
      React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
    ),
    React.createElement('button', { className:'btn btn-gray', style:{ marginTop:10 }, onClick: onRest }, 'Keep as Rest Day')
  );
}

/* ── Day menu sheet ────────────────────────────────────────────── */
function DayMenuSheet({ day, workout, onEdit, onChange, onRest, onRemove, onClose }) {
  return React.createElement(Sheet, { onClose, height:'56%' },
    React.createElement('div', { className:'center', style:{ margin:'4px 0 14px' } },
      React.createElement('div', { style:{ fontWeight:700, fontSize:'15px' } }, day),
      React.createElement('div', { className:'tiny muted' }, workout ? workout.name : 'Rest Day')
    ),
    React.createElement('div', { className:'list' },
      Row({ icon:'edit',  color:'var(--accent)', label:'Edit workout',   sub:'Change exercises, sets or order', onTap: onEdit }),
      Row({ icon:'swap',  color:'var(--blue)',   label:'Change workout', sub:`Assign a different workout to ${day}`, onTap: onChange }),
      Row({ icon:'moon',  color:'color-mix(in oklab,var(--text-2) 25%,var(--fill))', label:'Make it a rest day', onTap: onRest, chevron:false })
    ),
    React.createElement('div', { className:'list', style:{ marginTop:12 } },
      Row({ icon:'trash', color:'var(--red)', label:'Remove from program', onTap: onRemove, textColor:'var(--red)', chevron:false })
    ),
    React.createElement('button', { className:'btn btn-gray', style:{ marginTop:12 }, onClick: onClose }, 'Cancel')
  );
}

/* ── Add Plan sheet ────────────────────────────────────────────── */
function AddPlanSheet({ onClose, onPrograms, onBuildFromScratch }) {
  return React.createElement(Sheet, { onClose, height:'58%' },
    React.createElement('div', { className:'center', style:{ margin:'4px 0 16px' } },
      React.createElement('div', { style:{ fontWeight:800, fontSize:'17px' } }, 'Add to My Plans'),
      React.createElement('div', { className:'tiny muted', style:{ marginTop:3 } }, 'Pick a program or build your own')
    ),
    React.createElement('div', { className:'col', style:{ gap:10 } },
      React.createElement('button', { className:'src-card', onClick: () => { onClose(); onPrograms && onPrograms(); } },
        React.createElement('div', { className:'src-ic', style:{ background:'var(--accent-soft)', color:'var(--accent)' } }, React.createElement(Icon, { name:'sparkle', size:22 })),
        React.createElement('div', { className:'grow', style:{ textAlign:'left' } },
          React.createElement('div', { className:'src-t' }, 'Browse programs'),
          React.createElement('div', { className:'src-s' }, 'PPL, Upper/Lower, Full Body and more')),
        React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
      ),
      React.createElement('button', { className:'src-card', onClick: () => { onClose(); onBuildFromScratch && onBuildFromScratch(); } },
        React.createElement('div', { className:'src-ic', style:{ background:'color-mix(in oklab,var(--blue) 14%,transparent)', color:'var(--blue)' } }, React.createElement(Icon, { name:'dumbbell', size:22 })),
        React.createElement('div', { className:'grow', style:{ textAlign:'left' } },
          React.createElement('div', { className:'src-t' }, 'Build from scratch'),
          React.createElement('div', { className:'src-s' }, 'Create a custom weekly program')),
        React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
      ),
      React.createElement('button', { className:'src-card', onClick: onClose },
        React.createElement('div', { className:'src-ic', style:{ background:'color-mix(in oklab,var(--green) 14%,transparent)', color:'var(--green)' } }, React.createElement(Icon, { name:'note', size:22 })),
        React.createElement('div', { className:'grow', style:{ textAlign:'left' } },
          React.createElement('div', { className:'src-t' }, 'Duplicate active plan'),
          React.createElement('div', { className:'src-s' }, 'Copy Push Pull Legs and tweak it')),
        React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
      )
    ),
    React.createElement('button', { className:'btn btn-gray', style:{ marginTop:14 }, onClick: onClose }, 'Cancel')
  );
}

/* ── Workout seed data ───────────────────────────────────────── */
const WK_SEEDS = {
  'push-a':[{id:'pa1',name:'Barbell Bench Press',sets:4,reps:'6\u20138',superset:false},{id:'pa2',name:'Incline DB Press',sets:3,reps:'8\u201310',superset:false},{id:'pa3',name:'Cable Fly',sets:3,reps:'12\u201315',superset:false},{id:'pa4',name:'Overhead Press',sets:3,reps:'8\u201310',superset:false},{id:'pa5',name:'Lateral Raise',sets:4,reps:'12\u201315',superset:false},{id:'pa6',name:'Tricep Pushdown',sets:3,reps:'12\u201315',superset:false}],
  'pull-a':[{id:'pl1',name:'Barbell Row',sets:4,reps:'6\u20138',superset:false},{id:'pl2',name:'Pull-ups',sets:3,reps:'6\u201310',superset:false},{id:'pl3',name:'Cable Row',sets:3,reps:'10\u201312',superset:false},{id:'pl4',name:'Face Pull',sets:3,reps:'15\u201320',superset:false},{id:'pl5',name:'Barbell Curl',sets:3,reps:'8\u201312',superset:false},{id:'pl6',name:'Hammer Curl',sets:3,reps:'10\u201312',superset:false}],
  'leg-a': [{id:'le1',name:'Barbell Squat',sets:4,reps:'6\u20138',superset:false},{id:'le2',name:'Leg Press',sets:3,reps:'10\u201312',superset:false},{id:'le3',name:'Romanian Deadlift',sets:3,reps:'8\u201310',superset:false},{id:'le4',name:'Leg Curl',sets:3,reps:'12\u201315',superset:false},{id:'le5',name:'Leg Extension',sets:3,reps:'15\u201320',superset:false}],
  'push-b':[{id:'pb1',name:'Overhead Press',sets:4,reps:'6\u20138',superset:false},{id:'pb2',name:'DB Lateral Raise',sets:4,reps:'12\u201315',superset:false},{id:'pb3',name:'Incline DB Press',sets:3,reps:'8\u201310',superset:false},{id:'pb4',name:'Cable Lateral Raise',sets:3,reps:'15\u201320',superset:false},{id:'pb5',name:'Skull Crushers',sets:3,reps:'10\u201312',superset:false},{id:'pb6',name:'Tricep Dips',sets:3,reps:'10\u201315',superset:false}],
};
const WK_ADD_OPTIONS = [
  {id:'ao1',name:'Barbell Bench Press',muscle:'Chest',equip:'Barbell'},
  {id:'ao2',name:'Incline DB Press',muscle:'Upper Chest',equip:'Dumbbell'},
  {id:'ao3',name:'Cable Fly',muscle:'Chest',equip:'Cable'},
  {id:'ao4',name:'Barbell Row',muscle:'Back',equip:'Barbell'},
  {id:'ao5',name:'Pull-ups',muscle:'Back',equip:'Bodyweight'},
  {id:'ao6',name:'Overhead Press',muscle:'Shoulders',equip:'Barbell'},
  {id:'ao7',name:'Lateral Raise',muscle:'Shoulders',equip:'Dumbbell'},
  {id:'ao8',name:'Squat',muscle:'Legs',equip:'Barbell'},
  {id:'ao9',name:'Romanian Deadlift',muscle:'Legs',equip:'Barbell'},
  {id:'ao10',name:'Barbell Curl',muscle:'Biceps',equip:'Barbell'},
  {id:'ao11',name:'Tricep Pushdown',muscle:'Triceps',equip:'Cable'},
];

/* ── Rest stepper card ───────────────────────────────────────── */
function RestPicker({ label, value, onChange }) {
  const STEPS=[15,30,45,60,75,90,120,150,180,240,300];
  const fmt=s=>s<60?`${s}s`:`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
  const idx=STEPS.indexOf(value);
  const dec=()=>idx>0&&onChange(STEPS[idx-1]);
  const inc=()=>idx<STEPS.length-1&&onChange(STEPS[idx+1]);
  return React.createElement('div',{style:{flex:1,background:'var(--surface)',border:'1px solid var(--separator-2)',borderRadius:'var(--r-lg)',padding:'13px 14px'}},
    React.createElement('div',{style:{fontSize:'11px',fontWeight:700,color:'var(--text-2)',letterSpacing:'.05em',textTransform:'uppercase',marginBottom:10}},label),
    React.createElement('div',{style:{display:'flex',alignItems:'center',gap:8}},
      React.createElement('button',{className:'nav-icon-btn',style:{width:34,height:34,flexShrink:0},onClick:dec},
        React.createElement(Icon,{name:'minus',size:17})),
      React.createElement('div',{style:{flex:1,textAlign:'center',fontSize:'26px',fontWeight:800,letterSpacing:'-.03em',color:'var(--accent)',fontVariantNumeric:'tabular-nums'}},fmt(value)),
      React.createElement('button',{className:'nav-icon-btn',style:{width:34,height:34,flexShrink:0,background:'var(--accent-soft)',color:'var(--accent)'},onClick:inc},
        React.createElement(Icon,{name:'plus',size:17}))
    ),
    React.createElement('div',{style:{display:'flex',justifyContent:'center',gap:4,marginTop:10}},
      STEPS.map(s=>React.createElement('div',{key:s,style:{width:s===value?14:5,height:4,borderRadius:999,background:s===value?'var(--accent)':'var(--separator-2)',transition:'width .2s'}}))
    )
  );
}

/* ── Exercise Picker (full-screen search + catalog) ─────────── */
function ExercisePicker({ mode, replacingName, pickerTitle, onSelect, onBack }) {
  const [query,setQuery]=useState('');
  const [mf,setMf]=useState('All');
  const [ef,setEf]=useState('All');
  const MUSCLES=['All','Chest','Back','Shoulders','Arms','Legs','Core'];
  const EQUIPS=['All','Barbell','Dumbbell','Cable','Machine','Bodyweight','Smith'];
  const THUMB={
    Chest:    {bg:'linear-gradient(145deg,oklch(0.90 0.07 58),oklch(0.84 0.11 52))',  tx:'oklch(0.46 0.18 54)'},
    Back:     {bg:'linear-gradient(145deg,oklch(0.90 0.05 248),oklch(0.84 0.09 244))',tx:'oklch(0.44 0.13 248)'},
    Shoulders:{bg:'linear-gradient(145deg,oklch(0.90 0.05 284),oklch(0.84 0.08 279))',tx:'oklch(0.44 0.12 283)'},
    Biceps:   {bg:'linear-gradient(145deg,oklch(0.90 0.06 151),oklch(0.84 0.10 147))',tx:'oklch(0.44 0.14 149)'},
    Triceps:  {bg:'linear-gradient(145deg,oklch(0.90 0.06 151),oklch(0.84 0.10 147))',tx:'oklch(0.44 0.14 149)'},
    Legs:     {bg:'linear-gradient(145deg,oklch(0.90 0.06 31),oklch(0.84 0.10 25))',  tx:'oklch(0.44 0.13 27)'},
    Core:     {bg:'linear-gradient(145deg,oklch(0.90 0.05 19),oklch(0.84 0.09 13))',  tx:'oklch(0.44 0.13 17)'},
  };
  const LABEL={Biceps:'Arms',Triceps:'Arms'};
  const filtered=PLAN_EXERCISES_LIB.filter(e=>{
    const q=query.trim().toLowerCase();
    const mq=!q||e.name.toLowerCase().includes(q)||e.muscle.toLowerCase().includes(q)||e.equip.toLowerCase().includes(q);
    const mm=mf==='All'||(mf==='Arms'?(e.muscle==='Biceps'||e.muscle==='Triceps'):e.muscle===mf);
    const me=ef==='All'||e.equip===ef;
    return mq&&mm&&me;
  });
  return React.createElement('div',{className:'phone','data-theme':'light'},
    React.createElement('div',{className:'dynamic-island'}),
    React.createElement('div',{className:'statusbar auto'}),
    React.createElement('div',{className:'navbar bordered'},
      React.createElement('div',{className:'navbar-row'},
        React.createElement('button',{className:'nav-btn',onClick:onBack},
          React.createElement(Icon,{name:'chevron-left',size:22}),'Back'),
        React.createElement('div',{className:'nav-title'},pickerTitle||(mode==='sub'?'Substitute':'Add Exercise'))
      ),
      React.createElement('div',{style:{padding:'2px 14px 10px'}},
        mode==='sub'&&replacingName&&React.createElement('div',{
          style:{fontSize:'12px',fontWeight:600,color:'var(--text-2)',marginBottom:7}
        },'Replacing\u00a0',React.createElement('b',{style:{color:'var(--text)'}},replacingName)),
        React.createElement('div',{className:'search'},
          React.createElement(Icon,{name:'search',size:18}),
          React.createElement('input',{
            placeholder:'Search exercises\u2026',
            value:query,
            onChange:ev=>setQuery(ev.target.value)
          })
        )
      )
    ),
    React.createElement('div',{style:{flex:'0 0 auto',borderBottom:'1px solid var(--separator-2)'}},
      React.createElement('div',{className:'filters',style:{padding:'6px 14px 2px'}},
        MUSCLES.map(m=>React.createElement('button',{key:m,className:'chip'+(mf===m?' active':''),onClick:()=>setMf(m)},m))
      ),
      React.createElement('div',{className:'filters',style:{padding:'4px 14px 10px'}},
        EQUIPS.map(eq=>React.createElement('button',{key:eq,className:'chip'+(ef===eq?' active':''),onClick:()=>setEf(eq)},eq))
      )
    ),
    React.createElement('div',{className:'screen-body pad',style:{paddingTop:12,paddingBottom:28}},
      filtered.length===0
        ?React.createElement('div',{style:{textAlign:'center',padding:'52px 0',color:'var(--text-3)'}},
            React.createElement('div',{style:{fontWeight:700,fontSize:'16px',marginBottom:4}},'No exercises found'),
            React.createElement('div',{style:{fontSize:'13px'}},'Try a different filter or search term')
          )
        :React.createElement('div',{className:'catalog'},
            filtered.map(e=>{
              const th=THUMB[e.muscle]||{bg:'var(--fill)',tx:'var(--text-3)'};
              return React.createElement('button',{
                key:e.id,className:'cat-item',
                style:{border:0,textAlign:'left',cursor:'pointer'},
                onClick:()=>onSelect(e)
              },
                React.createElement('div',{className:'cat-thumb',style:{
                  background:th.bg,
                  display:'flex',alignItems:'center',justifyContent:'center'
                }},
                  React.createElement('span',{style:{
                    fontSize:'10px',fontWeight:800,color:th.tx,
                    letterSpacing:'.07em',textTransform:'uppercase',
                    textAlign:'center',padding:'0 6px',lineHeight:1.25
                  }},LABEL[e.muscle]||e.muscle)
                ),
                React.createElement('div',{className:'cat-name'},e.name),
                React.createElement('div',{className:'cat-meta'},e.muscle+' \u00b7 '+e.equip)
              );
            })
          )
    ),
    React.createElement('div',{className:'home-indicator'})
  );
}

/* ── Workout Editor ──────────────────────────────────────────── */
function WorkoutEditorView({ workout, onBack }) {
  const [wkName,setWkName]=useState(workout.name);
  const [restSets,setRestSets]=useState(60);
  const [restEx,setRestEx]=useState(90);
  const [exercises,setExercises]=useState(()=>clone(WK_SEEDS[workout.id]||WK_SEEDS['push-a']));
  const [modal,setModal]=useState(null);
  const [dragIdx,setDragIdx]=useState(null);
  const [picker,setPicker]=useState(null);
  const [exDetail,setExDetail]=useState(null);
  const lookupEx=name=>PLAN_EXERCISES_LIB.find(e=>e.name===name)||{id:'x',name,muscle:'Unknown',equip:'Unknown'};

  const mutEx=fn=>setExercises(exs=>{const a=clone(exs);fn(a);return a;});
  const removeEx=i=>{mutEx(a=>a.splice(i,1));setModal(null);};
  const addExAfter=(ai,opt)=>{mutEx(a=>a.splice(ai+1,0,{id:'e'+Date.now(),name:opt.name,sets:3,reps:'8\u201312',superset:false}));setModal(null);};
  const subEx=(i,opt)=>{mutEx(a=>{a[i].name=opt.name;});setModal(null);};
  const setSets=(i,v)=>mutEx(a=>{a[i].sets=v;});
  const setReps=(i,v)=>mutEx(a=>{a[i].reps=v;});
  const removeSuperset=()=>{mutEx(a=>a.forEach(e=>{e.superset=false;}));setModal(null);};
  const createSS=(src,tgt)=>{
    mutEx(a=>{
      a.forEach(e=>{e.superset=false;});
      const t=a.splice(tgt,1)[0];
      const ins=tgt>src?src+1:src;
      a.splice(ins,0,t);
      a[src<ins?src:ins].superset=true;
    });
    setModal(null);
  };
  const createSSWithNew=(src,opt)=>{
    mutEx(a=>{
      a.forEach(e=>{e.superset=false;});
      a.splice(src+1,0,{id:'e'+Date.now(),name:opt.name,sets:3,reps:'8–12',superset:false});
      a[src].superset=true;
    });
    setModal(null);
  };

  function rowBtn(ic,color,label,fn,textColor){
    return React.createElement('button',{className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick:fn},
      React.createElement('div',{className:'row-ic',style:{background:color}},React.createElement(Icon,{name:ic,size:17})),
      React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title',style:{color:textColor||'var(--text)'}},label)),
      React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
    );
  }

  function modalEl(){
    if(!modal) return null;
    if(modal.kind==='ex-menu'){
      const i=modal.idx; const ex=exercises[i];
      const isSSFirst=ex.superset===true;
      const isSSSecond=i>0&&exercises[i-1].superset===true;
      const isSSed=isSSFirst||isSSSecond;
      return React.createElement(Sheet,{onClose:()=>setModal(null),height:'70%'},
        React.createElement('div',{className:'center',style:{margin:'4px 0 12px'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'15px'}},ex.name)
        ),
        React.createElement('div',{className:'card card-pad',style:{marginBottom:10}},
          React.createElement('div',{className:'between'},
            React.createElement('div',{style:{fontWeight:600,fontSize:'14px'}},'Sets'),
            React.createElement('div',{style:{display:'flex',alignItems:'center',gap:10}},
              React.createElement('button',{className:'nav-icon-btn',style:{width:32,height:32},onClick:()=>setSets(i,Math.max(1,ex.sets-1))},React.createElement(Icon,{name:'minus',size:16})),
              React.createElement('div',{style:{fontWeight:800,fontSize:'17px',minWidth:24,textAlign:'center'}},ex.sets),
              React.createElement('button',{className:'nav-icon-btn',style:{width:32,height:32,background:'var(--accent-soft)',color:'var(--accent)'},onClick:()=>setSets(i,ex.sets+1)},React.createElement(Icon,{name:'plus',size:16}))
            )
          )
        ),
        React.createElement('div',{className:'card card-pad',style:{marginBottom:14}},
          React.createElement('div',{className:'between'},
            React.createElement('div',{style:{fontWeight:600,fontSize:'14px'}},'Rep range'),
            React.createElement('input',{value:ex.reps,onChange:e=>setReps(i,e.target.value),style:{width:80,background:'var(--fill)',border:'1px solid var(--separator-2)',borderRadius:'var(--r-sm)',padding:'6px 10px',fontFamily:'var(--font)',fontSize:'15px',fontWeight:700,color:'var(--text)',textAlign:'center',outline:'none'}})
          )
        ),
        React.createElement('div',{className:'list'},
          rowBtn('swap','var(--blue)','Substitute exercise',()=>{setPicker({mode:'sub',idx:i});setModal(null);}),

          rowBtn('bolt','var(--accent)',isSSed?'Remove Superset':'Create Superset\u2026',()=>isSSed?removeSuperset():setModal({kind:'ss-pick',idx:i})),
          rowBtn('plus-c','var(--green)','Add exercise after',()=>{setPicker({mode:'add',afterIdx:i});setModal(null);})
        ),
        React.createElement('div',{className:'list',style:{marginTop:12}},
          rowBtn('trash','var(--red)','Remove exercise',()=>removeEx(i),'var(--red)')
        ),
        React.createElement('button',{className:'btn btn-gray',style:{marginTop:12},onClick:()=>setModal(null)},'Cancel')
      );
    }


    if(modal.kind==='ss-pick'){
      const src=modal.idx; const srcEx=exercises[src];
      return React.createElement(Sheet,{onClose:()=>setModal(null),title:'Create Superset',height:'78%'},
        React.createElement('div',{style:{background:'var(--accent-soft)',borderRadius:'var(--r-md)',padding:'10px 12px',marginBottom:14,display:'flex',alignItems:'center',gap:10}},
          React.createElement('span',{style:{width:24,height:24,borderRadius:6,background:'var(--accent)',color:'#fff',fontSize:10,fontWeight:800,display:'grid',placeItems:'center',flexShrink:0}},'A'),
          React.createElement('span',{style:{fontWeight:700,fontSize:'14px'}},srcEx.name)
        ),
        React.createElement('button',{className:'src-card',style:{marginBottom:14},onClick:()=>{setPicker({mode:'ss-new',idx:src});setModal(null);}},
          React.createElement('div',{className:'src-ic',style:{background:'color-mix(in oklab,var(--blue) 14%,transparent)',color:'var(--blue)'}},React.createElement(Icon,{name:'search',size:22})),
          React.createElement('div',{className:'grow',style:{textAlign:'left'}},
            React.createElement('div',{className:'src-t'},'Pick from library'),
            React.createElement('div',{className:'src-s'},'Browse 50+ exercises')),
          React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
        ),
        React.createElement('div',{className:'tiny muted',style:{margin:'0 4px 10px',fontWeight:700,letterSpacing:'.04em',textTransform:'uppercase',fontSize:'11px'}},'Or pair with existing'),
        React.createElement('div',{className:'list',style:{marginBottom:12}},
          exercises.map((e,i)=>i===src?null:React.createElement('button',{key:e.id,className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left'},onClick:()=>createSS(src,i)},
            React.createElement('div',{className:'row-ic',style:{background:'var(--blue)',width:26,height:26,borderRadius:6,fontSize:10,fontWeight:800}},'B'),
            React.createElement('div',{className:'row-main'},React.createElement('div',{className:'row-title'},e.name),React.createElement('div',{className:'row-sub'},`${e.sets} sets \u00b7 ${e.reps} reps`)),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          ))
        ),
        React.createElement('button',{className:'btn btn-gray',onClick:()=>setModal(null)},'Cancel')
      );
    }
    return null;
  }

  if(exDetail) return React.createElement(ExerciseDetail,{
    exercise:exDetail.exercise||exDetail,
    workoutCtx:exDetail.ctx,
    onSave:(newSets,newReps,newRest)=>{
      if(exDetail.idx!=null){setSets(exDetail.idx,newSets);setReps(exDetail.idx,newReps);}
      setRestSets(newRest);
      setExDetail(null);
    },
    onBack:()=>setExDetail(null)
  });
  if(picker) return React.createElement(ExercisePicker,{
    mode:picker.mode==='ss-new'?'add':picker.mode,
    replacingName:picker.mode==='sub'?exercises[picker.idx].name:null,
    pickerTitle:picker.mode==='ss-new'?'Pick Exercise B':null,
    onSelect:ex=>{
      if(picker.mode==='sub') subEx(picker.idx,ex);
      else if(picker.mode==='ss-new') createSSWithNew(picker.idx,ex);
      else addExAfter(picker.afterIdx!=null?picker.afterIdx:exercises.length-1,ex);
      setPicker(null);
    },
    onBack:()=>setPicker(null)
  });

  return React.createElement('div', { className:'phone', 'data-theme':'light' },
    React.createElement('div', { className:'dynamic-island' }),
    React.createElement('div', { className:'statusbar auto' }),
    React.createElement('div', { className:'navbar bordered' },
      React.createElement('div', { className:'navbar-row' },
        React.createElement('button', { className:'nav-btn', onClick: onBack },
          React.createElement(Icon, { name:'chevron-left', size:22 })),
        React.createElement('div', { className:'nav-title' }, wkName),
        React.createElement('button', { className:'nav-btn', style:{ fontWeight:700, color:'var(--accent)' }, onClick: onBack }, 'Save')
      )
    ),
    React.createElement('div', { className:'screen-body pad pad-b' },
      React.createElement('div', { className:'field', style:{ marginTop:14 } },
        React.createElement('label', null, 'Workout name'),
        React.createElement('input', { value:wkName, onChange:e=>setWkName(e.target.value) })
      ),
      React.createElement('div', { style:{ display:'flex', gap:14, marginBottom:4 } },
        React.createElement(RestPicker, { label:'Between sets', value:restSets, onChange:setRestSets }),
        React.createElement(RestPicker, { label:'After exercise', value:restEx, onChange:setRestEx })
      ),
      React.createElement('div', { className:'between', style:{ margin:'18px 4px 10px' } },
        React.createElement('div', { className:'sec-label', style:{ margin:0 } }, 'Exercises'),
        React.createElement('button', { className:'nav-icon-btn', style:{ width:28, height:28, background:'var(--accent-soft)', color:'var(--accent)' },
          onClick:() => setPicker({ mode:'add', afterIdx: exercises.length - 1 }) },
          React.createElement(Icon, { name:'plus', size:16 }))
      ),
      React.createElement('div', { style:{ display:'flex', flexDirection:'column', gap:8 } },
        exercises.flatMap((ex, i) => {
          const isSSFirst  = ex.superset === true;
          const isSSSecond = i > 0 && exercises[i-1].superset === true;
          const card = React.createElement('div', {
            key: ex.id, className:'card card-pad', draggable:true,
            style:{ display:'flex', alignItems:'center', gap:10,
              ...(isSSFirst||isSSSecond ? { borderColor:'color-mix(in oklab,var(--accent) 30%,transparent)' } : {}),
              ...(dragIdx !== null && dragIdx !== i ? { opacity:.5, borderStyle:'dashed' } : {}) },
            onDragStart: ev => { ev.dataTransfer.effectAllowed='move'; setDragIdx(i); },
            onDragOver:  ev => ev.preventDefault(),
            onDrop: ev => {
              ev.preventDefault();
              if (dragIdx === null || dragIdx === i) { setDragIdx(null); return; }
              setExercises(exs => {
                const a = [...exs];
                const [moved] = a.splice(dragIdx, 1);
                a.splice(dragIdx < i ? i - 1 : i, 0, moved);
                return a;
              });
              setDragIdx(null);
            },
            onDragEnd: () => setDragIdx(null),
          },
            React.createElement('span', { style:{ color:'var(--text-3)', flexShrink:0, display:'flex', alignItems:'center', cursor:'grab' } },
              React.createElement(Icon, { name:'grip', size:18 })),
            React.createElement('div', { style:{ flex:1, minWidth:0 } },
              React.createElement('button',{style:{fontWeight:700,fontSize:'15px',letterSpacing:'-.01em',background:'none',border:0,padding:0,cursor:'pointer',color:'var(--text)',textAlign:'left',fontFamily:'var(--font)'},onClick:e=>{e.stopPropagation();const libEx=lookupEx(ex.name);const isSSFirst=ex.superset===true;const isSSSecond=i>0&&exercises[i-1].superset===true;const isSuperset=isSSFirst||isSSSecond;const partnerEx=isSSFirst?exercises[i+1]:(isSSSecond?exercises[i-1]:null);setExDetail({exercise:libEx,idx:i,ctx:{sets:ex.sets,reps:ex.reps,restTime:restSets,isSuperset,ssRole:isSSFirst?'A':'B',partner:partnerEx?lookupEx(partnerEx.name):null}});}},ex.name),
              React.createElement('div', { style:{ display:'flex', gap:5, marginTop:6, flexWrap:'wrap' } },
                React.createElement('span', { className:'chip', style:{ padding:'4px 10px', fontSize:'12px' } }, `${ex.sets} sets`),
                React.createElement('span', { className:'chip', style:{ padding:'4px 10px', fontSize:'12px' } }, `${ex.reps} reps`),
                isSSFirst && React.createElement('span', { className:'badge badge-accent', style:{ fontSize:'10px', padding:'2px 7px' } },
                  React.createElement(Icon, { name:'bolt', size:10 }), ' SS')
              )
            ),
            React.createElement('button', { className:'nav-icon-btn', style:{ flexShrink:0 }, onClick:() => setModal({ kind:'ex-menu', idx:i }) },
              React.createElement(Icon, { name:'ellipsis', size:18 }))
          );
          if (isSSSecond) {
            return [
              React.createElement('div', { key:'ss-conn-'+i, style:{ display:'flex', alignItems:'center', gap:8, padding:'0 10px' } },
                React.createElement('div', { style:{ flex:1, height:2, background:'var(--accent-soft)', borderRadius:999 } }),
                React.createElement('span', { style:{ fontSize:'10px', fontWeight:800, color:'var(--accent)', background:'var(--accent-soft)', padding:'3px 9px', borderRadius:999, display:'flex', alignItems:'center', gap:3 } },
                  React.createElement(Icon, { name:'bolt', size:11 }), '\u00a0SUPERSET'),
                React.createElement('div', { style:{ flex:1, height:2, background:'var(--accent-soft)', borderRadius:999 } })
              ),
              card
            ];
          }
          return [card];
        })
      ),
      React.createElement('button', { className:'btn btn-tinted', style:{ marginTop:14 },
        onClick:() => setPicker({ mode:'add', afterIdx: exercises.length - 1 }) },
        React.createElement(Icon, { name:'plus', size:18 }), ' Add Exercise')
    ),
    modalEl(),
    React.createElement('div', { className:'home-indicator' })
  );
}

/* ── Program Library view ─────────────────────────────────────── */
function ProgramsView({ onProgram }) {
  const [query,setQuery]=useState('');
  const [openF,setOpenF]=useState(null);
  const [freq,setFreq]=useState(null);
  const [equip,setEquip]=useState(null);
  const [level,setLevel]=useState(null);
  const [split,setSplit]=useState(null);
  const [type,setType]=useState(null);

  const FILTER_DEFS = [
    { id:'freq',  label:'Frequency', val:freq,  set:setFreq,  opts:['2 days/wk','3 days/wk','4 days/wk','5 days/wk','6 days/wk'] },
    { id:'equip', label:'Equipment', val:equip, set:setEquip, opts:['Full Gym','Barbell Only','Dumbbell','Bodyweight','Home'] },
    { id:'level', label:'Level',     val:level, set:setLevel, opts:['Beginner','Intermediate','Advanced'] },
    { id:'split', label:'Split',     val:split, set:setSplit, opts:['Body Part','Full Body','Push/Pull/Legs','Upper/Lower'] },
    { id:'type',  label:'Type',      val:type,  set:setType,  opts:['Strength','Hypertrophy','Mobility','Powerlifting'] },
  ];
  const PROG_META = {
    ppl:  { freq:'6 days/wk', equip:'Full Gym', split:'Push/Pull/Legs', type:'Hypertrophy' },
    ul:   { freq:'4 days/wk', equip:'Full Gym', split:'Upper/Lower',    type:'Strength' },
    phul: { freq:'4 days/wk', equip:'Full Gym', split:'Upper/Lower',    type:'Strength' },
    fb3:  { freq:'3 days/wk', equip:'Full Gym', split:'Full Body',      type:'Strength' },
    bro:  { freq:'5 days/wk', equip:'Full Gym', split:'Body Part',      type:'Hypertrophy' },
  };
  const filtered=PLAN_PROGRAMS.filter(p=>{
    const q=query.trim().toLowerCase();
    const mq=!q||p.name.toLowerCase().includes(q)||p.tag.toLowerCase().includes(q)||p.level.toLowerCase().includes(q);
    const meta=PROG_META[p.id]||{};
    return mq&&(!freq||meta.freq===freq)&&(!equip||meta.equip===equip)
      &&(!level||p.level===level)&&(!split||meta.split===split)&&(!type||meta.type===type);
  });
  const activeCount=[freq,equip,level,split,type].filter(Boolean).length;
  const activeFilter=openF?FILTER_DEFS.find(f=>f.id===openF):null;

  return React.createElement('div',{style:{display:'flex',flexDirection:'column',flex:1,minHeight:0}},
    React.createElement('div',{style:{flex:'0 0 auto',padding:'6px 14px 0'}},
      React.createElement('div',{className:'search',style:{marginBottom:8}},
        React.createElement(Icon,{name:'search',size:18}),
        React.createElement('input',{placeholder:'Search programs',value:query,onChange:e=>setQuery(e.target.value)})
      ),
      React.createElement('div',{style:{display:'flex',gap:6,overflowX:'auto',scrollbarWidth:'none',paddingBottom:8}},
        activeCount>0&&React.createElement('button',{
          onClick:()=>{setFreq(null);setEquip(null);setLevel(null);setSplit(null);setType(null);},
          style:{flexShrink:0,padding:'6px 10px',borderRadius:999,border:0,
            background:'var(--red)',color:'#fff',
            fontSize:12,fontWeight:700,cursor:'pointer',
            display:'flex',alignItems:'center',gap:4}
        },React.createElement(Icon,{name:'x',size:12}),' Clear'),
        FILTER_DEFS.map(f=>React.createElement('button',{key:f.id,
          onClick:()=>setOpenF(f.id),
          style:{flexShrink:0,padding:'6px 12px',borderRadius:999,cursor:'pointer',
            border:'1px solid '+(f.val?'var(--accent)':'var(--separator-2)'),
            background:f.val?'var(--accent-soft)':'var(--surface)',
            color:f.val?'var(--accent)':'var(--text-2)',
            fontSize:12,fontWeight:700,display:'flex',alignItems:'center',gap:5,whiteSpace:'nowrap'}
        },f.val||f.label,React.createElement(Icon,{name:'chevron-down',size:12,color:f.val?'var(--accent)':'var(--text-3)'})))
      )
    ),
    React.createElement('div',{className:'pad pad-b',style:{overflowY:'auto',flex:1,paddingTop:4}},
      filtered.length===0
        ?React.createElement('div',{style:{textAlign:'center',padding:'40px 0',color:'var(--text-3)'}},
            React.createElement('div',{style:{fontWeight:700,fontSize:'16px',marginBottom:4}},'No programs found'),
            React.createElement('div',{style:{fontSize:'13px'}},'Try a different filter')
          )
        :React.createElement('div',{className:'col',style:{gap:10}},
            filtered.map(p=>React.createElement('button',{key:p.id,className:'lib-card',
              style:{width:'100%',border:0,cursor:'pointer',textAlign:'left'},onClick:()=>onProgram(p)},
              React.createElement('div',{className:'ph lib-thumb'}),
              React.createElement('div',{className:'grow'},
                React.createElement('div',{className:'lib-title'},p.name),
                React.createElement('div',{className:'lib-meta'},(PROG_META[p.id]||{}).freq||p.days+' days/wk',
                  React.createElement('span',{className:'tag-dot'}),p.level,
                  React.createElement('span',{className:'tag-dot'}),p.tag)
              ),
              p.active
                ?React.createElement('span',{className:'badge badge-accent'},React.createElement(Icon,{name:'check',size:12}),' Added')
                :React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
            ))
          )
    ),
    activeFilter&&React.createElement('div',{className:'sheet'},
      React.createElement('div',{className:'scrim',onClick:()=>setOpenF(null)}),
      React.createElement('div',{className:'sheet-card',style:{maxHeight:'60%'}},
        React.createElement('div',{className:'grabber'}),
        React.createElement('div',{className:'between pad',style:{paddingBottom:8}},
          React.createElement('div',{className:'nav-title'},activeFilter.label),
          React.createElement('button',{className:'nav-icon-btn',onClick:()=>setOpenF(null)},
            React.createElement(Icon,{name:'x',size:18}))
        ),
        React.createElement('div',{className:'pad',style:{paddingTop:0,paddingBottom:24,overflowY:'auto'}},
          React.createElement('div',{className:'list'},
            ['All',...activeFilter.opts].map(o=>React.createElement('button',{key:o,className:'row',
              style:{width:'100%',
                background:(o==='All'?!activeFilter.val:activeFilter.val===o)?'var(--accent-soft)':'var(--surface)',
                border:0,textAlign:'left',cursor:'pointer'},
              onClick:()=>{activeFilter.set(o==='All'?null:o);setOpenF(null);}},
              React.createElement('div',{className:'row-main'},
                React.createElement('div',{className:'row-title',
                  style:{color:(o==='All'?!activeFilter.val:activeFilter.val===o)?'var(--accent)':'var(--text)',
                    fontWeight:(o==='All'?!activeFilter.val:activeFilter.val===o)?700:500}},o)
              ),
              (o==='All'?!activeFilter.val:activeFilter.val===o)&&React.createElement(Icon,{name:'check-c',size:20,color:'var(--accent)'})
            ))
          )
        )
      )
    )
  );
}

/* ── Program Editor (new / scratch) ──────────────────────────── */
function ProgramEditorView({ onBack, onEditWorkout, calStart }) {
  const [name, setName]   = useState('');
  const [level, setLevel] = useState(null);
  const [workouts, setWorkouts] = useState([]);
  const [addSheet, setAddSheet] = useState(false);
  const [schedule, setSchedule] = useState({ Mon:null,Tue:null,Wed:null,Thu:null,Fri:null,Sat:null,Sun:null });
  const [dayWarn, setDayWarn] = useState(false);
  const handleDayPlus = day => {
    if (workouts.length === 0) { setDayWarn(true); setTimeout(()=>setDayWarn(false), 2500); return; }
    setSchedule(s=>({...s,[day]:workouts[0].id||workouts[0].name}));
  };
  const LEVELS = ['Beginner','Intermediate','Advanced'];
  const LEVEL_COLOR = { Beginner:'var(--green)', Intermediate:'var(--accent)', Advanced:'var(--red)' };

  return React.createElement('div',{className:'phone','data-theme':'light'},
    React.createElement('div',{className:'dynamic-island'}),
    React.createElement('div',{className:'statusbar auto'}),
    React.createElement('div',{className:'navbar bordered'},
      React.createElement('div',{className:'navbar-row'},
        React.createElement('button',{className:'nav-btn',onClick:onBack},
          React.createElement(Icon,{name:'chevron-left',size:22}))
      )
    ),
    React.createElement('div',{className:'screen-body pad pad-b'},

      /* Name */
      React.createElement('input',{
        autoFocus:true,
        value:name,
        onChange:e=>setName(e.target.value),
        placeholder:'Program name',
        style:{
          fontSize:'24px',fontWeight:800,letterSpacing:'-.02em',
          border:0,outline:0,background:'transparent',
          fontFamily:'var(--font)',color:'var(--text)',
          width:'100%',marginTop:16,marginBottom:4,padding:0
        }
      }),

      /* Difficulty (optional) */
      React.createElement('div',{style:{marginBottom:18}},
        React.createElement('div',{className:'tiny muted',style:{marginBottom:8,fontWeight:700,letterSpacing:'.05em',textTransform:'uppercase',fontSize:10}},'Difficulty · optional'),
        React.createElement('div',{style:{display:'flex',gap:6}},
          LEVELS.map(l=>React.createElement('button',{
            key:l,
            onClick:()=>setLevel(level===l?null:l),
            style:{
              flex:1,padding:'8px 0',borderRadius:'var(--r-sm)',border:0,cursor:'pointer',
              fontSize:'12px',fontWeight:700,
              background:level===l?LEVEL_COLOR[l]:' var(--fill)',
              color:level===l?'#fff':'var(--text-2)',
              transition:'all .15s'
            }
          },l))
        )
      ),

      /* This Week */
      React.createElement(WeekStrip,{
        schedule,
        onDayMenu: () => {},
        onDayPlus: handleDayPlus,
        calStart: calStart || 'Mon'
      }),
      dayWarn && React.createElement('div',{style:{
        margin:'-6px 0 10px',padding:'9px 12px',borderRadius:'var(--r-sm)',
        background:'color-mix(in oklab,var(--accent) 10%,transparent)',
        color:'var(--accent)',fontSize:'13px',fontWeight:600,
        display:'flex',alignItems:'center',gap:8
      }},
        React.createElement(Icon,{name:'info',size:16,color:'var(--accent)'}),
        'Add workouts below before assigning days'
      ),

      /* Workouts */
      React.createElement('div',{className:'between',style:{marginBottom:10}},
        React.createElement('div',{className:'sec-label',style:{margin:0}},'Workouts'),
        workouts.length>0 && React.createElement('button',{
          className:'nav-icon-btn',
          style:{width:28,height:28,background:'var(--accent-soft)',color:'var(--accent)'},
          onClick:()=>setAddSheet('pick')
        },React.createElement(Icon,{name:'plus',size:16}))
      ),

      workouts.length===0
        ? React.createElement('div',{className:'col',style:{gap:10}},
            React.createElement('button',{className:'src-card',onClick:()=>setAddSheet('library')},
              React.createElement('div',{className:'src-ic',style:{background:'color-mix(in oklab,var(--blue) 14%,transparent)',color:'var(--blue)'}},
                React.createElement(Icon,{name:'search',size:22})),
              React.createElement('div',{className:'grow',style:{textAlign:'left'}},
                React.createElement('div',{className:'src-t'},'Add from Workout Library'),
                React.createElement('div',{className:'src-s'},'Browse and pick ready-made workouts')),
              React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
            ),
            React.createElement('button',{className:'src-card',onClick:()=>setWorkouts(ws=>[...ws,{name:'New Workout',exCount:0}])},
              React.createElement('div',{className:'src-ic',style:{background:'var(--accent-soft)',color:'var(--accent)'}},
                React.createElement(Icon,{name:'dumbbell',size:22})),
              React.createElement('div',{className:'grow',style:{textAlign:'left'}},
                React.createElement('div',{className:'src-t'},'Create your own workout'),
                React.createElement('div',{className:'src-s'},'Build a custom set of exercises')),
              React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
            )
          )
        : React.createElement('div',{className:'col',style:{gap:10}},
            workouts.map((w,i)=>{
              const c=wkStyle(w);
              return React.createElement('div',{key:i,className:'card',style:{overflow:'hidden'}},
                React.createElement('div',{style:{display:'flex',alignItems:'center',gap:10,padding:'11px 14px'}},
                  React.createElement('div',{style:{
                    width:38,height:38,borderRadius:10,flexShrink:0,
                    background:c?c.bg:'var(--fill)',
                    border:'1.5px solid '+(c?'color-mix(in oklab,'+c.pill+' 35%,transparent)':'var(--separator-2)'),
                    display:'flex',alignItems:'center',justifyContent:'center'
                  }},React.createElement(Icon,{name:wkIcon(w),size:17,color:c?c.tx:'var(--text-3)'})),
                  React.createElement('input',{
                    value:w.name,
                    onChange:e=>setWorkouts(ws=>ws.map((x,j)=>j===i?{...x,name:e.target.value}:x)),
                    style:{flex:1,border:0,outline:0,background:'transparent',fontFamily:'var(--font)',fontSize:'15px',fontWeight:700,color:'var(--text)',minWidth:0}
                  }),
                  React.createElement('button',{
                    className:'nav-icon-btn',style:{width:30,height:30,flexShrink:0},
                    onClick:()=>onEditWorkout&&onEditWorkout(w)
                  },React.createElement(Icon,{name:'chevron-right',size:16})),
                  React.createElement('button',{
                    className:'nav-icon-btn',style:{width:30,height:30,color:'var(--red)',flexShrink:0},
                    onClick:()=>setWorkouts(ws=>ws.filter((_,j)=>j!==i))
                  },React.createElement(Icon,{name:'trash',size:14}))
                )
              );
            })
          ),

      /* Add sheet — pick mode */
      addSheet==='pick' && React.createElement(Sheet,{onClose:()=>setAddSheet(false),title:'Add a Workout',max:'68%'},
        React.createElement('div',{className:'col',style:{gap:10}},
          React.createElement('button',{className:'src-card',onClick:()=>setAddSheet('library')},
            React.createElement('div',{className:'src-ic',style:{background:'color-mix(in oklab,var(--blue) 14%,transparent)',color:'var(--blue)'}},
              React.createElement(Icon,{name:'search',size:22})),
            React.createElement('div',{className:'grow',style:{textAlign:'left'}},
              React.createElement('div',{className:'src-t'},'From Workout Library'),
              React.createElement('div',{className:'src-s'},'Browse ready-made workouts')),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          ),
          React.createElement('button',{className:'src-card',onClick:()=>{
            setWorkouts(ws=>[...ws,{name:'New Workout',exCount:0}]);
            setAddSheet(false);
          }},
            React.createElement('div',{className:'src-ic',style:{background:'var(--accent-soft)',color:'var(--accent)'}},
              React.createElement(Icon,{name:'dumbbell',size:22})),
            React.createElement('div',{className:'grow',style:{textAlign:'left'}},
              React.createElement('div',{className:'src-t'},'Create your own workout'),
              React.createElement('div',{className:'src-s'},'Build a custom set of exercises')),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          )
        )
      ),

      /* Add sheet — library mode */
      addSheet==='library' && React.createElement(Sheet,{onClose:()=>setAddSheet(false),title:'Workout Library',max:'80%'},
        React.createElement('div',{className:'col',style:{gap:8}},
          PLAN_WORKOUTS.map(w=>React.createElement('button',{
            key:w.id,className:'src-card',
            onClick:()=>{ setWorkouts(ws=>[...ws,{name:w.name,exCount:w.exCount,muscles:w.muscles,id:w.id}]); setAddSheet(false); }
          },
            React.createElement('div',{className:'src-ic',style:{background:wkStyle(w)?wkStyle(w).bg:'var(--fill)',color:wkStyle(w)?wkStyle(w).tx:'var(--text-2)'}},
              React.createElement(Icon,{name:wkIcon(w),size:22})),
            React.createElement('div',{className:'grow',style:{textAlign:'left'}},
              React.createElement('div',{className:'src-t'},w.name),
              React.createElement('div',{className:'src-s'},w.muscles)),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          ))
        )
      )
    ),
    React.createElement('div',{style:{padding:'12px 14px',flexShrink:0}},
      React.createElement('button',{
        className:'btn btn-primary',
        style:{width:'100%',opacity:name.trim()?1:0.4,pointerEvents:name.trim()?'auto':'none'},
        onClick:onBack
      },'Save Program')
    ),
    React.createElement('div',{className:'home-indicator'})
  );
}

/* ── Program Detail view ─────────────────────────────────────── */
function ProgramDetailView({ program, onBack, onWorkout }) {
  const wks = PLAN_WORKOUTS.slice(0, 4);
  return React.createElement('div', { className:'phone', 'data-theme':'light' },
    React.createElement('div', { className:'dynamic-island' }),
    React.createElement('div', { className:'statusbar auto' }),
    React.createElement('div', { className:'navbar bordered' },
      React.createElement('div', { className:'navbar-row' },
        React.createElement('button', { className:'nav-btn', onClick: onBack },
          React.createElement(Icon, { name:'chevron-left', size:22 }), 'Programs'),
        React.createElement('button', { className:'nav-icon-btn' }, React.createElement(Icon, { name:'ellipsis', size:20 }))
      )
    ),
    React.createElement('div', { className:'screen-body pad pad-b' },
      React.createElement('div', { className:'ph rounded', style:{ aspectRatio:'16/9', marginTop:12 } }),
      React.createElement('h2', { style:{ fontSize:'24px', fontWeight:800, letterSpacing:'-.02em', margin:'14px 0 4px' } }, program.name),
      React.createElement('div', { className:'tiny muted', style:{ lineHeight:1.5 } },
        `A ${program.days}-day ${program.tag.toLowerCase()} split. ${program.level} level.`),
      React.createElement('div', { className:'chips', style:{ marginTop:12 } },
        React.createElement('span', { className:'chip' }, `${program.days} days/wk`),
        React.createElement('span', { className:'chip' }, program.level),
        React.createElement('span', { className:'chip' }, program.tag)
      ),
      React.createElement('div', { className:'sec-label' }, 'Workouts in this program'),
      React.createElement('div', { className:'list' },
        wks.map((w, i) =>
          React.createElement('button', { key: w.id, className:'row', style:{ width:'100%', background:'var(--surface)', border:0, textAlign:'left', cursor:'pointer' }, onClick: () => onWorkout && onWorkout(w) },
            React.createElement('div', { className:'ex-n', style:{ background:'var(--accent-soft)', color:'var(--accent)' } }, i + 1),
            React.createElement('div', { className:'row-main' },
              React.createElement('div', { className:'row-title' }, w.name),
              React.createElement('div', { className:'row-sub' }, `${w.exCount} exercises · ${w.muscles}`)
            ),
            React.createElement(Icon, { name:'chevron-right', size:18, color:'var(--text-3)' })
          )
        )
      ),
      React.createElement('div', { className:'hint-card', style:{ marginTop:14 } },
        React.createElement(Icon, { name:'info', size:18, color:'var(--text-2)' }),
        React.createElement('div', { className:'tiny', style:{ lineHeight:1.5, color:'var(--text-2)' } },
          'To edit a predefined program, add it to ', React.createElement('b', null, 'My Plans'), ' first. Your edits stay on your copy.')
      ),
      React.createElement('button', { className:'btn btn-primary', style:{ marginTop:16 } },
        React.createElement(Icon, { name:'plus', size:18 }), ' Add to My Plans')
    ),
    React.createElement('div', { className:'home-indicator' })
  );
}

/* ── Workout Library view ─────────────────────────────────────── */
function WorkoutsView({ onEdit }) {
  const [query,setQuery]=useState('');
  const [af,setAf]=useState('All');
  const FILTERS=['All','Push','Pull','Legs','Upper','Chest','Back'];
  const filtered=PLAN_WORKOUTS.filter(w=>{
    const q=query.trim().toLowerCase();
    const mq=!q||w.name.toLowerCase().includes(q)||w.muscles.toLowerCase().includes(q);
    const mf=af==='All'||w.name.toLowerCase().includes(af.toLowerCase())||w.muscles.toLowerCase().includes(af.toLowerCase());
    return mq&&mf;
  });
  return React.createElement('div',{className:'screen-body pad pad-b'},
    React.createElement('div',{style:{paddingTop:6,paddingBottom:4}},
      React.createElement('div',{className:'search'},
        React.createElement(Icon,{name:'search',size:18}),
        React.createElement('input',{placeholder:'Search workouts',value:query,onChange:e=>setQuery(e.target.value)})
      )
    ),
    React.createElement('div',{className:'filters',style:{marginBottom:8}},
      FILTERS.map(f=>React.createElement('button',{key:f,className:'chip'+(af===f?' active':''),onClick:()=>setAf(f)},f))
    ),
    filtered.length===0
      ?React.createElement('div',{style:{textAlign:'center',padding:'40px 0',color:'var(--text-3)'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'16px',marginBottom:4}},'No workouts found'),
          React.createElement('div',{style:{fontSize:'13px'}},'Try a different search or filter')
        )
      :React.createElement('div',{className:'col',style:{gap:10,marginTop:6}},
          filtered.map(w=>
            React.createElement('button',{key:w.id,className:'lib-card',style:{width:'100%',border:0,cursor:'pointer',textAlign:'left'},onClick:()=>onEdit(w)},
              React.createElement('div',{className:'ph lib-thumb'}),
              React.createElement('div',{className:'grow'},
                React.createElement('div',{className:'lib-title'},w.name),
                React.createElement('div',{className:'lib-meta'},`${w.exCount} exercises · ${w.muscles}`)
              ),
              React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
            )
          )
        )
  );
}

/* ── Exercise Library view ────────────────────────────────────── */
function ExercisesView({ onExercise }) {
  const [query,setQuery]=useState('');
  const [mf,setMf]=useState('All');
  const [ef,setEf]=useState('All');
  const MUSCLES=['All','Chest','Back','Shoulders','Arms','Legs','Core'];
  const EQUIPS=['All','Barbell','Dumbbell','Cable','Machine','Bodyweight','Smith'];
  const THUMB={
    Chest:    {bg:'linear-gradient(145deg,oklch(0.90 0.07 58),oklch(0.84 0.11 52))',  tx:'oklch(0.46 0.18 54)'},
    Back:     {bg:'linear-gradient(145deg,oklch(0.90 0.05 248),oklch(0.84 0.09 244))',tx:'oklch(0.44 0.13 248)'},
    Shoulders:{bg:'linear-gradient(145deg,oklch(0.90 0.05 284),oklch(0.84 0.08 279))',tx:'oklch(0.44 0.12 283)'},
    Biceps:   {bg:'linear-gradient(145deg,oklch(0.90 0.06 151),oklch(0.84 0.10 147))',tx:'oklch(0.44 0.14 149)'},
    Triceps:  {bg:'linear-gradient(145deg,oklch(0.90 0.06 151),oklch(0.84 0.10 147))',tx:'oklch(0.44 0.14 149)'},
    Legs:     {bg:'linear-gradient(145deg,oklch(0.90 0.06 31),oklch(0.84 0.10 25))',  tx:'oklch(0.44 0.13 27)'},
    Core:     {bg:'linear-gradient(145deg,oklch(0.90 0.05 19),oklch(0.84 0.09 13))',  tx:'oklch(0.44 0.13 17)'},
  };
  const CHIP_COLOR={
    Chest:    {soft:'oklch(0.93 0.05 58)',  tx:'oklch(0.46 0.18 54)',  active:'oklch(0.54 0.18 54)'},
    Back:     {soft:'oklch(0.93 0.04 248)', tx:'oklch(0.44 0.13 248)', active:'oklch(0.50 0.14 248)'},
    Shoulders:{soft:'oklch(0.93 0.04 284)', tx:'oklch(0.44 0.12 283)', active:'oklch(0.50 0.13 283)'},
    Arms:     {soft:'oklch(0.93 0.05 151)', tx:'oklch(0.44 0.14 149)', active:'oklch(0.50 0.15 149)'},
    Legs:     {soft:'oklch(0.93 0.05 31)',  tx:'oklch(0.44 0.13 27)',  active:'oklch(0.50 0.14 27)'},
    Core:     {soft:'oklch(0.93 0.04 19)',  tx:'oklch(0.44 0.13 17)',  active:'oklch(0.50 0.14 17)'},
  };
  const LABEL={Biceps:'Arms',Triceps:'Arms'};
  const filtered=PLAN_EXERCISES_LIB.filter(e=>{
    const q=query.trim().toLowerCase();
    const mq=!q||e.name.toLowerCase().includes(q)||e.muscle.toLowerCase().includes(q)||e.equip.toLowerCase().includes(q);
    const mm=mf==='All'||(mf==='Arms'?(e.muscle==='Biceps'||e.muscle==='Triceps'):e.muscle===mf);
    const me=ef==='All'||e.equip===ef;
    return mq&&mm&&me;
  });
  return React.createElement('div',{className:'screen-body pad pad-b'},
    React.createElement('div',{style:{paddingTop:6,paddingBottom:4}},
      React.createElement('div',{className:'search'},
        React.createElement(Icon,{name:'search',size:18}),
        React.createElement('input',{placeholder:'Search exercises',value:query,onChange:e=>setQuery(e.target.value)})
      )
    ),
    React.createElement('div',{className:'filters',style:{marginBottom:4}},
      MUSCLES.map(m=>{
        const cc=CHIP_COLOR[m];
        const isActive=mf===m;
        const chipStyle=cc
          ?{background:isActive?cc.active:cc.soft,color:isActive?'#fff':cc.tx,borderColor:'transparent'}
          :{};
        return React.createElement('button',{key:m,className:'chip'+(isActive?' active':''),style:chipStyle,onClick:()=>setMf(m)},m);
      })
    ),
    React.createElement('div',{className:'filters',style:{marginBottom:10}},
      EQUIPS.map(eq=>React.createElement('button',{key:eq,className:'chip'+(ef===eq?' active':''),onClick:()=>setEf(eq)},eq))
    ),
    filtered.length===0
      ?React.createElement('div',{style:{textAlign:'center',padding:'40px 0',color:'var(--text-3)'}},
          React.createElement('div',{style:{fontWeight:700,fontSize:'16px',marginBottom:4}},'No exercises found'),
          React.createElement('div',{style:{fontSize:'13px'}},'Try a different filter')
        )
      :React.createElement('div',{className:'catalog'},
          filtered.map(e=>{
            const th=THUMB[e.muscle]||{bg:'var(--fill)',tx:'var(--text-3)'};
            return React.createElement('button',{key:e.id,className:'cat-item',style:{border:0,cursor:'pointer',textAlign:'left'},onClick:()=>onExercise&&onExercise(e)},
              React.createElement('div',{className:'cat-thumb',style:{background:th.bg,display:'flex',alignItems:'center',justifyContent:'center'}},
                React.createElement('span',{style:{fontSize:'10px',fontWeight:800,color:th.tx,letterSpacing:'.07em',textTransform:'uppercase',textAlign:'center',padding:'0 6px',lineHeight:1.25}},LABEL[e.muscle]||e.muscle)
              ),
              React.createElement('div',{className:'cat-name'},e.name),
              React.createElement('div',{className:'cat-meta'},e.muscle+' · '+e.equip)
            );
          })
        )
  );
}

/* ── Workout colour / initials helpers ───────────────────────── */
function wkStyle(w) {
  if (!w) return null;
  const n = w.name.toLowerCase();
  if (n.includes('push'))  return { bg:'var(--accent-soft)', tx:'var(--accent)', pill:'linear-gradient(140deg,oklch(0.76 0.18 68),oklch(0.57 0.22 50))', glow:'oklch(0.68 0.17 60 / 0.5)' };
  if (n.includes('pull'))  return { bg:'color-mix(in oklab,var(--blue) 14%,transparent)',   tx:'var(--blue)',   pill:'linear-gradient(140deg,oklch(0.72 0.14 256),oklch(0.52 0.18 242))', glow:'oklch(0.66 0.14 250 / 0.5)' };
  if (n.includes('leg'))   return { bg:'color-mix(in oklab,var(--green) 14%,transparent)',  tx:'var(--green)',  pill:'linear-gradient(140deg,oklch(0.74 0.16 155),oklch(0.55 0.18 142))', glow:'oklch(0.70 0.15 150 / 0.5)' };
  if (n.includes('upper')) return { bg:'color-mix(in oklab,var(--purple) 14%,transparent)', tx:'var(--purple)', pill:'linear-gradient(140deg,oklch(0.68 0.14 305),oklch(0.50 0.17 292))', glow:'oklch(0.62 0.15 300 / 0.5)' };
  return { bg:'var(--accent-soft)', tx:'var(--accent)', pill:'linear-gradient(140deg,oklch(0.76 0.18 68),oklch(0.57 0.22 50))', glow:'oklch(0.68 0.17 60 / 0.5)' };
}
function wkIcon(w) {
  if (!w) return 'dumbbell';
  const n = w.name.toLowerCase();
  if (n.includes('push'))  return 'flame';
  if (n.includes('pull'))  return 'bolt';
  if (n.includes('leg'))   return 'trophy';
  if (n.includes('upper')) return 'arrow-up';
  return 'dumbbell';
}
function wkInitials(w) {
  if (!w) return '';
  const parts = w.name.split(' ');
  const last = parts[parts.length - 1];
  return (parts[0][0] + (last.length <= 2 ? last : parts[1] ? parts[1][0] : '')).toUpperCase().slice(0,3);
}

/* ── Week Strip ───────────────────────────────────────────────── */
function WeekStrip({ schedule, onDayMenu, onDayPlus, calStart }) {
  const orderedDays = calStart === 'Sun'
    ? ['SUN','MON','TUE','WED','THU','FRI','SAT']
    : ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  const shortLabel = { MON:'Mo',TUE:'Tu',WED:'We',THU:'Th',FRI:'Fr',SAT:'Sa',SUN:'Su' };
  return React.createElement('div',{style:{flex:'0 0 auto',padding:'14px 14px 12px'}},
    React.createElement('div',{className:'sec-label',style:{margin:'0 0 10px'}},'This week'),
    React.createElement('div',{style:{display:'flex',gap:4}},
      orderedDays.map(day=>{
        const wId=schedule[day];
        const w=wId?WorkoutById(wId):null;
        const c=wkStyle(w);
        const isRest=!w;
        return React.createElement('button',{
          key:day,
          style:{
            flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:6,
            padding:'9px 2px 10px',borderRadius:12,border:0,
            background:isRest?'transparent':c.bg,
            outline: isRest ? '1.5px solid var(--separator-2)' : '1.5px solid color-mix(in oklab,'+c.pill+' 35%,transparent)',
            cursor:'pointer',transition:'all .12s'
          },
          onClick:()=>w?onDayMenu(day):onDayPlus(day)
        },
          React.createElement('span',{style:{
            fontSize:'9px',fontWeight:700,letterSpacing:'.07em',textTransform:'uppercase',
            color:isRest?'var(--text-3)':c.tx
          }},shortLabel[day]),
          w
            ? React.createElement('div',{style:{
                width:34,height:34,borderRadius:10,
                background:c.bg,
                border:'1.5px solid color-mix(in oklab,'+c.pill+' 45%,transparent)',
                display:'flex',alignItems:'center',justifyContent:'center',
              }},
                React.createElement(Icon,{name:wkIcon(w),size:16,color:c.tx})
              )
            : React.createElement('div',{style:{
                width:34,height:34,borderRadius:10,
                border:'1.5px solid var(--separator-2)',
                display:'flex',alignItems:'center',justifyContent:'center',
                color:'var(--text-3)',background:'var(--fill)'
              }},
                React.createElement(Icon,{name:'moon',size:14,color:'var(--text-3)'})
              ),
          React.createElement('span',{style:{
            fontSize:'8px',fontWeight:700,
            color:isRest?'var(--text-3)':c.tx,
            textAlign:'center',lineHeight:1.2,
            maxWidth:34,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'
          }}, w ? w.name.replace(/workout/i,'').trim().split(' ')[0] : 'Rest')
        );
      })
    )
  );
}

/* ── My Plans view ────────────────────────────────────────────── */
function MyPlansView({ workouts, onEditWorkout, onAddWorkout, onDeleteWorkout }) {
  return React.createElement('div',{className:'screen-body pad pad-b',style:{paddingTop:4}},
    React.createElement('div',{className:'between',style:{marginTop:16,marginBottom:10}},
      React.createElement('div',{className:'sec-label',style:{margin:0}},'Workouts in program'),
      React.createElement('button',{className:'nav-icon-btn',style:{width:28,height:28,background:'var(--accent-soft)',color:'var(--accent)'},onClick:onAddWorkout},
        React.createElement(Icon,{name:'plus',size:16}))
    ),
    React.createElement('div',{className:'col',style:{gap:10}},
      workouts.map(w=>{
        const c=wkStyle(w);
        const ini=wkInitials(w);
        const muscles=w.muscles.split(', ');
        return React.createElement('div',{key:w.id,className:'card',style:{overflow:'hidden'}},
          React.createElement('div',{style:{display:'flex',alignItems:'center',gap:13,padding:'13px 14px 11px'}},
            React.createElement('div',{style:{
              width:46,height:46,borderRadius:14,flexShrink:0,
              background:c?c.bg:'var(--fill)',
              border:'1.5px solid '+(c?'color-mix(in oklab,'+c.pill+' 35%,transparent)':'var(--separator-2)'),
              display:'flex',alignItems:'center',justifyContent:'center',
            }},
              React.createElement(Icon,{name:wkIcon(w),size:20,color:c?c.tx:'var(--text-3)'})
            ),
            React.createElement('div',{style:{flex:1,minWidth:0}},
              React.createElement('div',{style:{fontWeight:800,fontSize:'15px',letterSpacing:'-.01em',marginBottom:4}},w.name),
              React.createElement('div',{style:{fontSize:'12px',fontWeight:500,color:c?c.tx:'var(--text-3)',letterSpacing:'.01em'}},
                muscles.join(' · ')
              )
            ),
            React.createElement('div',{style:{display:'flex',flexDirection:'column',alignItems:'flex-end',gap:8,flexShrink:0}},
              React.createElement('div',{style:{display:'flex',gap:5}},
                React.createElement('button',{className:'nav-icon-btn',style:{width:30,height:30},onClick:()=>onEditWorkout(w)},
                  React.createElement(Icon,{name:'edit',size:14})),
                React.createElement('button',{className:'nav-icon-btn',style:{width:30,height:30,color:'var(--red)'},onClick:()=>onDeleteWorkout(w.id)},
                  React.createElement(Icon,{name:'trash',size:14}))
              )
            )
          )
        );
      })
    )
  );
}

/* ── Main App ─────────────────────────────────────────────────── */
function App(props) {
  const [subtab, setSubtab]       = useState('myplans');
  const [schedule, setSchedule]   = useState(clone(DEFAULT_SCHEDULE));
  const [workouts, setWorkouts]   = useState(clone(PLAN_WORKOUTS));
  const [modal, setModal]         = useState(null);
  const [editingWk, setEditingWk] = useState(null);
  const [viewingProg, setViewingProg] = useState(null);
  const [editingProg, setEditingProg] = useState(false);
  const [viewingEx, setViewingEx] = useState(null);

  if (viewingEx) return React.createElement(ExerciseDetail, { exercise: viewingEx, onBack: () => setViewingEx(null), showActions: true });
  if (editingWk) return React.createElement(WorkoutEditorView, { workout: editingWk, onBack: () => setEditingWk(null) });
  if (editingProg) return React.createElement(ProgramEditorView, { onBack: () => setEditingProg(false), onEditWorkout: w => setEditingWk(w), calStart: props.calStart || 'Mon' });
  if (viewingProg) return React.createElement(ProgramDetailView, { program: viewingProg, onBack: () => setViewingProg(null), onWorkout: w => setEditingWk(w) });

  const assignDay  = (day, wId) => { setSchedule(s => ({ ...s, [day]: wId })); setModal(null); };
  const makeRest   = (day)      => { setSchedule(s => ({ ...s, [day]: null })); setModal(null); };
  const deleteWk   = (id)       => {
    setWorkouts(ws => ws.filter(w => w.id !== id));
    setSchedule(s => Object.fromEntries(Object.entries(s).map(([day, wId]) => [day, wId === id ? null : wId])));
    setModal(null);
  };

  function modalEl() {
    if (!modal) return null;
    if (modal.kind === 'assign')
      return React.createElement(AssignSheet, { day: modal.day, current: schedule[modal.day], workouts, onAssign: id => assignDay(modal.day, id), onRest: () => makeRest(modal.day), onClose: () => setModal(null) });
    if (modal.kind === 'day-menu')
      return React.createElement(DayMenuSheet, { day: modal.day, workout: WorkoutById(schedule[modal.day]),
        onEdit:   () => { setEditingWk(WorkoutById(schedule[modal.day])); setModal(null); },
        onChange: () => setModal({ kind:'assign', day: modal.day }),
        onRest:   () => makeRest(modal.day),
        onRemove: () => makeRest(modal.day),
        onClose:  () => setModal(null) });
    if (modal.kind === 'add-workout')
      return React.createElement(Sheet,{onClose:()=>setModal(null),title:'Add a Workout',max:'62%'},
        React.createElement('div',{className:'col',style:{gap:10}},
          React.createElement('button',{className:'src-card',onClick:()=>{ setModal(null); setSubtab('workouts'); }},
            React.createElement('div',{className:'src-ic',style:{background:'color-mix(in oklab,var(--blue) 14%,transparent)',color:'var(--blue)'}},
              React.createElement(Icon,{name:'search',size:22})),
            React.createElement('div',{className:'grow',style:{textAlign:'left'}},
              React.createElement('div',{className:'src-t'},'From Workout Library'),
              React.createElement('div',{className:'src-s'},'Browse and pick a ready-made workout')),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          ),
          React.createElement('button',{className:'src-card',onClick:()=>setModal({kind:'create-workout',name:'',icon:'dumbbell'})},
            React.createElement('div',{className:'src-ic',style:{background:'var(--accent-soft)',color:'var(--accent)'}},
              React.createElement(Icon,{name:'sparkle',size:22})),
            React.createElement('div',{className:'grow',style:{textAlign:'left'}},
              React.createElement('div',{className:'src-t'},'Create custom workout'),
              React.createElement('div',{className:'src-s'},'Name it, pick an icon, add exercises')),
            React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'})
          )
        )
      );
    if (modal.kind === 'create-workout') {
      const WK_ICONS = [
        {name:'flame',    label:'Push',      color:'var(--accent)'},
        {name:'bolt',     label:'Pull',      color:'var(--blue)'},
        {name:'trophy',   label:'Legs',      color:'var(--green)'},
        {name:'arrow-up', label:'Upper',     color:'var(--purple)'},
        {name:'dumbbell', label:'Weights',   color:'var(--text-2)'},
        {name:'sparkle',  label:'Full Body', color:'var(--accent)'},
        {name:'target',   label:'Core',      color:'var(--red)'},
        {name:'medal',    label:'Strength',  color:'oklch(0.70 0.14 58)'},
        {name:'timer',    label:'Cardio',    color:'var(--blue)'},
        {name:'cable',    label:'Cable',     color:'var(--purple)'},
        {name:'bulb',     label:'Hypertrophy',color:'oklch(0.65 0.17 95)'},
        {name:'moon',     label:'Recovery',  color:'oklch(0.52 0.06 260)'},
      ];
      return React.createElement(Sheet,{onClose:()=>setModal(null),title:'New Workout',max:'72%'},
        React.createElement('div',{className:'field',style:{marginBottom:16}},
          React.createElement('label',null,'Workout name'),
          React.createElement('input',{
            autoFocus:true,
            value:modal.name,
            placeholder:'e.g. Push Day A',
            onChange:e=>setModal(m=>({...m,name:e.target.value})),
          })
        ),
        React.createElement('div',{className:'tiny muted',style:{fontWeight:700,letterSpacing:'.05em',textTransform:'uppercase',fontSize:10,marginBottom:10}},'Icon'),
        React.createElement('div',{style:{display:'grid',gridTemplateColumns:'repeat(4,1fr)',gap:8,marginBottom:20}},
          WK_ICONS.map(ic=>React.createElement('button',{
            key:ic.name,
            onClick:()=>setModal(m=>({...m,icon:ic.name})),
            style:{
              display:'flex',flexDirection:'column',alignItems:'center',gap:5,
              padding:'10px 4px',borderRadius:10,border:0,cursor:'pointer',
              background:modal.icon===ic.name?'var(--accent-soft)':'var(--fill)',
              outline:modal.icon===ic.name?'1.5px solid var(--accent)':'none'
            }
          },
            React.createElement(Icon,{name:ic.name,size:20,color:modal.icon===ic.name?'var(--accent)':ic.color}),
            React.createElement('span',{style:{fontSize:'9px',fontWeight:700,color:modal.icon===ic.name?'var(--accent)':'var(--text-3)',letterSpacing:'.03em'}},ic.label)
          ))
        ),
        React.createElement('button',{
          className:'btn btn-primary',
          style:{opacity:modal.name.trim()?1:0.4,pointerEvents:modal.name.trim()?'auto':'none'},
          onClick:()=>{
            const newWk={id:'custom-'+Date.now(),name:modal.name.trim(),muscles:'Custom',exCount:0,icon:modal.icon};
            setWorkouts(ws=>[...ws,newWk]);
            setModal(null);
            setEditingWk(newWk);
          }
        },'Continue → Add Exercises')
      );
    }
      return React.createElement(AddPlanSheet, { onClose: () => setModal(null), onPrograms: () => setSubtab('programs'), onBuildFromScratch: () => { setModal(null); setEditingProg(true); } });
    return null;
  }

  const subtabs = ['myplans','programs','workouts','exercises'];
  const subtabLabels = { myplans:'My Plans', programs:'Programs', workouts:'Workouts', exercises:'Exercises' };

  return React.createElement('div', { className:'phone', 'data-theme':'light' },
    React.createElement('div', { className:'dynamic-island' }),
    React.createElement('div', { className:'statusbar auto' }),
    React.createElement('div', { className:'navbar' },
      React.createElement('div', { className:'navbar-row' },
        React.createElement('div', { className:'nav-title-lg' }, 'Plan'),
        React.createElement('button', { className:'nav-icon-btn accent', onClick: () => setModal({ kind:'add-plan' }) },
          React.createElement(Icon, { name:'plus', size:20 }))
      ),
      React.createElement('div', { className:'subtabs' },
        subtabs.map(st =>
          React.createElement('button', { key: st, className:'subtab' + (subtab===st?' active':''), onClick: () => setSubtab(st) },
            subtabLabels[st])
        )
      )
    ),
    subtab === 'myplans' && React.createElement(React.Fragment, null,
      React.createElement('div', { style:{ flex:'0 0 auto', padding:'10px 14px 0' } },
        React.createElement('div', { className:'plan-scroll' },
          React.createElement('div', { className:'plan-card', style:{ minWidth:150 } },
            React.createElement('div', { className:'pc-bg' }),
            React.createElement('div', { className:'badge', style:{ background:'#fff', color:'var(--accent)', alignSelf:'flex-start', marginBottom:'auto' } },
              React.createElement(Icon, { name:'check', size:12 }), ' Active'),
            React.createElement('div', { style:{ fontSize:'14px', fontWeight:800, letterSpacing:'-.02em' } }, 'Push Pull Legs'),
            React.createElement('div', { className:'tiny', style:{ opacity:.85, marginTop:1 } }, '6 days · Intermediate')
          ),
          React.createElement('div', { className:'plan-card alt', style:{ minWidth:130 } },
            React.createElement('div', { className:'pc-bg' }),
            React.createElement('div', { style:{ fontSize:'14px', fontWeight:800, letterSpacing:'-.02em', marginTop:'auto' } }, 'Upper / Lower'),
            React.createElement('div', { className:'tiny', style:{ opacity:.85, marginTop:1 } }, '4 days · Strength')
          ),
          React.createElement('div', { className:'plan-card alt2', style:{ minWidth:130 } },
            React.createElement('div', { className:'pc-bg' }),
            React.createElement('div', { style:{ fontSize:'14px', fontWeight:800, letterSpacing:'-.02em', marginTop:'auto' } }, 'Full Body 3×'),
            React.createElement('div', { className:'tiny', style:{ opacity:.85, marginTop:1 } }, '3 days · Beginner')
          ),
          React.createElement('div', { className:'plan-add', onClick: () => setModal({ kind:'add-plan' }) },
            React.createElement(Icon, { name:'plus', size:22 }),
            React.createElement('span', { className:'tiny', style:{ fontWeight:700 } }, 'New')
          )
        )
      ),
      React.createElement(WeekStrip, {
        schedule,
        onDayMenu: day => setModal({ kind:'day-menu', day }),
        onDayPlus: day => setModal({ kind:'assign', day }),
        calStart: props.calStart || 'Mon'
      }),
      React.createElement(MyPlansView, {
        workouts,
        onEditWorkout:  w    => setEditingWk(w),
        onAddWorkout:   ()   => setModal({ kind:'add-workout' }),
        onDeleteWorkout: id  => deleteWk(id)
      })
    ),
    subtab === 'programs'  && React.createElement(ProgramsView, { onProgram: p => setViewingProg(p) }),
    subtab === 'workouts'  && React.createElement(WorkoutsView, { onEdit: w => setEditingWk(w) }),
    subtab === 'exercises' && React.createElement(ExercisesView, { onExercise: ex => setViewingEx(ex) }),
    modalEl(),
    React.createElement(window.AuraTabBar, {
      active: (props&&props.tab)||'plan',
      onTab: props&&props.onTab,
      onAction: function(k) { if(props&&props.onTab) props.onTab(k==='workout'||k==='measure'||k==='photo'?'log':'plan'); }
    }),
    React.createElement('div', { className:'home-indicator' })
  );
}

window.PlanApp = App;
if (!window.__AURA_EMBED) ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(App));
})();
