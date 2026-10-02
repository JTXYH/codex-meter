# 用量统计设计预览

> 历史记录：此文保留当时的设计或验证结果。v1.7.0 的当前界面使用每日 / 每周 / 每月 / 每年统计，按日期展示模型明细与额度估算；每日从昨天开始。最新说明与原生截图见[主 README](../../README.md)。

本轮只制作设计稿。沿用现有月度卡片已选定的 C 样式，扩展为每日、每月、每年。

## 设计计划

1. 标题统一为「用量统计」，在卡片内增加每日 / 每月 / 每年切换。
2. 沿用日期选择、Token 与 API 等效费用、可点击柱状图。
3. 范围随周期变化：每日近 7 / 14 / 30 天；每月近 3 / 6 / 12 个月；每年近 3 / 5 年或全部年份。
4. 各周期独立保留范围与选中日期；当前周期提示统计截至当前时刻；无记录使用破折号。
5. 提供三种状态并排预览、单卡交互、深浅外观，截图后交给用户审阅。

## 来源

- `Sources/CodexMeter/Views/MonthlyUsageCard.swift`
- `Sources/CodexMeter/Views/MonthlyRangePopover.swift`
- `Sources/CodexMeter/Views/DesignSystem.swift`
- `Sources/CodexMeter/App/MeterFontSettings.swift`
- `designs/monthly-usage-panel/Monthly Usage Styles.html` 中已选定的 C 样式

保持 420 px 面板、20 px 卡片圆角、紫蓝强调色、系统常规字重与紧凑单层范围菜单。新增的周期切换是主要入口，日期选择使用较轻的高亮以区分层级。

所有数字均为设计示例，参考日期固定为 2026-09-22。实际日/月/年聚合、历史完整性、设置迁移和国际化需在设计确认后的功能开发阶段处理。

通过 HTTP 打开 `Usage Statistics.html`。React、ReactDOM、Babel 使用与项目原有设计稿一致的固定版本 CDN，其余资源位于本目录。
