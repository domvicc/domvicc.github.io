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
  
    // ------- configuration (edit these if you wire up an api) -------
    const api_config = {
      base_url: '',        // e.g., 'https://example.com/price'
      api_key: '',         // e.g., 'pk_...'
      header_name: 'x-api-key',
      map_rows: (json) => [] // return array of { t: date, o, h, l, c }
    };
  
    // ------- sample static data (from your original snippet) -------
    const sample_rows = [
      { t: new Date('2025-08-18'), o: 231.7,   h: 233.12, l: 230.11,  c: 230.89 },
      { t: new Date('2025-08-15'), o: 234,     h: 234.28, l: 229.335, c: 231.59 },
      { t: new Date('2025-08-14'), o: 234.055, h: 235.12, l: 230.85,  c: 232.78 },
      { t: new Date('2025-08-13'), o: 231.07,  h: 235,    l: 230.43,  c: 233.33 },
      { t: new Date('2025-08-12'), o: 228.005, h: 230.8,  l: 227.07,  c: 229.65 },
      { t: new Date('2025-08-11'), o: 227.92,  h: 229.56, l: 224.76,  c: 227.18 },
      { t: new Date('2025-08-08'), o: 220.83,  h: 231,    l: 219.25,  c: 229.35 },
      { t: new Date('2025-08-07'), o: 218.875, h: 220.85, l: 216.58,  c: 220.03 },
      { t: new Date('2025-08-06'), o: 205.63,  h: 215.38, l: 205.59,  c: 213.25 },
      { t: new Date('2025-08-05'), o: 203.4,   h: 205.34, l: 202.16,  c: 202.92 },
      { t: new Date('2025-08-04'), o: 204.505, h: 207.88, l: 201.675, c: 203.35 },
      { t: new Date('2025-08-01'), o: 210.865, h: 213.58, l: 201.5,   c: 202.38 },
      { t: new Date('2025-07-31'), o: 208.49,  h: 209.84, l: 207.16,  c: 207.57 },
      { t: new Date('2025-07-30'), o: 211.895, h: 212.39, l: 207.72,  c: 209.05 },
      { t: new Date('2025-07-29'), o: 214.175, h: 214.81, l: 210.82,  c: 211.27 },
      { t: new Date('2025-07-28'), o: 214.03,  h: 214.845,l: 213.06,  c: 214.05 },
      { t: new Date('2025-07-25'), o: 214.7,   h: 215.24, l: 213.4,   c: 213.88 },
      { t: new Date('2025-07-24'), o: 213.9,   h: 215.69, l: 213.53,  c: 213.76 },
      { t: new Date('2025-07-23'), o: 215,     h: 215.15, l: 212.41,  c: 214.15 },
      { t: new Date('2025-07-22'), o: 213.14,  h: 214.95, l: 212.2301,c: 214.4  },
      { t: new Date('2025-07-21'), o: 212.1,   h: 215.78, l: 211.63,  c: 212.48 },
      { t: new Date('2025-07-18'), o: 210.87,  h: 211.79, l: 209.7045,c: 211.18 },
      { t: new Date('2025-07-17'), o: 210.57,  h: 211.8,  l: 209.59,  c: 210.02 },
      { t: new Date('2025-07-16'), o: 210.295, h: 212.4,  l: 208.64,  c: 210.16 },
      { t: new Date('2025-07-15'), o: 209.22,  h: 211.89, l: 208.92,  c: 209.11 },
      { t: new Date('2025-07-14'), o: 209.925, h: 210.91, l: 207.54,  c: 208.62 },
      { t: new Date('2025-07-11'), o: 210.565, h: 212.13, l: 209.86,  c: 211.16 },
      { t: new Date('2025-07-10'), o: 210.505, h: 213.48, l: 210.03,  c: 212.41 },
      { t: new Date('2025-07-09'), o: 209.53,  h: 211.33, l: 207.22,  c: 211.14 },
      { t: new Date('2025-07-08'), o: 210.1,   h: 211.43, l: 208.45,  c: 210.01 }
    ].sort((a, b) => a.t - b.t);
  
    // ------- ui elements -------
    const el_chart = document.getElementById('candlestick_chart');
    const el_status = document.getElementById('chart-status');
    const el_performance = document.getElementById('performance_chart');
  
    const el_ticker = document.getElementById('ticker-select');
    const el_timeframe = document.getElementById('timeframe-select');
    const el_type = document.getElementById('type-select');
    const el_ma5 = document.getElementById('ma5-toggle');
    const el_ma20 = document.getElementById('ma20-toggle');
    const el_volume = document.getElementById('volume-toggle');
    const el_refresh = document.getElementById('refresh-btn');
    const el_download = document.getElementById('download-btn');
    const el_theme = document.getElementById('theme-btn');
  
    // ------- helpers -------
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
  
    // ------- core renderer -------
    const render_candles = (rows) => {
      const colors = get_theme_colors();
  
      const arrays = to_arrays(rows);
      const vol = simulate_volume(rows);
      const vol_colors = arrays.c.map((v, i) => (v >= arrays.o[i] ? colors.good : colors.bad));
  
      const ma5 = sma(arrays.c, 5);
      const ma20 = sma(arrays.c, 20);
  
      const trace_price = {
        type: el_type && el_type.value === 'ohlc' ? 'ohlc' : 'candlestick',
        x: arrays.x,
        open: arrays.o,
        high: arrays.h,
        low: arrays.l,
        close: arrays.c,
        increasing: { line: { color: colors.good } },
        decreasing: { line: { color: colors.bad } },
        name: (el_ticker?.value || 'aapl').toUpperCase(),
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
        y: ma5,
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
        y: ma20,
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
        uirevision: `rev-${el_ticker?.value || 'aapl'}-${el_type?.value || 'candlestick'}`,
  
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
        toImageButtonOptions: { format: 'png', filename: `${(el_ticker?.value || 'aapl')}_chart` }
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
      const header = 'date,open,high,low,close\n';
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
  
    const fetch_rows_from_api = async (ticker) => {
      if (!api_config.base_url) return null;
      const url = `${api_config.base_url}?symbol=${encodeURIComponent(ticker)}&interval=1d`;
      const headers = api_config.api_key ? { [api_config.header_name]: api_config.api_key } : {};
      try {
        const res = await fetch(url, { headers });
        if (!res.ok) throw new Error(`http ${res.status}`);
        const json = await res.json();
        const mapped = api_config.map_rows(json);
        mapped.sort((a, b) => a.t - b.t);
        return mapped;
      } catch (e) {
        console.error(e);
        return null;
      }
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
  
    // ------- init + events -------
    let current_rows = [...sample_rows];
  
    const boot = async () => {
      const api_rows = await fetch_rows_from_api((el_ticker?.value || 'aapl'));
      current_rows = api_rows && api_rows.length ? api_rows : sample_rows;
      render_candles(current_rows);
      apply_timeframe(current_rows);
      render_performance();
    };
  
    if (el_type) el_type.addEventListener('change', () => render_candles(current_rows));
    if (el_ma5) el_ma5.addEventListener('change', () => render_candles(current_rows));
    if (el_ma20) el_ma20.addEventListener('change', () => render_candles(current_rows));
    if (el_volume) el_volume.addEventListener('change', () => render_candles(current_rows));
  
    if (el_timeframe) el_timeframe.addEventListener('change', () => apply_timeframe(current_rows));
  
    if (el_ticker) el_ticker.addEventListener('change', async () => {
      set_status('loading data…');
      const api_rows = await fetch_rows_from_api(el_ticker.value);
      current_rows = api_rows && api_rows.length ? api_rows : sample_rows;
      render_candles(current_rows);
      apply_timeframe(current_rows);
    });
  
    if (el_refresh) el_refresh.addEventListener('click', async () => {
      set_status('refreshing…');
      const api_rows = await fetch_rows_from_api((el_ticker?.value || 'aapl'));
      if (api_rows && api_rows.length) current_rows = api_rows;
      render_candles(current_rows);
      apply_timeframe(current_rows);
    });
  
    if (el_download) el_download.addEventListener('click', () => download_csv(current_rows, `${(el_ticker?.value || 'aapl')}_ohlc.csv`));
  
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
  