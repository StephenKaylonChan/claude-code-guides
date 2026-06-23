---
title: Loop Engineering Skill
status: implementing
created: 2026-06-23
updated: 2026-06-23
total_phases: 4
active_phase: 4
roadmap: Phase 4 — 持续演进 / 待探索：自研需求
---

# Loop Engineering Skill 设计文档

## 讨论收敛总结

已达成共识：

- Loop Engineering 适合作为 guides 的新 Skill 方向，但第一版 MUST 是"目标驱动的有限循环协议"，MUST NOT 是无限自动执行器。
- Skill 的价值不在于替代 `/spec`、`/implement`、`/done`、`/handoff`、`/catchup`，而是把用户的目标转成可执行、可验证、可停止、可恢复的 loop contract，并按情况编排既有 Skill。
- 普通执行步骤 SHOULD 自动推进，避免每一步都问用户；重大决策、范围扩大、阻塞、预算耗尽、外部副作用、人工 Gate MUST 停下来问用户。
- 完成判断 MUST 依赖验证 Gate，不允许 Agent 自评即完成；高风险改动 SHOULD 使用 maker/checker 分离或 subagent 独立审查。
- 新增正式 Skill 会牵动 `.claude/skills/`、`.agents/skills/`、`03-Skills命令配置.md`、README Skills 总数、prompt 模板、版本记录和 Roadmap，正式实施时 SHOULD 走一次小版本升级。

已确认：

- Skill 名称采用 `loop-engineering`，不增加 `/loop` 短别名，避免和 Claude Code 既有 `/loop` / `/goal` 概念冲突。
- 第一版 `allowed-tools` 只保留 `Read, Glob, Grep, Bash`，不包含 `Write/Edit`；真正写入通过平台权限或既有 `/implement` 流程完成。
- 第一版不创建后台 automation/routine，最多输出建议并要求用户显式确认。

## 背景与目标

### 背景

近期社区开始讨论 "Loop Engineering"：相比一次性 Prompt Engineering，它强调设计一个能持续推进、验证、反馈、恢复和停止的 Agent 工作循环。它不是某个单一工具或标准，而是一组围绕 Coding Agent 的工作方法：

- 把目标表达为可验证的循环任务，而不是一次性指令。
- 用明确的 Done / Stop / Block 条件控制 Agent 行为。
- 用测试、lint、CI、日志、人工验证、diff review 等反馈信号驱动下一轮。
- 用 worktree、subagent、review agent、hooks、skills、automations 等能力拆分执行与校验。
- 把可复用上下文固化到 `CLAUDE.md` / `AGENTS.md` / Skills / project docs 中，减少重复提示。

调研中识别到的代表性来源：

- Addy Osmani 的 Loop Engineering 文章：把 agentic workflow、automation、worktree、skills、plugins/connectors、subagents 等组合视为下一阶段实践。
- Business Insider 对 2026 年 6 月社区讨论的整理：Loop Engineering 被描述为从提示单个 Agent 转向设计 Agent loops。
- OpenAI Codex 文档：Automations、Skills、Subagents、Worktrees 和 `AGENTS.md` 说明了 Codex 侧可实现 loop 的基础能力。
- Claude Code 文档：`/goal`、`/loop`、scheduled tasks/routines、skills、hooks、subagents 等提供了 Claude Code 侧的 loop primitives。
- Agent Skills 规范：说明 Skill 应以 frontmatter 触发、正文渐进加载、工具权限保守为原则。

### 目标

新增一个 `loop-engineering` Skill，帮助用户把"我想让 Coding Agent 持续推进直到目标完成"这类意图转成工程化循环：

1. 明确目标、范围、非目标、预算和验收条件。
2. 生成 `Loop Contract`，作为本轮执行的边界。
3. 按 `Observe -> Decide -> Act -> Verify -> Reflect` 迭代。
4. 普通步骤自动推进，重大节点停下来问用户。
5. 复用现有 guides 工作流，避免新增一套并行收尾体系。
6. 在验证通过、阻塞、预算耗尽、用户暂停或需要人工决策时停止。

## 非目标

