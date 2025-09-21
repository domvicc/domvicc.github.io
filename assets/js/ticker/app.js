// run when dom is ready
document.addEventListener('DOMContentLoaded', () => {
  if (window.feather && typeof window.feather.replace === 'function') window.feather.replace();

  // AOS with fallback
  if (window.AOS && typeof window.AOS.init === 'function') {
    window.AOS.init();
  } else {
    document.querySelectorAll('[data-aos]').forEach(el => el.removeAttribute('data-aos'));
  }

  const dir_url = 'ticker/daily/'; // directory with per-ticker jsons
  let currentArrays = null; // Store current data for dynamic Y-axis

  // Get ticker from URL parameter or default to 'aapl'
  const getTickerFromURL = () => {
    const params = new URLSearchParams(window.location.search);
    const ticker = params.get('ticker');
    return ticker ? ticker.toLowerCase() : 'aapl';
  };

  // Dynamic data endpoints
  const data_endpoints = {
    ticker: 'ticker/daily/',
    company_overview: 'company_overview/',
    income_statement: 'income_statement/',
    balance_sheet: 'balance_sheet/'
  };

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
  let current_ticker = getTickerFromURL(); // Use URL parameter or default to 'aapl'

  // Comprehensive ticker data for dynamic dashboard updates
  const ticker_data = {
    'aapl': {
      name: 'Apple Inc.',
      symbol: 'AAPL',
      exchange: 'NASDAQ',
      currentPrice: 230.89,
      change: 2.84,
      changePercent: 1.24,
      marketCap: '3.45T',
      marketCapRank: '#1 most valuable',
      peRatio: 35.38,
      industryPE: 25.7,
      dividendYield: 0.43,
      dividendPerShare: 1.01,
      revenue: 408.62,
      netIncome: 123.45,
      grossProfit: 189.34,
      operatingIncome: 134.62,
      sector: 'Technology',
      industry: 'Consumer Electronics',
      employees: '164,000',
      founded: '1976',
      description: 'Apple Inc. is an American multinational technology company that specializes in consumer electronics, computer software, and online services.',
      website: 'https://www.apple.com'
    },
    'abnb': {
      name: 'Airbnb, Inc.',
      symbol: 'ABNB',
      exchange: 'NASDAQ',
      currentPrice: 142.56,
      change: -1.23,
      changePercent: -0.86,
      marketCap: '94.2B',
      marketCapRank: '#174 by market cap',
      peRatio: 18.7,
      industryPE: 22.4,
      dividendYield: 0.0,
      dividendPerShare: 0.0,
      revenue: 9.92,
      netIncome: 4.79,
      grossProfit: 7.83,
      operatingIncome: 1.26,
      sector: 'Consumer Discretionary',
      industry: 'Travel Services',
      employees: '6,407',
      founded: '2008',
      description: 'Airbnb, Inc. operates a platform that enables hosts to offer stays and experiences to guests worldwide.',
      website: 'https://www.airbnb.com'
    },
    'adbe': {
      name: 'Adobe Inc.',
      symbol: 'ADBE',
      exchange: 'NASDAQ',
      currentPrice: 578.32,
      change: 8.45,
      changePercent: 1.48,
      marketCap: '259.7B',
      marketCapRank: '#67 by market cap',
      peRatio: 45.2,
      industryPE: 28.9,
      dividendYield: 0.0,
      dividendPerShare: 0.0,
      revenue: 19.41,
      netIncome: 5.61,
      grossProfit: 17.49,
      operatingIncome: 6.84,
      sector: 'Technology',
      industry: 'Software',
      employees: '26,430',
      founded: '1982',
      description: 'Adobe Inc. operates as a diversified software company worldwide, providing digital media and digital experience solutions.',
      website: 'https://www.adobe.com'
    },
    'meta': {
      name: 'Meta Platforms, Inc.',
      symbol: 'META',
      exchange: 'NASDAQ',
      currentPrice: 589.12,
      change: 12.34,
      changePercent: 2.14,
      marketCap: '1.49T',
      marketCapRank: '#8 by market cap',
      peRatio: 28.4,
      industryPE: 31.2,
      dividendYield: 0.37,
      dividendPerShare: 2.00,
      revenue: 134.90,
      netIncome: 39.07,
      grossProfit: 108.14,
      operatingIncome: 46.75,
      sector: 'Communication Services',
      industry: 'Social Media',
      employees: '67,317',
      founded: '2004',
      description: 'Meta Platforms, Inc. develops products that enable people to connect and share with friends and family through mobile devices, personal computers, virtual reality headsets, and wearables worldwide.',
      website: 'https://www.meta.com'
    },
    'amzn': {
      name: 'Amazon.com, Inc.',
      symbol: 'AMZN',
      exchange: 'NASDAQ',
      currentPrice: 186.43,
      change: -2.17,
      changePercent: -1.15,
      marketCap: '1.95T',
      marketCapRank: '#5 by market cap',
      peRatio: 47.8,
      industryPE: 25.3,
      dividendYield: 0.0,
      dividendPerShare: 0.0,
      revenue: 574.79,
      netIncome: 30.43,
      grossProfit: 270.16,
      operatingIncome: 48.03,
      sector: 'Consumer Discretionary',
      industry: 'E-commerce',
      employees: '1,541,000',
      founded: '1994',
      description: 'Amazon.com, Inc. engages in the retail sale of consumer products and subscriptions in North America and internationally.',
      website: 'https://www.amazon.com'
    }
  };

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
    // Use API data if available, otherwise fall back to hardcoded data
    const data = apiData?.companyOverview || ticker_data[ticker.toLowerCase()];
    if (!data) return;

    // Update company name and symbol in sidebar
    const companyNameEl = document.querySelector('aside h2.font-bold');
    const companySymbolEl = document.querySelector('aside p.text-xs.text-gray-400');
    
    if (companyNameEl) companyNameEl.textContent = (data.Name || data.name || '').toLowerCase();
    if (companySymbolEl) {
      const exchange = data.Exchange || data.exchange || 'NASDAQ';
      const symbol = data.Symbol || data.symbol || ticker.toUpperCase();
      companySymbolEl.textContent = `${exchange.toLowerCase()}: ${symbol.toLowerCase()}`;
    }
  };

  const updateKeyMetricsCards = (ticker, apiData = null) => {
    // Use API data if available, otherwise fall back to hardcoded data
    const data = apiData?.companyOverview || ticker_data[ticker.toLowerCase()];
    if (!data) return;

    // Map API fields to our expected format
    const currentPrice = data.currentPrice || parseFloat(data.Price) || 0;
    const changePercent = data.changePercent || parseFloat(data.ChangePercent) || 0;
    const marketCap = data.marketCap || data.MarketCapitalization || '0';
    const peRatio = data.peRatio || parseFloat(data.PERatio) || 0;
    const dividendYield = data.dividendYield || parseFloat(data.DividendYield) || 0;
    const dividendPerShare = data.dividendPerShare || parseFloat(data.DividendPerShare) || 0;

    // Update current price card
    const priceEl = document.querySelector('.grid .bg-gray-800 h3');
    const changeEl = document.querySelector('.grid .bg-gray-800 span');
    const symbolEl = document.querySelector('.grid .bg-gray-800 p.text-gray-400');
    
    if (priceEl) priceEl.textContent = `$${currentPrice.toFixed(2)}`;
    if (changeEl) {
      const isPositive = changePercent > 0;
      changeEl.className = `px-2 py-1 text-xs rounded-full ${isPositive ? 'bg-green-900 text-green-400' : 'bg-red-900 text-red-400'} flex items-center`;
      changeEl.innerHTML = `<i data-feather="${isPositive ? 'arrow-up' : 'arrow-down'}" class="w-3 h-3 mr-1"></i>${Math.abs(changePercent).toFixed(2)}%`;
    }
    if (symbolEl) {
      const exchange = data.Exchange || data.exchange || 'nasdaq';
      const symbol = data.Symbol || data.symbol || ticker;
      symbolEl.textContent = `${exchange.toLowerCase()}: ${symbol.toLowerCase()}`;
    }

    // Update other metric cards
    const metricCards = document.querySelectorAll('.grid .bg-gray-800');
    if (metricCards.length >= 4) {
      // Market cap card
      const marketCapValue = metricCards[1].querySelector('h3');
      const marketCapDesc = metricCards[1].querySelector('p.text-gray-400');
      if (marketCapValue) marketCapValue.textContent = formatMarketCap(marketCap);
      if (marketCapDesc) marketCapDesc.textContent = data.marketCapRank || '#N/A by market cap';

      // P/E ratio card
      const peValue = metricCards[2].querySelector('h3');
      const peDesc = metricCards[2].querySelector('p.text-gray-400');
      if (peValue) peValue.textContent = peRatio.toFixed(2);
      if (peDesc) peDesc.textContent = `industry: ${data.industryPE || 'N/A'}`;

      // Dividend yield card
      const divValue = metricCards[3].querySelector('h3');
      const divDesc = metricCards[3].querySelector('p.text-gray-400');
      if (divValue) divValue.textContent = `${(dividendYield * 100).toFixed(2)}%`;
      if (divDesc) divDesc.textContent = dividendPerShare > 0 ? `$${dividendPerShare.toFixed(2)} per share` : 'No dividend';
    }
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

  const updateFinancialMetricsSection = (ticker, apiData = null) => {
    // Use API data if available, otherwise fall back to hardcoded data
    const data = apiData?.incomeStatement || ticker_data[ticker.toLowerCase()];
    if (!data) return;

    // Map API fields to our expected format
    const revenue = data.totalRevenue || data.revenue || 0;
    const netIncome = data.netIncome || data.netIncome || 0;
    const grossProfit = data.grossProfit || data.grossProfit || 0;
    const operatingIncome = data.operatingIncome || data.operatingIncome || 0;

    // Update the key financials section
    const financialSection = document.querySelector('.bg-gray-800 .space-y-4');
    if (financialSection) {
      // Convert to billions for display if values are large
      const formatFinancial = (value) => {
        const num = parseFloat(value);
        if (num >= 1e9) return (num / 1e9).toFixed(1);
        if (num >= 1e6) return (num / 1e6).toFixed(1);
        return (num / 1e9).toFixed(1); // Assume most values are in the billions range
      };

      const revenueB = formatFinancial(revenue);
      const netIncomeB = formatFinancial(netIncome);
      const grossProfitB = formatFinancial(grossProfit);
      const operatingIncomeB = formatFinancial(operatingIncome);

      const metrics = [
        { label: 'revenue (ttm)', value: `$${revenueB}b`, width: '100%' },
        { label: 'net income (ttm)', value: `$${netIncomeB}b`, width: revenue > 0 ? `${(netIncome / revenue * 100).toFixed(0)}%` : '0%' },
        { label: 'gross profit (ttm)', value: `$${grossProfitB}b`, width: revenue > 0 ? `${(grossProfit / revenue * 100).toFixed(0)}%` : '0%' },
        { label: 'operating income (ttm)', value: `$${operatingIncomeB}b`, width: revenue > 0 ? `${(operatingIncome / revenue * 100).toFixed(0)}%` : '0%' }
      ];

      financialSection.innerHTML = metrics.map(metric => `
        <div>
          <div class="flex justify-between text-sm mb-1">
            <span class="text-gray-400">${metric.label}</span>
            <span>${metric.value}</span>
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2">
            <div class="bg-blue-500 h-2 rounded-full" style="width: ${metric.width}"></div>
          </div>
        </div>
      `).join('');
    }
  };

  const updateCompanyOverviewSection = (ticker, apiData = null) => {
    // Use API data if available, otherwise fall back to hardcoded data
    const data = apiData?.companyOverview || ticker_data[ticker.toLowerCase()];
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
          <p class="text-xs text-gray-400">sector</p>
          <p class="font-medium">${sector.toLowerCase()}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">industry</p>
          <p class="font-medium">${industry.toLowerCase()}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">employees</p>
          <p class="font-medium">${employees}</p>
        </div>
        <div class="bg-gray-700 p-3 rounded-lg">
          <p class="text-xs text-gray-400">founded</p>
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
    updateHeaderQuote(ticker, apiData);
    
    // Refresh feather icons after DOM updates
    if (window.feather && typeof window.feather.replace === 'function') {
      window.feather.replace();
    }
  };

  // Update the intrapanel quote header (symbol + OHLC + change)
  const updateHeaderQuote = (ticker, apiData = null) => {
    if (!ticker || !current_rows || current_rows.length === 0) return;
    const rows = current_rows; // already timeframe-filtered where applicable
    const latest = rows[rows.length - 1];
    // Find previous close (prior trading day) - scan backwards for first earlier bar with a close
    let prevClose = null;
    for (let i = rows.length - 2; i >= 0; i--) { if (rows[i].close != null) { prevClose = rows[i].close; break; } }
    const open = latest.open ?? latest.Open ?? 0;
    const high = latest.high ?? latest.High ?? 0;
    const low = latest.low ?? latest.Low ?? 0;
    const close = latest.close ?? latest.Close ?? 0;
    const change = (prevClose != null) ? (close - prevClose) : 0;
    const changePct = (prevClose != null && prevClose !== 0) ? (change / prevClose * 100) : 0;
    const company = apiData?.companyOverview?.Name || ticker_data[ticker]?.companyName || ticker_data[ticker]?.name || '';

    const elSymbol = document.getElementById('quote-symbol');
    const elCompany = document.getElementById('quote-company');
    const elOpen = document.getElementById('quote-open');
    const elHigh = document.getElementById('quote-high');
    const elLow = document.getElementById('quote-low');
    const elClose = document.getElementById('quote-close');
    const elChange = document.getElementById('quote-change');

    if (elSymbol) elSymbol.textContent = ticker.toLowerCase();
    if (elCompany && company) elCompany.textContent = company.toLowerCase();
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
    
    // Try to load API data for the new ticker
    try {
      console.log(`use_ticker: Loading API data for ${key}`);
      const apiData = await loadDataFromEndpoint(key);
      updateAllDashboardElements(key, apiData);
    } catch (error) {
      console.warn(`use_ticker: Failed to load API data for ${key}, using fallback:`, error);
      updateAllDashboardElements(key); // Fallback to hardcoded data
    }
  };

  const render_performance=()=>{
    const c=get_theme_colors(); const x=['q1 2024','q2 2024','q3 2024','q4 2024']; const revenue=[119.6,94.8,81.8,89.5]; const income=[34.6,24.2,19.9,15.0];
    Plotly.newPlot(el_performance,[{type:'bar',x,y:revenue,name:'revenue (b)',marker:{color:c.accent},yaxis:'y'},{type:'scatter',mode:'lines+markers',x,y:income,name:'net income (b)',line:{width:2},marker:{size:5},yaxis:'y2'}],
      {paper_bgcolor:c.paper,plot_bgcolor:c.plot,font:{color:c.text},margin:{t:20,r:20,b:30,l:40},xaxis:{gridcolor:c.grid,linecolor:c.border},yaxis:{title:'revenue ($b)',gridcolor:c.grid,linecolor:c.border},yaxis2:{title:'net income ($b)',overlaying:'y',side:'right'},legend:{orientation:'h'}},{responsive:true,displaylogo:false});
  };

  const boot=async()=>{
    set_status('loading daily data…');
    console.log('Boot: Starting ticker data load from:', dir_url);
    
    // Check for ticker in URL parameters
    const urlTicker = getTickerFromURL();
    console.log('Boot: URL ticker parameter:', urlTicker);
    
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
    
    // Set initial ticker from URL or default
    let initialTicker = urlTicker;
    if (urlTicker && !all_tickers.includes(urlTicker.toUpperCase())) {
      console.warn(`Boot: URL ticker "${urlTicker}" not found in available tickers, using default`);
      initialTicker = null;
    }
    
    current_ticker = initialTicker || el_ticker.value;
    if (el_ticker && initialTicker) {
      el_ticker.value = initialTicker;
    }
    
    current_rows=ticker_map.get(current_ticker)||[];
    render_candles(current_rows); 
    apply_timeframe(current_rows); 
    render_performance();
    
    // Load API data for the ticker and update dashboard
    if (urlTicker) {
      console.log(`Boot: Loading API data for URL ticker: ${urlTicker}`);
      try {
        const apiData = await loadDataFromEndpoint(urlTicker);
        updateAllDashboardElements(current_ticker, apiData);
        updateHeaderQuote(current_ticker, apiData);
        
        // Update page title with company name
        if (apiData?.companyOverview?.Name) {
          document.title = `${apiData.companyOverview.Name} (${urlTicker.toUpperCase()}) - Ticker Analysis`;
        }
      } catch (error) {
        console.warn('Boot: Failed to load API data, falling back to hardcoded data:', error);
        updateAllDashboardElements(current_ticker); // Fallback
        updateHeaderQuote(current_ticker); // Fallback header
      }
    } else {
      updateAllDashboardElements(current_ticker); // Initialize dashboard with default ticker
      updateHeaderQuote(current_ticker);
    }
  };

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
