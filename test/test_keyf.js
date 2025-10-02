// Simple Node test harness for keyf.js
// Run with: node test/test_keyf.js (from repo root)

const path = require('path');
const { loadData } = require('../assets/js/ticker/keyf.js');

(async () => {
  try {
    // Adjust symbols if needed; choose a few that exist
    const symbols = ['AAPL','MSFT','NVDA'];

    // Because keyf.js expects relative paths like ticker/income_statement/AAPL.json
    // ensure CWD is repo root when running.
    const { allData, metrics } = await loadData(symbols, { reportIndex: 0 });

    console.log('Loaded records:', allData.length);
    console.log('Sample first record:', allData[0]);
    console.log('Metrics ranges:', metrics);

    // Basic assertions
    if (!allData.length) throw new Error('No data returned');
    for (const k of ['revenue','grossProfit','netIncome','operatingIncome']) {
      if (metrics[k].min === Infinity || metrics[k].max === -Infinity) {
        throw new Error(`Metric ${k} did not compute min/max`);
      }
    }
    console.log('All basic checks passed.');
  } catch (e) {
    console.error('Test failed:', e);
    process.exit(1);
  }
})();