- 不做无限循环自动执行器。
- 不默认创建后台 routine、cron、automation 或 schedule。
- 不默认绕过权限、Hook、测试失败或人工确认。
- 不替代 `/spec` 的结构化设计职责。
- 不替代 `/implement` 的单改动执行纪律。
- 不替代 `/done` 的交付 Gate 与全局一致性检查。
- 不替代 `/handoff` / `/catchup` 的跨会话恢复机制。
- 不把 Claude Code 专属语法无脑镜像到 Codex 版 `.agents` 文件。

## 内容概要

正式落地后新增以下内容：

- `.claude/skills/loop-engineering/SKILL.md`：Claude Code 运行副本。
- `.agents/skills/loop-engineering/SKILL.md`：Codex 镜像副本，语义一致但术语与路径适配 Codex / AGENTS.md。
- `03-Skills命令配置.md`：新增 `/loop-engineering` 模板小节。
- `README.md`：目录结构、版本记录、Skills 总数更新。
- `prompt-新项目初始化.md`：初始化模板 Skills 清单与完成提示更新。
- `prompt-旧项目迁移.md`：迁移检查清单更新。
- `prompt-guide版本升级.md`：新功能知识与升级检查项更新。
- `docs/roadmap/phase-4-持续演进.md`：新增或勾选对应 Phase 4 自研需求条目。

## Skill 定位

### 推荐 frontmatter

Claude 版：

```yaml
---
name: loop-engineering
description: |
  目标驱动的有限 Agent 循环工作流。用于用户想把一次性 prompt 升级为可持续推进、可验证、可暂停恢复的 Coding Agent loop：定义目标、预算、停止条件、验证 Gate，必要时使用 subagents/并行审查，持续执行直到达成目标或遇到阻塞。
  触发关键词：Loop Engineering、loop、goal loop、自动迭代、循环推进、持续修复、多 Agent 协作、until done
argument-hint: "[目标描述] [可选: --budget N | --readonly | --plan | --execute]"
allowed-tools: Read, Glob, Grep, Bash
disallowed-tools: Write, Edit
disable-model-invocation: true
---
```

Codex 镜像版 SHOULD 保持同名同语义，但正文中的平台词汇应适配：

- `CLAUDE.md` -> `AGENTS.md`
- `.claude/skills/` -> `.agents/skills/`
- `Claude` -> `Codex`（仅在指代当前运行 Agent 时替换；引用 Claude Code 官方能力时不替换）
- `AskUserQuestion` -> 当前 Codex 环境可用的用户确认方式；没有弹窗时用明确的用户确认停顿

### 为什么禁用隐式模型调用

`loop-engineering` 权限边界比普通 Skill 更大。它会影响 Agent 是否持续执行、是否开 subagent、是否自动重试、是否进入长期任务。若隐式触发过宽，普通"改一下"可能被升级成 loop，导致成本和风险扩大。

因此第一版 SHOULD 设置 `disable-model-invocation: true`，要求用户显式调用或明确说"用 Loop Engineering"。

### 为什么硬禁止 Write/Edit（`disallowed-tools`）

Loop Engineering 的第一职责是设计循环协议和编排流程，不是直接写文件。第一版对写入做**硬禁止**，降低以下风险：

- 后台或长循环直接改仓库。
- 普通调研被误升级为写入。
- Skill 绕过 `/implement` 的模式扫描和自检。
- Skill 绕过 `/done` 的全局一致性检查。

**关键修正（v3.40 第三轮调研发现）**：`allowed-tools` 是"免确认预批准"清单，**不是限制清单**——不在其中列出 `Write/Edit` 并**不会**禁止它们，只是让它们走正常权限弹窗（一个减速带，不是硬墙）。要真正禁止，MUST 用 `disallowed-tools: Write, Edit`。因此第一版同时设置 `allowed-tools`（只读工具免确认）+ `disallowed-tools: Write, Edit`（硬禁止写入），二者职责不同。

当用户选择 `--execute` 且 scope / gate 清楚时，本 Skill **不直接写文件**，而是切换到 `/implement` 执行单点改动（由 `/implement` 走模式扫描、三红灯、Tidy First 等纪律），或通过当前平台正常申请写入权限。这正是"编排既有工作流"而非"自己动手"的设计意图。

## Loop Contract 模板

每次进入执行前 MUST 输出并遵守以下契约：

