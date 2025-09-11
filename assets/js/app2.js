/* app2.js
   floating viewers demo: pdf.js, svg pan/zoom, deep-zoom tiles
   - code is written in lowercase per preference
*/

(() => {
  'use strict';

  // ---------- config (edit paths to match your repo) ----------
  // resources are resolved relative to the page (document.baseURI) so
  // projects3.html can inject this script from assets/js/ without breaking fetch/iframe urls
  const resolve = (p) => new URL(p, document.baseURI).href;
  const cfg = {
    // matches the hint in projects3.html
    pdfjs_viewer: resolve('assets/pdfjs/web/viewer.html?file=../../pdf/DGAI.pdf'),
    svg_file: resolve('assets/svg/DGAI.svg'),
    deepzoom_dzi: resolve('assets/tiles/dgai.dzi')
  };

  // ---------- utils ----------
  const $ = (s, root=document) => root.querySelector(s);
  const $$ = (s, root=document) => [...root.querySelectorAll(s)];
  let z = 21;

  function bring_to_front(el){ el.style.zIndex = String(++z); }

  // ---------- panel (draggable + resizable + maximizable) ----------
  function make_panel({ title='viewer', content }){
    const panel = document.createElement('div');
    panel.className = 'panel';
    panel.innerHTML = `
      <div class="panel-head">
        <div class="panel-title">${title}</div>
        <div class="panel-actions">
          <button class="icon-btn" data-act="max" title="toggle maximize">⤢</button>
          <button class="icon-btn" data-act="close" title="close">✕</button>
        </div>
      </div>
      <div class="panel-body"></div>
      <div class="panel-resizer" title="resize"></div>
    `;
    document.body.appendChild(panel);
    bring_to_front(panel);

    const head = $('.panel-head', panel);
    const body = $('.panel-body', panel);
    const resizer = $('.panel-resizer', panel);

    // drag
    let drag = null;
    head.addEventListener('pointerdown', (e) => {
      if ((e.target).closest('.panel-actions')) return;
      bring_to_front(panel);
      drag = { x: e.clientX, y: e.clientY, left: panel.offsetLeft, top: panel.offsetTop };
      head.setPointerCapture(e.pointerId);
    });
    head.addEventListener('pointermove', (e) => {
      if (!drag) return;
      const dx = e.clientX - drag.x;
      const dy = e.clientY - drag.y;
      panel.style.left = `${drag.left + dx}px`;
      panel.style.top  = `${drag.top + dy}px`;
      panel.style.right = 'auto';
      panel.style.bottom = 'auto';
    });
    head.addEventListener('pointerup', () => { drag = null; });

    // resize
    let sizing = null;
    resizer.addEventListener('pointerdown', (e) => {
      bring_to_front(panel);
      sizing = { x: e.clientX, y: e.clientY, w: panel.offsetWidth, h: panel.offsetHeight };
      resizer.setPointerCapture(e.pointerId);
    });
    resizer.addEventListener('pointermove', (e) => {
      if (!sizing) return;
      const dx = e.clientX - sizing.x;
      const dy = e.clientY - sizing.y;
      panel.style.width  = `${Math.max(420, sizing.w + dx)}px`;
      panel.style.height = `${Math.max(300, sizing.h + dy)}px`;
    });
    resizer.addEventListener('pointerup', () => { sizing = null; });

    // actions
    panel.addEventListener('click', (e) => {
      const btn = (e.target).closest && (e.target).closest('[data-act]');
      if (!btn) return;
      const act = btn.getAttribute('data-act');
      if (act === 'close') panel.remove();
      if (act === 'max') {
        panel.dataset.state = panel.dataset.state === 'max' ? '' : 'max';
        bring_to_front(panel);
      }
    });

    // inject provided content
    if (typeof content === 'function') {
      content(body);
    } else if (content instanceof HTMLElement) {
      body.appendChild(content);
    } else if (typeof content === 'string') {
      body.innerHTML = content;
    }

    return panel;
  }

  // ---------- option 1: pdf.js floating panel ----------
  function open_pdfjs(){
    make_panel({
      title: 'pdf.js viewer',
      content: (body) => {
        const iframe = document.createElement('iframe');
        iframe.src = cfg.pdfjs_viewer;
        iframe.title = 'pdf.js viewer';
        iframe.loading = 'lazy';
        body.appendChild(iframe);
      }
    });
  }

  // ---------- option 2: svg pan/zoom canvas (vanilla) ----------
  function open_svg(){
    make_panel({
      title: 'svg canvas',
      content: async (body) => {
        const stage = document.createElement('div');
        stage.className = 'svg-stage';
        body.appendChild(stage);

        // try to fetch external svg; fallback to a simple placeholder svg
        let svg_text = '';
        try{
          const resp = await fetch(cfg.svg_file, {cache:'no-store'});
          if (resp.ok) svg_text = await resp.text();
        }catch(e){ /* ignore */ }

        if (!svg_text){
          svg_text = `<svg class="svg-canvas" width="1400" height="900" viewBox="0 0 1400 900" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="grad" x1="0" x2="1" y1="0" y2="1">
                <stop offset="0%" stop-color="#22d3ee"/><stop offset="100%" stop-color="#818cf8"/>
              </linearGradient>
            </defs>
            <rect x="0" y="0" width="1400" height="900" fill="#ffffff"/>
            <g id="g" font-family="inter, sans-serif">
              <rect x="120" y="120" width="1160" height="660" rx="18" fill="url(#grad)" opacity=".08" stroke="#e5e7eb"/>
              <text x="700" y="180" text-anchor="middle" font-size="28" fill="#111827">svg canvas placeholder</text>
              <text x="700" y="215" text-anchor="middle" font-size="15" fill="#374151">replace assets/svg/DGAI.svg to load your diagram</text>
              <circle cx="700" cy="450" r="140" fill="url(#grad)" opacity=".25"/>
              <rect x="520" y="380" width="360" height="140" rx="12" fill="#ffffff" stroke="#d1d5db"/>
              <text x="700" y="455" text-anchor="middle" font-size="16" fill="#111827">drag to pan • scroll to zoom • dbl-click to reset</text>
            </g>
          </svg>`;
        }

        stage.innerHTML = svg_text;
        const svg = stage.querySelector('svg');
        svg.classList.add('svg-canvas');

        // basic pan/zoom state
        let scale = 1, x = 0, y = 0;
        const min = 0.4, max = 8;
        let dragging = false, lx = 0, ly = 0;

        function apply(){
          svg.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
        }
        function clamp(v, a, b){ return Math.min(Math.max(v, a), b); }
        function local(cx, cy){
          const r = stage.getBoundingClientRect();
          return {x: cx - r.left, y: cy - r.top};
        }
        function zoom_at(cx, cy, f){
          const p = local(cx, cy);
          const s0 = scale;
          scale = clamp(scale * f, min, max);
          x = p.x - (p.x - x) * (scale / s0);
          y = p.y - (p.y - y) * (scale / s0);
          apply();
        }

        // wheel zoom
        stage.addEventListener('wheel', (e) => {
          e.preventDefault();
          zoom_at(e.clientX, e.clientY, e.deltaY < 0 ? 1.1 : 1/1.1);
        }, {passive:false});

        // drag pan
        stage.addEventListener('pointerdown', (e) => {
          dragging = true; stage.classList.add('is-dragging');
          lx = e.clientX; ly = e.clientY; stage.setPointerCapture(e.pointerId);
        });
        stage.addEventListener('pointermove', (e) => {
          if (!dragging) return;
          x += e.clientX - lx; y += e.clientY - ly; lx = e.clientX; ly = e.clientY; apply();
        });
        stage.addEventListener('pointerup', () => { dragging = false; stage.classList.remove('is-dragging'); });

        // double click reset / zoom-in
        stage.addEventListener('dblclick', (e) => {
          e.preventDefault();
          if (scale !== 1 || x !== 0 || y !== 0){ scale = 1; x = 0; y = 0; apply(); }
          else { zoom_at(e.clientX, e.clientY, 2); }
        });

        apply();
      }
    });
  }

  // ---------- option 3: deep-zoom (openseadragon) ----------
  function open_deepzoom(){
    make_panel({
      title: 'deep-zoom',
      content: (body) => {
        const wrap = document.createElement('div');
        wrap.className = 'dz-stage';
        body.appendChild(wrap);

        if (window.OpenSeadragon){
          const viewer = window.OpenSeadragon({
            element: wrap,
            prefixUrl: 'https://cdnjs.cloudflare.com/ajax/libs/openseadragon/4.1.0/images/',
            showNavigator: true,
            navigatorPosition: 'BOTTOM_RIGHT',
            animationTime: 0.8,
            blendTime: 0.2,
            springStiffness: 8.0,
            minZoomImageRatio: 0.5,
            tileSources: cfg.deepzoom_dzi
          });
          // expose for debugging
          window.dz = viewer;
        } else {
          wrap.innerHTML = '<div class="fallback">openseadragon failed to load. check cdn or network.</div>';
        }
      }
    });
  }

  // ---------- bind buttons ----------
  $$('.btn[data-open="pdfjs"]').forEach(b => b.addEventListener('click', open_pdfjs));
  $$('.btn[data-open="svg"]').forEach(b => b.addEventListener('click', open_svg));
  $$('.btn[data-open="deepzoom"]').forEach(b => b.addEventListener('click', open_deepzoom));
})();
