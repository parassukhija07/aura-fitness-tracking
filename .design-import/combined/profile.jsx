/* Aura — Profile tab: identity + full settings tree. Fully interactive. */
(function () {
const { useState } = React;
const Toggle = window.AuraToggle, Seg = window.AuraSeg, Row = window.SetRow, Stepper = window.Stepper, TabBar = window.AuraTabBar;

function Sheet({ onClose, max, title, children }) {
  return (
    <div className="sheet">
      <div className="scrim" onClick={onClose}></div>
      <div className="sheet-card" style={{ maxHeight: max || '60%' }}>
        <div className="grabber"></div>
        {title && <div className="pad" style={{ paddingBottom: 6 }}><div className="nav-title center">{title}</div></div>}
        <div className="pad" style={{ overflow: 'auto', paddingBottom: 28, scrollbarWidth: 'none' }}>{children}</div>
      </div>
    </div>
  );
}
const fmtRest = s => s < 60 ? s + ' s' : (s % 60 === 0 ? (s / 60) + ' min' : Math.floor(s / 60) + ' min ' + (s % 60) + ' s');

function ProfileTab(props) {
  props = props || {};
  const [screen, setScreen] = useState(null);
  const [sheet, setSheet] = useState(null);
  const [toast, setToast] = useState(null);
  const flash = m => { setToast(m); setTimeout(() => setToast(t => t === m ? null : t), 1800); };
  const [cfg, setCfg] = useState({
    calStart: props.calStart || 'Sun', logStat: props.logStat || 'Both',
    showFirst: 'reps', showWeightFirst: false, showPR: true,
    defSets: 3, defRepsLo: 6, defRepsHi: 10, restSet: 60, restEx: 90, autoRest: true, autoVideo: false,
    notif: true, restSound: 'Ding',
    weightUnit: 'kg', lengthUnit: 'cm',
    apple: true, google: false,
  });
  const set = (k, v) => {
    setCfg(c => ({ ...c, [k]: v }));
    if (k === 'calStart' && props.onCalStart) props.onCalStart(v);
    if (k === 'logStat'  && props.onLogStat)  props.onLogStat(v);
  };
  const [acct, setAcct] = useState({ first: 'Alex', last: 'Carter', email: 'alex@mail.com', phone: '+1 555 0182', bday: '1998-04-03', gender: 'Male', height: 178, country: 'United States', city: 'Austin', state: 'TX' });
  const setA = (k, v) => setAcct(a => ({ ...a, [k]: v }));
  const theme = props.dark ? 'dark' : 'light';

  function head(title) {
    return (
      <div className="navbar bordered">
        <div className="navbar-row">
          <button className="nav-btn" onClick={() => setScreen(null)}><Icon name="chevron-left" size={22} />Profile</button>
          <div className="nav-title" style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)' }}>{title}</div>
          <div style={{ width: 34 }}></div>
        </div>
      </div>
    );
  }
  const sectionLabel = t => <div className="sec-label">{t}</div>;
  const valRow = (title, sub, val) => (
    <div className="row"><div className="row-main"><div className="row-title">{title}</div>{sub && <div className="row-sub">{sub}</div>}</div><div className="row-val">{val}</div></div>
  );
  const toggleRow = (title, sub, k) => (
    <div className="row"><div className="row-main"><div className="row-title">{title}</div>{sub && <div className="row-sub">{sub}</div>}</div><Toggle on={cfg[k]} onChange={v => set(k, v)} /></div>
  );

  /* ── settings screens ──────────────────────────────────────── */
  function general() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('General')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Appearance')}
          <div className="list">
            <div className="row"><div className="row-ic" style={{ background: 'var(--purple)' }}><Icon name="moon" size={15} /></div><div className="row-main"><div className="row-title">Dark Mode</div><div className="row-sub">Applies across the app</div></div><Toggle on={!!props.dark} onChange={v => props.onDark && props.onDark(v)} /></div>
          </div>
          {sectionLabel('Calendar')}
          <div className="list"><div className="row"><div className="row-main"><div className="row-title">Start week on</div></div><Seg style={{ width: 150 }} options={['Sun', 'Mon']} value={cfg.calStart} onChange={v => set('calStart', v)} /></div></div>
          {sectionLabel('Log page')}
          <div className="list"><div className="row" style={{ display: 'block' }}><div className="row-title" style={{ marginBottom: 10 }}>Show on progress</div><Seg options={[{ v: 'Score', l: 'Strength score' }, { v: 'Balance', l: 'Balance' }, { v: 'Both', l: 'Both' }]} value={cfg.logStat} onChange={v => set('logStat', v)} /></div></div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function workout() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Workout')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Display')}
          <div className="list">
            <div className="row" style={{ display: 'block' }}><div className="row-title" style={{ marginBottom: 10 }}>Show first</div><Seg options={[{ v: 'reps', l: 'Reps / time' }, { v: 'weight', l: 'Weight' }]} value={cfg.showFirst} onChange={v => set('showFirst', v)} /></div>
            {toggleRow('Show PRs during workout', 'Surface your records inline', 'showPR')}
          </div>
          {sectionLabel('Exercise targets')}
          <div className="list">
            <div className="row"><div className="row-main"><div className="row-title">Default sets</div></div><Stepper value={cfg.defSets} min={1} max={10} onChange={v => set('defSets', v)} /></div>
            <div className="row"><div className="row-main"><div className="row-title">Default rep range</div></div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <Stepper value={cfg.defRepsLo} min={1} max={cfg.defRepsHi} onChange={v => set('defRepsLo', v)} />
                <span className="muted">–</span>
                <Stepper value={cfg.defRepsHi} min={cfg.defRepsLo} max={30} onChange={v => set('defRepsHi', v)} />
              </div>
            </div>
            <div className="row"><div className="row-main"><div className="row-title">Rest between sets</div></div><Stepper value={cfg.restSet} min={15} max={300} step={15} onChange={v => set('restSet', v)} fmt={fmtRest} /></div>
            <div className="row"><div className="row-main"><div className="row-title">Rest between exercises</div></div><Stepper value={cfg.restEx} min={15} max={300} step={15} onChange={v => set('restEx', v)} fmt={fmtRest} /></div>
          </div>
          {sectionLabel('Automation')}
          <div className="list">
            {toggleRow('Auto rest timer', 'Start timer after each set', 'autoRest')}
            {toggleRow('Auto-play video', 'Play demo when opening an exercise', 'autoVideo')}
          </div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function account() {
    const field = (label, k, type) => (
      <div className="field" style={{ marginBottom: 0 }}><label>{label}</label><input type={type || 'text'} value={acct[k]} onChange={e => setA(k, e.target.value)} /></div>
    );
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Account Details')}
        <div className="screen-body pad pad-b">
          <div className="center" style={{ margin: '14px 0 6px' }}>
            <div style={{ width: 78, height: 78, borderRadius: '50%', background: 'linear-gradient(150deg,var(--accent),oklch(0.62 0.16 40))', display: 'grid', placeItems: 'center', color: '#fff', fontWeight: 800, fontSize: 28, margin: '0 auto' }}>{acct.first[0]}{acct.last[0]}</div>
            <button className="btn-ghost tiny" style={{ fontWeight: 700, marginTop: 8 }} onClick={() => flash('Photo picker')}>Change photo</button>
          </div>
          {sectionLabel('Name')}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>{field('First', 'first')}{field('Last', 'last')}</div>
          {sectionLabel('Contact')}
          <div className="col" style={{ gap: 12 }}>{field('Email', 'email', 'email')}{field('Phone', 'phone')}</div>
          {sectionLabel('About')}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {field('Birthday', 'bday', 'date')}
            <div className="field" style={{ marginBottom: 0 }}><label>Gender</label><select value={acct.gender} onChange={e => setA('gender', e.target.value)}><option>Male</option><option>Female</option><option>Other</option></select></div>
            <div className="field" style={{ marginBottom: 0 }}><label>Height (cm)</label><input inputMode="numeric" value={acct.height} onChange={e => setA('height', e.target.value)} /></div>
            {field('Country', 'country')}
            {field('City', 'city')}
            {field('State', 'state')}
          </div>
          {sectionLabel('Data')}
          <div className="list">
            <Row icon="arrow-up" bg="var(--blue)" title="Export Data" sub="Download all your workout data" onClick={() => setSheet({ kind: 'export' })} />
            <Row icon="swap" bg="var(--text-2)" title="Reset Data" sub="Clear workouts or everything" onClick={() => setSheet({ kind: 'reset' })} />
          </div>
          <div className="list" style={{ marginTop: 12 }}>
            <Row icon="trash" bg="var(--red)" title="Delete Account" danger onClick={() => setSheet({ kind: 'delete' })} />
          </div>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => { setScreen(null); flash('Account saved'); }}>Save Changes</button>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function notifications() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Notifications')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Notifications')}
          <div className="list">{toggleRow('Enable notifications', 'Reminders, streaks and updates', 'notif')}</div>
          {sectionLabel('Rest timer sound')}
          <div className="list" style={{ opacity: cfg.notif ? 1 : 0.45, pointerEvents: cfg.notif ? 'auto' : 'none' }}>
            {['Ding', 'Alarm clock'].map(s => (
              <button key={s} className="row" style={{ width: '100%', background: 'var(--surface)', border: 0, textAlign: 'left', cursor: 'pointer' }} onClick={() => { set('restSound', s); flash(s + ' selected'); }}>
                <div className="row-ic" style={{ background: 'var(--blue)' }}><Icon name="timer" size={15} /></div>
                <div className="row-main"><div className="row-title">{s}</div></div>
                {cfg.restSound === s ? <Icon name="check" size={18} color="var(--accent)" /> : <span style={{ width: 18 }}></span>}
              </button>
            ))}
          </div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function units() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Units & Measurements')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Weight')}
          <div className="list"><div className="row"><div className="row-main"><div className="row-title">Weight unit</div></div><Seg style={{ width: 150 }} options={[{ v: 'kg', l: 'Kilograms' }, { v: 'lb', l: 'Pounds' }]} value={cfg.weightUnit} onChange={v => set('weightUnit', v)} /></div></div>
          {sectionLabel('Length')}
          <div className="list"><div className="row"><div className="row-main"><div className="row-title">Length unit</div></div><Seg style={{ width: 175 }} options={[{ v: 'cm', l: 'Centimeters' }, { v: 'in', l: 'Inches' }]} value={cfg.lengthUnit} onChange={v => set('lengthUnit', v)} /></div></div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function connected() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Connected Apps')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Health integrations')}
          <div className="list">
            <div className="row"><div className="row-ic" style={{ background: 'var(--red)' }}><Icon name="flame" size={15} /></div><div className="row-main"><div className="row-title">Apple Health</div><div className="row-sub">{cfg.apple ? 'Connected' : 'Not connected'}</div></div><Toggle on={cfg.apple} onChange={v => set('apple', v)} /></div>
            <div className="row"><div className="row-ic" style={{ background: 'var(--green)' }}><Icon name="target" size={15} /></div><div className="row-main"><div className="row-title">Google Health</div><div className="row-sub">{cfg.google ? 'Connected' : 'Not connected'}</div></div><Toggle on={cfg.google} onChange={v => set('google', v)} /></div>
          </div>
          <div className="hint-card" style={{ marginTop: 14 }}><Icon name="info" size={18} color="var(--text-2)" /><div className="tiny muted" style={{ lineHeight: 1.5 }}>Aura syncs workouts and body weight both ways with your connected health app.</div></div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }
  function support() {
    return (
      <div className="phone" data-theme={theme}>
        <div className="dynamic-island"></div><div className="statusbar auto"></div>{head('Support')}
        <div className="screen-body pad pad-b">
          {sectionLabel('Get help')}
          <div className="list">
            <Row icon="note" bg="var(--accent)" title="User Guides & FAQ" onClick={() => flash('Opening guides…')} />
            <Row icon="person" bg="var(--blue)" title="Contact Us" onClick={() => flash('Opening contact form…')} />
            <Row icon="sparkle" bg="var(--purple)" title="Feature Request" onClick={() => flash('Opening request form…')} />
          </div>
          <div className="tiny muted center" style={{ marginTop: 22 }}>Aura Fitness · v2.4.0</div>
        </div>
        <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} /><div className="home-indicator"></div>
      </div>
    );
  }

  if (screen === 'general') return general();
  if (screen === 'workout') return workout();
  if (screen === 'account') return account();
  if (screen === 'notifications') return notifications();
  if (screen === 'units') return units();
  if (screen === 'connected') return connected();
  if (screen === 'support') return support();

  /* ── confirm sheets ────────────────────────────────────────── */
  function sheetEl() {
    if (!sheet) return null;
    if (sheet.kind === 'export') {
      return (
        <Sheet onClose={() => setSheet(null)} title="Export Data" max="48%">
          <div className="tiny muted center" style={{ marginBottom: 16, lineHeight: 1.5 }}>Download a full copy of your workouts, measurements and settings as a CSV + JSON archive.</div>
          <button className="btn btn-primary" onClick={() => { setSheet(null); flash('Export started'); }}>Export Archive</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }
    if (sheet.kind === 'reset') {
      return (
        <Sheet onClose={() => setSheet(null)} title="Reset Data" max="52%">
          <div className="list">
            <Row icon="dumbbell" bg="var(--text-2)" title="Reset workout data only" sub="Keeps your profile & settings" onClick={() => { setSheet(null); flash('Workout data reset'); }} />
          </div>
          <div className="list" style={{ marginTop: 12 }}>
            <Row icon="trash" bg="var(--red)" title="Reset everything" danger onClick={() => { setSheet(null); flash('All data reset'); }} />
          </div>
          <button className="btn btn-gray" style={{ marginTop: 14 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }
    if (sheet.kind === 'delete' || sheet.kind === 'logout') {
      const del = sheet.kind === 'delete';
      return (
        <Sheet onClose={() => setSheet(null)} max="50%">
          <div className="center" style={{ margin: '4px 0 16px' }}>
            <div style={{ width: 52, height: 52, borderRadius: '50%', background: 'color-mix(in oklab,var(--red) 12%,transparent)', display: 'grid', placeItems: 'center', color: 'var(--red)', margin: '0 auto 12px' }}><Icon name={del ? 'trash' : 'person'} size={24} /></div>
            <div style={{ fontWeight: 800, fontSize: 18 }}>{del ? 'Delete account?' : 'Log out?'}</div>
            <div className="tiny muted" style={{ marginTop: 6, lineHeight: 1.5, maxWidth: 260, margin: '6px auto 0' }}>{del ? 'This permanently erases your account and all data. This cannot be undone.' : 'You can log back in anytime with your email.'}</div>
          </div>
          <button className={'btn ' + (del ? 'btn-danger' : 'btn-primary')} onClick={() => { setSheet(null); flash(del ? 'Account deleted' : 'Logged out'); }}>{del ? 'Delete Account' : 'Log Out'}</button>
          <button className="btn btn-gray" style={{ marginTop: 10 }} onClick={() => setSheet(null)}>Cancel</button>
        </Sheet>
      );
    }
    return null;
  }

  /* ── root ──────────────────────────────────────────────────── */
  const groups = [
    [['moon', 'var(--purple)', 'General', 'Appearance, calendar, log page', 'general'], ['dumbbell', 'var(--accent)', 'Workout', 'Targets, rest timer, display', 'workout'], ['timer', 'var(--blue)', 'Notifications', 'Reminders & rest sounds', 'notifications']],
    [['person', 'var(--text-2)', 'Account Details', 'Name, contact, export, delete', 'account'], ['target', 'var(--green)', 'Units & Measurements', cfg.weightUnit + ' · ' + cfg.lengthUnit, 'units'], ['flame', 'var(--red)', 'Connected Apps', cfg.apple ? 'Apple Health connected' : 'None connected', 'connected']],
    [['info', 'var(--text-2)', 'Support', 'Guides, FAQ, contact', 'support']],
  ];
  return (
    <div className="phone" data-theme={theme}>
      <div className="dynamic-island"></div>
      <div className="statusbar auto"></div>
      <div className="navbar"><div className="navbar-row"><div className="nav-title-lg">Profile</div></div></div>
      <div className="screen-body pad pad-b">
        <button className="card card-pad" style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 12, width: '100%', textAlign: 'left', cursor: 'pointer' }} onClick={() => setScreen('account')}>
          <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'linear-gradient(150deg,var(--accent),oklch(0.62 0.16 40))', display: 'grid', placeItems: 'center', color: '#fff', fontWeight: 800, fontSize: 22, flex: '0 0 auto' }}>{acct.first[0]}{acct.last[0]}</div>
          <div className="grow">
            <div style={{ fontSize: 19, fontWeight: 800, letterSpacing: '-.01em', color: 'var(--text)' }}>{acct.first} {acct.last}</div>
            <div className="tiny muted" style={{ marginTop: 2 }}>28 · {acct.height} cm · 78.4 kg · {acct.gender}</div>
          </div>
          <Icon name="chevron-right" size={18} color="var(--text-3)" />
        </button>
        <div className="flex" style={{ gap: 10, marginTop: 12 }}>
          {[['142', 'Sessions'], ['37', 'PRs'], ['18', 'Week streak']].map(s => (
            <div key={s[1]} className="card card-pad grow center" style={{ padding: 13 }}><div className="stat-num" style={{ fontSize: 22 }}>{s[0]}</div><div className="tiny muted" style={{ marginTop: 2 }}>{s[1]}</div></div>
          ))}
        </div>
        {groups.map((g, gi) => (
          <div className="list" key={gi} style={{ marginTop: 16 }}>
            {g.map(r => <Row key={r[4]} icon={r[0]} bg={r[1]} title={r[2]} sub={r[3]} onClick={() => setScreen(r[4])} />)}
          </div>
        ))}
        <button className="btn btn-danger" style={{ marginTop: 16 }} onClick={() => setSheet({ kind: 'logout' })}><Icon name="swap" size={17} /> Log Out</button>
      </div>
      {sheetEl()}
      {toast && <div style={{ position: 'absolute', bottom: 100, left: '50%', transform: 'translateX(-50%)', background: 'var(--text)', color: 'var(--bg)', fontSize: 13, fontWeight: 600, padding: '9px 16px', borderRadius: 999, zIndex: 90, boxShadow: '0 8px 24px rgba(0,0,0,.22)', whiteSpace: 'nowrap' }}>{toast}</div>}
      <TabBar active='profile' onTab={props.onTab} onAction={k => { props.onTab && props.onTab(k==='measure'||k==='photo'?'progress':'log'); }} />
      <div className="home-indicator"></div>
    </div>
  );
}

window.ProfileTab = ProfileTab;
})();
