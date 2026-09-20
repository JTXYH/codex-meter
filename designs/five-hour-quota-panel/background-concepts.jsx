const { useEffect, useState } = React;
const { DesignCanvas, DCSection, DCArtboard } = window;

function RefreshGlyph() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M20 7v5h-5"></path>
      <path d="M18.4 16.4A8 8 0 1 1 20 10l-5 2"></path>
    </svg>
  );
}

function GearGlyph() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="3"></circle>
      <path d="M19 15.4l1.2 1.8-3 3-1.8-1.2a8 8 0 0 1-2.2.9l-.4 2.1H8.6l-.4-2.1A8 8 0 0 1 6 19l-1.8 1.2-3-3 1.2-1.8a8 8 0 0 1-.9-2.2L-.6 12.8V8.6l2.1-.4A8 8 0 0 1 2.4 6L1.2 4.2l3-3L6 2.4a8 8 0 0 1 2.2-.9L8.6-.6h4.2l.4 2.1a8 8 0 0 1 2.2.9l1.8-1.2 3 3L19 6a8 8 0 0 1 .9 2.2l2.1.4v4.2l-2.1.4a8 8 0 0 1-.9 2.2Z"></path>
    </svg>
  );
}

function PowerGlyph() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" aria-hidden="true">
      <path d="M12 2v9"></path>
      <path d="M7.1 5.7a8 8 0 1 0 9.8 0"></path>
    </svg>
  );
}

function Header({ variant, onToast }) {
  const [emailVisible, setEmailVisible] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const refresh = () => {
    if (refreshing) return;
    setRefreshing(true);
    window.setTimeout(() => {
      setRefreshing(false);
      onToast("额度已更新 · 刚刚");
    }, 700);
  };

  return (
    <header className="meter-header">
      <div className={`profile-icon profile-icon-${variant}`} aria-label="自定义背景头像"></div>
      <div className="account-copy">
        <div className="account-row"><h1 className="product-title">Codex Meter</h1><span className="plan-chip">PLUS</span></div>
        <button className="email-toggle" onClick={() => setEmailVisible((value) => !value)} aria-label={emailVisible ? "隐藏邮箱" : "显示邮箱"}>
          <span>{emailVisible ? "demo.user@example.com" : "de••••@example.com"}</span><span className="eye-dot"></span>
        </button>
      </div>
      <button className={`refresh-button ${refreshing ? "spinning" : ""}`} onClick={refresh} aria-label="刷新额度"><RefreshGlyph /></button>
    </header>
  );
}

function QuotaHeroA() {
  return (
    <section className="quota-hero hero-a" aria-label="5 小时和每周额度">
      <div className="hero-a-content">
        <div className="quota-kicker">当前周期</div>
        <div className="quota-primary-line"><strong>72%</strong><span>5 小时额度</span></div>
        <div className="quota-primary-meta">2 小时 18 分后恢复 · 17:23</div>
        <div className="hero-progress"><span></span></div>
      </div>
      <div className="weekly-orbit">
        <div className="weekly-orbit-top"><span>每周额度</span><strong>63%</strong></div>
        <small>4 天 2 小时后恢复</small>
        <div className="mini-line"><span></span></div>
      </div>
    </section>
  );
}

function QuotaHeroB() {
  return (
    <section className="quota-hero hero-b" aria-label="5 小时和每周额度">
      <div className="hero-b-badge">当前额度 · 背景自动适配</div>
      <div className="glass-rail">
        <div className="glass-quota">
          <div className="glass-title">CURRENT · 5 小时额度</div>
          <div className="glass-main"><strong>72%</strong><span>剩余</span></div>
          <div className="glass-reset">2 小时 18 分后恢复</div>
          <div className="glass-line"><span></span></div>
        </div>
        <div className="glass-quota secondary">
          <div className="glass-title">每周额度</div>
          <div className="glass-main"><strong>63%</strong><span>剩余</span></div>
          <div className="glass-reset">4 天 2 小时后恢复</div>
          <div className="glass-line"><span></span></div>
        </div>
      </div>
    </section>
  );
}

