/* Active Workout — ExerciseView: the detailed set-logging screen. */
const { useState: useStateX, useRef: useRefX } = React;

function WkSetRow({ s, i, exId, isLast, planned, onChange, onToggle, onType, onNote, onDelete, showNote, toggleNote, history, isExtra }) {
  const t = SET_TYPES[s.type] || SET_TYPES.normal;
  const filled = s.weight !== "" && s.reps !== "";
  return (
    React.createElement('div', { className: 'set-block' },
      React.createElement('div', { className: 'set-row' + (s.done ? ' done' : '') },
        React.createElement('button', { className: 'set-no', onClick: () => onType(i) },
          s.type === 'normal'
            ? React.createElement('span', null, i + 1)
            : React.createElement('span', { style: { color: t.color } }, t.short)
        ),
        React.createElement('div', { className: 'set-input' },
          React.createElement('input', { type: 'text', inputMode: 'decimal', value: s.weight, placeholder: '–',
            onChange: e => onChange(i, 'weight', e.target.value),
            onBlur: () => { const f = s.weight !== '' && s.reps !== ''; if(f) onToggle(i, true); } }),
          React.createElement('label', null, 'kg')
        ),
        React.createElement('div', { className: 'set-input' },
          React.createElement('input', { type: 'text', inputMode: 'decimal', value: s.reps, placeholder: '–',
            onChange: e => onChange(i, 'reps', e.target.value),
            onBlur: () => { const f = s.weight !== '' && s.reps !== ''; if(f) onToggle(i, true); } }),
          React.createElement('label', null, 'reps')
        ),
        React.createElement('button', { className: 'set-check' + (s.done ? ' on' : ''), onClick: () => onToggle(i, !s.done) },
          React.createElement(Icon, { name: 'check', size: 18 })
        ),
        React.createElement('button', { className: 'set-del-btn', onClick: () => onDelete(i) },
          React.createElement(Icon, { name: 'trash', size: 17 })
        )
      ),
      (window.__wkTweaks?.showHistory !== false) && history && React.createElement('div', {
        style: { display: 'flex', alignItems: 'center', gap: '8px', padding: '2px 0 4px' }
      },
        React.createElement('div', { style: { width: '48px', flexShrink: 0 } }),
        React.createElement('div', { style: { flex: 1, textAlign: 'center' } },
          React.createElement('span', { style: { fontSize: '11px', fontWeight: 700, color: 'var(--text-3)' } }, `${history.weight} kg`)
        ),
        React.createElement('div', { style: { flex: 1, textAlign: 'center' } },
          React.createElement('span', { style: { fontSize: '11px', fontWeight: 700, color: 'var(--text-3)' } }, `${history.reps} reps`)
        ),
        React.createElement('div', { style: { width: '48px', flexShrink: 0 } }),
        React.createElement('div', { style: { width: '48px', flexShrink: 0 } })
      ),

    )
  );
}

