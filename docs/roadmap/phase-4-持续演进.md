# Phase 4 — 持续演进 (v3.14+)


> 跟进 Claude Code 官方更新 + 自研需求改进 + 社区最佳实践吸收

## 待跟进：官方更新

- [x] Claude Code 新版本功能研究与整合 ✅ 2026/04/19 — v3.32 跟进 v2.1.89-114（26 个小版本）。Bundled 命令 5→7（+/less-permission-prompts、+/ultrareview）；PreCompact 可阻塞（exit 2 / decision:block）；Skill description 上限 250→1536；frontmatter `context: fork` + `agent` 修复后生效；模型可通过 Skill tool 主动发现并调用内置命令；`/recap` Session Recap、`/tui fullscreen`、`/effort xhigh`（Opus 4.7）等。**v3.34 已处理**：01 新增 Section 7"环境变量与模型配置"（含 `ENABLE_PROMPT_CACHING_1H`、`CLAUDE_CODE_ENABLE_AWAY_SUMMARY` 等）。**v3.37 已处理**（2026/06/15 — 跟进 v2.1.114→176）：新增 **Fable 5 + Opus 4.8**（01 §7.2 模型表 + Model ID）；`xhigh`/`​fast` 适用模型修正；新增 **04 §9.4 Dynamic Workflows**（`ultracode`/`​/deep-research`/`​/workflows`）；Bundled 命令 7→9（+`/code-review`、+`/deep-research`、+`/workflows`，`/ultrareview` 降为 `/code-review ultra` 别名）；全局订正 `/less-permission-prompts`→`/fewer-permission-prompts`。**仍未处理**（待官方 changelog 核实版本号后写）：Hooks 新事件（WorktreeCreate/Remove、FileChanged、PermissionDenied）、settings 新字段（autoMode、worktree.baseRef、enforceAvailableModels）、02 `sandbox.network.deniedDomains`（v2.1.113）段落、plugin `monitors` manifest
- [x] 新增 Hook 事件 / Skills 能力的文档更新（合并到上条，v3.32 已覆盖本阶段）
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
- [x] /fix-permission Web 类诊断扩展 ✅ 2026/04/27 — v3.33 基于真实使用反馈（60+ WebFetch 域名分散在 settings.local.json 跨项目不复用 + 截图 14/17 弹窗为 Web 类）。Step 2 加 Web 类小表（WebFetch domain → 用户级 / WebSearch 零风险全局开）+ Step 5 写入级别建议加 Web 类 + "Yes, and don't ask again" 沉淀位置陷阱说明 + settings.local.json 残骸清理小节（拆词错误假规则识别）+ 与 Bundled /fewer-permission-prompts 分工说明。同步用户全局 settings.json 加 56 个 WebFetch domain + WebSearch noargs（实跑收尾）。**v3.38 补强**（2026/06/16 — 真实排查"WebSearch 已开但联网仍偶尔弹窗"驱动）：弹窗实为 WebFetch 撞名单外新域名。03 §2.11 Web 小节加三段——诊断翻转（"搜索还在问"先看弹窗第一行 `Fetch`/`Search`）+ 预期管理（逐域名白名单新站首次必弹属正常）+ 裸放 `WebFetch` 安全代价（拆掉防数据外泄防线）。三方同步源头/`.claude`/`.agents` 镜像。实跑全局 settings 补 6 域名 56→62。**v3.41 补强**（2026/06/26 — `deep-research` workflow 逐域名弹窗排查驱动）：全网抓取型 workflow 抓的是搜索结果动态冒出的不可预测 URL，逐域名白名单**结构性失效**。Web 小节加 **🌐 例外 callout**：此场景裸放 `WebFetch` 才是正解（非"图省事"）+ **判据**（域名"事先可枚举"→逐域名 /"由搜索结果动态决定"→裸放）+ 提示 `WebSearch` 全局开只解决搜索那步。三方同步源头/`.claude`/`.agents`。实跑全局 settings 加裸 `WebFetch`
- [x] /codex 三档输出升级（Codex CLI / Mac App 分化跟进） ✅ 2026/05/14 — v3.36 Codex 2025-2026 重启后分化为 **CLI**（npm `@openai/codex` v0.130.0+，Rust 实现）+ **Mac App**（独立桌面 App，Computer Use / Chrome 扩展 / Automations）。**新增 exec 模式**（CLI 闭环）：`cat .codex-task.md | codex exec --sandbox workspace-write --ask-for-approval never -`，Claude 直调拿回结果无需用户中转。**关键 flag 内置**（`--sandbox workspace-write` / `--ask-for-approval never` / 末尾 `-` / 可选 `--model X`）+ **未提交改动护栏**（exec 前 `git status` 提醒先 commit/stash） + **CLI 不可用降级 md 模式** + **app 模式提示段**（明示 Mac App 无法被自动调起 — `codex://` 仅打开面板、Automations 无外部 API，仅 Computer Use / Chrome 扩展场景手动选）。**Step 0 加 0-pre 检测段** + **Question 2 输出方式弹窗**（md / CLI exec / Mac App 手动 3 选项）
- [x] /loop-engineering 目标驱动有限循环 Skill ✅ 2026/06/23 — v3.40 基于 Loop Engineering 社区方法论和两轮调研沉淀：新增 `docs/specs/loop-engineering-skill.md` 设计文档 + `.claude/skills/loop-engineering` 运行副本 + `.agents/skills/loop-engineering` Codex 镜像 + 03 源头模板。核心机制：Loop Contract（Goal / Scope / Non-goals / Budget / Done / Stop / Block / Gate / Human confirmation points）+ Observe → Decide → Act → Verify → Reflect 有限迭代 + 自动推进/人工停顿边界 + 高风险 maker/checker 分离。首版保守：`disable-model-invocation: true`，`allowed-tools` 不含 `Write/Edit`，不默认创建后台 automation/routine。Skills 总数 13→14。**v3.40 打磨**（2026-06-23，用 `/loop-engineering --readonly` 自身试跑 + 联网核实驱动）：新增"要不要用 loop"前置闸门（distill and demote / 与内置 `/goal`·`/loop` 划清边界）+ 停滞 circuit-breaker + Done 判定独立 + L1-L3 自治分级 + 社区失败模式反例；改 `allowed-tools` 只读 + 增 `disallowed-tools: Write, Edit` 硬禁止写入（修正"不列即禁止"的误解）。spec 增第三轮调研补充节 + R1-R8 落点表 + 来源清单

## 待吸收：社区实践

- [ ] 社区优秀 CLAUDE.md 模式收集
- [ ] 社区 Hook/Skill 创意用法整合
