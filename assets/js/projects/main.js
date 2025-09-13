// assets/js/projects/main.js
import './viewer.js'; // ensures named exports are loaded
import { PROJECTS } from './data.js';
import { buildTabs, showProject } from './ui.js';

// wire tree
document.querySelectorAll('.tree-item').forEach(btn => {
  btn.addEventListener('click', () => {
    const id = btn.dataset.id;
    if (PROJECTS[id]) showProject(id);
  });
});

// init default
showProject('dgai');
