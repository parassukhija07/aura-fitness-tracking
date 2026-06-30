/* Active Workout — SupersetView: paired exercise logging screen (round-based). */

function SSSetRow({ ex, setIdx, onChange, onToggle, onDelete }) {
  const s = ex.sets[setIdx];
  if (!s) return null;
  const hist = ex.history && ex.history[setIdx];
  const isExtra = setIdx >= ex.planned;
  const filled = s.weight !== '' && s.reps !== '';

  return React.createElement('div', null,
    React.createElement('div', { className: 'set-row' + (s.done ? ' done' : '') },
      React.createElement('div', { className: 'set-no', style: { display: 'grid', placeItems: 'center', fontSize: '14px', fontWeight: 700, color: 'var(--text-2)', background: 'var(--fill)', borderRadius: 'var(--r-sm)', cursor: 'default' } }, setIdx + 1),
      React.createElement('div', { className: 'set-input' },
        React.createElement('input', {
          type: 'tel', value: s.weight,
          placeholder: hist ? String(hist.weight) : '\u2013',
          onChange: e => onChange(setIdx, 'weight', e.target.value),
          onBlur: () => filled && onToggle(setIdx, true)
        }),
        React.createElement('label', null, 'kg')
      ),
      React.createElement('div', { className: 'set-input' },
        React.createElement('input', {
          type: 'tel', value: s.reps,
          placeholder: hist ? String(hist.reps) : '\u2013',
          onChange: e => onChange(setIdx, 'reps', e.target.value),
          onBlur: () => filled && onToggle(setIdx, true)
        }),
        React.createElement('label', null, 'reps')
      ),
      React.createElement('button', { className: 'set-check' + (s.done ? ' on' : ''), onClick: () => onToggle(setIdx, !s.done) },
        React.createElement(Icon, { name: 'check', size: 18 })
      ),
      React.createElement('button', { className: 'set-del-btn', onClick: () => onDelete(setIdx) },
        React.createElement(Icon, { name: 'trash', size: 17 })
      )
    ),
    (window.__wkTweaks?.showHistory !== false) && hist && React.createElement('div', {
      style: { display: 'flex', alignItems: 'center', gap: '8px', padding: '2px 0 4px' }
    },
      React.createElement('div', { style: { width: '32px', flexShrink: 0 } }),
      React.createElement('div', { style: { flex: 1, textAlign: 'center' } },
        React.createElement('span', { style: { fontSize: '11px', fontWeight: 700, color: 'var(--text-3)' } }, `${hist.weight} kg`)
      ),
      React.createElement('div', { style: { flex: 1, textAlign: 'center' } },
        React.createElement('span', { style: { fontSize: '11px', fontWeight: 700, color: 'var(--text-3)' } }, `${hist.reps} reps`)
      ),
      React.createElement('div', { style: { width: '48px', flexShrink: 0 } }),
      React.createElement('div', { style: { width: '48px', flexShrink: 0 } })
    )
  );
}

