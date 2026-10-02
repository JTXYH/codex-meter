const quotaSamples = {
  regular: { count: '121,200', percent: '0.5%', input: '10 万', output: '2.1 万', cost: '$0.52', cache: '7 万', hit: '70%' },
  large: { count: '28,460,320', percent: '63.8%', input: '2,340 万', output: '506 万', cost: '$83.42', cache: '1,610 万', hit: '69%' }
};

function InfoButton() {
  const [open, setOpen] = React.useState(false);
  return <span className="info-wrap">
    <button type="button" className="info-button" aria-label="查看统计说明" aria-expanded={open} onClick={() => setOpen(!open)}>i</button>
    {open && <span className="info-popover" role="status">额度变化可能包含其他设备的用量。</span>}
  </span>;
}

function CardHeading() {
  return <div className="card-heading">
    <h2><span className="heading-dot" aria-hidden="true"></span>今日明细</h2>
    <span className="time-note">统计截至当前时刻</span>
  </div>;
}

function Details({ sample, variant }) {
  return <div className={`details details-${variant}`}>
    <div className="detail"><span className="detail-label">输入</span><strong>{sample.input}</strong></div>
    <div className="detail"><span className="detail-label">输出</span><strong>{sample.output}</strong></div>
    <div className="detail"><span className="detail-label">API 等效费用</span><strong>{sample.cost}</strong></div>
  </div>;
}

function CacheLine({ sample, variant }) {
  return <div className={`cache-line cache-${variant}`}>
    <span>缓存输入 <strong>{sample.cache}</strong></span>
    <span>命中率 <strong>{sample.hit}</strong></span>
  </div>;
}

function QuietHero({ sample }) {
  return <div className="hero hero-quiet">
    <div className="pair-cell"><div className="eyebrow">今日用量</div><div className="hero-count">{sample.count}</div></div>
    <span className="pair-divider" aria-hidden="true"></span>
    <div className="pair-cell"><div className="eyebrow">额度消耗 <InfoButton /></div><div className="pair-percent">{sample.percent}</div></div>
  </div>;
}

function LayeredHero({ sample }) {
  return <div className="hero hero-layered">
    <div className="eyebrow">今日用量</div>
    <div className="hero-count">{sample.count}</div>
    <div className="layered-quota"><span>额度消耗</span><div><strong>{sample.percent}</strong><InfoButton /></div></div>
  </div>;
}

function PercentHero({ sample }) {
  return <div className="hero hero-percent">
    <div className="eyebrow">额度消耗 <InfoButton /></div>
    <div className="percent-number">{sample.percent}</div>
    <div className="percent-support">今日用量 <strong>{sample.count}</strong></div>
  </div>;
}

function TodayCard({ variant, sample, large }) {
  return <div className={`panel-stage ${large ? 'large-sample' : ''}`} data-screen-label={`今日用量设计 · ${variant}`}>
    <section className={`today-card card-${variant}`} aria-label="今日明细">
      <CardHeading />
      {variant === 'quiet' && <QuietHero sample={sample} />}
      {variant === 'layered' && <LayeredHero sample={sample} />}
      {variant === 'percent' && <PercentHero sample={sample} />}
      <Details sample={sample} variant={variant} />
      <CacheLine sample={sample} variant={variant} />
    </section>
  </div>;
}

function App() {
  const [dark, setDark] = React.useState(false);
  const [large, setLarge] = React.useState(false);
  React.useEffect(() => { document.documentElement.dataset.theme = dark ? 'dark' : 'light'; }, [dark]);
  React.useEffect(() => {
    const fit = Math.min(1, Math.max(.7, (window.innerWidth - 150) / 1320));
    requestAnimationFrame(() => window.postMessage({ type: '__dc_set_zoom', scale: fit }, '*'));
  }, []);
  const sample = large ? quotaSamples.large : quotaSamples.regular;
  return <>
    <header className="review-bar">
      <div className="review-identity"><span className="brand-mark" aria-hidden="true"></span><strong>Codex Meter</strong><i></i><span>今日用量与额度 · 第二轮</span></div>
      <div className="review-controls"><span>示例数据</span><button type="button" aria-pressed={large} onClick={() => setLarge(!large)}>大数值测试</button><button type="button" aria-pressed={dark} onClick={() => setDark(!dark)}>{dark ? '浅色预览' : '深色预览'}</button></div>
    </header>
    <main className="canvas-area">
      <DesignCanvas style={{ height: '100%' }}>
        <DCSection id="quota-v2" title="数字优先，减少装饰" subtitle="三版都把数据放在左侧；点击画板右上角可放大比较。" gap={30}>
          <DCArtboard id="quiet" label="01 · 双数对照" width={420} height={334}><TodayCard variant="quiet" sample={sample} large={large} /></DCArtboard>
          <DCArtboard id="layered" label="02 · 上下分层" width={420} height={334}><TodayCard variant="layered" sample={sample} large={large} /></DCArtboard>
          <DCArtboard id="percent" label="03 · 百分比聚焦" width={420} height={334}><TodayCard variant="percent" sample={sample} large={large} /></DCArtboard>
        </DCSection>
      </DesignCanvas>
    </main>
  </>;
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
