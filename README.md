# 参考文档 (Reference Guides)

> **文档性质**: 通用参考文档，可复用于任何项目
> **版本**: v3.33（2026-04）

本目录包含 AI 协作系统的**通用配置指南**，基于 Claude Code 2.x 原生能力设计，可直接复制到其他项目使用。

---

## 📚 文档列表

### 使用说明 & 初始化 Prompt

| 文档 | 说明 | 何时用 |
|------|------|--------|
| [00-日常使用说明.md](./00-日常使用说明.md) | 完整使用指南：日常流程、命令速查、常见场景 | 随时参考 |
| [prompt-新项目初始化.md](./prompt-新项目初始化.md) | 直接粘贴给 Claude，初始化全新项目 | 新项目第一次配置 |
| [prompt-旧项目迁移.md](./prompt-旧项目迁移.md) | 直接粘贴给 Claude，将旧系统（v2.x）迁移到新体系 | 有 CONTEXT.md / commands/ 的老项目 |
| [prompt-guide版本升级.md](./prompt-guide版本升级.md) | 直接粘贴给 Claude，将已有 v3.x 配置同步到最新 guide | guide 更新后，同步到已有项目 |
| [prompt-更新指南规范.md](./prompt-更新指南规范.md) | 直接粘贴给 Claude，全网搜索最新规范，自动更新 guides 本身 | 定期维护（建议每月或新版本发布后） |

> **使用方式**：在目标项目中启动 Claude Code，@ 对应 prompt 文件，Claude 会自主读取并执行全部配置步骤。
>
> **维护循环**：`prompt-更新指南规范` → 更新 guides → `prompt-guide版本升级` → 同步到各项目

### 配置参考文档

| 文档 | 说明 | 优先阅读 |
|------|------|-----------|
| [01-CLAUDE配置架构指南.md](./01-CLAUDE配置架构指南.md) | CLAUDE.md 层级结构 + Auto Memory 管理 | 配置参考 |
| [02-Hooks自动化配置.md](./02-Hooks自动化配置.md) | 21个 Hook 事件 + 实用模板（测试门禁/自动格式化/通知/压缩恢复） | 配置参考 |
| [03-Skills命令配置.md](./03-Skills命令配置.md) | 替代旧 Slash Commands 的 Skills 系统配置 | 第三读 |
| [04-工作流最佳实践.md](./04-工作流最佳实践.md) | Explore→Plan→Code→Verify→Simplify→Commit、Worktrees、MCP 选型、反模式 | 随时参考 |

---

## 🎯 命令体系

命令分三类：**Bundled Skills**（Anthropic 内置，7 个）、**自定义 Skills**（安装到 `.claude/skills/`，12 个）、**系统命令**（内置，无需配置）。

完整命令速查表见 [00-日常使用说明.md](./00-日常使用说明.md) Section 7。

---

## 📁 新项目目录结构

