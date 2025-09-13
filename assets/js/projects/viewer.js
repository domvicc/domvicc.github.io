// assets/js/projects/viewer.js
export function render_auto_inline(stage,input){
    const lower=(input||'').toLowerCase();
    if(lower.endsWith('.svg')) return render_svg_inline(stage,input);
    if(lower.endsWith('.pdf')) return render_pdf_inline(stage,input);
    const img=document.createElement('img');
    img.src=input; img.alt='preview'; img.className='canvas-image';
    stage.appendChild(img);
  }

  export function renderCharts(stage,cfg){
    stage.innerHTML='';
    const wrap=document.createElement('div');
    wrap.style.padding='12px';
    const heading=document.createElement('h3');
    heading.textContent='Model Evaluation Charts';
    heading.style.margin='0 0 12px';
    heading.style.fontSize='1.1rem';
    wrap.appendChild(heading);

    const gallery=document.createElement('div');
    gallery.className='evals';
    cfg.charts.forEach(c=>{
      const card=document.createElement('div');
      card.className='eval-card';
      const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
      const img=document.createElement('img');
      img.src='assets/img/'+c.file;
      img.alt=c.alt;
      const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc;
      card.appendChild(t); card.appendChild(img); card.appendChild(d);
      gallery.appendChild(card);
    });
    wrap.appendChild(gallery);
    stage.appendChild(wrap);
  }

  function renderTab(project,label){
    stage.innerHTML='';
    const cfg=PROJECTS[project];
    if(label==='Architecture' && cfg.svg){
      render_auto_inline(stage,cfg.svg);
    } else if(label==='Code' && cfg.script){
      fetch(cfg.script).then(r=>r.text()).then(txt=>{
        const pre=document.createElement('pre');
        Object.assign(pre.style,{margin:0,padding:'14px',background:'#0a0f1e',color:'#fff',fontSize:'.8rem',lineHeight:'1.4',overflow:'auto',height:'100%'});
        pre.textContent=txt;
        stage.appendChild(pre);
      }).catch(()=>{ stage.textContent='script failed to load'; });
    } else if(label==='Charts' && cfg.charts){
      renderCharts(stage,cfg);
    } else {
      const ph=document.createElement('div');
      ph.className='placeholder';
      ph.textContent='content for '+label+' goes here.';
      stage.appendChild(ph);
    }
  }

  function buildTabs(project){
    tabsBar.innerHTML='';
    PROJECTS[project].tabs.forEach(name=>{
      const b=document.createElement('button');
      b.className='tab';
      b.textContent=name;
      b.setAttribute('aria-selected','false');
      b.addEventListener('click',()=>{
        [...tabsBar.querySelectorAll('.tab')].forEach(t=>t.setAttribute('aria-selected','false'));
        b.setAttribute('aria-selected','true');
        renderTab(project,name);
      });
      tabsBar.appendChild(b);
    });
  }

  function showProject(id){
    // toggle active details
    document.querySelectorAll('.project-details').forEach(sec=>{
      sec.classList.toggle('active',sec.dataset.project===id);
    });
    // active in tree
    document.querySelectorAll('.tree-item').forEach(btn=>{
      btn.classList.toggle('active',btn.dataset.id===id);
    });
    // tabs + initial tab
    buildTabs(id);
    const cfg=PROJECTS[id];
    const def=cfg.defaultTab||cfg.tabs[0];
    const btn=[...tabsBar.querySelectorAll('.tab')].find(t=>t.textContent===def) || tabsBar.querySelector('.tab');
    if(btn){ btn.click(); }
  }

  // tree click handlers
  document.querySelectorAll('.tree-item').forEach(btn=>{
    btn.addEventListener('click',()=>{
      const id=btn.dataset.id;
      if(PROJECTS[id]) showProject(id);
    });
  });

  // init
  showProject('dgai');
}
export function render_svg_inline(stage, svg_path){
    const wrap=document.createElement('div');
    Object.assign(wrap.style,{position:'absolute',inset:'0',background:'#fff',overflow:'hidden',touchAction:'none',cursor:'grab'});
    stage.appendChild(wrap);
    fetch(svg_path).then(r=>r.ok?r.text():Promise.reject()).then(txt=>{
      wrap.innerHTML=txt;
      const svg=wrap.querySelector('svg'); if(!svg){ wrap.textContent='svg failed to load'; return; }
      svg.style.transformOrigin='0 0';
      let scale=1,x=0,y=0,drag=false,lx=0,ly=0;
      function apply(){ svg.style.transform=`translate(${x}px, ${y}px) scale(${scale})`; }
      wrap.addEventListener('wheel',e=>{ e.preventDefault(); const p=e.deltaY<0?1.1:1/1.1; scale=Math.min(Math.max(scale*p,0.4),8); apply(); },{passive:false});
      wrap.addEventListener('pointerdown',e=>{ drag=true; wrap.setPointerCapture(e.pointerId); lx=e.clientX; ly=e.clientY; });
      wrap.addEventListener('pointermove',e=>{ if(!drag)return; x+=e.clientX-lx; y+=e.clientY-ly; lx=e.clientX; ly=e.clientY; apply(); });
      wrap.addEventListener('pointerup',()=>{ drag=false; });
      wrap.addEventListener('dblclick',()=>{ scale=1;x=0;y=0;apply(); });
      apply();
    }).catch(()=>{ const ph=document.createElement('div'); ph.className='placeholder'; ph.textContent='svg failed to load'; stage.appendChild(ph); });
  }
  export function render_auto_inline(stage,input){
    const lower=(input||'').toLowerCase();
    if(lower.endsWith('.svg')) return render_svg_inline(stage,input);
    if(lower.endsWith('.pdf')) return render_pdf_inline(stage,input);
    const img=document.createElement('img');
    img.src=input; img.alt='preview'; img.className='canvas-image';
    stage.appendChild(img);
  }

  export function renderCharts(stage,cfg){
    stage.innerHTML='';
    const wrap=document.createElement('div');
    wrap.style.padding='12px';
    const heading=document.createElement('h3');
    heading.textContent='Model Evaluation Charts';
    heading.style.margin='0 0 12px';
    heading.style.fontSize='1.1rem';
    wrap.appendChild(heading);

    const gallery=document.createElement('div');
    gallery.className='evals';
    cfg.charts.forEach(c=>{
      const card=document.createElement('div');
      card.className='eval-card';
      const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
      const img=document.createElement('img');
      img.src='assets/img/'+c.file;
      img.alt=c.alt;
      const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc;
      card.appendChild(t); card.appendChild(img); card.appendChild(d);
      gallery.appendChild(card);
    });
    wrap.appendChild(gallery);
    stage.appendChild(wrap);
  }

  function renderTab(project,label){
    stage.innerHTML='';
    const cfg=PROJECTS[project];
    if(label==='Architecture' && cfg.svg){
      render_auto_inline(stage,cfg.svg);
    } else if(label==='Code' && cfg.script){
      fetch(cfg.script).then(r=>r.text()).then(txt=>{
        const pre=document.createElement('pre');
        Object.assign(pre.style,{margin:0,padding:'14px',background:'#0a0f1e',color:'#fff',fontSize:'.8rem',lineHeight:'1.4',overflow:'auto',height:'100%'});
        pre.textContent=txt;
        stage.appendChild(pre);
      }).catch(()=>{ stage.textContent='script failed to load'; });
    } else if(label==='Charts' && cfg.charts){
      renderCharts(stage,cfg);
    } else {
      const ph=document.createElement('div');
      ph.className='placeholder';
      ph.textContent='content for '+label+' goes here.';
      stage.appendChild(ph);
    }
  }

  function buildTabs(project){
    tabsBar.innerHTML='';
    PROJECTS[project].tabs.forEach(name=>{
      const b=document.createElement('button');
      b.className='tab';
      b.textContent=name;
      b.setAttribute('aria-selected','false');
      b.addEventListener('click',()=>{
        [...tabsBar.querySelectorAll('.tab')].forEach(t=>t.setAttribute('aria-selected','false'));
        b.setAttribute('aria-selected','true');
        renderTab(project,name);
      });
      tabsBar.appendChild(b);
    });
  }

  function showProject(id){
    // toggle active details
    document.querySelectorAll('.project-details').forEach(sec=>{
      sec.classList.toggle('active',sec.dataset.project===id);
    });
    // active in tree
    document.querySelectorAll('.tree-item').forEach(btn=>{
      btn.classList.toggle('active',btn.dataset.id===id);
    });
    // tabs + initial tab
    buildTabs(id);
    const cfg=PROJECTS[id];
    const def=cfg.defaultTab||cfg.tabs[0];
    const btn=[...tabsBar.querySelectorAll('.tab')].find(t=>t.textContent===def) || tabsBar.querySelector('.tab');
    if(btn){ btn.click(); }
  }

  // tree click handlers
  document.querySelectorAll('.tree-item').forEach(btn=>{
    btn.addEventListener('click',()=>{
      const id=btn.dataset.id;
      if(PROJECTS[id]) showProject(id);
    });
  });

  // init
  showProject('dgai');
}
export function render_pdf_inline(stage, pdf_path){
    const rel = pdf_path.replace(/^assets\//,'');
    const src = 'assets/pdfjs/web/viewer.html?file=' + encodeURIComponent('../..' + '/' + rel);
    const f=document.createElement('iframe');
    Object.assign(f.style,{position:'absolute',inset:'0',width:'100%',height:'100%',border:'0',background:'#fff'});
    f.src=src; stage.appendChild(f);
  }
  export function render_svg_inline(stage, svg_path){
    const wrap=document.createElement('div');
    Object.assign(wrap.style,{position:'absolute',inset:'0',background:'#fff',overflow:'hidden',touchAction:'none',cursor:'grab'});
    stage.appendChild(wrap);
    fetch(svg_path).then(r=>r.ok?r.text():Promise.reject()).then(txt=>{
      wrap.innerHTML=txt;
      const svg=wrap.querySelector('svg'); if(!svg){ wrap.textContent='svg failed to load'; return; }
      svg.style.transformOrigin='0 0';
      let scale=1,x=0,y=0,drag=false,lx=0,ly=0;
      function apply(){ svg.style.transform=`translate(${x}px, ${y}px) scale(${scale})`; }
      wrap.addEventListener('wheel',e=>{ e.preventDefault(); const p=e.deltaY<0?1.1:1/1.1; scale=Math.min(Math.max(scale*p,0.4),8); apply(); },{passive:false});
      wrap.addEventListener('pointerdown',e=>{ drag=true; wrap.setPointerCapture(e.pointerId); lx=e.clientX; ly=e.clientY; });
      wrap.addEventListener('pointermove',e=>{ if(!drag)return; x+=e.clientX-lx; y+=e.clientY-ly; lx=e.clientX; ly=e.clientY; apply(); });
      wrap.addEventListener('pointerup',()=>{ drag=false; });
      wrap.addEventListener('dblclick',()=>{ scale=1;x=0;y=0;apply(); });
      apply();
    }).catch(()=>{ const ph=document.createElement('div'); ph.className='placeholder'; ph.textContent='svg failed to load'; stage.appendChild(ph); });
  }
  export function render_auto_inline(stage,input){
    const lower=(input||'').toLowerCase();
    if(lower.endsWith('.svg')) return render_svg_inline(stage,input);
    if(lower.endsWith('.pdf')) return render_pdf_inline(stage,input);
    const img=document.createElement('img');
    img.src=input; img.alt='preview'; img.className='canvas-image';
    stage.appendChild(img);
  }

  export function renderCharts(stage,cfg){
    stage.innerHTML='';
    const wrap=document.createElement('div');
    wrap.style.padding='12px';
    const heading=document.createElement('h3');
    heading.textContent='Model Evaluation Charts';
    heading.style.margin='0 0 12px';
    heading.style.fontSize='1.1rem';
    wrap.appendChild(heading);

    const gallery=document.createElement('div');
    gallery.className='evals';
    cfg.charts.forEach(c=>{
      const card=document.createElement('div');
      card.className='eval-card';
      const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
      const img=document.createElement('img');
      img.src='assets/img/'+c.file;
      img.alt=c.alt;
      const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc;
      card.appendChild(t); card.appendChild(img); card.appendChild(d);
      gallery.appendChild(card);
    });
    wrap.appendChild(gallery);
    stage.appendChild(wrap);
  }

  function renderTab(project,label){
    stage.innerHTML='';
    const cfg=PROJECTS[project];
    if(label==='Architecture' && cfg.svg){
      render_auto_inline(stage,cfg.svg);
    } else if(label==='Code' && cfg.script){
      fetch(cfg.script).then(r=>r.text()).then(txt=>{
        const pre=document.createElement('pre');
        Object.assign(pre.style,{margin:0,padding:'14px',background:'#0a0f1e',color:'#fff',fontSize:'.8rem',lineHeight:'1.4',overflow:'auto',height:'100%'});
        pre.textContent=txt;
        stage.appendChild(pre);
      }).catch(()=>{ stage.textContent='script failed to load'; });
    } else if(label==='Charts' && cfg.charts){
      renderCharts(stage,cfg);
    } else {
      const ph=document.createElement('div');
      ph.className='placeholder';
      ph.textContent='content for '+label+' goes here.';
      stage.appendChild(ph);
    }
  }

  function buildTabs(project){
    tabsBar.innerHTML='';
    PROJECTS[project].tabs.forEach(name=>{
      const b=document.createElement('button');
      b.className='tab';
      b.textContent=name;
      b.setAttribute('aria-selected','false');
      b.addEventListener('click',()=>{
        [...tabsBar.querySelectorAll('.tab')].forEach(t=>t.setAttribute('aria-selected','false'));
        b.setAttribute('aria-selected','true');
        renderTab(project,name);
      });
      tabsBar.appendChild(b);
    });
  }

  function showProject(id){
    // toggle active details
    document.querySelectorAll('.project-details').forEach(sec=>{
      sec.classList.toggle('active',sec.dataset.project===id);
    });
    // active in tree
    document.querySelectorAll('.tree-item').forEach(btn=>{
      btn.classList.toggle('active',btn.dataset.id===id);
    });
    // tabs + initial tab
    buildTabs(id);
    const cfg=PROJECTS[id];
    const def=cfg.defaultTab||cfg.tabs[0];
    const btn=[...tabsBar.querySelectorAll('.tab')].find(t=>t.textContent===def) || tabsBar.querySelector('.tab');
    if(btn){ btn.click(); }
  }

  // tree click handlers
  document.querySelectorAll('.tree-item').forEach(btn=>{
    btn.addEventListener('click',()=>{
      const id=btn.dataset.id;
      if(PROJECTS[id]) showProject(id);
    });
  });

  // init
  showProject('dgai');
}
export function renderCharts(stage,cfg){
    stage.innerHTML='';
    const wrap=document.createElement('div');
    wrap.style.padding='12px';
    const heading=document.createElement('h3');
    heading.textContent='Model Evaluation Charts';
    heading.style.margin='0 0 12px';
    heading.style.fontSize='1.1rem';
    wrap.appendChild(heading);

    const gallery=document.createElement('div');
    gallery.className='evals';
    cfg.charts.forEach(c=>{
      const card=document.createElement('div');
      card.className='eval-card';
      const t=document.createElement('p'); t.className='eval-title'; t.textContent=c.title;
      const img=document.createElement('img');
      img.src='assets/img/'+c.file;
      img.alt=c.alt;
      const d=document.createElement('p'); d.className='eval-desc'; d.textContent=c.desc;
      card.appendChild(t); card.appendChild(img); card.appendChild(d);
      gallery.appendChild(card);
    });
    wrap.appendChild(gallery);
    stage.appendChild(wrap);
  }

  function renderTab(project,label){
    stage.innerHTML='';
    const cfg=PROJECTS[project];
    if(label==='Architecture' && cfg.svg){
      render_auto_inline(stage,cfg.svg);
    } else if(label==='Code' && cfg.script){
      fetch(cfg.script).then(r=>r.text()).then(txt=>{
        const pre=document.createElement('pre');
        Object.assign(pre.style,{margin:0,padding:'14px',background:'#0a0f1e',color:'#fff',fontSize:'.8rem',lineHeight:'1.4',overflow:'auto',height:'100%'});
        pre.textContent=txt;
        stage.appendChild(pre);
      }).catch(()=>{ stage.textContent='script failed to load'; });
    } else if(label==='Charts' && cfg.charts){
      renderCharts(stage,cfg);
    } else {
      const ph=document.createElement('div');
      ph.className='placeholder';
      ph.textContent='content for '+label+' goes here.';
      stage.appendChild(ph);
    }
  }

  function buildTabs(project){
    tabsBar.innerHTML='';
    PROJECTS[project].tabs.forEach(name=>{
      const b=document.createElement('button');
      b.className='tab';
      b.textContent=name;
      b.setAttribute('aria-selected','false');
      b.addEventListener('click',()=>{
        [...tabsBar.querySelectorAll('.tab')].forEach(t=>t.setAttribute('aria-selected','false'));
        b.setAttribute('aria-selected','true');
        renderTab(project,name);
      });
      tabsBar.appendChild(b);
    });
  }

  function showProject(id){
    // toggle active details
    document.querySelectorAll('.project-details').forEach(sec=>{
      sec.classList.toggle('active',sec.dataset.project===id);
    });
    // active in tree
    document.querySelectorAll('.tree-item').forEach(btn=>{
      btn.classList.toggle('active',btn.dataset.id===id);
    });
    // tabs + initial tab
    buildTabs(id);
    const cfg=PROJECTS[id];
    const def=cfg.defaultTab||cfg.tabs[0];
    const btn=[...tabsBar.querySelectorAll('.tab')].find(t=>t.textContent===def) || tabsBar.querySelector('.tab');
    if(btn){ btn.click(); }
  }

  // tree click handlers
  document.querySelectorAll('.tree-item').forEach(btn=>{
    btn.addEventListener('click',()=>{
      const id=btn.dataset.id;
      if(PROJECTS[id]) showProject(id);
    });
  });

  // init
  showProject('dgai');
}
