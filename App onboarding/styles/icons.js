/* AURA — shared UI helpers: SVG icons + auto status bar.
   Usage: <i data-ic="calendar"></i>  ·  <div class="statusbar auto"></div> */
(function () {
  const P = {
    // tabs
    'log':       '<path d="M8 2v3M16 2v3M3.5 9h17"/><rect x="3.5" y="4.5" width="17" height="16" rx="3"/><path d="M7.5 13.5h3M7.5 17h3M14 13.5h2.5"/>',
    'dumbbell':  '<path d="M6.5 6.5l11 11M4 9l-1.5 1.5a2 2 0 0 0 0 2.8L4 14.8M9 4l-1.2 1.2M20 15l1.5-1.5a2 2 0 0 0 0-2.8L20 9.2M15 20l1.2-1.2"/>',
    'chart':     '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    'person':    '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.5-7 8-7s8 3 8 7"/>',
    // ui
    'chevron-right':'<path d="M9 6l6 6-6 6"/>',
    'chevron-left': '<path d="M15 6l-6 6 6 6"/>',
    'chevron-down': '<path d="M6 9l6 6 6-6"/>',
    'chevron-up':   '<path d="M6 15l6-6 6 6"/>',
    'plus':      '<path d="M12 5v14M5 12h14"/>',
    'plus-c':    '<circle cx="12" cy="12" r="9"/><path d="M12 8.5v7M8.5 12h7"/>',
    'minus':     '<path d="M5 12h14"/>',
    'minus-c':   '<circle cx="12" cy="12" r="9"/><path d="M8.5 12h7"/>',
    'x':         '<path d="M6 6l12 12M18 6L6 18"/>',
    'x-c':       '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
    'check':     '<path d="M5 12.5l4.5 4.5L19 7"/>',
    'check-c':   '<circle cx="12" cy="12" r="9"/><path d="M8.5 12.2l2.5 2.5 4.5-4.8"/>',
    'search':    '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    'filter':    '<path d="M3 5h18M6 12h12M10 19h4"/>',
    'ellipsis':  '<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>',
    'play':      '<path d="M7 5l12 7-12 7z" fill="currentColor" stroke="none"/>',
    'play-c':    '<circle cx="12" cy="12" r="9"/><path d="M10 8.5l6 3.5-6 3.5z" fill="currentColor" stroke="none"/>',
    'pause':     '<rect x="7" y="5" width="3.5" height="14" rx="1" fill="currentColor" stroke="none"/><rect x="13.5" y="5" width="3.5" height="14" rx="1" fill="currentColor" stroke="none"/>',
    'calendar':  '<rect x="3.5" y="4.5" width="17" height="16" rx="3"/><path d="M8 2v4M16 2v4M3.5 9h17"/>',
    'calendar-day':'<rect x="3.5" y="4.5" width="17" height="16" rx="3"/><path d="M8 2v4M16 2v4M3.5 9h17"/><rect x="7" y="12" width="4" height="4" rx="1" fill="currentColor" stroke="none"/>',
    'timer':     '<circle cx="12" cy="13" r="8"/><path d="M12 13V9M9 2h6"/>',
    'clock':     '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    'flame':     '<path d="M12 3c1 3-1.5 4.5-1.5 7A2.5 2.5 0 0 0 13 12c.5-.7.5-1.5.5-1.5 1.5 1.2 3 3 3 5.5a4.5 4.5 0 0 1-9 0c0-3 2.5-4.5 4-7 .3 1 1 1.5 1.5 2"/>',
    'trophy':    '<path d="M7 4h10v3a5 5 0 0 1-10 0zM7 5H4v1a3 3 0 0 0 3 3M17 5h3v1a3 3 0 0 1-3 3M9.5 12.5L9 17h6l-.5-4.5M8 20h8M10 17v3M14 17v3"/>',
    'medal':     '<circle cx="12" cy="14" r="6"/><path d="M9 3l3 5 3-5M12 11.5l1 2 2 .2-1.5 1.5.4 2L12 16.2 10.1 17.2l.4-2L9 13.7l2-.2z"/>',
    'edit':      '<path d="M4 20h4L18.5 9.5a2 2 0 0 0-3-3L5 17v3z"/><path d="M14 7l3 3"/>',
    'trash':     '<path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13"/>',
    'swap':      '<path d="M7 4L3 8l4 4M3 8h13M17 20l4-4-4-4M21 16H8"/>',
    'swap-v':    '<path d="M8 3v18M8 21l-3-3M8 21l3-3M16 21V3M16 3l-3 3M16 3l3 3"/>',
    'gear':      '<circle cx="12" cy="12" r="3"/><path d="M12 2l1.2 2.4 2.6-.6.4 2.6L19 8l-1.4 2.2L19 12.4 16.2 14l-.4 2.6-2.6-.6L12 18.4 10.8 16l-2.6.6L7.8 14 5 12.4 6.4 10.2 5 8l2.8-1.6.4-2.6 2.6.6z"/>',
    'bell':      '<path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6M10 20a2 2 0 0 0 4 0"/>',
    'info':      '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.5v.5"/>',
    'question':  '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.8.4-1 1-1 1.7M12 16.5v.3"/>',
    'heart':     '<path d="M12 20S4 15 4 9.5A4 4 0 0 1 12 7a4 4 0 0 1 8 2.5C20 15 12 20 12 20z"/>',
    'note':      '<path d="M5 4h14v16l-4-3H5z"/><path d="M9 9h6M9 12.5h4"/>',
    'plus-note': '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 9v6M9 12h6"/>',
    'grip':      '<circle cx="9" cy="7" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="7" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="17" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="17" r="1.4" fill="currentColor" stroke="none"/>',
    'target':    '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/>',
    'sparkle':   '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
    'scale':     '<path d="M12 3v3M5 7h14M7 7l-3 7a3 3 0 0 0 6 0l-3-7zM17 7l-3 7a3 3 0 0 0 6 0l-3-7zM8 21h8"/>',
    'ruler':     '<rect x="3" y="8" width="18" height="8" rx="2"/><path d="M7 8v3M11 8v4M15 8v3M19 8v4"/>',
    'apple-h':   '<path d="M12 7c1-3 6-3 6 1 0 3-4 6-6 8-2-2-6-5-6-8 0-4 5-4 6-1z"/>',
    'camera':    '<rect x="3" y="7" width="18" height="13" rx="3"/><circle cx="12" cy="13.5" r="3.5"/><path d="M8 7l1.5-3h5L16 7"/>',
    'photo':     '<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="8.5" cy="10" r="1.8"/><path d="M5 18l5-4 3 2 3-3 4 4"/>',
    'bolt':      '<path d="M13 2L4 14h7l-1 8 9-12h-7z" fill="currentColor" stroke="none"/>',
    'bulb':      '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.2 1 2.5h6c0-1.3.3-1.8 1-2.5A6 6 0 0 0 12 3z"/>',
    'arrow-up':  '<path d="M12 19V5M6 11l6-6 6 6"/>',
    'arrow-down':'<path d="M12 5v14M6 13l6 6 6-6"/>',
    'logout':    '<path d="M14 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h8M16 16l4-4-4-4M20 12H9"/>',
    'export':    '<path d="M12 3v12M8 7l4-4 4 4M5 14v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4"/>',
    'shield':    '<path d="M12 3l8 3v5c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6z"/>',
    'reset':     '<path d="M4 4v5h5M20 20v-5h-5"/><path d="M19 9a8 8 0 0 0-14-2L4 9M5 15a8 8 0 0 0 14 2l1-2"/>',
    'mail':      '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M4 7l8 6 8-6"/>',
    'phone':     '<path d="M5 4h4l2 5-3 2a12 12 0 0 0 5 5l2-3 5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
    'globe':     '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 2.5 15 0 18M12 3c-2.5 2.5-2.5 15 0 18"/>',
    'moon':      '<path d="M20 13A8 8 0 0 1 9 4a7 7 0 1 0 11 9z"/>',
    'link':      '<path d="M9 15l6-6M10 6l1-1a4 4 0 0 1 6 6l-1 1M14 18l-1 1a4 4 0 0 1-6-6l1-1"/>',
    'cable':     '<path d="M12 3v6M9 9h6v3a3 3 0 0 1-6 0zM12 15v3a3 3 0 0 0 3 3"/>',
    'water':     '<path d="M12 3c4 5 6 8 6 11a6 6 0 0 1-12 0c0-3 2-6 6-11z"/>',
    'egg':       '<path d="M12 3c3.5 0 6 5 6 9a6 6 0 0 1-12 0c0-4 2.5-9 6-9z"/>',
    'wheat':     '<path d="M12 21V8M12 8c0-2 1.5-3 1.5-3M12 8c0-2-1.5-3-1.5-3M12 12c1.5 0 2.5-1 2.5-1M12 12c-1.5 0-2.5-1-2.5-1M12 16c1.5 0 2.5-1 2.5-1M12 16c-1.5 0-2.5-1-2.5-1"/>',
    'rest':      '<path d="M5 12h4l1-2 2 4 1-2h6"/>',
    'add-set':   '<path d="M4 6h10M4 12h7M4 18h10M17 14v6M14 17h6"/>',
    'history':   '<path d="M3 12a9 9 0 1 0 3-6.7L3 8m0-5v5h5"/><path d="M12 8v4l3 2"/>',swap2:'',
  };
  function svg(name) {
    const d = P[name];
    if (d == null) return '';
    const filled = /fill="currentColor"/.test(d) && !/<path d="[^"]*"\/>/.test(d);
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  }
  function paint() {
    document.querySelectorAll('[data-ic]').forEach(el => {
      if (el.dataset.icDone) return;
      const s = el.dataset.ic;
      const size = el.dataset.size || 22;
      el.innerHTML = svg(s);
      const g = el.querySelector('svg');
      if (g) { g.style.width = size + 'px'; g.style.height = size + 'px'; g.style.display = 'block'; }
      el.style.display = el.style.display || 'inline-flex';
      el.dataset.icDone = '1';
    });
    // auto status bar
    document.querySelectorAll('.statusbar.auto').forEach(el => {
      if (el.dataset.sbDone) return;
      const t = el.dataset.time || '9:41';
      el.innerHTML =
        `<div class="sb-left">${t}</div>` +
        `<div class="sb-right">` +
          `<svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="4.5" width="3" height="7.5" rx="1"/><rect x="10" y="2" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>` +
          `<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.5C11 2.5 13.2 3.5 15 5.2l1.4-1.5C14.2 1.5 11.5.3 8.5.3S2.8 1.5.6 3.7L2 5.2C3.8 3.5 6 2.5 8.5 2.5z" opacity=".9"/><path d="M8.5 6c1.3 0 2.5.5 3.4 1.4l-3.4 3.5L5.1 7.4C6 6.5 7.2 6 8.5 6z"/></svg>` +
          `<svg width="27" height="13" viewBox="0 0 27 13" fill="none"><rect x="0.5" y="0.5" width="22" height="12" rx="3.5" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/><rect x="24" y="4" width="2" height="5" rx="1" fill="currentColor" opacity=".4"/></svg>` +
        `</div>`;
      el.dataset.sbDone = '1';
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', paint);
  else paint();
  window.AuraPaint = paint;
  window.AURA_ICONS = P;
  window.auraSvg = svg;
})();
