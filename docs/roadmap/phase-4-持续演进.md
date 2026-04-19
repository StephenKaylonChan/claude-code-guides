# Phase 4 — 持续演进 (v3.14+)


> 跟进 Claude Code 官方更新 + 自研需求改进 + 社区最佳实践吸收

## 待跟进：官方更新

- [ ] Claude Code 新版本功能研究与整合
- [ ] 新增 Hook 事件 / Skills 能力的文档更新
- [x] AGENTS.md 兼容 Step 1（调研 + 共存指南） ✅ 2026/04/19 — v3.31 01 新增 Section 9 "与 AGENTS.md 共存"：`@import` 方案（推荐）+ symlink 备选 + Claude Code 当前不原生支持说明（issue #6235 / #34235 Open）+ 迁移路径 v4.0 触发信号。订正旧 TODO 误传："Claude/Cursor/Aider/Codex 均兼容" 对 Claude Code **不成立**
- [ ] AGENTS.md 兼容 Step 2（等 Claude Code 原生支持 AGENTS.md 后做 v4.0 迁移指南）— 跟踪 [issue #6235](https://github.com/anthropics/claude-code/issues/6235) / [#34235](https://github.com/anthropics/claude-code/issues/34235) 关闭状态

## 待探索：自研需求

- [x] 使用中发现的工作流改进点 ✅ 2026/03/25 — v3.14 `/task` 日常小任务 Skill（v3.19 重命名为 `/implement` 并流程强化）
- [x] 代码质量深度诊断工作流 ✅ 2026/03/29 — v3.15 `/diagnose` 全维度代码健康诊断 Skill
- [x] 测试策略体系 ✅ 2026/03/29 — v3.16 Testing Trophy 集成测试为主 + 完成标准增强 + rules 测试规则
- [x] `/task` → `/implement` 重命名 + 防面条流程强化 ✅ 2026/04/14 — v3.19 Kent Beck 三红灯 + Tidy First + rg 模式扫描 + ADR 弹窗触发
- [x] Skills 体系梳理（逐个重新定位） ✅ 2026/04/14-15 — v3.19-v3.30 共梳理 12 个 skill + 废弃 1 个（/deep-audit）：/implement、/done、/catchup、/handoff、/spec+/done Gate 三类型、/audit、**/docs 扩展为文档生态守护者**、/diagnose、/release 参数分流、/nbp2、**/fix-permission 写入模板**、**/codex 写入模板**
- [x] "重复模式 → lint 建议"维度 ✅ 2026/04/15 — v3.26 加入 /diagnose D11 一致性维度（Addy Osmani "重复犯错升级为 lint 规则"理念，2+ 次重复输出独立清单含 ESLint/.claude/rules/ 配置建议）
- [ ] guides 自身配置优化（已完成基础配置 v3.13）

## 待吸收：社区实践

- [ ] 社区优秀 CLAUDE.md 模式收集
- [ ] 社区 Hook/Skill 创意用法整合
