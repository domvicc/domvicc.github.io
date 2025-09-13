// viewer module for wb-stage (pdf / svg / code)
(() => {
  'use strict';
  const resolve = (p) => new URL(p, document.baseURI).href;

  function viewer_iframe(stage, src){
    const iframe = document.createElement('iframe');
    iframe.style.position='absolute';
    iframe.style.inset='0';
    iframe.style.width='100%';
    iframe.style.height='100%';
    iframe.style.border='0';
    iframe.style.background='#fff';
    iframe.src = src;
    stage.appendChild(iframe);
  }

  function render_pdf(stage, pdf_path){
    // assumes pdf files are under assets/pdf/ and pdfjs viewer lives at assets/pdfjs/web/
    const rel = pdf_path.replace(/^assets\//,''); // e.g., 'pdf/dgai.pdf'
    const vsrc = resolve('assets/pdfjs/web/viewer.html?file=' + encodeURIComponent('../..' + '/' + rel));
    viewer_iframe(stage, vsrc);
  }

  function render_svg(stage, svg_path){
    stage.innerHTML='';
    const wrap = document.createElement('div');
    wrap.className='svg-stage';
    wrap.style.position='absolute';
    wrap.style.inset='0';
    wrap.style.background='#fff';
    wrap.style.overflow='hidden';
    wrap.style.touchAction='none';
    wrap.style.cursor='grab';
    stage.appendChild(wrap);

    fetch(svg_path).then(r => r.ok ? r.text() : Promise.reject(new Error('fetch failed')))
      .then(text => {
        wrap.innerHTML = text;
        const svg = wrap.querySelector('svg');
        if (!svg) throw new Error('no svg root found');
        svg.classList.add('svg-canvas');
        svg.style.transformOrigin = '0 0';

        let scale = 1, x = 0, y = 0;
        const min = 0.4, max = 8;
        let dragging = false, lx = 0, ly = 0;

        function apply(){ svg.style.transform = `translate(${x}px, ${y}px) scale(${scale})`; }

        wrap.addEventListener('wheel', (e) => {
          e.preventDefault();
          const p = e.deltaY < 0 ? 1.1 : 1/1.1;
          scale = Math.min(Math.max(scale * p, min), max);
          apply();
        }, { passive:false });

        wrap.addEventListener('pointerdown', (e) => {
          dragging = true;
          wrap.setPointerCapture(e.pointerId);
          lx = e.clientX; ly = e.clientY;
          wrap.classList.add('is-dragging');
        });

        wrap.addEventListener('pointermove', (e) => {
          if (!dragging) return;
          x += (e.clientX - lx);
          y += (e.clientY - ly);
          lx = e.clientX; ly = e.clientY;
          apply();
        });

        wrap.addEventListener('pointerup', () => {
          dragging = false;
          wrap.classList.remove('is-dragging');
        });

        wrap.addEventListener('dblclick', () => { scale = 1; x = 0; y = 0; apply(); });

        apply();
      })
      .catch(err => {
        const fb = document.createElement('div');
        fb.className = 'placeholder';
        fb.textContent = 'svg failed to load: ' + err.message;
        stage.appendChild(fb);
      });
  }

  function render_code(stage, { src, text, lang } = {}){
    const pre = document.createElement('pre');
    pre.style.margin='0';
    pre.style.padding='1rem';
    pre.style.height='100%';
    pre.style.overflow='auto';
    pre.style.background='#0b1020';
    pre.style.color='#e6e9ef';
    pre.style.border='1px solid #1c2442';
    const code = document.createElement('code');
    code.textContent = '';
    pre.appendChild(code);
    stage.appendChild(pre);

    if (text){ code.textContent = text; return; }
    if (src){
      fetch(src).then(r => r.text())
        .then(t => { code.textContent = t; })
        .catch(e => { code.textContent = 'failed to load code: ' + e.message; });
    }
  }

  function render_auto(stage, input){
    if (typeof input === 'string'){
      const lower = input.toLowerCase();
      if (lower.endsWith('.pdf')) return render_pdf(stage, input);
      if (lower.endsWith('.svg')) return render_svg(stage, input);
      if (/(\.js|\.ts|\.json|\.py|\.sql|\.html|\.css|\.md)$/.test(lower))
        return render_code(stage, { src: input });
      // fallback image
      const img = document.createElement('img');
      img.src = input;
      img.alt = 'preview';
      img.className = 'canvas-image';
      stage.appendChild(img);
      return;
    }
  }

  window.viewer = { render_pdf, render_svg, render_code, render_auto };
})();
