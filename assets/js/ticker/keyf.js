
// script to load min/max values for the key financial bars (cleaned: removed <script> tags that break external JS loading)

/**
 * Load financial metrics pulling:
 *  - revenue & grossProfit from ticker/income_statement/<SYMBOL>.json (annualReports[mostRecent])
 *  - netIncome & operatingIncome from ticker/balance_sheet/<SYMBOL>.json (if absent, fallback to income_statement values with warning)
 * @param {string[]} symbols - Array of ticker symbols (e.g. ['AAPL','MSFT']).
 * @param {object} [opts]
 * @param {number} [opts.reportIndex=0] - Which annualReports index to use (0 = most recent if file already ordered newest->oldest as appears in sample).
 * @returns {Promise<{allData: Array<{symbol:string,revenue:number,gross:number,net:number,op:number}>, metrics: Record<string,{min:number,max:number}>}>}
 */
async function loadData(symbols, opts = {}) {
  if (!Array.isArray(symbols) || symbols.length === 0) {
    throw new Error("loadData(symbols): 'symbols' must be a non-empty array");
  }
  const { reportIndex = 0 } = opts;

  const INCOME_DIR = 'ticker/income_statement/';
  const BALANCE_DIR = 'ticker/balance_sheet/';

  const metrics = {
    revenue: { min: Infinity, max: -Infinity },
    grossProfit: { min: Infinity, max: -Infinity },
    netIncome: { min: Infinity, max: -Infinity },
    operatingIncome: { min: Infinity, max: -Infinity }
  };

  const allData = [];

  for (const symbol of symbols) {
    try {
      const incomePath = `${INCOME_DIR}${symbol}.json`;
      const balancePath = `${BALANCE_DIR}${symbol}.json`;

      const [incomeJson, balanceJson] = await Promise.all([
        fetchJson(incomePath).catch(() => { console.warn(`loadData: income statement fetch failed for ${symbol}`); return null; }),
        fetchJson(balancePath).catch(() => { console.warn(`loadData: balance sheet fetch failed for ${symbol}`); return null; })
      ]);

      if (!incomeJson && !balanceJson) continue; // nothing to use

      const incomeReport = Array.isArray(incomeJson?.annualReports) ? incomeJson.annualReports[reportIndex] : undefined;
      const balanceReport = Array.isArray(balanceJson?.annualReports) ? balanceJson.annualReports[reportIndex] : undefined;

      // revenue & gross from income statement
      const revenue = toNumber(incomeReport?.totalRevenue ?? incomeReport?.revenue);
      const gross = toNumber(incomeReport?.grossProfit);

      // net & operating from balance sheet (per requirement) but fall back to income statement if missing
      let net = toNumber(balanceReport?.netIncome);
      let op = toNumber(balanceReport?.operatingIncome);
      if (!net && toNumber(incomeReport?.netIncome)) {
        console.warn(`loadData: netIncome not found in balance sheet for ${symbol}, using income_statement value`);
        net = toNumber(incomeReport?.netIncome);
      }
      if (!op && toNumber(incomeReport?.operatingIncome)) {
        console.warn(`loadData: operatingIncome not found in balance sheet for ${symbol}, using income_statement value`);
        op = toNumber(incomeReport?.operatingIncome);
      }

      allData.push({ symbol, revenue, gross, net, op });

      updateMetric(metrics.revenue, revenue);
      updateMetric(metrics.grossProfit, gross);
      updateMetric(metrics.netIncome, net);
      updateMetric(metrics.operatingIncome, op);
    } catch (err) {
      console.error(`loadData: error processing symbol ${symbol}`, err);
    }
  }

  if (allData.length === 0) {
    Object.values(metrics).forEach(m => { m.min = 0; m.max = 1; });
  }

  return { allData, metrics };
}

// Fetch helper that works in browser (native fetch) and Node (fs read) for local testing.
async function fetchJson(path) {
  if (typeof window !== 'undefined' && typeof window.fetch === 'function') {
    const resp = await fetch(path);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return resp.json();
  }
  // Node environment fallback
  const fs = await import('node:fs/promises');
  const urlLike = path.startsWith('http://') || path.startsWith('https://');
  if (urlLike) {
    // dynamic import for node fetch if needed
    const undici = await import('node-fetch').catch(() => null);
    if (!undici) throw new Error('node-fetch not installed for remote URL');
    const r = await undici.default(path);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return r.json();
  }
  const data = await fs.readFile(path, 'utf8');
  return JSON.parse(data);
}

function toNumber(val) {
  const num = Number(val);
  return Number.isFinite(num) ? num : 0;
}

function updateMetric(metric, value) {
  metric.min = Math.min(metric.min, value);
  metric.max = Math.max(metric.max, value);
}

function scale(value, min, max) {
  if (max === min) return 1; // avoid divide by zero -> full bar
  return (value - min) / (max - min);
}

/**
 * Render the bars for a single company/record into DOM elements by id.
 * Expects elements with ids: revenueBar, grossBar, netIncomeBar, operatingIncomeBar
 * @param {{revenue:number,gross:number,net:number,op:number}} data
 * @param {{revenue:{min:number,max:number},grossProfit:{min:number,max:number},netIncome:{min:number,max:number},operatingIncome:{min:number,max:number}}} metrics
 */