```markdown
## Loop Contract

**Goal**: [本轮要达成的目标]
**Scope**: [允许读/改的范围]
**Non-goals**: [明确不做的事]
**Mode**: readonly / plan / execute / maintenance
**Budget**: 最多 [N] 轮；最多 [M] 次自动返工；上下文超过 [X%] 停止或 handoff
**Done condition**:
- [可验证完成条件 1]
- [可验证完成条件 2]
**Stop condition**:
- Gate 全部通过
- 用户要求暂停/停止
- 达到预算上限
- 连续 N 轮无新证据或无进展
**Block condition**:
- 缺少权限/凭证/环境
- 目标或范围不清
- 修改面扩大到未批准范围
- Gate 失败且自动修复次数用完
**Verification gate**:
- [command: 可执行命令]
- [auto: 可观察事实]
- [manual: 需要用户验证的条件]
**Human confirmation points**:
- [必须停下来问用户的节点]
```

## 工作模式

| 模式 | 使用场景 | 行为 |
|------|----------|------|
| `readonly` | 调研、审计、方案评估 | 只读上下文和联网资料，输出 loop design，不改文件 |
| `plan` | 目标较大或需跨文档/跨模块 | 生成 Loop Contract 和 Phase 计划，必要时建议 `/spec` |
| `execute` | 用户已明确授权执行 | 在 scope 和 gate 内循环推进，普通步骤不反复询问 |
| `maintenance` | 周期巡检、定期刷新 | 只允许低风险只读；创建后台任务或写入前 MUST 询问 |

默认模式推断：

- 用户只说"研究/看看/评估" -> `readonly`
- 用户说"沉淀/设计/写方案/spec" -> `plan`
- 用户说"开始执行/自动推进/直到完成" -> `execute`
- 用户说"每天/每周/定期/监控" -> `maintenance`

## Workflow

### Step 0: Parse Arguments

从 `$ARGUMENTS` 提取：

- 目标描述
- 期望产物
- 模式参数：`--readonly` / `--plan` / `--execute`
- 预算参数：`--budget N`
- 范围限制：路径、模块、文件类型、禁止事项
- 验收线索：测试命令、文档检查、人工确认条件

如果目标或验收标准不清，MUST 停下来问用户，不进入循环。

### Step 1: Context Scan

读取当前项目的上下文，但避免重复加载已由入口文件 `@` 引用的内容。

通用扫描：

```bash
git status --short
git log --oneline -5
find docs/specs -maxdepth 1 -name "*.md" 2>/dev/null
```

guides 项目扫描：

```bash
find .claude/skills -maxdepth 2 -name "SKILL.md" | sort
find .agents/skills -maxdepth 2 -name "SKILL.md" | sort
rg -n "^### 2\\.[0-9]+ /|Skills 总数|\\.claude/skills|\\.agents/skills" 03-Skills命令配置.md README.md prompt-*.md
```

### Step 2: Build Loop Contract

基于 Step 0-1 输出本轮 Loop Contract。若用户没有给预算，默认：

- 最多 3 个 iteration。
- 最多 1 次自动返工。
- 上下文超过 60%-70% 时停止并建议 `/handoff`。
- 默认不创建 subagent，除非风险或搜索空间值得。

### Step 3: Choose Execution Path

| 判断 | 动作 |
|------|------|
| 涉及新增 Skill / Hook / frontmatter / 版本号 / 跨 00-04 多文档 | 升级 `/spec` 或先写 docs/specs 设计文档 |
| 单点小改动，scope 清楚 | 降解为 `/implement <描述>` |
| 已完成一轮修改，需要全局一致性 | 交给 `/done <描述>` |
| 预算/上下文不足但还没完成 | 执行或建议 `/handoff` |
| 恢复上一轮 loop | 先 `/catchup` |
| 只读调研 | 输出研究结论和 loop 设计，不写文件 |

### Step 4: Iterate

每轮 MUST 只推进一个最小交付单元：

1. Observe：读取当前状态和证据。
2. Decide：选择最小下一步，并说明原因。
3. Act：在批准 scope 内执行。
4. Verify：运行本轮 Gate。
5. Reflect：记录结果、失败原因、下一轮计划。

进入下一轮前检查：

- 是否达到 Done condition。
- 是否触发 Stop condition。
- 是否触发 Block condition。
- 是否触发 Human confirmation point。
- 是否仍在预算内。

