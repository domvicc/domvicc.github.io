// assets/js/projects/ui.js
// note: expects PROJECTS to define { tabs: string[], defaultTab?: string, svg?, script?, charts? }
// and the page to include elements: #wb-stage (content area), #wb-tabs (tab bar),
// .project-details[data-project], and .tree-item[data-id]

import { PROJECTS } from './data.js';
import { render_auto_inline, renderCharts } from './viewer.js';

const stage = document.getElementById('wb-stage');
const tabsBar = document.getElementById('wb-tabs');

function renderTab(project, label){
  stage.innerHTML = '';
  const cfg = PROJECTS[project] || {};

  if (label === 'Architecture' && cfg.svg){
    render_auto_inline(stage, cfg.svg);

  } else if (label === 'Code' && cfg.script){
    fetch(cfg.script)
      .then(r => r.text())
      .then(txt => {
        const pre = document.createElement('pre');
        Object.assign(pre.style, {
          margin: 0,
          padding: '14px',
          background: '#0a0f1e',
          color: '#fff',
          fontSize: '.8rem',
          lineHeight: '1.4',
          overflow: 'auto',
          height: '100%'
        });
        pre.textContent = txt;
        stage.appendChild(pre);
      })
      .catch(() => { stage.textContent = 'script failed to load'; });

  } else if (label === 'Charts' && cfg.charts){
    renderCharts(stage, cfg);

  } else {
    const ph = document.createElement('div');
    ph.className = 'placeholder';
    ph.textContent = 'content for ' + label + ' goes here.';
    stage.appendChild(ph);
  }
}

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

function showProject(id){
  // toggle active details
  document.querySelectorAll('.project-details').forEach(sec => {
    sec.classList.toggle('active', sec.dataset.project === id);
  });

  // toggle active in tree
  document.querySelectorAll('.tree-item').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.id === id);
  });

  // build tabs and open default tab
  buildTabs(id);
  const cfg = PROJECTS[id] || {};
  const def = cfg.defaultTab || (cfg.tabs && cfg.tabs[0]);
  const btn =
    [...tabsBar.querySelectorAll('.tab')].find(t => t.textContent === def) ||
    tabsBar.querySelector('.tab');

  if (btn) btn.click();
}

export { buildTabs, renderTab, showProject };
