const sampleData = {
  normal: {
    input: '10 万', output: '2.1 万', cost: '$0.52',
    cache: '7 万', hitRate: '70%', tokens: '121,200', percent: '0.5%'
  },
  large: {
    input: '2,340 万', output: '506 万', cost: '$83.42',
    cache: '1,610 万', hitRate: '69%', tokens: '28,460,320', percent: '63.8%'
  }
};

function DetailMetric({ symbol, label, value }) {
  return <div className="detail-metric">
    <div className="metric-label"><span className="metric-symbol" aria-hidden="true">{symbol}</span><span>{label}</span></div>
    <div className="metric-value">{value}</div>
  </div>;
}

function DetailGrid({ data }) {
  return <>
    <div className="detail-grid">
      <DetailMetric symbol="↓" label="输入" value={data.input} />
      <DetailMetric symbol="↑" label="输出" value={data.output} />
      <DetailMetric symbol="$" label="API 等效费用" value={data.cost} />
    </div>
    <div className="cache-strip">
      <span className="cache-left"><span className="cache-dot" aria-hidden="true"></span>缓存输入 <strong>{data.cache}</strong></span>
      <span className="cache-rate">命中率 {data.hitRate}</span>
    </div>
  </>;
}

function Conversion({ variant, data }) {
  if (variant === 'inline') {
    return <div className="conversion conversion-inline">
      <div className="compact-line">
        <span>今日</span><strong>{data.tokens}</strong><span>Token</span>
        <span className="compact-dot" aria-hidden="true">·</span>
        <span>约占额度</span><strong className="percent">{data.percent}</strong>
      </div>
      <div className="estimate-note">其他设备用量可能计入</div>
    </div>;
  }
  if (variant === 'footer') {
    return <div className="conversion conversion-footer">
      <div className="conversion-eyebrow">今日 Token 对应额度</div>
      <div className="conversion-line">
        <strong>{data.tokens}</strong><span className="token-unit">Token</span>
        <span className="conversion-arrow" aria-hidden="true">→</span>
        <strong className="percent">≈{data.percent}</strong>
      </div>
      <div className="estimate-note">估算值 · 其他设备用量可能计入</div>
    </div>;
  }
  return <div className="conversion conversion-lead">
    <div className="conversion-eyebrow">今日 Token 对应额度</div>
    <div className="conversion-line">
      <strong>{data.tokens}</strong><span className="token-unit">Token</span>
      <span className="conversion-arrow" aria-hidden="true">→</span>
      <strong className="percent">≈{data.percent}</strong>
    </div>
    <div className="estimate-note">估算值 · 其他设备用量可能计入</div>
  </div>;
}

function TokenPanel({ variant, data, large }) {
  return <div className={`panel-stage variant-${variant}${large ? ' large-sample' : ''}`} data-screen-label={`今日 Token 对应额度 · ${variant}`}>
    <section className="activity-card" aria-label="今日明细">
      <div className="section-heading"><h2><span className="section-dot" aria-hidden="true"></span>今日明细</h2><span className="current-note">统计截至当前时刻</span></div>
      {variant === 'lead' && <Conversion variant={variant} data={data} />}
      <DetailGrid data={data} />
      {variant !== 'lead' && <Conversion variant={variant} data={data} />}
    </section>
  </div>;
}

function App() {
  const [theme, setTheme] = React.useState('light');
  const [large, setLarge] = React.useState(false);
  React.useEffect(() => { document.documentElement.dataset.theme = theme; }, [theme]);
  React.useEffect(() => {
    const fit = Math.min(1, Math.max(.7, (window.innerWidth - 150) / 1320));
    requestAnimationFrame(() => window.postMessage({ type: '__dc_set_zoom', scale: fit }, '*'));
  }, []);
  const data = large ? sampleData.large : sampleData.normal;
  return <>
    <header className="review-bar">
      <div className="review-identity"><span className="review-mark" aria-hidden="true"></span><strong>Codex Meter</strong><span className="review-divider"></span><span>今日 Token 与额度 · 设计对比</span></div>
      <div className="review-controls">
        <span className="sample-tag">示例数据</span>
        <button type="button" className={large ? 'selected' : ''} onClick={() => setLarge(!large)} aria-pressed={large}>大数值测试</button>
        <button type="button" className={theme === 'dark' ? 'selected' : ''} onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')} aria-pressed={theme === 'dark'}>{theme === 'light' ? '深色预览' : '浅色预览'}</button>
      </div>
    </header>
    <main className="canvas-area">
      <DesignCanvas style={{ height: '100%' }}>
        <DCSection id="today-concepts" title="让两个数字直接建立关系" subtitle="三种信息层级；保留现有今日明细。点击画板右上角可放大查看。" gap={30}>
          <DCArtboard id="inline" label="01 · 紧凑内联" width={420} height={326}><TokenPanel variant="inline" data={data} large={large} /></DCArtboard>
          <DCArtboard id="footer" label="02 · 柔和底带" width={420} height={326}><TokenPanel variant="footer" data={data} large={large} /></DCArtboard>
          <DCArtboard id="lead" label="03 · 数字优先" width={420} height={326}><TokenPanel variant="lead" data={data} large={large} /></DCArtboard>
        </DCSection>
      </DesignCanvas>
    </main>
  </>;
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
