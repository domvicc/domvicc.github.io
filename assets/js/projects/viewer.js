// project viewer module (clean)

let _stage, _tabsBar, _projects;

/* ---------- render helpers ---------- */
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
      if(!svg){ wrap.textContent='svg failed to load'; return; }
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
    .catch(()=>{ wrap.textContent='svg failed to load'; });
}

export function renderPdfInline(stage, pdfPath){
  stage.innerHTML='';
  const rel = pdfPath.replace(/^assets\//,'');
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
  h.textContent='model evaluation charts';
  h.style.margin='0 0 12px'; h.style.fontSize='1.05rem';
  wrap.appendChild(h);
  const gallery=document.createElement('div');
  gallery.className='evals';
  (cfg.charts||[]).forEach(c=>{
    const card=document.createElement('div');
    card.className='eval-card';
    const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
    const img=document.createElement('img'); img.src='assets/img/'+c.file; img.alt=c.alt||c.title;
    const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc||'';
    card.appendChild(t); card.appendChild(img); card.appendChild(d);
    gallery.appendChild(card);
  });
  wrap.appendChild(gallery);
  stage.appendChild(wrap);
}

/* ---------- tabs / switching ---------- */
function renderCodeBox(projectId){
  const cfg=_projects[projectId];
  if(!cfg?.script){ _stage.innerHTML='<div class="placeholder">no code available.</div>'; return; }
  _stage.innerHTML='';
  const box=document.createElement('div');
  box.className='code-box';

  const header=document.createElement('div');
  header.className='code-box-header';
  const fname=cfg.script.split('/').pop();
  header.innerHTML=`<span class="file-name">${fname}</span>`;
  const actions=document.createElement('div');
  actions.className='code-box-actions';
  const copyBtn=document.createElement('button');
  copyBtn.type='button';
  copyBtn.className='copy-btn';
  copyBtn.textContent='copy';
  actions.appendChild(copyBtn);
  header.appendChild(actions);
  box.appendChild(header);

  const pre=document.createElement('pre');
  const code=document.createElement('code');
  pre.appendChild(code);
  box.appendChild(pre);
  _stage.appendChild(box);

  fetch(cfg.script).then(r=>r.text()).then(txt=>{
    const lines=txt.replace(/\r\n?/g,'\n').split('\n');
    const frag=document.createDocumentFragment();
    lines.forEach(line=>{
      const span=document.createElement('span');
      // show a space if line empty so line height remains
      span.textContent=line.length?line:' ';
      frag.appendChild(span);
    });
    code.appendChild(frag);
  }).catch(()=>{
    code.innerHTML='/* failed to load script */';
  });

  copyBtn.addEventListener('click',()=>{
    const raw=[...code.querySelectorAll('span')].map(s=>s.textContent).join('\n');
    navigator.clipboard.writeText(raw).then(()=>{
      copyBtn.textContent='copied';
      box.classList.add('copy-ok');
      setTimeout(()=>{copyBtn.textContent='copy';box.classList.remove('copy-ok');},1600);
    });
  });
}

function renderTab(projectId,label){
  const cfg=_projects[projectId];
  if(!cfg){ _stage.textContent='unknown project'; return; }
  if(label==='Architecture' && cfg.svg) return renderAutoInline(_stage,cfg.svg);
  if(label==='Charts' && cfg.charts) return renderCharts(_stage,cfg);
  if(label==='Code' && cfg.script) return renderCodeBox(projectId);
  _stage.innerHTML='<div class="placeholder">no content for '+label+'</div>';
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
      else _stage.innerHTML='<div class="placeholder">no content defined.</div>';
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
