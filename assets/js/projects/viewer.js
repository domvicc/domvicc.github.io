// Project Viewer Module (clean)

let _stage, _tabsBar, _projects;

/* ---------- Render Helpers ---------- */
export function renderSvgInline(stage, svgPath){
  stage.innerHTML = '';
  const wrap = document.createElement('div');
  Object.assign(wrap.style,{
    position:'absolute', inset:'0', background:'#fff', overflow:'hidden',
    touchAction:'none', cursor:'grab'
  });
  stage.appendChild(wrap);
  fetch(svgPath).then(r=>r.ok?r.text():Promise.reject(svgPath))
    .then(txt=>{
      wrap.innerHTML = txt;
      const svg = wrap.querySelector('svg');
      if(!svg){ wrap.textContent='SVG failed to load'; return; }
      svg.style.transformOrigin='0 0';
      let scale=1,x=0,y=0,drag=false,lx=0,ly=0;
      const apply=()=> svg.style.transform=`translate(${x}px,${y}px) scale(${scale})`;
      wrap.addEventListener('wheel',e=>{
        e.preventDefault();
        const f=e.deltaY<0?1.1:1/1.1;
        scale=Math.min(Math.max(scale*f,0.4),8); apply();
      },{passive:false});
      wrap.addEventListener('pointerdown',e=>{drag=true;wrap.setPointerCapture(e.pointerId);lx=e.clientX;ly=e.clientY;});
      wrap.addEventListener('pointermove',e=>{if(!drag)return;x+=e.clientX-lx;y+=e.clientY-ly;lx=e.clientX;ly=e.clientY;apply();});
      wrap.addEventListener('pointerup',()=>{drag=false;});
      wrap.addEventListener('dblclick',()=>{scale=1;x=0;y=0;apply();});
      apply();
    })
    .catch(()=>{ wrap.textContent='SVG failed to load'; });
}

