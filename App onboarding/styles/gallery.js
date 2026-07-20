/* AURA gallery — theme toggle shared by all screen pages. */
function toggleTheme(){
  const dark = document.body.classList.toggle('viewer-dark');
  document.querySelectorAll('.phone').forEach(p=>p.setAttribute('data-theme', dark?'dark':'light'));
  const m=document.getElementById('tmode'); if(m) m.textContent = dark ? 'Light' : 'Dark';
}
