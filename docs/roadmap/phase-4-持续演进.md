# Phase 4 — 持续演进 (v3.14+)


> 跟进 Claude Code 官方更新 + 自研需求改进 + 社区最佳实践吸收

## 待跟进：官方更新

- [ ] Claude Code 新版本功能研究与整合
- [ ] 新增 Hook 事件 / Skills 能力的文档更新
- [ ] AGENTS.md 兼容（2025-12 Linux Foundation 接管标准，Claude/Cursor/Aider/Codex 均兼容，6 万+ repo 采用）

## 待探索：自研需求

- [x] 使用中发现的工作流改进点 ✅ 2026/03/25 — v3.14 `/task` 日常小任务 Skill（v3.19 重命名为 `/implement` 并流程强化）
- [x] 代码质量深度诊断工作流 ✅ 2026/03/29 — v3.15 `/diagnose` 全维度代码健康诊断 Skill
- [x] 测试策略体系 ✅ 2026/03/29 — v3.16 Testing Trophy 集成测试为主 + 完成标准增强 + rules 测试规则
- [x] `/task` → `/implement` 重命名 + 防面条流程强化 ✅ 2026/04/14 — v3.19 Kent Beck 三红灯 + Tidy First + rg 模式扫描 + ADR 弹窗触发
- [ ] `/audit` 新增"重复模式 → lint 建议"维度（Addy Osmani "重复犯错升级为 lint 规则"理念）
- [ ] guides 自身配置优化（已完成基础配置 v3.13）

## 待吸收：社区实践

- [ ] 社区优秀 CLAUDE.md 模式收集
- [ ] 社区 Hook/Skill 创意用法整合