export function renderPdfInline(stage, pdfPath){
  stage.innerHTML='';
  const rel=pdfPath.replace(/^assets\//,'')
  const src='assets/pdfjs/web/viewer.html?file='+encodeURIComponent('../..'+'/'+rel);
  const f=document.createElement('iframe');
  Object.assign(f.style,{position:'absolute',inset:'0',width:'100%',height:'100%',border:'0',background:'#fff'});
  f.src=src;
  stage.appendChild(f);
}

export function renderAutoInline(stage,input){
  const lower=(input||'').toLowerCase();
  if(lower.endsWith('.svg')) return renderSvgInline(stage,input);
  if(lower.endsWith('.pdf')) return renderPdfInline(stage,input);
  stage.innerHTML='';
  const img=document.createElement('img');
  img.src=input; img.alt='preview'; img.className='canvas-image';
  stage.appendChild(img);
}

export function renderCharts(stage,cfg){
  stage.innerHTML='';
  const wrap=document.createElement('div');
  wrap.style.padding='12px';
  const h=document.createElement('h3');
  h.textContent='Model Evaluation Charts';
  h.style.margin='0 0 12px'; h.style.fontSize='1.05rem';
  wrap.appendChild(h);
  const gallery=document.createElement('div');
  gallery.className='evals';
  (cfg.charts||[]).forEach(c=>{
    const card=document.createElement('div');
    card.className='eval-card';
    const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
    const img=document.createElement('img'); img.src='assets/img/cc-fraud/'+c.file; img.alt=c.alt||c.title;
    const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc||'';
    card.appendChild(t); card.appendChild(img); card.appendChild(d);
    gallery.appendChild(card);
  });
  wrap.appendChild(gallery);
  stage.appendChild(wrap);
}

/* ---------- Tabs / Switching ---------- */
function renderTab(projectId,label){
  const cfg=_projects[projectId];
  if(!cfg){ _stage.textContent='Unknown project'; return; }
  if(label==='Architecture' && cfg.svg) return renderAutoInline(_stage,cfg.svg);
  if(label==='Code' && cfg.script){
    _stage.innerHTML='';
    fetch(cfg.script).then(r=>r.text()).then(txt=>{
      const pre=document.createElement('pre');
      Object.assign(pre.style,{margin:0,padding:'14px',background:'#0a0f1e',color:'#fff',fontSize:'.8rem',lineHeight:'1.4',overflow:'auto',height:'100%'});
      pre.textContent=txt; _stage.appendChild(pre);
    }).catch(()=>{ _stage.textContent='Script failed to load'; });
    return;
  }
  if(label==='Charts' && cfg.charts) return renderCharts(_stage,cfg);
  _stage.innerHTML='<div class="placeholder">No content for '+label+'</div>';
}

function buildTabs(projectId){
  const cfg=_projects[projectId];
  _tabsBar.innerHTML='';
  if(!cfg || !cfg.tabs || !cfg.tabs.length){
    _tabsBar.style.display='none';
    if(cfg){
      if(cfg.charts) renderCharts(_stage,cfg);
      else if(cfg.script) renderTab(projectId,'Code');
      else if(cfg.svg) renderAutoInline(_stage,cfg.svg);
      else _stage.innerHTML='<div class="placeholder">No content defined.</div>';
    }
    return;
  }
  _tabsBar.style.display='flex';
  cfg.tabs.forEach(name=>{
    const b=document.createElement('button');
    b.className='tab';
    b.textContent=name;
    b.setAttribute('aria-selected','false');
    b.addEventListener('click',()=>{
      [..._tabsBar.querySelectorAll('.tab')].forEach(t=>t.setAttribute('aria-selected','false'));
      b.setAttribute('aria-selected','true');
      renderTab(projectId,name);
    });
    _tabsBar.appendChild(b);
  });
}

export function showProject(id){
  document.querySelectorAll('.project-details')
    .forEach(sec=>sec.classList.toggle('active',sec.dataset.project===id));
  document.querySelectorAll('.tree-item')
    .forEach(btn=>btn.classList.toggle('active',btn.dataset.id===id));
  buildTabs(id);
  const cfg=_projects[id];
  if(cfg && cfg.tabs && cfg.tabs.length){
    const def=cfg.defaultTab||cfg.tabs[0];
    const btn=[..._tabsBar.querySelectorAll('.tab')].find(t=>t.textContent===def) || _tabsBar.querySelector('.tab');
    if(btn) btn.click();
  }
}

export function initProjectViewer({stage,tabsBar,projects,defaultProject}){
  if(!stage||!tabsBar) throw new Error('initProjectViewer: stage and tabsBar required');
  _stage=stage; _tabsBar=tabsBar; _projects=projects||{};
  document.querySelectorAll('.tree-item').forEach(btn=>{
    btn.addEventListener('click',()=>{
      const id=btn.dataset.id;
      if(_projects[id]) showProject(id);
    });
  });
  const start = (defaultProject && _projects[defaultProject]) ? defaultProject : Object.keys(_projects)[0];
  if(start) showProject(start);
}

export const _debug=()=>({_projects,_stage,_tabsBar});
  // tabs builder
  function buildTabs(project){
    tabsBar.innerHTML = '';
    const tabs = (PROJECTS[project] && PROJECTS[project].tabs) || [];
    tabs.forEach(name => {
      const b = document.createElement('button');
      b.className = 'tab';
      b.textContent = name;
      b.setAttribute('aria-selected','false');
      b.addEventListener('click', () => {
        [...tabsBar.querySelectorAll('.tab')].forEach(t => t.setAttribute('aria-selected','false'));
        b.setAttribute('aria-selected','true');
        renderTab(project, name);
      });
      tabsBar.appendChild(b);
    });
  }

  // project switcher
  function showProject(id){
    // toggle active details
    document.querySelectorAll('.project-details').forEach(sec => {
      sec.classList.toggle('active', sec.dataset.project === id);
    });
    // active in tree
    document.querySelectorAll('.tree-item').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.id === id);
    });
    // tabs + initial tab
    buildTabs(id);
    const cfg = PROJECTS[id] || {};
    const def = cfg.defaultTab || (cfg.tabs && cfg.tabs[0]);
    const btn = [...tabsBar.querySelectorAll('.tab')].find(t => t.textContent === def) || tabsBar.querySelector('.tab');
    if(btn){ btn.click(); }
  }

  // tree click handlers
  document.querySelectorAll('.tree-item').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.id;
      if(PROJECTS[id]) showProject(id);
    });
  });

  // init
  if(PROJECTS[defaultProject]) showProject(defaultProject);
}
