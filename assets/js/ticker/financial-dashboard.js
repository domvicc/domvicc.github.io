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

  // ----- candlestick data -----
  const candlestickData = [
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
  ];

  // sort ascending by date (oldest -> newest)
  candlestickData.sort((a, b) => a.t - b.t);

  // transform to plugin format {x, o, h, l, c}
  const ohlcData = candlestickData.map(d => ({ x: d.t, o: d.o, h: d.h, l: d.l, c: d.c }));

  // ----- candlestick chart -----
  const candleCtx = document.getElementById('candlestickChart').getContext('2d');
  new Chart(candleCtx, {
    type: 'candlestick',
    data: {
      datasets: [{
        label: 'AAPL',
        data: ohlcData,
        color: { 
          up: '#00d4aa', 
          down: '#ff6b6b', 
          unchanged: '#64748b' 
        },
        borderColor: {
          up: '#00d4aa',
          down: '#ff6b6b',
          unchanged: '#64748b'
        },
        borderWidth: 1,
        borderSkipped: false
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      normalized: true,
      interaction: {
        intersect: false,
        mode: 'index'
      },
      scales: {
        x: {
          type: 'time',
          time: { 
            unit: 'day', 
            tooltipFormat: 'MMM dd, yyyy',
            displayFormats: {
              day: 'MMM dd',
              week: 'MMM dd',
              month: 'MMM yyyy'
            }
          },
          grid: { 
            color: 'rgba(148, 163, 184, 0.1)',
            drawBorder: false,
            lineWidth: 1
          },
          ticks: { 
            color: '#94a3b8',
            font: {
              size: 11,
              family: 'Inter, system-ui, sans-serif'
            },
            maxTicksLimit: 8,
            padding: 8
          },
          border: {
            display: false
          }
        },
        y: {
          position: 'right',
          grid: { 
            color: 'rgba(148, 163, 184, 0.1)',
            drawBorder: false,
            lineWidth: 1
          },
          ticks: { 
            color: '#94a3b8',
            font: {
              size: 11,
              family: 'Inter, system-ui, sans-serif'
            },
            padding: 8,
            callback: function(value) {
              return '$' + value.toFixed(2);
            }
          },
          border: {
            display: false
          }
        }
      },
      plugins: {
        legend: { 
          display: false 
        },
        tooltip: {
          backgroundColor: 'rgba(15, 23, 42, 0.95)',
          titleColor: '#f1f5f9',
          bodyColor: '#cbd5e1',
          borderColor: 'rgba(148, 163, 184, 0.2)',
          borderWidth: 1,
          cornerRadius: 8,
          padding: 12,
          titleFont: {
            size: 13,
            weight: '600',
            family: 'Inter, system-ui, sans-serif'
          },
          bodyFont: {
            size: 12,
            family: 'Inter, system-ui, sans-serif'
          },
          displayColors: false,
          callbacks: {
            title: (items) => {
              const d = items[0].raw.x;
              return new Intl.DateTimeFormat('en-US', {
                weekday: 'short',
                year: 'numeric', 
                month: 'short', 
                day: '2-digit'
              }).format(new Date(d));
            },
            label: (context) => {
              const d = context.raw;
              const change = d.c - d.o;
              const changePercent = ((change / d.o) * 100).toFixed(2);
              const changeColor = change >= 0 ? '#00d4aa' : '#ff6b6b';
              const changeSymbol = change >= 0 ? '+' : '';
              
              return [
                `Open: $${d.o.toFixed(2)}`,
                `High: $${d.h.toFixed(2)}`,
                `Low: $${d.l.toFixed(2)}`,
                `Close: $${d.c.toFixed(2)}`,
                `Change: ${changeSymbol}$${change.toFixed(2)} (${changeSymbol}${changePercent}%)`
              ];
            }
          }
        }
      },
      elements: {
        point: {
          radius: 0,
          hoverRadius: 6
        }
      }
    }
  });

  // ----- performance chart (bar + line dual axis) -----
  const perfCtx = document.getElementById('performanceChart').getContext('2d');
  new Chart(perfCtx, {
    type: 'bar',
    data: {
      labels: ['Q1 2024', 'Q2 2024', 'Q3 2024', 'Q4 2024'],
      datasets: [
        {
          label: 'revenue (b)',
          data: [119.6, 94.8, 81.8, 89.5],
          backgroundColor: 'rgba(59, 130, 246, 0.7)',
          borderColor: 'rgba(59, 130, 246, 1)',
          borderWidth: 1,
          yAxisID: 'y'
        },
        {
          label: 'net income (b)',
          data: [34.6, 24.2, 19.9, 15.0],
          backgroundColor: 'rgba(16, 185, 129, 0.7)',
          borderColor: 'rgba(16, 185, 129, 1)',
          borderWidth: 1,
          type: 'line',
          yAxisID: 'y1'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: {
          grid: { color: 'rgba(255, 255, 255, 0.1)' },
          ticks: { color: '#9ca3af' }
        },
        y: {
          type: 'linear',
          position: 'left',
          grid: { color: 'rgba(255, 255, 255, 0.1)' },
          ticks: { color: '#9ca3af' },
          title: { display: true, text: 'revenue ($b)', color: '#9ca3af' }
        },
        y1: {
          type: 'linear',
          position: 'right',
          grid: { drawOnChartArea: false, color: 'rgba(255, 255, 255, 0.1)' },
          ticks: { color: '#9ca3af' },
          title: { display: true, text: 'net income ($b)', color: '#9ca3af' }
        }
      },
      plugins: {
        legend: { position: 'top', labels: { color: '#f3f4f6' } },
        tooltip: {
          callbacks: {
            label: (context) => {
              let label = context.dataset.label ? context.dataset.label + ': ' : '';
              if (context.parsed.y !== null) {
                label += new Intl.NumberFormat('en-US', {
                  style: 'currency',
                  currency: 'USD',
                  minimumFractionDigits: 1,
                  maximumFractionDigits: 1
                }).format(context.parsed.y) + 'b';
              }
              return label;
            }
          }
        }
      }
    }
  });
});
