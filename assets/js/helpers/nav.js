// assets/js/helpers/nav.js
// tiny nav + year initializer (shared across pages)
(function(){
  const navToggle = document.querySelector('.nav-toggle');
  const nav = document.getElementById('site-nav');
  if (navToggle && nav){
    navToggle.addEventListener('click', () => {
      const open = nav.classList.toggle('open');
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
  const y = document.getElementById('year');
  if (y){ y.textContent = new Date().getFullYear(); }
})();