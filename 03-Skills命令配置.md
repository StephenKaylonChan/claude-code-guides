# Skills 命令配置指南

> Claude Code 自定义工作流命令系统

**版本**: v3.21
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [Frontmatter 字段参考](#1-frontmatter-字段参考)
2. [自定义 Skills](#2-自定义-skills)
3. [Anthropic 内置命令（Bundled Skills）](#3-anthropic-内置命令bundled-skills)
4. [安装说明](#4-安装说明)


---

## 1. Frontmatter 字段参考

### SKILL.md 原生字段

```yaml
---
name: skill-name                      # 斜杠命令名称（max 64 字符，小写+数字+连字符）
description: |                        # Claude 自动检测触发的描述（max 1024 字符，超过 250 字符在列表中截断）
  当用户需要做 X 时使用此命令。
  触发关键词：X、Y、Z
argument-hint: "[参数说明]"           # 命令行自动补全提示
allowed-tools: Read, Grep, Bash       # 免确认工具（注意：不是限制可用，其他工具仍可调用但需确认）
model: haiku                          # 模型覆盖（haiku/sonnet/opus/inherit）
effort: medium                        # 思考深度覆盖（low/medium/high/max）
context: fork                         # fork = 在隔离子代理中运行
agent: Explore                        # 搭配 context:fork，指定子代理类型
disable-model-invocation: false       # true = 只能用户触发，Claude 不能自动调用
user-invocable: true                  # false = 隐藏，只能 Claude 内部调用
paths:                                # 限定自动激活的文件路径 glob
  - "apps/web/**/*.tsx"
shell: bash                           # 控制 !command 的 shell（bash/powershell）
hooks:                                # Skill 作用域内的 Hooks（详见文档 02 Section 6.3）
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/check.sh"
---
```

> **`allowed-tools` 含义**：不是"限制 Skill 只能用这些工具"，而是"这些工具免确认"。Skill 仍然可以调用其他工具，只是需要用户确认。

### Subagent 配置字段

以下字段属于 **Subagent（子代理，`.claude/agents/`）** 配置，不是 SKILL.md 原生字段。在 `context: fork` 的 Skill 中也可使用部分：

| 字段 | 用途 | 说明 |
|------|------|------|
| `memory` | 跨会话记忆 | `user`/`project`/`local`，运行结束后持久化 |
| `maxTurns` | 限制代理轮次 | 防止无限循环 |
| `permissionMode` | 权限模式 | `plan` = 只分析不修改，适合审查类 |
| `disallowed-tools` | 工具黑名单 | 禁止特定工具 |
| `mcpServers` | MCP 服务器限定 | 只有列出的 MCP 可用 |
| `skills` | 预加载 Skills | 注入子代理上下文 |
| `isolation` | 声明式 Worktree 隔离 | `worktree` = 在独立 worktree 中运行 |
| `background` | 后台运行 | `true` = 始终后台 |

### Skill 内容生命周期

- Skill 调用后以**单条消息**进入对话，整个会话期间**不会重新读取**
- Auto-compaction 保留最近调用的每个 Skill 前 **5,000 tokens**，总共 **25,000 tokens** 预算
- 旧的 Skill 可能在 compaction 后被完全丢弃——如果 Skill 似乎失效，重新调用即可恢复

### 动态变量

| 变量 | 说明 |
|------|------|
| `$ARGUMENTS` / `$1` `$2` | 用户传入的参数 |
| `${CLAUDE_SKILL_DIR}` | Skill 所在目录的绝对路径，用于引用同目录下的脚本或资源文件 |
| `${CLAUDE_SESSION_ID}` | 当前会话 ID，适合日志记录和会话级数据隔离 |

### `description` 的重要性

`description` 字段控制 Claude 是否会**自动检测并调用** Skill。写得越具体，自动触发越准确。**超过 250 字符会在列表中被截断**——关键用例放在前面。如果不希望自动触发，设置 `disable-model-invocation: true`。

### `` !`command` `` 动态上下文注入

在 Skill 内容中使用反引号命令（前加 `!`），会在 Skill 执行前将命令输出注入到提示中：

```markdown
当前 Git 状态：
!`git status --short`

最近 5 个 commit：
!`git log --oneline -5`
```

> **安全控制**：管理员可通过 `disableSkillShellExecution` 设置禁用 Skills 中的 `!command` 执行。

---

## 2. 自定义 Skills

共 11 个自定义 Skill，按用途分为四类：

| 类别 | Skills | 说明 |
|------|--------|------|
| **质量审查** | `/audit`、`/deep-audit`、`/diagnose` | 项目健康检查、文档一致性审计、代码架构诊断 |
| **开发流程** | `/catchup`、`/handoff`、`/spec`、`/implement`、`/done` | 上下文恢复、会话交接、设计文档、单改动实施、收尾检查 |
| **文档管理** | `/docs`、`/release` | 开发文档梳理、Phase 系统性刷新 |
| **工具** | `/nbp2` | AI 生图 Prompt 助手 |

---

### 2.1 /audit — 项目健康检查

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

### 2.2 /deep-audit — 全面深度审计

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

## Step 1: 变更摘要 + 代码结构扫描

先定位"上次审计以来改了什么"，再全量扫描：

```bash
# 最近变更摘要（优先扫描这些区域）
echo "=== 最近 30 个 commit ==="
git log --oneline -30
echo "=== 变更密集的文件 ==="
git log --since="1 month ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -20
echo "=== 新增的文件 ==="
git log --since="1 month ago" --diff-filter=A --name-only --pretty=format: | sort -u
```

然后全量扫描所有源文件，记录实际状态：

```bash
# 前端文件统计
find apps/web/src -name "*.tsx" -o -name "*.ts" | wc -l
find apps/web/src/components -name "*.tsx" | sort

# 后端文件统计
find apps/api -name "*.py" | wc -l

# 所有文档文件
find . -name "*.md" -not -path "*/node_modules/*" | sort
```

**审计优先级**：Step 2-3 MUST 优先检查上方标记的变更密集区域和新增文件，确保这些区域的文档覆盖完整。

## Step 2: 文档系统检查

逐一读取并验证：

- `CLAUDE.md`：行数是否 < 200？内容是否准确？
- `.claude/rules/`：路径 glob 是否仍然匹配实际文件？
- `docs/roadmap/`：各 Phase 功能描述是否准确反映代码现状？README.md 进度统计是否正确？
- `docs/specs/`：各 spec 的设计描述是否仍然准确反映代码现状？状态是否正确（是否有"实施中"但功能已完成的 spec）？
- `docs/architecture/README.md`：架构认知地图是否与代码现状一致（模块划分、组件分层、数据流、非直觉设计）？
- `docs/architecture/adr/`：ADR 是否反映实际决策？
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



### 2.3 /catchup — 工作上下文重建 + 下一步指引

**用途**：在 `/clear` 之后、或新会话开始（隔了几天）时，快速重建工作状态——**只读 @ 不会自动加载的**（避免重复读），支持参数聚焦，用 **AskUserQuestion** 引导下一步。

**定位**：**轻量、有方向的上下文重建**。不做环境检查（那是 SessionStart Hook 的责任），不做代码验证（那是 /implement 和 /done 的责任）——只做"**把你带回昨天的工作状态**"。

**v3.21 变化**：从"全量通用恢复"重新定位为"有方向的聚焦恢复"：
- **去重加载**：识别 CLAUDE.md 已 @ 的文件（roadmap、architecture），**不重复读**
- **参数聚焦**：`/catchup auth` 只读 auth 相关（spec + 最近 commit + 相关文件）
- **AskUserQuestion 引导**：弹窗列 3-4 个下一步具体候选，不散文询问
- **和 SessionStart Hook 分工**：Hook 跑 git 状态（被动），/catchup 恢复 session-notes + spec 状态（手动）

**文件路径**: `.claude/skills/catchup/SKILL.md`

````markdown
---
name: catchup
description: |
  工作上下文重建 + 下一步指引。在 /clear 之后或新会话开始时使用。
  只读 @ 不会自动加载的文件（session-notes、implementing spec、最近源文件），
  支持参数聚焦（如 `/catchup auth` 聚焦 auth 相关），最后用 AskUserQuestion 引导下一步。
  触发关键词：恢复上下文、catchup、接着做、继续昨天、/clear 后
argument-hint: "[可选：关键词如 auth / 功能名 / 或'昨天做到哪了'这类描述]"
allowed-tools: Read, Bash, Glob, Grep
---

<task>
重建工作上下文：读 @ 不会自动加载的关键文件 + 按参数聚焦 + 输出恢复摘要 + AskUserQuestion 引导下一步。
**不重复读 CLAUDE.md 已 @ 加载的文件**（roadmap、architecture 等），只读补充的（session-notes、implementing spec、最近源文件）。
</task>

<workflow>

## Step 0: 明确模式

读取 `$ARGUMENTS` 判断：

| $ARGUMENTS | 模式 | 行为 |
|-----------|------|------|
| 空 | **通用恢复** | 读全部关键补充文件 |
| 关键词（如 `auth`、`dashboard`） | **聚焦模式** | 只读与关键词相关的 spec / commit / 文件 |
| 描述（如 `昨天做到哪了`） | **概览模式** | 重点读 session-notes，简要输出 |

## Step 1: 快速扫描当前状态

```bash
echo "=== 当前状态 $(date '+%Y-%m-%d %H:%M') ==="
git log --oneline -5

echo "--- 修改的文件 ---"
git status --short

echo "--- 未推送 commit ---"
if git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
  UNPUSHED=$(git log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNPUSHED" -gt 0 ] && echo "⚠️ 有 $UNPUSHED 个未推送 commit"
fi
```

> **注意**：SessionStart Hook 可能已经跑过类似命令并输出到会话。/catchup 的重点是**恢复更深的上下文**（session-notes、spec 状态），不是重复跑 git 状态。

## Step 2: 读取 @ 不会自动加载的文件（去重）

**MUST 只读以下补充文件**——CLAUDE.md 里通过 `@` 引用的文件（如 `@docs/roadmap/README.md`、`@docs/architecture/README.md`、当前 Phase 文件）会话启动时已自动加载，**不重复读**。

### 通用恢复（无参数）

按优先级读取：

1. **`.claude/session-notes.md`**（MUST，如存在）—— /handoff 写的交接文档，最高价值
2. **`docs/specs/` 中 `status: implementing` 或 `status: approved` 的 spec**
   ```bash
   grep -rl "status: implementing\|status: approved" docs/specs/ 2>/dev/null
   ```
3. **最近修改的源文件列表**（不读内容，只列名）
   ```bash
   git diff HEAD~3..HEAD --name-only | head -10
   ```

### 聚焦模式（有关键词参数）

```bash
KEYWORD="$ARGUMENTS"

# 1. 匹配 spec
find docs/specs -name "*${KEYWORD}*.md" 2>/dev/null

# 2. 最近涉及该关键词的 commit
git log --oneline --grep="${KEYWORD}" -10
git log --oneline -10 -- "*${KEYWORD}*"

# 3. 相关源文件
find . -name "*${KEYWORD}*" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -20
```

只读匹配到的 spec + session-notes（如有），不读其他。

### 概览模式（描述性参数）

- 重点读 `.claude/session-notes.md`
- 输出简要摘要（见 Step 3 的"概览输出"）
- 不读 spec 内容（只列文件名）

## Step 3: 输出恢复摘要

### 通用 / 聚焦模式输出

```
✅ 上下文已重建（[通用 / 聚焦: KEYWORD]）

## 项目状态
**当前 Phase**：Phase N [名称] ([M/K])
**本次变更**：[git status --short 概要]
**未推送**：[X 个 commit / 无]

## 最近工作（git log）
- [hash] [message]
- ...

## 交接笔记（session-notes.md）
[session-notes 里"下次继续"部分的要点，如无则写"无"]

## 设计文档状态
[列出 implementing/approved 的 spec：文件名 + status + active_phase]

## 修改中的文件
[git status --short 输出]
```

### 概览模式输出（参数为描述）

```
📋 会话接续摘要

**上次做到**：[session-notes 摘要]
**未完成**：[session-notes 里的"遗留"部分]
**上次决策**：[key decisions]

---
准备继续。
```

## Step 4: AskUserQuestion 引导下一步

**MUST 用弹窗**（不散文询问），根据 Step 2-3 收集的信息列 3-4 个具体候选：

**候选生成规则**：
1. 如 session-notes 有"下次继续"项 → 候选 1 = 继续该项
2. 如有 `status: implementing` 的 spec → 候选 2 = 继续该 spec 的 active_phase
3. 当前 Phase 有未完成条目 → 候选 3 = 从 Phase 待办里选（列 3 个具体条目）
4. 总有一个 "其他（自由输入）" 兜底

**弹窗示例**：

```
Question: 上下文已重建，下一步做什么？

Header: "下一步"

Options:
1. (Recommended) 继续 /implement auth 功能（session-notes 遗留）
2. 开始 Spec user-profile Phase 2（status: implementing, active_phase: 2）
3. 从 Phase 3 待办里选（3 个条目：支付集成 / 通知系统 / 数据导出）
4. 其他（自由输入）
```

选 1/2/3 → Claude 直接开始；选 "其他" → 用户输入。

**例外**：概览模式（描述性参数）输出摘要即可，**不弹窗**（用户只是想了解现状，不一定要立即开始新任务）。

</workflow>
````

**用法示例**：

```bash
# 通用恢复：/clear 后或新会话开始
/catchup

# 聚焦模式：有明确方向时，只读相关内容（节省上下文）
/catchup auth             # 聚焦 auth 相关
/catchup dashboard        # 聚焦 dashboard 相关

# 概览模式：了解昨天做到哪了，不一定要立即开始
/catchup 昨天做到哪了
/catchup 回顾一下项目进度
```

**与相关命令的职责边界**：

| 场景 | 用哪个 |
|------|-------|
| 会话中断前保存进度 | `/handoff`（写 session-notes） |
| /clear 之后或新会话开始 | **`/catchup`**（读 session-notes + 其他） |
| 每次会话启动自动显示 git 状态 | SessionStart Hook（被动触发） |

**/catchup vs SessionStart Hook 的分工**：
- **SessionStart Hook**：每次启动都跑，轻量被动（git 状态 + 环境检查）
- **`/catchup`**：手动触发，恢复深层上下文（session-notes + spec + 聚焦参数）

**什么时候不需要 /catchup**：
- 新开终端但当前会话没做过任何工作（直接描述需求即可）
- CLAUDE.md 里已 @ 完整路线图，新功能从零开始（无历史需要恢复）

---

### 2.4 /handoff — 会话交接文档

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

### 2.5 /spec — 讨论成果整理为设计文档

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

### 2.6 /implement — 有纪律的单改动实施

**用途**：处理不需要 Spec 的单个代码改动——业务小需求、Bug 修复、功能微调、技术改进。与 `/spec` 互补：`/spec` 关注"做什么"（产品/UI/API 设计讨论），`/implement` 关注"**在现有代码里怎么做才一致**"（代码层面的快速对齐）。支持批量模式，一个会话连续处理多个改动（每个独立走完整流程）。

**定位**：`/implement` 不是 `/spec` 的轻量版——它是"**有纪律的快速执行**"，压缩流程但**不丢关键检查点**（模式扫描、架构边界、Tidy First）。名字不挑大小，任何一个连贯的实施都可以走。

**设计参考**：
- Anthropic 官方 "search before implement" 模式（agent 每任务跑 10-30 次 rg）
- Kent Beck [Augmented Coding: Beyond the Vibes](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes)（Tidy First + 三红灯信号）
- Claude Code 官方最佳实践的"一句话能描述 → 直改，≥3 文件 → plan"阈值
- Augment Code [11 prompting techniques](https://www.augmentcode.com/blog/how-to-build-your-agent-11-prompting-techniques-for-better-ai-agents)（反重复 prompt 模式）

**文件路径**: `.claude/skills/implement/SKILL.md`

````markdown
---
name: implement
description: |
  有纪律地实施一个单个代码改动（业务小需求、Bug 修复、功能微调、技术改进）。
  不需要 Spec 但需保证与现有代码一致、不引入面条代码。
  支持批量模式：`/implement` 无参数时进入批量模式，每个改动独立走完整流程。
  触发关键词：实施、加个功能、改一下、修复、小需求、快速修复
argument-hint: "<改动描述> 或留空进入批量模式"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
有纪律地实施一个代码改动——MUST 先扫描现有模式再动手，MUST 在 commit 前做架构边界自检，避免面条代码累积。
</task>

<workflow>

## Step 0: 接收任务

**单任务模式**（有参数）：`/implement 列表页加排序功能` → 进入 Step 1

**批量模式**（无参数）：
- 询问用户要处理哪些改动
- 用户列出编号清单
- **每个改动独立走完整 Step 1-7 流程**（批量 ≠ 简化）

## Step 1: 复杂度评估（硬阈值）

**任一触发 → 建议升级到 /spec 或 Plan Mode**：

| 硬阈值 | 为什么 |
|--------|--------|
| 涉及 ≥3 文件（无法用一句话描述 diff） | 需要先规划影响面 |
| 跨模块/跨层 import（如 controller 直接调 repo） | 触碰架构边界 |
| 新增第三方依赖 | 决策影响长期维护 |
| 改变数据流向（API 形状、state 形状、DB schema） | 影响其他模块 |
| 需要多轮讨论才能明确需求 | 应该先 /spec |

触发时输出：
> 这个改动涉及 [具体触发项]，建议用 `/spec` 先讨论设计再实施。要继续还是切换？

用户坚持继续 → 尊重判断，继续执行。

## Step 2: 模式扫描（MUST，Code 前）

**核心原则**：在写任何新代码之前，MUST 确认"项目里是否已有同类实现"。防止 5 个 sort 实现、3 种命名风格的面条代码累积。

### 扫描步骤

1. **识别动词/名词关键词**：从改动描述提取（sort / filter / format / validate / parse / fetch...）
2. **用 rg 搜索现有实现**：
   ```bash
   rg -i "sort|orderBy|order_by" --type ts
   rg "format.*date|dateFormat" --type ts
   ```
3. **列出所有匹配位置**（给用户看一眼，透明决策）
4. **判断**：
   - **找到相似实现** → MUST 说明"为什么不复用"或"怎么复用"——不能装作没看见
   - **未找到** → 明确记录"项目无同类实现，新增为 X"
   - **发现 3+ 种风格并存** → 提醒"这里已有风格分裂，本次改动要统一到哪种？"

### 架构敏感区识别

扫描中同步检查：
- 新增的代码属于哪一层（router/service/repo/util/component）？放对了吗？
- 是否与项目现有的目录/命名约定一致？
- 是否触碰了 `.claude/rules/` 中声明的红线？

## Step 3: 按复杂度执行

| 复杂度 | 流程 |
|--------|------|
| **简单**（1-2 文件） | Code → Verify → Commit |
| **中等**（3-5 文件，已通过 Step 1 阈值） | Explore → Code → Verify → Simplify（建议）→ Commit |
| **Bug 修复** | Explore（复现+定位）→ Code（先写**集成测试**重现 Bug → 修复 → 测试变绿）→ Verify → Commit |

遵循项目 CLAUDE.md 的完成标准和 `.claude/rules/` 的编码红线。

> **Bug 修复的集成测试要求**：MUST 从用户视角重现问题（详见文档 04 Section 1 Testing Trophy）。只测内部函数通过但用户仍然报 Bug —— 这是典型的"测试类型错了"。

## Step 4: Verify（验证）

- 运行相关测试，全部通过
- 运行 lint / 类型检查
- 检查边界条件（空值、异常输入、权限不足）
- 回归验证（确认不影响现有功能）
- 项目无测试 → 跳过测试，但 lint 和类型检查仍 MUST 执行

## Step 5: Commit 前自检（MUST，防面条关键关卡）

### Kent Beck 三红灯（任一触发 → 暂停，向用户汇报）

- 我是否写了循环/重试逻辑**来掩盖失败**（而非处理真实错误）？
- 我是否加了**用户没要求的功能**（顺手优化、未经确认的扩展）？
- 我是否**禁用或删除了任何测试**（包括 `.skip` / `.only` / xdescribe）？

**为什么重要**：Kent Beck 在 [Augmented Coding](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes) 中明确观察到 AI 会在阻力前"自作主张"——这三个信号是 AI 偷懒的典型标志。

### Tidy First 分 commit（显式卡顺序）

检查本次 diff 是否**同时**包含：
- **结构变动**（提取函数、重命名、拆分文件、移动代码）
- **行为变动**（新功能、修复、逻辑改变）

**任一同时存在 → MUST 拆成两个 commit**：

1. 先提交结构变动（纯重构，行为不变）：`refactor: 提取 xxx 到 utils/`
2. 再提交行为变动：`feat: ...` / `fix: ...`

> **为什么**：Beck 观察到"AI 不会自觉 safe-sequencing"。结构和行为混在一起的 commit 后续难以 review、难以回滚，是架构腐化的主要路径。

## Step 6: Commit

- 使用 Conventional Commits（`feat:` / `fix:` / `refactor:` / `chore:` / `perf:` / `test:`）
- message 包含足够上下文（改了什么、为什么）
- 若本次改动和已有 Roadmap 条目关联 → 在输出末尾提示"如需更新 Roadmap，执行 `/done <描述>`"

## Step 7: ADR 触发检查（条件触发弹窗）

**四类触发条件**（任一满足）：
- 新增跨模块依赖
- 替换已有实现（如旧 dateUtil → 新 dateFormatter）
- 引入新第三方库
- 改变数据流向（API / state / DB schema）

满足任一 → 调用 AskUserQuestion 弹窗：

```
Question: 本次改动涉及 [具体决策，如"新增 date-fns 依赖替换 moment"]，
          是否记录为 ADR？

Header: "ADR 决策"

Options:
1. (Recommended) 生成 ADR 草稿
   description: Claude 生成含 Context/Decision/Alternatives/Consequences 的草稿到 docs/architecture/adr/
2. 跳过
   description: 本次不记录
```

**不触发就不问**——避免疲劳。

> 为什么用 AskUserQuestion 而非对话询问：频率低（月均 2-5 次）+ 一键选择 + 沉淀率高。散文标记 90% 会被忽略。

## Step 8: /docs 联动提示

改动涉及架构敏感区（新增模块 / 改路由组织 / 新增跨层依赖 / 改变数据流） → 在输出末尾提示：
> 本次改动涉及架构敏感区，建议执行 `/docs architecture` 刷新架构文档。

不自动执行（避免打断），由用户决定时机。

## 批量模式处理

| 情况 | 动作 |
|------|------|
| 单个改动测试失败 | **停止批量**，汇报失败原因 + 已完成数，等用户决定 |
| 用户说"暂停"/"停一下" | 立即报告当前进度，等待指令 |
| 上下文 > 60% | 提醒剩余改动数，建议 /handoff 后分批处理 |
| ADR 弹窗 | 每次独立询问（不累积批量问） |

**批量 ≠ 简化**：每个改动都走完整 Step 1-8，包括模式扫描和 Commit 前自检。

## 输出格式

**单任务完成**：
```
✓ [hash] fix(list): 修复日期格式显示不正确
  改动: src/utils/date.ts, src/components/List.tsx
  模式扫描: 已复用现有 formatDate（src/utils/date.ts:15）
  [可选] ⚠️ 涉及架构敏感区，建议 /docs architecture 刷新
```

**批量完成汇总**：
```
✅ 完成 3/4 个改动：
1. ✓ [hash] feat(list): 添加列表排序功能
2. ✓ [hash] fix(date): 修复日期格式显示
3. ✓ [hash] chore: 默认分页数从 10 改为 20（Tidy First 拆为 refactor + chore 两个 commit）
4. ⏭️ 跳过 — 涉及 4 文件 + 跨模块依赖，建议 /spec
```

</workflow>
````

**用法示例**：

```bash
# 单任务
/implement 列表页加个按名称排序的功能
/implement 日期显示格式从 MM/DD 改成 YYYY-MM-DD
/implement 首页加载慢，商品列表查询需要加索引

# 批量模式
/implement
# Claude: 请列出要处理的改动
# 你：
# 1. 列表加排序
# 2. 日期格式修复
# 3. 默认分页改成 20
```

**与其他命令的关系**：

| 场景 | 用什么 |
|------|--------|
| 需要多轮讨论的复杂功能 | `/spec` → 实施 → `/done` |
| 方向明确、可直接执行的单改动 | **`/implement`** |
| 功能完成后的收尾检查（有 Spec/Roadmap） | `/done` |
| PR 前的代码审查 | `/simplify` |

> **与旧 `/task` 的关系**：`/implement` 是 `/task`（v3.14-v3.18）的重命名和流程强化版。旧项目迁移方式见 `prompt-guide版本升级.md` v3.19 迁移指令。

---

### 2.7 /done — 功能交付检查清单

**用途**：功能或 Spec Phase 完成 commit 之后，**按 checklist 逐项验证交付完整性**——测试覆盖、Roadmap 状态、Spec 进度、开发文档、代码审查。像飞行员起飞前的 checklist：逐项检查"是否到位"，不到位就**弹窗询问**（AskUserQuestion），到位就放行。

**定位**：**功能交付检查清单，不是"全流程收尾"也不是"进度引擎"**。三个关键原则：
- **不重做**：已经做过的事（commit hook 跑过的测试、/implement 刚跑的 simplify）不重跑
- **检查 + 询问**：每一步都是"轻量扫描 + 弹窗决策"，不自动执行重操作
- **分层触发**：按完成粒度智能判断文档/发版触发（单改动 / Spec Phase / Spec 完成 / Roadmap Phase）

**v3.20 变化**：从"7 步全流程收尾"重新定位为"9 步功能交付检查清单"。剥离代码验证重跑（交给 /implement Verify 和 PreToolUse Hook），新增测试覆盖扫描、文档影响智能判断、AskUserQuestion 决策点，避免 90% 被忽略的散文建议。

**v3.11 历史**：从"自动猜测完成范围"改为"用户显式描述 + Claude 匹配"，提高可靠性。

**文件路径**: `.claude/skills/done/SKILL.md`

````markdown
---
name: done
description: |
  功能交付检查清单。commit 后逐项验证交付完整性（测试覆盖、Roadmap、Spec、文档、simplify）。
  用户描述完成了什么，自动匹配 Roadmap/Spec 并用 AskUserQuestion 询问决策点。
  触发关键词：功能完成、收尾检查、done、wrap up、Phase 完成、交付验证
argument-hint: "<完成了什么功能的描述>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
对刚完成的功能执行交付检查清单：测试覆盖扫描 + Roadmap 更新 + Spec 进度推进 + 文档影响判断 + simplify 补跑询问 + Phase 完成检测。
**不重跑**已做过的验证（commit 存在 = PreToolUse Hook 通过），只**检查 + 询问**决策点。
</task>

<workflow>

## Step 0: 解析完成描述 + 匹配

读取 `$ARGUMENTS` 确定刚完成了什么：

```bash
git log --oneline -5
git diff --stat HEAD~5..HEAD
```

**匹配流程**：
1. 从描述提取关键词（功能名、模块名）
2. 扫描 `docs/roadmap/` 匹配条目
3. 扫描 `docs/specs/` 匹配文件（优先 `status: implementing` 的 spec）

**匹配不明确时 MUST 用 AskUserQuestion 询问**（不散文追问、不猜测跳过）：

```
Question: 根据描述"[用户输入]"，匹配到以下候选，请确认：

Options:
1. Roadmap: phase-2.md - [条目 A]
2. Spec: user-auth.md (implementing, Phase 2)
3. 两个都关联
4. 都不对（跳过 Roadmap/Spec 更新，仅做工作区检查）
```

## Step 1: 工作区状态检查

**MUST 第一步检查**，确保 checklist 基于稳定的 commit 状态：

```bash
git status --short
```

- **有未提交变更** → 停止 `/done`，输出：
  > ⚠️ 检测到未提交变更：[文件列表]
  > `/done` 应在 commit 之后运行。请先 commit 再重试。

- **工作区干净** → commit 存在代表 PreToolUse Hook 验证通过，**不重跑测试**，继续下一步。

## Step 2: 测试覆盖快速扫描

识别本次功能涉及的新代码文件，扫描对应测试文件是否存在：

```bash
# 最近 commit 涉及的源文件（排除测试文件本身）
git diff --name-only HEAD~5..HEAD -- '*.ts' '*.tsx' '*.js' '*.py' '*.java' \
  | grep -vE '\.(test|spec)\.' | grep -v '__tests__'
```

对每个源文件推断预期测试路径（按项目惯例）：
- `src/utils/date.ts` → `src/utils/date.test.ts` 或 `tests/utils/date.test.ts`
- `apps/api/routers/users.py` → `tests/api/routers/test_users.py`

**缺失 → AskUserQuestion 询问**：

```
Question: 检测到以下文件缺少对应测试：
- src/utils/date.ts
- apps/api/routers/users.py

是否补测试？

Options:
1. (Recommended) 补测试（按项目 Testing Trophy 策略写集成测试）
2. 跳过（已在其他地方覆盖或不需要测试）
3. 自定义（说明原因）
```

选 1 → Claude 按 Testing Trophy（文档 04 Section 1）补测试，完成后另起 commit。
选 2/3 → 记录跳过原因，继续下一步。

## Step 3: Roadmap 更新（含"部分完成"检测）

如果 Step 0 匹配到 Roadmap 条目：

1. 读取条目上下文，检查是否是**父条目**（下面有子条目）：
   ```markdown
   - [ ] 用户认证模块                    ← 父条目
     - [x] ✅ 登录 UI
     - [x] ✅ 登录 API
     - [ ] 持久化 Session                ← 未完成子项
   ```

2. **父条目有未完成子项 → AskUserQuestion**：
   ```
   Question: "[条目]" 下还有未完成子项：
   - 持久化 Session
   是否仍标记父条目为完成？

   Options:
   1. (Recommended) 否，只勾已完成的子项
   2. 是，强制标记父条目完成（所有子项一并勾选）
   ```

3. 更新 checkbox：`- [ ]` → `- [x] ✅ YYYY/MM/DD`
4. 更新 `docs/roadmap/README.md` 进度统计（如 `2/5` → `3/5`）

## Step 4: Spec 状态推进（Phase 进度引擎）

如果 Step 0 匹配到 Spec 文件，读取 spec 并按当前 `active_phase` 检查进度：

### 4a. Phase Gate 验证

不论 Spec 有 1 个还是 N 个 Phase，统一检查当前 `active_phase`：
- 所有 Tasks 是否已勾 `[x]`？
- Gate 条件是否全部满足？

**Gate 通过**：
1. 更新 frontmatter `active_phase` → 下一个 Phase
2. 更新 `updated` 日期
3. 检查 `active_phase > total_phases`？
   - **否** → 记录"Phase N 完成，进入 Phase N+1"
   - **是（所有 Phase 完成）** → 进入 4b

**Gate 未通过** → 输出未满足的条件列表，询问用户是否强制推进（AskUserQuestion）。

### 4b. Spec 全部完成

1. frontmatter `status`：`implementing` → `implemented`
2. 更新 `updated` 日期
3. 记录"Spec 全部完成"（后续 Step 5 会询问是否刷新文档）

## Step 5: 文档影响智能判断

基于本次 commit 的 diff 范围 + 完成粒度，智能判断是否建议刷新文档：

### 5a. 触发条件分析

扫描 `git diff HEAD~5..HEAD` 检测：

| 信号 | 建议的 /docs 范围 |
|------|-----------------|
| 新增模块 / 目录 | `/docs architecture` |
| 改路由组织 / 新增 API | `/docs backend`（如有） |
| 新增页面 / 路由 | `/docs frontend`（如有） |
| 新增跨层依赖 | `/docs architecture` |
| 改变数据流向（API / schema / state 形状） | `/docs architecture` |
| 新增环境依赖 / 配置 | `/docs getting-started` 或 `deployment` |
| 仅组件内部逻辑改动 | **不建议**（跳过询问） |

### 5b. 按粒度 + 触发条件组合询问

| 完成粒度 | 触发条件 | 询问方式 |
|---------|---------|---------|
| 单改动 / Spec 单 Phase | 触碰敏感区 | AskUserQuestion 询问是否 /docs |
| 单改动 / Spec 单 Phase | 未触碰敏感区 | **不询问**（跳过） |
| Spec 全部完成 | 任何 | AskUserQuestion **强烈推荐** /docs |
| Roadmap Phase 全部完成 | 任何 | 由 Step 7 的 /release 统一处理（/release 含 /docs 全量，此步不重复询问） |

**弹窗示例**：

```
Question: 本次改动涉及[新增模块 apps/api/notifications/]，建议刷新架构文档。现在执行吗？

Options:
1. (Recommended) 现在执行 /docs architecture
2. 稍后手动执行
3. 跳过（本次不需要）
```

选 1 → Claude 继续执行 `/docs architecture` 流程；选 2/3 → 记录，继续。

## Step 6: 代码审查检查（/simplify）

检测本次 commit 前是否跑过 /simplify：
- `/implement` 中等复杂度任务会提示用户跑 /simplify（用户可能选了或跳过）
- 独立开发者可能忘记跑

**启发式判断**：
- 本次 commit 涉及文件 ≤ 2 且是简单修复 → 跳过询问（通常不需要）
- 涉及 ≥ 3 文件 / 新功能 / 重构 → AskUserQuestion

```
Question: 未检测到本次改动的 /simplify 审查。是否补跑？

Options:
1. (Recommended) 跑 /simplify（三维并行审查：复用 / 质量 / 效率）
2. 跳过（已手动审查过 / 不需要）
```

选 1 → Claude 调用 /simplify；选 2 → 继续。

## Step 7: Roadmap Phase 完成检测

检查当前 Roadmap Phase 所有 checkbox 是否都已勾选：

- **否** → 记录"Phase N 还剩 [M] 个功能"
- **是 → AskUserQuestion**：

```
Question: Roadmap Phase [N] 全部完成！现在执行 /release 进行系统性文档刷新吗？

Options:
1. (Recommended) 现在执行 /release（含 /docs 全量 + Changelog + ADR 检查）
2. 稍后手动执行
3. 跳过（此 Phase 暂不发版）
```

选 1 → Claude 调用 /release；选 2/3 → 记录建议，继续。

## Step 8: 提交文档变更

如果 Step 3-4 产生了文档更新，精确 add 相关目录：

```bash
git add docs/roadmap/ docs/specs/
```

**commit message 根据实际变更动态生成**：

| 变更内容 | commit message |
|---------|---------------|
| 仅勾 Roadmap checkbox | `docs: 勾选 Phase N "[条目]" 完成` |
| Spec Phase 推进 | `docs: Spec [名] Phase N→N+1` |
| Spec 全部完成 | `docs: Spec [名] → implemented` |
| Roadmap + Spec 同时更新 | `docs: Phase N 勾选 + Spec [名] Phase N→N+1` |

## Step 9: 输出汇总

按完成粒度输出不同格式：

**单功能 / Spec 单 Phase 完成**：
```
✅ 交付检查完成

功能：[用户描述]
━━━━━━━━━━━━━━━━━━━━━━━━
Step 1 工作区       ✅ 干净（commit 存在）
Step 2 测试覆盖     ✅ 完整 / ⚠️ 缺失 [N] 文件（已补 / 已跳过）
Step 3 Roadmap     ✅ Phase N "[条目]" 已勾 / ⏭️ 无关联
Step 4 Spec        ✅ Phase M→M+1 / ⏭️ 无关联
Step 5 文档         ⏭️ 未触碰敏感区 / 📝 已启动 /docs [范围]
Step 6 Simplify    ⏭️ 已手动跑过 / ✅ 已补跑
Step 7 Phase 完成   ⏳ 还剩 [M] 个功能
━━━━━━━━━━━━━━━━━━━━━━━━
下一步：继续实施 Spec Phase [M+1] / 继续下一个功能
```

**Spec 全部完成**：
```
🎉 Spec 全部完成：[spec名].md → implemented

（Step 1-8 详情同上）

Spec 状态     ✅ implementing → implemented
Phase 进度    [M/M] 全部 Gate 通过
Roadmap      ✅ Phase N "[条目]" 已勾
文档刷新      📝 已启动 /docs / ⏭️ 已手动执行 / ⏭️ 已跳过

Roadmap Phase 状态：还剩 [M] 个功能 / 🎯 本 Phase 全部完成，已弹窗询问 /release
```

**Roadmap Phase 全部完成**：
```
🎉 Roadmap Phase [N] 全部完成！

所有功能已交付，所有 Spec 已 implemented。
/release 执行状态：✅ 已启动 / ⏭️ 用户选择稍后
```

</workflow>
````

**用法示例**：

```bash
/done 完成了用户登录功能
/done 完成了 user-auth spec 的 Phase 2
/done 修复了移动端按钮无响应的 bug
```

**与相关命令的职责边界**：

| 场景 | 用哪个 |
|------|-------|
| 实施单个代码改动 | `/implement` |
| 功能 commit 后验证交付完整性 | **`/done`** |
| 会话中断时整理进度（无论是否完成） | `/handoff` |
| Phase 里程碑系统性发版 | `/release` |

**/done vs /handoff 的 Roadmap 更新区别**：
- `/done`：**主业** — Phase 进度引擎，精确维护 Spec frontmatter（active_phase / status / Gate 验证）+ Roadmap checkbox + 文档影响判断
- `/handoff`：**副业** — 会话中断时顺手勾已完成的 Roadmap checkbox（不动 Spec frontmatter）

**三级升级逻辑**（基于 Step 7 Roadmap Phase 检测 + Step 4b Spec 完成）：

| 检测到的完成粒度 | `/done` 的关键动作 |
|-----------------|-----------------|
| **Spec 单个 Phase** | Step 5 条件询问 /docs + Step 6 询问 /simplify |
| **Spec 全部完成** | 上述 + Step 4b `status→implemented` + Step 5 强烈推荐 /docs |
| **Roadmap Phase 完成** | 上述 + Step 7 AskUserQuestion 询问 /release |

---

### 2.8 /docs — 开发文档梳理

**用途**：深度探索项目代码，梳理并更新开发文档。可全量刷新，也可按范围指定。日常高频使用，保持文档与代码同步。

**文件路径**: `.claude/skills/docs/SKILL.md`

````markdown
---
name: docs
description: |
  深度探索代码逻辑，梳理并更新开发文档（架构、上手指南、部署）。
  当用户说"更新文档"、"梳理架构"、"写一下开发文档"时使用。
  触发关键词：更新文档、梳理文档、docs、架构梳理、文档同步
argument-hint: "[architecture | frontend | backend | getting-started | deployment | 空=全量]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
深度探索项目代码，对比现有开发文档，增量更新。保持文档准确反映代码现状。
</task>

<workflow>

## Step 0: 确定范围

解析 `$ARGUMENTS`：

| 参数 | 更新范围 |
|------|---------|
| 无参数 | 全量：architecture + getting-started + deployment |
| `architecture` | `docs/architecture/` 全部（README + frontend + backend） |
| `frontend` | `docs/architecture/frontend.md` |
| `backend` | `docs/architecture/backend.md` |
| `getting-started` | `docs/development/getting-started.md` |
| `deployment` | `docs/development/deployment.md` |

```bash
mkdir -p docs/architecture docs/development
```

## Step 1: 变更锚定（增量检测基准）

确定"上次文档更新以来改了什么"，为后续探索提供方向：

```bash
# 找到最近一次文档更新的 commit
LAST_DOC_COMMIT=$(git log --oneline -- 'docs/architecture/' 'docs/development/' | head -1 | cut -d' ' -f1)

# 自那以后变更的源文件（按目录分组）
echo "=== 变更文件 ==="
git diff --name-only $LAST_DOC_COMMIT..HEAD -- '*.py' '*.ts' '*.tsx' '*.js' '*.jsx' '*.java' 2>/dev/null | sort

# 新增的文件（上次文档更新时不存在的）
echo "=== 新增文件 ==="
git diff --diff-filter=A --name-only $LAST_DOC_COMMIT..HEAD 2>/dev/null

# 最近 commit 摘要（理解变更意图）
echo "=== 变更摘要 ==="
git log --oneline $LAST_DOC_COMMIT..HEAD | head -30
```

将变更文件按模块分组，标记每个模块的变更密度（文件数）。
**Step 2 的探索 MUST 覆盖所有有变更的模块**，不能只泛泛扫描。

如果 `LAST_DOC_COMMIT` 找不到（首次运行 `/docs` 或文档目录不存在），则跳过锚定，Step 2 做全量探索。

## Step 2: 深度探索代码

**优先探索 Step 1 标记的变更模块**，然后按范围补充探索：

根据范围，使用 Explore subagent 或直接读取关键文件：

**架构相关**（architecture / frontend / backend）：
- 扫描顶层目录结构和模块划分
- 读取路由/控制器，梳理请求完整链路
- 读取中间件/拦截器，梳理横切关注点
- 读取 service/repository 层，梳理业务逻辑链路
- 识别状态机、异步任务、定时任务等复杂流程
- 读取组件目录结构，梳理分层和复用模式
- 特别关注跨多文件才能串起来的逻辑链路

**上手指南相关**（getting-started）：
- 读取 package.json / pyproject.toml（依赖和脚本）
- 读取 .env.example（环境变量）
- 读取 Docker 配置（如有）
- 验证启动步骤是否仍然有效

**部署相关**（deployment）：
- 读取 CI/CD 配置
- 读取 Dockerfile / docker-compose
- 读取环境变量使用情况（grep 所有 process.env / os.environ）
- 检查部署脚本

## Step 3: 读取现有文档 + 变更覆盖检查

读取对应的现有文档文件（如存在），标记：
- ✅ 仍然准确的内容
- ⚠️ 需要更新的内容（代码已变但文档未同步）
- ❌ 已过时需删除的内容
- 🆕 代码中有但文档中缺失的内容

**变更覆盖检查**（基于 Step 1 锚定结果）：
逐一检查 Step 1 中每个变更模块，确认文档是否覆盖：
- 新增的文件/模块 → 文档是否提及？
- 新增的机制/流程（从 commit message 的 `feat:` / `refactor:` 识别）→ 文档是否描述？
- 删除/重构的功能 → 文档是否还在引用已不存在的内容？

未覆盖的变更 MUST 在 Step 4 中补充到对应文档。

## Step 4: 增量更新

按以下规范写入/更新文档：

### `docs/architecture/README.md` — 架构总览（30-50 行）
- 顶层模块职责和边界
- 模块间依赖关系
- 前后端通信方式
- 关键技术选型一句话理由
- 非直觉的全局设计决策

### `docs/architecture/frontend.md` — 前端架构（50-100 行）
- 路由结构（哪些页面用模板布局、哪些独立）
- 组件分层规则（ui / business / page）
- 全局状态流转（store → component → API 调用）
- 表单/列表/弹窗等通用交互模式
- 样式约定（全局 vs 组件级 vs 共享）

### `docs/architecture/backend.md` — 后端架构（50-100 行）
- 请求完整链路：Router → Middleware → Service → Repository → DB
- 认证/鉴权链路（token 解析 → 权限判断 → 端点保护）
- 业务逻辑中的状态机流转（如订单、审批流程）
- 异步任务/定时任务的触发条件和执行路径
- 错误处理和统一响应格式
- 数据处理约定（Converter/Transformer 位置、事务管理）

### `docs/development/getting-started.md` — 上手指南
- 环境要求（语言/包管理器/数据库版本）
- 从 clone 到跑通的完整步骤
- 关键 URL（本地服务地址、API 文档地址）
- 项目结构概览

### `docs/development/deployment.md` — 部署文档
- 环境变量表（名称、必填、说明、示例）
- 部署流程步骤
- 回滚方案

**写入原则**：
- 写代码里看不出来的：模块为什么这样划分、数据为什么这样流转
- 写跨多文件才能串起来的逻辑链路（请求链路、认证流程、状态机等）
- 不写具体函数签名、props 列表（看代码）
- 不写 API 端点列表（看自动生成的 API 文档）
- 不写数据库表结构（看 ORM 模型）
- 已有内容只增量更新，不全量重写

## Step 5: 提交

```bash
git add docs/architecture/ docs/development/
git commit -m "docs: 更新开发文档 — [更新范围描述]"
```

## Step 6: 输出报告

```
✅ 开发文档已更新

更新范围：[全量 / architecture / frontend / backend / getting-started / deployment]
变更锚定：基于 [hash] 以来 [N] 个 commit，[M] 个模块有变更 / 首次运行（全量探索）

变更摘要：
- docs/architecture/README.md: [新建 / 更新 N 处 / 无变更]
- docs/architecture/frontend.md: [新建 / 更新 N 处 / 无变更]
- docs/architecture/backend.md: [新建 / 更新 N 处 / 无变更]
- docs/development/getting-started.md: [新建 / 更新 N 处 / 无变更]
- docs/development/deployment.md: [新建 / 更新 N 处 / 无变更]

主要变更：
- [列出 2-3 个最重要的文档变更]
```

</workflow>
````

---

### 2.9 /release — Phase 完成系统性文档刷新

**用途**：一个 Roadmap Phase 的所有功能完成后，进行**系统性文档刷新**——全量执行 `/docs`、生成 Changelog、检查 ADR、更新 Phase 状态。与 `/docs` 的区别：`/docs` 是日常随时可用的轻量更新，`/release` 是 Phase 里程碑节点的全面梳理。

**文件路径**: `.claude/skills/release/SKILL.md`

````markdown
---
name: release
description: |
  Phase 完成系统性文档刷新。全量执行 /docs + 生成 Changelog + 检查 ADR + 更新 Phase 状态。
  触发关键词：release、发版、Phase 完成、阶段完成、系统性文档刷新
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
Phase 完成后的系统性文档刷新：全量执行 /docs（架构+上手+部署），生成 Changelog，检查 ADR，更新 Roadmap Phase 状态。
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

## Step 1: 全量文档刷新（按 /docs Skill 完整流程）

执行 `/docs` Skill 的完整 6 步流程（MUST 包含变更锚定）：
1. **变更锚定**：`git diff` 定位上次文档更新以来的变更文件，按模块分组
2. **深度探索**：优先探索变更模块，再补充全量
3. **文档对比 + 变更覆盖检查**：现有文档准确性 + 变更模块是否有文档覆盖
4. **增量更新**：刷新 `docs/architecture/`（README + frontend + backend）、`getting-started.md`、`deployment.md`

详细规范见 `/docs` Skill（Step 1-6）。

## Step 2: 生成 Changelog

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

## Step 3: 检查 ADR

检查本 Phase 是否有需要记录的架构决策：

- 是否引入了新的技术栈组件
- 是否有重大架构重构
- 是否有技术选型变更

如有，提示用户："检测到 [变更描述]，建议新增 ADR，是否创建？"
用户确认后，按 ADR 模板在 `docs/architecture/adr/` 中新建。

## Step 4: 更新 Roadmap Phase 状态

```bash
# 将当前 Phase 文件中的所有 checkbox 状态确认
# 更新 docs/roadmap/README.md 中的 Phase 状态为 "✅ 完成"
# 更新进度统计
```

## Step 5: 提交所有文档变更

```bash
git add docs/
git commit -m "docs: Phase N [Phase名称] 完成 — 系统性文档刷新"
```

## Step 6: 输出 Release 报告

```
🎉 Phase N [Phase名称] 系统性文档刷新完成

文档更新摘要：
- 架构文档：✅ 已刷新（README/frontend/backend） / ⏭️ 无变更
- 上手指南：✅ 已更新 / ⏭️ 无需更新
- 部署文档：✅ 已更新 / ⏭️ 无变更
- Changelog：✅ 新增 [版本号] 条目
- ADR：✅ 新增 N 条 / ⏭️ 无需新增
- Roadmap：✅ Phase N 标记为完成

下一步建议：
- git push 推送更新
- /deep-audit 全面代码审计
- 开始规划 Phase N+1
```

</workflow>
````

---

### 2.10 /nbp2 — AI 生图 Prompt 助手（Nano Banana Pro 2）

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

### 2.11 /diagnose — 全维度代码健康诊断

**用途**：独立于功能开发的系统性代码健康诊断。覆盖结构、实现、卫生、战略四层共 13 个维度，输出量化评分 + 完整问题清单 + 分批重构计划。与 `/audit`（项目卫生检查）和 `/deep-audit`（文档一致性审计）互补——`/diagnose` 关注代码架构与长期可维护性。

**设计依据**：CodeScene 热点分析 + ISO 25010 质量模型 + SonarQube 三维度体系 + Martin Fowler 重构方法论。核心原则——全维度扫描确保无死角，热点分析决定执行优先级。

**文件路径**: `.claude/skills/diagnose/SKILL.md`

````markdown
---
name: diagnose
description: |
  全维度代码健康诊断。系统性扫描代码结构、耦合度、可维护性等 13 个维度，输出诊断报告和重构计划。
  独立于功能开发，专门用于发现和规划代码优化。
  触发关键词：代码诊断、代码健康、重构评估、全面审查、code health、技术债
argument-hint: "[frontend | backend | <模块名> | 空=全项目]"
allowed-tools: Read, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
对项目进行全维度代码健康诊断（13 个维度），输出量化评分、完整问题清单和分批重构计划。
**只诊断不改代码**——改代码在后续用 `/implement` 批量模式按计划执行。
</task>

<dimensions>

## 诊断维度（四层 13 维度）

### 结构层（影响面大，优先级高）

**D1 耦合度** — 改 A 会不会崩 B？
- 检查组件/模块间的导入依赖数量和深度
- 查找跨模块直接引用内部状态或私有方法
- 前端：组件是否依赖过多不相关 store；CSS 样式是否穿透到其他组件
- 后端：Service 之间是否有非接口级的直接调用

**D2 职责划分** — 每个单元是否只做一件事？
- 查找"万能文件"（> 300 行的组件 / > 500 行的 Service）
- 前端：组件内是否直接调 API、处理数据转换、包含业务逻辑
- 后端：Controller/Router 内是否有业务逻辑；Service 是否混合了多个业务域

**D3 模块边界** — 模块之间是通过接口通信还是深入内部？
- 查找被 > 10 个文件导入的"上帝模块"
- 检查模块是否暴露了内部实现（应只暴露公共接口/index）
- 前后端 API 契约是否清晰（请求/响应类型定义）

**D4 依赖方向** — 依赖关系是否合理？
- 检查循环依赖（A→B→C→A）
- 检查是否有下层依赖上层（data 层引用 UI 层）
- 检查共享代码是否独立（不依赖任何业务模块）

### 实现层（局部优化，逐步改进）

**D5 代码重复** — 近似逻辑是否散落多处？
- grep 相似的函数签名和代码块
- 重点关注 80% 相似但略有不同的代码（比完全相同更危险）
- 应该抽成公共 hook/util/service 但没有的

**D6 错误处理** — 是否一致且完整？
- 检查 try-catch 使用是否一致
- 查找静默失败（catch 了但空处理 / 仅 console.log）
- 检查错误响应格式是否统一

**D7 类型安全** — 类型系统是否被正确使用？
- 前端：grep `any`、`@ts-ignore`、`@ts-expect-error`、类型断言 `as`
- 后端（Python）：关键函数是否有类型注解；Pydantic model 是否覆盖 API 边界
- 后端（Java）：是否用 Map 代替 DTO；泛型是否正确使用

**D8 性能隐患** — 是否有明显的性能反模式？
- 前端：组件内创建对象/函数导致不必要 re-render；缺少 key 或 key 使用 index
- 后端：循环内 DB 查询（N+1）；同步阻塞调用；缺少分页
- 通用：未清理的定时器/订阅（内存泄漏风险）

**D9 测试覆盖** — 关键操作链路是否有集成测试？
- 关键用户交互（分页/搜索/表单/CRUD）是否有集成测试（测完整操作链路，不只是独立函数）
- 是否存在"假覆盖"：只有单元测试，每个函数单独通过，但串起来的链路没人测
- 后端 API 是否有请求级集成测试（走完整 路由→service→DB 链路，不只是测 service 函数）
- 测试是否在测实现细节而非用户行为（如直接检查 state 值而非检查页面显示内容）
- 紧耦合导致无法测试的模块

### 卫生层（认知负担）

**D10 死代码** — 是否有不再使用的代码？
- 未使用的函数、组件、导入、变量
- 注释掉的代码块（应删除，git 有历史）
- 已废弃但未清理的功能

**D11 一致性** — 同一件事是否用同一种方式做？
- 同一功能多种实现（如 HTTP 客户端既用 fetch 又用 axios）
- 命名风格不统一（camelCase 和 snake_case 混用）
- 错误处理/日志格式不统一

### 战略层（投入产出比）

**D12 代码热点** — 哪些代码改动最频繁且质量最差？
- 分析 git log 找改动频率最高的文件
- 交叉对比代码质量（文件大小、复杂度、问题密度）
- 热点 = 改动频繁 × 质量差 = 最值得重构的地方

**D13 知识孤岛** — 是否有只有一个人碰过的关键模块？
- 分析 git blame/log 的作者分布
- 标记 bus factor = 1 的模块（只有一个贡献者）
- 单人项目跳过此维度

</dimensions>

<workflow>

## Step 0: 读取项目上下文

```bash
echo "=== 代码健康诊断 $(date '+%Y-%m-%d %H:%M') ==="
```

读取（如存在）：
1. `CLAUDE.md`（技术栈、约束、完成标准）
2. `docs/architecture/`（设计意图基准，对比实际代码偏差）
3. 上一次诊断报告 `docs/reports/diagnose-*.md`（用于对比改善）

## Step 1: 探索项目结构 → 决定扫描策略

```bash
# 源文件统计（排除依赖和构建产物）
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.java" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/__pycache__/*" | wc -l

# 顶层目录结构
ls -d */ 2>/dev/null
```

- 从 `package.json` / `pyproject.toml` / `pom.xml` 识别技术栈
- 识别模块边界（目录划分方式）
- 检查 `$ARGUMENTS`，限定扫描范围

**扫描策略**：

| 条件 | 策略 |
|------|------|
| < 50 源文件 或 scope 指定了具体模块 | 主 Agent 直接扫全维度 |
| ≥ 50 源文件，前后端分离 | SubAgent: 前端 + 后端 + 跨模块 |
| ≥ 50 源文件，按业务域划分 | SubAgent: 每个业务域 + 跨域 |

SubAgent 指令要点：
> 扫描 [范围] 下的所有源文件，按 13 个维度逐一检查。
> 每个问题输出：维度编号、文件路径:行号、严重性(P0-P3)、置信度(高/中/低)、问题描述、判断依据。
> **不改代码，只输出发现。**

## Step 2: 热点分析（可选）

**前置条件**：git 历史 ≥ 1 个月且 commit ≥ 30 个。不满足则跳过，标记"热点分析: 跳过（历史不足）"。

```bash
# 最近 3 个月文件改动频率 Top 20
git log --since="3 months ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -20

# 文件行数排序（大文件 = 复杂度信号）
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.java" \) \
  -not -path "*/node_modules/*" -exec wc -l {} \; | sort -rn | head -20
```

改动频率高 × 文件大 = 热点候选，在最终报告中标记。

## Step 3: 全维度扫描

按 D1-D13 逐维度扫描。对每个维度：

1. 用 Grep/Glob 做模式匹配（快速发现明显问题）
2. 读取关键文件做语义分析（发现需要理解上下文的问题）
3. 每个问题记录：`[维度] [文件:行号] [P0-P3] [置信度] 描述 | 依据`

**技术栈专项**（根据 Step 1 识别结果自动追加）：

| 技术栈 | 追加检查 |
|--------|---------|
| React/Next.js | 组件 > 200 行、`style={{}}`、props drilling > 3 层、Server/Client 分界 |
| FastAPI | 路由函数 > 30 行、async/sync 混用、缺少 Pydantic 校验 |
| Spring Boot | Controller 业务逻辑、字段注入 `@Autowired`、Entity 直接作响应 |

## Step 4: 汇总评分

每维度评分 0-10（10 = 完美）：

| 评分 | 含义 |
|------|------|
| 8-10 | 优秀，无需处理 |
| 5-7 | 可接受，有改进空间 |
| 3-4 | 需要关注，建议本月处理 |
| 0-2 | 严重，建议立即处理 |

综合健康度 = 13 维度加权平均（结构层权重 ×1.5，其余 ×1.0）。
如有上次诊断报告，输出对比变化。

## Step 5: 生成重构计划

将 P0-P2 问题分批：
1. **同一模块的问题合并到同一 Batch**（减少上下文切换）
2. **有依赖关系的 Batch 标注前置条件**
3. **每个 Batch 预估不超过 1 个会话**
4. **每个 Batch 有明确验收标准**

P3 观察项单独列出，不进入重构计划。

## Step 6: 输出报告

```bash
mkdir -p docs/reports
```

写入 `docs/reports/diagnose-YYYY-MM-DD.md`：

```markdown
---
date: YYYY-MM-DD
scope: [full | frontend | backend | 模块名]
tech_stack: [识别到的技术栈]
files_scanned: [数量]
issues_found: [数量]
health_score: [0-10]
previous_score: [上次得分，如有]
---

# 代码健康诊断报告

## 健康度评分

| 维度 | 得分 | 说明 |
|------|------|------|
| D1 耦合度 | X/10 | ... |
| D2 职责划分 | X/10 | ... |
| ... | | |
| **综合** | **X.X/10** | [与上次对比] |

## 热点文件
[Top 10 热点文件表，或"跳过（历史不足）"]

## 问题清单

### 🔴 P0 — 结构性问题
[编号]. [D维度] [文件:行号] [置信度:高/中/低]
  描述: ...
  依据: ...

### 🟡 P1 — 实现质量问题
...

### 🟢 P2 — 卫生问题
...

### ℹ️ P3 — 观察项
...

## 跨边界观察
[scope 限定时检测到的跨边界问题，注明对侧未完整分析]

## 重构计划

### Batch 1: [名称]（预估 [N] 个会话）
- **前置**: 无 / Batch N
- **范围**: [涉及的文件/模块]
- **解决问题**: #1, #3, #7
- **验收标准**: [具体可验证条件]

### Batch 2: ...

## 执行建议

按 Batch 顺序执行，每个 Batch 用 `/implement` 批量模式：
1. 先补测试锁定现有行为
2. 重构
3. 跑测试确认不破坏
4. commit

全部完成后再次运行 `/diagnose` 验证改善效果。
```

## Step 7: 输出确认

```
✅ 代码健康诊断完成

综合健康度: X.X/10 [与上次对比]
扫描范围: [scope]
扫描文件: [N] 个
发现问题: P0 [N] 个 | P1 [N] 个 | P2 [N] 个 | P3 [N] 个
重构计划: [N] 个 Batch，预估 [N] 个会话

报告: docs/reports/diagnose-YYYY-MM-DD.md

下一步：
- 查看报告，确认优先级排序
- 按 Batch 顺序用 /implement 批量模式执行重构
- 全部完成后再次 /diagnose 验证改善
```

</workflow>
````

**用法示例**：

```bash
# 全项目诊断
/diagnose

# 仅前端
/diagnose frontend

# 仅后端
/diagnose backend

# 指定模块
/diagnose auth
```

**与其他命令的关系**：

| 命令 | 关注点 | 何时用 |
|------|--------|--------|
| `/simplify` | 本次改动的代码质量 | 功能完成后、PR 前 |
| `/audit` | 项目卫生（lint/依赖/文档） | 每周 |
| `/deep-audit` | 文档与代码一致性 | Phase 完成后 |
| **`/diagnose`** | **代码架构与可维护性** | **独立会话，定期或迭代前** |

**推荐频率**：

| 项目阶段 | 建议频率 |
|----------|---------|
| 快速迭代期 | 每月 1 次 |
| 稳定维护期 | 每季度 1 次 |
| 大功能开发前 | 开发前跑一次，识别要碰的区域的健康度 |
| 技术债感觉积累了 | 随时 |

---

## 3. Anthropic 内置命令（Bundled Skills）

Claude Code 2.x 内置了五个由 Anthropic 维护的 bundled 命令，随版本自动更新，**无需手动配置，直接使用**。

### 3.1 /simplify — 代码简化审查

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

### 3.2 /batch — 大规模并行变更

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

### 3.3 /debug — 交互式调试助手

**何时用**：遇到难以定位的 Bug 时，让 Claude 引导你逐步调试。

```bash
/debug                         # 从当前错误开始调试
/debug "TypeError in auth flow" # 指定问题描述
```

**内部机制**：Claude 会引导你设置断点、分析堆栈跟踪、检查变量状态，逐步缩小问题范围直到定位根因。

---

### 3.4 /loop — 定时重复执行

**何时用**：需要定期检查状态或重复执行任务时。

```bash
/loop 5m /audit --quick        # 每 5 分钟跑一次快速审查
/loop 10m "检查 CI 状态"       # 每 10 分钟检查 CI
```

**限制**：默认间隔 10 分钟，最长运行 3 天，上限 50 个任务。支持 `.claude/loop.md` 文件作为默认 prompt。

---

### 3.5 /claude-api — Claude API 集成指导

**何时用**：项目中需要使用 Claude API 或 Anthropic SDK 时。

```bash
/claude-api                    # 获取 API 集成指导
```

**内部机制**：提供 Claude API 的最佳实践、SDK 用法、Tool Use 配置、Managed Agents 参考等专业指导。支持 Python/TypeScript/Java/Go/Ruby/C#/PHP/cURL。

---

### 区分 Bundled 命令 vs 自定义 Skills

| 维度 | Bundled（/simplify /batch /debug /loop /claude-api） | 自定义 Skills |
|------|---------------------------|--------------|
| 维护方 | Anthropic（随版本更新） | 你自己 |
| 配置位置 | 无需配置，内置 | `.claude/skills/*/SKILL.md` |
| 内部能力 | 可访问内部 API | 仅标准工具 |
| 适合场景 | 代码质量、批量变更 | 项目特定工作流 |

---

## 4. 安装说明

### 4.1 目录结构

```bash
# 创建 Skills 目录
mkdir -p .claude/skills/audit
mkdir -p .claude/skills/deep-audit
mkdir -p .claude/skills/catchup
mkdir -p .claude/skills/handoff
mkdir -p .claude/skills/spec
mkdir -p .claude/skills/implement
mkdir -p .claude/skills/done
mkdir -p .claude/skills/docs
mkdir -p .claude/skills/release
mkdir -p .claude/skills/nbp2
mkdir -p .claude/skills/diagnose
```

### 4.2 文件创建

将上述各 Skill 内容分别写入：
- `.claude/skills/audit/SKILL.md`
- `.claude/skills/deep-audit/SKILL.md`
- `.claude/skills/catchup/SKILL.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/spec/SKILL.md`
- `.claude/skills/implement/SKILL.md`
- `.claude/skills/done/SKILL.md`
- `.claude/skills/docs/SKILL.md`
- `.claude/skills/release/SKILL.md`
- `.claude/skills/nbp2/SKILL.md`
- `.claude/skills/diagnose/SKILL.md`

### 4.3 查看已安装的 Skills

```bash
# Claude Code 内部命令
/skills         # 列出所有可用 Skills
```

### 4.4 使用方式

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

/done 完成了用户登录    # 功能完成收尾检查（附描述）

/docs               # 全量刷新开发文档
/docs backend       # 只刷新后端架构文档

/release            # Phase 完成系统性文档刷新

/nbp2               # AI 生图 Prompt 助手
/nbp2 一只猫在雨中的东京街头   # 指定描述

/diagnose            # 全项目代码健康诊断
/diagnose frontend   # 仅前端
/diagnose auth       # 指定模块
```

---

**版本**: v3.21
**更新日期**: 2026-04（v3.21）