### Step 5: Independent Review

以下情况 SHOULD 使用 subagent 或独立 review：

- 改动跨多个模块或多个文档源头。
- 实现者容易自我确认完成。
- 验证面包括安全、并发、权限、数据一致性、长期维护性。
- 搜索空间很大，主 Agent 串行探索成本高。

使用 subagent 的规则：

- 任务必须具体、自包含。
- 不把预期答案泄露给 reviewer。
- 实现 agent 与 review agent 的职责分离。
- 不默认每轮都开 subagent，避免成本失控。

### Step 6: Stop or Close

停止时 MUST 输出：

```markdown
## Loop Result

**Status**: done / blocked / stopped / handoff-needed
**Iterations**: [实际轮数] / [预算]
**Evidence**:
- [证据 1]
- [证据 2]
**Files changed**:
- [文件，如有]
**Verification run**:
- [命令或检查结果]
**Remaining risks**:
- [风险，如有]
**Recommended next command**:
- [/done / /handoff / /catchup / /spec / 无]
```

## 自动执行与人工确认边界

### SHOULD 自动执行

- 读取项目文档、spec、roadmap、session-notes、git 状态。
- `rg` / `grep` / `find` / `git status` / `git diff` / `git log` 等只读检查。
- 生成 Loop Contract。
- 拆分 iteration。
- 执行只读验证。
- 低风险失败后最多自动返工 1 次。
- 在 scope 内继续下一轮普通执行。

### MUST 停下来问用户

- 目标、范围、验收标准不清。
- 要新增 Skill、改 frontmatter、改 Hook、改权限策略。
- 涉及 guides 版本号 bump、README 版本记录、Skills 总数、prompt 模板同步。
- 要修改多个 00-04 文档或大段结构。
- 要创建后台 routine / automation / cron / schedule。
- 要联网、安装依赖、调用外部服务、访问生产系统、写入数据库。
- 要 push、发布、部署、删除文件、迁移数据。
- Gate 需要人工视觉/业务验证。
- 连续失败或预算即将耗尽。
- 当前发现与用户原始目标冲突，需要改变方向。

## Gate 设计

### 通用代码项目 Gate

- `[command: npm test]` / `[command: pnpm test]` / `[command: pytest]`
- `[command: npm run lint]`
- `[command: npm run typecheck]`
- `[auto: git diff 仅包含本轮 scope 内文件]`
- `[manual] While 用户执行关键路径, when 完成操作, the 系统 shall 表现为预期行为`

### guides 文档项目 Gate

- `[auto: README.md 与 00-04 文档版本号一致]`
- `[auto: README Skills 总数与实际模板清单一致]`
- `[auto: 03-Skills命令配置.md 与 .claude/.agents 运行副本语义一致]`
- `[auto: prompt-新项目初始化.md / prompt-guide版本升级.md Skills 清单同步]`
- `[auto: 新增代码块均标注语言]`
- `[auto: 表格列格式无明显错位]`
- `[manual] While 用户阅读新 Skill 描述, when 触发场景出现, the Skill shall 不误触普通小改动`

### Skill 本身 Gate

- frontmatter 包含 `name` / `description`，名称 kebab-case。
- description 明确触发范围，不泛化到所有 coding task。
- `allowed-tools` 保守，不默认预批准 `Write/Edit`。
- body 包含模式、Loop Contract、自动/人工边界、停止条件、失败反例。
- Claude 版与 Codex 镜像版路径术语一致但平台适配正确。

## 与现有 Skill 的关系

| 现有 Skill | 关系 |
|------------|------|
| `/spec` | 大目标、跨文档、新 Skill、版本升级时由 Loop Engineering 触发或建议，沉淀执行契约 |
| `/implement` | 每个小型 Act 阶段 SHOULD 降解为一个 `/implement` 可处理的单改动 |
| `/done` | 完成 Gate 和全局一致性检查由 `/done` 承担，Loop Engineering 不复制其职责 |
| `/handoff` | 预算不足、上下文变长、用户中断时保存 loop 状态 |
| `/catchup` | 下一轮恢复 loop 前读取 session-notes、active spec 和最近状态 |
| `/audit` | 可作为 readonly loop 的快速检查输入 |
| `/docs` | 文档一致性深审由 `/docs` 执行，Loop Engineering 只负责判断是否需要 |
| `/release` | Phase 完成后仍由 `/release` 管里程碑收官 |
| `/codex` | 大任务需要外部 AI 审查/闭环时可作为 Act 或 Review 阶段工具 |

