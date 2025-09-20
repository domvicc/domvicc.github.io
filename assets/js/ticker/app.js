
// run when dom is ready
document.addEventListener('DOMContentLoaded', () => {
  // feather icons
  if (window.feather && typeof window.feather.replace === 'function') {
    window.feather.replace();
  }

  // aos animations
  if (window.AOS && typeof window.AOS.init === 'function') {
    window.AOS.init();
  }

  // ------------- paths -------------
  // now points to a DIRECTORY that contains one json file per ticker
  const dir_url = 'ticker/daily/'; // trailing slash required

  // ------------- ui elements -------------
  const el_chart = document.getElementById('candlestick_chart');
  const el_status = document.getElementById('chart-status');
  const el_performance = document.getElementById('performance_chart');

  const el_ticker = document.getElementById('ticker-select');
  const el_ticker_filter = document.getElementById('ticker-filter');
  const el_timeframe = document.getElementById('timeframe-select');
  const el_type = document.getElementById('type-select');
  const el_ma5 = document.getElementById('ma5-toggle');
  const el_ma20 = document.getElementById('ma20-toggle');
  const el_volume = document.getElementById('volume-toggle');
  const el_refresh = document.getElementById('refresh-btn');
  const el_download = document.getElementById('download-btn');
  const el_theme = document.getElementById('theme-btn');

  // ------------- state -------------
  /** @type {Map<string, Array<{t: Date, o:number,h:number,l:number,c:number}>>} */
  let ticker_map = new Map();
  /** @type {string[]} */
  let all_tickers = [];
  /** @type {Array<{t: Date, o:number,h:number,l:number,c:number}>} */
  let current_rows = [];
  let current_ticker = 'aapl';

  // ------------- helpers -------------
  const to_arrays = (rows) => {
    const x = [], o = [], h = [], l = [], c = [];
    rows.forEach(r => { x.push(r.t); o.push(r.o); h.push(r.h); l.push(r.l); c.push(r.c); });
    return { x, o, h, l, c };
  };

  const sma = (values, period) => {
    const out = new Array(values.length).fill(null);
    let sum = 0;
    for (let i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period) sum -= values[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  };

  const simulate_volume = (rows) => {
    return rows.map(r => {
      const range = Math.max(1, r.h - r.l);
      return Math.round((range * 2_000_000) + (Math.random() * 6_000_000));
    });
  };

  const fmt_currency = (n) => new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 }).format(n);
  const fmt_date = (d) => new Intl.DateTimeFormat('en-US', { month: 'short', day: '2-digit', year: 'numeric' }).format(d);

  const debounce = (fn, ms=150) => {
    let t;
    return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
  };

  const set_status = (msg) => { if (el_status) el_status.textContent = msg; };

  const get_theme_colors = () => {
    const styles = getComputedStyle(document.body);
    return {
      paper: styles.getPropertyValue('--panel').trim(),
      plot: styles.getPropertyValue('--panel').trim(),
      text: styles.getPropertyValue('--text').trim(),
      grid: styles.getPropertyValue('--grid').trim(),
      good: styles.getPropertyValue('--good').trim(),
      bad: styles.getPropertyValue('--bad').trim(),
      accent: styles.getPropertyValue('--accent').trim(),
      muted: styles.getPropertyValue('--muted').trim(),
      border: styles.getPropertyValue('--border').trim()
    };
  };

  // ------------- json parsing (robust to several shapes) -------------
  const normalize_row = (obj) => {
    const o = obj.o ?? obj.open;
    const h = obj.h ?? obj.high;
    const l = obj.l ?? obj.low;
    const c = obj.c ?? obj.close;

    let dt = obj.t ?? obj.date ?? obj.timestamp ?? obj.time;
    if (typeof dt === 'string') {
      dt = new Date(dt);
    } else if (typeof dt === 'number') {
      if (dt < 2_000_000_000) dt *= 1000;
      dt = new Date(dt);
    } else if (dt instanceof Date) {
      // ok
    } else {
      const y = obj.year ?? obj.y;
      const m = obj.month ?? obj.m;
      const d = obj.day ?? obj.d;
      if (y && m && d) dt = new Date(Number(y), Number(m) - 1, Number(d));
    }

    if (!dt || isNaN(+dt) || [o,h,l,c].some(v => v == null || isNaN(Number(v)))) return null;
    return { t: dt, o: Number(o), h: Number(h), l: Number(l), c: Number(c) };
  };

  const parse_daily_json = (json) => {
    const map = new Map();

    const push_row = (sym, raw) => {
      const row = normalize_row(raw);
      if (!row) return;
      const key = String(sym || raw.ticker || raw.symbol || raw.s || '').toLowerCase();
      if (!key) return;
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(row);
    };

    const parse_array = (arr) => {
      for (const item of arr) {
        if (Array.isArray(item?.data) && (item.symbol || item.ticker || item.s)) {
          const sym = (item.symbol || item.ticker || item.s);
          for (const r of item.data) push_row(sym, r);
        } else {
          const sym = (item.ticker || item.symbol || item.s);
          push_row(sym, item);
        }
      }
    };

    if (Array.isArray(json)) {
      parse_array(json);
    } else if (json && typeof json === 'object') {
      if (Array.isArray(json.data)) {
        parse_array(json.data);
      } else if (Array.isArray(json.tickers)) {
        parse_array(json.tickers);
      } else {
        for (const [sym, rows] of Object.entries(json)) {
          if (Array.isArray(rows)) {
            for (const r of rows) push_row(sym, r);
          }
        }
      }
    }

    for (const [sym, rows] of map) {
      rows.sort((a,b) => a.t - b.t);
      const dedup = [];
      let lastKey = null;
      for (const r of rows) {
        const k = r.t.toISOString().slice(0,10);
        if (k !== lastKey) { dedup.push(r); lastKey = k; } else { dedup[dedup.length-1] = r; }
      }
      map.set(sym, dedup);
    }

    return map;
  };

  const populate_ticker_select = (tickers, selectEl, keepCurrent=false) => {
    if (!selectEl) return;
    const prev = keepCurrent ? (selectEl.value || '').toLowerCase() : '';
    selectEl.innerHTML = '';
    const frag = document.createDocumentFragment();
    for (const t of tickers) {
      const opt = document.createElement('option');
      opt.value = t;
      opt.textContent = t.toUpperCase();
      frag.appendChild(opt);
    }
    selectEl.appendChild(frag);
    if (keepCurrent && prev && tickers.includes(prev)) {
      selectEl.value = prev;
    } else if (tickers.length) {
      selectEl.value = tickers.includes('aapl') ? 'aapl' : tickers[0];
    }
  };

  // ------------- chart renderers -------------
  const render_candles = (rows) => {
    if (!rows || !rows.length) {
      set_status('no data to render');
      return;
    }
    const colors = get_theme_colors();

    const arrays = to_arrays(rows);
    const vol = simulate_volume(rows);
    const vol_colors = arrays.c.map((v, i) => (v >= arrays.o[i] ? colors.good : colors.bad));

    const m5 = sma(arrays.c, 5);
    const m20 = sma(arrays.c, 20);

    const trace_price = {
      type: el_type && el_type.value === 'ohlc' ? 'ohlc' : 'candlestick',
      x: arrays.x,
      open: arrays.o,
      high: arrays.h,
      low: arrays.l,
      close: arrays.c,
      increasing: { line: { color: colors.good } },
      decreasing: { line: { color: colors.bad } },
      name: (el_ticker?.value || current_ticker || 'aapl').toUpperCase(),
      yaxis: 'y',
      hovertemplate:
        '<b>%{x|%b %d, %Y}</b><br>' +
        'o: %{open:.2f}<br>' +
        'h: %{high:.2f}<br>' +
        'l: %{low:.2f}<br>' +
        'c: %{close:.2f}<extra></extra>'
    };

    const trace_ma5 = {
      type: 'scatter',
      mode: 'lines',
      name: 'ma5',
      x: arrays.x,
      y: m5,
      line: { width: 1.2, color: colors.accent },
      yaxis: 'y',
      visible: (el_ma5?.checked ?? true) ? true : 'legendonly',
      hovertemplate: 'ma5: %{y:.2f}<extra></extra>'
    };

    const trace_ma20 = {
      type: 'scatter',
      mode: 'lines',
      name: 'ma20',
      x: arrays.x,
      y: m20,
      line: { width: 1.2, dash: 'dot', color: colors.muted },
      yaxis: 'y',
      visible: (el_ma20?.checked ?? true) ? true : 'legendonly',
      hovertemplate: 'ma20: %{y:.2f}<extra></extra>'
    };

    const trace_volume = {
      type: 'bar',
      name: 'volume',
      x: arrays.x,
      y: vol,
      marker: { color: vol_colors },
      yaxis: 'y2',
      visible: (el_volume?.checked ?? true) ? true : 'legendonly',
      hovertemplate: 'vol: %{y:,}<extra></extra>'
    };

    const last_close = arrays.c[arrays.c.length - 1];
    const last_date = arrays.x[arrays.x.length - 1];

    const layout = {
      paper_bgcolor: colors.paper,
      plot_bgcolor: colors.plot,
      font: { color: colors.text, size: 12 },
      margin: { t: 30, r: 20, b: 35, l: 45 },
      showlegend: true,
      legend: { orientation: 'h', x: 0, y: 1.1 },

      xaxis: {
        domain: [0, 1],
        rangeslider: { visible: true, thickness: 0.07, bgcolor: colors.paper, bordercolor: colors.border },
        rangeselector: {
          buttons: [
            { step: 'month', stepmode: 'backward', count: 1, label: '1m' },
            { step: 'month', stepmode: 'backward', count: 3, label: '3m' },
            { step: 'month', stepmode: 'backward', count: 6, label: '6m' },
            { step: 'year', stepmode: 'todate', label: 'ytd' },
            { step: 'year', stepmode: 'backward', count: 1, label: '1y' },
            { step: 'all', label: 'all' }
          ],
          bgcolor: colors.paper,
          activecolor: colors.accent,
          font: { color: colors.text }
        },
        showspikes: true,
        spikemode: 'across',
        spikecolor: colors.muted,
        spikethickness: 1,
        gridcolor: colors.grid,
        linecolor: colors.border
      },

      yaxis: {
        domain: [0.28, 1],
        side: 'right',
        gridcolor: colors.grid,
        zerolinecolor: colors.grid,
        linecolor: colors.border,
        tickformat: ',.2f'
      },

      yaxis2: {
        domain: [0, 0.2],
        side: 'right',
        gridcolor: colors.grid,
        zerolinecolor: colors.grid,
        linecolor: colors.border,
        title: { text: 'volume', font: { color: colors.muted, size: 11 } }
      },

      hovermode: 'x unified',
      uirevision: `rev-${(el_ticker?.value || current_ticker || 'aapl')}-${el_type?.value || 'candlestick'}`,

      shapes: [
        {
          type: 'line',
          xref: 'x',
          yref: 'y',
          x0: arrays.x[0],
          x1: last_date,
          y0: last_close,
          y1: last_close,
          line: { color: colors.muted, width: 1, dash: 'dot' }
        }
      ],

      annotations: [
        {
          x: last_date, y: last_close, xref: 'x', yref: 'y',
          text: `close ${fmt_currency(last_close)}`,
          showarrow: true, arrowhead: 1, ax: 20, ay: -20,
          bgcolor: 'rgba(0,0,0,.2)', bordercolor: colors.border, font: { size: 11 }
        }
      ]
    };

    const config = {
      responsive: true,
      displaylogo: false,
      modeBarButtonsToAdd: ['v1hovermode', 'hovercompare', 'togglespikelines', 'toImage'],
      toImageButtonOptions: { format: 'png', filename: `${(el_ticker?.value || current_ticker || 'aapl')}_chart` }
    };

    if (!el_chart.dataset.rendered) {
      Plotly.newPlot(el_chart, [trace_price, trace_ma5, trace_ma20, trace_volume], layout, config)
        .then(() => { el_chart.dataset.rendered = '1'; });
    } else {
      Plotly.react(el_chart, [trace_price, trace_ma5, trace_ma20, trace_volume], layout, config);
    }

    const change = arrays.c[arrays.c.length - 1] - arrays.o[arrays.o.length - 1];
    const pct = (change / arrays.o[arrays.o.length - 1]) * 100;
    const dir = change >= 0 ? '▲' : '▼';
    set_status(`${fmt_date(last_date)} • open ${fmt_currency(arrays.o.at(-1))} • close ${fmt_currency(last_close)} • ${dir} ${fmt_currency(Math.abs(change))} (${pct.toFixed(2)}%)`);
  };

  const apply_timeframe = (rows) => {
    if (!rows?.length) return;
    const last = rows.at(-1)?.t;
    if (!last) return;

    const map = { '3m': 90, '6m': 180, 'ytd': 'ytd', '1y': 365, 'all': 'all' };
    const sel = (el_timeframe?.value || '6m');
    const days = map[sel];

    if (days === 'all') {
      Plotly.relayout(el_chart, { 'xaxis.autorange': true });
    } else if (days === 'ytd') {
      const start = new Date(new Date(last).getFullYear(), 0, 1);
      Plotly.relayout(el_chart, { 'xaxis.range': [start, last] });
    } else {
      const start = new Date(last);
      start.setDate(start.getDate() - days);
      Plotly.relayout(el_chart, { 'xaxis.range': [start, last] });
    }
  };

  const download_csv = (rows, filename = 'ohlc.csv') => {
    const header = 'date,open,high,low,close
';
    const body = rows.map(r => {
      const d = new Date(r.t);
      const iso = d.toISOString();
      return `${iso.substring(0,10)},${r.o},${r.h},${r.l},${r.c}`;
    }).join('\n');

    const blob = new Blob([header + body], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
    URL.revokeObjectURL(link.href);
  };

  // ------------- directory loading (one file per ticker) -------------
  /**
   * List json files under a directory. Tries in order:
   * 1) manifest.json (array or {files:[...]} or {tickers:[...]})
   * 2) autoindex html of the directory (works with `python -m http.server`, nginx/Apache dir listing, etc.)
   */
  const list_json_files = async (dirUrl) => {
    // try manifest.json
    try {
      const r = await fetch(dirUrl + 'manifest.json', { cache: 'no-store' });
      if (r.ok) {
        const m = await r.json();
        if (Array.isArray(m)) return m.map(x => String(x));
        if (Array.isArray(m.files)) return m.files;
        if (Array.isArray(m.tickers)) return m.tickers.map(t => `${t}.json`);
      }
    } catch (_) {}

    // try autoindex
    try {
      const r = await fetch(dirUrl, { cache: 'no-store' });
      if (r.ok) {
        const text = await r.text();
        const doc = new DOMParser().parseFromString(text, 'text/html');
        const hrefs = [...doc.querySelectorAll('a')]
          .map(a => a.getAttribute('href') || '')
          .filter(h => /\.json$/i.test(h));
        return hrefs.map(h => h.split('?')[0].split('#')[0]);
      }
    } catch (_) {}

    return [];
  };

  // small concurrency limiter
  const pMap = async (list, mapper, concurrency = 8) => {
    const ret = [];
    let idx = 0;
    const next = async () => {
      while (idx < list.length) {
        const i = idx++;
        try { ret[i] = await mapper(list[i], i); }
        catch (e) { ret[i] = { error: e }; }
      }
    };
    const workers = Array.from({ length: Math.min(concurrency, Math.max(1, list.length)) }, next);
    await Promise.all(workers);
    return ret;
  };

  const merge_series = (into, fromMap) => {
    for (const [sym, rows] of fromMap) {
      const key = String(sym).toLowerCase();
      const existing = into.get(key) || [];
      const merged = existing.concat(rows);
      merged.sort((a,b) => a.t - b.t);
      const out = [];
      let lastKey = null;
      for (const r of merged) {
        const k = r.t.toISOString().slice(0,10);
        if (k !== lastKey) { out.push(r); lastKey = k; } else { out[out.length-1] = r; }
      }
      into.set(key, out);
    }
    return into;
  };

  const fetch_all_from_directory = async () => {
    set_status('discovering data files…');
    const files = await list_json_files(dir_url);
    if (!files.length) {
      set_status('no json files discovered in ticker/daily. add a manifest.json or enable directory listing.');
      return new Map();
    }

    const jsonFiles = files.filter(f => /\.json$/i.test(f));

    set_status(`loading ${jsonFiles.length} file${jsonFiles.length !== 1 ? 's' : ''}…`);

    const results = await pMap(jsonFiles, async (fname) => {
      const url = dir_url + fname;
      try {
        const res = await fetch(url, { cache: 'no-store' });
        if (!res.ok) throw new Error(`http ${res.status}`);
        const j = await res.json();

        let parsed = parse_daily_json(j);

        if (parsed.size === 0 && Array.isArray(j)) {
          const sym = String(fname.replace(/\.json$/i, '')).toLowerCase();
          const rows = j.map(normalize_row).filter(Boolean);
          if (rows.length) parsed.set(sym, rows);
        }

        return { fname, parsed };
      } catch (e) {
        console.warn('failed', fname, e);
        return { fname, error: e };
      }
    }, 8);

    const map = new Map();
    for (const r of results) {
      if (r && r.parsed instanceof Map) merge_series(map, r.parsed);
    }

    return map;
  };

  const use_ticker = (sym) => {
    const key = String(sym || '').toLowerCase();
    current_ticker = key;
    current_rows = ticker_map.get(key) || [];
    render_candles(current_rows);
    apply_timeframe(current_rows);
  };

  const render_performance = () => {
    const colors = get_theme_colors();

    const x = ['q1 2024', 'q2 2024', 'q3 2024', 'q4 2024'];
    const revenue = [119.6, 94.8, 81.8, 89.5];
    const income = [34.6, 24.2, 19.9, 15.0];

    const t_revenue = { type: 'bar', x, y: revenue, name: 'revenue (b)', marker: { color: colors.accent }, yaxis: 'y' };
    const t_income  = { type: 'scatter', mode: 'lines+markers', x, y: income, name: 'net income (b)', line: { width: 2 }, marker: { size: 5 }, yaxis: 'y2' };

    const layout = {
      paper_bgcolor: colors.paper,
      plot_bgcolor: colors.plot,
      font: { color: colors.text },
      margin: { t: 20, r: 20, b: 30, l: 40 },
      xaxis: { gridcolor: colors.grid, linecolor: colors.border },
      yaxis: { title: 'revenue ($b)', gridcolor: colors.grid, linecolor: colors.border },
      yaxis2: { title: 'net income ($b)', overlaying: 'y', side: 'right' },
      legend: { orientation: 'h' }
    };

    const config = { responsive: true, displaylogo: false };
    Plotly.newPlot(el_performance, [t_revenue, t_income], layout, config);
  };

  // ------------- init + events -------------
  const boot = async () => {
    set_status('loading daily data…');
    ticker_map = await fetch_all_from_directory();
    all_tickers = Array.from(ticker_map.keys()).sort();

    if (all_tickers.length === 0) {
      set_status('no tickers found; ensure the server exposes a directory listing or add ticker/daily/manifest.json.');
      return;
    }

    populate_ticker_select(all_tickers, el_ticker);
    current_ticker = el_ticker.value;
    current_rows = ticker_map.get(current_ticker) || [];
    render_candles(current_rows);
    apply_timeframe(current_rows);
    render_performance();
  };

  if (el_ticker) el_ticker.addEventListener('change', () => {
    use_ticker(el_ticker.value);
  });

  if (el_ticker_filter) el_ticker_filter.addEventListener('input', debounce(() => {
    const q = (el_ticker_filter.value || '').trim().toLowerCase();
    const filtered = !q ? all_tickers : all_tickers.filter(t => t.includes(q));
    populate_ticker_select(filtered, el_ticker, true);
  }, 120));

  if (el_type) el_type.addEventListener('change', () => render_candles(current_rows));
  if (el_ma5) el_ma5.addEventListener('change', () => render_candles(current_rows));
  if (el_ma20) el_ma20.addEventListener('change', () => render_candles(current_rows));
  if (el_volume) el_volume.addEventListener('change', () => render_candles(current_rows));

  if (el_timeframe) el_timeframe.addEventListener('change', () => apply_timeframe(current_rows));

  if (el_refresh) el_refresh.addEventListener('click', async () => {
    set_status('refreshing file list…');
    ticker_map = await fetch_all_from_directory();
    const tickers = Array.from(ticker_map.keys()).sort();
    all_tickers = tickers;
    populate_ticker_select(tickers, el_ticker, true);
    use_ticker(el_ticker.value);
  });

  if (el_download) el_download.addEventListener('click', () => download_csv(current_rows, `${(el_ticker?.value || current_ticker || 'aapl')}_ohlc.csv`));

  if (el_theme) el_theme.addEventListener('click', () => {
    const body = document.body;
    const dark = body.classList.toggle('theme-dark');
    if (!dark) body.classList.add('theme-light'); else body.classList.remove('theme-light');
    render_candles(current_rows);
    render_performance();
  });

  window.addEventListener('resize', debounce(() => {
    if (el_chart && el_chart.parentElement) Plotly.Plots.resize(el_chart);
    if (el_performance && el_performance.parentElement) Plotly.Plots.resize(el_performance);
  }, 150));

  boot();
});
