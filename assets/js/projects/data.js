// assets/js/projects/data.js
export const PROJECTS={
    dgai:{
      tabs:['Architecture'],
      defaultTab:'Architecture',
      svg:'assets/svg/DGAI.svg'
    },
    'pdf-svg-util':{
      tabs:['Code'],
      defaultTab:'Code',
      script:'assets/py/pdf_to_svg.py'
    },
    'cc-fraud-nn':{
      tabs:['Charts','Code'],          // added Charts tab
      defaultTab:'Code',
      script:'assets/py/credit_card_fraud_detection_neural_network.py',
      charts:[
        {
          file:'threshold_tuning.png',
          title:'Threshold Tuning – Precision vs Recall',
          alt:'Precision and recall versus decision threshold curve',
          desc:'How tightening the cutoff trades fewer false alerts for more missed fraud. Start near the bend where precision and recall separate.'
        },
        {
          file:'roc_curve.png',
            title:'ROC Curve',
            alt:'ROC curve with high top-left bend',
            desc:'Shows overall separation power (AUC 0.9821). Good for comparing models; not ideal alone for threshold choice on rare events.'
        },
        {
          file:'precision_recall_curve.png',
          title:'Precision–Recall Curve',
          alt:'Precision-recall curve for rare fraud detection',
          desc:'Focuses on alert quality vs fraud coverage. Falling edge shows diminishing returns from lowering the threshold further.'
        },
        {
          file:'reliability_curve.png',
          title:'Reliability (Calibration)',
          alt:'Calibration curve comparing predicted to observed fraud rate',
          desc:'Near-diagonal + low Brier score → scores approximate true risk; supports tiered actions and cost optimization.'
        },
        {
          file:'confusion_matrix.png',
          title:'Confusion Matrix (Normalized)',
          alt:'Normalized confusion matrix at 0.50 threshold',
          desc:'High recall but low precision at default 0.50 due to rarity. Raise threshold if analyst queue is overloaded.'
        },
        {
          file:'threshold_tuning.png',   // changed from risk_map.png
          title:'Threshold Tuning Focus View',
          alt:'Threshold tuning chart highlighting optimal operating region',
          desc:'Secondary view of the threshold tuning curve used to call out the practical operating band where small threshold shifts materially change alert volume or missed fraud.'
        }
      ]
    }
  };
