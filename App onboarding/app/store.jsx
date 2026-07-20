/* AURA APP — shared store: seed data, context, persistence. */
const { createContext, useContext, useState, useEffect, useRef, useMemo } = React;

/* ---------- helpers ---------- */
const uid = (p='id') => p + Math.random().toString(36).slice(2,8);
const iso = d => d.toISOString().slice(0,10);
const TODAY = new Date(2026,5,22); // Mon Jun 22 2026
const DOW = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
function addDays(d,n){ const x=new Date(d); x.setDate(x.getDate()+n); return x; }
function weekStart(d){ return addDays(d, -d.getDay()); } // Sunday

/* ---------- exercise catalog ---------- */
const EX = (o)=>({ difficulty:'Intermediate', isCable:false, groups:[], hint:'Focus on controlled form and full range of motion.', ...o });
const EXERCISES = [
  EX({id:'bench', name:'Barbell Bench Press', category:'Chest', equipment:'Barbell', muscle:'Chest',
     groups:[{name:'Mid Chest',pct:90},{name:'Front Delts',pct:52},{name:'Triceps',pct:40}],
     hint:'Drive your feet into the floor, keep shoulder blades pinned. Lower to the lower chest.'}),
  EX({id:'incline', name:'Incline Dumbbell Press', category:'Chest', equipment:'Dumbbell', muscle:'Upper Chest',
     groups:[{name:'Upper Chest',pct:88},{name:'Front Delts',pct:55},{name:'Triceps',pct:35}],
     hint:'Set the bench to ~30°. Keep the dumbbells stacked over your elbows.'}),
  EX({id:'fly', name:'Cable Fly', category:'Chest', equipment:'Cable', muscle:'Chest', isCable:true, difficulty:'Beginner',
     groups:[{name:'Mid Chest',pct:92},{name:'Front Delts',pct:48},{name:'Biceps',pct:22}],
     hint:'Lead with your pinkies and squeeze at the midline. Soft fixed bend in the elbows.'}),
  EX({id:'pecdeck', name:'Pec Deck', category:'Chest', equipment:'Machine', muscle:'Chest', difficulty:'Beginner',
     groups:[{name:'Mid Chest',pct:85},{name:'Front Delts',pct:38}], hint:'Keep your back flat against the pad and squeeze.'}),
  EX({id:'dips', name:'Weighted Dips', category:'Chest', equipment:'Bodyweight', muscle:'Lower Chest',
     groups:[{name:'Lower Chest',pct:80},{name:'Triceps',pct:65},{name:'Front Delts',pct:45}], hint:'Lean forward for chest, stay upright for triceps.'}),
  EX({id:'ohp', name:'Seated Shoulder Press', category:'Shoulders', equipment:'Machine', muscle:'Shoulders',
     groups:[{name:'Front Delts',pct:88},{name:'Side Delts',pct:55},{name:'Triceps',pct:42}], hint:'Brace your core, avoid arching your lower back.'}),
  EX({id:'lateral', name:'Cable Lateral Raise', category:'Shoulders', equipment:'Cable', muscle:'Side Delts', isCable:true, difficulty:'Beginner',
     groups:[{name:'Side Delts',pct:90},{name:'Traps',pct:35}], hint:'Lead with your elbow. Slow eccentric.'}),
  EX({id:'reardelt', name:'Reverse Pec Deck', category:'Shoulders', equipment:'Machine', muscle:'Rear Delts',
     groups:[{name:'Rear Delts',pct:85},{name:'Traps',pct:48}], hint:'Squeeze your shoulder blades together at the end.'}),
  EX({id:'pushdown', name:'Triceps Rope Pushdown', category:'Arms', equipment:'Cable', muscle:'Triceps', isCable:true, difficulty:'Beginner',
     groups:[{name:'Triceps',pct:92},{name:'Forearms',pct:28}], hint:'Pin your elbows to your sides, spread the rope at the bottom.'}),
  EX({id:'ohext', name:'Overhead Triceps Extension', category:'Arms', equipment:'Cable', muscle:'Triceps', isCable:true,
     groups:[{name:'Triceps',pct:88}], hint:'Keep your upper arms still and get a full stretch overhead.'}),
  EX({id:'pulldown', name:'Lat Pulldown', category:'Back', equipment:'Cable', muscle:'Lats', isCable:true,
     groups:[{name:'Lats',pct:88},{name:'Biceps',pct:45},{name:'Rear Delts',pct:38}], hint:'Drive your elbows down and back, lead with the chest.'}),
  EX({id:'row', name:'Barbell Row', category:'Back', equipment:'Barbell', muscle:'Mid Back',
     groups:[{name:'Lats',pct:78},{name:'Mid Back',pct:82},{name:'Biceps',pct:48}], hint:'Hinge to ~45°, pull to your belt, keep a neutral spine.'}),
  EX({id:'curl', name:'Dumbbell Biceps Curl', category:'Arms', equipment:'Dumbbell', muscle:'Biceps', difficulty:'Beginner',
     groups:[{name:'Biceps',pct:90},{name:'Forearms',pct:40}], hint:'No swinging — control the lower and squeeze at the top.'}),
  EX({id:'hammer', name:'Hammer Curl', category:'Arms', equipment:'Dumbbell', muscle:'Biceps', difficulty:'Beginner',
     groups:[{name:'Brachialis',pct:85},{name:'Forearms',pct:60}], hint:'Neutral grip throughout, elbows tucked.'}),
  EX({id:'squat', name:'Barbell Back Squat', category:'Legs', equipment:'Barbell', muscle:'Quads', difficulty:'Advanced',
     groups:[{name:'Quads',pct:90},{name:'Glutes',pct:65},{name:'Hamstrings',pct:40}], hint:'Brace hard, break at the hips and knees together, depth to parallel.'}),
  EX({id:'rdl', name:'Romanian Deadlift', category:'Legs', equipment:'Barbell', muscle:'Hamstrings',
     groups:[{name:'Hamstrings',pct:88},{name:'Glutes',pct:72},{name:'Lower Back',pct:45}], hint:'Push your hips back, soft knees, feel the hamstring stretch.'}),
  EX({id:'legpress', name:'Leg Press', category:'Legs', equipment:'Machine', muscle:'Quads', difficulty:'Beginner',
     groups:[{name:'Quads',pct:85},{name:'Glutes',pct:55}], hint:'Feet shoulder width, don\u2019t let your lower back round at the bottom.'}),
  EX({id:'legcurl', name:'Seated Leg Curl', category:'Legs', equipment:'Machine', muscle:'Hamstrings', difficulty:'Beginner',
     groups:[{name:'Hamstrings',pct:90}], hint:'Control the negative, full range each rep.'}),
];

