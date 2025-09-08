// assets/js/app.js
/* projects hub logic (vanilla js)
   - parses embedded json
   - renders grid/list/timeline
   - filters + search + sort with url sync
   - detail modal with carousel + deep links
   - keyboard shortcuts + a11y focus trapping
*/

(() => {
  const qs = (s,root=document) => root.querySelector(s);
  const qsa = (s,root=document) => [...root.querySelectorAll(s)];
  const byId = id => document.getElementById(id);

  const dataEl = byId('projects-data');
  if (!dataEl) return;
  const projects = JSON.parse(dataEl.textContent.trim());

  /* state */
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

  /* dom refs */
  const viewBtns = qsa('.view-btn');
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

  /* derive filter vocab */
  const vocab = {
    tags: uniq(projects.flatMap(p => p.tags || [])).sort(),
    tech: uniq(projects.flatMap(p => p.tech_stack || [])).sort(),
    years: uniq(projects.map(p => p.year).filter(Boolean)).sort((a,b)=>b-a),
    status: uniq(projects.map(p => (p.status||'').toLowerCase()).filter(Boolean)).sort()
  };

  /* init from url */
  initFromUrl();

  /* build ui */
  renderFilters();
  renderChipsRow();
  render();

  /* events: view toggle */
  viewBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const v = btn.dataset.view;
      setView(v);
    });
  });

  /* search */
  if (searchInput){
    searchInput.value = state.search;
    searchInput.addEventListener('input', debounce(() => {
      state.search = searchInput.value.trim();
      syncUrl(); render();
    }, 120));
  }
  if (clearSearchBtn){
    clearSearchBtn.addEventListener('click', () => {
      searchInput.value = '';
      state.search = '';
      syncUrl(); render();
      searchInput.focus();
    });
  }

  /* sort */
  if (sortSelect){
    sortSelect.value = state.sort;
    sortSelect.addEventListener('change', () => {
      state.sort = sortSelect.value;
      syncUrl(); render();
    });
  }

  /* floating actions */
  btnTop?.addEventListener('click', () => window.scrollTo({top:0, behavior:'smooth'}));
  btnClear?.addEventListener('click', () => { clearAllFilters(); });

  /* sidebar chip interactions */
  wireChipGroup(side.tags, state.tags, 'tags');
  wireChipGroup(side.tech, state.tech, 'tech');
  wireChipGroup(side.years, state.years, 'years');
  wireChipGroup(side.status, state.status, 'status');
  side.featured?.addEventListener('change', () => { state.featuredOnly = side.featured.checked; mirrorFeaturedToSheet(); syncUrl(); render(); });

  /* mobile sheet toggles */
  sheet.toggleBtn?.addEventListener('click', () => openSheet(sheet.el));
  sheet.close?.addEventListener('click', () => closeSheet(sheet.el));
  sheet.apply?.addEventListener('click', () => {
    // mirror selections back to sidebar state
    syncSheetToSidebar(); closeSheet(sheet.el); syncUrl(); render();
  });
  qsa('[data-close]').forEach(btn => btn.addEventListener('click', e => {
    const target = btn.getAttribute('data-close');
    const el = qs(target);
    if (el) closeSheet(el);
  }));

  /* clear filters (both places) */
  clearButtons.forEach(b => b.addEventListener('click', clearAllFilters));

  /* keyboard shortcuts */
  document.addEventListener('keydown', (e) => {
    if (isEditable(e)) return;
    if (e.key === '/') { e.preventDefault(); searchInput?.focus(); }
    if (e.key.toLowerCase() === 'g') setView('grid');
    if (e.key.toLowerCase() === 'l') setView('list');
    if (e.key.toLowerCase() === 't') setView('timeline');
    if (e.key === 'Escape'){
      // close modal if open, else clear search
      if (!closeModal()) {
        if (searchInput?.value){ searchInput.value=''; state.search=''; syncUrl(); render(); }
      }
    }
  });

  /* deep link to project via hash */
  window.addEventListener('hashchange', handleHashOpen);
  handleHashOpen();

  /* reveal animations */
  const reveal = new IntersectionObserver((entries) => {
    for (const e of entries){
      if (e.isIntersecting) {
        e.target.classList.add('reveal');
        reveal.unobserve(e.target);
      }
    }
  }, {threshold:.12});
  
  /* main render */
  function render(){
    const rows = filtered(projects);
    const sorted = sortRows(rows, state.sort);

    // grid
    views.grid.innerHTML = '';
    const grid = document.createElement('div');
    grid.className = 'grid';
    for (const p of sorted){
      const card = renderCard(p);
      grid.appendChild(card);
      reveal.observe(card);
    }
    views.grid.appendChild(grid);

    // list
    views.list.innerHTML = '';
    const list = document.createElement('div');
    list.className = 'list';
    for (const p of sorted){
      const row = renderRow(p);
      list.appendChild(row);
      reveal.observe(row);
    }
    views.list.appendChild(list);

    // timeline (group by year desc)
    views.timeline.innerHTML = '';
    const groups = groupBy(sorted, p => p.year || 'unknown');
    const years = Object.keys(groups).sort((a,b)=>b-a);
    const tl = document.createElement('div'); tl.className='timeline';
    for (const y of years){
      const g = document.createElement('div'); g.className='time-group';
      const h = document.createElement('div'); h.className='time-year'; h.textContent = y;
      g.appendChild(h);
      for (const p of groups[y]){
        const item = document.createElement('div'); item.className='time-item';
        const t = document.createElement('h4'); t.className='time-title'; t.textContent = p.title;
        const s = document.createElement('div'); s.className='time-sub'; s.textContent = p.subtitle || '';
        const chips = chipRow((p.tags||[]), 'meta-tag small');
        item.append(t,s,chips);
        item.addEventListener('click', () => openProject(p));
        g.appendChild(item);
      }
      tl.appendChild(g);
    }
    views.timeline.appendChild(tl);

    emptyState.hidden = sorted.length !== 0;

    // quick chips: show active filters summary
    renderActiveChips();

    // ensure correct view visibility
    showView(state.view);
  }

  /* build one card */
  function renderCard(p){
    const card = el('article', 'card', {'data-id':p.id});
    const head = el('div','card-head');
    const img = el('img','card-cover',{loading:'lazy',alt:p?.cover?.[0]?.alt||p.title,src:p?.cover?.[0]?.src||'assets/img/placeholder.jpg'});
    const badges = el('div','card-badges');
    (p.tags||[]).slice(0,3).forEach(t => badges.appendChild(el('span','badge',{},t)));
    head.append(img,badges);

    const body = el('div','card-body');
    const title = el('h3','card-title',{},p.title);
    const sub = el('p','card-sub',{},p.subtitle||'');
    const desc = el('p','card-desc',{},p.description||'');

    const meta = el('div','card-meta');
    const tagRow = chipRow(p.tech_stack||[], 'meta-tag');
    const small = el('div','small',{}, (p.role||'') + (p.year? ` • ${p.year}`:''));
    meta.append(tagRow, small);

    const actions = el('div','card-actions');
    const more = btn('view details', () => openProject(p));
    actions.appendChild(more);
    if (p.links?.demo) actions.appendChild(linkBtn('demo', p.links.demo));
    if (p.links?.repo) actions.appendChild(copyBtn('copy repo', p.links.repo));
    if (p.links?.case_study) actions.appendChild(linkBtn('case study', p.links.case_study));

    body.append(title, sub, desc, meta, actions);
    card.append(head, body);
    card.addEventListener('click', (e) => {
      if (e.target.closest('a,button,select,input,textarea')) return;
      openProject(p);
    });
    card.querySelectorAll('.meta-tag').forEach(ch => {
      ch.addEventListener('click', (e) => { e.stopPropagation(); toggleFilter(state.tech, ch.textContent); syncUrl(); render(); });
    });
    return card;
  }

  /* list row */
  function renderRow(p){
    const row = el('article','row', {'data-id':p.id});
    const img = el('img','', {loading:'lazy', alt:p?.cover?.[0]?.alt||p.title, src:p?.cover?.[0]?.src||'assets/img/placeholder.jpg'});
    const body = el('div','row-body');
    const title = el('h3','card-title',{},p.title);
    const sub = el('p','card-sub',{},p.subtitle||'');
    const meta = el('div','row-meta');
    (p.tags||[]).forEach(t => meta.appendChild(el('span','meta-tag',{},t)));
    const actions = el('div','card-actions');
    actions.append(btn('details', () => openProject(p)));
    if (p.links?.repo) actions.append(copyBtn('copy repo', p.links.repo));
    body.append(title, sub, meta, actions);
    row.append(img, body);
    row.addEventListener('click', (e) => {
      if (e.target.closest('a,button')) return;
      openProject(p);
    });
    return row;
  }

  /* active chips row */
  function renderActiveChips(){
    quickChips.innerHTML = '';
    const act = [...state.tags, ...state.tech, ...state.years, ...state.status];
    if (state.featuredOnly) act.push('featured');
    if (state.search) act.push(`“${state.search}”`);
    act.forEach(v => {
      const c = el('button','chip',{'aria-pressed':'true','title':'remove'},v);
      c.addEventListener('click', () => {
        if (v === 'featured'){ state.featuredOnly=false; side.featured.checked=false; mirrorFeaturedToSheet(); }
        toggleFilter(state.tags,v,false); toggleFilter(state.tech,v,false); toggleFilter(state.years,v,false); toggleFilter(state.status,v,false);
        if (state.search === stripQuotes(v)) { state.search=''; searchInput.value=''; }
        syncUrl(); render();
      });
      quickChips.appendChild(c);
    });
  }

  /* filters ui */
  function renderFilters(){
    // sidebar chips
    side.tags.innerHTML = ''; vocab.tags.forEach(v => side.tags.appendChild(chip(v, state.tags)));
    side.tech.innerHTML = ''; vocab.tech.forEach(v => side.tech.appendChild(chip(v, state.tech)));
    side.years.innerHTML = ''; vocab.years.forEach(v => side.years.appendChild(chip(v, state.years)));
    side.status.innerHTML = ''; vocab.status.forEach(v => side.status.appendChild(chip(v, state.status)));
    side.featured.checked = state.featuredOnly;

    // sheet chips (mobile)
    sheet.tags.innerHTML = ''; vocab.tags.forEach(v => sheet.tags.appendChild(chip(v, state.tags, true)));
    sheet.tech.innerHTML = ''; vocab.tech.forEach(v => sheet.tech.appendChild(chip(v, state.tech, true)));
    sheet.years.innerHTML = ''; vocab.years.forEach(v => sheet.years.appendChild(chip(v, state.years, true)));
    sheet.status.innerHTML = ''; vocab.status.forEach(v => sheet.status.appendChild(chip(v, state.status, true)));
    sheet.featured.checked = state.featuredOnly;
  }

  function chip(label, setRef, isMobile=false){
    const c = el('button','chip',{'aria-pressed': setRef.has(label) ? 'true' : 'false'}, label);
    c.addEventListener('click', () => {
      toggleFilter(setRef,label);
      if (!isMobile) mirrorChipToMobile(label);
      else mirrorChipToSidebar(label);
      syncUrl(); render();
    });
    return c;
  }

  function chipRow(items, cls='meta-tag'){
    const row = el('div','meta-tags');
    items.forEach(t => row.appendChild(el('span',cls,{},t)));
    return row;
  }

  function wireChipGroup(container, setRef){
    container?.addEventListener('click', (e) => {
      const b = e.target.closest('.chip'); if (!b) return;
      const v = b.textContent.trim();
      toggleFilter(setRef, v);
      mirrorChipToMobile(v);
      syncUrl(); render();
    });
  }

  function toggleFilter(setRef, val, flip=true){
    if (flip){
      setRef.has(val) ? setRef.delete(val) : setRef.add(val);
    } else {
      setRef.delete(val);
    }
  }

  function mirrorChipToMobile(label){
    qsa('#filters-sheet .chip').forEach(c => {
      if (c.textContent.trim() === label) c.setAttribute('aria-pressed', isActive(label) ? 'true' : 'false');
    });
  }
  function mirrorChipToSidebar(label){
    qsa('.filters .chip').forEach(c => {
      if (c.textContent.trim() === label) c.setAttribute('aria-pressed', isActive(label) ? 'true' : 'false');
    });
  }
  function mirrorFeaturedToSheet(){
    sheet.featured.checked = side.featured.checked = state.featuredOnly;
  }

  function isActive(label){
    return state.tags.has(label) || state.tech.has(label) || state.years.has(label) || state.status.has(label) || (label==='featured' && state.featuredOnly);
  }

  function clearAllFilters(){
    state.tags.clear(); state.tech.clear(); state.years.clear(); state.status.clear(); state.featuredOnly=false; side.featured.checked=false; mirrorFeaturedToSheet();
    searchInput.value=''; state.search='';
    renderFilters(); syncUrl(); render();
  }

  function openSheet(el){ el?.setAttribute('aria-hidden','false'); sheet.toggleBtn?.setAttribute('aria-expanded','true'); }
  function closeSheet(el){ el?.setAttribute('aria-hidden','true'); sheet.toggleBtn?.setAttribute('aria-expanded','false'); }

  function syncSheetToSidebar(){
    // read chips from mobile sheet
    const act = qsa('#filters-sheet .chip[aria-pressed="true"]').map(c => c.textContent.trim());
    state.tags = new Set(act.filter(v => vocab.tags.includes(v)));
    state.tech = new Set(act.filter(v => vocab.tech.includes(v)));
    state.years = new Set(act.filter(v => vocab.years.includes(Number(v))).map(Number));
    state.status = new Set(act.filter(v => vocab.status.includes(v)));
    state.featuredOnly = sheet.featured.checked;
    renderFilters();
  }

  /* filtering + sorting */
  function filtered(rows){
    return rows.filter(p => {
      if (state.featuredOnly && !p.featured) return false;

      // tags
      if (state.tags.size){
        const ok = [...state.tags].every(t => (p.tags||[]).includes(t));
        if (!ok) return false;
      }
      // tech
      if (state.tech.size){
        const ok = [...state.tech].every(t => (p.tech_stack||[]).includes(t));
        if (!ok) return false;
      }
      // years
      if (state.years.size && !state.years.has(p.year)) return false;
      // status
      if (state.status.size && !state.status.has((p.status||'').toLowerCase())) return false;

      // text search
      if (state.search){
        const hay = `${p.title} ${p.subtitle||''} ${p.description||''} ${(p.tags||[]).join(' ')} ${(p.tech_stack||[]).join(' ')}`.toLowerCase();
        if (!hay.includes(state.search.toLowerCase())) return false;
      }
      return true;
    });
  }

  function sortRows(rows, how){
    const copy = rows.slice();
    if (how === 'recent') copy.sort((a,b) => (b.year||0) - (a.year||0) || a.title.localeCompare(b.title));
    if (how === 'a-z') copy.sort((a,b) => a.title.localeCompare(b.title));
    if (how === 'z-a') copy.sort((a,b) => b.title.localeCompare(a.title));
    return copy;
  }

  /* view switching */
  function setView(v){
    state.view = v;
    saveView(v);
    syncUrl();
    showView(v);
  }
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

  /* url sync */
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
    const q = p.toString();
    const url = q ? `?${q}` : location.pathname;
    history.replaceState(null,'',url);
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

  /* modal */
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
    // build carousel (images or pdf iframe if provided via case_study)
    carouselTrack.innerHTML = '';
    const media = (p.cover && p.cover.length) ? p.cover : [{src:'assets/img/placeholder.jpg',alt:p.title}];
    media.forEach(m => {
      if (String(m.src).toLowerCase().endsWith('.pdf')){
        const frame = document.createElement('iframe');
        frame.setAttribute('loading','lazy');
        frame.src = m.src;
        carouselTrack.appendChild(frame);
      } else {
        const img = document.createElement('img');
        img.loading = 'lazy'; img.alt = m.alt || p.title; img.src = m.src;
        carouselTrack.appendChild(img);
      }
    });

    modalEls.kicker.textContent = (p.tags||[]).slice(0,1).join(' • ');
    modalEls.title.textContent = p.title;
    modalEls.sub.textContent = p.subtitle || '';
    modalEls.desc.textContent = p.description || '';

    modalEls.highlights.innerHTML = '';
    (p.highlights||[]).forEach(h => {
      const li = document.createElement('li'); li.textContent = h; modalEls.highlights.appendChild(li);
    });

    modalEls.metrics.innerHTML = '';
    (p.metrics||[]).forEach(m => {
      const card = el('div','metric');
      card.append(el('div','metric-label',{},m.label), el('div','metric-value',{},m.value));
      modalEls.metrics.appendChild(card);
    });

    modalEls.links.innerHTML = '';
    if (p.links?.demo) modalEls.links.appendChild(linkBtn('open demo', p.links.demo));
    if (p.links?.repo) modalEls.links.appendChild(copyBtn('copy repo', p.links.repo));
    if (p.links?.case_study) modalEls.links.appendChild(linkBtn('open case study', p.links.case_study));

    // similar (shared tag overlap)
    const sim = filtered(projects).filter(x => x.id !== p.id).map(x => ({x,score:overlap(p.tags||[], x.tags||[])})).filter(s => s.score>0).sort((a,b)=>b.score-a.score).slice(0,6).map(s=>s.x);
    const wrap = byId('modal-similar'); wrap.innerHTML='';
    sim.forEach(sp => wrap.appendChild(renderMini(sp)));

    // open + hash
    openModal();
    location.hash = `project-${p.id}`;
  }

  function renderMini(p){
    const a = el('a','card',{'href':`#project-${p.id}`});
    const img = el('img','card-cover',{loading:'lazy',alt:p?.cover?.[0]?.alt||p.title,src:p?.cover?.[0]?.src||'assets/img/placeholder.jpg'});
    const body = el('div','card-body');
    const t = el('h4','card-title',{},p.title);
    body.appendChild(t);
    a.append(img, body);
    a.addEventListener('click', (e) => { e.preventDefault(); openProject(p); });
    return a;
  }

  function openModal(){
    modal?.setAttribute('aria-hidden','false');
    trapFocus(modal);
    // focus scroller for keyboard
    qs('.modal-scroller')?.focus();
  }
  function closeModal(){
    if (!modal || modal.getAttribute('aria-hidden') === 'true') return false;
    modal.setAttribute('aria-hidden','true');
    if (location.hash.startsWith('#project-')) history.replaceState(null,'',location.pathname + location.search);
    return true;
  }

  function handleHashOpen(){
    const h = location.hash;
    if (h.startsWith('#project-')){
      const id = h.replace('#project-','');
      const p = projects.find(p => p.id === id);
      if (p) openProject(p);
    }
  }

  let slideIndex = 0;
  function slide(dir){
    const track = carouselTrack;
    const count = track.children.length;
    if (!count) return;
    slideIndex = (slideIndex + dir + count) % count;
    track.scrollTo({left: track.clientWidth * slideIndex, behavior:'smooth'});
  }

  /* helpers */
  function el(tag, cls, attrs={}, text){
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    Object.entries(attrs||{}).forEach(([k,v]) => n.setAttribute(k,String(v)));
    if (text !== undefined) n.textContent = text;
    return n;
  }
  function btn(label, onClick){
    const b = el('button','btn',{},label);
    b.addEventListener('click', (e) => { e.stopPropagation(); onClick?.(e); });
    return b;
  }
  function linkBtn(label, href){
    const a = el('a','btn ghost', {href, target:'_blank', rel:'noopener'}, label);
    a.addEventListener('click', e => e.stopPropagation());
    return a;
  }
  function copyBtn(label, text){
    const b = el('button','btn ghost',{},label);
    b.addEventListener('click', async (e) => {
      e.stopPropagation();
      try{
        await navigator.clipboard.writeText(text);
        toast('copied');
      }catch{}
    });
    return b;
  }
  function toast(msg){
    const t = el('div','toast',{},msg);
    Object.assign(t.style,{position:'fixed',bottom:'1rem',left:'50%',transform:'translateX(-50%)',background:'var(--card)',border:'1px solid var(--border)',padding:'.5rem .75rem',borderRadius:'12px',zIndex:80});
    document.body.appendChild(t);
    setTimeout(()=>t.remove(),1200);
  }
  function uniq(a){ return [...new Set(a)]; }
  function groupBy(arr, fn){
    return arr.reduce((m, x) => {
      const k = fn(x); (m[k]||(m[k]=[])).push(x); return m;
    }, {});
  }
  function overlap(a,b){ return a.filter(x => b.includes(x)).length; }
  function debounce(fn, ms){ let t; return (...args)=>{ clearTimeout(t); t=setTimeout(()=>fn(...args),ms); }; }
  function isEditable(e){ const n = e.target; return ['input','textarea','select'].includes(n.tagName.toLowerCase()) || n.isContentEditable; }
  function stripQuotes(s){ return s.replace(/^“|”$/g,''); }

  /* focus trap for modal */
  function trapFocus(scope){
    const sel = 'a[href],button:not([disabled]),textarea,input,select,[tabindex]:not([tabindex="-1"])';
    const focusables = () => qsa(sel, scope).filter(el => el.offsetParent !== null);
    const first = () => focusables()[0], last = () => focusables().slice(-1)[0];

    function onKey(e){
      if (e.key !== 'Tab') return;
      const f = focusables(); if (!f.length) return;
      if (e.shiftKey && document.activeElement === first()){ e.preventDefault(); last()?.focus(); }
      else if (!e.shiftKey && document.activeElement === last()){ e.preventDefault(); first()?.focus(); }
    }
    scope.addEventListener('keydown', onKey, {once:true});
  }

  /* initial focus style for parallax fade on header logo */
  document.addEventListener('scroll', () => {
    const hdr = qs('.site-header');
    if (!hdr) return;
    const y = Math.min(1, window.scrollY / 220);
    hdr.style.backdropFilter = `saturate(${140 - y*20}%) blur(${10 - y*4}px)`;
    const mark = qs('.brand-mark');
    if (mark) mark.style.transform = `scale(${1 - y*0.06})`;
    const text = qs('.brand-text');
    if (text) text.style.opacity = String(1 - y*0.15);
  }, {passive:true});

  /* initial reveal */
  function renderChipsRow(){
    // pre-populate quick chips with a few common tags for quick filtering
    const common = ['sql development','architecture','analytics','operations','finance','compliance'];
    quickChips.innerHTML = '';
    common.forEach(tag => {
      const c = el('button','chip',{'aria-pressed': state.tags.has(tag) ? 'true':'false'}, tag);
      c.addEventListener('click', () => { toggleFilter(state.tags, tag); mirrorChipToMobile(tag); syncUrl(); render(); });
      quickChips.appendChild(c);
    });
  }

})();
