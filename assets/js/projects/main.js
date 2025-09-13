// assets/js/projects/main.js
import { initProjectViewer } from './viewer.js';

const PROJECTS = {
  dgai:{
    tabs:['Overview','Architecture'],
    defaultTab:'Architecture',
    svg:'assets/svg/DGAI.svg'
  },
  'pdf-svg-util':{
    tabs:['Overview','Code'],
    defaultTab:'Code',
    script:'assets/py/pdf_to_svg.py'
  },
  'cc-fraud-nn':{
    tabs:['Code','Charts'],
    defaultTab:'Code',
    script:'assets/py/credit_card_fraud_detection_neural_network.py',
    charts:[
      { file:'threshold_tuning.png', title:'Threshold Tuning – Precision vs Recall', alt:'Precision vs recall by threshold', desc:'Trade-off between alert purity and fraud coverage.' },
      { file:'roc_curve.png', title:'ROC Curve', alt:'ROC curve', desc:'Overall discrimination power (AUC).' },
      { file:'precision_recall_curve.png', title:'Precision–Recall Curve', alt:'PR curve', desc:'Alert quality vs fraud catch on imbalanced data.' },
      { file:'reliability_curve.png', title:'Reliability (Calibration)', alt:'Calibration curve', desc:'How well predicted probabilities match reality.' },
      { file:'confusion_matrix.png', title:'Confusion Matrix (Normalized)', alt:'Normalized confusion matrix', desc:'Recall / precision snapshot at threshold.' },
      { file:'threshold_tuning.png', title:'Threshold Tuning Focus View', alt:'Threshold focus view', desc:'Operating band sensitivity illustration.' }
    ]
  }
};

window.addEventListener('DOMContentLoaded', ()=>{
  try{
    initProjectViewer({
      stage: document.getElementById('wb-stage'),
      tabsBar: document.getElementById('wb-tabs'),
      projects: PROJECTS,
      defaultProject: 'dgai'
    });
  }catch(err){
    console.error('Viewer init failed', err);
    const stage=document.getElementById('wb-stage');
    if(stage){
      stage.innerHTML='<div class="placeholder">Viewer failed: '+err.message+'</div>';
    }
  }
});
