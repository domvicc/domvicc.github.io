// project viewer module (clean)

let _stage, _tabsBar, _projects;

// --- lightweight vscode-ish syntax highlighting (refined) ---
let _themeInjected=false;
function injectCodeTheme(){
  if(_themeInjected) return;
  _themeInjected=true;
  const css=`
  /* token colors only (do not override existing pre background) */
  .code-box .token.comment { color:#6A9955; }
  .code-box .token.keyword { color:#569CD6; }
  .code-box .token.string { color:#CE9178; }
  .code-box .token.number { color:#B5CEA8; }
  .code-box .token.function { color:#DCDCAA; }
  .code-box .token.class { color:#4EC9B0; }
  .code-box .token.decorator,
  .code-box .token.builtin { color:#C586C0; }
  .code-box .token.operator { color:#D4D4D4; }
  `;
  const style=document.createElement('style');
  style.dataset.codeTheme='vscode-lite';
  style.textContent=css;
  document.head.appendChild(style);
}
function escapeHtml(s){ return s.replace(/[&<>]/g,c=>({ '&':'&amp;','<':'&lt;','>':'&gt;' }[c])); }
function tokenizeFlat(text,patterns){
  let out='',i=0;
  while(i<text.length){
    let earliest=null,pat=null;
    for(const p of patterns){
      p.re.lastIndex=0;
      const m=p.re.exec(text.slice(i));
      if(m){
        const idx=i+m.index;
        if(earliest===null||idx<earliest){ earliest=idx; pat={p,match:m[0],offset:idx}; if(idx===i) break; }
      }
    }
    if(!pat){ out+=escapeHtml(text.slice(i)); break; }
    if(pat.offset>i) out+=escapeHtml(text.slice(i,pat.offset));
    out+=`<span class="token ${pat.p.type}">${escapeHtml(pat.match)}</span>`;
    i=pat.offset+pat.match.length;
  }
  return out;
}
function makeTokenizer(lang){
  if(lang==='py'){
    const keywords=["False","None","True","and","as","assert","async","await","break","class","continue","def","del","elif","else","except","finally","for","from","global","if","import","in","is","lambda","nonlocal","not","or","pass","raise","return","try","while","with","yield"];
    const builtins=["abs","all","any","bin","bool","bytes","chr","dict","dir","enumerate","eval","exec","float","format","getattr","hasattr","hash","help","hex","id","int","isinstance","issubclass","iter","len","list","map","max","min","next","object","open","ord","pow","print","range","repr","reversed","round","set","slice","sorted","str","sum","tuple","type","vars","zip"];
    const kwRe=new RegExp('\\b(' + keywords.join('|') + ')\\b');
    const biRe=new RegExp('\\b(' + builtins.join('|') + ')\\b');
    const patterns=[
      {type:'comment',re:/#.*/},
      {type:'string',re:/(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")/},
      {type:'number',re:/\b\d+(?:\.\d+)?\b/},
      {type:'decorator',re:/@\w+/},
      {type:'keyword',re:kwRe},
      {type:'builtin',re:biRe},
      {type:'function',re:/\b(?<=def\s+)[A-Za-z_]\w*/},
      {type:'class',re:/\b(?<=class\s+)[A-Za-z_]\w*/},
    ];
    let triple=null;
    return line=>{
      let out='',working=line;
      if(triple){
        const closeIdx=working.indexOf(triple);
        if(closeIdx===-1) return `<span class="token string">${escapeHtml(working)}</span>`;
        out+=`<span class="token string">${escapeHtml(working.slice(0,closeIdx+3))}</span>`;
        triple=null;
        working=working.slice(closeIdx+3);
      }
      const tqRe=/(?:'''|""")/g;
      while(working.length){
        tqRe.lastIndex=0;
        const m=tqRe.exec(working);
        if(!m){ out+=tokenizeFlat(working,patterns); break; }
        const before=working.slice(0,m.index);
        if(before) out+=tokenizeFlat(before,patterns);
        const rest=working.slice(m.index+3);
        const closeAgain=rest.indexOf(m[0]);
        if(closeAgain===-1){
          out+=`<span class="token string">${escapeHtml(working.slice(m.index))}</span>`;
          triple=m[0];
          working='';
        }else{
          const full=m[0]+rest.slice(0,closeAgain+3);
          out+=`<span class="token string">${escapeHtml(full)}</span>`;
          working=rest.slice(closeAgain+3);
        }
      }
      return out||' ';
    };
  }
  if(lang==='js'||lang==='ts'){
    const keywords=["break","case","catch","class","const","continue","debugger","default","delete","do","else","export","extends","finally","for","function","if","import","in","instanceof","let","new","return","super","switch","this","throw","try","typeof","var","void","while","with","yield","await","async","of"];
    const kwRe=new RegExp('\\b('+keywords.join('|')+')\\b');
    const patterns=[
      {type:'comment',re:/\/\/.*/},
      {type:'comment',re:/\/\*[\s\S]*?\*\//},
      {type:'string',re:/(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`])*`)/},
      {type:'number',re:/\b\d+(?:\.\d+)?\b/},
      {type:'keyword',re:kwRe},
      {type:'function',re:/\b(?<=function\s+)[A-Za-z_]\w*/},
      {type:'class',re:/\b(?<=class\s+)[A-Za-z_]\w*/},
    ];
    return line=>tokenizeFlat(line,patterns);
  }
  return line=>escapeHtml(line)||' ';
}
// --- end highlighting utilities ---

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
    injectCodeTheme();
    const lines=txt.replace(/\r\n?/g,'\n').split('\n');
    const frag=document.createDocumentFragment();
    const fname=cfg.script.split('/').pop();
    const ext=fname.split('.').pop().toLowerCase();
    const lang = ext==='py'?'py':(ext==='js'?'js':(ext==='ts'?'ts':null));
    const tokenize=makeTokenizer(lang||'');
    lines.forEach(line=>{
      const lineSpan=document.createElement('span');
      lineSpan.className='code-line';
      lineSpan.innerHTML=tokenize(line);
      frag.appendChild(lineSpan);
    });
    code.appendChild(frag);
  }).catch(()=>{
    code.innerHTML='/* failed to load script */';
  });

  copyBtn.addEventListener('click',()=>{
    const raw=[...code.querySelectorAll('.code-line')]
      .map(l=>l.textContent)
      .join('\n');
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
