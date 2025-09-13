// assets/js/app.js (v25.1 hardened filters)

(() => {
  const qs = (s, root=document) => root.querySelector(s);
  const qsa = (s, root=document) => [...root.querySelectorAll(s)];
  const byId = id => document.getElementById(id);

  const dataEl = byId('projects-data');
  if (!dataEl) { console.warn('projects: missing #projects-data json'); return; }

  let projects;
  try { projects = JSON.parse(dataEl.textContent.trim()); }
  catch (e) { console.error('projects: invalid json in #projects-data', e); return; }

  console.info('projects hub loaded', { count: projects.length });

  const state = {
    view: loadView(),
    search: '',
    sort: 'recent',
    tags: new Set(),
    tech: new Set(),
    years: new Set(),
    status: new Set(),
    featuredOnly: false
  };

  const views = {
    grid: byId('view-grid'),
    list: byId('view-list'),
    timeline: byId('view-timeline'),
  };

  const searchInput = byId('search');
  const clearSearchBtn = qs('.clear-search');
  const sortSelect = byId('sort');
  const emptyState = byId('empty');
  const quickChips = byId('quick-chips');

  const side = {
    tags: byId('filter-tags'),
    tech: byId('filter-tech'),
    years: byId('filter-years'),
    status: byId('filter-status'),
    featured: byId('filter-featured'),
  };

  const sheet = {
    el: byId('filters-sheet'),
    tags: byId('m-filter-tags'),
    tech: byId('m-filter-tech'),
    years: byId('m-filter-years'),
    status: byId('m-filter-status'),
    featured: byId('m-filter-featured'),
    apply: qs('.apply-filters', byId('filters-sheet')),
    close: qs('.close-sheet', byId('filters-sheet')),
    toggleBtn: qs('.filters-toggle')
  };

  const clearButtons = qsa('.clear-filters');
  const btnTop = byId('btn-top');
  const btnClear = byId('btn-clear');

  const vocab = {
    tags: uniq(projects.flatMap(p => p.tags || [])).sort(),
    tech: uniq(projects.flatMap(p => p.tech_stack || [])).sort(),
    years: uniq(projects.map(p => p.year).filter(Boolean)).sort((a,b)=>b-a),
    status: uniq(projects.map(p => (p.status||'').toLowerCase()).filter(Boolean)).sort()
  };

  initFromUrl();
  buildUi();

  /* ---------- ui build ---------- */
  function buildUi(){
    renderFilters();
    renderChipsRow();
    wireFilterDelegation();    // <— hardened click wiring
    render();
    wireGlobals();
  }

  function wireGlobals(){
    qsa('.view-btn').forEach(btn => btn.addEventListener('click', () => setView(btn.dataset.view)));

    if (searchInput){
      searchInput.value = state.search;
      searchInput.addEventListener('input', debounce(() => { state.search = searchInput.value.trim(); syncUrl(); render(); }, 120));
    }
    clearSearchBtn?.addEventListener('click', () => { state.search=''; searchInput.value=''; syncUrl(); render(); searchInput.focus(); });

    if (sortSelect){
      sortSelect.value = state.sort;
      sortSelect.addEventListener('change', () => { state.sort = sortSelect.value; syncUrl(); render(); });
    }

    btnTop?.addEventListener('click', () => window.scrollTo({ top:0, behavior:'smooth' }));
    btnClear?.addEventListener('click', clearAllFilters);

    sheet.toggleBtn?.addEventListener('click', () => sheet.el?.setAttribute('aria-hidden','false'));
    sheet.close?.addEventListener('click', () => sheet.el?.setAttribute('aria-hidden','true'));
    sheet.apply?.addEventListener('click', () => { syncSheetToSidebar(); sheet.el?.setAttribute('aria-hidden','true'); syncUrl(); render(); });

    clearButtons.forEach(b => b.addEventListener('click', clearAllFilters));

    document.addEventListener('keydown', (e) => {
      if (isEditable(e)) return;
      if (e.key === '/') { e.preventDefault(); searchInput?.focus(); }
      if (e.key.toLowerCase() === 'g') setView('grid');
      if (e.key.toLowerCase() === 'l') setView('list');
      if (e.key.toLowerCase() === 't') setView('timeline');
      if (e.key === 'Escape'){
        if (!closeModal()) { if (searchInput?.value){ searchInput.value=''; state.search=''; syncUrl(); render(); } }
      }
    });

    window.addEventListener('hashchange', handleHashOpen);
    handleHashOpen();
  }

  /* ---------- hardened filter delegation ---------- */
  function wireFilterDelegation(){
    const containers = [
      ['tags', side.tags], ['tech', side.tech], ['years', side.years], ['status', side.status],
      ['tags', sheet.tags], ['tech', sheet.tech], ['years', sheet.years], ['status', sheet.status],
      ['tags', quickChips]
    ];

    containers.forEach(([group, el]) => {
      if (!el) return;
      el.addEventListener('click', (e) => {
        const b = e.target.closest('.chip'); if (!b) return;
        const labelText = b.textContent.trim();
        const val = (group === 'years') ? Number(labelText) : labelText;
        const setRef = state[group];

        // toggle and update aria
        setRef.has(val) ? setRef.delete(val) : setRef.add(val);
        b.setAttribute('aria-pressed', setRef.has(val) ? 'true' : 'false');

        // keep sidebar ↔ mobile in sync
        mirrorChips(labelText);

        syncUrl(); render();
      });
    });

    side.featured?.addEventListener('change', () => {
      state.featuredOnly = side.featured.checked;
      sheet.featured.checked = state.featuredOnly;
      syncUrl(); render();
    });
    sheet.featured?.addEventListener('change', () => {
      state.featuredOnly = sheet.featured.checked;
      side.featured.checked = state.featuredOnly;
    });
  }

  function mirrorChips(label){
    // ensure both sets show pressed state appropriately
    qsa('#projects .chips .chip').forEach(c => {
      if (c.textContent.trim() !== label) return;
      const pressed = c.getAttribute('aria-pressed') === 'true';
      // reflect the same state in all twins
      qsa('#projects .chips .chip').forEach(other => {
        if (other.textContent.trim() === label) other.setAttribute('aria-pressed', pressed ? 'true' : 'false');
      });
    });
  }

  /* ---------- renderers ---------- */
  function render(){
    const rows = filtered(projects);
    const sorted = sortRows(rows, state.sort);

    // grid
    views.grid.innerHTML = '';
    const grid = document.createElement('div');
    grid.className = 'grid';
    for (const p of sorted){ grid.appendChild(renderCard(p)); }
    views.grid.appendChild(grid);

    // list
    views.list.innerHTML = '';
    const list = document.createElement('div');
    list.className = 'list';
    for (const p of sorted){ list.appendChild(renderRow(p)); }
    views.list.appendChild(list);

    // timeline
    views.timeline.innerHTML = '';
    const groups = groupBy(sorted, p => p.year || 'unknown');
    const years = Object.keys(groups).sort((a,b)=>b-a);
    const tl = document.createElement('div'); tl.className='timeline';
    for (const y of years){
      const g = div('time-group'); const h = div('time-year', y); g.appendChild(h);
      for (const p of groups[y]){
        const item = div('time-item');
        item.append(div('time-title', p.title), div('time-sub', p.subtitle||''), chipRow(p.tags||[], 'meta-tag small'));
        item.addEventListener('click', () => openProject(p));
        g.appendChild(item);
      }
      tl.appendChild(g);
    }
    views.timeline.appendChild(tl);

    emptyState.hidden = sorted.length !== 0;
    showView(state.view);
  }

  function renderFilters(){
    // sidebar
    side.tags.innerHTML = ''; vocab.tags.forEach(v => side.tags.appendChild(chip(v, state.tags)));
    side.tech.innerHTML = ''; vocab.tech.forEach(v => side.tech.appendChild(chip(v, state.tech)));
    side.years.innerHTML = ''; vocab.years.forEach(v => side.years.appendChild(chip(v, state.years)));
    side.status.innerHTML = ''; vocab.status.forEach(v => side.status.appendChild(chip(v, state.status)));
    if (side.featured) side.featured.checked = state.featuredOnly;

    // mobile
    sheet.tags.innerHTML = ''; vocab.tags.forEach(v => sheet.tags.appendChild(chip(v, state.tags)));
    sheet.tech.innerHTML = ''; vocab.tech.forEach(v => sheet.tech.appendChild(chip(v, state.tech)));
    sheet.years.innerHTML = ''; vocab.years.forEach(v => sheet.years.appendChild(chip(v, state.years)));
    sheet.status.innerHTML = ''; vocab.status.forEach(v => sheet.status.appendChild(chip(v, state.status)));
    if (sheet.featured) sheet.featured.checked = state.featuredOnly;
  }

  function renderChipsRow(){
    const common = ['sql development','architecture','analytics','operations','finance','compliance'];
    quickChips.innerHTML = '';
    common.forEach(tag => quickChips.appendChild(chip(tag, state.tags)));
  }

  /* ---------- components ---------- */
  function chip(label, setRef){
    const pressed = setRef.has(typeof label === 'number' ? label : String(label));
    const b = document.createElement('button');
    b.className = 'chip';
    b.setAttribute('type','button');
    b.setAttribute('aria-pressed', pressed ? 'true' : 'false');
    b.textContent = String(label);
    return b;
  }

  function chipRow(items, cls='meta-tag'){
    const row = document.createElement('div'); row.className = 'meta-tags';
    items.forEach(t => row.appendChild(span(cls, t)));
    return row;
  }

  function renderCard(p){
    const card = div('card'); card.setAttribute('data-id', p.id);
    const head = div('card-head');
    const img = document.createElement('img');
    img.className = 'card-cover'; img.loading = 'lazy'; img.alt = p?.cover?.[0]?.alt||p.title; img.src = p?.cover?.[0]?.src||'assets/img/placeholder.jpg';
    const badges = div('card-badges'); (p.tags||[]).slice(0,3).forEach(t => badges.appendChild(span('badge', t)));
    head.append(img,badges);

    const body = div('card-body');
    body.append(
      h('h3','card-title', p.title),
      p.subtitle ? pEl('card-sub', p.subtitle) : div('card-sub',''),
      p.description ? pEl('card-desc', p.description) : div('card-desc',''),
      (() => { const meta = div('card-meta'); meta.append(chipRow(p.tech_stack||[], 'meta-tag'), small(`${p.role||''}${p.year?` • ${p.year}`:''}`)); return meta; })(),
      (() => {
        const a = div('card-actions');
        a.append(btn('view details', () => openProject(p)));
        if (p.links?.demo) a.append(linkBtn('demo', p.links.demo));
        if (p.links?.repo) a.append(copyBtn('copy repo', p.links.repo));
        if (p.links?.case_study) a.append(linkBtn('case study', p.links.case_study));
        return a;
      })()
    );

    card.append(head, body);
    card.addEventListener('click', (e) => { if (!e.target.closest('a,button')) openProject(p); });
    return card;
  }

  function renderRow(p){
    const row = div('row'); row.setAttribute('data-id', p.id);
    const img = document.createElement('img'); img.loading='lazy'; img.alt=p?.cover?.[0]?.alt||p.title; img.src=p?.cover?.[0]?.src||'assets/img/placeholder.jpg';
    const body = div('row-body');
    body.append(h('h3','card-title', p.title), pEl('card-sub', p.subtitle||''), (() => { const m=div('row-meta'); (p.tags||[]).forEach(t => m.appendChild(span('meta-tag', t))); return m; })(),
      (() => { const a = div('card-actions'); a.append(btn('details', () => openProject(p))); if (p.links?.repo) a.append(copyBtn('copy repo', p.links.repo)); return a; })()
    );
    row.append(img, body);
    row.addEventListener('click', (e) => { if (!e.target.closest('a,button')) openProject(p); });
    return row;
  }

  /* ---------- filtering/sorting ---------- */
  function filtered(rows){
    return rows.filter(p => {
      if (state.featuredOnly && !p.featured) return false;
      if (state.tags.size && !everyIn([...state.tags], p.tags||[])) return false;
      if (state.tech.size && !everyIn([...state.tech], p.tech_stack||[])) return false;
      if (state.years.size && !state.years.has(p.year)) return false;
      if (state.status.size && !state.status.has((p.status||'').toLowerCase())) return false;
      if (state.search){
        const hay = `${p.title} ${p.subtitle||''} ${p.description||''} ${(p.tags||[]).join(' ')} ${(p.tech_stack||[]).join(' ')}`.toLowerCase();
        if (!hay.includes(state.search.toLowerCase())) return false;
      }
      return true;
    });
  }

  function sortRows(rows, how){
    const a = rows.slice();
    if (how === 'recent') a.sort((x,y) => (y.year||0) - (x.year||0) || x.title.localeCompare(y.title));
    if (how === 'a-z') a.sort((x,y) => x.title.localeCompare(y.title));
    if (how === 'z-a') a.sort((x,y) => y.title.localeCompare(x.title));
    return a;
  }

  /* ---------- view + url state ---------- */
  function setView(v){ state.view=v; saveView(v); syncUrl(); showView(v); }
  function showView(v){
    Object.entries(views).forEach(([k,el]) => {
      const btn = qs(`.view-btn[data-view="${k}"]`);
      const is = k===v;
      el.hidden = !is;
      el.classList.toggle('is-active', is);
      btn?.classList.toggle('is-active', is);
      btn?.setAttribute('aria-pressed', is ? 'true' : 'false');
    });
  }
  function saveView(v){ try{ localStorage.setItem('projects:view', v); }catch{} }
  function loadView(){ try{ return localStorage.getItem('projects:view') || 'grid'; }catch{ return 'grid'; } }

  function syncUrl(){
    const p = new URLSearchParams();
    p.set('view', state.view);
    if (state.search) p.set('search', state.search);
    if (state.sort !== 'recent') p.set('sort', state.sort);
    if (state.tags.size) p.set('tags', [...state.tags].join(','));
    if (state.tech.size) p.set('tech', [...state.tech].join(','));
    if (state.years.size) p.set('years', [...state.years].join(','));
    if (state.status.size) p.set('status', [...state.status].join(','));
    if (state.featuredOnly) p.set('featured','1');
    history.replaceState(null,'', p.toString() ? `?${p}` : location.pathname);
  }

  function initFromUrl(){
    const p = new URLSearchParams(location.search);
    state.view = p.get('view') || state.view;
    state.search = p.get('search') || '';
    state.sort = p.get('sort') || 'recent';
    if (p.get('tags')) state.tags = new Set(p.get('tags').split(',').filter(Boolean));
    if (p.get('tech')) state.tech = new Set(p.get('tech').split(',').filter(Boolean));
    if (p.get('years')) state.years = new Set(p.get('years').split(',').map(n => Number(n)).filter(Boolean));
    if (p.get('status')) state.status = new Set(p.get('status').split(',').filter(Boolean));
    state.featuredOnly = p.get('featured') === '1';
  }

  /* ---------- modal ---------- */
  const modal = byId('project-modal');
  const carouselTrack = byId('carousel-track');
  const modalEls = {
    kicker: byId('modal-kicker'),
    title: byId('modal-title'),
    sub: byId('modal-sub'),
    desc: byId('modal-desc'),
    highlights: byId('modal-highlights'),
    metrics: byId('modal-metrics'),
    links: byId('modal-links'),
  };
  qsa('[data-close="#project-modal"]').forEach(b => b.addEventListener('click', closeModal));
  qs('.modal-backdrop')?.addEventListener('click', closeModal);
  qs('.carousel-prev')?.addEventListener('click', () => slide(-1));
  qs('.carousel-next')?.addEventListener('click', () => slide(1));

  function openProject(p){
    carouselTrack.innerHTML = '';
    const media = (p.cover && p.cover.length) ? p.cover : [{src:'assets/img/placeholder.jpg',alt:p.title}];
    media.forEach(m => {
      if (String(m.src).toLowerCase().endsWith('.pdf')){
        const f = document.createElement('iframe'); f.loading='lazy'; f.src=m.src; carouselTrack.appendChild(f);
      } else {
        const i = document.createElement('img'); i.loading='lazy'; i.alt=m.alt||p.title; i.src=m.src; carouselTrack.appendChild(i);
      }
    });

    modalEls.kicker.textContent = (p.tags||[]).slice(0,1).join(' • ');
    modalEls.title.textContent = p.title;
    modalEls.sub.textContent = p.subtitle || '';
    modalEls.desc.textContent = p.description || '';

    modalEls.highlights.innerHTML = ''; (p.highlights||[]).forEach(h => modalEls.highlights.appendChild(li(h)));
    modalEls.metrics.innerHTML = ''; (p.metrics||[]).forEach(m => { const c=div('metric'); c.append(div('metric-label', m.label), div('metric-value', m.value)); modalEls.metrics.appendChild(c); });
    modalEls.links.innerHTML = '';
    if (p.links?.demo) modalEls.links.appendChild(linkBtn('open demo', p.links.demo));
    if (p.links?.repo) modalEls.links.appendChild(copyBtn('copy repo', p.links.repo));
    if (p.links?.case_study) modalEls.links.appendChild(linkBtn('open case study', p.links.case_study));

    const sim = filtered(projects).filter(x => x.id !== p.id)
      .map(x => ({x,score:overlap(p.tags||[], x.tags||[])}))
      .filter(s => s.score>0).sort((a,b)=>b.score-a.score).slice(0,6).map(s=>s.x);
    const wrap = byId('modal-similar'); wrap.innerHTML=''; sim.forEach(sp => wrap.appendChild(renderMini(sp)));

    openModal();
    location.hash = `project-${p.id}`;
  }

  function renderMini(p){
    const a = document.createElement('a'); a.className='card'; a.href=`#project-${p.id}`;
    const img = document.createElement('img'); img.className='card-cover'; img.loading='lazy'; img.alt=p?.cover?.[0]?.alt||p.title; img.src=p?.cover?.[0]?.src||'assets/img/placeholder.jpg';
    const body = div('card-body'); body.append(h('h4','card-title', p.title));
    a.append(img, body);
    a.addEventListener('click', (e) => { e.preventDefault(); openProject(p); });
    return a;
  }

  function openModal(){ modal?.setAttribute('aria-hidden','false'); qs('.modal-scroller')?.focus(); }
  function closeModal(){ if (!modal || modal.getAttribute('aria-hidden') === 'true') return false; modal.setAttribute('aria-hidden','true'); if (location.hash.startsWith('#project-')) history.replaceState(null,'',location.pathname + location.search); return true; }

  let slideIndex = 0;
  function slide(dir){ const track = carouselTrack; const count = track.children.length; if (!count) return; slideIndex = (slideIndex + dir + count) % count; track.scrollTo({left: track.clientWidth * slideIndex, behavior:'smooth'}); }

  /* ---------- helpers ---------- */
  function uniq(a){ return [...new Set(a)]; }
  function everyIn(needles, haystack){ return needles.every(n => haystack.includes(n)); }
  function groupBy(arr, fn){ return arr.reduce((m, x) => { const k = fn(x); (m[k]||(m[k]=[])).push(x); return m; }, {}); }
  function overlap(a,b){ return a.filter(x => b.includes(x)).length; }
  function debounce(fn, ms){ let t; return (...args)=>{ clearTimeout(t); t=setTimeout(()=>fn(...args),ms); }; }
  function isEditable(e){ const n = e.target; return ['input','textarea','select'].includes(n.tagName.toLowerCase()) || n.isContentEditable; }

  // mini dom helpers
  function div(cls, text){ const n=document.createElement('div'); if (cls) n.className=cls; if (text!==undefined) n.textContent=text; return n; }
  function span(cls, text){ const n=document.createElement('span'); if (cls) n.className=cls; n.textContent=text; return n; }
  function small(text){ const n=document.createElement('small'); n.textContent=text; return n; }
  function h(tag, cls, text){ const n=document.createElement(tag); if (cls) n.className=cls; n.textContent=text; return n; }
  function pEl(cls, text){ const n=document.createElement('p'); if (cls) n.className=cls; n.textContent=text; return n; }
  function li(text){ const n=document.createElement('li'); n.textContent=text; return n; }

  // tiny header parallax polish (optional)
  document.addEventListener('scroll', () => {
    const hdr = qs('.site-header'); if (!hdr) return;
    const y = Math.min(1, window.scrollY / 220);
    hdr.style.backdropFilter = `saturate(${140 - y*20}%) blur(${10 - y*4}px)`;
    const mark = qs('.brand-mark'); if (mark) mark.style.transform = `scale(${1 - y*0.06})`;
    const text = qs('.brand-text'); if (text) text.style.opacity = String(1 - y*0.15);
  }, { passive:true });
})();
