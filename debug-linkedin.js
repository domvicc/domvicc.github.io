// Debug script to check if LinkedIn scraper project is working
console.log('=== LinkedIn Scraper Debug ===');

// Create debug output element
const debugDiv = document.createElement('div');
debugDiv.id = 'debug-output';
debugDiv.style.cssText = `
    position: fixed;
    top: 10px;
    right: 10px;
    background: #000;
    color: #0f0;
    padding: 10px;
    font-family: monospace;
    font-size: 12px;
    z-index: 10000;
    max-width: 400px;
    max-height: 300px;
    overflow: auto;
    border: 1px solid #0f0;
`;

function debugLog(message) {
    console.log(message);
    debugDiv.innerHTML += message + '<br>';
}

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
    document.body.appendChild(debugDiv);
    
    debugLog('=== LinkedIn Scraper Debug ===');
    debugLog('DOM Content Loaded');
    
    // Check if elements exist
    const linkedinButton = document.querySelector('[data-id="linkedin-scraper"]');
    const linkedinDetails = document.querySelector('[data-project="linkedin-scraper"]');
    
    debugLog('LinkedIn button found: ' + !!linkedinButton);
    debugLog('LinkedIn details found: ' + !!linkedinDetails);
    
    if (linkedinButton) {
        debugLog('Button classes: ' + linkedinButton.className);
        debugLog('Button data-id: ' + linkedinButton.dataset.id);
        debugLog('Button has tree-item class: ' + linkedinButton.classList.contains('tree-item'));
        
        // Test manual click
        linkedinButton.addEventListener('click', () => {
            debugLog('LinkedIn button clicked manually!');
            alert('LinkedIn button clicked!');
        });
        
        // Add visual indicator
        linkedinButton.style.border = '2px solid red';
        linkedinButton.title = 'DEBUG: This button should be clickable!';
    } else {
        debugLog('ERROR: LinkedIn button NOT found!');
    }
    
    if (linkedinDetails) {
        debugLog('Details classes: ' + linkedinDetails.className);
        debugLog('Details data-project: ' + linkedinDetails.dataset.project);
    } else {
        debugLog('ERROR: LinkedIn details NOT found!');
    }
    
    // Check all tree items
    const allTreeItems = document.querySelectorAll('.tree-item');
    debugLog('Total tree items found: ' + allTreeItems.length);
    allTreeItems.forEach((item, index) => {
        debugLog(`Tree item ${index}: ${item.dataset.id} - "${item.textContent.trim().substring(0, 30)}..."`);
    });
});

// Listen for all clicks to see if anything is working
document.addEventListener('click', (e) => {
    if (e.target.matches('.tree-item')) {
        debugLog('CLICK: Tree item clicked: ' + e.target.dataset.id);
    }
});

debugLog('Debug script loaded successfully');