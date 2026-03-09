# Skills 命令配置指南

> Slash Commands 的进化版 — 更强大的自定义工作流命令

**版本**: v3.6
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

```markdown
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
```

---

### 4.2 /deep-audit — 全面深度审计

**文件路径**: `.claude/skills/deep-audit/SKILL.md`

```markdown
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
- `docs/development/`：API 文档是否与代码同步？

## Step 3: 对比分析

**组件 vs 文档**：
- 实际组件数 vs 文档记录数
- 找出文档缺失的组件

**API vs 文档**：
- 实际 API 端点（扫描 router 文件）vs api.md 记录
- 找出文档缺失的端点

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
```

---

## 5. 新增的 Skills

### 5.1 /catchup — 上下文快速恢复

**用途**：执行 `/clear` 清空上下文后，快速重建工作状态，无需重新解释项目背景。

**文件路径**: `.claude/skills/catchup/SKILL.md`

```markdown
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
```

---

### 5.2 /handoff — 会话交接文档

**用途**：关闭会话前生成结构化交接笔记，自动更新项目路线图进度，供下次会话快速恢复。

**文件路径**: `.claude/skills/handoff/SKILL.md`

```markdown
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
```

---

### 5.3 /spec — 讨论成果整理为设计文档

**用途**：需求讨论、技术方案探讨、UI 设计讨论到一定程度后，将对话中的讨论成果整理为结构化设计文档，持久化到 `docs/specs/` 目录。支持增量更新（跨多次上下文持续完善同一份 spec）。

**文件路径**: `.claude/skills/spec/SKILL.md`

```markdown
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

## Step 1: 提取讨论成果

回顾当前对话，提取以下内容（按需包含，不强制全部有）：

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
- 实施建议（开发顺序、依赖关系、风险点）

## Step 2: 写入/更新 Spec 文件

**新建模式** — 写入 `docs/specs/<name>.md`：

```markdown
---
title: [功能名称]
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
phase: phase-N
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

## 实施备注

[开发顺序建议、依赖关系、风险点]
```

**增量更新模式** — 读取已有文件，将新讨论成果合并到对应模块：
- 保留已有内容不删除
- 新增内容融入对应章节
- 更新 frontmatter 中的 `updated` 日期
- 如果讨论推翻了之前的结论，更新对应内容并在"讨论过的方案"中记录变更原因

## Step 3: 检查 ROADMAP 关联

如果 `docs/roadmap/` 存在：
- 检查当前 spec 对应的功能是否在 ROADMAP 中有对应条目
- 如有 → 在 spec 头部填写关联信息
- 如无 → 提示用户是否需要添加到 ROADMAP

## Step 4: 判断状态

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

## Step 5: 输出确认

```
✅ Spec 已生成/更新

文件：docs/specs/<name>.md
状态：草稿 / 已确认
内容：需求 [N] 项、设计方案 [N] 个、API [N] 个、UI [N] 个页面、...
关联 ROADMAP：[有/无]

建议下一步：
- 继续讨论 → 讨论后再次 /spec 更新
- 开始实施 → /clear 后 "读取 docs/specs/<name>.md，开始实施"
- 确认内容 → 告诉我"确认"，状态改为"已确认"
```

</workflow>
```

---

### 5.4 /done — 功能完成收尾

**用途**：一个功能开发完成后，执行完整的收尾检查：验证代码质量、同步文档状态（Roadmap + Spec）、确认无遗漏。大多数情况下，完成标准会自动执行这些动作；`/done` 作为手动兜底，偶尔执行以确保没有遗漏。

**文件路径**: `.claude/skills/done/SKILL.md`

```markdown
---
name: done
description: |
  功能完成收尾检查。验证代码质量，同步文档状态（Roadmap + Spec），确认无遗漏。
  触发关键词：功能完成、收尾检查、done、wrap up
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
对刚完成的功能执行完整的收尾检查：代码验证 + 文档同步 + 状态汇总。
</task>

<workflow>

## Step 0: 识别刚完成的功能

- 查看最近的 git log 和 diff，确定刚完成了什么功能
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

## Step 3: Spec 状态更新

如果 `docs/specs/` 存在：

```bash
ls docs/specs/
```

- 找到与当前功能关联的 spec 文件
- 将 frontmatter 中的 `status` 从 `implementing` 更新为 `implemented`
- 更新 `updated` 日期

## Step 4: 代码审查

运行 `/simplify` 进行三维并行审查（如果本次还未运行过）。

## Step 5: 提交文档变更

如果 Step 2-3 产生了文档更新：

```bash
git add docs/roadmap/ docs/specs/
git commit -m "docs: 更新 [功能名] 的 roadmap 和 spec 状态"
```

## Step 6: 输出状态汇总

```
✅ 功能收尾完成

功能：[功能名称]
代码验证：✅ 测试通过 | ✅ Lint 通过
Roadmap：✅ Phase N — [条目] 已勾选 / ⏭️ 无关联条目
Spec：✅ [spec名].md → implemented / ⏭️ 无关联 Spec
代码审查：✅ /simplify 已执行 / ⏭️ 之前已执行

下一步建议：
- 继续下一个功能
- git push 推送到远程
- /deep-audit（如果当前 Phase 接近完成）
```

</workflow>
```

**自动 vs 手动**：

| 方式 | 触发 | 覆盖内容 |
|------|------|---------|
| **自动**（推荐） | CLAUDE.md 完成标准，Claude 报告"功能完成"前自动执行 | 代码验证 + 文档同步 |
| **手动** `/done` | 用户显式调用 | 完整检查（含 /simplify 审查 + 状态汇总） |

日常开发中，完成标准驱动 Claude 自动完成文档同步。`/done` 用于阶段性核查，确保没有遗漏。

---

## 6. Anthropic 内置命令（Bundled Skills）

Claude Code 2.x 内置了两个由 Anthropic 维护的 bundled 命令，随版本自动更新，**无需手动配置，直接使用**。

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

### 区分 Bundled 命令 vs 自定义 Skills

| 维度 | Bundled（/simplify /batch） | 自定义 Skills |
|------|---------------------------|--------------|
| 维护方 | Anthropic（随版本更新） | 你自己 |
| 配置位置 | 无需配置，内置 | `.claude/skills/*/SKILL.md` |
| 内部能力 | 可访问内部 API | 仅标准工具 |
| 适合场景 | 代码质量、批量变更 | 项目特定工作流 |

---

## 7. 安装说明

### 6.1 目录结构

```bash
# 创建 Skills 目录
mkdir -p .claude/skills/audit
mkdir -p .claude/skills/deep-audit
mkdir -p .claude/skills/catchup
mkdir -p .claude/skills/handoff
mkdir -p .claude/skills/spec
mkdir -p .claude/skills/done
```

### 6.2 文件创建

将上述各 Skill 内容分别写入：
- `.claude/skills/audit/SKILL.md`
- `.claude/skills/deep-audit/SKILL.md`
- `.claude/skills/catchup/SKILL.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/spec/SKILL.md`
- `.claude/skills/done/SKILL.md`

### 6.3 查看已安装的 Skills

```bash
# Claude Code 内部命令
/skills         # 列出所有可用 Skills
```

### 6.4 使用方式

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
```

### 6.5 旧 commands/ 迁移

如果有旧版 `.claude/commands/` 文件：

```bash
# 旧文件仍然有效，可以先保留
# 等迁移到 Skills 格式后再删除
ls .claude/commands/

# 确认新 Skills 工作正常后清理
rm -rf .claude/commands/
```

---

**版本**: v3.6
**更新日期**: 2026-03
