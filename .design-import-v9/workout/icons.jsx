/* Active Workout — Icon component (React). Subset of the shared icon set. */
const ICONS = {
  'x':'<path d="M6 6l12 12M18 6L6 18"/>',
  'x-c':'<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
  'check':'<path d="M5 12.5l4.5 4.5L19 7"/>',
  'check-c':'<circle cx="12" cy="12" r="9"/><path d="M8.5 12.2l2.5 2.5 4.5-4.8"/>',
  'play':'<path d="M7 5l12 7-12 7z" fill="currentColor" stroke="none"/>',
  'play-c':'<circle cx="12" cy="12" r="9"/><path d="M10 8.5l6 3.5-6 3.5z" fill="currentColor" stroke="none"/>',
  'pause':'<rect x="7" y="5" width="3.5" height="14" rx="1" fill="currentColor" stroke="none"/><rect x="13.5" y="5" width="3.5" height="14" rx="1" fill="currentColor" stroke="none"/>',
  'plus':'<path d="M12 5v14M5 12h14"/>',
  'plus-c':'<circle cx="12" cy="12" r="9"/><path d="M12 8.5v7M8.5 12h7"/>',
  'minus':'<path d="M5 12h14"/>',
  'ellipsis':'<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>',
  'timer':'<circle cx="12" cy="13" r="8"/><path d="M12 13V9M9 2h6"/>',
  'clock':'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
  'chevron-left':'<path d="M15 6l-6 6 6 6"/>',
  'chevron-right':'<path d="M9 6l6 6-6 6"/>',
  'chevron-down':'<path d="M6 9l6 6 6-6"/>',
  'swap':'<path d="M7 4L3 8l4 4M3 8h13M17 20l4-4-4-4M21 16H8"/>',
  'trash':'<path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13"/>',
  'note':'<path d="M5 4h14v16l-4-3H5z"/><path d="M9 9h6M9 12.5h4"/>',
  'flame':'<path d="M12 3c1 3-1.5 4.5-1.5 7A2.5 2.5 0 0 0 13 12c.5-.7.5-1.5.5-1.5 1.5 1.2 3 3 3 5.5a4.5 4.5 0 0 1-9 0c0-3 2.5-4.5 4-7 .3 1 1 1.5 1.5 2"/>',
  'trophy':'<path d="M7 4h10v3a5 5 0 0 1-10 0zM7 5H4v1a3 3 0 0 0 3 3M17 5h3v1a3 3 0 0 1-3 3M9.5 12.5L9 17h6l-.5-4.5M8 20h8M10 17v3M14 17v3"/>',
  'medal':'<circle cx="12" cy="14" r="6"/><path d="M9 3l3 5 3-5M12 11.5l1 2 2 .2-1.5 1.5.4 2L12 16.2 10.1 17.2l.4-2L9 13.7l2-.2z"/>',
  'target':'<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/>',
  'info':'<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.5v.5"/>',
  'sparkle':'<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
  'grip':'<circle cx="9" cy="8" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="8" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="16" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="16" r="1.4" fill="currentColor" stroke="none"/>',
  'search':'<circle cx="11" cy="11" r="7"/><path d="M17 17l4 4"/>',
  'cable':'<path d="M12 3v6M9 9h6v3a3 3 0 0 1-6 0zM12 15v3a3 3 0 0 0 3 3"/>',
  'add-set':'<path d="M4 6h10M4 12h7M4 18h10M17 14v6M14 17h6"/>',
  'bulb':'<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.2 1 2.5h6c0-1.3.3-1.8 1-2.5A6 6 0 0 0 12 3z"/>',
  'bolt':'<path d="M13 2L4 14h7l-1 8 9-12h-7z" fill="currentColor" stroke="none"/>',
  'minus-c':'<circle cx="12" cy="12" r="9"/><path d="M8.5 12h7"/>',
  'arrow-up':'<path d="M12 19V5M6 11l6-6 6 6"/>',
  'log':'<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 7h6M9 11h6M9 15h4"/>',
  'dumbbell':'<rect x="3" y="9" width="3" height="6" rx="1.5"/><rect x="18" y="9" width="3" height="6" rx="1.5"/><path d="M6 12h12M6 9V7a1 1 0 0 1 2 0v10a1 1 0 0 1-2 0v-2M18 9V7a1 1 0 0 0-2 0v10a1 1 0 0 0 2 0v-2"/>',
  'chart':'<path d="M4 20V13M9 20V8M14 20v-5M19 20V4"/>',
  'person':'<circle cx="12" cy="7" r="4"/><path d="M4 21c0-4.4 3.6-8 8-8s8 3.6 8 8"/>',
  'edit':'<path d="M11 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5"/><path d="M17.5 2.5a2.12 2.12 0 0 1 3 3L12 14l-4 1 1-4z"/>',
  'moon':'<path d="M21 12.8A9 9 0 0 1 11.2 3a7 7 0 1 0 9.8 9.8z"/>',
  'calendar-day':'<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/>',
};
function Icon({ name, size = 22, color, style, className }) {
  return React.createElement('span', {
    className, style: { display:'inline-flex', color, lineHeight:0, ...style },
    dangerouslySetInnerHTML: { __html:
      `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${ICONS[name]||''}</svg>` }
  });
}
window.Icon = Icon;
