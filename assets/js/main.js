// basic scripts
// tip: this keeps the mobile nav usable. you can add more scripts as needed.

(function () {
  const toggle = document.querySelector('.nav-toggle');
  const nav = document.getElementById('site-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      const isOpen = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', String(isOpen));
    });
  }

  // tip: smooth-scroll for same-page anchors (optional extension point)
  document.querySelectorAll('a[href^="#"]').forEach((a) => {
    a.addEventListener('click', (e) => {
      const id = a.getAttribute('href').slice(1);
      const el = document.getElementById(id);
      if (el) {
        e.preventDefault();
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });
  
  // subtle parallax for hero logo on scroll
  const heroLogo = document.querySelector('.hero-logo');
  if (heroLogo) {
    let lastY = 0;
    window.addEventListener('scroll', () => {
      const y = window.scrollY;
      // small parallax offset, dampened
      const offset = Math.round((y - lastY) * 0.06 + y * 0.02);
      heroLogo.style.transform = `translateY(${offset}px)`;
      lastY = y;
    }, { passive: true });
  }
})();