function ExMeta({ ex, color }) {
  const letter = color === 'var(--accent)' ? 'A' : 'B';
  return React.createElement('div', { style: { background: 'var(--surface)', border: '1px solid var(--separator-2)', borderRadius: 'var(--r-md)', padding: '9px 11px', marginBottom: '8px' } },
    React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: '5px', marginBottom: '7px' } },
      React.createElement('span', { style: { width: 15, height: 15, borderRadius: 4, background: color, color: '#fff', fontSize: 8, fontWeight: 800, display: 'grid', placeItems: 'center', flexShrink: 0 } }, letter),
      React.createElement('span', { style: { fontWeight: 700, fontSize: '12px', letterSpacing: '-.01em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0 } }, ex.name)
    ),
    React.createElement('div', { style: { display: 'flex', gap: '0', borderRadius: 'var(--r-sm)', overflow: 'hidden', border: '1px solid var(--separator-2)' } },
      React.createElement('div', { style: { flex: 1, padding: '5px 8px', background: 'var(--fill)', borderRight: '1px solid var(--separator-2)' } },
        React.createElement('div', { style: { fontSize: '9px', fontWeight: 700, color: 'var(--text-3)', letterSpacing: '.05em', textTransform: 'uppercase', marginBottom: '2px' } }, '🏆 PR'),
        React.createElement('div', { style: { fontSize: '12px', fontWeight: 800, whiteSpace: 'nowrap' } }, `${ex.lastPR.weight} kg × ${ex.lastPR.reps}`),
        React.createElement('div', { style: { fontSize: '9px', color: 'var(--text-3)', marginTop: '1px' } }, ex.lastPR.date)
      ),
      React.createElement('div', { style: { flex: 1, padding: '5px 8px', background: 'var(--accent-soft)' } },
        React.createElement('div', { style: { fontSize: '9px', fontWeight: 700, color: 'var(--accent)', letterSpacing: '.05em', textTransform: 'uppercase', marginBottom: '2px' } }, '🎯 Target'),
        React.createElement('div', { style: { fontSize: '12px', fontWeight: 800, color: 'var(--accent)', whiteSpace: 'nowrap' } }, `${ex.target.weight} kg × ${ex.target.reps}`),
        React.createElement('div', { style: { fontSize: '9px', color: 'var(--accent)', opacity: .7, marginTop: '1px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' } }, ex.target.note)
      )
    )
  );
}