```
project-root/
├── CLAUDE.md                      # AI 记忆核心（< 150 行）
├── CLAUDE.local.md                # 个人本地配置（gitignore）
│
├── .claude/
│   ├── settings.json              # 权限 + Hooks 配置
│   ├── rules/
│   │   ├── frontend.md            # 前端路径感知规则
│   │   └── backend.md             # 后端路径感知规则
│   ├── skills/                    # 自定义命令（12 个，v3.29 fix-permission、v3.30 codex）
│   │   ├── audit/SKILL.md
│   │   ├── catchup/SKILL.md
│   │   ├── handoff/SKILL.md
│   │   ├── spec/SKILL.md
│   │   ├── implement/SKILL.md
│   │   ├── done/SKILL.md
│   │   ├── docs/SKILL.md
│   │   ├── release/SKILL.md
│   │   ├── nbp2/SKILL.md
│   │   ├── diagnose/SKILL.md
│   │   ├── fix-permission/SKILL.md
│   │   └── codex/SKILL.md
│   ├── agents/                    # 自定义子代理（可选）
│   └── hooks/                     # Hook 脚本
│       ├── session-start.sh
│       ├── pre-commit-check.sh
│       ├── post-write.sh
│       └── on-stop.sh
│
├── apps/
│   ├── web/
│   │   └── CLAUDE.md              # 前端专属规范（懒加载）
│   └── api/
│       └── CLAUDE.md              # 后端专属规范（懒加载）
│
└── docs/
    ├── roadmap/                   # 项目路线图（进度跟踪）
    │   ├── README.md              #   总览：Phase 列表 + 当前进度
    │   ├── phase-1-xxx.md         #   已完成的 Phase（不加载）
    │   └── phase-2-xxx.md         #   当前 Phase（@引用加载）
    ├── specs/                     # 功能设计文档（/spec 生成）
    │   ├── user-auth.md           #   各功能的设计 spec
    │   └── dashboard-redesign.md
    ├── development/               # 开发文档（/release 刷新）
    │   ├── getting-started.md     #   手写：新人上手指南
    │   ├── deployment.md          #   手写：部署流程、环境变量、回滚
    │   └── changelog.md           #   自动生成：版本发布记录
    └── architecture/
        ├── README.md              # 架构总览（@引用自动加载，/docs 刷新）
        ├── frontend.md            # 前端架构详细（/docs frontend 刷新）
        ├── backend.md             # 后端架构详细（/docs backend 刷新）
        └── adr/                   # 架构决策记录（/release 检查是否需要新增）
```

---

## 🚀 新项目初始化

在目标项目中启动 Claude Code，@ 引用 `prompt-新项目初始化.md`，Claude 会自主完成全部配置（CLAUDE.md、settings.json、hooks、skills、rules、roadmap）。

详见 [00-日常使用说明.md](./00-日常使用说明.md) Section 1 或直接使用 [prompt-新项目初始化.md](./prompt-新项目初始化.md)。

---

