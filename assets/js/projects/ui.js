// assets/js/projects/ui.js
import { PROJECTS } from './data.js';
import { render_auto_inline, renderCharts } from './viewer.js';

const stage = document.getElementById('wb-stage');
const tabsBar = document.getElementById('wb-tabs');

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
    }
export { buildTabs, renderTab, showProject };