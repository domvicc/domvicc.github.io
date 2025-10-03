// run when dom is ready
document.addEventListener('DOMContentLoaded', () => {
  if (window.feather && typeof window.feather.replace === 'function') window.feather.replace();

  // AOS with fallback (remove attribute if library missing)
  if (window.AOS && typeof window.AOS.init === 'function') {
    window.AOS.init();
  } else {
    document.querySelectorAll('[data-aos]').forEach(el => el.removeAttribute('data-aos'));
  }

  // NOTE: Removed premature updateKeyMetricsCards call to avoid initial flash.

  const dir_url = 'ticker/daily/'; // directory with per-ticker jsons
  let currentArrays = null; // Store current data for dynamic Y-axis

  // Default starting ticker
  const DEFAULT_TICKER = 'aapl';

  // Dynamic data endpoints
  const data_endpoints = {
    ticker: 'ticker/daily/',
    company_overview: 'ticker/company_overview/',
    income_statement: 'ticker/income_statement/',
    balance_sheet: 'ticker/balance_sheet/'
  };

  // Cache for company overview manifest + individual files
  let companyOverviewCache = new Map();
  let companyOverviewLoaded = false;
  let manifestTickers = [];

  async function loadCompanyOverviewManifest(){
    if(companyOverviewLoaded) return;
    try{
      const res = await fetch('ticker/company_overview/manifest.json');
      if(!res.ok) throw new Error('manifest fetch '+res.status);
      const manifest = await res.json();
      // Handle both old 'tickers' format and new 'files' format
      if(manifest.files && Array.isArray(manifest.files)){
        // Extract ticker symbols from filenames (remove .json extension)
        manifestTickers = manifest.files.map(f => f.replace(/\.json$/i, '').toLowerCase());
      } else {
        // Fallback to old format
        manifestTickers = (manifest.tickers||manifest.data?.map(d=>d.Symbol)||[]).map(s=>s.toLowerCase());
      }
      // Pre-seed cache from inline data array if present
      if(Array.isArray(manifest.data)){
        for(const obj of manifest.data){
          if(obj && obj.Symbol) companyOverviewCache.set(obj.Symbol.toLowerCase(), obj);
        }
      }
      companyOverviewLoaded = true;
    }catch(err){
      console.warn('company overview manifest load failed', err);
    }
  }

  // Prefetch all company overviews listed in manifest to enable accurate initial ranking totals.
  async function prefetchAllCompanyOverviews(concurrency=6){
    await loadCompanyOverviewManifest();
    if(!manifestTickers || manifestTickers.length===0) {
      console.warn('prefetchAllCompanyOverviews: No manifest tickers found');
      return;
    }
    console.log(`prefetchAllCompanyOverviews: Starting prefetch of ${manifestTickers.length} tickers`);
    const limiter = async (list, worker, limit) => {
      const ret=[]; let i=0; const running=new Set();
      const launch=()=>{
        if(i>=list.length) return Promise.resolve();
        const item=list[i++];
        const p=worker(item).finally(()=>{running.delete(p);});
        running.add(p);
        let chain = Promise.resolve();
        if(running.size>=limit){ chain = Promise.race(running); }
        return chain.then(launch);
      };
      const starters=Math.min(limit,list.length);
      const launches=[]; for(let j=0;j<starters;j++) launches.push(launch());
      await Promise.all(launches); return ret;
    };
    await limiter(manifestTickers, async (sym)=>{ 
      if(!companyOverviewCache.has(sym)) {
        const result = await getCompanyOverview(sym);
        if(!result) {
          console.warn(`Failed to load company overview for ${sym}`);
        }
      }
    }, concurrency);
    console.log(`prefetchAllCompanyOverviews: Completed. Cache now has ${companyOverviewCache.size} entries`);
  }

  async function getCompanyOverview(sym){
    const key = String(sym||'').toLowerCase();
    if(companyOverviewCache.has(key)) return companyOverviewCache.get(key);
    try{
      const res = await fetch(`ticker/company_overview/${key.toUpperCase()}.json`);
      if(!res.ok) throw new Error(res.status);
      const data = await res.json();
      companyOverviewCache.set(key,data);
      return data;
    }catch(err){
      console.warn('fetch company overview failed', key, err);
      return null;
    }
  }

  const el_chart = document.getElementById('candlestick_chart');
  const el_status = document.getElementById('chart-status');
  
  // New Financial Charts
  const el_revenue_earnings = document.getElementById('revenue_earnings_chart');
  const el_profit_margins = document.getElementById('profit_margins_chart');
  const el_operating_expenses = document.getElementById('operating_expenses_chart');
  const el_asset_composition = document.getElementById('asset_composition_chart');
  const el_debt_equity = document.getElementById('debt_equity_chart');
  const el_liquidity = document.getElementById('liquidity_chart');
  
  // Chart Controls
  const el_income_period = document.getElementById('income-period-select');
  const el_income_timeframe = document.getElementById('income-timeframe-select');
  const el_income_growth = document.getElementById('income-growth-toggle');
  const el_income_refresh = document.getElementById('income-refresh-btn');
  const el_balance_period = document.getElementById('balance-period-select');
  const el_balance_timeframe = document.getElementById('balance-timeframe-select');
  const el_balance_ratios = document.getElementById('balance-ratios-toggle');
  const el_balance_refresh = document.getElementById('balance-refresh-btn');
  
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

  let ticker_map = new Map();
  let all_tickers = [];
  let current_rows = [];
  let current_ticker = DEFAULT_TICKER; // always start from default now
  // Global key financial metrics (set in boot)
  let globalKeyFinancialMetrics = null; // { revenue:{min,max}, grossProfit:{min,max}, netIncome:{min,max}, operatingIncome:{min,max} }
  let globalKeyFinancialData = null; // array of {symbol,revenue,gross,net,op}

  // Comprehensive ticker data for dynamic dashboard updates
  // Removed hardcoded ticker_data. All company context now sourced dynamically via:
  // - Manifest preload (loadCompanyOverviewManifest)
  // - Per-symbol JSON fetch (getCompanyOverview / loadCompanyOverview)
  // Provide an empty object to avoid reference errors; logic below must not rely on seeded values.
  const ticker_data = {};

  const to_arrays = (rows) => {
    const x=[],o=[],h=[],l=[],c=[];
    for (const r of rows){x.push(r.t);o.push(r.o);h.push(r.h);l.push(r.l);c.push(r.c);}
    return {x,o,h,l,c};
  };

  const sma=(values,period)=>{const out=new Array(values.length).fill(null);let sum=0;for(let i=0;i<values.length;i++){sum+=values[i];if(i>=period)sum-=values[i-period];if(i>=period-1)out[i]=sum/period;}return out;};

  const simulate_volume=(rows)=>rows.map(r=>{const range=Math.max(1,r.h-r.l);return Math.round((range*2_000_000)+(Math.random()*6_000_000));});

  const fmt_currency=(n)=>new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n);
  const fmt_date=(d)=>new Intl.DateTimeFormat('en-US',{month:'short',day:'2-digit',year:'numeric'}).format(d);
  const debounce=(fn,ms=150)=>{let t;return(...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms)}};
  const set_status=(m)=>{if(el_status)el_status.textContent=m;};
  const get_theme_colors=()=>{const s=getComputedStyle(document.body);return{paper:s.getPropertyValue('--panel').trim(),plot:s.getPropertyValue('--panel').trim(),text:s.getPropertyValue('--text').trim(),grid:s.getPropertyValue('--grid').trim(),good:s.getPropertyValue('--good').trim(),bad:s.getPropertyValue('--bad').trim(),accent:s.getPropertyValue('--accent').trim(),muted:s.getPropertyValue('--muted').trim(),border:s.getPropertyValue('--border').trim()}};

  const normalize_row=(obj)=>{
    const o=obj.o??obj.open, h=obj.h??obj.high, l=obj.l??obj.low, c=obj.c??obj.close;
    let dt=obj.t??obj.date??obj.timestamp??obj.time;
    if(typeof dt==='string'){dt=new Date(dt);}
    else if(typeof dt==='number'){if(dt<2_000_000_000) dt*=1000; dt=new Date(dt);}
    else if(!(dt instanceof Date)){const y=obj.year??obj.y, m=obj.month??obj.m, d=obj.day??obj.d; if(y&&m&&d) dt=new Date(+y,+m-1,+d);}
    if(!dt||isNaN(+dt)||[o,h,l,c].some(v=>v==null||isNaN(Number(v)))) return null;
    return {t:dt,o:+o,h:+h,l:+l,c:+c};
  };

  const parse_daily_json=(json)=>{
    const map=new Map();
    const push_row=(sym,raw)=>{const row=normalize_row(raw); if(!row) return; const key=String(sym||raw.ticker||raw.symbol||raw.s||'').toLowerCase(); if(!key) return; if(!map.has(key)) map.set(key,[]); map.get(key).push(row);};
    const parse_array=(arr)=>{for(const item of arr){if(Array.isArray(item?.data)&&(item.symbol||item.ticker||item.s)){const sym=(item.symbol||item.ticker||item.s); for(const r of item.data) push_row(sym,r);} else {const sym=(item.ticker||item.symbol||item.s); push_row(sym,item);}}};
    if(Array.isArray(json)) parse_array(json);
    else if(json&&typeof json==='object'){ if(Array.isArray(json.data)) parse_array(json.data); else if(Array.isArray(json.tickers)) parse_array(json.tickers); else { for(const [sym,rows] of Object.entries(json)){ if(Array.isArray(rows)){ for(const r of rows) push_row(sym,r);}}}}
    for(const [sym,rows] of map){ rows.sort((a,b)=>a.t-b.t); const out=[]; let last=null; for(const r of rows){const k=r.t.toISOString().slice(0,10); if(k!==last){out.push(r); last=k;} else {out[out.length-1]=r;}} map.set(sym,out); }
    return map;
  };

  const populate_ticker_select=(tickers,selectEl,keep=false)=>{
    if(!selectEl) return;
    const prev=keep?(selectEl.value||'').toLowerCase():'';
    selectEl.innerHTML='';
    const frag=document.createDocumentFragment();
    for(const t of tickers){const opt=document.createElement('option'); opt.value=t; opt.textContent=t.toUpperCase(); frag.appendChild(opt);}
    selectEl.appendChild(frag);
    if(keep&&prev&&tickers.includes(prev)){selectEl.value=prev;}
    else if(tickers.length){selectEl.value=tickers.includes('aapl')?'aapl':tickers[0];}
  };

  // Helper function to calculate dynamic candlestick width
  const calculateCandlestickWidth = (visibleDataPoints) => {
    // Adjust width based on number of visible points
    if (visibleDataPoints > 500) return 0.3;
    if (visibleDataPoints > 200) return 0.5;
    if (visibleDataPoints > 100) return 0.7;
    if (visibleDataPoints > 50) return 0.8;
    return 0.9;
  };

  // Helper function to get visible data range and adjust Y-axis
  const adjustYAxisToVisibleData = (arrays, xRange) => {
    if (!xRange || !arrays.x.length) return { autorange: true };
    
    const [xMin, xMax] = xRange;
    const visibleIndices = [];
    
    // Find indices of visible data points
    for (let i = 0; i < arrays.x.length; i++) {
      const date = new Date(arrays.x[i]);
      if (date >= new Date(xMin) && date <= new Date(xMax)) {
        visibleIndices.push(i);
      }
    }
    
    if (visibleIndices.length === 0) return { autorange: true };
    
    // Get min/max values for visible data
    let yMin = Infinity, yMax = -Infinity;
    visibleIndices.forEach(i => {
      yMin = Math.min(yMin, arrays.l[i]); // low
      yMax = Math.max(yMax, arrays.h[i]); // high
    });
    
    // Add padding (10% on each side)
    const padding = (yMax - yMin) * 0.1;
    return { range: [yMin - padding, yMax + padding] };
  };

  const render_candles=(rows)=>{
    if(!rows||!rows.length){set_status('no data to render');return;}
    const colors=get_theme_colors();
    const arrays=to_arrays(rows);
    currentArrays = arrays; // Store for dynamic Y-axis updates
    const vol=simulate_volume(rows);
    const vol_colors=arrays.c.map((v,i)=>v>=arrays.o[i]?colors.good:colors.bad);
    const m5=sma(arrays.c,5), m20=sma(arrays.c,20);
    const trace_price={type:(el_type&&el_type.value==='ohlc')?'ohlc':'candlestick',x:arrays.x,open:arrays.o,high:arrays.h,low:arrays.l,close:arrays.c,increasing:{line:{color:colors.good}},decreasing:{line:{color:colors.bad}},name:(el_ticker?.value||current_ticker||'aapl').toUpperCase(),yaxis:'y',
      hovertemplate:'<b>%{x|%b %d, %Y}</b><br>o: %{open:.2f}<br>h: %{high:.2f}<br>l: %{low:.2f}<br>c: %{close:.2f}<extra></extra>'};
    const trace_ma5={type:'scatter',mode:'lines',name:'ma5',x:arrays.x,y:m5,line:{width:1.2,color:colors.accent},yaxis:'y',visible:(el_ma5?.checked??true)?true:'legendonly',hovertemplate:'ma5: %{y:.2f}<extra></extra>'};
    const trace_ma20={type:'scatter',mode:'lines',name:'ma20',x:arrays.x,y:m20,line:{width:1.2,dash:'dot',color:colors.muted},yaxis:'y',visible:(el_ma20?.checked??true)?true:'legendonly',hovertemplate:'ma20: %{y:.2f}<extra></extra>'};
    const trace_volume={type:'bar',name:'volume',x:arrays.x,y:vol,marker:{color:vol_colors},yaxis:'y2',visible:(el_volume?.checked??true)?true:'legendonly',hovertemplate:'vol: %{y:,}<extra></extra>'};
    const last_close=arrays.c.at(-1), last_date=arrays.x.at(-1);
    
    // Calculate optimal Y-axis range for default view (similar to zoom logic)
    const defaultYRange = (() => {
      const defaultDays = 90; // Show last 3 months by default for better detail
      const cutoffDate = new Date(last_date);
      cutoffDate.setDate(cutoffDate.getDate() - defaultDays);
      
      const visibleData = arrays.h.map((high, i) => ({high, low: arrays.l[i], date: new Date(arrays.x[i])}))
        .filter(d => d.date >= cutoffDate);
      
      if (visibleData.length === 0) return { autorange: true };
      
      const yMin = Math.min(...visibleData.map(d => d.low));
      const yMax = Math.max(...visibleData.map(d => d.high));
      const padding = (yMax - yMin) * 0.05; // Reduce padding for tighter view
      
      return { range: [yMin - padding, yMax + padding] };
    })();
    
    // Set default X-axis range to match (last 3 months)
    const defaultXRange = (() => {
      const cutoffDate = new Date(last_date);
      cutoffDate.setDate(cutoffDate.getDate() - 90);
      return { range: [cutoffDate, last_date] };
    })();
    
    const layout={
      paper_bgcolor:colors.paper,
      plot_bgcolor:colors.plot,
      font:{color:colors.text,size:12},
      margin:{t:30,r:20,b:35,l:45},
      showlegend:true,
      legend:{orientation:'h',x:0,y:1.1},
      dragmode:'pan',
      xaxis:{
        domain:[0,1],
        rangeslider:{visible:true,thickness:0.07,bgcolor:colors.paper,bordercolor:colors.border},
        rangeselector:{buttons:[{step:'month',stepmode:'backward',count:1,label:'1m'},{step:'month',stepmode:'backward',count:3,label:'3m'},{step:'month',stepmode:'backward',count:6,label:'6m'},{step:'year',stepmode:'todate',label:'ytd'},{step:'year',stepmode:'backward',count:1,label:'1y'},{step:'all',label:'all'}],bgcolor:colors.paper,activecolor:colors.accent,font:{color:colors.text}},
        showspikes:true,
        spikemode:'across',
        spikecolor:colors.muted,
        spikethickness:1,
        gridcolor:colors.grid,
        linecolor:colors.border,
        ...defaultXRange
      },
      yaxis:{
        domain:[0.28,1],
        side:'right',
        gridcolor:colors.grid,
        zerolinecolor:colors.grid,
        linecolor:colors.border,
        tickformat:',.2f',
        fixedrange:false,
        ...defaultYRange
      },
      yaxis2:{domain:[0,0.2],side:'right',gridcolor:colors.grid,zerolinecolor:colors.grid,linecolor:colors.border,title:{text:'volume',font:{color:colors.muted,size:11}}},
      hovermode:'x unified',uirevision:`rev-${(el_ticker?.value||current_ticker||'aapl')}-${el_type?.value||'candlestick'}`,
      shapes:[{type:'line',xref:'x',yref:'y',x0:arrays.x[0],x1:last_date,y0:last_close,y1:last_close,line:{color:colors.muted,width:1,dash:'dot'}}],
      annotations:[{x:last_date,y:last_close,xref:'x',yref:'y',text:`close ${fmt_currency(last_close)}`,showarrow:true,arrowhead:1,ax:20,ay:-20,bgcolor:'rgba(0,0,0,.2)',bordercolor:colors.border,font:{size:11}}]};
    const config={
      responsive:true,
      displaylogo:false,
      displayModeBar:false,
      scrollZoom:true
    };
    if(!el_chart.dataset.rendered){
      Plotly.newPlot(el_chart,[trace_price,trace_ma5,trace_ma20,trace_volume],layout,config).then(()=>{
        el_chart.dataset.rendered='1';
        
        // Add event listener for zoom/pan events
        el_chart.on('plotly_relayout', (eventData) => {
          if (currentArrays && (eventData['xaxis.range[0]'] && eventData['xaxis.range[1]'])) {
            const xRange = [eventData['xaxis.range[0]'], eventData['xaxis.range[1]']];
            const yAxisUpdate = adjustYAxisToVisibleData(currentArrays, xRange);
            
            // Count visible data points for dynamic width
            const visibleCount = currentArrays.x.filter(x => {
              const date = new Date(x);
              return date >= new Date(xRange[0]) && date <= new Date(xRange[1]);
            }).length;
            
            const candleWidth = calculateCandlestickWidth(visibleCount);
            
            // Update both Y-axis and candlestick width
            const updates = {};
            if (yAxisUpdate.range) {
              updates['yaxis.range'] = yAxisUpdate.range;
            }
            
            Plotly.restyle(el_chart, {
              'width': [candleWidth]
            }, [0]); // Update only the first trace (candlesticks)
            
            if (Object.keys(updates).length > 0) {
              Plotly.relayout(el_chart, updates);
            }
          }
        });
      });
    }
    else {Plotly.react(el_chart,[trace_price,trace_ma5,trace_ma20,trace_volume],layout,config);}
    const change=arrays.c.at(-1)-arrays.o.at(-1); const pct=(change/arrays.o.at(-1))*100; const dir=change>=0?'▲':'▼';
    set_status(`${fmt_date(last_date)} • open ${fmt_currency(arrays.o.at(-1))} • close ${fmt_currency(last_close)} • ${dir} ${fmt_currency(Math.abs(change))} (${pct.toFixed(2)}%)`);
  };

  const apply_timeframe=(rows)=>{
    if(!rows?.length) return;
    const last=rows.at(-1)?.t; if(!last) return;
    const map={'3m':90,'6m':180,'ytd':'ytd','1y':365,'all':'all'}; const sel=(el_timeframe?.value||'6m'); const days=map[sel];
    if(days==='all'){Plotly.relayout(el_chart,{'xaxis.autorange':true});}
    else if(days==='ytd'){const start=new Date(new Date(last).getFullYear(),0,1); Plotly.relayout(el_chart,{'xaxis.range':[start,last]});}
    else {const start=new Date(last); start.setDate(start.getDate()-days); Plotly.relayout(el_chart,{'xaxis.range':[start,last]});}
  };

  const download_csv=(rows,filename='ohlc.csv')=>{
    const header='date,open,high,low,close\n';
    const body=rows.map(r=>{const iso=new Date(r.t).toISOString(); return `${iso.substring(0,10)},${r.o},${r.h},${r.l},${r.c}`;}).join('\n');
    const blob=new Blob([header+body],{type:'text/csv;charset=utf-8;'}); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=filename; a.click(); URL.revokeObjectURL(a.href);
  };

  // --- Dynamic Data Loading Functions ---
  const loadDataFromEndpoint = async (endpoint, ticker) => {
    const url = `${data_endpoints[endpoint]}${ticker.toUpperCase()}.json`;
    try {
      console.log(`Loading ${endpoint} data from:`, url);
      const response = await fetch(url);
      if (!response.ok) {
        console.warn(`Failed to load ${endpoint} data for ${ticker}:`, response.status);
        return null;
      }
      const data = await response.json();
      console.log(`Successfully loaded ${endpoint} data for ${ticker}`);
      return data;
    } catch (error) {
      console.warn(`Error loading ${endpoint} data for ${ticker}:`, error);
      return null;
    }
  };

  const loadTickerData = async (ticker) => {
    return await loadDataFromEndpoint('ticker', ticker);
  };

  const loadCompanyOverview = async (ticker) => {
    return await loadDataFromEndpoint('company_overview', ticker);
  };

  const loadIncomeStatement = async (ticker) => {
    return await loadDataFromEndpoint('income_statement', ticker);
  };

  const loadBalanceSheet = async (ticker) => {
    return await loadDataFromEndpoint('balance_sheet', ticker);
  };

  const loadAllTickerData = async (ticker) => {
    const [tickerData, companyOverview, incomeStatement, balanceSheet] = await Promise.all([
      loadTickerData(ticker),
      loadCompanyOverview(ticker),
      loadIncomeStatement(ticker),
      loadBalanceSheet(ticker)
    ]);

    return {
      ticker: tickerData,
      companyOverview,
      incomeStatement,
      balanceSheet
    };
  };

  // --- Dynamic Dashboard Updates ---
  const updateSidebarCompanyInfo = (ticker, apiData = null) => {
    const key = String(ticker||'').toLowerCase();
    // Prefer API data, then hardcoded, else fallback placeholder
  const base = apiData?.companyOverview || companyOverviewCache.get(key) || {};
    const exchange = base.Exchange || base.exchange || 'NASDAQ';
    const symbol = (base.Symbol || base.symbol || ticker || '').toUpperCase();
    const displayName = (base.Name || base.name || symbol).toLowerCase();

    const companyNameEl = document.querySelector('aside h2.font-bold');
    const companySymbolEl = document.querySelector('aside p.text-xs.text-gray-400');

    if (companyNameEl) companyNameEl.textContent = displayName.replace(/\b\w/g,c=>c.toUpperCase());
    if (companySymbolEl) companySymbolEl.textContent = `${exchange.toUpperCase()}: ${symbol.toUpperCase()}`;
  };

  const updateKeyMetricsCards = (ticker, apiData = null) => {
    if(!ticker) return;
    const key = String(ticker).toLowerCase();
  const data = apiData?.companyOverview || companyOverviewCache.get(key);
    if(!data) return; // silent fail to avoid console noise in production

    // Price: prefer explicit currentPrice then latest candle close
    let currentPrice = Number(data.currentPrice || data.Price) || 0;
    if(currentPrice === 0 && current_rows && current_rows.length){
      const last = current_rows[current_rows.length-1];
      const lastClose = last?.c ?? last?.close;
      if(lastClose>0) currentPrice = Number(lastClose) || currentPrice;
    }

    // Change percent: prefer computed from current_rows, fallback to hardcoded
    let changePercent = computeChangePercentFromRows();
    if(changePercent == null){
      changePercent = Number(data.changePercent || data.ChangePercent) || 0;
    }
  const marketCapRaw = data.marketCap || data.MarketCapitalization || '0';
  const peRatio = Number(data.peRatio || data.PERatio) || 0;
  const dividendYieldRaw = normalizeDividendYield(Number(data.dividendYield), data.DividendYield);
    const dividendPerShare = Number(data.dividendPerShare || data.DividendPerShare) || 0;

    const metricsGrid = document.getElementById('metrics-grid');
    if(!metricsGrid) return;
    const metricCards = metricsGrid.children;
    if(metricCards.length < 4) return;

    // Card references in order
    const priceCard = metricCards[0];
    const marketCapCard = metricCards[1];
    const peCard = metricCards[2];
    const dividendCard = metricCards[3];

    // Current Price card updates (keep original static label styling)
    const priceEl = priceCard.querySelector('h3');
    const changeEl = priceCard.querySelector('span.rounded-full, span.px-2'); // support existing markup
    const symbolEl = priceCard.querySelector('div.mt-4 p.text-gray-400');
    
    if (priceEl) priceEl.textContent = currentPrice>0 ? `$${currentPrice.toFixed(2)}` : '--';
    if (changeEl) {
      const isPositive = changePercent > 0;
      changeEl.textContent = changePercent !== 0 ? `${isPositive?'+':''}${Math.abs(changePercent).toFixed(2)}%` : '--';
      changeEl.classList.remove('bg-green-900','text-green-400','bg-red-900','text-red-400');
      if(changePercent!==0){
        changeEl.classList.add(isPositive? 'bg-green-900':'bg-red-900', isPositive? 'text-green-400':'text-red-400');
      }
    }
    if (symbolEl) {
      const exchange = (data.Exchange || data.exchange || 'NASDAQ').toUpperCase();
      const symbol = (data.Symbol || data.symbol || ticker).toUpperCase();
      symbolEl.textContent = `${exchange}: ${symbol}`;
    }

    // Update other metric cards with better selectors
    // Market Cap card
  const marketCapValue = marketCapCard.querySelector('h3');
  const marketCapDesc = marketCapCard.querySelector('div.mt-4 p.text-gray-400');
  if (marketCapValue) marketCapValue.textContent = formatMarketCap(marketCapRaw);
    if (marketCapDesc){
      const rankObj = computeMarketCapRank(ticker);
      if(rankObj){
        marketCapDesc.textContent = `Rank #${rankObj.rank} of ${rankObj.total}`;
      } else if (data.marketCapRank){
        marketCapDesc.textContent = data.marketCapRank;
      } else {
        marketCapDesc.textContent = '';
      }
    }

    // P/E Ratio card
  const peValue = peCard.querySelector('h3');
  const peDesc = peCard.querySelector('div.mt-4 p.text-gray-400');
  if (peValue) peValue.textContent = peRatio>0 ? peRatio.toFixed(2) : '--';
    if (peDesc){
      const industryAvg = computeIndustryAveragePERatio(ticker);
      if(industryAvg){
        peDesc.textContent = `Industry Avg: ${industryAvg.toFixed(1)}`;
      } else if (data.industryPE) {
        peDesc.textContent = `Industry: ${data.industryPE}`;
      } else {
        peDesc.textContent = '';
      }
    }

    // Dividend Yield card
    const divValue = dividendCard.querySelector('h3');
    const divDesc = dividendCard.querySelector('div.mt-4 p.text-gray-400');
    if (divValue) {
      // Hardcoded data uses 0.43 to mean 0.43% already
      divValue.textContent = dividendYieldRaw>0 ? `${dividendYieldRaw.toFixed(2)}%` : '0.00%';
    }
    if (divDesc) divDesc.textContent = dividendPerShare>0 ? `$${dividendPerShare.toFixed(2)} per share` : 'No dividend';
  };


  // Helper function to format market cap
  const formatMarketCap = (marketCap) => {
    if (typeof marketCap === 'string' && (marketCap.includes('T') || marketCap.includes('B'))) {
      return marketCap;
    }
    const num = parseFloat(marketCap);
    if (num >= 1e12) return `$${(num / 1e12).toFixed(2)}T`;
    if (num >= 1e9) return `$${(num / 1e9).toFixed(2)}B`;
    if (num >= 1e6) return `$${(num / 1e6).toFixed(2)}M`;
    return `$${num.toFixed(2)}`;
  };

  // ---------- Helper Computations Added ----------
  const computeChangePercentFromRows = () => {
    if(!current_rows || current_rows.length < 2) return null;
    const latest = current_rows[current_rows.length-1];
    let prevClose = null;
    for (let i = current_rows.length - 2; i >=0; i--) {
      const c = current_rows[i].c ?? current_rows[i].close;
      if (c != null) { prevClose = c; break; }
    }
    const close = latest.c ?? latest.close;
    if(prevClose==null || prevClose===0 || close==null) return null;
    return ( (close - prevClose) / prevClose ) * 100;
  };

  const parseNumericMarketCap = (val) => {
    if(val==null) return 0;
    if(typeof val === 'number') return val;
    if(/^[0-9]+$/.test(val)) return parseFloat(val);
    const m = String(val).trim();
    if(m.endsWith('T')) return parseFloat(m)*1e12;
    if(m.endsWith('B')) return parseFloat(m)*1e9;
    if(m.endsWith('M')) return parseFloat(m)*1e6;
    return parseFloat(m)||0;
  };

  const computeMarketCapRank = (ticker) => {
    const key = String(ticker||'').toLowerCase();
    if(!companyOverviewCache || companyOverviewCache.size===0) {
      // Fallback: if cache is empty but we have manifest data, use manifest count
      if(manifestTickers && manifestTickers.length > 0) {
        console.warn('Market cap ranking: using manifest fallback, cache not populated');
        return { rank: 1, total: manifestTickers.length };
      }
      return null;
    }
    const list = Array.from(companyOverviewCache.entries())
      .map(([t,obj])=>({t, mc: parseNumericMarketCap(obj.MarketCapitalization || obj.marketCap)}))
      .filter(o=>o.mc>0)
      .sort((a,b)=>b.mc - a.mc);
    const idx = list.findIndex(o=>o.t === key);
    if(idx===-1) {
      // If ticker not found in cache but we have manifest data, provide fallback total
      if(manifestTickers && manifestTickers.length > 0) {
        console.warn(`Market cap ranking: ticker ${key} not found in cache, using manifest total`);
        return { rank: 1, total: manifestTickers.length };
      }
      return null;
    }
    // If the cache seems under-populated compared to manifest, use manifest total as fallback
    const actualTotal = Math.max(list.length, manifestTickers?.length || 0);
    return { rank: idx+1, total: actualTotal };
  };

  const computeIndustryAveragePERatio = (ticker) => {
    const key = String(ticker||'').toLowerCase();
    // Resolve a base object from either hardcoded set or cache
  const base = companyOverviewCache.get(key);
    if(!base) return null;
    const sector = (base.sector || base.Sector || '').toLowerCase();
    const industry = (base.industry || base.Industry || '').toLowerCase();
    if(!sector && !industry) return null;

    // Build unified peer set
    const unified = companyOverviewCache ? Array.from(companyOverviewCache.values()) : [];
    // Filter peers sharing exact industry, fallback to sector if industry sparse
    let peers = unified.filter(v => {
      const ind = (v.industry || v.Industry || '').toLowerCase();
      return industry && ind === industry;
    });
    if(peers.length < 2) { // insufficient peers, broaden to sector
      peers = unified.filter(v => {
        const sec = (v.sector || v.Sector || '').toLowerCase();
        return sector && sec === sector;
      });
    }
    const nums = peers.map(p=>Number(p.peRatio || p.PERatio)).filter(n=>n>0 && isFinite(n));
    if(!nums.length) return null;
    const avg = nums.reduce((a,b)=>a+b,0)/nums.length;
    return avg;
  };

  const normalizeDividendYield = (raw, apiVal) => {
    // raw from hardcoded may already be percent; apiVal (DividendYield) often decimal like 0.004
    if(raw && raw > 1 && raw < 50) return raw; // already a percent value like 2.15
    if(raw && raw > 0 && raw <= 1) return raw; // treat small value as already percent (e.g. 0.43) if usage defined that way
    if(apiVal){
      const n = Number(apiVal);
      if(n>0 && n < 0.25) return n*100; // API decimal to percent
      if(n<=50) return n; // already percent form
    }
    return 0;
  };

  const updateFinancialMetricsSection = (ticker, apiData = null) => {
    console.log('updateFinancialMetricsSection called with ticker:', ticker);
    // Leave value population for other sections but skip bar width logic (handled by keyf.js global initializer)
    let data = null;
    if (apiData?.incomeStatement?.annualReports && Array.isArray(apiData.incomeStatement.annualReports) && apiData.incomeStatement.annualReports.length > 0) {
      data = apiData.incomeStatement.annualReports[0];
    } else if (apiData?.companyOverview) {
      data = apiData.companyOverview;
    } else {
      data = companyOverviewCache.get(ticker.toLowerCase());
    }
    if(!data) return;
    const revenue = data.totalRevenue || data.revenue || data.RevenueTTM || data.totalRevenueTTM || 0;
    const netIncome = data.netIncome || data.NetIncomeTTM || data.netIncomeTTM || 0;
    const grossProfit = data.grossProfit || data.GrossProfitTTM || data.grossProfitTTM || 0;
    const operatingIncome = data.operatingIncome || data.OperatingIncomeTTM || data.operatingIncomeTTM || 0;
    const formatFinancial = (v)=>{const n=Number(String(v).replace(/[^0-9.-]/g,''));return isFinite(n)?(n/1e9).toFixed(1):'0.0';};
    const mapVals = {
      'revenue-value': '$'+formatFinancial(revenue)+'B',
      'gross-profit-value': '$'+formatFinancial(grossProfit)+'B',
      'net-income-value': '$'+formatFinancial(netIncome)+'B',
      'operating-income-value': '$'+formatFinancial(operatingIncome)+'B'
    };
    for(const [id,val] of Object.entries(mapVals)) { const el=document.getElementById(id); if(el) el.textContent=val; }
    // Bars intentionally not updated here.
  };

  /* ================= Header + Orchestrator (Reintroduced) ================= */
  function updateHeaderQuote(ticker, apiData = null){
    const sym = (ticker||'').toUpperCase();
    const last = current_rows && current_rows.length ? current_rows[current_rows.length-1] : null;
    const openEl = document.getElementById('quote-open');
    const highEl = document.getElementById('quote-high');
    const lowEl = document.getElementById('quote-low');
    const closeEl = document.getElementById('quote-close');
    const changeEl = document.getElementById('quote-change');
    const symbolEl = document.getElementById('quote-symbol');
    const companyEl = document.getElementById('quote-company');
    if(last){
      if(openEl) openEl.textContent = (last.o??last.open)?.toFixed(2) || '--';
      if(highEl) highEl.textContent = (last.h??last.high)?.toFixed(2) || '--';
      if(lowEl) lowEl.textContent  = (last.l??last.low)?.toFixed(2) || '--';
      if(closeEl) closeEl.textContent= (last.c??last.close)?.toFixed(2) || '--';
    }
    // change percent via existing helper
    const chg = computeChangePercentFromRows();
    if(changeEl){
      if(chg==null){changeEl.textContent='--'; changeEl.classList.remove('text-green-400','text-red-400');}
      else {
        const pos = chg>0; changeEl.textContent = `${pos?'+':''}${chg.toFixed(2)}%`;
        changeEl.classList.remove('text-green-400','text-red-400');
        changeEl.classList.add(pos? 'text-green-400':'text-red-400');
      }
    }
    const base = apiData?.companyOverview || companyOverviewCache.get(sym.toLowerCase()) || {};
    if(symbolEl) symbolEl.textContent = sym;
    if(companyEl){
      const name = (base.Name || base.name || sym).toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());
      companyEl.textContent = name;
    }
  }

  function updateAllDashboardElements(ticker, apiData=null){
    updateSidebarCompanyInfo(ticker, apiData);
    updateKeyMetricsCards(ticker, apiData);
    updateFinancialMetricsSection(ticker, apiData);
    renderExtendedSections(ticker, apiData);
    // sync key financial bar selection if global scaling loaded
    if(window.KeyFinancial && window.KeyFinancial.global && typeof window.KeyFinancial.global.setSymbol==='function'){
      window.KeyFinancial.global.setSymbol(ticker.toUpperCase());
    }
  }

  // Expose for debugging (optional)
  if(typeof window !== 'undefined'){
    window.updateHeaderQuote = updateHeaderQuote;
    window.updateAllDashboardElements = updateAllDashboardElements;
  }

  // Ensure ticker change works even if earlier function removed
  async function use_ticker(ticker){
    if(!ticker) return; ticker = ticker.toLowerCase();
    current_ticker = ticker;
    current_rows = ticker_map.get(ticker)||[];
    render_candles(current_rows);
    apply_timeframe(current_rows);
    renderFinancialCharts(ticker);
    try {
      const full = await loadAllTickerData(ticker);
      updateHeaderQuote(ticker, full);
      updateAllDashboardElements(ticker, full);
    } catch(err){
      console.error('use_ticker error', err);
    }
  }
  if(typeof window !== 'undefined') window.use_ticker = use_ticker;

  // Financial Chart Data Processing
  const processIncomeStatementData = (incomeData, period = 'annual', timeframe = '5y') => {
    if (!incomeData) return null;
    
    const reports = period === 'annual' ? incomeData.annualReports : incomeData.quarterlyReports;
    if (!reports || reports.length === 0) return null;
    
    // Apply timeframe filter (different strategy for annual vs quarterly)
    let filteredReports = [...reports];
    if (timeframe !== 'all') {
      if (period === 'annual') {
        const count = timeframe === '1y' ? 1 : timeframe === '3y' ? 3 : timeframe === '5y' ? 5 : 10;
        filteredReports = reports
          .slice() // copy
          .sort((a,b)=> new Date(b.fiscalDateEnding) - new Date(a.fiscalDateEnding))
          .slice(0, count);
      } else { // quarterly
        if (timeframe === '1y') {
          // For 1 year quarterly, use date-based filtering
          const now = new Date();
          const oneYearAgo = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
          filteredReports = reports.filter(r => new Date(r.fiscalDateEnding) >= oneYearAgo);
        } else {
          // For other timeframes, use count-based approach
          const quarters = timeframe === '3y' ? 12 : timeframe === '5y' ? 20 : 40;
          filteredReports = reports
            .slice()
            .sort((a,b)=> new Date(b.fiscalDateEnding) - new Date(a.fiscalDateEnding))
            .slice(0, quarters);
        }
      }
    }
    
    // Sort by date (oldest first for trend charts)
    filteredReports.sort((a, b) => new Date(a.fiscalDateEnding) - new Date(b.fiscalDateEnding));
    
    return filteredReports.map(report => ({
      date: report.fiscalDateEnding,
      revenue: parseFloat(report.totalRevenue) / 1e9, // Convert to billions
      netIncome: parseFloat(report.netIncome) / 1e9,
      grossProfit: parseFloat(report.grossProfit) / 1e9,
      operatingIncome: parseFloat(report.operatingIncome) / 1e9,
      operatingExpenses: parseFloat(report.operatingExpenses) / 1e9,
      rnd: parseFloat(report.researchAndDevelopment || 0) / 1e9,
      sga: parseFloat(report.sellingGeneralAndAdministrative || 0) / 1e9,
      grossMargin: ((parseFloat(report.grossProfit) / parseFloat(report.totalRevenue)) * 100) || 0,
      operatingMargin: ((parseFloat(report.operatingIncome) / parseFloat(report.totalRevenue)) * 100) || 0,
      netMargin: ((parseFloat(report.netIncome) / parseFloat(report.totalRevenue)) * 100) || 0
    })).filter(d => !isNaN(d.revenue) && d.revenue > 0);
  };

  const processBalanceSheetData = (balanceData, period = 'annual', timeframe = '5y') => {
    if (!balanceData) return null;
    
    const reports = period === 'annual' ? balanceData.annualReports : balanceData.quarterlyReports;
    if (!reports || reports.length === 0) return null;
    
    // Apply timeframe filter same logic as income
    let filteredReports = [...reports];
    if (timeframe !== 'all') {
      if (period === 'annual') {
        const count = timeframe === '1y' ? 1 : timeframe === '3y' ? 3 : timeframe === '5y' ? 5 : 10;
        filteredReports = reports
          .slice()
          .sort((a,b)=> new Date(b.fiscalDateEnding) - new Date(a.fiscalDateEnding))
          .slice(0, count);
      } else { // quarterly
        if (timeframe === '1y') {
          // For 1 year quarterly, use date-based filtering
          const now = new Date();
          const oneYearAgo = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
          filteredReports = reports.filter(r => new Date(r.fiscalDateEnding) >= oneYearAgo);
        } else {
          // For other timeframes, use count-based approach
          const quarters = timeframe === '3y' ? 12 : timeframe === '5y' ? 20 : 40;
          filteredReports = reports
            .slice()
            .sort((a,b)=> new Date(b.fiscalDateEnding) - new Date(a.fiscalDateEnding))
            .slice(0, quarters);
        }
      }
    }
    
    // Sort by date (oldest first for trend charts)
    filteredReports.sort((a, b) => new Date(a.fiscalDateEnding) - new Date(b.fiscalDateEnding));
    
    return filteredReports.map(report => ({
      date: report.fiscalDateEnding,
      totalAssets: parseFloat(report.totalAssets) / 1e9,
      currentAssets: parseFloat(report.totalCurrentAssets) / 1e9,
      nonCurrentAssets: parseFloat(report.totalNonCurrentAssets) / 1e9,
      totalLiabilities: parseFloat(report.totalLiabilities) / 1e9,
      totalEquity: parseFloat(report.totalShareholderEquity) / 1e9,
      longTermDebt: parseFloat(report.longTermDebt || 0) / 1e9,
      shortTermDebt: parseFloat(report.shortTermDebt || 0) / 1e9,
      cash: parseFloat(report.cashAndCashEquivalentsAtCarryingValue || 0) / 1e9,
      investments: parseFloat(report.longTermInvestments || 0) / 1e9,
      debtToEquity: (parseFloat(report.longTermDebt || 0) + parseFloat(report.shortTermDebt || 0)) / parseFloat(report.totalShareholderEquity) || 0
    })).filter(d => !isNaN(d.totalAssets) && d.totalAssets > 0);
  };

  // Render Revenue & Earnings Chart
  const renderRevenueEarningsChart = (data) => {
    if (!el_revenue_earnings || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    const revenue = data.map(d => d.revenue);
    const netIncome = data.map(d => d.netIncome);
    
    const showGrowth = el_income_growth && el_income_growth.checked;
    let revenueGrowth = [], incomeGrowth = [];
    
    if (showGrowth && data.length > 1) {
      for (let i = 1; i < data.length; i++) {
        const revGrowth = ((data[i].revenue - data[i-1].revenue) / data[i-1].revenue) * 100;
        const incGrowth = ((data[i].netIncome - data[i-1].netIncome) / data[i-1].netIncome) * 100;
        revenueGrowth.push(revGrowth);
        incomeGrowth.push(incGrowth);
      }
    }
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: revenue,
        name: 'Revenue ($B)',
        marker: { color: '#3B82F6' }, // Blue-500 - primary data
        yaxis: 'y'
      },
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: dates,
        y: netIncome,
        name: 'Net Income ($B)',
        line: { width: 3, color: '#10B981' }, // Emerald-500 - success/profit
        marker: { size: 6, color: '#10B981' },
        yaxis: 'y2'
      }
    ];
    
    if (showGrowth && revenueGrowth.length > 0) {
      traces.push({
        type: 'scatter',
        mode: 'lines+markers',
        x: dates.slice(1),
        y: revenueGrowth,
        name: 'Revenue Growth (%)',
        line: { width: 2, dash: 'dot', color: '#8B5CF6' }, // Violet-500 - secondary metric
        marker: { size: 4, color: '#8B5CF6' },
        yaxis: 'y3'
      });
    }
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 50, b: 35, l: 55 },
      height: 288, // Explicit height constraint
      autosize: true,
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 },
        showticklabels: true
      },
      yaxis: { 
        title: { text: 'Revenue ($B)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 },
        side: 'left'
      },
      yaxis2: { 
        
        title: { text: 'Net Income ($B)', font: { size: 10, color: c.muted } }, 
        overlaying: 'y', 
        side: 'right',
        tickfont: { size: 9 },
        gridcolor: 'rgba(0,0,0,0)'
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    if (showGrowth && revenueGrowth.length > 0) {
      layout.yaxis3 = {
        title: { text: 'Growth (%)', font: { size: 10, color: c.muted } },
        overlaying: 'y',
        side: 'right',
        position: 0.95,
        tickfont: { size: 9 },
        gridcolor: 'rgba(0,0,0,0)'
      };
    }
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_revenue_earnings, traces, layout, config);
  };

  // Render Profit Margins Chart
  const renderProfitMarginsChart = (data) => {
    if (!el_profit_margins || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    // Extract raw margin series
    const gross = data.map(d => d.grossMargin);
    const operating = data.map(d => d.operatingMargin);
    const net = data.map(d => d.netMargin);

  // Determine bar width in ms (if date axis) so bars appear balanced
  // Use first interval * 0.35 for slimmer grouped bars
    let barWidthMs = 24 * 3600 * 1000 * 180; // fallback ~180 days
    try {
      if (dates.length > 1) {
        const firstDiff = (new Date(dates[1]).getTime() - new Date(dates[0]).getTime());
  if (firstDiff > 0) barWidthMs = firstDiff * 0.35; // 35% of span for slimmer bars
      }
    } catch(e) { /* silent fallback */ }
    const widthArray = new Array(dates.length).fill(barWidthMs);

    // Helper to compute percent change vs previous period
    const pctChange = (arr) => arr.map((v,i) => {
      if (i === 0) return null; // no prior period
      const prev = arr[i-1];
      if (prev === 0 || prev == null) return null; // avoid div by zero / invalid
      return ((v - prev) / Math.abs(prev)) * 100;
    });
    const grossDelta = pctChange(gross);
    const operatingDelta = pctChange(operating);
    const netDelta = pctChange(net);
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: gross,
        name: 'Gross Margin',
        marker: { 
          color: '#1E88E5', // Material Blue 600
          line: { color: '#1565C0', width: 1 }
        },
        offsetgroup: 'gross',
        width: widthArray
      },
      {
        type: 'bar',
        x: dates,
        y: operating,
        name: 'Operating Margin',
        marker: { 
          color: '#43A047', // Material Green 600
          line: { color: '#2E7D32', width: 1 }
        },
        offsetgroup: 'operating',
        width: widthArray
      },
      {
        type: 'bar',
        x: dates,
        y: net,
        name: 'Net Margin',
        marker: { 
          color: '#8E24AA', // Material Purple 600
          line: { color: '#6A1B9A', width: 1 }
        },
        offsetgroup: 'net',
        width: widthArray
      },
      // Dotted percent change lines (skip first null point)
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: dates,
        y: grossDelta,
  name: 'Gross Δ %',
  line: { color: '#1E88E5', dash: 'dot', width: 2 },
  marker: { size: 5, color: '#1E88E5' },
        yaxis: 'y2'
      },
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: dates,
        y: operatingDelta,
  name: 'Operating Δ %',
  line: { color: '#43A047', dash: 'dot', width: 2 },
  marker: { size: 5, color: '#43A047' },
        yaxis: 'y2'
      },
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: dates,
        y: netDelta,
  name: 'Net Δ %',
  line: { color: '#8E24AA', dash: 'dot', width: 2 },
  marker: { size: 5, color: '#8E24AA' },
        yaxis: 'y2'
      }
    ];
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 25, b: 35, l: 50 },
      height: 288, // Explicit height constraint
      autosize: true,
  barmode: 'group',
  bargap: 0.25, // slightly wider spacing between groups for slimmer bars
  bargroupgap: 0.18, // increased spacing within group to reinforce separation
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 }
      },
      yaxis: { 
        title: { text: 'Margin (%)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 }
      },
      yaxis2: {
        title: { text: 'Δ vs Prior (%)', font: { size: 10, color: c.muted } },
        overlaying: 'y',
        side: 'right',
        showgrid: false,
        tickfont: { size: 9 }
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_profit_margins, traces, layout, config);
  };

  // Render Operating Expenses Chart
  const renderOperatingExpensesChart = (data) => {
    if (!el_operating_expenses || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.rnd),
        name: 'R&D',
        marker: { color: '#F59E0B' } // Amber-500 - innovation/investment
      },
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.sga),
        name: 'SG&A',
        marker: { color: '#EF4444' } // Red-500 - operational costs
      }
    ];
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 25, b: 35, l: 50 },
      height: 256, // Explicit height constraint
      autosize: true,
      barmode: 'stack',
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 }
      },
      yaxis: { 
        title: { text: 'Expenses ($B)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 }
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_operating_expenses, traces, layout, config);
  };

  // Render Asset Composition Chart
  const renderAssetCompositionChart = (data) => {
    if (!el_asset_composition || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.currentAssets),
        name: 'Current Assets',
        marker: { color: '#06B6D4' } // Cyan-500 - liquid/current
      },
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.nonCurrentAssets),
        name: 'Non-Current Assets',
        marker: { color: '#3B82F6' } // Blue-500 - long-term/stable
      }
    ];
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 25, b: 35, l: 50 },
      height: 288, // Explicit height constraint
      autosize: true,
      barmode: 'stack',
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 }
      },
      yaxis: { 
        title: { text: 'Assets ($B)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 }
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_asset_composition, traces, layout, config);
  };

  // Render Debt & Equity Chart
  const renderDebtEquityChart = (data) => {
    if (!el_debt_equity || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    const showRatios = el_balance_ratios && el_balance_ratios.checked;
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.totalLiabilities),
        name: 'Total Liabilities',
        marker: { color: '#DC2626' }, // Red-600 - debt/obligations
        yaxis: 'y'
      },
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.totalEquity),
        name: 'Total Equity',
        marker: { color: '#059669' }, // Emerald-600 - equity/positive
        yaxis: 'y'
      }
    ];
    
    if (showRatios) {
      traces.push({
        type: 'scatter',
        mode: 'lines+markers',
        x: dates,
        y: data.map(d => d.debtToEquity),
        name: 'Debt/Equity Ratio',
        line: { width: 3, color: '#F59E0B' }, // Amber-500 - ratio/warning indicator
        marker: { size: 6, color: '#F59E0B' },
        yaxis: 'y2'
      });
    }
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 50, b: 35, l: 55 },
      height: 288, // Explicit height constraint
      autosize: true,
      barmode: 'group',
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 }
      },
      yaxis: { 
        title: { text: 'Amount ($B)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 }
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    if (showRatios) {
      layout.yaxis2 = {
        title: { text: 'Debt/Equity Ratio', font: { size: 10, color: c.muted } },
        overlaying: 'y',
        side: 'right',
        tickfont: { size: 9 },
        gridcolor: 'rgba(0,0,0,0)'
      };
    }
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_debt_equity, traces, layout, config);
  };

  // Render Liquidity Chart
  const renderLiquidityChart = (data) => {
    if (!el_liquidity || !data || data.length === 0) return;
    
    const c = get_theme_colors();
    const dates = data.map(d => d.date);
    
    const traces = [
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.cash),
        name: 'Cash & Equivalents',
        marker: { color: '#10B981' } // Emerald-500 - immediate liquidity
      },
      {
        type: 'bar',
        x: dates,
        y: data.map(d => d.investments),
        name: 'Long-term Investments',
        marker: { color: '#6366F1' } // Indigo-500 - long-term value
      }
    ];
    
    const layout = {
      paper_bgcolor: c.paper,
      plot_bgcolor: c.plot,
      font: { color: c.text, size: 11, family: 'Inter, system-ui, sans-serif' },
      margin: { t: 15, r: 25, b: 35, l: 50 },
      height: 256, // Explicit height constraint
      autosize: true,
      barmode: 'stack',
      xaxis: { 
        gridcolor: c.grid, 
        linecolor: c.border,
        title: { text: '', font: { size: 10 } },
        tickfont: { size: 9 }
      },
      yaxis: { 
        title: { text: 'Liquidity ($B)', font: { size: 10, color: c.muted } }, 
        gridcolor: c.grid, 
        linecolor: c.border,
        tickfont: { size: 9 }
      },
      legend: { 
        orientation: 'h', 
        y: -0.25, 
        x: 0,
        font: { size: 9 },
        itemwidth: 30,
        tracegroupgap: 3
      },
      hovermode: 'x unified',
      hoverlabel: { bgcolor: c.plot, bordercolor: c.border, font: { size: 10 } }
    };
    
    const config = { responsive: true, displaylogo: false, displayModeBar: false };
    Plotly.newPlot(el_liquidity, traces, layout, config);
  };

  // Main function to render all financial charts
  const renderFinancialCharts = async (ticker) => {
    if (!ticker) return;
    
    try {
      // Load income statement data
      const incomeResponse = await fetch(`ticker/income_statement/${ticker.toUpperCase()}.json`);
      const incomeData = incomeResponse.ok ? await incomeResponse.json() : null;
      
      // Load balance sheet data
      const balanceResponse = await fetch(`ticker/balance_sheet/${ticker.toUpperCase()}.json`);
      const balanceData = balanceResponse.ok ? await balanceResponse.json() : null;
      
      // Process data based on current settings
      const incomePeriod = el_income_period ? el_income_period.value : 'annual';
      const incomeTimeframe = el_income_timeframe ? el_income_timeframe.value : '5y';
      const balancePeriod = el_balance_period ? el_balance_period.value : 'annual';
      const balanceTimeframe = el_balance_timeframe ? el_balance_timeframe.value : '5y';
      
      const processedIncomeData = processIncomeStatementData(incomeData, incomePeriod, incomeTimeframe);
      const processedBalanceData = processBalanceSheetData(balanceData, balancePeriod, balanceTimeframe);
      
      // Render all charts
      if (processedIncomeData) {
        renderRevenueEarningsChart(processedIncomeData);
        renderProfitMarginsChart(processedIncomeData);
        renderOperatingExpensesChart(processedIncomeData);
      }
      
      if (processedBalanceData) {
        renderAssetCompositionChart(processedBalanceData);
        renderDebtEquityChart(processedBalanceData);
        renderLiquidityChart(processedBalanceData);
      }
      
    } catch (error) {
      console.error('Error rendering financial charts:', error);
    }
  };

  const boot=async()=>{    
    // First, load ticker list from manifest to populate the select immediately
    console.log('Boot: Loading ticker list from manifest...');
    const manifestTickers = await loadTickerListFromManifest();
    all_tickers = manifestTickers;
    populate_ticker_select(all_tickers, el_ticker);
    current_ticker = el_ticker.value || DEFAULT_TICKER;
    
    // Clear ticker filter to ensure all tickers are visible initially
    if (el_ticker_filter) el_ticker_filter.value = '';
    
    console.log('Boot: Ticker select populated with', all_tickers.length, 'tickers from manifest');
    
    // Now load the actual ticker data
    set_status('loading daily data…');
    console.log('Boot: Starting ticker data load from:', dir_url);
    
    try {
      ticker_map=await fetch_all_from_directory();
      const availableTickers = Array.from(ticker_map.keys()).sort();
      console.log('Boot: Loaded tickers:', availableTickers.length, 'symbols:', availableTickers);
      
      // Update ticker list with actually available data (in case manifest has more than available data)
      if (availableTickers.length > 0) {
        all_tickers = availableTickers;
        populate_ticker_select(all_tickers, el_ticker, true); // keep current selection if possible
        console.log('Boot: Updated ticker select with', availableTickers.length, 'available tickers');
      } else {
        console.error('Boot: No ticker data loaded - check manifest.json and data files');
        set_status('No ticker data found. Using manifest list only.'); 
        // Don't return here - continue with manifest-based ticker list
      }
    } catch(error) {
      console.error('Boot: Error during data loading:', error);
      set_status('Error loading ticker data. Using manifest list only.');
      // Don't return here - continue with manifest-based ticker list
    }
    
    // Ensure we have a valid current ticker
    current_ticker = el_ticker.value || DEFAULT_TICKER;    current_rows=ticker_map.get(current_ticker)||[];
    render_candles(current_rows); 
    apply_timeframe(current_rows); 
    renderFinancialCharts(current_ticker);
    // Load global key financial metrics for scaling bars
    try {
      if (window.KeyFinancial && typeof window.KeyFinancial.loadData === 'function' && all_tickers.length) {
        console.log('Boot: Loading global key financial metrics...');
        const { allData, metrics } = await window.KeyFinancial.loadData(all_tickers.map(t=>t.toUpperCase()), { reportIndex: 0 });
        globalKeyFinancialMetrics = metrics;
        globalKeyFinancialData = allData;
        console.log('Boot: Global key financial metrics loaded', metrics);
      } else {
        console.warn('Boot: KeyFinancial module unavailable or no tickers');
      }
    } catch(err) {
      console.error('Boot: Error loading global key financial metrics', err);
    }
    // Load manifest & prefetch all overviews so ranking has full denominator on first paint
    console.log('Boot: Starting prefetch of company overviews...');
    await prefetchAllCompanyOverviews();
    console.log(`Boot: Prefetch complete. Cache size: ${companyOverviewCache.size}, Manifest tickers: ${manifestTickers?.length || 0}`);
    
    // Load complete ticker data including income statement for proper financial metrics display
    console.log('Boot: Loading complete ticker data...');
    const completeTickerData = await loadAllTickerData(current_ticker);
    updateHeaderQuote(current_ticker, completeTickerData);
    updateAllDashboardElements(current_ticker, completeTickerData);
  };

  /* ================= Extended Sections Rendering ================= */
  const safeNum = (v)=>{ if(v==null||v==='None'||v==='') return null; const n=Number(v); return isNaN(n)?null:n; };
  const pctFmt = (v, d=1)=> v==null? '—' : (v*100).toFixed(d)+'%';
  const ratioFmt = (v, d=2)=> v==null? '—' : Number(v).toFixed(d);
  const capFmt = (v)=>{ if(v==null) return '—'; const n=Number(v); if(isNaN(n)) return '—'; if(n>=1e12) return (n/1e12).toFixed(2)+'T'; if(n>=1e9) return (n/1e9).toFixed(2)+'B'; if(n>=1e6) return (n/1e6).toFixed(2)+'M'; return n.toFixed(0); };

  function renderValuation(data){
    const el = document.getElementById('valuation-metrics'); if(!el||!data) return;
    const items = [
      {label:'P/E', val: ratioFmt(safeNum(data.PERatio))},
      {label:'Fwd P/E', val: ratioFmt(safeNum(data.ForwardPE))},
      {label:'PEG', val: ratioFmt(safeNum(data.PEGRatio))},
      {label:'P/S', val: ratioFmt(safeNum(data.PriceToSalesRatioTTM))},
      {label:'P/B', val: ratioFmt(safeNum(data.PriceToBookRatio))},
      {label:'EV/EBITDA', val: ratioFmt(safeNum(data.EVToEBITDA))}
    ];
    el.innerHTML = items.map(i=>`<div class="flex justify-between items-center py-2 border-b border-gray-700/50 last:border-b-0"><span class="text-gray-400 text-sm">${i.label}</span><span class="text-white font-medium">${i.val}</span></div>`).join('');
  }

  function renderProfitability(data){
    const el = document.getElementById('profitability-metrics'); if(!el||!data) return;
    const items = [
      {label:'Profit Margin', val: pctFmt(safeNum(data.ProfitMargin))},
      {label:'Op Margin', val: pctFmt(safeNum(data.OperatingMarginTTM))},
      {label:'ROA', val: pctFmt(safeNum(data.ReturnOnAssetsTTM))},
      {label:'ROE', val: pctFmt(safeNum(data.ReturnOnEquityTTM))},
      {label:'EBITDA ($B)', val: (()=>{const e=safeNum(data.EBITDA); return e? (e/1e9).toFixed(2):'—';})()},
      {label:'Gross Profit ($B)', val: (()=>{const g=safeNum(data.GrossProfitTTM); return g? (g/1e9).toFixed(2):'—';})()}
    ];
    el.innerHTML = items.map(i=>`<div class="flex justify-between items-center py-2 border-b border-gray-700/50 last:border-b-0"><span class="text-gray-400 text-sm">${i.label}</span><span class="text-white font-medium">${i.val}</span></div>`).join('');
  }

  function renderGrowth(data){
    const el = document.getElementById('growth-metrics'); if(!el||!data) return;
    const revGrowth = safeNum(data.QuarterlyRevenueGrowthYOY);
    const earnGrowth = safeNum(data.QuarterlyEarningsGrowthYOY);
    const items = [
      {label:'Rev YoY', val: pctFmt(revGrowth)},
      {label:'Earnings YoY', val: pctFmt(earnGrowth)},
      {label:'Revenue/Share', val: ratioFmt(safeNum(data.RevenuePerShareTTM))},
      {label:'EPS (TTM)', val: ratioFmt(safeNum(data.DilutedEPSTTM))},
      {label:'Book Value', val: ratioFmt(safeNum(data.BookValue))},
      {label:'Beta', val: ratioFmt(safeNum(data.Beta))}
    ];
    el.innerHTML = items.map(i=>`<div class="flex justify-between items-center py-2 border-b border-gray-700/50 last:border-b-0"><span class="text-gray-400 text-sm">${i.label}</span><span class="text-white font-medium">${i.val}</span></div>`).join('');
  }

  function renderAnalyst(data, currentPrice){
    const bar = document.getElementById('analyst-bar');
    const legend = document.getElementById('analyst-legend');
    const tgt = document.getElementById('analyst-target');
    const delta = document.getElementById('analyst-target-delta');
    const totalEl = document.getElementById('analyst-total');
    if(!data||!bar) return;
    const buckets = [
      {k:'AnalystRatingStrongBuy', label:'Strong Buy', color:'bg-emerald-500'},
      {k:'AnalystRatingBuy', label:'Buy', color:'bg-green-500'},
      {k:'AnalystRatingHold', label:'Hold', color:'bg-yellow-500'},
      {k:'AnalystRatingSell', label:'Sell', color:'bg-orange-500'},
      {k:'AnalystRatingStrongSell', label:'Strong Sell', color:'bg-red-500'}
    ];
    const counts = buckets.map(b=>({ ...b, v: safeNum(data[b.k])||0 }));
    const total = counts.reduce((a,b)=>a+b.v,0)||1;
    bar.innerHTML = counts.map(c=>`<div class="h-full ${c.color}" style="width:${(c.v/total*100).toFixed(2)}%"></div>`).join('');
    if(legend) legend.innerHTML = counts.map(c=>`<span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded-sm ${c.color}"></span>${c.label} <span class="text-gray-400">${c.v}</span></span>`).join('');
    if(tgt){ const target = safeNum(data.AnalystTargetPrice); tgt.textContent = target? '$'+target.toFixed(2):'—'; if(delta){ if(target && currentPrice){ const diff = ((target-currentPrice)/currentPrice*100).toFixed(1); delta.textContent = (diff>0?'+':'')+diff+'%'; } else delta.textContent='—'; }}
    if(totalEl) totalEl.textContent = total ? total : '—';
  }

  function renderRangeMomentum(data, currentPrice){
    const lowEl = document.getElementById('range-low');
    const highEl = document.getElementById('range-high');
    const prog = document.getElementById('range-progress');
    const marker = document.getElementById('range-marker');
    const label = document.getElementById('range-label');
    const maBoxes = document.getElementById('ma-boxes');
    if(!data) return;
    const low = safeNum(data['52WeekLow']);
    const high = safeNum(data['52WeekHigh']);
    const ma50 = safeNum(data['50DayMovingAverage']);
    const ma200 = safeNum(data['200DayMovingAverage']);
    if(lowEl) lowEl.textContent = low? low.toFixed(2):'Low';
    if(highEl) highEl.textContent = high? high.toFixed(2):'High';
    if(currentPrice && low && high && high>low){
      const pct = (currentPrice-low)/(high-low)*100;
      if(prog) prog.style.width = pct.toFixed(2)+'%';
      if(marker) marker.style.left = pct.toFixed(2)+'%';
      if(label) label.textContent = `Price at ${(pct).toFixed(1)}% of 52W range`;
    }else{
      if(label) label.textContent='—';
    }
    if(maBoxes){
      maBoxes.innerHTML = [
        {label:'50D MA', v: ma50},
        {label:'200D MA', v: ma200},
        {label:'52W High', v: high},
        {label:'52W Low', v: low}
      ].map(m=>`<div class="flex justify-between items-center py-1.5 border-b border-gray-700/30 last:border-b-0"><span class="text-gray-400 text-xs">${m.label}</span><span class="text-white text-xs font-medium">${m.v?m.v.toFixed(2):'—'}</span></div>`).join('');
    }
  }

  function renderPeerTable(){
    const tbody = document.getElementById('peer-tbody'); if(!tbody||companyOverviewCache.size===0) return;
    const rows = Array.from(companyOverviewCache.values());
    const sortSel = document.getElementById('peer-sort');
    let sortBy = sortSel? sortSel.value: 'marketcap';
    const numOrNull = (k,o)=>{const v = safeNum(o[k]); return v==null? -Infinity : v; };
    const enrich = rows.map(r=>({
      sym: r.Symbol||r.symbol,
      sector: (r.Sector||'').toLowerCase().replace(/\b\w/g,c=>c.toUpperCase()),
      mc: safeNum(r.MarketCapitalization),
      pe: safeNum(r.PERatio),
      profit: safeNum(r.ProfitMargin),
      roe: safeNum(r.ReturnOnEquityTTM)
    }));
    const cmpMap = {
      marketcap:(a,b)=> (b.mc||0)-(a.mc||0),
      pe:(a,b)=> (a.pe||Infinity)-(b.pe||Infinity),
      profit:(a,b)=> (b.profit||0)-(a.profit||0),
      roe:(a,b)=> (b.roe||0)-(a.roe||0)
    };
    enrich.sort(cmpMap[sortBy]||cmpMap.marketcap);
    const fmtPct = v=> v==null? '—' : (v*100).toFixed(1);
    const fmtCap = v=> v==null? '—' : capFmt(v);
    tbody.innerHTML = enrich.map(r=>`<tr class="border-b border-gray-700/50 hover:bg-gray-700/30 transition">
      <td class="py-2 pr-4 font-medium">${r.sym}</td>
      <td class="py-2 pr-4">${r.sector||'—'}</td>
      <td class="py-2 pr-4 text-right">${fmtCap(r.mc)}</td>
      <td class="py-2 pr-4 text-right">${r.pe==null?'—':r.pe.toFixed(2)}</td>
      <td class="py-2 pr-4 text-right">${fmtPct(r.profit)}</td>
      <td class="py-2 pr-4 text-right">${fmtPct(r.roe)}</td>
    </tr>`).join('');
  }

  function renderExtendedSections(ticker, api){
    const data = api?.companyOverview || api || null;
    if(!data) return;
    // derive current price from latest candle
    let currentPrice = null;
    if(current_rows && current_rows.length) currentPrice = current_rows.at(-1).c;
    renderValuation(data);
    renderProfitability(data);
    renderGrowth(data);
    renderAnalyst(data, currentPrice);
    renderRangeMomentum(data, currentPrice);
    renderPeerTable();
  }

  // Sort change listener for peer table
  document.addEventListener('change', (e)=>{
    if(e.target && e.target.id === 'peer-sort') renderPeerTable();
  });

  if(el_ticker) el_ticker.addEventListener('change',()=>use_ticker(el_ticker.value));
  if(el_ticker_filter) el_ticker_filter.addEventListener('input',debounce(()=>{const q=(el_ticker_filter.value||'').trim().toLowerCase(); const filtered=!q?all_tickers:all_tickers.filter(t=>t.includes(q)); populate_ticker_select(filtered,el_ticker,true);},120));
  if(el_type) el_type.addEventListener('change',()=>render_candles(current_rows));
  if(el_ma5) el_ma5.addEventListener('change',()=>render_candles(current_rows));
  if(el_ma20) el_ma20.addEventListener('change',()=>render_candles(current_rows));
  if(el_volume) el_volume.addEventListener('change',()=>render_candles(current_rows));
  if(el_timeframe) el_timeframe.addEventListener('change',()=>apply_timeframe(current_rows));
  if(el_refresh) el_refresh.addEventListener('click',async()=>{set_status('refreshing file list…'); ticker_map=await fetch_all_from_directory(); const tickers=Array.from(ticker_map.keys()).sort(); all_tickers=tickers; populate_ticker_select(tickers,el_ticker,true); use_ticker(el_ticker.value);});
  if(el_download) el_download.addEventListener('click',()=>download_csv(current_rows,`${(el_ticker?.value||current_ticker||'aapl')}_ohlc.csv`));
  if(el_theme) el_theme.addEventListener('click',()=>{const body=document.body; const dark=body.classList.toggle('theme-dark'); if(!dark) body.classList.add('theme-light'); else body.classList.remove('theme-light'); render_candles(current_rows); renderFinancialCharts(current_ticker);});
  
  // Add event listeners for new financial chart controls
  if(el_income_period) el_income_period.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_income_timeframe) el_income_timeframe.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_income_growth) el_income_growth.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_income_refresh) el_income_refresh.addEventListener('click', () => renderFinancialCharts(current_ticker));
  if(el_balance_period) el_balance_period.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_balance_timeframe) el_balance_timeframe.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_balance_ratios) el_balance_ratios.addEventListener('change', () => renderFinancialCharts(current_ticker));
  if(el_balance_refresh) el_balance_refresh.addEventListener('click', () => renderFinancialCharts(current_ticker));
  
  window.addEventListener('resize',debounce(()=>{
    if(el_chart&&el_chart.parentElement) Plotly.Plots.resize(el_chart);
    if(el_revenue_earnings&&el_revenue_earnings.parentElement) Plotly.Plots.resize(el_revenue_earnings);
    if(el_profit_margins&&el_profit_margins.parentElement) Plotly.Plots.resize(el_profit_margins);
    if(el_operating_expenses&&el_operating_expenses.parentElement) Plotly.Plots.resize(el_operating_expenses);
    if(el_asset_composition&&el_asset_composition.parentElement) Plotly.Plots.resize(el_asset_composition);
    if(el_debt_equity&&el_debt_equity.parentElement) Plotly.Plots.resize(el_debt_equity);
    if(el_liquidity&&el_liquidity.parentElement) Plotly.Plots.resize(el_liquidity);
  },150));
  boot();
});