## 实施计划

### Phase 1: 设计文档沉淀

**Tasks**:

- [x] 整理两轮调研结论。
- [x] 定义 Skill 定位、非目标、Loop Contract、模式、workflow。
- [x] 明确自动执行与人工确认边界。
- [x] 规划实施阶段和 Gate。

**Gate**:

- [x] `docs/specs/loop-engineering-skill.md` 存在。
- [x] frontmatter 包含 `status`、`total_phases`、`active_phase`。
- [x] 文档包含实施计划，且每个 Phase 独立可验证。

**On Complete**: 已进入 Phase 2。

### Phase 2: 新增 Skill 运行副本

**Tasks**:

- [x] 新建 `.claude/skills/loop-engineering/SKILL.md`。
- [x] 新建 `.agents/skills/loop-engineering/SKILL.md`。
- [x] 确保 Claude 版和 Codex 镜像版语义一致，平台路径和术语正确。
- [x] 对照本 spec 检查 frontmatter、workflow、Gate、风险反例。

**Gate**:

- [x] 两个 `SKILL.md` 均存在。
- [x] `.claude` 版使用 `.claude` 目录语义。
- [x] `.agents` 版使用 `.agents` 目录语义。
- [x] `rg -n "Loop Contract|Stop condition|Human confirmation|/spec|/implement|/done" .claude/skills/loop-engineering .agents/skills/loop-engineering` 能命中关键段落。

**On Complete**: 已进入 Phase 3，同步源头模板和版本信息。

### Phase 3: 同步 guides 模板与版本体系

**Tasks**:

- [x] `03-Skills命令配置.md` 新增 `/loop-engineering` 小节。
- [x] README 目录结构加入 `loop-engineering/SKILL.md`。
- [x] README 版本记录新增 v3.40 条目。
- [x] Skills 总数从 13 更新为 14。
- [x] `prompt-新项目初始化.md` Skills 必选清单与检查命令更新。
- [x] `prompt-旧项目迁移.md` 迁移清单更新。
- [x] `prompt-guide版本升级.md` 新功能知识和检查项更新。
- [x] Roadmap Phase 4 增加 "Loop Engineering Skill" 条目。

**Gate**:

- [x] 所有 00-04 文档和 README 版本号一致。
- [x] README、prompt 文件、03 模板中的 Skills 总数一致。
- [x] `rg -n "loop-engineering|Loop Engineering|Skills 总数|14 个" README.md 03-Skills命令配置.md prompt-*.md docs/roadmap/phase-4-持续演进.md` 输出覆盖预期文件。
- [x] 新增/修改代码块均有语言标注。

**On Complete**: 进入 Phase 4，执行静态验证与使用反馈验证。

### Phase 4: 验证与使用反馈

**Tasks**:

- [x] 用一个只读任务试跑：`/loop-engineering --readonly` 调研 Loop Engineering 本身 + 评估优化本 Skill（2026-06-23，产出 R1–R8 改动）。
- [ ] 用一个小执行任务试跑：例如"单文档小节措辞优化，预算 2 轮"。
- [ ] 验证普通步骤不频繁打断用户。
- [ ] 验证重大决策点会停下来问用户。
- [ ] 根据试跑反馈微调 Skill。

**Gate**:

- [ ] 只读试跑没有写文件。
- [ ] 执行试跑遵守预算和 Stop condition。
- [ ] 触发新增 Skill / 跨文档同步时会升级到 `/spec` 或停下来确认。
- [ ] 失败反例中至少覆盖"无限循环"、"自评完成"、"默认写文件"三类风险。

**On Complete**: 如 Roadmap Phase 条目完成，执行 `/done`，必要时进入 `/release`。

## 危险设计反例

