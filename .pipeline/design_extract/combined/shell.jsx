/* Aura — app shell: working tab bar + active-workout overlay. */
(function () {
const { useState, useEffect } = React;

function AuraRoot() {
  const [tab, setTab] = useState('log');
  const [workoutOpen, setWorkoutOpen] = useState(false);
  const [inProgress, setInProgress] = useState(false);
  const [dark, setDark] = useState(() => { try { return localStorage.getItem('aura_dark') === '1'; } catch (e) { return false; } });
  const [calStart, setCalStart] = useState(() => { try { return localStorage.getItem('aura_calstart') || 'Sun'; } catch (e) { return 'Sun'; } });
  const [logStat, setLogStat]   = useState(() => { try { return localStorage.getItem('aura_logstat') || 'Both'; } catch (e) { return 'Both'; } });
  const [workoutCfg, setWorkoutCfg] = useState({ name: '', empty: false });
  const onDark = v => { setDark(v); try { localStorage.setItem('aura_dark', v ? '1' : '0'); } catch (e) {} };
  const onCalStart = v => { setCalStart(v); try { localStorage.setItem('aura_calstart', v); } catch (e) {} };
  const onLogStat  = v => { setLogStat(v);  try { localStorage.setItem('aura_logstat',  v); } catch (e) {} };

  // Force every phone surface (incl. Plan & Workout sub-views that hardcode light) to the chosen theme.
  useEffect(() => {
    const want = dark ? 'dark' : 'light';
    const apply = () => document.querySelectorAll('.phone').forEach(el => { if (el.getAttribute('data-theme') !== want) el.setAttribute('data-theme', want); });
    apply();
    const mo = new MutationObserver(apply);
    mo.observe(document.body, { subtree: true, attributes: true, attributeFilter: ['data-theme'], childList: true });
    return () => mo.disconnect();
  }, [dark, tab, workoutOpen]);

  if (workoutOpen) {
    return React.createElement(window.WorkoutApp, {
      onExit: () => { setWorkoutOpen(false); setInProgress(false); setTab('log'); },
      onMinimize: () => { setWorkoutOpen(false); setInProgress(true); setTab('log'); },
      workoutName: workoutCfg.name,
      emptyMode: workoutCfg.empty,
    });
  }

  const startWorkout = (name, empty) => { setWorkoutCfg({ name: name || '', empty: !!empty }); setInProgress(true); setWorkoutOpen(true); };

  if (tab === 'log') return React.createElement(window.LogTab, { tab, onTab: setTab, onStartWorkout: startWorkout, inProgress, dark, calStart });
  if (tab === 'plan') return React.createElement(window.PlanApp, { tab, onTab: setTab, calStart });
  if (tab === 'progress') return React.createElement(window.ProgressTab, { tab, onTab: setTab, dark, onDark, logStat });
  return React.createElement(window.ProfileTab, { tab, onTab: setTab, dark, onDark, calStart, onCalStart, logStat, onLogStat });
}

ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(AuraRoot));
})();