function ActivityCard() {
  return (
    <section className="data-card activity-card">
      <div className="section-row">
        <h2 className="section-heading"><span className="section-mark">∿</span>Token 活跃度</h2>
        <span className="section-note">峰值基准</span>
      </div>
      <div className="usage-bars">
        <div className="usage-row">
          <span className="usage-name">今日</span><strong className="usage-value">3.3 百万</strong><span className="usage-rate">79%</span>
          <div className="usage-track"><span style={{ width: "79%" }}></span></div>
        </div>
        <div className="usage-row">
          <span className="usage-name">近 7 天</span><strong className="usage-value">7.1 百万</strong><span className="usage-rate">24%</span>
          <div className="usage-track"><span style={{ width: "24%" }}></span></div>
        </div>
      </div>
      <div className="activity-details">
        <div className="activity-detail"><span>↓ 输入</span><strong>3.1 百万</strong></div>
        <div className="activity-detail"><span>↑ 输出</span><strong>18.4 万</strong></div>
        <div className="activity-detail"><span>＄ API 等效费用</span><strong>$2.47</strong></div>
      </div>
      <div className="cache-note">● 缓存输入 2.6 百万 · 命中 84%</div>
    </section>
  );
}

const heatLevels = [
  [0,1,2,2,3,3,1,0,3,4,2,3,1],
  [1,3,3,2,4,3,2,3,3,2,4,3,0],
  [0,2,4,3,3,1,2,4,3,3,2,4,2],
  [1,3,2,4,2,3,3,0,4,2,3,3,1],
  [0,2,3,2,4,3,1,3,2,4,0,2,3],
  [1,3,4,0,3,2,4,3,3,2,3,4,2],
  [0,2,3,2,4,1,3,2,4,3,2,3,1]
];

function HeatmapCard() {
  const weekdays = ["一", "二", "三", "四", "五", "六", "日"];
  return (
    <section className="data-card heat-card">
      <div className="section-row">
        <h2 className="section-heading"><span className="section-mark">▦</span>近 90 天用量</h2>
        <span className="section-note">连续使用 18 天</span>
      </div>
      <div className="heat-grid">
        {heatLevels.map((row, rowIndex) => (
          <React.Fragment key={weekdays[rowIndex]}>
            <span className="heat-day">{weekdays[rowIndex]}</span>
            {row.map((level, cellIndex) => <span className="heat-cell" data-level={level} key={`${rowIndex}-${cellIndex}`}></span>)}
          </React.Fragment>
        ))}
      </div>
      <div className="heat-footer"><span>合计 1.7 亿 Token</span><span>少　■ ■ ■ ■　多</span></div>
    </section>
  );
}

function Footer({ onToast }) {
  return (
    <footer className="meter-footer">
      <button className="footer-button" onClick={() => onToast("设置入口")} aria-label="设置"><GearGlyph /></button>
      <button className="footer-button" onClick={() => onToast("退出 Codex Meter")} aria-label="退出"><PowerGlyph /></button>
    </footer>
  );
}

function MeterPanel({ variant }) {
  const [toast, setToast] = useState("");

  useEffect(() => {
    if (!toast) return undefined;
    const timer = window.setTimeout(() => setToast(""), 1300);
    return () => window.clearTimeout(timer);
  }, [toast]);

  return (
    <article className={`meter-panel panel-${variant}`} data-screen-label={`背景额度方案 ${variant.toUpperCase()}`} aria-label={`Codex Meter 背景额度方案 ${variant.toUpperCase()}`}>
      <Header variant={variant} onToast={setToast} />
      <main className="panel-content">
        {variant === "a" ? <QuotaHeroA /> : <QuotaHeroB />}
        <ActivityCard />
        <HeatmapCard />
      </main>
      <Footer onToast={setToast} />
      <div className={`toast ${toast ? "visible" : ""}`}>{toast}</div>
    </article>
  );
}

function App() {
  const params = new URLSearchParams(window.location.search);
  const exportVariant = params.get("variant");

  if (exportVariant === "a" || exportVariant === "b") {
    return <div className="export-stage"><MeterPanel variant={exportVariant} /></div>;
  }

  return (
    <DesignCanvas minScale={0.55} maxScale={2.4}>
      <DCSection id="background-quota" title="5 小时额度 × 自定义背景" subtitle="A 更沉浸；B 对任意图片更稳。点击画板可放大查看。" gap={54}>
        <DCArtboard id="aurora-focus" label="A · 沉浸式背景" width={420} height={700}><MeterPanel variant="a" /></DCArtboard>
        <DCArtboard id="adaptive-glass" label="B · 自适应玻璃轨道" width={420} height={700}><MeterPanel variant="b" /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
