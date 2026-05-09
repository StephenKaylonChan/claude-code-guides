# Phase 4 — 持续演进 (v3.14+)


> 跟进 Claude Code 官方更新 + 自研需求改进 + 社区最佳实践吸收

## 待跟进：官方更新

- [x] Claude Code 新版本功能研究与整合 ✅ 2026/04/19 — v3.32 跟进 v2.1.89-114（26 个小版本）。Bundled 命令 5→7（+/less-permission-prompts、+/ultrareview）；PreCompact 可阻塞（exit 2 / decision:block）；Skill description 上限 250→1536；frontmatter `context: fork` + `agent` 修复后生效；模型可通过 Skill tool 主动发现并调用内置命令；`/recap` Session Recap、`/tui fullscreen`、`/effort xhigh`（Opus 4.7）等。**v3.34 已处理**：01 新增 Section 7"环境变量与模型配置"（含 `ENABLE_PROMPT_CACHING_1H`、`CLAUDE_CODE_ENABLE_AWAY_SUMMARY` 等）。**仍未处理**：02 新增 `sandbox.network.deniedDomains`（v2.1.113）段落、plugin `monitors` manifest 待新开段落
- [ ] 新增 Hook 事件 / Skills 能力的文档更新（合并到上条，v3.32 已覆盖本阶段）
- [x] AGENTS.md 兼容 Step 1（调研 + 共存指南） ✅ 2026/04/19 — v3.31 01 新增 Section 9 "与 AGENTS.md 共存"：`@import` 方案（推荐）+ symlink 备选 + Claude Code 当前不原生支持说明（issue #6235 / #34235 Open）+ 迁移路径 v4.0 触发信号。订正旧 TODO 误传："Claude/Cursor/Aider/Codex 均兼容" 对 Claude Code **不成立**
- [ ] AGENTS.md 兼容 Step 2（等 Claude Code 原生支持 AGENTS.md 后做 v4.0 迁移指南）— 跟踪 [issue #6235](https://github.com/anthropics/claude-code/issues/6235) / [#34235](https://github.com/anthropics/claude-code/issues/34235) 关闭状态

## 待探索：自研需求

- [x] 使用中发现的工作流改进点 ✅ 2026/03/25 — v3.14 `/task` 日常小任务 Skill（v3.19 重命名为 `/implement` 并流程强化）
- [x] 代码质量深度诊断工作流 ✅ 2026/03/29 — v3.15 `/diagnose` 全维度代码健康诊断 Skill
- [x] 测试策略体系 ✅ 2026/03/29 — v3.16 Testing Trophy 集成测试为主 + 完成标准增强 + rules 测试规则
- [x] `/task` → `/implement` 重命名 + 防面条流程强化 ✅ 2026/04/14 — v3.19 Kent Beck 三红灯 + Tidy First + rg 模式扫描 + ADR 弹窗触发
- [x] Skills 体系梳理（逐个重新定位） ✅ 2026/04/14-15 — v3.19-v3.30 共梳理 12 个 skill + 废弃 1 个（/deep-audit）：/implement、/done、/catchup、/handoff、/spec+/done Gate 三类型、/audit、**/docs 扩展为文档生态守护者**、/diagnose、/release 参数分流、/nbp2、**/fix-permission 写入模板**、**/codex 写入模板**
- [x] "重复模式 → lint 建议"维度 ✅ 2026/04/15 — v3.26 加入 /diagnose D11 一致性维度（Addy Osmani "重复犯错升级为 lint 规则"理念，2+ 次重复输出独立清单含 ESLint/.claude/rules/ 配置建议）
- [x] guides 自身配置优化 ✅ 2026/04/19 — v3.32 本地 `.claude/skills/` 新增 4 个文档项目定制版 skill（/implement /docs /audit /release），针对文档项目适配：/implement 移除 ADR 触发、/docs 改"源头-副本"一致性、/audit 换"文档质量+session-notes 新鲜度"、/release 移除 --publish 模式。/diagnose 跳过（13 维度全代码属性文档项目空转）。共 11 个本地 skill。识别 6 条自验证 insights（写入各 skill `<notes>` 段）可反馈 v3.33 通用版模板
- [x] /fix-permission Web 类诊断扩展 ✅ 2026/04/27 — v3.33 基于真实使用反馈（60+ WebFetch 域名分散在 settings.local.json 跨项目不复用 + 截图 14/17 弹窗为 Web 类）。Step 2 加 Web 类小表（WebFetch domain → 用户级 / WebSearch 零风险全局开）+ Step 5 写入级别建议加 Web 类 + "Yes, and don't ask again" 沉淀位置陷阱说明 + settings.local.json 残骸清理小节（拆词错误假规则识别）+ 与 Bundled /fewer-permission-prompts 分工说明。同步用户全局 settings.json 加 56 个 WebFetch domain + WebSearch noargs（实跑收尾）

## 待吸收：社区实践

- [ ] 社区优秀 CLAUDE.md 模式收集
- [ ] 社区 Hook/Skill 创意用法整合