function ExerciseView(props) {
  const { ex, exIdx, onBack, onChange, onToggle, onAddSet, onDelete, onComplete,
          onOpenType, onOpenMenu, onSetNote, onPulley, onExNote, onExerciseDetail } = props;
  const [warmOpen, setWarmOpen] = useStateX(true);
  const [noteOpen, setNoteOpen] = useStateX(null);
  const done = ex.sets.filter(s => s.done).length;
  const planned = ex.planned;
  const showWarmup = ex.warmup && ex.warmup.length > 0;
  const extraHistory = ex.history ? ex.history.slice(planned) : [];

  return React.createElement('div', { className: 'phone', 'data-theme': 'light' },
    React.createElement('div', { className: 'dynamic-island' }),
    React.createElement('div', { className: 'statusbar auto' }),
    // header
    React.createElement('div', { className: 'navbar bordered' },
      React.createElement('div', { className: 'navbar-row' },
        React.createElement('button', { className: 'nav-btn nav-btn-icon', onClick: onBack },
          React.createElement(Icon, { name: 'chevron-left', size: 22 })),
        React.createElement('div', { className: 'col', style: { alignItems: 'center', gap: '1px' } },
          React.createElement('div', { style: { fontSize: '10px', fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase', color: 'var(--text-3)' } }, `Exercise ${exIdx + 1}`),
          React.createElement('div', { style: { fontSize: '14px', fontWeight: 700, letterSpacing: '-.01em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '160px' } }, ex.name)
        ),
        React.createElement('button', { className: 'nav-icon-btn', onClick: () => onOpenMenu(exIdx) },
          React.createElement(Icon, { name: 'ellipsis', size: 20 }))
      )
    ),
    React.createElement('div', { className: 'screen-body pad pad-b' },
      // video thumb
      React.createElement('div', { className: 'ex-video', style:{marginTop:'14px'} },
        React.createElement('div', { className: 'ph rounded', style: { aspectRatio:'16/10', borderRadius:'var(--r-lg)' } }, 'exercise demo'),
        React.createElement('button', { className: 'play-btn', style:{position:'absolute',top:'50%',left:'50%',transform:'translate(-50%,-50%)'} },
          React.createElement(Icon, { name: 'play', size: 22 }))
      ),
      React.createElement('h2', { style:{fontSize:'24px',fontWeight:800,letterSpacing:'-.02em',margin:'14px 0 8px', cursor:'pointer'}, onClick:()=>onExerciseDetail&&onExerciseDetail() }, ex.name),
      React.createElement('div', { className:'chips', style:{marginBottom:'4px'} },
        React.createElement('span', { className:'chip', style:{background:'var(--accent-soft)',color:'var(--accent)'} }, ex.equipment),
        ...ex.groups.map((g,i)=>React.createElement('span',{key:i,className:'chip'},g))
      ),
      // cable pulley
      ex.isCable && React.createElement('div', { className:'card card-pad', style:{marginTop:'14px'} },
        React.createElement('div',{className:'between'},
          React.createElement('div',{className:'flex gap2',style:{alignItems:'center'}},
            React.createElement(Icon,{name:'cable',size:18,color:'var(--text-2)'}),
            React.createElement('span',{style:{fontWeight:600,fontSize:'15px'}},'Pulley setup')),
          React.createElement('div',{className:'segmented',style:{width:'150px'}},
            React.createElement('button',{className:ex.pulley==='single'?'active':'',onClick:()=>onPulley('single')},'Single'),
            React.createElement('button',{className:ex.pulley==='double'?'active':'',onClick:()=>onPulley('double')},'Double'))
        )
      ),
      // PR + target
      React.createElement('div', { className:'flex gap3', style:{marginTop:'14px'} },
        React.createElement('div',{className:'mini-card'},
          React.createElement('div',{className:'mini-head'},React.createElement(Icon,{name:'trophy',size:15,color:'var(--accent)'}),' Last PR'),
          React.createElement('div',{className:'mini-val'},`${ex.lastPR.weight} kg × ${ex.lastPR.reps}`),
          React.createElement('div',{className:'mini-sub'},ex.lastPR.date)),
        React.createElement('div',{className:'mini-card',style:{borderColor:'var(--accent)',background:'var(--accent-soft)'}},
          React.createElement('div',{className:'mini-head'},React.createElement(Icon,{name:'target',size:15,color:'var(--accent)'}),' Today\u2019s target'),
          React.createElement('div',{className:'mini-val'},`${ex.target.weight} kg × ${ex.target.reps}`),
          React.createElement('div',{className:'mini-sub'},ex.target.note))
      ),
      // warmup
      showWarmup && React.createElement('div', { className:'card', style:{marginTop:'14px',overflow:'hidden'} },
        React.createElement('button',{className:'warm-head',onClick:()=>setWarmOpen(!warmOpen)},
          React.createElement(Icon,{name:'flame',size:17,color:'var(--accent)'}),
          React.createElement('span',{style:{fontWeight:700,fontSize:'15px',flex:1,textAlign:'left'}},'Warm-up protocol'),
          React.createElement('span',{className:'tiny muted'},`${ex.warmup.length} sets`),
          React.createElement(Icon,{name:'chevron-down',size:18,color:'var(--text-3)',style:{transform:warmOpen?'rotate(180deg)':'',transition:'.2s'}})),
        warmOpen && React.createElement('div',{className:'warm-body'},
          ex.warmup.map((w,i)=>React.createElement('div',{key:i,className:'warm-row'},
            React.createElement('span',{className:'warm-n'},`W${i+1}`),
            React.createElement('span',{className:'grow'},`${w.reps} reps`),
            React.createElement('span',{className:'muted tiny'},w.pct)))
        )
      ),
      // hint
      React.createElement('div',{className:'hint-card',style:{marginTop:'14px'}},
        React.createElement(Icon,{name:'bulb',size:18,color:'var(--accent)',style:{flexShrink:0,marginTop:'1px'}}),
        React.createElement('div',null,
          React.createElement('div',{style:{fontWeight:700,fontSize:'13px',marginBottom:'3px'}},'Form tip'),
          React.createElement('div',{className:'tiny',style:{lineHeight:1.5,color:'var(--text-2)'}},ex.hint))),
      // sets header
      React.createElement('div',{className:'between',style:{margin:'22px 4px 6px'}},
        React.createElement('div',{style:{fontWeight:800,fontSize:'17px'}},'Working sets'),
        React.createElement('div',{className:'badge badge-gray'},`${done}/${ex.sets.length} done`)),
      // progression bar
      React.createElement('div',{className:'bar',style:{marginBottom:'14px'}},
        React.createElement('i',{style:{width:`${Math.min(100,done/ex.sets.length*100)}%`}})),
      // set rows
      React.createElement('div',{className:'sets'},
        ex.sets.map((s,i)=>React.createElement(WkSetRow,{
          key:i,s,i,exId:ex.id,planned,
          onChange,onToggle,onType:onOpenType,onNote:onSetNote,onDelete,
          history: ex.history ? ex.history[i] : undefined,
          isExtra: i >= planned,
          showNote: noteOpen===i || (s.note!=null && s.note!==''),
          toggleNote:(idx)=>setNoteOpen(noteOpen===idx?null:idx)
        }))),
      React.createElement('button',{className:'btn btn-tinted btn-sm',style:{width:'100%',marginTop:'12px'},onClick:onAddSet},
        React.createElement(Icon,{name:'plus',size:17}),' Add set'),
      extraHistory.length > 0 && React.createElement('div', { className: 'hint-card', style: { marginTop: '14px', background: 'color-mix(in oklab,var(--blue) 8%,transparent)', border: '1px solid color-mix(in oklab,var(--blue) 22%,transparent)' } },
        React.createElement(Icon, { name: 'info', size: 18, color: 'var(--blue)', style: { flexShrink: 0, marginTop: '1px' } }),
        React.createElement('div', null,
          React.createElement('div', { style: { fontWeight: 700, fontSize: '13px', marginBottom: '3px' } }, `${extraHistory.length} extra set${extraHistory.length > 1 ? 's' : ''} last session`),
          React.createElement('div', { className: 'tiny', style: { lineHeight: 1.5, color: 'var(--text-2)' } },
            extraHistory.map((h, j) => `Set ${planned + j + 1}: ${h.weight}\u202fkg \xd7 ${h.reps}\u202freps`).join(' \xb7 '))
        )
      ),
      React.createElement('div', { style: { marginTop: '20px' } },
        React.createElement('div', { className: 'sec-label', style: { margin: '0 4px 8px' } }, 'Exercise notes'),
        React.createElement('textarea', {
          className: 'notes-area',
          style: { minHeight: '72px', marginTop: 0 },
          placeholder: 'Cues, adjustments, how it felt…',
          value: ex.note || '',
          onChange: e => onExNote(e.target.value)
        })
      ),
      React.createElement('button',{className:'btn btn-primary',style:{marginTop:'16px'},onClick:onComplete},
        React.createElement(Icon,{name:'check',size:19}),' Complete Exercise')
    )
  );
}
window.ExerciseView = ExerciseView;
