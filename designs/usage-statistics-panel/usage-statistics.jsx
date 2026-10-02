const {useState,useEffect,useRef} = React;

// Design fixtures only. September 22, 2026 is the fixed reference date.
const usageModes = {
  day:{label:'每日',unit:'天',current:'今天',noun:'日',ranges:[7,14,30],defaultRange:7},
  month:{label:'每月',unit:'个月',current:'本月',noun:'月',ranges:[3,6,12],defaultRange:6},
  year:{label:'每年',unit:'年',current:'今年',noun:'年',ranges:[3,5,'all'],defaultRange:3}
};
const dailyFixtures = [[4800000,12.36],[3290000,8.64],[2150000,5.22],[4120000,10.48],[1860000,4.85],[2670000,6.71],[3540000,8.98],[1680000,4.21],[1140000,2.91],[920000,2.12],[1350000,3.31],[1130000,2.63],[980000,2.23],[600000,1.20],[720000,1.44],[820000,1.61],[420000,.91],[580000,1.12],[740000,1.43],[520000,1.06],[450000,.93],[520000,.96],[840000,2.04],[610000,1.46],[760000,1.82],[820000,1.95],[470000,1.13],[530000,1.27],[680000,1.63],[540000,1.30]];
const monthlyFixtures = [[36000000,87.77],[29000000,71.10],[24000000,60.85],[18000000,46.32],[12000000,30.09],[6400000,16.68],[15600000,40.22],[19000000,48.13],[18000000,47.20],[14600000,36.50],[15800000,39.65],[16200000,40.30]];
const yearlyFixtures = [[178000000,448.36],[246000000,618.24],[93000000,237.86]];
function formatTokens(value) {
  if(value===null)return '—';
  if(value>=100000000)return (value/100000000).toFixed(2).replace(/\.?0+$/,'')+' 亿';
  return (value/10000).toFixed(value%10000===0?0:1)+' 万';
}
function formatCost(value) {return value===null?'—':new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(value);}
function makeUsageRecords(mode,count) {
  const total=count==='all'?3:count;
  return Array.from({length:total},(_,i)=>{
    const date=mode==='day'?new Date(2026,8,22-i):mode==='month'?new Date(2026,8-i,1):new Date(2026-i,0,1);
    const year=date.getFullYear(),month=date.getMonth()+1,day=date.getDate();
    let label,full,short;
    if(mode==='day') {label=i===0?'今天':i===1?'昨天':`${month}/${day}`;short=i===0?'今天':`${day}`;full=`${year}.${String(month).padStart(2,'0')}.${String(day).padStart(2,'0')}`;}
    if(mode==='month') {label=i===0?'本月':year===2026?`${month} 月`:`${year}/${month}`;short=i===0?'本月':`${month}月`;full=`${year} 年 ${month} 月`;}
    if(mode==='year') {label=i===0?'今年':`${year}`;short=label;full=`${year} 年`;}
    const fixture=(mode==='day'?dailyFixtures:mode==='month'?monthlyFixtures:yearlyFixtures)[i];
    return {i,label,short,full,tokens:fixture?.[0]??null,cost:fixture?.[1]??null};
  });
}
function UsagePanel({initialMode='month',panelId='single'}) {
  const [mode,setMode]=useState(initialMode);
  const [preferences,setPreferences]=useState({day:{count:7,selected:0},month:{count:6,selected:0},year:{count:3,selected:0}});
  const [menuOpen,setMenuOpen]=useState(false);
  const pickerRef=useRef(null),triggerRef=useRef(null),periodsRef=useRef(null);
  const config=usageModes[mode],{count,selected}=preferences[mode];
  const records=makeUsageRecords(mode,count),record=records[selected]||records[0];
  const rangeLabel=value=>value==='all'?'全部年份':`近 ${value} ${config.unit}`;
  const selectRecord=i=>{setPreferences(p=>({...p,[mode]:{...p[mode],selected:i}}));setMenuOpen(false);};
  const selectRange=value=>{setPreferences(p=>({...p,[mode]:{count:value,selected:p[mode].selected<(value==='all'?3:value)?p[mode].selected:0}}));setMenuOpen(false);triggerRef.current?.focus();};
  const changeMode=next=>{setMode(next);setMenuOpen(false);};
  useEffect(()=>{
    if(!menuOpen)return;
    const onPointer=event=>{if(!pickerRef.current?.contains(event.target))setMenuOpen(false);};
    const onKey=event=>{if(event.key==='Escape'){setMenuOpen(false);triggerRef.current?.focus();}};
    document.addEventListener('pointerdown',onPointer);document.addEventListener('keydown',onKey);
    return ()=>{document.removeEventListener('pointerdown',onPointer);document.removeEventListener('keydown',onKey);};
  },[menuOpen]);
  useEffect(()=>{
    const container=periodsRef.current,item=container?.children[selected];
    if(container&&item)container.scrollLeft=Math.max(0,item.offsetLeft-container.offsetLeft-container.clientWidth/2+item.clientWidth/2);
  },[mode,count,selected]);
  const peak=Math.max(...records.map(r=>r.tokens||0));
  const currentNote=mode==='day'?'今日统计截至当前时刻':mode==='month'?'本月统计截至当前时刻':'今年统计截至当前时刻';
  const note=record.tokens===null?`该${config.noun}暂无本机用量记录`:record.i===0?currentNote:`${record.full} · 本机用量记录`;
  return <div className="app-shell" data-screen-label={`${config.label}用量预览`} data-testid={`panel-${panelId}`}>
    <header className="app-header">
      <img src="CodexIcon.png" alt="Codex"/>
      <div><div className="app-name">Codex Meter <span>PLUS</span></div><div className="app-email">de••••@example.com</div></div>
      <span className="app-context">用量区域</span>
    </header>
    <div className="card-area">
      <section className="usage-card" aria-label="用量统计">
        <div className="card-heading">
          <h2><span className="calendar-icon" aria-hidden="true"></span>用量统计</h2>
          <div className="range-picker" ref={pickerRef}>
            <button className="range-trigger" ref={triggerRef} aria-label={`显示范围：${rangeLabel(count)}`} aria-haspopup="menu" aria-expanded={menuOpen} onClick={()=>setMenuOpen(!menuOpen)}>{rangeLabel(count)}<i className="chevron" aria-hidden="true"></i></button>
            {menuOpen&&<div className="range-menu" role="menu" aria-label="显示范围" onKeyDown={event=>{if(['ArrowDown','ArrowUp'].includes(event.key)){event.preventDefault();const options=[...event.currentTarget.querySelectorAll('button')],index=options.indexOf(document.activeElement);options[(index+(event.key==='ArrowDown'?1:options.length-1))%options.length]?.focus();}}}>
              {config.ranges.map(value=><button key={value} role="menuitemradio" aria-checked={value===count} onClick={()=>selectRange(value)}>{rangeLabel(value)}<span aria-hidden="true">{value===count?'✓':''}</span></button>)}
            </div>}
          </div>
        </div>
        <div className="granularity" role="tablist" aria-label="统计周期">
          {Object.entries(usageModes).map(([key,value])=><button key={key} role="tab" id={`${panelId}-tab-${key}`} aria-controls={`${panelId}-details`} aria-selected={mode===key} tabIndex={mode===key?0:-1} onClick={()=>changeMode(key)} onKeyDown={event=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(event.key)){event.preventDefault();const modes=Object.keys(usageModes),index=modes.indexOf(mode);const next=event.key==='Home'?'day':event.key==='End'?'year':modes[(index+(event.key==='ArrowRight'?1:2))%3];changeMode(next);document.getElementById(`${panelId}-tab-${next}`)?.focus();}}}>{value.label}</button>)}
        </div>
        <div id={`${panelId}-details`} role="tabpanel" aria-labelledby={`${panelId}-tab-${mode}`}>
          <div className="period-tabs" ref={periodsRef} role="group" aria-label={mode==='day'?'选择日期':mode==='month'?'选择月份':'选择年份'} style={{'--period-width':mode==='day'?'45px':mode==='year'?'60px':'52px'}}>
            {records.map(item=><button key={item.i} aria-pressed={item.i===record.i} title={item.full} onClick={()=>selectRecord(item.i)}>{item.label}</button>)}
          </div>
          <div className="detail-heading"><span className="status-dot"></span><h3>{record.label}用量</h3><span className="date-range">{record.full}</span></div>
          <div className="metrics" aria-live="polite">
            <div className="metric"><span>Token</span><strong>{formatTokens(record.tokens)}</strong></div>
            <div className="metric"><span>API 等效费用</span><strong>{formatCost(record.cost)}</strong></div>
          </div>
          <div className={`chart ${records.length>14?'dense':''}`} role="group" aria-label={`${config.label} Token 用量对比`} style={{'--bar-count':records.length,'--bar-gap':records.length>14?'3px':'8px'}}>
            {records.map(item=><button key={item.i} className={item.tokens===null?'no-record':''} aria-label={`查看${item.full}用量`} aria-pressed={item.i===record.i} title={`${item.full}\n${item.tokens===null?'暂无本机记录':`${formatTokens(item.tokens)} Token · ${formatCost(item.cost)}`}`} onClick={()=>selectRecord(item.i)}>
              <i className="chart-bar" style={{'--bar-height':`${Math.max(2,65*(item.tokens||0)/(peak||1))}px`}}></i>
              <span className="chart-label">{records.length<=7||item.i===0||item.i===records.length-1||item.i%Math.ceil(records.length/6)===0?item.short:''}</span>
            </button>)}
          </div>
          <div className="footnote"><span className="info" aria-hidden="true">i</span><span>{note}</span></div>
        </div>
      </section>
    </div>
  </div>;
}
function UsageDesignApp() {
  const [dark,setDark]=useState(false);
  const [view,setView]=useState(new URLSearchParams(location.search).get('view')==='single'?'single':'compare');
  useEffect(()=>{document.documentElement.dataset.theme=dark?'dark':'light';},[dark]);
  useEffect(()=>{
    if(view!=='compare')return;
    const fit=()=>window.postMessage({type:'__dc_fit_usage'},location.origin);
    const timer=setTimeout(fit,100);
    return ()=>clearTimeout(timer);
  },[view]);
  return <>
    <header className="review-toolbar">
      <div className="review-identity"><img src="CodexIcon.png" alt=""/><strong>Codex Meter</strong><span>用量统计 · 设计预览</span></div>
      <div className="review-actions"><span className="sample">示例数据</span><button className={view==='compare'?'active':''} onClick={()=>setView('compare')}>三种状态</button><button className={view==='single'?'active':''} onClick={()=>setView('single')}>单卡体验</button><button onClick={()=>setDark(!dark)}>{dark?'浅色预览':'深色预览'}</button></div>
    </header>
    {view==='compare'?<main className="canvas-wrapper"><DesignCanvas style={{height:'100%'}}><DCSection id="usage-periods" title="从每天，到每月、每年" subtitle="同一张卡片，切换统计周期。点选日期或柱子查看用量，右上角调整范围。" gap={32}>
      <DCArtboard id="usage-daily" label="01 · 每日 / 近 7 天" width={420} height={519}><UsagePanel initialMode="day" panelId="daily"/></DCArtboard>
      <DCArtboard id="usage-monthly" label="02 · 每月 / 近 6 个月" width={420} height={519}><UsagePanel initialMode="month" panelId="monthly"/></DCArtboard>
      <DCArtboard id="usage-yearly" label="03 · 每年 / 近 3 年" width={420} height={519}><UsagePanel initialMode="year" panelId="yearly"/></DCArtboard>
    </DCSection></DesignCanvas></main>:<main className="single-stage"><div className="single-caption"><span>主面板 · 用量统计</span><span>420 px · 可点击</span></div><UsagePanel panelId="single"/><p className="single-note">切换周期、选择日期或点击柱状图，试试查看历史用量。</p></main>}
  </>;
}
ReactDOM.createRoot(document.getElementById('root')).render(<UsageDesignApp/>);
