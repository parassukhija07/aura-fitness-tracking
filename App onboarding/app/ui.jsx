/* AURA APP — shared UI: Icon, nav context, NavBar, TabBar, Sheet, controls. */
const { createContext: createCtx, useContext: useCtx, useState: uS, useEffect: uE } = React;

function Icon({name,size=22,color,style,className,onClick}){
  return React.createElement('span',{className,onClick,
    style:{display:'inline-flex',color,lineHeight:0,flex:'0 0 auto',...style},
    dangerouslySetInnerHTML:{__html:(window.auraSvg?window.auraSvg(name):'')}},);
}
// auraSvg returns full svg but width fixed 24; wrap to set size
function IconSized(p){ const html=(window.AURA_ICONS&&window.AURA_ICONS[p.name])||'';
  return React.createElement('span',{className:p.className,onClick:p.onClick,
    style:{display:'inline-flex',color:p.color,lineHeight:0,flex:'0 0 auto',...p.style},
    dangerouslySetInnerHTML:{__html:`<svg width="${p.size||22}" height="${p.size||22}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${html}</svg>`}});
}
window.Icon = IconSized;

/* ---------- navigation ---------- */
const Nav = createCtx(null);
const useNav = ()=>useCtx(Nav);

function StatusBar({dark}){
  return React.createElement('div',{className:'statusbar',style:{color:'var(--text)'}},
    React.createElement('div',{className:'sb-left'},'9:41'),
    React.createElement('div',{className:'sb-right',dangerouslySetInnerHTML:{__html:
      `<svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="4.5" width="3" height="7.5" rx="1"/><rect x="10" y="2" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>`+
      `<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.5C11 2.5 13.2 3.5 15 5.2l1.4-1.5C14.2 1.5 11.5.3 8.5.3S2.8 1.5.6 3.7L2 5.2C3.8 3.5 6 2.5 8.5 2.5z"/><path d="M8.5 6c1.3 0 2.5.5 3.4 1.4l-3.4 3.5L5.1 7.4C6 6.5 7.2 6 8.5 6z"/></svg>`+
      `<svg width="27" height="13" viewBox="0 0 27 13" fill="none"><rect x="0.5" y="0.5" width="22" height="12" rx="3.5" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/><rect x="24" y="4" width="2" height="5" rx="1" fill="currentColor" opacity=".4"/></svg>`}}));
}

function NavBar({title,large,sub,onBack,backLabel='Back',right,left}){
  return React.createElement('div',{className:'navbar'+(large?'':' bordered')},
    React.createElement('div',{className:'navbar-row'},
      onBack
        ? React.createElement('button',{className:'nav-btn',onClick:onBack},React.createElement(Icon,{name:'chevron-left',size:22}),backLabel)
        : (left||React.createElement('div',null)),
      large
        ? React.createElement('div',{style:{flex:1}})
        : React.createElement('div',{className:'nav-title',style:{position:'absolute',left:'50%',transform:'translateX(-50%)'}},title),
      right||React.createElement('div',{style:{width:34}})
    ),
    large&&React.createElement('div',null,
      sub&&React.createElement('div',{className:'tiny muted',style:{fontWeight:700,letterSpacing:'.02em'}},sub),
      React.createElement('div',{className:'nav-title-lg'},title))
  );
}

function TabBar(){
  const {tab,setTab} = useNav();
  const tabs=[['log','Log','log'],['plan','Plan','dumbbell'],['progress','Progress','chart'],['profile','Profile','person']];
  return React.createElement('div',{className:'tabbar'},
    tabs.map(([id,label,ic])=>React.createElement('button',{key:id,className:'tab'+(tab===id?' active':''),onClick:()=>setTab(id)},
      React.createElement(Icon,{name:ic,size:25}),React.createElement('span',null,label))));
}

function Sheet({title,onClose,children,max='72%',pad=true}){
  return React.createElement('div',{className:'sheet'},
    React.createElement('div',{className:'scrim',onClick:onClose}),
    React.createElement('div',{className:'sheet-card',style:{maxHeight:max}},
      React.createElement('div',{className:'grabber'}),
      title&&React.createElement('div',{className:'between pad',style:{paddingBottom:8}},
        React.createElement('div',{className:'nav-title'},title),
        React.createElement('button',{className:'nav-icon-btn',onClick:onClose},React.createElement(Icon,{name:'x',size:18}))),
      React.createElement('div',{className:pad?'pad':'',style:{overflow:'auto',paddingBottom:26}},children)));
}

/* ---------- controls ---------- */
function Toggle({on,onClick}){ return React.createElement('div',{className:'toggle'+(on?' on':''),onClick}); }
function Seg({options,value,onChange,style}){
  return React.createElement('div',{className:'segmented',style},
    options.map(o=>{const v=typeof o==='string'?o:o.v,l=typeof o==='string'?o:o.l;
      return React.createElement('button',{key:v,className:value===v?'active':'',onClick:()=>onChange(v)},l);}));
}
function Row({icon,iconBg,title,sub,val,right,onClick,danger,accent}){
  return React.createElement('button',{className:'row',style:{width:'100%',background:'var(--surface)',border:0,textAlign:'left',cursor:onClick?'pointer':'default'},onClick},
    icon&&React.createElement('div',{className:'row-ic',style:{background:iconBg||'var(--text-2)'}},React.createElement(Icon,{name:icon,size:16})),
    React.createElement('div',{className:'row-main'},
      React.createElement('div',{className:'row-title',style:{color:danger?'var(--red)':accent?'var(--accent)':'var(--text)'}},title),
      sub&&React.createElement('div',{className:'row-sub'},sub)),
    val!=null&&React.createElement('div',{className:'row-val'},val),
    right||(onClick&&!danger?React.createElement(Icon,{name:'chevron-right',size:18,color:'var(--text-3)'}):null));
}
function PH({label,style,className=''}){ return React.createElement('div',{className:'ph rounded '+className,style},label); }

function Search({placeholder,value,onChange}){
  return React.createElement('div',{className:'search'},React.createElement(Icon,{name:'search',size:18}),
    React.createElement('input',{placeholder,value:value||'',onChange:e=>onChange&&onChange(e.target.value)}));
}

Object.assign(window,{Nav,useNav,StatusBar,NavBar,TabBar,Sheet,Toggle,Seg,Row,PH,Search});