function renderBars(data, metrics) {
  if (!data || !metrics) return;

  const elMap = {
    revenueBar: scale(data.revenue, metrics.revenue.min, metrics.revenue.max) * 100,
    grossBar: scale(data.gross, metrics.grossProfit.min, metrics.grossProfit.max) * 100,
    netIncomeBar: scale(data.net, metrics.netIncome.min, metrics.netIncome.max) * 100,
    operatingIncomeBar: scale(data.op, metrics.operatingIncome.min, metrics.operatingIncome.max) * 100
  };

  for (const [id, pct] of Object.entries(elMap)) {
    const el = document.getElementById(id);
    if (el) {
      el.style.width = pct.toFixed(2) + '%';
      el.setAttribute('data-value', pct.toFixed(2));
    } else {
      // Only warn once per missing id
      if (!renderBars._missing) renderBars._missing = new Set();
      if (!renderBars._missing.has(id)) {
        console.warn(`renderBars: element #${id} not found`);
        renderBars._missing.add(id);
      }
    }
  }
}

/**
 * Convenience initializer: loads all files, then renders the bars for a chosen index (default 0)
 * @param {string[]} files
 * @param {number} [recordIndex=0]
 */
async function initKeyFinancialBars(symbols, reportIndex = 0) {
  try {
    const { allData, metrics } = await loadData(symbols, { reportIndex });
    if (allData.length === 0) {
      console.warn('initKeyFinancialBars: no data loaded');
      return;
    }
    const idx = Math.min(Math.max(0, reportIndex), allData.length - 1);
    renderBars(allData[idx], metrics);
  } catch (e) {
    console.error('initKeyFinancialBars error', e);
  }
}

// Expose to global scope if loaded via <script src="..."> (no bundler scenario)
if (typeof window !== 'undefined') {
  window.KeyFinancial = { loadData, renderBars, initKeyFinancialBars };

  /**
   * Initialize and control the Key Financials bar widget using global min/max across all symbols.
   * Expects DOM elements with ids: revenue-bar, gross-profit-bar, net-income-bar, operating-income-bar
   * and value labels: revenue-value, gross-profit-value, net-income-value, operating-income-value.
   * @param {string[]} symbols - Ticker symbols to build global min/max context.
   * @param {string} initialSymbol - Symbol to display first.
   * @param {number} reportIndex - Annual report index to use.
   */
  async function initGlobalKeyFinancialBars(symbols, initialSymbol, reportIndex = 0) {
    if (!Array.isArray(symbols) || symbols.length === 0) return;
    try {
      const { allData, metrics } = await loadData(symbols, { reportIndex });
      // map for quick lookup
      const map = new Map(allData.map(r => [r.symbol.toUpperCase(), r]));

      function setWidths(record) {
        if (!record) return;
        const els = {
          revenue: document.getElementById('revenue-bar'),
          grossProfit: document.getElementById('gross-profit-bar'),
          netIncome: document.getElementById('net-income-bar'),
          operatingIncome: document.getElementById('operating-income-bar')
        };
        const values = {
          revenue: record.revenue,
          grossProfit: record.gross,
          netIncome: record.net,
          operatingIncome: record.op
        };
        for (const k of Object.keys(els)) {
          const el = els[k];
          if (!el) continue;
          const { min, max } = metrics[k];
          const span = max - min;
          const scaled = span === 0 ? 1 : (values[k] - min) / span;
          const pct = Math.max(0, Math.min(1, scaled)) * 100;
          el.style.width = pct.toFixed(2) + '%';
          el.setAttribute('data-scale', pct.toFixed(2) + '%');
          el.setAttribute('title', `${k} range ${(min/1e9).toFixed(1)}B - ${(max/1e9).toFixed(1)}B`);
        }
        // value labels (billions)
        const fmtB = v => '$' + (v/1e9).toFixed(1) + 'B';
        const labelMap = {
          'revenue-value': fmtB(record.revenue),
          'gross-profit-value': fmtB(record.gross),
          'net-income-value': fmtB(record.net),
          'operating-income-value': fmtB(record.op)
        };
        for (const [id,val] of Object.entries(labelMap)) {
          const el = document.getElementById(id);
          if (el) el.textContent = val;
        }
      }

      // initial render
      setWidths(map.get((initialSymbol || symbols[0]).toUpperCase()));

      // expose a small API for switching symbol without recomputing globals
      window.KeyFinancial.global = {
        metrics,
        data: allData,
        setSymbol(sym) { setWidths(map.get(sym.toUpperCase())); }
      };
    } catch (e) {
      console.error('initGlobalKeyFinancialBars error', e);
    }
  }

  // extend export
  if (typeof window !== 'undefined') {
    window.KeyFinancial.initGlobalKeyFinancialBars = initGlobalKeyFinancialBars;
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports.initGlobalKeyFinancialBars = initGlobalKeyFinancialBars;
  }
}

// Node / CommonJS export for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { loadData, renderBars, initKeyFinancialBars, scale };
}

// Optional auto-init example (comment out if controlling manually):
// document.addEventListener('DOMContentLoaded', () => {
//   initKeyFinancialBars([
//     'data/aapl.json',
//     'data/msft.json'
//   ]);
// });