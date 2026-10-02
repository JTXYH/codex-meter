const quotaBlockSamples = {
  normal: { input: '10万', output: '2.1万', cost: '$0.52', cache: '7万', hit: '70%', count: '121,200', percent: '0.5' },
  large: { input: '1亿5千万', output: '56.9万', cost: '$97.44', cache: '1亿4千万', hit: '97%', count: '150,569,000', percent: '63.8' }
};

function DetailIcon({ kind }) {
  if (kind === 'down') return <svg viewBox="0 0 18 18" aria-hidden="true"><path d="M9 2v13m0 0-5-5m5 5 5-5" /></svg>;
  if (kind === 'up') return <svg viewBox="0 0 18 18" aria-hidden="true"><path d="M9 16V3m0 0L4 8m5-5 5 5" /></svg>;
  if (kind === 'money') return <svg viewBox="0 0 18 18" aria-hidden="true"><path d="M13.2 5.2c-.9-.9-2.4-1.3-4-1.3-2.3 0-3.9 1.1-3.9 2.9 0 1.6 1.6 2.2 3.8 2.6 2.4.4 3.9 1.1 3.9 2.8 0 1.8-1.7 3-4.1 3-1.8 0-3.3-.5-4.3-1.5M9.1 2v14" /></svg>;
  return <span aria-hidden="true">%</span>;
}

function DetailTile({ kind, label, value }) {
  return <div className="detail-tile">
    <div className="detail-top"><span className="detail-icon"><DetailIcon kind={kind} /></span><span>{label}</span></div>
    <strong className="detail-value">{value}</strong>
  </div>;
}

function QuotaBlock({ variant, sample }) {
  const tooltip = '根据今日日志中的额度变化估算，其他设备用量也可能计入。';
  if (variant === 'surface') return <div className="quota-block quota-surface" title={tooltip}>
    <div className="quota-eyebrow"><span className="quota-icon"><DetailIcon kind="percent" /></span>今日额度消耗</div>
    <div className="quota-reading"><strong>{sample.percent}</strong><span>%</span></div>
    <div className="quota-source">今日用量 <strong>{sample.count}</strong></div>
  </div>;

  if (variant === 'outlined') return <div className="quota-block quota-outlined" title={tooltip}>
    <div className="quota-eyebrow"><span className="quota-icon"><DetailIcon kind="percent" /></span>今日额度消耗</div>
    <div className="quota-reading"><strong>{sample.percent}</strong><span>%</span></div>
    <div className="quota-source">今日用量 <strong>{sample.count}</strong></div>
  </div>;

  return <div className="quota-block quota-editorial" title={tooltip}>
    <div className="quota-eyebrow">今日额度消耗</div>
    <div className="quota-reading"><strong>{sample.percent}</strong><span>%</span></div>
    <div className="quota-source">基于今日用量 <strong>{sample.count}</strong></div>
  </div>;
}

function TodayDetails({ variant, sample, large }) {
  return <div className={`panel-stage ${large ? 'large-sample' : ''}`} data-screen-label={`今日明细 · ${variant}`}>
    <section className="today-card" aria-label="今日明细">
      <header className="card-header"><h2><span className="heading-dot" aria-hidden="true"></span>今日明细</h2><span>统计截至当前时刻</span></header>
      <div className="detail-grid">
        <DetailTile kind="down" label="输入" value={sample.input} />
        <DetailTile kind="up" label="输出" value={sample.output} />
        <DetailTile kind="money" label="API 等效费用" value={sample.cost} />
      </div>
      <div className="cache-strip"><span className="cache-left"><i aria-hidden="true"></i>缓存输入 <strong>{sample.cache}</strong></span><span className="cache-hit">命中率 {sample.hit}</span></div>
      <QuotaBlock variant={variant} sample={sample} />
    </section>
  </div>;
}

function App() {
  const [dark, setDark] = React.useState(false);
  const [large, setLarge] = React.useState(false);
  React.useEffect(() => { document.documentElement.dataset.theme = dark ? 'dark' : 'light'; }, [dark]);
  React.useEffect(() => {
    const scale = Math.min(1, Math.max(.7, (window.innerWidth - 100) / 1400));
    requestAnimationFrame(() => window.postMessage({ type: '__dc_set_zoom', scale }, '*'));
  }, []);
  const sample = large ? quotaBlockSamples.large : quotaBlockSamples.normal;
  return <>
    <header className="review-bar">
      <div className="review-title"><span className="brand-mark" aria-hidden="true"></span><strong>今日明细</strong><span className="review-divider"></span><span>只调整新增区块</span></div>
      <div className="review-controls"><button type="button" aria-pressed={large} onClick={() => setLarge(!large)}>{large ? '常规数据' : '大数值'}</button><button type="button" aria-pressed={dark} onClick={() => setDark(!dark)}>{dark ? '浅色' : '深色'}</button></div>
    </header>
    <main className="canvas-area">
      <DesignCanvas style={{ height: '100%' }}>
        <DCSection id="today-quota-block" title="新增区块的三种数字排版" subtitle="外层卡片、原有三项与缓存条保持一致；点击画板可放大查看。" gap={22}>
          <DCArtboard id="surface" label="01 · 柔和底色" width={420} height={362}><TodayDetails variant="surface" sample={sample} large={large} /></DCArtboard>
          <DCArtboard id="outlined" label="02 · 沿用描边" width={420} height={362}><TodayDetails variant="outlined" sample={sample} large={large} /></DCArtboard>
          <DCArtboard id="editorial" label="03 · 极简分隔" width={420} height={362}><TodayDetails variant="editorial" sample={sample} large={large} /></DCArtboard>
        </DCSection>
      </DesignCanvas>
    </main>
  </>;
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