| 反例 | 问题 | 修正 |
|------|------|------|
| "一直做直到完成" | 无预算、无停止条件，容易失控 | 必须写 Loop Contract 和预算 |
| 实现 Agent 自己宣布完成 | 自我确认，缺少外部证据 | 必须通过 Gate，必要时独立 review |
| 默认允许 `Write/Edit` | 背景循环可直接改仓库 | frontmatter 保守，写入走授权或 `/implement` |
| 自动创建 routine/cron | 用户可能只想一次性研究 | maintenance 模式创建前必须确认 |
| 复制 `/done` 逻辑 | 形成第二套收尾体系 | 完成检查交给 `/done` |
| 绕过 `/spec` 直接新增 Skill | 跨文档同步风险高 | 新 Skill / 版本 bump 先 spec 或确认 |
| 每轮都开 subagent | token 成本高，结果难合并 | 只在高风险或大搜索空间使用 |
| Claude/Codex 镜像混写 | 路径和平台语义错误 | 分别适配 `.claude` 与 `.agents` |

## 第三轮调研补充与打磨（v3.40）

第三轮用 `/loop-engineering --readonly` 自身试跑（即 Phase 4 的只读试跑任务），联网核实了概念来源与平台声明，据此打磨首版。

### 核实结论

- **概念真实**：Loop Engineering = "不再逐轮 prompt agent，而是设计会自己 prompt agent 的系统"。Addy Osmani 2026-06-07 同名长文给出正式解剖；Peter Steinberger 推文点火；Boris Cherny（Claude Code 负责人）背书"我不再 prompt Claude，我写 loop"。谱系：ReAct(2022) → AutoGPT(2023) → "Ralph loop" 脚本(2025) → `/goal`、`/loop` 产品化(2026)。
- **Osmani 六件套**：Automations / Worktrees / Skills / Plugins-Connectors / Sub-agents / External State；四原则：maker-checker 分离、context offloading（外部记忆）、Done condition 由独立模型判、budget awareness。
- **平台声明核实**：`/goal`（v2.1.139+，设完成条件后持续推进）、`/loop`（定时或自定步调）、`disable-model-invocation`、subagents、hooks、worktrees 均**真实存在**。唯一修正见下。

### 据此落地的改动（R1–R8）

| 项 | 内容 | 落点 |
|----|------|------|
| R1 | 与内置 `/goal`、`/loop` 划清边界（避免重复造轮子） | SKILL Step 0 前置闸门 |
| R2 | 修正 `allowed-tools` 语义误解，增加 `disallowed-tools: Write, Edit` 硬禁止写入 | frontmatter + 本文上节 |
| R3 | "要不要用 loop" 前置判断（distill and demote：稳定任务用脚本/cron/lint，不套 LLM loop） | SKILL Step 0 前置闸门 |
| R4 | 停滞 circuit-breaker：连续 2 轮同一状态/局部最优 → 停下换大胆改动或问用户 | Loop Contract Stop condition + Step 4 |
| R5 | 完成判定（Done）MUST 由 Gate 或独立 agent 判，不许自评 | SKILL Step 6 |
| R6 | 把 Observe→Decide→Act→Verify→Reflect 标注为社区 Plan-Act-Observe 的超集 | SKILL Step 4 |
| R7 | L1/L2/L3 自治分级 + 与 `/diagnose` D11 联动（distill and demote） | SKILL notes |
| R8 | 补真实失败模式反例（loopmaxxing、comprehension debt、局部最优停滞、self-certification） | SKILL notes |

### 主要来源

- Addy Osmani — Loop Engineering（addyosmani.com/blog/loop-engineering，2026-06-07，一手）
- Addy Osmani — Plan-Act-Observe glossary（addyosmani.com/agentic-engineering/plan-act-observe/）
- bdtechtalks "loop engineering / loopmaxxing"（2026-06-22，批判视角）
- siliconsnark "Loop Writing Wants to Replace Prompting"（"不是所有任务都该用 loop"）
- firecrawl.dev / GitHub cobusgreyling/loop-engineering（Loop Contract 与成本工具）
- Claude Code 官方 docs：goal / scheduled-tasks / skills / sub-agents / worktrees / hooks

## 待确认问题

1. ~~是否需要在下一轮使用反馈后放宽 `allowed-tools`~~ → v3.40 已定：硬禁止写入（`disallowed-tools`），写入一律走 `/implement`，暂不放宽。
2. R8 已补社区失败模式反例；是否还要补 guides 项目内的**真实使用案例**（如本次自身试跑）待下一轮决定。
3. 是否需要在 00 日常使用说明中增加更完整的用户侧场景示例。