## 🔄 版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v3.33 | 2026-04 | **`/fix-permission` Web 类诊断扩展**（基于真实使用反馈：60+ WebFetch 域名分散在 `settings.local.json` 跨项目不复用 + 截图 14/17 弹窗为 Web 类）。**Step 2 诊断表新增 Web 类小表**（`Claude wants to fetch content from X` → `WebFetch(domain:X)` 首选用户级 / `WebSearch` 弹窗 → 零风险全局开 noargs 形式）。**Step 5 写入级别建议加 Web 类**（WebFetch domain 跨项目复用价值大，强烈建议用户级；WebSearch 文本无 URL 抓取风险）。**新增"`Yes, and don't ask again` 沉淀位置陷阱"说明**：默认进 `settings.local.json` 项目本地不复用，建议定期提升至用户级。**新增"`settings.local.json` 残骸清理"小节**：识别 Claude Code 对 for-loop / heredoc 拆词错误产生的假规则（`Bash(do)` / `Bash(done)` / `Bash(for f:*)` 等），跑完 `/fix-permission` 顺手扫一眼删除。**与 Bundled `/fewer-permission-prompts` 分工说明**：单条精确诊断 + 用户级写入 vs 批量补全项目级白名单。Skills 总数不变（12 个）|
| v3.32 | 2026-04 | **Claude Code 2.1.89-114 功能跟进 + guides 自身配置优化**。**00 文档**：Bundled 命令 **5 → 7**（新增 `/less-permission-prompts` v2.1.111 扫描 transcript 生成权限白名单、`/ultrareview` v2.1.111 云端并行多 agent 审查）+ 高频命令表补 `/recap`（v2.1.108 返回会话摘要）、`/tui fullscreen`（v2.1.110 无闪烁全屏）、`/focus`（v2.1.110 独立命令）、`/team-onboarding`（v2.1.101）、`/effort` 新增 `xhigh` 等级（v2.1.111 Opus 4.7 专属）、`/undo` = `/rewind` 别名（v2.1.108）。**02 文档**：PreCompact Hook 新增**阻塞能力**（v2.1.105 `exit 2` / `{"decision":"block"}`），附示例代码。**03 文档**：Frontmatter description 列表显示上限 **250 → 1,536 字符**（v2.1.105）+ `context: fork` / `agent` 字段 v2.1.101 起修复后真正生效 + Bundled Skills 新增 2 个 + **v2.1.108 新机制**（模型可通过 Skill tool 主动发现和调用 `/init` `/review` `/security-review` 等内置命令）。**自身配置优化**：guides 本地 `.claude/skills/` 新增 4 个定制版 skill（implement/docs/audit/release），针对文档项目适配（移除 ADR 触发、测试/lint/构建检查等代码项目专属逻辑），连同之前 7 个共 **11 个**本地 skill（/diagnose 维度全代码属性，对文档项目空转，跳过）。识别 6 条自验证 insights 待 v3.33 反馈通用版模板。Phase 4 进度 **8/11 → 10/11** |
| v3.31 | 2026-04 | **AGENTS.md 兼容 Step 1**（调研 + 共存指南）。01-CLAUDE配置架构指南 新增 **Section 9 "与 AGENTS.md 共存"**：背景（2025-12 Linux Foundation 接管、AAIF founding project、6 万+ repo 采用）+ **Claude Code 当前不原生支持**（issue #6235 / #34235 仍 Open，订正旧 TODO 误传）+ **何时需要写 AGENTS.md**（多工具协作 / 外部贡献者 / `/codex` 跨 AI）+ **共存两种方案**（`@import` 推荐 / symlink 备选，对比优缺点）+ **v4.0 迁移触发信号**（Anthropic 官方原生支持 / AAIF schema 标准化 / 团队多工具占比）。Phase 4 roadmap 同步拆分为 Step 1（v3.31 已完成）+ Step 2（等 Claude Code 原生支持后做 v4.0 迁移指南）。Phase 4 进度 **7/10 → 8/11** |
| v3.30 | 2026-04 | `/codex` **首次写入 03 模板** + 混合使用模式，**Skills 体系梳理完成**（v3.19-v3.30 共梳理 12 个 skill + 废弃 1 个 /deep-audit）。Skills 总数 **11 → 12**。**核心改动**：**混合使用模式**（有参数快速 / 无参数 AskUserQuestion 引导 7 类任务 / 参数模糊时细化）+ **生成文件防覆盖**（已存在时 AskUserQuestion 覆盖/时间戳/取消）+ **粒度控制**（源文件 <30 全包含 / 30-100 最近改动 / ≥100 弹窗选范围）+ **大任务拆分提示**（估算 >50k tokens 时）+ **Step 1 自适应扫描**（读 CLAUDE.md 技术栈）+ **生成文档加 frontmatter**（generated/task_type/estimated_tokens）+ **description 明确适用范围**（Codex/GPT/Gemini/其他 Claude 等任意外部 AI）|
| v3.29 | 2026-04 | `/fix-permission` **首次写入 03 模板**（之前只存在于 guides 本地），Skills 总数 **10 → 11**。**核心能力升级**：**三级 settings 扫描**（用户级 `~/.claude/settings.json` / 项目级 `./.claude/settings.json` / 项目本地 `./.claude/settings.local.json`）+ **AskUserQuestion 选择写入级别**（根据规则性质选最合适）+ **写入前预演确认**（显示将添加规则 + 弹窗）+ **Step 4A 更新**（`Bash(*)` 仍被拦截时的 4 种解法：更具体规则 / deny 优先 / Auto mode / 手动确认）+ **扩展诊断表**（加管道、后台进程等常见拦截）|
| v3.28 | 2026-04 | `/nbp2` 轻度优化（工具类 skill，改动最小）：**Step 1 分流**——有参数（`/nbp2 <主题>`）直接走默认 NBP2；**无参数 AskUserQuestion 一次问清**（场景 + 目标模型 5 选项含自定义）。**模型对比表加注**（价格/速度/Model ID 数据截至 2026-04，以 Google 官方最新定价为准）。**加"与其他 skill 的关系"段**（声明 /nbp2 是独立工具，不对接开发工作流；专注 Nano Banana 生态，不适用其他生图模型）。**加用法示例段**（有参数推荐 / 无参数弹窗两种）。**不加** `disable-model-invocation: true`（工具类保持自动触发，"Nano Banana / NBP2 / Gemini 生图" 是强信号）。专业知识（六要素公式、进阶技巧、5 个示例）全部保留 |
| v3.27 | 2026-04 | `/release` 重新定位为"**Phase 里程碑工作流（含可选对外发版）**"：**明确区分两件事**——Phase 完成（内部里程碑）vs 对外发版（外部里程碑）。**参数分流**：`/release`（默认 A，Phase 内部里程碑）/ `/release --publish`（A+B，加版本号 bump + git tag + 对外 Changelog）。**对接 v3.25 /docs 新流程**：Step 1 全量 /docs + Step 1b 可选 /docs audit 深度审计。**ADR 检查 AskUserQuestion**：识别模式对齐 v3.19 /implement 四类触发（跨模块依赖 / 替换实现 / 新依赖 / 数据流向），基于 Phase 期间 commit message 推断。**Phase 开始日期三种 fallback**（Phase 文件 frontmatter → 上次 /release commit → 第一个 commit）。**精确 git add**（不用 `git add docs/` 宽泛 stage）。**默认不 push**（对齐 v3.25 /docs）。**Step 8 AskUserQuestion 引导下一步**（push / /diagnose / 规划 Phase N+1 / 其他）。明确排除临时 hotfix 场景（直接 `git tag` 更快）|
| v3.26 | 2026-04 | `/diagnose` 细节优化 + 吸收 Phase 4 "lint 建议" TODO：**Step 7 AskUserQuestion 引导下一步**（启动 /implement Batch / 写入 Roadmap / 只看报告）+ **D9 测试覆盖对接 v3.23 Gate**（扫 spec `[command]` Gate 对应测试是否存在，假 Gate 标记 P1）+ **D11 加"重复模式 → lint 建议"**（Addy Osmani 理念，2+ 次重复反模式 → 独立清单输出具体 ESLint / `.claude/rules/` 配置）+ **Step 1 自适应文件类型**（读 CLAUDE.md 技术栈段 + package.json/pyproject.toml 推断，不硬编码）+ **Step 5 加"不做"列**（投入产出比低明确标记，减少决策负担）+ **SubAgent 指令加 D9/D11 补充要点**。Phase 4 路线图"`/audit` 重复模式 → lint 建议"TODO 已在 /diagnose 完成并打勾 |
| v3.25 | 2026-04 | **体系重构**：`/deep-audit` **废弃**，功能合并到 `/docs`（重新定位为"**文档生态守护者**"）。**三个审查类命令分工明确**：/audit（代码质量+依赖+安全，浅层）/ /docs（文档一致性含 spec/ADR，深度）/ /diagnose（架构健康，13 维度量化）。`/docs` 四种操作：**更新**（不一致）/ **新增**（代码有文档缺）/ **删除**（文档有代码缺）/ **审计**（spec-code、ADR 有效性、Gate `[command]` 可执行性，对接 v3.23）。`audit` 子模式：`/docs audit` 专注深度审计。AskUserQuestion 修改前审核（>10 处弹窗）。历史对比（docs/reports/docs-*.md）。默认不 push。Skills 总数 **11 → 10**（移除 deep-audit）|
| v3.24 | 2026-04 | `/audit` 重新定位为"**浅层快速巡检**"：**参数 5 种简化为 3 种**（`/audit` / `--deep` / `--security`，去掉 `--quick` 和 `--docs`）+ **明确职责边界**（/audit 只发现不改代码 vs /deep-audit 修复 + commit vs /diagnose 架构量化）+ **命令自适应**（从 CLAUDE.md / package.json 读 lint/test/build 命令，不硬编码 pnpm；包管理器自动识别 pnpm/npm/yarn/poetry/pip）+ **AskUserQuestion 修复引导**（4 选项：只看报告 / 启动 /implement 批量修复 / 只修 P0 / 写入 Roadmap TODO）+ **历史对比**（保留 `docs/reports/audit-YYYY-MM-DD.md`，下次审计显示趋势 ↑/↓/→）+ **文档同步并入标准检查**（CLAUDE.md 行数、rules 路径、roadmap 一致性、stale spec 每次都查）+ **Security 优先用 gitleaks**（fallback grep）。Skills 总数不变（11 个）|
| v3.23 | 2026-04 | `/spec` 重新定位为"讨论成果整理为**执行契约**"+ Gate 三类型机器判定：**Gate 条件带类型标注**（`[auto: 观察表达式]` Claude 只读不判断 / `[command: shell]` 执行 exit code 0 / `[manual]` + **EARS 句式** `While X, when Y, the Z shall W` 弹窗）+ **文档边界声明**（Spec 执行契约，**不是** PRD/RFC/ADR；ADR 不合并进 spec 保留不可变性）+ **使用时机流程图**（初稿时机 vs 定稿时机，迭代式 spec 符合 Brooker 2026 共识）+ **AskUserQuestion 决策点**（分歧确认 / Roadmap 关联 / status 切换 draft→approved）+ **Phase 拆分阈值**（对齐 /implement 硬阈值：≤5 文件/单 Phase）+ frontmatter 精简（去冗余 `phase` 字段）。**连带升级 /done Step 4a**：Gate 验证支持三类型（auto 读取 / command 执行 / manual 弹窗），兼容旧格式视为 manual。设计依据：EARS（Rolls-Royce 2009）、Fitness Functions（Neal Ford）、Kiro + GitHub Spec Kit 社区实践、Martin Fowler 对"AI 自证"的警告。Skills 总数不变（11 个）|
| v3.22 | 2026-04 | `/handoff` 重新定位为"状态快照 + 下次恢复桥梁"：**参数分流**（默认完整 / `quick` 精简）+ **session-notes 瘦身为 6 段 + 关联指针**（保留叙事性摘要 + git 抓不到的软信息，去掉纯数字 git 统计，合并 Roadmap/Spec 状态到关联指针）+ **修复职责重叠**（不再碰 Spec frontmatter，归 /done 主业）+ **安全化 commit 失败处理**（Hook 拦下 → AskUserQuestion 询问用户，不自动 --no-verify）+ **新增文件 multiSelect 询问**（避免误 stage 临时文件）+ **commit message 复杂改动列候选**（≥4 文件 / 跨模块时弹窗）+ **Gate 满足但未 /done 检测**（提示用户先跑 /done）。Skills 总数不变（11 个）|
| v3.21 | 2026-04 | `/catchup` 重新定位为"工作上下文重建 + 下一步指引"：**去重加载**（识别 CLAUDE.md 已 @ 的文件不重复读，避免 Token 浪费）+ **参数聚焦模式**（`/catchup auth` 只读相关 spec/commit/文件；`/catchup 昨天做到哪了` 概览模式简要输出）+ **AskUserQuestion 引导下一步**（基于 session-notes/Phase 待办/implementing spec 生成 3-4 个具体候选，不散文询问）+ **和 SessionStart Hook 明确分工**（Hook 跑 git 被动、catchup 恢复深层上下文手动）。Skills 总数不变（11 个）|
| v3.20 | 2026-04 | `/done` 重新定位为"功能交付检查清单"（7 步 → 9 步）：**剥离代码验证重跑**（交给 /implement Verify 和 PreToolUse Hook）+ **新增测试覆盖快速扫描**（推断测试路径，缺失 AskUserQuestion 询问是否补）+ **Roadmap 部分完成检测**（父条目有未完成子项 → 弹窗确认）+ **文档影响智能判断**（按 diff 范围 + 完成粒度判断是否弹窗询问 /docs）+ **simplify 补跑询问**（启发式判断，≥3 文件才问）+ **Roadmap Phase 完成 AskUserQuestion 询问 /release**+ **commit message 动态生成**。新增"职责边界"说明（/done vs /handoff vs /implement）。原"自动 vs 手动"表格删除（/done 从不自动触发）。模板从 188 行扩展到 280 行 |
| v3.19 | 2026-04 | `/task` 重命名为 `/implement` 并流程强化：**命名冲突修正**（原 `/task` 与 Claude Code 原生 Task tool 语义冲突）+ **三个防面条机制**（Step 2 rg 模式扫描 MUST、Step 5 Kent Beck 三红灯 + Tidy First 分 commit MUST、Step 7 ADR 四类条件触发 AskUserQuestion 弹窗）+ **Step 1 硬阈值**（≥3 文件/跨模块 import/新依赖/数据流改变 → 升级 /spec 或 Plan Mode）+ frontmatter 修正（`disable-model-invocation: true`、移除 `Agent`）+ 六层收尾模型"小任务级"→"实施级"。设计依据：Anthropic "search before implement"、Kent Beck Augmented Coding、Claude Code 最佳实践。Skills 总数不变（仍 11 个） |
| v3.18 | 2026-04 | 全文档梳理优化：删除旧方案对比内容、Hook 事件 21→26 + handler 矩阵更新 + `if` 字段 + 渐进式配置建议、Skills Frontmatter 区分原生/Subagent 字段 + allowed-tools 含义修正 + Skill 生命周期、Plan Mode 补 Ultraplan/Auto Mode/opusplan、1M 上下文窗口说明、命令速查去重（00 保留完整版）、rules 红线与规范分离建议、完成标准精简（技术栈移 rules/）、维护指南与 /audit 对齐 |
| v3.17 | 2026-03 | `/docs` Skill 增加变更锚定步骤：用 git diff 定位"上次文档更新以来改了什么"，解决只查数字不一致、不查新增功能缺文档的设计漏洞。工作流从 5 步扩展为 6 步（Step 1 变更锚定 + Step 3 变更覆盖检查） |
| v3.16 | 2026-03 | Testing Trophy 测试策略：集成测试为主（测用户操作链路，不只是独立函数）、四层测试体系（静态/单元/集成/E2E）、CLAUDE.md 完成标准要求关键交互 MUST 有集成测试、rules 模板增加前后端测试规则（RTL+MSW/TestClient/MockMvc）、`/diagnose` D9 维度从"可测试性"扩展为"测试覆盖" |
| v3.15 | 2026-03 | `/diagnose` 全维度代码健康诊断 Skill：四层 13 维度系统性扫描（结构/实现/卫生/战略）、量化健康度评分（0-10）、热点分析（git 历史 × 代码质量）、自动 SubAgent 并行（大项目）、分批重构计划输出、技术栈专项检查（React/Next.js/FastAPI/Spring Boot）、Skills 总数 10→11 |
| v3.14 | 2026-03 | `/task` 日常小任务 Skill：补齐 Spec 与"改 typo"之间的空白、自动复杂度分流（太大→建议 /spec）、支持批量模式、六层收尾模型新增"小任务级"、Skills 总数 9→10（v3.19 重命名为 `/implement`） |
| v3.13 | 2026-03 | 代码质量防御体系：Stop Hook 质量门禁（响应结束后自动检查致命问题）、分层防御模型（Hook 硬拦 > 上下文纪律 > CLAUDE.md 红线 > /simplify 兜底）、CLAUDE.md 编码红线模板 + `.claude/rules/` 技术栈专属红线（含 React/FastAPI/Spring Boot 示例）、红线编写原则（少/硬/具体/含修 Bug 场景）、上下文劣化认知更新 |
| v3.12 | 2026-03 | Hook 事件 18→21（新增 PostCompact/Elicitation/ElicitationResult）、Hook Handler 类型补全（prompt/agent 支持更多事件）、PostCompact 模板、Skills/Agent frontmatter 新字段（memory/mcpServers/maxTurns/permissionMode/disallowedTools/`${CLAUDE_SKILL_DIR}`/`${CLAUDE_SESSION_ID}`）、Chrome 浏览器集成、Plugin 插件系统、`/effort` 命令、模型更新（Opus 4.6 默认/Sonnet 4.6/Effort 级别简化） |
| v3.11 | 2026-03 | `/done` 改进（显式描述参数，去掉自动猜测）、新增 `/docs` 开发文档梳理 Skill（深度探索代码→刷新架构/上手/部署文档，支持按范围指定）、`/release` 调整为 Phase 系统性梳理（含 `/docs` 全量）、架构文档拆分为 README+frontend.md+backend.md、Skills 总数 8→9 |
| v3.10 | 2026-03 | 架构认知地图（`docs/architecture/README.md` — 项目组织方式/模块划分/数据流，`@`引用自动加载，`/release` 审查 + `/deep-audit` 验证 + `/done` 结构性变更检测）、`/nbp2` AI 生图 Prompt 助手 Skill、Skills 总数 7→8 |
| v3.9 | 2026-03 | `/done` 三级智能升级（自动检测完成粒度：功能/Spec Phase/Spec 完成/Roadmap Phase）、四层收尾模型、Spec 分阶段实施（Implementation Phases + Tasks/Gate/On Complete）、Spec 进度自检协议、讨论收敛机制（共识/分歧归纳）、PreCompact Hook 增强（Spec 进度保存 + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`）、大 Spec 实施策略、auto-compact 应对 |
| v3.8 | 2026-03 | 开发文档体系（`docs/development/` 上手指南/部署/Changelog + 代码即文档原则 + ADR 模板）、`/release` Skill、`/done` 增强（部署配置检测）、`/voice` 语音模式、`/mcp` 对话框管理 + `list_changed`、`/rewind` 回滚模式、Worktree 声明式隔离 + Hook 状态、Remote Control `--name`、`/loop` 调度增强 |
| v3.7 | 2026-03 | Bug 修复工作流变体（复用六步循环，侧重复现+定位+回归测试），修复子节编号错位（04/03 文档） |
| v3.6 | 2026-03 | 三层收尾模型（Commit/功能/Phase），/done Skill，Spec YAML frontmatter 生命周期，完成标准扩展文档同步，Hook 高级能力（updatedInput/CLAUDE_ENV_FILE/Frontmatter Hooks），GitHub Actions 集成，Remote Control |
| v3.5 | 2026-03 | 升级开发循环为六步（加 Verify 验证步骤），复杂度分级流程选择，Explore→Plan→Clear→Code 主动策略，CLAUDE.md 完成标准驱动自动验证 |
| v3.4 | 2026-03 | 对标最新 Claude Code 功能：补充 5 个 Hook 事件 + async hooks，更新 MCP Tool Search 懒加载，补充 /loop 命令，更新 Context7 安装方式 |
| v3.3 | 2026-03 | 新增 /spec Skill + docs/specs/ 设计文档系统，更新 catchup/handoff/audit 联动，更新三个 Prompt 模板 |
| v3.2 | 2026-03 | 新增 docs/roadmap/ 项目进度跟踪系统，改造 handoff/catchup Skill，更新三个 Prompt 模板 |
| v3.1 | 2026-03 | 补充新 Hook 事件、/simplify /batch 内置命令、Agent Teams、/handoff 自动 commit 优化、新增 prompt-guide版本升级.md |
| v3.0 | 2026-03 | 全面重构：基于 Claude Code 2.x 原生能力重新设计 |
| v2.2 | 2025-12 | 补充 /deep-audit 和 /fix 完整配置 |
| v2.1 | 2025-12 | 添加 /deep-audit 命令 |
| v2.0 | 2025-11 | 全面更新，添加标准模板 |
| v1.0 | 2025-11 | 初始创建 |

---

**文档性质**: 通用参考模板（可跨项目复用）
**最后更新**: 2026-04（v3.31）