/* ---------- workouts ---------- */
const W = (id,name,muscles,items)=>({id,name,muscles,custom:false,
  items:items.map(([exId,sets,rep])=>({exId,sets,repRange:rep,restSet:60,restEx:90}))});
const WORKOUTS = [
  W('pushA','Push Day A','Chest, Shoulders, Triceps',[['bench',4,'6–8'],['incline',3,'8–10'],['fly',3,'12–15'],['ohp',3,'8–12'],['lateral',3,'12–15'],['pushdown',3,'10–12']]),
  W('pullA','Pull Day A','Back, Biceps',[['pulldown',4,'8–10'],['row',4,'6–8'],['reardelt',3,'12–15'],['curl',3,'8–12'],['hammer',3,'10–12']]),
  W('legA','Leg Day A','Quads, Hamstrings',[['squat',4,'5–8'],['rdl',3,'8–10'],['legpress',3,'10–12'],['legcurl',3,'10–12']]),
  W('pushB','Push Day B','Shoulders focus',[['ohp',4,'6–8'],['incline',3,'8–10'],['lateral',4,'12–15'],['dips',3,'8–12'],['ohext',3,'10–12']]),
  W('pullB','Pull Day B','Back width',[['row',4,'6–8'],['pulldown',4,'10–12'],['hammer',3,'10–12'],['curl',3,'10–12']]),
  W('upper','Upper Body Strength','Chest, Back, Arms',[['bench',4,'5'],['row',4,'5'],['ohp',3,'8'],['pulldown',3,'10'],['curl',3,'10']]),
  W('arm','Arm Day Pump','Biceps, Triceps',[['curl',4,'10–12'],['pushdown',4,'10–12'],['hammer',3,'12'],['ohext',3,'12'],['dips',3,'10']]),
];