function SupersetView({ exA, exB, onBack, onChangeA, onToggleA, onDeleteA, onChangeB, onToggleB, onDeleteB, onAddRound, onComplete, onOpenMenu, onExNoteA, onExNoteB, onExerciseDetailA, onExerciseDetailB }) {
  const rounds = Math.max(exA.sets.length, exB.sets.length);
  const doneA = exA.sets.filter(s => s.done).length;
  const doneB = exB.sets.filter(s => s.done).length;
  const totalDone = doneA + doneB;
  const totalSets = exA.sets.length + exB.sets.length;

  const roundEls = Array.from({ length: rounds }, (_, r) => {
    const sa = exA.sets[r];
    const sb = exB.sets[r];
    const roundDone = sa && sb && sa.done && sb.done;
    const progress = (sa && sa.done ? 1 : 0) + (sb && sb.done ? 1 : 0);

    return React.createElement('div', {
      key: r,
      className: 'round-card',
      style: { borderColor: roundDone ? 'color-mix(in oklab,var(--green) 35%,transparent)' : 'var(--separator-2)' }
    },
      React.createElement('div', { className: 'round-header', style: { background: roundDone ? 'color-mix(in oklab,var(--green) 7%,transparent)' : 'transparent' } },
        React.createElement('div', { style: { fontWeight: 700, fontSize: '13px' } }, `Round ${r + 1}`),
        roundDone
          ? React.createElement(Icon, { name: 'check-c', size: 18, color: 'var(--green)' })
          : React.createElement('div', { style: { fontSize: '11px', color: 'var(--text-3)', fontWeight: 600 } }, `${progress}/2 done`)
      ),
      React.createElement('div', { className: 'round-ex' },
        React.createElement('div', { className: 'ex-label' },
          React.createElement('span', { className: 'ex-label-pill', style: { background: 'var(--accent)' } }, 'A'),
          React.createElement('button',{style:{background:'none',border:0,padding:0,fontWeight:700,fontSize:'12px',color:'var(--text)',cursor:'pointer',fontFamily:'var(--font)'},onClick:()=>onExerciseDetailA&&onExerciseDetailA()},exA.name)
        ),
        sa ? React.createElement(SSSetRow, { ex: exA, setIdx: r, onChange: onChangeA, onToggle: onToggleA, onDelete: onDeleteA }) : null
      ),
      React.createElement('div', { className: 'round-ex', style: { borderTop: '1px solid var(--separator-2)' } },
        React.createElement('div', { className: 'ex-label' },
          React.createElement('span', { className: 'ex-label-pill', style: { background: 'var(--blue)' } }, 'B'),
          React.createElement('button',{style:{background:'none',border:0,padding:0,fontWeight:700,fontSize:'12px',color:'var(--text)',cursor:'pointer',fontFamily:'var(--font)'},onClick:()=>onExerciseDetailB&&onExerciseDetailB()},exB.name)
        ),
        sb ? React.createElement(SSSetRow, { ex: exB, setIdx: r, onChange: onChangeB, onToggle: onToggleB, onDelete: onDeleteB }) : null
      )
    );
  });

  return React.createElement('div', { className: 'phone', 'data-theme': 'light' },
    React.createElement('div', { className: 'dynamic-island' }),
    React.createElement('div', { className: 'statusbar auto' }),
    React.createElement('div', { className: 'navbar bordered' },
      React.createElement('div', { className: 'navbar-row' },
        React.createElement('button', { className: 'nav-btn', onClick: onBack },
          React.createElement(Icon, { name: 'chevron-left', size: 22 })),
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: '5px', fontWeight: 800, fontSize: '16px', letterSpacing: '-.01em', color: 'var(--accent)' } },
          React.createElement(Icon, { name: 'bolt', size: 16 }), 'Superset'
        ),
        React.createElement('button', { className: 'nav-icon-btn', onClick: onOpenMenu },
          React.createElement(Icon, { name: 'ellipsis', size: 20 }))
      )
    ),
    React.createElement('div', { className: 'screen-body pad pad-b' },
      // progress
      React.createElement('div', { className: 'between', style: { margin: '14px 4px 6px' } },
        React.createElement('div', { style: { fontWeight: 800, fontSize: '15px' } }, `${totalDone}/${totalSets} sets`),
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px', fontWeight: 700, color: 'var(--accent)', background: 'var(--accent-soft)', padding: '3px 9px', borderRadius: '999px' } },
          React.createElement(Icon, { name: 'bolt', size: 12 }), ` ${rounds} rounds`)
      ),
      React.createElement('div', { className: 'bar', style: { marginBottom: '14px' } },
        React.createElement('i', { style: { width: `${totalSets ? totalDone / totalSets * 100 : 0}%` } })
      ),
      // PR + target cards for both exercises
      React.createElement('div', { style: { marginBottom: '4px' } },
        React.createElement(ExMeta, { ex: exA, color: 'var(--accent)' }),
        React.createElement(ExMeta, { ex: exB, color: 'var(--blue)' })
      ),
      // rounds
      ...roundEls,
      React.createElement('button', { className: 'btn btn-tinted btn-sm', style: { width: '100%', marginTop: '4px' }, onClick: onAddRound },
        React.createElement(Icon, { name: 'plus', size: 17 }), ' Add Round'),
      // notes
      React.createElement('div', { style: { marginTop: '20px' } },
        React.createElement('div', { className: 'sec-label', style: { margin: '0 4px 6px' } }, 'Notes'),
        React.createElement('textarea', {
          className: 'notes-area',
          style: { minHeight: '52px', marginTop: 0 },
          placeholder: `${exA.name}\u2026`,
          value: exA.note || '',
          onChange: e => onExNoteA(e.target.value)
        }),
        React.createElement('textarea', {
          className: 'notes-area',
          style: { minHeight: '52px', marginTop: '8px' },
          placeholder: `${exB.name}\u2026`,
          value: exB.note || '',
          onChange: e => onExNoteB(e.target.value)
        })
      ),
      React.createElement('button', { className: 'btn btn-primary', style: { marginTop: '16px' }, onClick: onComplete },
        React.createElement(Icon, { name: 'check', size: 19 }), ' Complete Superset')
    ),
    React.createElement('div', { className: 'home-indicator' })
  );
}

window.SupersetView = SupersetView;
