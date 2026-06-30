/* Plan Tab — seed data */
const PLAN_WORKOUTS = [
  { id:'push-a', name:'Push Day A',  exCount:6, muscles:'Chest, Shoulders, Triceps', duration:58 },
  { id:'pull-a', name:'Pull Day A',  exCount:6, muscles:'Back, Biceps',              duration:52 },
  { id:'leg-a',  name:'Leg Day A',   exCount:5, muscles:'Quads, Hamstrings',         duration:55 },
  { id:'push-b', name:'Push Day B',  exCount:6, muscles:'Shoulders focus',           duration:55 },
  { id:'pull-b', name:'Pull Day B',  exCount:5, muscles:'Back, Biceps',              duration:50 },
];

const PLAN_PROGRAMS = [
  { id:'ppl',   name:'Push Pull Legs',     days:6, level:'Intermediate', tag:'Hypertrophy', active:true  },
  { id:'ul',    name:'Upper / Lower 4-Day',days:4, level:'Strength',     tag:'Barbell',     active:false },
  { id:'arnold',name:'Arnold Split',       days:6, level:'Advanced',     tag:'Volume',      active:false },
  { id:'fb3',   name:'Full Body 3×',       days:3, level:'Beginner',     tag:'Compound',    active:false },
  { id:'phul',  name:'PHUL',               days:4, level:'Intermediate', tag:'Power',       active:false },
  { id:'bro',   name:'Bro Split 5-Day',    days:5, level:'Intermediate', tag:'Isolation',   active:false },
];

const PLAN_EXERCISES_LIB = [
  // Chest
  { id:'bbar',  name:'Barbell Bench Press',   muscle:'Chest',     equip:'Barbell'    },
  { id:'idb',   name:'Incline DB Press',      muscle:'Chest',     equip:'Dumbbell'   },
  { id:'cfly',  name:'Cable Fly',             muscle:'Chest',     equip:'Cable'      },
  { id:'peck',  name:'Pec Deck',              muscle:'Chest',     equip:'Machine'    },
  { id:'dfly',  name:'Dumbbell Fly',          muscle:'Chest',     equip:'Dumbbell'   },
  { id:'smbp',  name:'Smith Machine Bench',   muscle:'Chest',     equip:'Smith'      },
  { id:'decbp', name:'Decline Bench Press',   muscle:'Chest',     equip:'Barbell'    },
  { id:'pushup',name:'Push-up',               muscle:'Chest',     equip:'Bodyweight' },
  // Back
  { id:'brow',  name:'Barbell Row',           muscle:'Back',      equip:'Barbell'    },
  { id:'pull',  name:'Pull-ups',              muscle:'Back',      equip:'Bodyweight' },
  { id:'crow',  name:'Cable Row',             muscle:'Back',      equip:'Cable'      },
  { id:'latpd', name:'Lat Pulldown',          muscle:'Back',      equip:'Machine'    },
  { id:'drow',  name:'Dumbbell Row',          muscle:'Back',      equip:'Dumbbell'   },
  { id:'dead',  name:'Deadlift',              muscle:'Back',      equip:'Barbell'    },
  { id:'tbar',  name:'T-Bar Row',             muscle:'Back',      equip:'Barbell'    },
  { id:'smrow', name:'Smith Machine Row',     muscle:'Back',      equip:'Smith'      },
  // Shoulders
  { id:'ohp',   name:'Overhead Press',        muscle:'Shoulders', equip:'Barbell'    },
  { id:'latdb', name:'Lateral Raise',         muscle:'Shoulders', equip:'Dumbbell'   },
  { id:'latc',  name:'Cable Lateral Raise',   muscle:'Shoulders', equip:'Cable'      },
  { id:'fp',    name:'Face Pull',             muscle:'Shoulders', equip:'Cable'      },
  { id:'arnp',  name:'Arnold Press',          muscle:'Shoulders', equip:'Dumbbell'   },
  { id:'frt',   name:'Front Raise',           muscle:'Shoulders', equip:'Dumbbell'   },
  { id:'smohp', name:'Smith Machine Press',   muscle:'Shoulders', equip:'Smith'      },
  // Biceps
  { id:'bcurl', name:'Barbell Curl',          muscle:'Biceps',    equip:'Barbell'    },
  { id:'hcurl', name:'Hammer Curl',           muscle:'Biceps',    equip:'Dumbbell'   },
  { id:'ccurl', name:'Cable Curl',            muscle:'Biceps',    equip:'Cable'      },
  { id:'icurl', name:'Incline DB Curl',       muscle:'Biceps',    equip:'Dumbbell'   },
  { id:'pccurl',name:'Preacher Curl',         muscle:'Biceps',    equip:'Machine'    },
  { id:'concur',name:'Concentration Curl',    muscle:'Biceps',    equip:'Dumbbell'   },
  // Triceps
  { id:'tpush', name:'Tricep Pushdown',       muscle:'Triceps',   equip:'Cable'      },
  { id:'skull', name:'Skull Crushers',        muscle:'Triceps',   equip:'Barbell'    },
  { id:'ohext', name:'Overhead Extension',    muscle:'Triceps',   equip:'Dumbbell'   },
  { id:'tdips', name:'Tricep Dips',           muscle:'Triceps',   equip:'Bodyweight' },
  { id:'kbext', name:'Kickback',              muscle:'Triceps',   equip:'Dumbbell'   },
  { id:'clpush',name:'Close-Grip Bench',      muscle:'Triceps',   equip:'Barbell'    },
  // Legs
  { id:'squat', name:'Barbell Squat',         muscle:'Legs',      equip:'Barbell'    },
  { id:'rdl',   name:'Romanian Deadlift',     muscle:'Legs',      equip:'Barbell'    },
  { id:'legpr', name:'Leg Press',             muscle:'Legs',      equip:'Machine'    },
  { id:'legcr', name:'Leg Curl',              muscle:'Legs',      equip:'Machine'    },
  { id:'legex', name:'Leg Extension',         muscle:'Legs',      equip:'Machine'    },
  { id:'lunge', name:'Barbell Lunge',         muscle:'Legs',      equip:'Barbell'    },
  { id:'gobsq', name:'Goblet Squat',          muscle:'Legs',      equip:'Dumbbell'   },
  { id:'sumo',  name:'Sumo Deadlift',         muscle:'Legs',      equip:'Barbell'    },
  { id:'smsq',  name:'Smith Machine Squat',   muscle:'Legs',      equip:'Smith'      },
  // Core
  { id:'plank', name:'Plank',                 muscle:'Core',      equip:'Bodyweight' },
  { id:'crunch',name:'Cable Crunch',          muscle:'Core',      equip:'Cable'      },
  { id:'hangk', name:'Hanging Knee Raise',    muscle:'Core',      equip:'Bodyweight' },
  { id:'abwh',  name:'Ab Wheel Rollout',      muscle:'Core',      equip:'Bodyweight' },
  { id:'rus',   name:'Russian Twist',         muscle:'Core',      equip:'Bodyweight' },
];

const DEFAULT_SCHEDULE = { MON:'push-a', TUE:'pull-a', WED:null, THU:'leg-a', FRI:'push-b', SAT:null, SUN:null };

window.PLAN_WORKOUTS = PLAN_WORKOUTS;
window.PLAN_PROGRAMS = PLAN_PROGRAMS;
window.PLAN_EXERCISES_LIB = PLAN_EXERCISES_LIB;
window.DEFAULT_SCHEDULE = DEFAULT_SCHEDULE;