/* ---------- programs ---------- */
const PR = (id,name,level,style,days,gradient,template,custom=false)=>({id,name,level,style,days,gradient,template,custom});
// template: [Sun..Sat] of workoutId | null(rest)
const PROGRAMS = [
  PR('ppl','Push Pull Legs','Intermediate','Hypertrophy',6,'accent',['pushA','pullA',null,'legA','pushB','pullB',null]),
  PR('ul','Upper / Lower 4-Day','Strength','Barbell',4,'alt',[null,'upper','legA',null,'upper','legA',null]),
  PR('fb','Full Body 3×','Beginner','Compound',3,'alt2',[null,'upper',null,'legA',null,'upper',null]),
  PR('arnold','Arnold Split','Advanced','Volume',6,'alt',['pushA','pullA','legA','pushB','pullB','legA',null]),
  PR('phul','PHUL','Intermediate','Power',4,'accent',[null,'upper','legA',null,'upper','legA',null]),
  PR('bro','Bro Split 5-Day','Intermediate','Isolation',5,'alt2',[null,'pushA','pullA','legA','arm','pushB',null]),
];

/* ---------- initial state ---------- */
function freshState(){
  // seed a few past log entries as done for the heatmap / week bar
  const log = {};
  for(let i=1;i<=40;i++){ const d=iso(addDays(TODAY,-i)); const wd=addDays(TODAY,-i).getDay();
    const tpl=PROGRAMS[0].template[wd];
    if(tpl) log[d]={status: Math.random()<0.12?'partial':'done', workoutId:tpl};
    else log[d]={status:'rest'};
  }
  return {
    exercises: EXERCISES, workouts: WORKOUTS, programs: PROGRAMS,
    myPlanIds: ['ppl','ul','fb'], defaultPlanId: 'ppl',
    log,
    session: null,
    profile: { first:'Alex', last:'Carter', age:28, height:178, weight:78.4, sex:'Male', email:'alex@mail.com', phone:'+1 555 0182', city:'Austin, TX, US', bday:'Apr 3, 1998' },
    settings: { weightUnit:'kg', lengthUnit:'cm', startWeek:'Sun', darkMode:'Auto', repsFirst:true, showPR:true, autoRest:true, autoVideo:false,
      notif:true, restSound:'Ding', appleHealth:true, googleHealth:false,
      defSets:3, defReps:'6–10', restSet:'1 min', restEx:'1 min 30 s' },
    nutrition: { goal:'Lean gain', macro:'Balanced', calories:2840, protein:180, carbs:320, fats:78, fiber:38, targetWeight:80 },
    measurements: { weight:78.4, bodyFat:16.2, neck:null, chest:104, waist:82, hips:null, arms:38.5, thighs:59, shoulders:122 },
    prs: { chest:[{name:'Barbell Bench Press',w:82.5,r:6,date:'May 28'},{name:'Incline DB Press',w:34,r:9,date:'May 21'},{name:'Cable Fly',w:17.5,r:14,date:'Jun 4'},{name:'Pec Deck',w:68,r:12,date:'Jun 11'},{name:'Weighted Dips',w:25,r:10,date:'Jun 18'}] },
  };
}

/* ---------- context ---------- */
const Store = createContext(null);
function StoreProvider({children}){
  const [state,setState] = useState(()=>{
    try{ const s=localStorage.getItem('aura_app'); if(s) return JSON.parse(s); }catch(e){}
    return freshState();
  });
  useEffect(()=>{ try{ localStorage.setItem('aura_app', JSON.stringify(state)); }catch(e){} }, [state]);
  const api = useMemo(()=>({
    state, setState,
    set:(fn)=>setState(p=>{ const n=JSON.parse(JSON.stringify(p)); fn(n); return n; }),
    reset:()=>setState(freshState()),
    ex:(id)=>state.exercises.find(e=>e.id===id),
    workout:(id)=>state.workouts.find(w=>w.id===id),
    program:(id)=>state.programs.find(p=>p.id===id),
  }), [state]);
  return React.createElement(Store.Provider,{value:api},children);
}
const useStore = ()=>useContext(Store);
Object.assign(window,{ StoreProvider, useStore, EXERCISES, TODAY, DOW, MONTHS, addDays, weekStart, iso, uid });
