# Skills 命令配置指南

> Slash Commands 的进化版 — 更强大的自定义工作流命令

**版本**: v3.10
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [Skills vs 旧 Commands](#1-skills-vs-旧-commands)
2. [命令迁移说明](#2-命令迁移说明)
3. [Frontmatter 字段参考](#3-frontmatter-字段参考)
4. [保留的 Skills](#4-保留的-skills)
5. [新增的 Skills](#5-新增的-skills)
6. [Anthropic 内置命令（Bundled Skills）](#6-anthropic-内置命令bundled-skills)
7. [安装说明](#7-安装说明)

---

## 1. Skills vs 旧 Commands

Skills 是 Claude Code 2.x 中 Slash Commands 的升级版（文件位置从 `.claude/commands/` 迁移到 `.claude/skills/<name>/SKILL.md`）。

### 核心差异

| 特性 | 旧 Commands（`.claude/commands/`） | 新 Skills（`.claude/skills/`） |
|------|----------------------------------|-------------------------------|
| 文件格式 | 单个 `.md` 文件 | 目录内 `SKILL.md` + 可选资源 |
| 子代理执行 | 不支持 | 支持（`context: fork`） |
| 动态上下文注入 | 不支持 | 支持（`` !`command` `` 语法） |
| 自动触发 | 仅手动 | 支持基于 `description` 自动检测 |
| 模型覆盖 | 不支持 | 支持（`model: haiku/sonnet/opus`） |
| 独立 Hooks | 不支持 | 支持（Skill 作用域内的 Hooks） |
| 参数传递 | 基础 | `$ARGUMENTS`, `$1`, `$2` 等 |

> **兼容性**：旧 `.claude/commands/*.md` 文件仍然有效，但建议迁移到 Skills 格式以获得新特性。

---

## 2. 命令迁移说明

### 旧方案中哪些命令已被原生功能替代

下列旧命令**不再需要**，已由 Claude Code 原生能力或 Hooks 接管：

| 旧命令 | 替代方案 | 原因 |
|--------|---------|------|
| `/start` | `SessionStart` Hook + Auto Memory | 会话启动自动执行，无需手动恢复 |
| `/checkpoint` | `Stop` Hook + Auto Memory | Claude 完成响应时自动记录 |
| `/end` | `Stop` Hook + Auto Memory | 自动维护，无需手动执行 |
| `/weekly` | 不需要了 | CLAUDE.md < 200 行不会膨胀；Auto Memory 自动管理 |
| `/monthly` | 不需要了 | Auto Memory 无需手动归档 |
| `/fix` | `PostToolUse` Hook（自动触发） | 写文件时自动格式化，无需手动调用 |

### 保留并升级的命令

| 旧命令 | 新命令 | 变化 |
|--------|--------|------|
| `/audit` | `/audit` | 升级为 Skill 格式，增加子代理并行检查 |
| `/deep-audit` | `/deep-audit` | 升级为 Skill 格式，增加自动修复能力 |

### 新增命令

| 新命令 | 用途 |
|--------|------|
| `/catchup` | 执行 `/clear` 后快速恢复工作上下文 |
| `/handoff` | 会话结束前生成结构化交接文档 |
| `/spec` | 讨论成果整理为设计文档 |
| `/done` | 功能完成收尾检查（Roadmap/Spec/开发文档同步） |
| `/release` | Phase 完成：全量刷新开发文档 + 生成 Changelog |

---

## 3. Frontmatter 字段参考

```yaml
---
name: skill-name                      # 斜杠命令名称（/skill-name）
description: |                        # Claude 自动检测触发的描述（重要！）
  当用户需要做 X 时使用此命令。
  触发关键词：X、Y、Z
argument-hint: "[参数说明]"           # 命令行自动补全提示
allowed-tools: Read, Grep, Bash       # 此 Skill 可用的工具列表
model: haiku                          # 模型覆盖（haiku/sonnet/opus/inherit）
context: fork                         # fork = 在隔离子代理中运行
disable-model-invocation: false       # true = 只能用户触发，Claude 不能自动调用
user-invocable: true                  # false = 隐藏，只能 Claude 内部调用
---
```

### `description` 的重要性

`description` 字段控制 Claude 是否会**自动检测并调用** Skill。
写得越具体，自动触发越准确。如果不希望自动触发，设置 `disable-model-invocation: true`。

### `` !`command` `` 动态上下文注入

在 Skill 内容中使用反引号命令（前加 `!`），会在 Skill 执行前将命令输出注入到提示中：

```markdown
当前 Git 状态：
!`git status --short`

最近 5 个 commit：
!`git log --oneline -5`
```

---

## 4. 保留的 Skills

### 4.1 /audit — 项目健康检查

**文件路径**: `.claude/skills/audit/SKILL.md`

````markdown
---
name: audit
description: |
  项目健康检查。当需要检查代码质量、依赖安全、文档同步状态时使用。
  触发关键词：健康检查、audit、代码质量检查、依赖检查
argument-hint: "[--quick | --full | --security | --docs]"
allowed-tools: Read, Bash, Grep, Glob
disable-model-invocation: true
---

<task>
对项目进行健康检查，根据参数决定检查深度。
</task>

<workflow>

## Step 0: 获取基本信息

```bash
echo "=== 项目审计 $(date '+%Y-%m-%d %H:%M') ==="
echo "--- 最近 5 个 commit ---"
git log --oneline -5
echo "--- 未提交文件 ---"
git status --short | head -20
```

## Step 1: 解析参数

| 参数 | 检查范围 | 适用场景 |
|------|---------|---------|
| `--quick` | Git 状态 + CLAUDE.md 行数 | 每天快速检查 |
| 无参数 | 代码质量 + 依赖 + 文档同步 | 每周常规 |
| `--full` | 全部 + 构建测试 | 大版本发布前 |
| `--security` | 安全漏洞 + 敏感信息扫描 | 上线前 |
| `--docs` | 文档与代码同步深度检查 | Phase 完成后 |

## Step 2: Quick 模式检查

```bash
# CLAUDE.md 行数（超过 200 行需要拆分）
wc -l CLAUDE.md 2>/dev/null || echo "CLAUDE.md 不存在"

# 未提交文件数量
git status --short | wc -l
```

## Step 3: 标准模式检查（无参数）

**代码质量**：
```bash
# ESLint 检查
pnpm lint 2>&1 | tail -5

# TODO/FIXME 统计
grep -r "TODO\|FIXME\|HACK\|XXX" apps/ --include="*.ts" --include="*.tsx" --include="*.py" | wc -l
```

**依赖健康**：
```bash
# 过时依赖
pnpm outdated 2>/dev/null | head -20

# 安全漏洞
pnpm audit --audit-level=high 2>&1 | tail -10
```

**文档同步**：
- CLAUDE.md 是否在 200 行以内？
- 技术栈版本是否与 package.json 一致？
- .claude/rules/ 路径是否仍然有效？
- docs/roadmap/ 是否存在？当前 Phase 文件是否与 CLAUDE.md 中的 `@` 引用一致？
- docs/specs/ 中是否有状态为"实施中"超过 2 周且无相关 commit 的 spec（视为 stale）？是否有状态为"已确认"但未开始实施的 spec？

## Step 4: Full 模式额外检查（--full）

```bash
# 前端构建
pnpm build:web 2>&1 | tail -5

# 测试覆盖率
pnpm test --coverage 2>&1 | tail -10
```

## Step 5: Security 模式（--security）

```bash
# 扫描硬编码密钥
grep -r "password\|secret\|api_key\|token" apps/ --include="*.ts" --include="*.py" \
  -i | grep -v "test\|spec\|example\|.env" | head -10

# .env 是否在 .gitignore
grep "^\.env" .gitignore || echo "⚠️ .env 可能未被忽略"
```

## Step 6: 输出审计报告

```
## 📋 项目审计报告

**时间**: [当前时间]
**模式**: [quick/标准/full/security/docs]

### 总览
| 维度 | 状态 | 说明 |
|------|------|------|
| 代码质量 | ✅/⚠️/❌ | [ESLint errors/warnings 数量] |
| 依赖健康 | ✅/⚠️/❌ | [过时依赖数] |
| 文档同步 | ✅/⚠️/❌ | [CLAUDE.md 行数] |
| Git 状态 | ✅/⚠️/❌ | [未提交文件数] |

### 🔴 需要立即处理
[列出 Critical 问题]

### 🟡 建议本周处理
[列出 Warning 问题]

### 🎯 行动建议（优先级排序）
1. [最重要的问题]
2. [次要问题]
```

</workflow>
````

---

### 4.2 /deep-audit — 全面深度审计

**文件路径**: `.claude/skills/deep-audit/SKILL.md`

````markdown
---
name: deep-audit
description: |
  全面深度审计，逐文件检查代码与文档一致性，自动修复并提交。
  Phase 完成后、大版本发布前使用。
argument-hint: "[--no-fix | --no-push]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
执行全面深度审计：扫描所有代码文件和文档，识别不一致，自动修复，提交变更。

**默认行为**：审计 → 修复 → 提交
**参数**：
- `--no-fix`: 仅审计报告，不修复
- `--no-push`: 修复并提交，但不推送
</task>

<workflow>

## Step 0: 初始化

```bash
AUDIT_DATE=$(date +%Y-%m-%d)
AUDIT_TIME=$(date +%H:%M)
echo "=== 深度审计开始 $AUDIT_DATE $AUDIT_TIME ==="
```

## Step 1: 代码结构全面扫描

扫描所有源文件，记录实际状态：

```bash
# 前端文件统计
find apps/web/src -name "*.tsx" -o -name "*.ts" | wc -l
find apps/web/src/components -name "*.tsx" | sort

# 后端文件统计
find apps/api -name "*.py" | wc -l

# 所有文档文件
find . -name "*.md" -not -path "*/node_modules/*" | sort
```

## Step 2: 文档系统检查

逐一读取并验证：

- `CLAUDE.md`：行数是否 < 200？内容是否准确？
- `.claude/rules/`：路径 glob 是否仍然匹配实际文件？
- `docs/roadmap/`：各 Phase 功能描述是否准确反映代码现状？README.md 进度统计是否正确？
- `docs/specs/`：各 spec 的设计描述是否仍然准确反映代码现状？状态是否正确（是否有"实施中"但功能已完成的 spec）？
- `docs/architecture/`：ADR 是否反映实际决策？
- `docs/development/`：部署文档和上手指南是否与代码同步？

## Step 3: 对比分析

**组件 vs 文档**：
- 实际组件数 vs 文档记录数
- 找出文档缺失的组件

**API 自动文档**：
- 检查 FastAPI `/docs` 或 springdoc `/swagger-ui` 是否正常可访问
- 检查 CLAUDE.md 中是否指明了 API 路由和数据模型的源码路径

**package.json vs CLAUDE.md**：
- 实际依赖版本 vs CLAUDE.md 声明的版本

## Step 4: 识别问题，按优先级分类

```
P0 - 严重（立即修复）:
1. CLAUDE.md 内容与代码不符（会让 Claude 理解错误）
2. 安全漏洞或硬编码密钥

P1 - 中等（今日修复）:
1. 文档缺失的组件/API
2. 版本声明不一致

P2 - 轻微（本周修复）:
1. 冗余文档内容
2. 过期的注释
```

## Step 5: 生成审计报告

写入 `docs/reports/deep-audit-$AUDIT_DATE.md`

## Step 6: 执行修复（除非 --no-fix）

按 P0 → P1 → P2 顺序修复：
- 更新 CLAUDE.md
- 更新 .claude/rules/
- 更新 docs/ 各文档

## Step 7: 提交（除非 --no-push）

```bash
git add .
git commit -m "docs: 深度审计与自动优化 $AUDIT_DATE

- 修复 P0 问题: [数量] 处
- 修复 P1 问题: [数量] 处
- 生成审计报告: docs/reports/deep-audit-$AUDIT_DATE.md

🤖 Generated with Claude Code"

# 如果没有 --no-push 参数
git push
```

## Step 8: 输出完成报告

```
═══════════════════════════════════
✅ 深度审计完成
═══════════════════════════════════

📊 扫描统计:
├── 代码文件: [X] 个
├── 文档文件: [X] 个
└── 检查项目: [X] 项

🔧 修复统计:
├── P0 严重: [X] 处 ✅
├── P1 中等: [X] 处 ✅
└── P2 轻微: [X] 处 ✅

📝 报告: docs/reports/deep-audit-$AUDIT_DATE.md
⏰ 下次建议: 下一个 Phase 完成后
═══════════════════════════════════
```

</workflow>
````

---

## 5. 新增的 Skills

### 5.1 /catchup — 上下文快速恢复

**用途**：执行 `/clear` 清空上下文后，快速重建工作状态，无需重新解释项目背景。

**文件路径**: `.claude/skills/catchup/SKILL.md`

````markdown
---
name: catchup
description: |
  执行 /clear 后快速恢复工作上下文。
  当用户说"重新开始"、"清空后需要继续"、"帮我恢复上下文"时使用。
argument-hint: ""
allowed-tools: Read, Bash, Glob
---

<task>
快速恢复工作上下文，让我们继续之前的工作。
</task>

<workflow>

## Step 0: 获取当前状态

```bash
echo "=== 当前状态 $(date '+%Y-%m-%d %H:%M') ==="
git log --oneline -5
echo "--- 修改的文件 ---"
git status --short
echo "--- 未推送 commit ---"
git log --oneline @{u}.. 2>/dev/null || echo "（无法获取，可能没有追踪分支）"
```

## Step 1: 读取关键文件

依次读取（按重要性）：
1. `CLAUDE.md`（项目规范）
2. `.claude/session-notes.md`（如果存在，是压缩前保存的进度）
3. `docs/roadmap/README.md`（如果存在，项目整体进度）
4. 当前 Phase 文件（从 README.md 中确定当前 Phase，读取对应文件）
5. `docs/specs/` 中状态为"实施中"或"已确认"的 spec 文件（如有，当前正在实施或待实施的设计文档）
6. 最近修改的源文件（`git diff HEAD~3 --name-only` 列出的文件）

## Step 2: 输出恢复摘要

```
✅ 上下文已恢复

## 项目: [项目名称]
**技术栈**: [从 CLAUDE.md 获取]

## 项目路线图
[当前 Phase 名称及进度，如："Phase 2 核心业务 3/5"]
[列出当前 Phase 中进行中和待办的条目]

## 当前设计文档
[如有状态为"实施中"或"已确认"的 spec，列出文件名和概要]

## 最近工作
[最近 5 个 commit 摘要]

## 修改中的文件
[git status --short 输出]

## 下一步建议
[根据 session-notes.md + 路线图当前 Phase 的待办项推断]

---
**准备好继续了。我们从哪里开始？**
```

</workflow>
````

---

### 5.2 /handoff — 会话交接文档

**用途**：关闭会话前生成结构化交接笔记，自动更新项目路线图进度，供下次会话快速恢复。

**文件路径**: `.claude/skills/handoff/SKILL.md`

````markdown
---
name: handoff
description: |
  会话结束前生成交接文档。当用户说"生成交接文档"、"我要关闭了"、"记录一下进度"时使用。
argument-hint: ""
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

<task>
提交当前所有变更，更新项目路线图进度，然后生成结构化会话交接文档。
</task>

<workflow>

## Step 0: 收集当前状态

```bash
echo "=== 会话信息 ==="
date '+%Y-%m-%d %H:%M'
git log --oneline -10
git status --short
git diff --stat HEAD 2>/dev/null | tail -5
```

## Step 1: 提交当前变更

检查是否有未提交的变更（`git status --short` 有输出）。

**如果有未提交文件**，按以下步骤处理：

1. 精确 stage 变更文件（不用 `git add .`）：
   - 读取 `git status --short` 输出，识别已修改和新增文件
   - 排除 `.env`、`*.log`、`node_modules/`、构建产物等
   - 执行 `git add <具体文件列表>`

2. 分析变更内容，生成符合 Conventional Commits 规范的 commit message，尝试正常提交：
   ```bash
   git commit -m "<type>(<scope>): <subject>"
   ```

3. 根据结果：
   - **成功** → 记录"正常 commit: `<message>`"，继续 Step 2
   - **失败（测试不通过，exit code 2）** → 降级为 WIP 提交：
     ```bash
     git commit --no-verify -m "wip: <简要描述当前开发状态>"
     ```
     记录"WIP commit: `wip: <描述>`"，继续 Step 2

**如果没有未提交文件** → 记录"无变更"，直接跳到 Step 2。

## Step 2: 更新项目路线图

检查 `docs/roadmap/` 目录是否存在。

**如果存在**：

1. 读取 `docs/roadmap/README.md` 确定当前 Phase
2. 读取当前 Phase 文件（如 `phase-2-核心业务.md`）
3. 根据本次会话完成的工作，**仅更新 checkbox 状态**：
   - 已完成的功能：`[ ]` → `[x] ✅ <日期>`
   - 开始进行中的功能：`[ ]` → `[-] 🏗️ <日期>`
4. 更新 README.md 中的进度统计（如 `2/5` → `3/5`）
5. 如果当前 Phase 全部完成，将状态改为 `✅ 完成`

**重要**：只更新状态，**不添加新功能条目**。新功能需用户在开发过程中明确要求添加。

**如果不存在** → 跳过此步骤。

**更新 Spec 状态**：检查 `docs/specs/` 中状态为"实施中"的 spec 文件。如果本次会话完成了 spec 中的全部功能，将状态更新为"已完成"。

**提交文档状态更新**：如果 Step 2 修改了 roadmap 或 spec 文件，单独提交：
```bash
git add docs/roadmap/ docs/specs/ 2>/dev/null
git commit -m "docs: 更新路线图和设计文档状态" 2>/dev/null || true
```

## Step 3: 生成交接文档

写入 `.claude/session-notes.md`：

```markdown
# 会话交接文档

**生成时间**: [当前时间]
**当前分支**: [git branch --show-current]

## 本次会话完成的工作

[总结这次会话完成了什么]

## 关键技术决策

[记录做了什么重要决策，为什么这样决定]

## 代码变更摘要

[git diff --stat HEAD 输出]

## 路线图进度

[当前 Phase 名称及进度，如："Phase 2 核心业务 3/5"]

## 设计文档状态

[如有活跃的 spec，注明文件名、状态和实施进度]

## 遗留问题 / 下次继续

[还没完成什么，下次从哪里接手]

## 注意事项

[有什么需要特别注意的，踩过的坑]

---
*下次会话运行 `/catchup` 恢复此上下文*
```

## Step 4: 确认

```
✅ 交接完成

提交状态: [正常 commit: <message> | WIP commit: wip: <描述> | 无变更]
路线图更新: [已更新 Phase X: N/M | 无 roadmap 目录，跳过]
交接文档: .claude/session-notes.md

下次会话运行 /catchup 可快速恢复上下文。
辛苦了！
```

</workflow>
````

---

### 5.3 /spec — 讨论成果整理为设计文档

**用途**：需求讨论、技术方案探讨、UI 设计讨论到一定程度后，将对话中的讨论成果整理为结构化设计文档，持久化到 `docs/specs/` 目录。支持增量更新（跨多次上下文持续完善同一份 spec）。

**v3.9 增强**：Spec 输出结构支持分阶段实施追踪——每个 Phase 包含 Tasks checklist、Gate 完成条件、完成触发动作，解决大 Spec 实施中途 auto-compact 后丢失进度的问题。

**文件路径**: `.claude/skills/spec/SKILL.md`

````markdown
---
name: spec
description: |
  将讨论成果整理为结构化设计文档。当需求讨论、技术方案探讨、UI 设计讨论到一定程度时使用。
  触发关键词：整理讨论、写 spec、保存设计、记录方案、整理成文档
argument-hint: "[功能名称]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
将当前对话中的讨论成果整理为结构化设计文档，写入 docs/specs/ 目录。
如果目标文件已存在，执行增量更新（合并新内容，保留已有内容）。

重点：输出的 spec 必须包含可追踪的实施计划（Implementation Phases），每个 Phase 独立可交付、独立可验证。
</task>

<workflow>

## Step 0: 确定文件名和模式

- 如果提供了参数（如 `/spec user-auth`），用参数作为文件名（kebab-case）
- 如果没有参数，根据讨论主题自动命名
- 检查 `docs/specs/<name>.md` 是否已存在：
  - **已存在** → 增量更新模式（读取现有内容，合并新讨论成果）
  - **不存在** → 新建模式

```bash
mkdir -p docs/specs
```

## Step 1: 收敛讨论成果

回顾当前对话，**先归纳共识与分歧**，再提取内容：

### 1a. 共识与分歧梳理

在整理前，先输出一段简要总结：

```
📋 讨论收敛总结：
✅ 已达成共识：[列出 2-5 条核心决定]
⚠️ 待确认/分歧：[列出尚未敲定的点，如有]
```

如有待确认项，询问用户是否现在确认，或标记为 draft 后续再定。

### 1b. 提取讨论内容

按需提取（不强制全部有）：

- 功能背景与目标
- 需求要点和验收标准
- 讨论过的方案及取舍理由
- 最终确定的设计方案
- UI/交互设计细节（页面布局、按钮功能、交互流程）
- API 设计（端点、请求/响应格式）
- 数据模型设计（表结构、字段、关系）
- 业务逻辑和处理流程
- 调研发现（联网搜索结果、技术选型依据）
- 约束条件和注意事项

## Step 2: 规划实施阶段

将功能拆分为 **2-5 个 Implementation Phases**，每个 Phase 必须满足：

- **独立可交付**：完成后有可验证的产出（不是"写了一半的模块"）
- **独立可验证**：有明确的 Gate 条件可以检查
- **上下文友好**：单个 Phase 的实施不超过一个上下文窗口（约 30 分钟人工等效工作量）

Phase 拆分原则：
- 数据层 → API 层 → UI 层（后端优先）
- 或按功能模块独立拆分（各模块无强依赖时）
- 简单功能（预估 < 30 分钟）可以只有 1 个 Phase

## Step 3: 写入/更新 Spec 文件

**新建模式** — 写入 `docs/specs/<name>.md`：

```markdown
---
title: [功能名称]
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
phase: phase-N
total_phases: 3
active_phase: 1
---

# [功能名称] 设计文档

## 背景与目标

[为什么要做这个功能，解决什么问题]

## 需求概要

[核心功能点，验收标准]

## 设计方案

### 讨论过的方案

[方案 A vs B vs C，各自优缺点，最终选择理由]

### 最终方案

[确定的技术/设计方案]

## 详细设计

（以下模块按需包含，没有的不写）

### UI/交互设计

[页面布局、组件、按钮功能、交互流程]

### API 设计

[端点列表、请求/响应格式]

### 数据模型

[表结构、字段、关系]

### 业务逻辑

[核心处理流程、边界情况、异常处理]

## 调研记录

[联网搜索发现的信息、参考资料、技术选型依据]

## 约束与注意事项

[性能要求、安全考虑、兼容性、已知限制]

## Implementation Phases

### Phase 1: [阶段名称，如"数据模型与迁移"]
**Tasks**:
- [ ] [具体任务 1]
- [ ] [具体任务 2]
- [ ] [具体任务 3]

**Gate（全部满足才算完成）**:
- [ ] 所有 Tasks 已勾选
- [ ] 相关测试通过
- [ ] 无 lint errors

**On Complete**: 更新 active_phase → 2，建议执行 /done

### Phase 2: [阶段名称，如"API 端点实现"]
**Tasks**:
- [ ] [具体任务 1]
- [ ] [具体任务 2]

**Gate**:
- [ ] 所有 Tasks 已勾选
- [ ] API 测试通过
- [ ] 与 Phase 1 集成验证通过

**On Complete**: 更新 active_phase → 3，建议执行 /done

### Phase 3: [阶段名称，如"前端 UI 集成"]
**Tasks**:
- [ ] [具体任务 1]
- [ ] [具体任务 2]

**Gate**:
- [ ] 所有 Tasks 已勾选
- [ ] 端到端测试通过
- [ ] UI 响应式检查通过

**On Complete**: 所有 Phase 完成，建议执行 /done + /release（如当前 Roadmap Phase 也完成）
```

**增量更新模式** — 读取已有文件，将新讨论成果合并到对应模块：
- 保留已有内容不删除
- 新增内容融入对应章节
- 更新 frontmatter 中的 `updated` 日期
- 如果讨论推翻了之前的结论，更新对应内容并在"讨论过的方案"中记录变更原因
- Implementation Phases 已完成的 Phase 保留 `[x]` 状态不动

## Step 4: 检查 ROADMAP 关联

如果 `docs/roadmap/` 存在：
- 检查当前 spec 对应的功能是否在 ROADMAP 中有对应条目
- 如有 → 在 spec 头部填写关联信息
- 如无 → 提示用户是否需要添加到 ROADMAP

## Step 5: 判断状态

根据讨论充分程度判断 frontmatter 中的 `status`：
- `draft`：讨论还在进行中，部分模块尚未确定
- `approved`：核心方案已确定，可以开始实施

如果用户明确说"确认"或"可以开始做了"，status 设为 `approved`。

**完整状态生命周期**：

```
draft → approved → implementing → implemented → [deprecated | superseded]
```

| status | 含义 | 转换时机 | 谁触发 |
|--------|------|---------|--------|
| `draft` | 讨论中 | `/spec` 首次生成 | `/spec` Skill |
| `approved` | 方案已确认 | 用户确认内容 OK | `/spec` Skill |
| `implementing` | 实施中 | 基于 spec 开始编码时 | Claude 自动更新 |
| `implemented` | 已完成 | 功能全部完成 | `/done` 或完成标准自动更新 |
| `deprecated` | 已弃用 | 技术/业务变化 | 手动更新 |
| `superseded` | 被替代 | 新 spec 取代 | 手动更新（在 frontmatter 中注明替代文件） |

## Step 6: 输出确认

```
✅ Spec 已生成/更新

文件：docs/specs/<name>.md
状态：草稿 / 已确认
实施阶段：[N] 个 Phase，当前 Phase [active_phase]
内容：需求 [N] 项、设计方案 [N] 个、API [N] 个、UI [N] 个页面、...
关联 ROADMAP：[有/无]

建议下一步：
- 继续讨论 → 讨论后再次 /spec 更新
- 开始实施 → /clear 后 "读取 docs/specs/<name>.md，开始实施 Phase 1"
  （每次只实施一个 Phase，完成 Gate 后再进入下一个）
- 确认内容 → 告诉我"确认"，状态改为"已确认"
```

</workflow>
````

---

### 5.4 /done — 智能收尾检查（v3.9 增强）

**用途**：功能或 Spec Phase 完成后，执行收尾检查。`/done` 会**自动检测完成粒度**——单个功能、Spec 某个 Phase、Spec 全部完成、Roadmap Phase 全部完成——根据粒度执行不同深度的收尾动作。

**v3.9 变化**：从"固定单功能收尾"升级为"三级自动升级"——一个命令覆盖所有完成粒度，用户不需要判断该用 `/done` 还是 `/release`。

**文件路径**: `.claude/skills/done/SKILL.md`

````markdown
---
name: done
description: |
  智能收尾检查。自动检测完成粒度（功能/Spec Phase/Spec 完成/Roadmap Phase 完成），
  执行对应深度的验证和文档同步。
  触发关键词：功能完成、收尾检查、done、wrap up、Phase 完成
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
智能收尾检查：自动检测完成粒度，执行对应深度的代码验证 + 文档同步 + 状态汇总。
</task>

<workflow>

## Step 0: 识别完成范围

- 查看最近的 git log 和 diff，确定刚完成了什么
- 如果用户提供了功能名称，以用户说明为准

```bash
git log --oneline -5
git diff --stat HEAD~3
```

## Step 1: 代码验证

运行项目的测试和 lint 命令（从 CLAUDE.md 的"完成标准"或"常用命令"中获取）：

```bash
# 示例（根据项目实际命令调整）
pnpm test
pnpm lint
```

检查项：
- [ ] 所有测试通过
- [ ] Lint 无 error
- [ ] 边界条件已考虑（空值、异常输入、权限不足）
- [ ] 改动不影响现有功能

## Step 2: Roadmap 更新

如果 `docs/roadmap/` 存在：

```bash
ls docs/roadmap/
```

- 找到当前功能对应的 Phase 文件
- 将对应的 checkbox 从 `- [ ]` 改为 `- [x] ✅ YYYY/MM/DD`
- 更新 `docs/roadmap/README.md` 中的进度统计

## Step 3: Spec 状态智能检测

如果 `docs/specs/` 存在，找到关联的 spec 文件：

```bash
# 查找状态为 implementing 的 spec
grep -rl "status: implementing" docs/specs/ 2>/dev/null
```

读取 spec 文件，检查 Implementation Phases 的完成情况：

### 情况 A：Spec 有 Implementation Phases（v3.9 结构）

检查当前 `active_phase` 对应的 Phase：
- 所有 Tasks 是否已勾 `[x]`？
- Gate 条件是否全部满足？

**如果当前 Phase 的 Gate 通过**：
1. 更新 spec frontmatter 的 `active_phase` → 下一个 Phase
2. 检查是否所有 Phase 都已完成（`active_phase` > `total_phases`）
   - **否（还有后续 Phase）** → 记录"Spec Phase N 完成，进入 Phase N+1"
   - **是（Spec 全部完成）** → 进入 Step 3b

### 情况 B：Spec 无 Implementation Phases（旧结构）

直接进入 Step 3b（视为整体完成）

### Step 3b: Spec 完全完成时的额外动作

当 Spec 的所有 Phase 完成（或无 Phase 的 spec 功能完成）时：
1. 将 frontmatter `status` 从 `implementing` 更新为 `implemented`
2. 更新 `updated` 日期
3. 扫描该 Spec 涉及的所有代码变更，检测是否有：
   - 部署/配置变更 → 提示更新 deployment.md
   - 新增依赖/启动步骤 → 提示检查 getting-started.md
   - 新技术选型 → 提示是否需要新增 ADR

## Step 4: 开发文档检测

检测本次改动是否涉及部署/配置变更：

```bash
# 检测配置/环境/部署变更
git diff --stat HEAD~3 -- '**/.env*' '**/docker*' '**/deploy*' '**/Dockerfile*' '**/nginx*' '**/ci*' '**/cd*'
```

如果 `docs/development/deployment.md` 存在且检测到变更：
- 提示："检测到部署/配置变更，建议更新 `docs/development/deployment.md`，是否现在更新？"
- 用户确认后执行增量更新
- 用户拒绝则跳过（不阻断流程）

> 注意：API 文档和数据库文档不需要手动维护 — FastAPI/Spring Boot 自动生成 API 文档，ORM 模型定义本身就是数据库文档。此步骤仅关注代码中无法自动体现的部署信息。

## Step 5: 代码审查

运行 `/simplify` 进行三维并行审查（如果本次还未运行过）。

## Step 6: Roadmap Phase 完成检测

检查当前 Roadmap Phase 的所有功能是否都已完成（所有 checkbox 已勾选）：

- **否** → 记录"Roadmap Phase N 还剩 [M] 个功能未完成"
- **是** → 建议执行 `/release` 进行全量文档刷新

> `/done` 只**建议** `/release`，不自动执行。`/release` 涉及全量文档扫描和 Changelog 生成，应由用户主动触发。

## Step 7: 提交文档变更

如果 Step 2-4 产生了文档更新：

```bash
git add docs/
git commit -m "docs: 更新 [功能名/spec名] 的 roadmap、spec 状态和开发文档"
```

## Step 8: 输出状态汇总

根据检测到的完成粒度，输出对应的汇总：

**单功能 / Spec 单个 Phase 完成**：
```
✅ 功能收尾完成

功能：[功能名称]
代码验证：✅ 测试通过 | ✅ Lint 通过
Roadmap：✅ Phase N — [条目] 已勾选 / ⏭️ 无关联条目
Spec：✅ Phase [M/N] 完成，进入 Phase [M+1] / ⏭️ 无关联 Spec
代码审查：✅ /simplify 已执行 / ⏭️ 之前已执行

下一步：继续实施 Spec Phase [M+1] / 继续下一个功能
```

**Spec 全部完成**：
```
🎉 Spec 全部完成

Spec：[spec名].md → implemented ✅
代码验证：✅ 测试通过 | ✅ Lint 通过
Roadmap：✅ Phase N — [条目] 已勾选
部署文档：✅ 已更新 / ⏭️ 无需更新 / ⚠️ 建议更新
代码审查：✅ /simplify 已执行

Roadmap Phase 状态：还剩 [M] 个功能 / 🎯 全部完成，建议执行 /release
```

**Roadmap Phase 也全部完成**：
```
🎉 Roadmap Phase N 全部完成！

所有功能已完成，所有 Spec 已 implemented。
建议执行 /release 进行全量文档刷新（部署/上手指南/Changelog/ADR）。
```

</workflow>
````

**自动 vs 手动**：

| 方式 | 触发 | 覆盖内容 |
|------|------|---------|
| **自动**（推荐） | CLAUDE.md 完成标准，Claude 报告"功能完成"前自动执行 | 代码验证 + 文档同步 + Spec Phase 勾选 |
| **手动** `/done` | 用户显式调用 | 完整检查（含 /simplify 审查 + Spec 完成度检测 + Roadmap Phase 检测 + 状态汇总） |

**三级自动升级**：用户只需执行 `/done`，Skill 自动判断完成粒度并执行对应动作：

| 检测到的完成粒度 | `/done` 自动做的事 |
|-----------------|-------------------|
| **Spec 单个 Phase** | 更新 active_phase，基础验证 |
| **Spec 全部完成** | 上述 + status→implemented + 开发文档检测 + ADR 检查 |
| **Roadmap Phase 完成** | 上述 + 建议执行 `/release` |

---

### 5.5 /release — Phase 完成文档刷新

**用途**：一个 Phase 的所有功能完成后，全量扫描代码变更，自动刷新开发文档（部署、上手指南），生成 Changelog 条目，更新 Roadmap Phase 状态，检查是否需要新增 ADR。

**文件路径**: `.claude/skills/release/SKILL.md`

````markdown
---
name: release
description: |
  Phase 完成文档刷新。全量更新开发文档（部署/上手指南），生成 Changelog，更新 Phase 状态。
  触发关键词：release、发版、Phase 完成、阶段完成、全量文档刷新
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
Phase 完成后的全量文档刷新：扫描所有代码变更，自动更新开发文档，生成 Changelog，更新 Roadmap Phase 状态。
</task>

<workflow>

## Step 0: 确认 Phase 范围

- 查看 `docs/roadmap/README.md` 确认当前 Phase
- 查看当前 Phase 文件，确认所有功能是否已完成（所有 checkbox 已勾选）
- 如有未完成的功能条目，提醒用户确认是否继续

```bash
cat docs/roadmap/README.md
ls docs/roadmap/
```

## Step 1: 分析 Phase 变更范围

使用 Explore Subagent 全面扫描当前 Phase 期间的所有变更：

```bash
# 查看 Phase 期间的所有提交
git log --oneline --since="[Phase 开始日期]"

# 分析变更涉及的文件类型
git diff --stat [Phase 起始 commit]..HEAD
```

分类整理：
- **配置变更**：新增/修改了哪些环境变量、部署配置
- **依赖变更**：新增/升级/移除了哪些依赖
- **架构变更**：是否有重大架构决策

> 注意：API 接口和数据库结构不需要手动维护文档 — FastAPI/Spring Boot 自动生成 API 文档，ORM 模型定义本身就是数据库文档。

## Step 2: 更新部署文档

如果有配置/部署变更且 `docs/development/deployment.md` 存在：

- 更新环境变量列表
- 更新部署流程（如有变化）
- 更新依赖版本要求

## Step 3: 更新上手指南

如果 `docs/development/getting-started.md` 存在：

- 检查环境要求是否仍然准确（对照 package.json / pyproject.toml）
- 检查首次运行步骤是否需要更新（新增的初始化步骤）
- 更新项目结构概览（如有新增目录）

## Step 4: 生成 Changelog

更新 `docs/development/changelog.md`（如不存在则新建）：

```bash
# 收集 Phase 期间的所有功能性提交
git log --oneline --no-merges --since="[Phase 开始日期]" | grep -E "^[a-f0-9]+ (feat|fix|perf|refactor)"
```

按 [Keep a Changelog](https://keepachangelog.com/) 格式生成：
- **Added**: feat 类型的提交
- **Fixed**: fix 类型的提交
- **Changed**: refactor/perf 类型的提交
- **Removed**: 删除功能的提交

## Step 5: 检查 ADR

检查本 Phase 是否有需要记录的架构决策：

- 是否引入了新的技术栈组件
- 是否有重大架构重构
- 是否有技术选型变更

如有，提示用户："检测到 [变更描述]，建议新增 ADR，是否创建？"
用户确认后，按 ADR 模板在 `docs/architecture/adr/` 中新建。

## Step 6: 更新 Roadmap Phase 状态

```bash
# 将当前 Phase 文件中的所有 checkbox 状态确认
# 更新 docs/roadmap/README.md 中的 Phase 状态为 "✅ 完成"
# 更新进度统计
```

## Step 7: 提交所有文档变更

```bash
git add docs/
git commit -m "docs: Phase N [Phase名称] 完成 — 全量更新开发文档"
```

## Step 8: 输出 Release 报告

```
🎉 Phase N [Phase名称] 文档刷新完成

文档更新摘要：
- 部署文档：✅ 新增 N 个环境变量 / ⏭️ 无变更
- 上手指南：✅ 已更新 / ⏭️ 无需更新
- Changelog：✅ 新增 [版本号] 条目
- ADR：✅ 新增 N 条 / ⏭️ 无需新增
- Roadmap：✅ Phase N 标记为完成

下一步建议：
- git push 推送文档更新
- /deep-audit 全面代码审计
- 开始规划 Phase N+1
```

</workflow>
````

---

### 5.6 /nbp2 — AI 生图 Prompt 助手（Nano Banana Pro 2）

**用途**：帮助编写针对 Google Nano Banana Pro / Nano Banana 2 优化的高质量图片生成 Prompt。不同 AI 生图模型有不同的 prompt 写法，此 Skill 内嵌 NBP2 最佳实践，直接输出可用 prompt。

**文件路径**: `.claude/skills/nbp2/SKILL.md`

````markdown
---
name: nbp2
description: |
  帮助用户编写 Nano Banana Pro / Nano Banana 2 AI 生图 Prompt。
  当用户需要生成图片、写图片 prompt、使用 Nano Banana、NBP2、Gemini 生图时自动触发。
  触发关键词：生图、图片 prompt、Nano Banana、NBP2、AI 生图、image prompt
argument-hint: "[图片描述 或 场景需求]"
allowed-tools: Read, Bash
---

<task>
根据用户的描述需求，生成针对 Nano Banana Pro 2（Google Gemini 图像生成模型）优化的高质量 Prompt。
</task>

<context>

## Nano Banana 模型概览

| 特性 | Nano Banana Pro (Gemini 3 Pro) | Nano Banana 2 (Gemini 3.1 Flash) |
|------|-------------------------------|----------------------------------|
| 速度 (1K) | 10-20 秒 | 4-6 秒 |
| 价格/张 | ~$0.15 | ~$0.08 |
| 质量 | 最佳 | Pro 的 ~95% |
| Image Search Grounding | 无 | 有（可检索真实参考图） |
| Thinking Mode | 有 | 有（Minimal/High/Dynamic） |
| 角色一致性 | 强 | 最多 5 角色、14 对象/工作流 |
| Model ID | gemini-3-pro-image | gemini-3.1-flash-image-preview |

## 核心差异 — 工作流策略

- **Pro**：精雕细琢单个 prompt，追求一次到位的最高品质
- **Nano Banana 2**：快速起步 → 迭代精修（速度优势支撑多轮对话式调整）

</context>

<workflow>

## Step 1: 理解用户需求

询问或从 `$ARGUMENTS` 中提取：
1. **画面主题** — 要画什么？
2. **用途场景** — 社交媒体封面？产品图？海报？个人创作？
3. **目标模型** — 用 Pro（最高品质）还是 NBP2（快速迭代）？默认 NBP2
4. **特殊要求** — 需要文字渲染？角色一致性？真实地标？

## Step 2: 按六要素公式构建 Prompt

按以下顺序组织（越前面权重越高）：

### 公式：`[主体] + [动作/关系] + [场景/环境] + [构图/镜头] + [风格/介质] + [光线]`

### 各要素详解

**1. 主体 (Subject)** — 最重要
- 具体描述：数量、年龄、材质、形状、服装
- 差：`a woman in a red dress`
- 好：`a sophisticated elderly woman wearing a vintage Chanel-style tweed suit, silver hair in a French twist`

**2. 动作与关系 (Action & Relationships)**
- 主体在做什么，与其他元素的交互
- 例：`reading a leather-bound book while her cat sleeps on the armrest beside her`

**3. 场景/环境 (Setting / Location)**
- 地点、时间、天气、氛围
- 例：`in a sunlit Parisian apartment with tall windows overlooking autumn chestnut trees, late afternoon`

**4. 构图/镜头 (Composition / Camera)**
- 镜头角度、焦距、景深、取景
- 关键术语：`low angle` / `aerial view` / `close-up` / `wide shot` / `over-the-shoulder`
- 镜头：`50mm portrait lens` / `macro at f/8` / `35mm wide angle`
- 例：`medium shot, 85mm lens at f/2.8, shallow depth of field with soft bokeh`

**5. 风格/介质 (Style & Medium)**
- 摄影 / 插画 / 3D / 水彩 / 像素风 / 油画 ...
- 时代风格：`1960s aesthetic`（自动暗示胶片颗粒和褪色调色板）
- 例：`film photography style inspired by Kodak Portra 400, warm tones, subtle grain`

**6. 光线 (Lighting)**
- 主光源位置、阴影行为、雾感/光晕
- 例：`soft key light from camera-left, subtle rim light on shoulders, faint atmospheric haze`

## Step 3: 应用进阶技巧

### 文字渲染
- 精确文字必须用引号包裹：`with the text "MIDNIGHT REVERIE" in bold art deco typography`
- 指定字体风格：`bold sans-serif` / `handwritten script` / `retro neon sign`
- 多语言支持：可指定 10+ 种语言

### 负面约束（抑制不想要的元素）
- 在 prompt 末尾添加：`no text, no watermark, no extra limbs, no deformed hands, clean framing`
- 如果不要文字：`clean image without any typography or text overlays`
- 通用安全负面约束：`no low quality, no blurry, no grain, no watermark, no bad anatomy, no extra fingers, no cluttered background`

### 角色一致性（多图工作流）
- 先生成角色设定图（多角度）：`Generate a character reference sheet showing front, profile, and three-quarter views of [character description]`
- 后续引用：`Using the character from @img1, place them in [new scene], maintaining the same outfit and facial features`
- NBP2 最多支持 5 角色 + 14 对象

### Image Search Grounding（仅 NBP2）
- 用于真实地标/名人/品牌/实时数据
- 触发词：`search for` / `latest` / `current` / `real-time`
- 例：`Use image search to find accurate reference of the Sydney Opera House. Create a cinematic 3:2 photo of it at golden hour with dramatic clouds`

### Thinking Mode
- 适合复杂构图、需要推理的场景
- 通过 API 参数 `include_thoughts` 启用
- 成本增加约 20-40%，但质量显著提升

## Step 4: 输出格式

向用户提供：

```
## NBP2 Prompt

**目标模型**: [Pro / Nano Banana 2]
**建议分辨率**: [如 1024x1024, 1920x1080, 等]

### Prompt

[完整的英文 prompt，自然语言描述，不是标签堆叠]

### Negative Constraints

[负面约束，逗号分隔]

### 调优建议

- [针对该场景的 1-3 条调整建议]
```

</workflow>

<rules>

## 关键规则

1. **自然语言，不是标签堆叠** — 用完整句子和正确语法描述画面，不要 `dog, park, 4k, realistic, HDR` 这种旧式标签
2. **Prompt 用英文** — Nano Banana 对英文 prompt 效果最好，即使用户用中文描述需求，输出的 prompt 也用英文
3. **具体胜过模糊** — `a 30-year-old woman with freckles and warm brown hair` 远优于 `a beautiful woman`
4. **避免矛盾** — 不要同时要求 `bright sunlight` 和 `dark moody shadows`
5. **顺序即权重** — 最重要的描述放最前面
6. **Pro vs NBP2 策略不同**：
   - Pro：写一个精确详尽的 prompt
   - NBP2：先写简短 prompt 锁定方向，再迭代精修
7. **文字必须引号包裹** — 需要渲染的文字用双引号标注
8. **如用户未指定模型，默认推荐 NBP2** — 性价比更高，速度更快，支持 Image Search Grounding

</rules>

<examples>

## 示例 Prompt

### 产品摄影
```
A luxury wristwatch with silver metal band and black face showing 10:10 time,
reflective polished surface. High-end product photography, commercial advertising
aesthetic, shot on Phase One XF. Macro lens at f/8 for sharp detail, controlled
studio lighting with softbox from above and reflector cards bouncing light onto
the watch face, dramatic shadows underneath. Horizontal composition, watch centered
on white seamless background with slight angle to show depth and dimension.
No text, no watermark, clean framing.
```

### 电影感场景
```
A cinematic wide shot of a futuristic sports car speeding through a rainy Tokyo
street at night, neon reflections on wet asphalt, motion blur on background lights,
shot from a low angle, moody cyberpunk atmosphere. Anamorphic lens flare,
teal and orange color grading, 35mm film grain.
No text, no logos, no extra vehicles blocking the subject.
```

### 杂志封面（含文字）
```
A glossy fashion magazine cover featuring a confident young woman with short
platinum blonde hair, wearing an oversized blazer in electric blue, shot against
a minimalist coral background. The bold title "VANGUARD" in large uppercase
serif typography at the top, "Spring Collection 2026" in smaller elegant type
below. Studio lighting with beauty dish, catchlights in eyes, high-fashion
editorial style. Clean layout, no clutter.
```

### 等距场景
```
A perfectly isometric captured photograph of a beautiful modern rooftop garden.
Features a 2-shaped swimming pool with turquoise water, surrounded by lush
tropical plants, wooden deck chairs, and string lights. Golden hour lighting
casting long shadows, photorealistic style. The text "PARADISE" in clean
white sans-serif at the bottom right corner.
No tilt-shift blur, no miniature effect.
```

### 艺术/混合媒介
```
An everyday scene at a busy morning cafe. In the foreground, an anime-style
man with electric blue hair drinks espresso, next to a woman rendered as a
detailed pencil sketch, and a third patron as a claymation figure. The cafe
environment itself is photorealistic with warm ambient lighting, steam rising
from coffee cups, and rain visible through the window.
No watermark, no text overlays.
```

</examples>
````

---

## 6. Anthropic 内置命令（Bundled Skills）

Claude Code 2.x 内置了五个由 Anthropic 维护的 bundled 命令，随版本自动更新，**无需手动配置，直接使用**。

### 6.1 /simplify — 代码简化审查

**何时用**：功能实现完成后、提 PR 前，对本次改动做三维并行审查并自动修复。

```bash
/simplify                    # 审查所有近期改动
/simplify "focus on auth module"   # 聚焦指定范围
```

**内部机制**：同时启动 3 个并行 agent：
- **Code Reuse agent**：扫描重复模式，提取公共逻辑
- **Code Quality agent**：变量命名、函数拆分、控制流清晰度
- **Efficiency agent**：冗余循环、不必要的内存分配、可批处理的操作

每个 agent 独立分析，汇总后一次性应用修复。实践中平均每个 feature branch 发现 3-5 个问题。

> **推荐习惯**：每次 PR 前必跑 /simplify，它是你的第一道 code review。

---

### 6.2 /batch — 大规模并行变更

**何时用**：需要对整个代码库做统一变更时（替换库、重命名、统一格式等）。

```bash
/batch "将所有 moment.js 替换为 dayjs，更新 API 调用语法"
/batch "为所有 API 端点添加 OpenAPI 注释"
```

**执行流程**：
1. 分析代码库，将任务分解为 5-30 个独立单元
2. 展示分解计划，**等你确认**
3. 为每个单元启动独立 agent，每个 agent 在独立 git worktree 中工作
4. 每个 agent 完成后自动运行 `/simplify` 再提交
5. 每个单元各自创建 PR

> **重要**：描述要具体。"更新代码库"太模糊；"将所有 moment.js 替换为 dayjs，更新 `.format()` 和 `.diff()` 的调用语法" 才能让 planner 准确分解。

---

### 6.3 /debug — 交互式调试助手

**何时用**：遇到难以定位的 Bug 时，让 Claude 引导你逐步调试。

```bash
/debug                         # 从当前错误开始调试
/debug "TypeError in auth flow" # 指定问题描述
```

**内部机制**：Claude 会引导你设置断点、分析堆栈跟踪、检查变量状态，逐步缩小问题范围直到定位根因。

---

### 6.4 /loop — 定时重复执行

**何时用**：需要定期检查状态或重复执行任务时。

```bash
/loop 5m /audit --quick        # 每 5 分钟跑一次快速审查
/loop 10m "检查 CI 状态"       # 每 10 分钟检查 CI
```

**限制**：默认间隔 10 分钟，最长运行 3 天，上限 50 个任务。

---

### 6.5 /claude-api — Claude API 集成指导

**何时用**：项目中需要使用 Claude API 或 Anthropic SDK 时。

```bash
/claude-api                    # 获取 API 集成指导
```

**内部机制**：提供 Claude API 的最佳实践、SDK 用法、Tool Use 配置等专业指导。

---

### 区分 Bundled 命令 vs 自定义 Skills

| 维度 | Bundled（/simplify /batch /debug /loop /claude-api） | 自定义 Skills |
|------|---------------------------|--------------|
| 维护方 | Anthropic（随版本更新） | 你自己 |
| 配置位置 | 无需配置，内置 | `.claude/skills/*/SKILL.md` |
| 内部能力 | 可访问内部 API | 仅标准工具 |
| 适合场景 | 代码质量、批量变更 | 项目特定工作流 |

---

## 7. 安装说明

### 7.1 目录结构

```bash
# 创建 Skills 目录
mkdir -p .claude/skills/audit
mkdir -p .claude/skills/deep-audit
mkdir -p .claude/skills/catchup
mkdir -p .claude/skills/handoff
mkdir -p .claude/skills/spec
mkdir -p .claude/skills/done
mkdir -p .claude/skills/release
mkdir -p .claude/skills/nbp2
```

### 7.2 文件创建

将上述各 Skill 内容分别写入：
- `.claude/skills/audit/SKILL.md`
- `.claude/skills/deep-audit/SKILL.md`
- `.claude/skills/catchup/SKILL.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/spec/SKILL.md`
- `.claude/skills/done/SKILL.md`
- `.claude/skills/release/SKILL.md`
- `.claude/skills/nbp2/SKILL.md`

### 7.3 查看已安装的 Skills

```bash
# Claude Code 内部命令
/skills         # 列出所有可用 Skills
```

### 7.4 使用方式

```bash
/audit              # 标准健康检查
/audit --quick      # 快速检查
/audit --security   # 安全扫描（上线前）
/audit --full       # 完整检查（大版本后）

/deep-audit         # 全面深度审计（Phase 完成后）
/deep-audit --no-fix    # 仅生成报告

/catchup            # 清空上下文后恢复
/handoff            # 会话结束前生成交接文档

/spec               # 将讨论成果整理为设计文档
/spec user-auth     # 指定功能名称

/done               # 功能完成收尾检查（手动兜底）

/release            # Phase 完成文档刷新

/nbp2               # AI 生图 Prompt 助手
/nbp2 一只猫在雨中的东京街头   # 指定描述
```

### 7.5 旧 commands/ 迁移

如果有旧版 `.claude/commands/` 文件：

```bash
# 旧文件仍然有效，可以先保留
# 等迁移到 Skills 格式后再删除
ls .claude/commands/

# 确认新 Skills 工作正常后清理
rm -rf .claude/commands/
```

---

**版本**: v3.10
**更新日期**: 2026-03
