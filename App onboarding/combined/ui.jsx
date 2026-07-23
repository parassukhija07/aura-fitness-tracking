/* Aura — shared UI helpers for combined tabs. */
(function () {
const { useState } = React;

function Toggle({ on, onChange }) {
  return <div className={'toggle' + (on ? ' on' : '')} onClick={() => onChange(!on)} role="switch" aria-checked={on}></div>;
}

function Seg({ options, value, onChange, style }) {
  return (
    <div className="segmented" style={style}>
      {options.map(o => {
        const v = typeof o === 'string' ? o : o.v, l = typeof o === 'string' ? o : o.l;
        return <button key={v} className={value === v ? 'active' : ''} onClick={() => onChange(v)}>{l}</button>;
      })}
    </div>
  );
}

/* SVG line chart. data: number[]. */
function LineChart({ data, h = 120, color = 'var(--accent)', area = true, flat }) {
  const W = 320, H = h, pad = 12;
  const max = Math.max.apply(null, data), min = Math.min.apply(null, data);
  const rng = (max - min) || 1;
  const n = data.length;
  const pts = data.map((v, i) => {
    const x = pad + (n === 1 ? (W - 2 * pad) / 2 : i * (W - 2 * pad) / (n - 1));
    const y = H - pad - (v - min) / rng * (H - 2 * pad - 6);
    return [x, y];
  });
  const line = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
  const areaD = line + ' L ' + pts[n - 1][0].toFixed(1) + ' ' + (H - pad) + ' L ' + pts[0][0].toFixed(1) + ' ' + (H - pad) + ' Z';
  const gid = 'lc' + Math.random().toString(36).slice(2, 7);
  return (
    <svg viewBox={'0 0 ' + W + ' ' + H} style={{ width: '100%', height: H, display: 'block' }} preserveAspectRatio="none">
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.22" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {area && <path d={areaD} fill={'url(#' + gid + ')'} />}
      <path d={line} fill="none" stroke={color} strokeWidth="2.4" strokeLinejoin="round" strokeLinecap="round" />
      {!flat && pts.map((p, i) => i === n - 1 && <circle key={i} cx={p[0]} cy={p[1]} r="4" fill={color} />)}
    </svg>
  );
}

/* Settings-style nav bar with back button. */
function BackNav({ title, onBack, right }) {
  return (
    <div className="navbar bordered">
      <div className="navbar-row">
        <button className="nav-btn" onClick={onBack}><Icon name="chevron-left" size={22} />Settings</button>
        <div className="nav-title" style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)' }}>{title}</div>
        {right || <div style={{ width: 34 }}></div>}
      </div>
    </div>
  );
}

function TabBarEl({ active, onTab, onAction }) {
  const [fabOpen, setFabOpen] = React.useState(false);
  const [collapsed, setCollapsed] = React.useState(false);
  const [hoverIdx, setHoverIdx] = React.useState(null);
  const [swipeProg, setSwipeProg] = React.useState(0);
  const [dragging, setDragging] = React.useState(false);
  const ALL_TABS = [['log','Log','log'],['plan','Plan','dumbbell'],['progress','Progress','chart'],['profile','Profile','person']];
  const ACTIONS = [
    { icon:'play-c',  label:'Start Workout',    color:'var(--accent)', key:'workout' },
    { icon:'log',     label:'Log Measurements', color:'var(--blue)',   key:'measure' },
    { icon:'medal',   label:'Progress Photo',   color:'var(--green)',  key:'photo'   },
  ];
  const tabIdx = ALL_TABS.findIndex(t => t[0] === active);
  const pillRef = React.useRef(null);
  const touchX = React.useRef(null);

  React.useEffect(() => {
    const handler = e => setCollapsed(e.detail.dir === 'down');
    window.addEventListener('aura:scroll', handler);
    return () => window.removeEventListener('aura:scroll', handler);
  }, []);

  const handleTouchStart = e => {
    touchX.current = e.touches[0].clientX;
    setDragging(true); setSwipeProg(0);
  };
  const handleTouchMove = e => {
    if (touchX.current === null) return;
    const dx = e.touches[0].clientX - touchX.current;
    const pillW = pillRef.current ? pillRef.current.offsetWidth : 280;
    const prog = Math.max(-1, Math.min(1, dx / (pillW / 4)));
    if ((prog < 0 && tabIdx < 3) || (prog > 0 && tabIdx > 0)) setSwipeProg(-prog);
  };
  const handleTouchEnd = e => {
    if (touchX.current === null) return;
    const dx = e.changedTouches[0].clientX - touchX.current;
    touchX.current = null; setDragging(false); setSwipeProg(0);
    if (Math.abs(dx) < 35) return;
    if (dx < 0 && tabIdx < 3) onTab && onTab(ALL_TABS[tabIdx + 1][0]);
    if (dx > 0 && tabIdx > 0) onTab && onTab(ALL_TABS[tabIdx - 1][0]);
  };

  const targetIdx = hoverIdx !== null ? hoverIdx : Math.max(0, Math.min(3, tabIdx + swipeProg));
  // Single indicator: translate based on targetIdx
  const indicatorX = `calc(4px + ${targetIdx} * (100% - 8px) / 4)`;
  const indicatorW = `calc((100% - 8px) / 4)`;

  const barH = collapsed ? 66 : 96;
  const labelStyle = {
    fontSize: collapsed ? 0 : 10, opacity: collapsed ? 0 : 1,
    height: collapsed ? 0 : 'auto', overflow:'hidden', display:'block',
    transition:'all .22s cubic-bezier(.4,0,.2,1)', whiteSpace:'nowrap', fontWeight:600,
  };

  return (
    <>
      {fabOpen && <>
        <div onClick={() => setFabOpen(false)} style={{ position:'absolute', inset:0, zIndex:80 }} />
        <div style={{ position:'absolute', bottom: barH+10, left:0, right:0,
          display:'flex', flexDirection:'column', alignItems:'flex-end',
          gap:10, zIndex:90, padding:'0 16px' }}>
          {ACTIONS.map((a,i) => (
            <button key={a.key} onClick={() => { setFabOpen(false); onAction&&onAction(a.key); }}
              style={{ display:'flex', alignItems:'center', gap:12,
                background:'color-mix(in oklab,var(--bg) 55%,transparent)',
                backdropFilter:'blur(40px) saturate(2.5)', WebkitBackdropFilter:'blur(40px) saturate(2.5)',
                border:'1px solid color-mix(in oklab,var(--text) 14%,transparent)',
                borderRadius:999, padding:'10px 18px 10px 12px',
                cursor:'pointer', fontFamily:'var(--font)', fontWeight:700,
                fontSize:14, color:'var(--text)',
                boxShadow:'0 8px 32px rgba(0,0,0,.22), inset 0 1px 0 rgba(255,255,255,.10)',
                animation:`fabItemIn ${0.06+i*0.05}s ease both` }}>
              <div style={{width:32,height:32,borderRadius:'50%',background:a.color,display:'grid',placeItems:'center',flexShrink:0}}>
                <Icon name={a.icon} size={16} color="#fff" />
              </div>
              {a.label}
            </button>
          ))}
        </div>
      </>}

      <div onTouchStart={handleTouchStart} onTouchMove={handleTouchMove} onTouchEnd={handleTouchEnd}
        style={{ position:'absolute', bottom:0, left:0, right:0, display:'flex', alignItems:'center',
          justifyContent:'center', gap: collapsed ? 6 : 10,
          padding:`0 ${collapsed?8:10}px ${collapsed?30:38}px`,
          background:'transparent', transition:'padding .25s cubic-bezier(.4,0,.2,1)',
          zIndex:20, height: barH }}>

        {/* Glass pill */}
        <div ref={pillRef} style={{
          display:'flex', alignItems:'center', position:'relative', flex:1,
          background:'color-mix(in oklab,var(--text) 5%,transparent)',
          backdropFilter:'blur(40px) saturate(2.5)', WebkitBackdropFilter:'blur(40px) saturate(2.5)',
          border:'1px solid color-mix(in oklab,var(--text) 11%,transparent)',
          borderRadius:999, padding:`${collapsed?3:6}px 3px`, gap:0,
          maxWidth: collapsed ? '72%' : 'calc(100% - 62px)',
          boxShadow:'0 4px 32px rgba(0,0,0,.14), inset 0 1px 0 rgba(255,255,255,.07)',
          overflow:'hidden',
        }}>
          {/* Single sliding orange pill */}
          <div style={{
            position:'absolute', top:4, bottom:4,
            left: indicatorX,
            width: indicatorW,
            background:'var(--accent)',
            borderRadius:999,
            transition: dragging ? 'none' : hoverIdx !== null ? 'left .18s cubic-bezier(.4,0,.2,1)' : 'left .32s cubic-bezier(.4,0,.2,1)',
            boxShadow:'0 2px 14px color-mix(in oklab,var(--accent) 50%,transparent)',
            pointerEvents:'none',
          }} />

          {ALL_TABS.map((t,i) => (
            <button key={t[0]}
              onClick={() => { setFabOpen(false); onTab&&onTab(t[0]); }}
              onMouseEnter={() => setHoverIdx(i)}
              onMouseLeave={() => setHoverIdx(null)}
              style={{
                flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:2,
                padding:`5px 0`, borderRadius:999, border:0, cursor:'pointer',
                background:'transparent', position:'relative', zIndex:1,
                color: active===t[0] ? '#fff' : hoverIdx===i ? 'rgba(255,255,255,0.7)' : 'var(--text-3)',
                transition:'color .2s',
              }}>
              <Icon name={t[2]} size={22} />
              <span style={labelStyle}>{t[1]}</span>
            </button>
          ))}
        </div>

        {/* FAB circle */}
        <button onClick={() => setFabOpen(f=>!f)} style={{
          width:collapsed?34:46, height:collapsed?34:46,
          borderRadius:'50%', border:'1px solid color-mix(in oklab,var(--text) 12%,transparent)',
          cursor:'pointer', flexShrink:0,
          background: fabOpen
            ? 'color-mix(in oklab,var(--bg) 55%,transparent)'
            : 'var(--accent)',
          backdropFilter:'blur(40px)', WebkitBackdropFilter:'blur(40px)',
          boxShadow: fabOpen
            ? '0 2px 16px rgba(0,0,0,.14)'
            : '0 4px 20px color-mix(in oklab,var(--accent) 55%,transparent)',
          display:'grid', placeItems:'center',
          transition:'all .22s cubic-bezier(.4,0,.2,1)',
        }}>
          <Icon name="plus" size={collapsed?15:22}
            color={fabOpen?'var(--text)':'#fff'}
            style={{transition:'transform .2s', transform:fabOpen?'rotate(45deg)':'none'}} />
        </button>
      </div>
    </>
  );
}

/* settings row */
function SetRow({ icon, bg, title, sub, val, right, onClick, danger, last }) {
  return (
    <button className="row" style={{ width: '100%', background: 'var(--surface)', border: 0, textAlign: 'left', cursor: onClick ? 'pointer' : 'default' }} onClick={onClick}>
      {icon && <div className="row-ic" style={{ background: bg || 'var(--text-2)' }}><Icon name={icon} size={16} /></div>}
      <div className="row-main">
        <div className="row-title" style={{ color: danger ? 'var(--red)' : 'var(--text)' }}>{title}</div>
        {sub && <div className="row-sub">{sub}</div>}
      </div>
      {val != null && <div className="row-val">{val}</div>}
      {right || (onClick && !danger ? <Icon name="chevron-right" size={18} color="var(--text-3)" /> : null)}
    </button>
  );
}

function Stepper({ value, onChange, min = 0, max = 99, step = 1, fmt }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <button className="nav-icon-btn" style={{ width: 30, height: 30 }} onClick={() => onChange(Math.max(min, value - step))}><Icon name="minus" size={16} /></button>
      <div style={{ fontWeight: 800, fontSize: 15, minWidth: 56, textAlign: 'center' }}>{fmt ? fmt(value) : value}</div>
      <button className="nav-icon-btn" style={{ width: 30, height: 30, background: 'var(--accent-soft)', color: 'var(--accent)' }} onClick={() => onChange(Math.min(max, value + step))}><Icon name="plus" size={16} /></button>
    </div>
  );
}

Object.assign(window, { AuraToggle: Toggle, AuraSeg: Seg, LineChart, BackNav, AuraTabBar: TabBarEl, SetRow, Stepper });
})();
