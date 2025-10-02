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

  let ticker_map = new Map();
  let all_tickers = [];
  let current_rows = [];
  let current_ticker = DEFAULT_TICKER; // always start from default now

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
    
    // Use income statement data if available, otherwise fall back to company overview
    let data = apiData?.incomeStatement;
    if (!data && apiData?.companyOverview) {
      data = apiData.companyOverview;
    }
    if (!data) {
      data = companyOverviewCache.get(ticker.toLowerCase());
    }
    
    if (!data) {
      console.warn('updateFinancialMetricsSection: No data found for ticker:', ticker);
      return;
    }

    console.log('updateFinancialMetricsSection: Using data:', data);

    // Map API fields to our expected format - try multiple field name variations
    const revenue = data.totalRevenue || data.revenue || data.RevenueTTM || data.totalRevenueTTM || 0;
    const netIncome = data.netIncome || data.NetIncomeTTM || data.netIncomeTTM || 0;
    const grossProfit = data.grossProfit || data.GrossProfitTTM || data.grossProfitTTM || 0;
    const operatingIncome = data.operatingIncome || data.OperatingIncomeTTM || data.operatingIncomeTTM || 0;

    console.log('Financial values:', { revenue, netIncome, grossProfit, operatingIncome });

    // Update the key financials section - try multiple selectors
    let financialSection = document.querySelector('.bg-gray-800 .space-y-4');
    
    if (!financialSection) {
      // Fallback selector - find section that contains Revenue (TTM)
      const allSections = document.querySelectorAll('.space-y-4');
      for (let section of allSections) {
        if (section.textContent.includes('Revenue (TTM)')) {
          financialSection = section;
          console.log('updateFinancialMetricsSection: Found section with fallback selector');
          break;
        }
      }
    }
    
    if (!financialSection) {
      console.warn('updateFinancialMetricsSection: Could not find financial section');
      return;
    }
    
    console.log('updateFinancialMetricsSection: Found section:', financialSection);

    // Convert to billions for display - handle both raw numbers and already-formatted billions
    const formatFinancial = (value) => {
      if (!value || value === 0 || value === '0' || value === 'None' || value === '') return '0.0';
      
      const num = parseFloat(value);
      if (isNaN(num)) return '0.0';
      
      // If value is already in billions format (< 1000), use as-is
      if (num < 1000 && num > 0) return num.toFixed(1);
      // Otherwise convert from raw dollars to billions
      if (num >= 1e9) return (num / 1e9).toFixed(1);
      if (num >= 1e6) return (num / 1e6 / 1000).toFixed(1); // Convert millions to billions
      if (num >= 1e3) return (num / 1e6).toFixed(1); // Convert thousands to millions and then to billions
      return (num / 1e9).toFixed(1); // Handle smaller numbers
    };

    const revenueB = formatFinancial(revenue);
    const netIncomeB = formatFinancial(netIncome);
    const grossProfitB = formatFinancial(grossProfit);
    const operatingIncomeB = formatFinancial(operatingIncome);
    
    // Calculate relative percentages for progress bars
    const revenueNum = parseFloat(revenue) || 0;
    const grossProfitNum = parseFloat(grossProfit) || 0;
    const netIncomeNum = parseFloat(netIncome) || 0;
    const operatingIncomeNum = parseFloat(operatingIncome) || 0;

    const metrics = [
      { label: 'Revenue (TTM)', value: `$${revenueB}B`, width: '100%', color: 'bg-blue-500' },
      { label: 'Gross Profit', value: `$${grossProfitB}B`, width: revenueNum > 0 ? `${Math.max(0, Math.min(100, (grossProfitNum / revenueNum * 100))).toFixed(0)}%` : '0%', color: 'bg-green-500' },
      { label: 'Net Income', value: `$${netIncomeB}B`, width: revenueNum > 0 ? `${Math.max(0, Math.min(100, (Math.abs(netIncomeNum) / revenueNum * 100))).toFixed(0)}%` : '0%', color: 'bg-purple-500' },
      { label: 'Operating Income', value: `$${operatingIncomeB}B`, width: revenueNum > 0 ? `${Math.max(0, Math.min(100, (Math.abs(operatingIncomeNum) / revenueNum * 100))).toFixed(0)}%` : '0%', color: 'bg-yellow-500' }
    ];

    financialSection.innerHTML = metrics.map(metric => `
      <div>
        <div class="flex justify-between text-sm mb-1">
          <span class="text-gray-400">${metric.label}</span>
          <span>${metric.value}</span>
        </div>
        <div class="w-full bg-gray-700 rounded-full h-2">
          <div class="${metric.color} h-2 rounded-full" style="width: ${metric.width}"></div>
        </div>
      </div>
    `).join('');

    console.log('updateFinancialMetricsSection: Updated financial metrics successfully');

    // Update valuation ratios section
    const valuationGrid = document.getElementById('valuation-ratios-grid');
    if (valuationGrid) {
      // Use company overview data for ratios, fallback to ticker data
  const overviewData = apiData?.companyOverview || companyOverviewCache.get(ticker.toLowerCase());
      if (overviewData) {
        const peRatio = overviewData.peRatio || parseFloat(overviewData.PERatio) || 0;
        const pbRatio = overviewData.pbRatio || parseFloat(overviewData.PriceToBookRatio) || 0;
        const psRatio = overviewData.psRatio || parseFloat(overviewData.PriceToSalesRatioTTM) || 0;
        const evEbitda = overviewData.evEbitda || parseFloat(overviewData.EVToEBITDA) || 0;

        const ratios = [
          { label: 'P/E', value: peRatio > 0 ? peRatio.toFixed(2) : '—' },
          { label: 'P/B', value: pbRatio > 0 ? pbRatio.toFixed(1) : '—' },
          { label: 'P/S', value: psRatio > 0 ? psRatio.toFixed(2) : '—' },
          { label: 'EV/EBITDA', value: evEbitda > 0 ? evEbitda.toFixed(2) : '—' }
        ];

        valuationGrid.innerHTML = ratios.map(ratio => `
          <div class="bg-gray-700 p-3 rounded-lg">
            <p class="text-xs text-gray-400">${ratio.label}</p>
            <p class="font-medium">${ratio.value}</p>
          </div>
        `).join('');
      }
    }
  };

  const updateCompanyOverviewSection = (ticker, apiData = null) => {
    // Use API data if available, otherwise fall back to hardcoded data
  const data = apiData?.companyOverview || companyOverviewCache.get(ticker.toLowerCase());
    if (!data) return;

    // Update company description
    const descEl = document.querySelector('.bg-gray-800 p.text-gray-300');
    if (descEl) {
      const description = data.Description || data.description || 'No description available.';
      descEl.textContent = description;
    }

    // Update company details grid
    const detailsGrid = document.querySelector('.grid.grid-cols-2.md\\:grid-cols-4');
    if (detailsGrid) {
      const sector = data.Sector || data.sector || 'N/A';
      const industry = data.Industry || data.industry || 'N/A';
      const employees = data.FullTimeEmployees || data.employees || 'N/A';
      const founded = data.Founded || data.founded || 'N/A';

      detailsGrid.innerHTML = `
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">Sector</p>
          <p class="font-medium">${sector.replace(/\b\w/g,c=>c.toUpperCase())}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">Industry</p>
          <p class="font-medium">${industry.replace(/\b\w/g,c=>c.toUpperCase())}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">Employees</p>
          <p class="font-medium">${employees}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">Founded</p>
          <p class="font-medium">${founded}</p>
        </div>
      `;
    }
  };

  const updateAllDashboardElements = (ticker, apiData = null) => {
    updateSidebarCompanyInfo(ticker, apiData);
    updateKeyMetricsCards(ticker, apiData);
    updateFinancialMetricsSection(ticker, apiData);
    updateCompanyOverviewSection(ticker, apiData);
    renderExtendedSections(ticker, apiData);
    if (window.feather && typeof window.feather.replace === 'function') window.feather.replace();
  };

  // Update the intrapanel quote header (symbol + OHLC + change)
  const updateHeaderQuote = (ticker, apiData = null) => {
    if (!ticker || !current_rows || current_rows.length === 0) return;
    const rows = current_rows; // already timeframe-filtered where applicable
    const latest = rows[rows.length - 1];
    // Find previous close (prior trading day) - scan backwards for first earlier bar with a close
    let prevClose = null;
    for (let i = rows.length - 2; i >= 0; i--) { if ((rows[i].c ?? rows[i].close) != null) { prevClose = rows[i].c ?? rows[i].close; break; } }
    const open = latest.o ?? latest.open ?? 0;
    const high = latest.h ?? latest.high ?? 0;
    const low = latest.l ?? latest.low ?? 0;
    const close = latest.c ?? latest.close ?? 0;
    const change = (prevClose != null) ? (close - prevClose) : 0;
    const changePct = (prevClose != null && prevClose !== 0) ? (change / prevClose * 100) : 0;
  const lower = String(ticker||'').toLowerCase();
  const company = apiData?.companyOverview?.Name || companyOverviewCache.get(lower)?.Name || companyOverviewCache.get(lower)?.name || ticker.toUpperCase();

    const elSymbol = document.getElementById('quote-symbol');
    const elCompany = document.getElementById('quote-company');
    const elOpen = document.getElementById('quote-open');
    const elHigh = document.getElementById('quote-high');
    const elLow = document.getElementById('quote-low');
    const elClose = document.getElementById('quote-close');
    const elChange = document.getElementById('quote-change');

  if (elSymbol) elSymbol.textContent = ticker.toUpperCase();
  if (elCompany && company) elCompany.textContent = company.replace(/\b\w/g,c=>c.toUpperCase());
    if (elOpen) elOpen.textContent = Number(open).toFixed(2);
    if (elHigh) elHigh.textContent = Number(high).toFixed(2);
    if (elLow) elLow.textContent = Number(low).toFixed(2);
    if (elClose) elClose.textContent = Number(close).toFixed(2);
    if (elChange) {
      const positive = change > 0;
      elChange.className = positive ? 'text-green-400' : (change < 0 ? 'text-red-400' : 'text-gray-300');
      const sign = change > 0 ? '+' : '';
      elChange.textContent = `${sign}${change.toFixed(2)} (${sign}${changePct.toFixed(2)}%)`;
    }
  };

  // --- discover json files ---
  const list_json_files=async(dirUrl)=>{
    console.log('list_json_files: Trying to load from:', dirUrl);
    const tryManifests=async(name)=>{
      console.log('tryManifests: Attempting to load:', dirUrl + name);
      try{const r=await fetch(dirUrl+name); 
        console.log('tryManifests: Fetch response for', name, '- Status:', r.status, r.ok ? 'OK' : 'FAILED');
        if(!r.ok) return null; 
        const m=await r.json();
        console.log('tryManifests: Parsed JSON for', name, ':', m);
        if(Array.isArray(m)){const arr=m.map(x=>String(x)); return arr.map(x=>(/\.json$/i.test(x)?x:`${x}.json`));}
        if(Array.isArray(m.files)) return m.files.map(String);
        if(Array.isArray(m.tickers)) return m.tickers.map(t=>`${t}.json`);
        return null;
      }catch(e){console.error('tryManifests: Error loading', name, ':', e); return null;}
    };
    for(const c of ['manifest.json','tickers.json','index.json','files.json']){ 
      console.log('list_json_files: Trying manifest file:', c);
      const files=await tryManifests(c); 
      if(files&&files.length) {
        console.log('list_json_files: Found files in', c, ':', files);
        return files;
      }
    }
    try{const r=await fetch(dirUrl); if(r.ok){const html=await r.text(); const doc=new DOMParser().parseFromString(html,'text/html');
        const hrefs=[...doc.querySelectorAll('a')].map(a=>a.getAttribute('href')||'').filter(h=>/\.json$/i.test(h)); return hrefs.map(h=>h.split('?')[0].split('#')[0]);}}catch(_){}
    return [];
  };

  const pMap=async(list,mapper,concurrency=8)=>{const ret=[]; let i=0; const next=async()=>{while(i<list.length){const idx=i++; try{ret[idx]=await mapper(list[idx],idx);}catch(e){ret[idx]={error:e};}}}; await Promise.all(Array.from({length:Math.min(concurrency,Math.max(1,list.length))},next)); return ret;};

  const merge_series=(into,fromMap)=>{for(const [sym,rows] of fromMap){const key=String(sym).toLowerCase(); const existing=into.get(key)||[]; const merged=existing.concat(rows); merged.sort((a,b)=>a.t-b.t);
      const out=[]; let last=null; for(const r of merged){const k=r.t.toISOString().slice(0,10); if(k!==last){out.push(r); last=k;} else {out[out.length-1]=r;}} into.set(key,out);} return into;};

  const fetch_all_from_directory=async()=>{
    set_status('discovering data files…');
    console.log('fetch_all_from_directory: Starting discovery from:', dir_url);
    const files=await list_json_files(dir_url);
    if(!files.length){ 
      console.error('No JSON files discovered. Tried manifest files:', ['manifest.json','tickers.json','index.json','files.json']);
      console.error('Check if manifest.json exists at:', dir_url + 'manifest.json');
      set_status('No JSON files found in /ticker/daily. Check manifest.json exists and contains valid file list.'); 
      return new Map(); 
    }
    console.log('fetch_all_from_directory: Found files to load:', files);
    set_status(`loading ${files.length} file${files.length!==1?'s':''}…`);
    const results=await pMap(files,async(fname)=>{
      const url=dir_url+fname;
      console.log('fetch_all_from_directory: Loading file:', url);
      try{const res=await fetch(url); 
        console.log('fetch_all_from_directory: Fetch response for', fname, '- Status:', res.status, res.ok ? 'OK' : 'FAILED');
        if(!res.ok) throw new Error(`http ${res.status} - ${res.statusText}`); 
        const j=await res.json();
        console.log('fetch_all_from_directory: JSON loaded for', fname, '- Records:', Array.isArray(j) ? j.length : 'Not an array');
        let parsed=parse_daily_json(j);
        console.log('fetch_all_from_directory: Parsed data for', fname, '- Tickers found:', parsed.size);
        if(parsed.size===0 && Array.isArray(j)){ const sym=String(fname.replace(/\.json$/i,'')).toLowerCase(); const rows=j.map(normalize_row).filter(Boolean); if(rows.length) parsed.set(sym,rows); }
        return {fname,parsed};
      }catch(e){console.error('Failed to load ticker file:', fname, 'Error:', e); return {fname,error:e};}
    },8);
    const map=new Map(); for(const r of results){ if(r&&r.parsed instanceof Map) merge_series(map,r.parsed); }
    return map;
  };

  const use_ticker=async(sym)=>{
    const key=String(sym||'').toLowerCase(); 
    current_ticker=key; 
    current_rows=ticker_map.get(key)||[]; 
    render_candles(current_rows); 
    apply_timeframe(current_rows);
    updateHeaderQuote(key); // provisional update with existing data while API loads
    await loadCompanyOverviewManifest();
    // Load complete ticker data including income statement for proper financial metrics
    const completeData = await loadAllTickerData(key);
    updateAllDashboardElements(key, completeData);
  };

  const render_performance=()=>{
    const c=get_theme_colors(); const x=['q1 2024','q2 2024','q3 2024','q4 2024']; const revenue=[119.6,94.8,81.8,89.5]; const income=[34.6,24.2,19.9,15.0];
    Plotly.newPlot(el_performance,[{type:'bar',x,y:revenue,name:'revenue (b)',marker:{color:c.accent},yaxis:'y'},{type:'scatter',mode:'lines+markers',x,y:income,name:'net income (b)',line:{width:2},marker:{size:5},yaxis:'y2'}],
      {paper_bgcolor:c.paper,plot_bgcolor:c.plot,font:{color:c.text},margin:{t:20,r:20,b:30,l:40},xaxis:{gridcolor:c.grid,linecolor:c.border},yaxis:{title:'revenue ($b)',gridcolor:c.grid,linecolor:c.border},yaxis2:{title:'net income ($b)',overlaying:'y',side:'right'},legend:{orientation:'h'}},{responsive:true,displaylogo:false});
  };

  const boot=async()=>{
    set_status('loading daily data…');
    console.log('Boot: Starting ticker data load from:', dir_url);
    
    try {
      ticker_map=await fetch_all_from_directory();
      all_tickers=Array.from(ticker_map.keys()).sort();
      console.log('Boot: Loaded tickers:', all_tickers.length, 'symbols:', all_tickers);
      if(all_tickers.length===0){ 
        console.error('Boot: No tickers loaded - check manifest.json and data files');
        set_status('No tickers found. Check browser console for detailed error information.'); 
        return; 
      }
    } catch(error) {
      console.error('Boot: Error during initialization:', error);
      set_status('Error loading data. Check browser console for details.');
      return;
    }
    
    populate_ticker_select(all_tickers,el_ticker);
    current_ticker = el_ticker.value || DEFAULT_TICKER;
    
    // Clear ticker filter to ensure all tickers are visible initially
    if(el_ticker_filter) el_ticker_filter.value = '';
    
    current_rows=ticker_map.get(current_ticker)||[];
    render_candles(current_rows); 
    apply_timeframe(current_rows); 
    render_performance();
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
  if(el_theme) el_theme.addEventListener('click',()=>{const body=document.body; const dark=body.classList.toggle('theme-dark'); if(!dark) body.classList.add('theme-light'); else body.classList.remove('theme-light'); render_candles(current_rows); render_performance();});
  window.addEventListener('resize',debounce(()=>{if(el_chart&&el_chart.parentElement) Plotly.Plots.resize(el_chart); if(el_performance&&el_performance.parentElement) Plotly.Plots.resize(el_performance);},150));
  boot();
});
