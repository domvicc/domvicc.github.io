// assets/js/projects/main.js
import { initProjectViewer } from './viewer.js';

const PROJECTS = {
  dgai:{
    tabs:['Overview','Architecture'],
    defaultTab:'Overview',
    svg:'assets/svg/DGAI.svg',
    media:[
      {
        file:'assets/img/Ticker Analysis.png',
        title:'Ticker Analysis Dashboard',
        alt:'Screenshot of DomGuardianAI ticker analysis dashboard with candlestick chart and key financials',
        desc:'High-level view of the interactive market analysis dashboard. Use the links in the DomGuardianAI section to open the live homepage and the full Ticker Analysis experience.'
      }
    ]
  },
  'linkedin-scraper':{
    tabs:['Overview','Code'],
    // Set Code as default so code viewer opens first
    defaultTab:'Code',
    script:'assets/py/linkedin_credentials_scrape.py'
  },
  'pdf-svg-util':{
    tabs:['Overview','Code'],
    defaultTab:'Code',
    script:'assets/py/pdf_to_svg.py'
  },
  'cc-fraud-nn':{
    tabs:['Charts','Code'],
    defaultTab:'Charts',
    script:'assets/py/credit_card_fraud_detection_neural_network.py',
    // Chart file names only; viewer.js composes full path:
    // assets/img/cc-fraud/<file>
    charts:[
      { file:'threshold_tuning.png', title:'Threshold Tuning – Precision vs Recall', alt:'Precision vs recall by threshold', desc:'Trade-off between alert purity and fraud coverage.' },
      { file:'roc_curve.png', title:'ROC Curve', alt:'ROC curve', desc:'Overall discrimination power (AUC).' },
      { file:'precision_recall_curve.png', title:'Precision–Recall Curve', alt:'PR curve', desc:'Alert quality vs fraud catch on imbalanced data.' },
      { file:'reliability_curve.png', title:'Reliability (Calibration)', alt:'Calibration curve', desc:'How well predicted probabilities match reality.' },
      { file:'confusion_matrix.png', title:'Confusion Matrix (Normalized)', alt:'Normalized confusion matrix', desc:'Recall / precision snapshot at threshold.' },
      { file:'threshold_tuning.png', title:'Threshold Tuning Focus View', alt:'Threshold focus view', desc:'Operating band sensitivity illustration.' }
    ]
  },
  'quant-rating':{
    tabs:['Overview','Code'],
    defaultTab:'Overview',
    // Reuse code viewer for SQL view definition
    script:'sql/company_quant_rating.sql',
    media:[
      { file:'assets/img/quant_ticker_analysis.png', title:'Radar: Multi-Factor Pillar Scores', alt:'Radar chart of Quality Growth Value Momentum Income Risk pillars', desc:'Power BI radar visualization sourced from Synapse view.' }
    ]
  }
};

window.addEventListener('DOMContentLoaded', ()=>{
  try{
    console.log('PROJECTS configuration:', PROJECTS);
    console.log('Has linkedin-scraper:', 'linkedin-scraper' in PROJECTS);
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

  // Handle export actions
  document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-action]');
    if (!target) return;

    const action = target.dataset.action;
    
    if (action === 'export-linkedin-scraper') {
      e.preventDefault();
      downloadLinkedInScraper();
    }
  });
});

// Export function for LinkedIn scraper
async function downloadLinkedInScraper() {
  try {
    const response = await fetch('assets/py/linkedin_credentials_scrape.py');
    const scriptContent = await response.text();
    
    const blob = new Blob([scriptContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = 'linkedin_credentials_scraper.py';
    a.style.display = 'none';
    
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    
    URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Failed to download LinkedIn scraper:', error);
    alert('Failed to download file. Please try again.');
  }
}
