# Skills 命令配置指南

> Claude Code 自定义工作流命令系统

**版本**: v3.33
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
description: |                        # Claude 自动检测触发的描述（max 1024 字符，列表显示上限 1536 字符，v2.1.105+）
  当用户需要做 X 时使用此命令。
  触发关键词：X、Y、Z
argument-hint: "[参数说明]"           # 命令行自动补全提示
allowed-tools: Read, Grep, Bash       # 免确认工具（注意：不是限制可用，其他工具仍可调用但需确认）
model: haiku                          # 模型覆盖（haiku/sonnet/opus/inherit）
effort: medium                        # 思考深度覆盖（low/medium/high/max）
context: fork                         # fork = 在隔离子代理中运行（v2.1.101+ 修复后生效）
agent: Explore                        # 搭配 context:fork，指定子代理类型（v2.1.101+ 修复后生效）
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

`description` 字段控制 Claude 是否会**自动检测并调用** Skill。写得越具体，自动触发越准确。**列表显示上限 1,536 字符**（v2.1.105 起，此前为 250；超限时 Claude Code 启动会显示警告）——关键用例仍 MUST 放在前面以保证截断时不丢失。如果不希望自动触发，设置 `disable-model-invocation: true`。

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

共 12 个自定义 Skill，按用途分为四类：

| 类别 | Skills | 说明 |
|------|--------|------|
| **质量审查** | `/audit`、`/diagnose` | 项目健康浅层巡检、代码架构量化诊断（文档一致性归 `/docs`）|
| **开发流程** | `/catchup`、`/handoff`、`/spec`、`/implement`、`/done` | 上下文恢复、会话交接、设计文档、单改动实施、收尾检查 |
| **文档管理** | `/docs`、`/release` | 开发文档梳理、Phase 系统性刷新 |
| **工具** | `/nbp2`、`/fix-permission`、`/codex` | AI 生图 Prompt 助手、Claude Code 权限拦截诊断修复、外部 AI 任务文档生成器 |

---

### 2.1 /audit — 浅层快速巡检

**用途**：5-10 分钟内跑一遍找"**明显问题**"——超行、硬编码密钥、过时依赖、.env 未忽略、stale spec 等。**不做深度分析、不改代码**。日常或 PR 前用。

**定位**：**浅层快速巡检**。只**发现问题 + 弹窗询问修复策略**，不自动修复（代码问题交 `/implement`，文档问题交 `/docs`）。

### 和 /docs、/diagnose 的分工

| 场景 | 用哪个 | 耗时 | 改代码？|
|------|-------|-----|-------|
| **日常快速巡检**（PR 前、每周、改配置后） | **`/audit`** | 5-10 分钟 | ❌ 只发现+询问 |
| **PR 前安全扫描** | `/audit --security` | 5 分钟 | ❌ 只发现 |
| **大版本前含构建测试的全面检查** | `/audit --deep` | 20-30 分钟 | ❌ 只发现 |
| **代码/文档一致性审计 + 文档修复**（spec/ADR 准确性、Gate 可执行性） | `/docs`（文档生态守护者） | 30-60 分钟 | ✅ 只改文档 + commit |
| **重构前代码架构量化评估** | `/diagnose` | 20-40 分钟 | ❌ 输出重构计划 |

### v3.24 变化

- **参数 5 种简化为 3 种**：`/audit` / `/audit --deep` / `/audit --security`（去掉 `--quick` 和 `--docs`——quick 和标准差别太小，docs 归 /docs）
- **命令自适应**：从 CLAUDE.md "常用命令" 段或 package.json 读实际 lint / test 命令（不硬编码 pnpm）
- **AskUserQuestion 修复引导**：发现问题后弹窗询问处理方式
- **历史对比**：保留 `docs/reports/audit-YYYY-MM-DD.md`，下次审计对比趋势
- **文档同步并入标准检查**：CLAUDE.md 行数、rules 路径、roadmap 一致性、stale spec 每次都查
- **Security 优先用 gitleaks**（如已安装），fallback grep

**文件路径**: `.claude/skills/audit/SKILL.md`

````markdown
---
name: audit
description: |
  浅层快速巡检项目健康状况（5-10 分钟）。只发现问题，不改代码。
  默认标准模式；`--deep` 加构建/测试覆盖率；`--security` 专项安全扫描。
  触发关键词：健康检查、audit、快速巡检、代码质量检查、依赖检查
argument-hint: "[--deep | --security | 空=标准]"
allowed-tools: Read, Bash, Grep, Glob
disable-model-invocation: true
---

<task>
对项目进行浅层快速巡检，发现"明显问题"。
**只发现问题 + 询问修复策略，不自动改代码/文档**（代码归 `/implement`，文档归 `/docs`）。
</task>

<workflow>

## Step 0: 读取项目实际命令

从项目上下文推断实际 lint / test / build 命令（**不硬编码**）：

1. 读 `CLAUDE.md` 的"常用命令"段落
2. 读 `package.json` 的 `scripts` 字段
3. 推断出的命令写入内部变量：`LINT_CMD`、`TEST_CMD`、`BUILD_CMD`

**推断失败**（找不到这些命令） → AskUserQuestion：
```
Question: 未找到项目的 lint / test / build 命令，如何处理？

Options:
1. 跳过相关检查（只做不依赖这些命令的项目）
2. 手动指定命令（自由输入）
```

## Step 1: 基本信息

```bash
echo "=== 项目审计 $(date '+%Y-%m-%d %H:%M') ==="
echo "--- 最近 5 个 commit ---"
git log --oneline -5
echo "--- 未提交文件 ---"
git status --short | head -20
```

## Step 2: 解析参数

| 参数 | 执行哪些 Step | 适用场景 |
|------|-------------|---------|
| 无参数 | Step 3（标准）+ Step 6（报告） | 日常 / 每周 / PR 前 |
| `--deep` | Step 3 + Step 4（构建测试）+ Step 6 | 大版本发布前 |
| `--security` | Step 5（安全专项）+ Step 6 | 上线前 / 定期安全审计 |

## Step 3: 标准巡检

### 3a. 代码质量

```bash
# Lint（从 Step 0 推断）
$LINT_CMD 2>&1 | tail -5

# TODO/FIXME/HACK 统计（自适应识别源码目录）
# 根据项目结构自动选择目录（apps/、src/、packages/ 等）
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.java" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
  -exec grep -l "TODO\|FIXME\|HACK\|XXX" {} \; 2>/dev/null | wc -l
```

### 3b. 依赖健康（自适应包管理器）

```bash
# 检测包管理器
if [ -f pnpm-lock.yaml ]; then PM=pnpm; fi
if [ -f yarn.lock ]; then PM=yarn; fi
if [ -f package-lock.json ]; then PM=npm; fi
if [ -f poetry.lock ]; then PM=poetry; fi
if [ -f pyproject.toml ] && [ -z "$PM" ]; then PM=pip; fi

# 过时依赖 + 漏洞扫描（按包管理器）
case "$PM" in
  pnpm|npm|yarn) $PM outdated 2>/dev/null | head -20; $PM audit --audit-level=high 2>&1 | tail -10 ;;
  poetry) poetry show --outdated 2>/dev/null | head -20 ;;
  pip) pip list --outdated 2>/dev/null | head -20 ;;
esac
```

### 3c. 文档同步（原 --docs，现在合并到标准）

- [ ] CLAUDE.md 是否 < 200 行？（`wc -l CLAUDE.md`）
- [ ] 技术栈版本与 package.json 一致？
- [ ] `.claude/rules/` 的 paths glob 是否仍然匹配实际文件？
- [ ] `docs/roadmap/` 与 CLAUDE.md 中 `@` 引用一致？
- [ ] `docs/specs/` 中是否有 `status: implementing` **超过 2 周** 且无相关 commit 的 stale spec？
- [ ] 是否有 `status: approved` 但**从未开始实施**的 spec？

### 3d. Git 状态

- [ ] 未提交文件数（> 20 → 提醒）
- [ ] 未推送 commit 数（提醒 push）
- [ ] 是否有 WIP commit 累积 > 3 天未整理？

## Step 4: `--deep` 额外检查

```bash
# 构建（从 Step 0 推断）
$BUILD_CMD 2>&1 | tail -5

# 测试覆盖率（从 Step 0 推断）
$TEST_CMD --coverage 2>&1 | tail -10
```

## Step 5: `--security` 专项安全

### 5a. 硬编码密钥扫描（优先 gitleaks）

```bash
# 优先用 gitleaks（更精准，误报低）
if command -v gitleaks &>/dev/null; then
  gitleaks detect --no-git --redact 2>&1 | tail -20
else
  # fallback 到 grep（不推荐，误报多）
  echo "⚠️ gitleaks 未安装，建议：brew install gitleaks"
  find . -type f \( -name "*.ts" -o -name "*.py" -o -name "*.java" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -exec grep -iE "(password|secret|api[_-]?key|token)\s*=\s*['\"][^'\"]+['\"]" {} + \
    2>/dev/null | grep -v "test\|spec\|example" | head -10
fi
```

### 5b. 环境文件检查

- [ ] `.env` 是否在 `.gitignore`？
- [ ] `.env.example` 是否存在（模板可复制）？
- [ ] 未跟踪的 `.env*` 文件列表（可能被误提交）

### 5c. 依赖漏洞高危

```bash
# 只看 high / critical 级别
case "$PM" in
  pnpm|npm|yarn) $PM audit --audit-level=high 2>&1 ;;
esac
```

## Step 6: 历史对比 + 输出报告

### 6a. 读取上次审计结果（如有）

```bash
LAST_REPORT=$(ls -t docs/reports/audit-*.md 2>/dev/null | head -1)
```

有则读取关键数值（CLAUDE.md 行数、过时依赖数、未提交文件数等）用于趋势对比。

### 6b. 写入本次报告

路径：`docs/reports/audit-YYYY-MM-DD.md`

内容：

```markdown
# 项目审计报告 - YYYY-MM-DD

**模式**: 标准 / --deep / --security

## 总览（含趋势对比）

| 维度 | 状态 | 数值 | 上次 | 趋势 |
|------|------|-----|------|------|
| 代码质量 | ✅/⚠️/❌ | [N] warnings | [M] | ↑/↓/→ |
| 依赖健康 | ✅/⚠️/❌ | [N] 过时 / [M] 高危 | ... | ... |
| 文档同步 | ✅/⚠️/❌ | CLAUDE.md [N] 行 | [M] | ... |
| Git 状态 | ✅/⚠️/❌ | [N] 未提交 / [M] 未推送 | ... | ... |

## 🔴 P0 立即处理
[Critical 问题]

## 🟡 P1 本周处理
[Warning 问题]

## 🟢 P2 有空再说
[Info 问题]

## 📈 趋势分析
[和上次对比：哪些恶化，哪些改善]
```

### 6c. AskUserQuestion 引导修复

**有问题** → 弹窗：

```
Question: 发现问题：P0 [X] 个 / P1 [Y] 个 / P2 [Z] 个。下一步？

Options:
1. (Recommended) 只看报告，我自己决定（报告已写入 docs/reports/）
2. 启动 /implement 批量修复（按 P0 → P1 → P2 顺序）
3. 只处理 P0（立即修复 Critical）
4. 生成 TODO 清单到 Roadmap（留给后续）
```

选 2/3 → 调用 /implement 批量模式执行修复。
选 1/4 → 仅输出报告。

## Step 7: 输出确认

```
✅ 审计完成（模式：标准 / --deep / --security）

━━━━━━━━━━━━━━━━━━━━━━━━
问题统计：P0 [X] / P1 [Y] / P2 [Z]
趋势：[恶化 / 持平 / 改善]（对比 [上次日期]）
━━━━━━━━━━━━━━━━━━━━━━━━

报告：docs/reports/audit-YYYY-MM-DD.md
下一步：[根据弹窗选择输出]
```

</workflow>
````

**用法示例**：

```bash
# 日常 / PR 前 / 每周
/audit

# 大版本发布前（含构建 + 测试覆盖率）
/audit --deep

# 上线前 / 定期安全审计
/audit --security
```

**与相关命令的关系**：

| 场景 | 用哪个 |
|------|-------|
| 日常快速发现明显问题 | **`/audit`** |
| 深度逐文件检查代码-文档一致性 + 修文档 | `/docs`（文档生态守护者） |
| 代码架构量化评估（13 维度） | `/diagnose` |
| 发现问题后批量修复 | `/implement`（批量模式） |

> **/audit 不改代码**——只发现问题 + 弹窗询问修复策略。要修复走 `/implement`（代码）或 `/docs`（文档）。

---

### 2.2 /catchup — 工作上下文重建 + 下一步指引

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

### 2.3 /handoff — 会话状态快照 + 下次恢复桥梁

**用途**：会话中断前（/clear 之前 / 结束一天任务未完成 / 临时中断 / WIP 状态）生成结构化交接，供下次 /catchup 快速恢复。

**定位**：**状态快照 + 恢复桥梁**。承载"**git log 抓不到的软信息**"（决策/踩坑/下一步）+ "**叙事性预汇总**"（省 /catchup 的推理成本）。

**明确职责边界**：
- ✅ Commit 当前变更（不绕 Hook，失败弹窗询问）
- ✅ 勾 Roadmap checkbox（**副业**）
- ✅ 写 session-notes
- ❌ **不管 Spec frontmatter**（那是 /done 的职责——主业）
- ❌ **不跑 `--no-verify`**（绕 Hook 要用户明确授权）
- ❌ 不做代码验证（commit 存在即验证过）

**v3.22 变化**：
- **参数分流**：`/handoff`（完整）+ `/handoff quick`（精简，只填 2 段）
- **session-notes 结构化为 6 段 + 关联指针**（去掉纯数字统计、合并 Roadmap/Spec 状态到关联指针）
- **去掉 Spec frontmatter 更新**（职责归 /done）
- **去掉自动 --no-verify**（改为 AskUserQuestion 让用户决定）
- **新增文件 → AskUserQuestion multiSelect**（避免误 stage 临时文件）
- **commit message 复杂改动 → AskUserQuestion 列候选**（简单改动 Claude 直接判）
- **检测到 Gate 满足但未跑 /done → 提示先跑 /done**

**什么时候不需要 /handoff**：
- 任务完整 commit 了，明天从新功能开始（文档 00 Section 6 已说明）
- 会话中完全没做事

**文件路径**: `.claude/skills/handoff/SKILL.md`

````markdown
---
name: handoff
description: |
  会话状态快照 + 下次 /catchup 恢复桥梁。/clear 前或结束开发时使用。
  默认完整模式写 6 段 session-notes；`/handoff quick` 精简模式只填 2 段（适合短时间中断）。
  触发关键词：生成交接文档、我要关闭了、记录进度、handoff、/clear 前
argument-hint: "[quick | 空=完整]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
会话中断前的状态快照：commit 未提交变更 + 勾 Roadmap checkbox + 写 session-notes。
**不碰 Spec frontmatter**（归 /done），**不绕 Hook**（--no-verify 要用户授权）。
</task>

<workflow>

## Step 0: 明确模式 + 收集状态

读取 `$ARGUMENTS`：
- `quick` → 精简模式（仅填 session-notes 的 2 段必填字段）
- 空 → 完整模式（填 6 段 + 关联指针）

收集会话状态供后续使用（不展示给用户，仅内部参考）：

```bash
date '+%Y-%m-%d %H:%M'
git branch --show-current
git log --oneline -10
git status --short
git diff --stat HEAD 2>/dev/null | tail -5
```

## Step 1: 处理未提交变更

### 1a. 工作区干净 → 跳过到 Step 2

### 1b. 有未提交变更

**已修改文件**（`git status --short` 里 ` M` 开头）：Claude 读取并自动 stage（排除 `.env`、`*.log`、`node_modules/`、构建产物）。

**新增文件**（`??` 开头，unstaged）：**MUST 用 AskUserQuestion multiSelect 询问**，避免误 stage 临时文件：

```
Question: 发现未跟踪的新增文件，选择要提交的（多选）：

multiSelect: true

Options:
1. src/components/LoginForm.tsx
2. src/hooks/useAuth.ts
3. test.md   ← 看起来是临时文件？
4. notes.txt ← 看起来是临时文件？
```

用户勾选后 stage。

### 1c. 生成 commit message

**简单改动**（≤3 文件，单一主题）→ Claude 直接生成 Conventional Commits message。

**复杂改动**（≥4 文件 / 跨模块 / 多个主题）→ **AskUserQuestion 询问**：

```
Question: 本次变更跨多个模块/主题，commit message 建议：

Options:
1. (Recommended) feat(auth): 实现 JWT 刷新机制
2. feat: 添加认证相关代码（auth + api + frontend）
3. 拆成多个 commit（Tidy First）
4. 自定义（自由输入）
```

选 3 → Claude 按 Tidy First 拆 commit（结构先、行为后，详见 /implement Step 5）。

### 1d. 执行 commit

```bash
git commit -m "<message>"
```

**失败处理**（Hook 拦下，exit code 2）→ **MUST 用 AskUserQuestion 询问**（不自动 --no-verify）：

```
Question: commit 被 Hook 拦下（测试/lint 未通过）。如何处理？

Options:
1. (Recommended) 返回编辑修复（取消本次 /handoff）
2. 只写 session-notes 记录未提交状态（不 commit）
3. 强制跳过 Hook（--no-verify，会留下未验证的 commit 在历史中）
4. 自定义
```

选 1 → 停止 /handoff，用户去修复。
选 2 → 跳过 commit，继续 Step 2-3（session-notes 里标注"工作区有未提交变更"）。
选 3 → 仅在用户明确选择时才 `--no-verify`，message 前缀 `wip:`。

## Step 2: Roadmap 更新（副业）

**只更新 checkbox，不碰 Spec frontmatter**（那是 /done 的主业）。

如果 `docs/roadmap/` 存在：
1. 读取 `docs/roadmap/README.md` 确定当前 Phase
2. 读取当前 Phase 文件
3. 根据本次会话已完成的工作，**仅**更新 checkbox：
   - 已完成：`- [ ]` → `- [x] ✅ YYYY/MM/DD`
   - 进行中：`- [ ]` → `- [-] 🏗️ YYYY/MM/DD`
4. 更新 README.md 进度统计（如 `2/5` → `3/5`）
5. 当前 Phase 全部完成 → 状态改为 `✅ 完成`

**MUST NOT**：
- 不添加新条目（新功能需用户明确要求）
- 不碰 `docs/specs/` 的 frontmatter（active_phase / status / Gate）

### Step 2b: Gate 满足但未 /done 检测

扫描 `docs/specs/` 中 `status: implementing` 的 spec：
- 检查当前 `active_phase` 的 Tasks 是否全勾 `[x]`
- Gate 条件是否全部满足

**检测到 Gate 已满足但 active_phase 未推进** → 提示（不阻塞）：

```
⚠️ 检测到 docs/specs/user-auth.md 的 Phase 2 Gate 已满足，但未推进到 Phase 3。
建议先执行 `/done <描述>` 再 /handoff，以正确推进 Spec 进度。

是否继续 /handoff？
```

AskUserQuestion：
```
Options:
1. 先跑 /done 再 handoff（推荐）
2. 继续 handoff（稍后手动跑 /done）
```

### Step 2c: 提交文档变更

```bash
git add docs/roadmap/
git commit -m "docs: 勾选 Phase N [条目名] 完成"
```

## Step 3: 写 session-notes.md

### 完整模式（默认）

写 6 段 + 关联指针到 `.claude/session-notes.md`：

```markdown
# 会话交接文档

**生成时间**: YYYY-MM-DD HH:MM
**分支**: [branch-name]
**模式**: 完整 / quick

## 🔗 关联指针（/catchup 可快速定位）
- Spec: docs/specs/user-auth.md (Phase 2, status: implementing)
- Roadmap: phase-2.md - "用户认证模块" (3/5)
- 最近 commits:
  - abc1234 feat(auth): 实现 JWT 刷新端点
  - def5678 feat(web): 集成 axios 拦截器
  - ...（最多 5 个）

## 📝 本次会话做了什么（叙事摘要）
[一段话概括，让 /catchup 无需读 5 个 commit message 推理]
今天完成了 JWT 刷新 Token 机制：实现了 /auth/refresh 端点
（apps/api/auth/refresh.py）、集成了前端 axios 拦截器
（apps/web/src/lib/api.ts）、补了集成测试（tests/auth/...）。

## 🎯 下一步具体动作（MUST 有，供 /catchup 弹窗候选）
- 优先级 1：实现 refreshToken revoke 机制（apps/api/auth/revoke.py）
- 优先级 2：前端 401 自动刷新拦截器（apps/web/src/lib/api.ts:L120）
- 优先级 3：...

## 🧠 关键决策（git log 不写的软信息）
- 选 refresh token 方案而非 session — 支持移动端
- Token 有效期 7 天，refresh 30 天 — 平衡安全与体验

## 🕳️ 踩过的坑（避免重犯）
- 中间件顺序要在路由之前注册，否则不生效
- CORS 要加 X-Refresh-Token 响应头，前端才能读到

## ⚠️ 注意事项 / 临时 TODO
- refresh token revoke 还没实现（非本 Spec 范围）
- 可能需要前端 401 自动刷新拦截器
```

### 精简模式（`quick`）

只填 2 段必填：

```markdown
# 会话交接文档（quick）

**生成时间**: YYYY-MM-DD HH:MM
**分支**: [branch-name]
**模式**: quick

## 🔗 关联指针
- [spec/roadmap 如有，Claude 自动填]
- 最近 commits: [最多 3 个]

## 📝 本次会话做了什么
[一句话]

## 🎯 下一步具体动作
- [1-3 条]

---
*其他字段（决策/坑/注意事项）quick 模式不强制，如有就写*
```

## Step 4: 输出确认

```
✅ 交接完成（模式：完整 / quick）

━━━━━━━━━━━━━━━━━━━━━━━━
提交状态：
  ✅ 正常 commit: feat(auth): ...
  / ⚠️ 只记录未提交状态（Hook 拦下，用户选择不 --no-verify）
  / 🏷️ WIP commit（--no-verify，用户明确授权）
  / ⏭️ 无变更

Roadmap：
  ✅ 勾选 Phase N "[条目]" / ⏭️ 无关联

Spec Gate 检测：
  ⚠️ 检测到 Gate 满足但未 /done，建议跑 /done 再关闭
  / ✅ 无待推进的 Spec

交接文档：
  .claude/session-notes.md (6 段 / 2 段 quick)
━━━━━━━━━━━━━━━━━━━━━━━━

下次会话运行 /catchup 可快速恢复上下文。
```

</workflow>
````

**用法示例**：

```bash
# 完整模式（默认）：结束一天、WIP 中断、跨天恢复
/handoff

# 精简模式：上下文满了要 /clear，短时间内会 /catchup
/handoff quick
```

**与相关命令的职责边界**：

| 场景 | 用哪个 |
|------|-------|
| 会话中断前保存状态 + 写 session-notes | **`/handoff`** |
| 完成功能后做交付检查（测试/Roadmap/Spec 状态） | `/done` |
| /clear 之后恢复上下文 | `/catchup` |

**/handoff vs /done 的 Roadmap/Spec 分工**：
- `/done`：**主业** — Phase 进度引擎（active_phase / status / Gate 验证）+ Roadmap checkbox
- `/handoff`：**副业** — 只勾 Roadmap checkbox（**不碰** Spec frontmatter）

**什么时候不需要 /handoff**：
- 任务完整 commit 了，明天从新功能开始（详见文档 00 Section 6）
- 会话中完全没做事

---

### 2.4 /spec — 讨论成果整理为执行契约

**用途**：需求讨论到一定程度后，将对话中的讨论成果整理为**结构化执行契约**，持久化到 `docs/specs/` 目录。支持增量更新（跨多次上下文持续完善同一份 spec）。

**定位**：**Spec 是执行契约（Execution Contract）**，不是 PRD、RFC 或 ADR。它承载"做什么 + 怎么验证完成"，用 Phase + 可机器判定的 Gate 条件驱动 /implement 和 /done 的自动化流程。

### 文档边界（Spec vs 其他）

| 文档类型 | 定位 | 写入时机 |
|---------|------|---------|
| **PRD** | 问题是什么（产品视角） | 立项阶段 |
| **RFC** | 提议方案征求评审 | 方案争议大时 |
| **ADR** | 已达成的架构决策（不可变事后记录） | 关键决策发生时，**不合并进 spec** |
| **Design Doc**（Google 风格）| 实施细节 + 风险 / trade-off | 讨论成熟后 |
| **Spec**（本命令产出） | **执行契约**：需求 + 方案 + 可机器判定的 Gate | 讨论方向已定，准备实施前 |

> **关键原则**：ADR 另外写，不合并进 spec——ADR 的**不可变性**是其核心价值，和 spec 的"活文档"属性冲突。spec 里可以**引用 ADR 链接**。

### 设计参考

- **EARS 句式**（Rolls-Royce 2009，Kiro 2025 产品化）——`[manual]` Gate 条件用
- **Fitness Functions**（Neal Ford《Building Evolutionary Architectures》）——架构特性可执行化思路
- **GitHub Spec Kit** + **Kiro**：业界参考，但本命令保持**单文件 + 更轻**
- **Brooker 2026-04**："spec 是被迭代的对象"——支持 draft → approved 的迭代流程

### v3.23 重要变化

- **Gate 三类型标注**：`[auto: <观察表达式>]` / `[command: <shell>]` / `[manual]` + EARS 句式
  - **关键**：`[auto]` 必须映射到**可观察事实**（Claude 只读不判断），避免"AI 自证清白"
- **使用时机流程图**：明确**初稿时机**（方向定了即可写）vs **定稿时机**（实施前 approved）
- **文档边界声明**：Spec vs PRD/RFC/ADR/Design Doc
- **AskUserQuestion**：分歧确认 / Roadmap 关联 / status 切换
- **frontmatter 精简**：去掉冗余 `phase` 字段

### 使用时机流程图

```
讨论需求（多轮，方向逐渐明确）
  ↓
方向已定（细节可留待后续）
  ↓
/spec <name>              ← 【初稿时机】status: draft
  ↓
┌────────────────────────────────────┐
│ 讨论仍在继续？                       │
│   ├── 是 → 继续讨论                 │
│   │         ↓                      │
│   │       /spec <name>（增量更新）  │
│   │         （重复此循环）           │
│   └── 否 → 确认方案                 │
│             ↓                      │
│           /spec <name> 确认          │
│             ↓                      │
│           【定稿时机】status: approved │
└────────────────────────────────────┘
  ↓
/clear
  ↓
开始实施（/implement 或 Phase 1）
```

**关键原则**（不要这样用）：
- ❌ 不要每轮讨论都跑 /spec（太频繁，增量价值有限）
- ❌ 不要讨论没有共识就 /spec（会写出充满 TODO 的半成品）
- ❌ 不要用 /spec "强制开始讨论"——它是讨论的**结果**，不是触发器

**文件路径**: `.claude/skills/spec/SKILL.md`

````markdown
---
name: spec
description: |
  将讨论成果整理为结构化执行契约（Spec），写入 docs/specs/ 目录。
  支持增量更新（跨多次对话持续完善）。
  Spec 定位：执行契约（不是 PRD/RFC/ADR），含可机器判定的 Gate 条件。
  触发关键词：整理讨论、写 spec、保存设计、记录方案
argument-hint: "[功能名称] [可选：确认 → status 改为 approved]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
将当前对话的讨论成果整理为 Spec（执行契约）。
- 新建时：写入 docs/specs/<name>.md（status: draft）
- 已存在时：增量合并新讨论
- 用户说"确认"时：status → approved

MUST 原则：
1. 每个 Gate 条件带类型标注（[auto: 表达式] / [command: shell] / [manual]）
2. [auto] 必须映射到可观察事实，Claude 只读不判断
3. [manual] 用 EARS 句式（减少含糊）
4. 不合并 ADR 内容（引用即可）
</task>

<workflow>

## Step 0: 确定文件名和模式

读取 `$ARGUMENTS`：
- `/spec user-auth` → 文件名 `user-auth.md`，新建或增量
- `/spec user-auth 确认` → 已存在的 spec，status 切换为 approved（进入 Step 5b）
- 无参数 → 根据讨论主题自动命名（kebab-case）

判断模式：
- 文件不存在 → **新建模式**（Step 3a）
- 文件已存在 → **增量更新模式**（Step 3b）

```bash
mkdir -p docs/specs
```

## Step 1: 收敛讨论成果

### 1a. 共识与分歧梳理

先输出总结：

```
📋 讨论收敛：
✅ 共识：[2-5 条核心决定]
⚠️ 待定：[尚未敲定的点，如有]
```

**有待定项 → AskUserQuestion**：

```
Question: 讨论中有 [N] 项待确认：
- [分歧 A]
- [分歧 B]

Options:
1. 现在逐一确认（你回答后 Claude 继续整理）
2. 标记为 draft，这些点后续讨论（Spec 里用 TODO 标出）
3. 按 Claude 建议方案写入（自担风险）
```

### 1b. 提取讨论内容

按需提取（**没有的不写**）：

- 功能背景与目标
- 需求要点和验收标准
- 讨论过的方案及取舍理由
- 最终确定的设计方案
- UI/交互设计
- API 设计
- 数据模型
- 业务逻辑
- 调研发现
- 约束条件

## Step 2: 规划 Implementation Phases

拆分为 **2-5 个 Phase**，每个 Phase 必须：

- **独立可交付**：完成后有可验证产出
- **独立可验证**：有**可机器判定**的 Gate 条件
- **规模合理**（对齐 /implement 硬阈值）：
  - 控制在 3-5 文件改动范围
  - 避免单 Phase 同时跨模块 + 新依赖 + 改数据流
  - 超出 → 拆两个 Phase

拆分策略：
- **纵向**：数据层 → API 层 → UI 层（后端优先）
- **横向**：独立模块并行（各模块无强依赖时）
- **简单功能**（预估 < 30 分钟）：1 个 Phase 即可

## Step 3: 写入 Spec 文件

### Step 3a: 新建模式

写入 `docs/specs/<name>.md`：

```markdown
---
title: [功能名称]
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
total_phases: 3
active_phase: 1
---

# [功能名称] — 执行契约（Spec）

> 这是 **Spec（执行契约）**，不是 PRD / RFC / ADR。
> ADR 链接（如有）：[docs/architecture/adr/XXXX-xxx.md]

## 背景与目标

[为什么做，解决什么问题]

## 需求概要

[核心功能点 + 验收标准]

## 设计方案

### 讨论过的方案

[方案 A vs B vs C，各自优缺点，最终选择理由]

### 最终方案

[确定的技术/设计方案]

## 详细设计

（以下模块按需包含，没有的不写）

### UI/交互设计
[页面布局、组件、交互流程]

### API 设计
[端点列表、请求/响应格式]

### 数据模型
[表结构、字段、关系]

### 业务逻辑
[核心处理流程、边界情况]

## 调研记录
[联网搜索、技术选型依据]

## 约束与注意事项
[性能、安全、兼容性、已知限制]

## Implementation Phases

### Phase 1: [名称，如"数据模型与迁移"]

**Tasks**:
- [ ] 定义 User/Token 模型（apps/api/models/auth.py）
- [ ] 创建迁移脚本
- [ ] 补单元测试

**Gate（全部满足才算完成，/done 验证）**:
- [ ] Tasks 全部勾选                              [auto: phase.tasks.unchecked == 0]
- [ ] 单元测试通过                                [command: pnpm test apps/api/models/auth]
- [ ] 无 lint error                              [command: pnpm lint apps/api/models]
- [ ] While 数据库已迁移, when 查询 User, the 系统 shall 返回正确 schema    [manual]

**On Complete**: active_phase → 2，建议 /done

### Phase 2: [名称，如"API 端点实现"]

**Tasks**:
- [ ] /auth/login 端点
- [ ] /auth/refresh 端点
- [ ] 集成测试

**Gate**:
- [ ] Tasks 全部勾选                              [auto: phase.tasks.unchecked == 0]
- [ ] 集成测试通过                                [command: pnpm test tests/auth/]
- [ ] While 用户已注册, when POST /auth/login 正确凭据, the API shall 返回 200 + token  [manual]

**On Complete**: active_phase → 3，建议 /done

### Phase 3: [名称，如"前端 UI 集成"]

**Tasks**:
- [ ] 登录页面
- [ ] axios 拦截器
- [ ] E2E 测试

**Gate**:
- [ ] Tasks 全部勾选                              [auto: phase.tasks.unchecked == 0]
- [ ] E2E 测试通过                                [command: pnpm test:e2e auth]
- [ ] While 未登录, when 访问受保护页面, the 系统 shall 重定向到 /login  [manual]

**On Complete**: 所有 Phase 完成，建议 /done + /release（如 Roadmap Phase 也完成）
```

#### Gate 条件的 3 种类型

| 类型 | 语法 | 说明 | 示例 |
|------|------|------|------|
| **`[auto: <表达式>]`** | 可观察事实的表达式 | /done 读取文件/spec 验证，**Claude 只读不判断** | `[auto: phase.tasks.unchecked == 0]` |
| **`[command: <shell>]`** | shell 命令 | /done 执行，exit code 0 = 通过 | `[command: pnpm test tests/auth/]` |
| **`[manual]`** + EARS 句式 | While X, when Y, the Z shall W | /done 弹窗询问用户验证 | `[manual] While 用户已登录, when 点击登出, the 系统 shall 清除 token` |

**为什么三类型**：
- `[auto]` 避免"AI 自证清白"（Martin Fowler 对纯 AI 判断的质疑）
- `[command]` 是相对 Kiro/spec-kit 的**独特增量**——Gherkin 纯文本仍是"AI 解释"，shell 命令是真正的机器判定
- `[manual]` 用 EARS 句式（Rolls-Royce 2009）减少"怎么算验证通过"的含糊

**EARS 五种模式**（`[manual]` 可用）：
- **Ubiquitous**: `The <system> shall <response>`
- **Event-Driven**: `When <trigger>, the <system> shall <response>`
- **State-Driven**: `While <precondition>, the <system> shall <response>`
- **Unwanted**: `If <unwanted condition>, then the <system> shall <mitigation>`
- **Optional**: `Where <feature>, the <system> shall <response>`

### Step 3b: 增量更新模式

已存在的 spec 追加新讨论成果：
- 保留已有内容不删除
- 新讨论融入对应章节
- 更新 frontmatter 的 `updated` 日期
- 推翻之前的结论 → 更新内容 + 在"讨论过的方案"记录变更原因
- Phases 已完成 `[x]` 的状态**不动**
- Gate 条件如果有升级（如从自由格式升级为类型标注） → 同步补充类型标注

## Step 4: Roadmap 关联（AskUserQuestion）

检查 `docs/roadmap/` 是否有对应条目：

**找到** → 在 spec 头部标注：`关联 Roadmap: phase-2.md - "用户认证模块"`
**未找到** → AskUserQuestion：

```
Question: 未在 Roadmap 找到对应条目，是否添加？

Options:
1. (Recommended) 添加到当前 Phase
2. 添加到下一个 Phase
3. 不添加（spec 独立存在）
```

## Step 5: 状态判断

### 5a. 默认首次生成 → status: draft

不主动推断用户意图。

### 5b. 用户明确"确认" → AskUserQuestion 确认

当 `$ARGUMENTS` 包含"确认"或生成后用户表示要确认：

```
Question: 当前 status: draft，是否切换为 approved？

Options:
1. (Recommended) approved（方案已定，可以开始实施）
2. 保持 draft（还想继续讨论某部分）
3. 保持 draft + 补充某个模块（自由输入要补的部分）
```

选 1 → frontmatter status: draft → approved + 更新 updated 日期

### 状态生命周期

```
draft → approved → implementing → implemented
                                      ↓
                              [deprecated | superseded]
```

| status | 含义 | 触发时机 |
|--------|------|---------|
| `draft` | 讨论中 | /spec 首次生成 |
| `approved` | 方案已确认，可实施 | 用户明确确认 |
| `implementing` | 实施中 | Claude 基于 spec 开始编码时自动切换 |
| `implemented` | 已完成 | /done 推进所有 Phase 后 |
| `deprecated` | 已弃用 | 手动（技术/业务变化，不再实施） |
| `superseded` | 被替代 | 手动（新 spec 取代，frontmatter 注明替代文件） |

## Step 6: 输出确认

```
✅ Spec 已生成/更新

文件：docs/specs/<name>.md
状态：draft / approved / implementing / implemented
Phases：[N] 个（active_phase: [M]）
Gate 类型分布：[auto] X 条 / [command] Y 条 / [manual] Z 条
关联 Roadmap：[有 phase-X.md "[条目]" / 无]

建议下一步（按状态）：
- draft → 继续讨论 → 再次 /spec <name> 增量更新
- draft → 确认方案 → /spec <name> 确认（切换到 approved）
- approved → /clear 后 "读取 docs/specs/<name>.md，开始实施 Phase 1"
  （每次只实施一个 Phase，完成 Gate 后 /done 推进）
```

</workflow>
````

**用法示例**：

```bash
# 首次生成
/spec user-auth

# 增量更新（多轮讨论后再次整理）
/spec user-auth

# 确认方案（status: draft → approved）
/spec user-auth 确认
```

**与相关命令的关系**：

| 阶段 | 命令 | 做什么 |
|------|------|-------|
| **讨论** | （对话） | 多轮讨论需求/方案 |
| **整理** | **`/spec`** | 讨论成果 → 执行契约 |
| **实施** | `/implement` | 按 Phase 执行单个改动 |
| **收尾** | `/done` | 验证 Phase Gate（三类型），推进 active_phase / status |
| **发版** | `/release` | Roadmap Phase 完成后发版 |

> **`/spec` 不做代码验证**——那是 /done 的职责（见 2.7 Step 4）。

---

### 2.5 /implement — 有纪律的单改动实施

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

### 2.6 /done — 功能交付检查清单

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

### 4a. Phase Gate 验证（支持三类型标注，v3.23）

读取当前 `active_phase` 的 Gate 条件。**解析每个 Gate 条件的类型标注**（详见文档 03 Section 2.5 的 Gate 三类型），按类型分别验证：

#### 类型 1：`[auto: <表达式>]` — 读取可观察事实

Claude **只读取不判断**，映射到具体可观察事实。

常见表达式：
| 表达式 | 验证方式 |
|--------|---------|
| `phase.tasks.unchecked == 0` | 读 spec 文件，当前 Phase 的 `- [ ]` 数量是否为 0 |
| `grep -q 'TODO' spec.md && exit 1` | spec 里无 TODO 标记 |
| `file.exists: apps/api/auth/login.py` | 指定文件存在 |

#### 类型 2：`[command: <shell>]` — 执行命令

```bash
# 直接执行 shell，exit code 0 = 通过
<shell 命令>
echo "exit: $?"
```

通过条件：exit code == 0。
示例：
- `[command: pnpm test tests/auth/]` → 跑 `pnpm test tests/auth/`
- `[command: pnpm lint apps/api/auth/]` → 跑 lint

#### 类型 3：`[manual]` + EARS 句式 — 弹窗询问

用户视觉验证类条件（如"While 用户已登录, when 点击登出, the 系统 shall 清除 token"），/done **MUST 用 AskUserQuestion** 询问：

```
Question: 请验证 Manual Gate 条件：

[EARS 句式，如 "While 用户已登录, when 点击登出, the 系统 shall 清除 token 并跳转首页"]

Options:
1. ✅ 已验证通过
2. ❌ 未通过（说明原因）
3. ⏭️ 跳过（暂不验证，记为"未验证"）
```

#### 汇总判定

所有 Gate 条件全部通过 → **Gate 通过**：
1. 更新 frontmatter `active_phase` → 下一个 Phase
2. 更新 `updated` 日期
3. 检查 `active_phase > total_phases`？
   - **否** → 记录"Phase N 完成，进入 Phase N+1"
   - **是（所有 Phase 完成）** → 进入 4b

**Gate 未通过** → 输出未满足的条件列表（分类型），AskUserQuestion 询问：
```
Options:
1. 返回修复未通过的条件（取消 /done 推进）
2. 强制推进（自担风险，未通过条件记录到 spec 的"遗留"段）
```

#### 兼容旧格式（无类型标注）

遇到旧 spec 的 Gate 条件没有类型标注（如 `- [ ] 相关测试通过`）：
- 视为 `[manual]` 类型
- 弹窗询问用户
- 建议用户下次运行 /spec 时补类型标注（/spec 增量更新会识别并升级）

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

### 2.7 /docs — 文档生态守护者

**用途**：对照代码实际状态，对项目所有文档做**四种操作**——更新 / 新增 / 删除 / 审计一致性。**不只局限于更新**——发现代码有文档没有 → 新增；文档还在代码没了 → 删除；spec/ADR 描述对不上代码 → 更新或标记失效。

**定位**：**文档生态守护者**。职责范围覆盖 `CLAUDE.md`、`docs/architecture/`、`docs/development/`、`docs/specs/`、`docs/architecture/adr/` 等所有文档。核心原则：**文档必须反映代码实际状态**。

### 四种操作

| 操作 | 触发条件 | 举例 |
|------|---------|------|
| **更新** | 文档描述和代码不一致 | CLAUDE.md 技术栈版本过时 |
| **新增** | 代码有了但文档没有 | 新增模块但架构文档没写 |
| **删除** | 文档还在但代码没了 | 旧组件已删除但文档还引用 |
| **审计一致性** | 跨文档交叉验证 | spec 描述 vs 代码实现、ADR 是否仍生效、Gate `[command]` 是否可执行 |

### v3.25 重要变化

- **定位扩展**：从"开发文档梳理"扩展为"文档生态守护者"（四种操作）
- **合并 /deep-audit 功能**（已废弃）：逐文件代码-文档一致性审计、spec/ADR 审计、历史对比
- **Gate 可执行性检查**（v3.23 对接）：每个 `implementing` / `implemented` 的 spec 的 `[command]` Gate 条件是否仍能跑
- **AskUserQuestion 修改前审核**：发现大量改动（>10 处）时弹窗让用户审核
- **历史对比**：保留 `docs/reports/docs-YYYY-MM-DD.md`，下次对比趋势
- **默认不 push**（从 /deep-audit 继承的修复）

### 和 /audit、/diagnose 的分工

| 维度 | 命令 | 做什么 |
|------|------|-------|
| **代码质量 + 依赖 + 安全** | `/audit` | 浅层巡检发现明显问题（不改代码/文档）|
| **文档一致性**（含 spec/ADR） | **`/docs`** | 四种操作守护文档生态（改文档）|
| **架构健康** | `/diagnose` | 13 维度量化 + 重构计划（不改代码）|

**文件路径**: `.claude/skills/docs/SKILL.md`

````markdown
---
name: docs
description: |
  文档生态守护者：对照代码实际状态，对所有文档做更新 / 新增 / 删除 / 审计一致性。
  覆盖 CLAUDE.md、架构文档、开发文档、spec、ADR 等所有文档。
  Gate 可执行性检查、spec 描述 vs 代码对齐、历史趋势对比。
  触发关键词：更新文档、梳理文档、docs、架构梳理、文档同步、文档审计、spec 一致性
argument-hint: "[架构范围 | audit | 空=全量]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
对项目所有文档执行"文档生态守护"：
1. 扫描代码实际状态 + 对比所有文档（architecture / development / specs / ADR / CLAUDE.md）
2. 识别四种操作：更新（不一致）/ 新增（代码有文档缺）/ 删除（文档有代码缺）/ 审计（spec-code、ADR 有效性、Gate 可执行性）
3. 改动 >10 处 → AskUserQuestion 审核；≤10 处直接修
4. 只改文档，**不改代码**（代码问题输出到报告让 /implement 修）
5. **不自动 push**
</task>

<workflow>

## Step 0: 确定范围

解析 `$ARGUMENTS`：

| 参数 | 执行范围 |
|------|---------|
| 无参数 | **全量守护**：所有四种操作 × 所有文档（architecture + development + specs + ADR + CLAUDE.md） |
| `architecture` | `docs/architecture/` 全部（README + frontend + backend） |
| `frontend` | `docs/architecture/frontend.md` |
| `backend` | `docs/architecture/backend.md` |
| `getting-started` | `docs/development/getting-started.md` |
| `deployment` | `docs/development/deployment.md` |
| `audit` | **深度审计模式**：专注 spec-code 一致性、ADR 有效性、Gate 可执行性（不改架构文档） |

```bash
mkdir -p docs/architecture docs/development docs/reports
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

读取对应的现有文档文件（如存在），标记**四种操作**：
- ✅ 仍然准确的内容（**保持**）
- ⚠️ 需要**更新**的内容（代码已变但文档未同步）
- ❌ 需要**删除**的内容（文档还在但代码已删除 / 过时引用）
- 🆕 需要**新增**的内容（代码中有但文档中缺失）

**变更覆盖检查**（基于 Step 1 锚定结果）：
逐一检查 Step 1 中每个变更模块，确认文档是否覆盖：
- 新增的文件/模块 → 文档是否提及？（如缺 → 🆕 新增）
- 新增的机制/流程（从 commit message 的 `feat:` / `refactor:` 识别）→ 文档是否描述？
- 删除/重构的功能 → 文档是否还在引用已不存在的内容？（如是 → ❌ 删除）

未覆盖的变更 MUST 在 Step 5 中补充到对应文档。

## Step 4: Spec / ADR / Gate 审计（全量模式或 `audit` 模式）

**仅在无参数（全量）或 `audit` 参数时执行**。架构/frontend/backend/getting-started/deployment 单独参数时跳过。

### 4a. Spec 描述 vs 代码实现一致性

扫描 `docs/specs/` 所有 `status: implementing` 或 `status: implemented` 的 spec：

对每个 spec：
- **spec 里提到的模块/文件/函数是否仍存在**？
  ```bash
  # 提取 spec 里引用的路径（如 apps/api/auth/login.py）
  grep -oE '[a-zA-Z_/]+\.(ts|tsx|py|java)' docs/specs/<name>.md | sort -u
  # 逐一验证文件是否存在
  ```
- **spec 里的设计方案是否和代码实现一致**？（读 spec 的"最终方案"段，对比实际代码）
- **spec 里描述的数据流/状态机是否仍然有效**？

**不一致 → 询问用户**：
- spec 过时 → 更新 spec 描述对齐代码
- 代码偏离 spec → 输出到报告，建议用户用 /implement 修代码（不在本命令修）

### 4b. ADR 有效性检查

扫描 `docs/architecture/adr/` 所有 ADR：

- **ADR 里的决策是否仍在代码中生效**？（如 "MUST 使用 Zustand 而非 Redux" → grep `redux` 看有无违反）
- **ADR 提到的技术/库是否仍在项目中**？（package.json / pyproject.toml）
- **有没有代码违反 ADR 约定**？

**发现违反 → 询问**：
- ADR 已不再适用 → 标记为 `deprecated` 或 `superseded`（不直接删，保留历史）
- 代码违反 ADR → 输出报告让 /implement 修复

### 4c. Gate `[command]` 可执行性检查（v3.23 对接）

扫描 `docs/specs/` 中的 Gate 条件，提取 `[command: <shell>]` 类型：

```bash
# 提取所有 [command: xxx] 条件
grep -oE '\[command: [^]]+\]' docs/specs/*.md
```

对每个 `[command]` 条件：
- 试跑一次（`--dry-run` 模式或加 `echo` 前缀）看命令是否仍存在、参数是否仍有效
- 如命令已失效（如引用的测试文件路径不存在）→ 标记为 stale，提示用户更新 spec

**不自动修**——输出到报告，在 Step 5 询问用户。

## Step 5: 增量更新

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

## Step 6: AskUserQuestion 审核（改动 >10 处时）

统计 Step 3-5 识别的总改动数（更新 + 新增 + 删除）。

**改动 ≤10 处** → 直接执行修改（Step 7）。

**改动 >10 处** → **MUST 用 AskUserQuestion 让用户审核**：

```
Question: 检测到 [X] 处文档需要修改：
- 更新 [Y] 处（文档对不上代码）
- 新增 [Z] 处（代码有文档缺）
- 删除 [W] 处（文档引用已删除的代码）
- spec/ADR/Gate 审计问题 [V] 处

如何处理？

Options:
1. (Recommended) 全部修（我已 review 报告）
2. 只修 P0（只改明显过时 + 代码已删除引用）
3. 只生成报告（完全手动处理）
4. 自定义范围（自由输入）
```

报告路径：`docs/reports/docs-YYYY-MM-DD.md`（含完整改动清单，供用户 review）。

## Step 7: 执行修改 + 提交

根据用户选择执行修改。精确 `git add` 相关目录：

```bash
git add docs/architecture/ docs/development/ docs/specs/ docs/architecture/adr/ CLAUDE.md
git commit -m "docs: [实际变更描述]"
```

**commit message 按实际变更动态生成**：
- 主要是架构文档更新 → `docs: 同步架构文档（[模块] 新增 / 更新 [N] 处）`
- 主要是 spec/ADR 审计 → `docs: spec-code 一致性审计修复（[N] 处）`
- 混合 → `docs: 文档生态守护 — [N] 处更新 + [M] 处新增 + [W] 处删除`

**MUST NOT `git push`**——push 必须用户显式要求。

## Step 8: 输出报告

```
✅ 文档生态守护完成（范围：[全量 / architecture / audit / ...]）

━━━━━━━━━━━━━━━━━━━━━━━━
变更锚定：基于 [hash] 以来 [N] 个 commit / 首次运行（全量探索）

四种操作统计：
- 更新 [Y] 处 ✅
- 新增 [Z] 处 ✅
- 删除 [W] 处 ✅
- 审计问题 [V] 处（spec-code / ADR / Gate）
━━━━━━━━━━━━━━━━━━━━━━━━

文档改动清单：
- CLAUDE.md: [新建 / 更新 N 处 / 无变更]
- docs/architecture/README.md: [新建 / 更新 N 处 / 无变更]
- docs/architecture/frontend.md: ...
- docs/architecture/backend.md: ...
- docs/development/getting-started.md: ...
- docs/development/deployment.md: ...
- docs/specs/: [审计 N 个 spec，修复 M 处]
- docs/architecture/adr/: [审计 N 个 ADR，标记 M 个 deprecated]

历史趋势：
- 上次审计 [日期]：X 处问题
- 本次：Y 处问题（↑恶化 / →持平 / ↓改善）

需用户关注（代码问题，/docs 未修）：
- [列出需要用 /implement 修的代码不一致项]

报告：docs/reports/docs-YYYY-MM-DD.md
下一步：git push（如需）/ /implement 修复代码不一致项
```

</workflow>
````

**用法示例**：

```bash
# 全量守护（四种操作 + 全文档）
/docs

# 只刷新架构文档
/docs architecture

# 只做 spec/ADR/Gate 审计（不碰架构文档）
/docs audit

# 按子范围
/docs frontend
/docs deployment
```

**与相关命令的关系**：

| 场景 | 用哪个 |
|------|-------|
| 日常快速发现明显问题 | `/audit`（浅层）|
| 守护文档生态（更新/新增/删除/审计一致性） | **`/docs`** |
| 代码架构量化评估 | `/diagnose` |
| Phase 完成后发版（含 /docs 全量） | `/release` |
| 发现代码问题批量修复 | `/implement`（批量模式）|

> **/docs 只改文档**——代码问题（spec 描述对不上代码等）会输出到报告，由 /implement 修复。**默认不 push**。

---

### 2.8 /release — Phase 里程碑工作流（可选对外发版）

**用途**：Roadmap Phase 所有功能完成后的**里程碑工作流**。两种模式：
- `/release`（默认）= **Phase 内部里程碑**：文档刷新 + ADR 检查 + Roadmap 状态 + 内部 Changelog
- `/release --publish` = **Phase + 对外发版**：上面的 + 版本号升级 + git tag + 对外 Changelog

**定位**：**Phase 里程碑工作流（含可选对外发版）**。区分两件事：Phase 完成（内部里程碑）和对外发版（外部里程碑）——大多数 Phase 完成**不需要**对外发版，所以默认只做内部里程碑。

### 使用时机

**应该用**：
- `/done` Step 7 弹窗告知 "Roadmap Phase N 全部完成！" → 执行 `/release`
- 用户主动：Phase 所有 checkbox 打勾后想整理文档推进 Roadmap
- 对外发版时：加 `--publish`

**不应该用**（明确排除）：
- Phase 没全部完成（/done 会拦住）
- 日常文档刷新（用 `/docs`）
- 代码质量检查（用 `/audit` 或 `/diagnose`）
- 临时 hotfix 发版（直接 `git tag` + 手动改 changelog，/release 太重）

### 和其他命令的链路

```
/implement → /done → /done Step 7 检测 Phase 完成 → 弹窗询问 /release
                                                        ↓
                                                  /release（模式 A 默认）
                                                        ↓
                                              需要对外发版？→ /release --publish
```

### v3.27 重要变化

- **参数分流**：`/release`（默认 A）/ `/release --publish`（A+B 含版本号 + tag）
- **对接 v3.25 /docs 新流程**：从"6 步" → 现在是"无参全量守护 + 可选 /docs audit"
- **ADR 检查 AskUserQuestion**：对齐 v3.19 /implement 四类触发（跨模块依赖 / 替换实现 / 新依赖 / 数据流向）
- **版本号/tag 管理**（模式 B）：AskUserQuestion 让用户选 major/minor/patch
- **精确 git add**：不用 `git add docs/` 宽泛 stage
- **默认不 push**（对齐 v3.25 /docs）
- **Phase 开始日期三种 fallback**：Phase 文件 frontmatter → 上次 /release commit → 第一个 commit

**文件路径**: `.claude/skills/release/SKILL.md`

````markdown
---
name: release
description: |
  Phase 里程碑工作流（内部里程碑 + 可选对外发版）。
  默认模式：全量 /docs + ADR 检查 + Roadmap 状态 + 内部 Changelog。
  --publish 模式：加版本号 bump + git tag + 对外 Changelog。
  触发关键词：release、发版、Phase 完成、阶段完成、里程碑
argument-hint: "[--publish | 空=默认模式]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
Phase 里程碑工作流。
- 默认模式（A）：Phase 内部里程碑（文档 + ADR + Roadmap + 内部 Changelog）
- --publish 模式（A+B）：A + 对外发版（版本号 + tag + 对外 Changelog）

MUST 原则：
1. Phase 必须全部完成（checkbox 全勾）才能跑 /release
2. 不自动 push（push 必须用户明确要求）
3. 精确 git add（不用 `git add docs/` 宽泛 stage）
4. ADR/版本号/push 都用 AskUserQuestion 询问
</task>

<workflow>

## Step 0: 模式判断 + Phase 完成检查

解析 `$ARGUMENTS`：
- 无参数 → **模式 A**（Phase 内部里程碑）
- `--publish` → **模式 A+B**（加对外发版）

确认 Phase 范围：

```bash
cat docs/roadmap/README.md
ls docs/roadmap/
```

读取当前 Phase 文件，确认所有功能 checkbox 已勾选。

**有未完成条目 → AskUserQuestion**：
```
Question: 当前 Phase 还有 [N] 个未完成条目：
- [条目 A]
- [条目 B]

Options:
1. 停止 /release（先完成这些条目）
2. 忽略并继续（Phase 可能不完整）
3. 从 Phase 中移除这些条目（改为"不做"）
```

## Step 1: 全量文档守护（对接 v3.25 /docs）

执行 `/docs`（**无参数**，全量守护四种操作）：
- 更新（文档描述和代码不一致）
- 新增（代码有了但文档没有）
- 删除（文档还在但代码没了）
- 审计一致性（spec-code、ADR 有效性、Gate 可执行性）

详细流程见文档 03 Section 2.7 /docs（8 步）。

## Step 1b（推荐）: 深度 spec/ADR 审计

执行 `/docs audit` 专注深度审计：
- spec 描述 vs 代码实现一致性
- ADR 决策是否仍生效
- Gate `[command]` 可执行性

Phase 完成是跑深度审计的**最佳时机**——之后再跑要等下一个 Phase。

**AskUserQuestion 询问**：
```
Question: Phase 完成是深度文档审计的好时机。现在跑 /docs audit？

Options:
1. (Recommended) 现在跑（5-10 分钟，确保 spec/ADR 和代码对齐）
2. 跳过（之前刚跑过 / 本 Phase 没动 spec 和 ADR）
```

## Step 2: 收集 Phase 期间变更（为 Changelog 和 ADR 检查准备）

**确定 Phase 开始日期**（三种 fallback）：

```bash
# 1. 优先读 Phase 文件 frontmatter 的 created / started 字段
PHASE_START=$(grep -E "^(created|started):" docs/roadmap/phase-N-*.md | head -1 | cut -d' ' -f2)

# 2. 如无，用上次 /release commit 时间
if [ -z "$PHASE_START" ]; then
  PHASE_START=$(git log --oneline --all --grep="release:" | head -1 | awk '{print $1}' | xargs -I {} git show -s --format=%ci {} 2>/dev/null)
fi

# 3. 如无，用第一个 commit 时间（首个 Phase）
if [ -z "$PHASE_START" ]; then
  PHASE_START=$(git log --reverse --pretty=format:"%ci" | head -1)
fi
```

收集 Phase 期间的所有功能性提交：

```bash
git log --oneline --no-merges --since="$PHASE_START" \
  | grep -E "^[a-f0-9]+ (feat|fix|perf|refactor|chore)"
```

## Step 3: ADR 检查（AskUserQuestion + 四类触发）

扫描 Phase 期间 commit message，按 **v3.19 /implement 四类触发条件**识别可能需要 ADR 的决策：

| 触发条件 | 识别模式 |
|---------|---------|
| 新增跨模块依赖 | `refactor:` 跨模块重构 / commit 涉及跨多个顶层目录 |
| 替换已有实现 | `refactor:` 含 "替换" / "迁移" / "rewrite" / "rework" |
| 引入新第三方库 | `feat:` 或 `chore:` 涉及 package.json / pyproject.toml 新增依赖 |
| 改变数据流向 | `feat:`/`refactor:` 改 API 形状 / state 形状 / DB schema |

**检测到候选 → AskUserQuestion**：
```
Question: Phase 期间检测到 [N] 项可能需要记 ADR 的决策：
1. [commit hash] 引入 date-fns 替换 moment（模式：替换已有实现 + 新依赖）
2. [commit hash] 订单 status state 重构为状态机（模式：改变数据流向）

Options:
1. 全部生成 ADR 草稿（我 review 后提交）
2. 只为部分生成（自由输入编号）
3. 跳过（本 Phase 无需记录）
```

选 1/2 → Claude 按 ADR 模板在 `docs/architecture/adr/NNNN-<名称>.md` 生成草稿（含 Context/Decision/Alternatives/Consequences）。

## Step 4: 生成内部 Changelog

更新 `docs/development/changelog.md`（如不存在则新建），按 [Keep a Changelog](https://keepachangelog.com/) 格式：

```markdown
## [Phase N - Phase 名称] - YYYY-MM-DD

### Added
- [feat 类型的提交，一句话描述]

### Fixed
- [fix 类型的提交]

### Changed
- [refactor/perf 类型的提交]

### Removed
- [删除的功能]
```

这是**内部 Changelog**（项目团队可见）。模式 B 会额外生成**对外 Changelog**（Step 6）。

## Step 5: 更新 Roadmap Phase 状态

- 当前 Phase 文件：`status: completed`，添加完成日期
- `docs/roadmap/README.md`：Phase 状态改为 `✅ 完成`
- 进度统计更新

## Step 6: 模式 B（--publish）额外步骤

**仅 `--publish` 模式执行**；默认模式跳过到 Step 7。

### 6a. 版本号升级

检测项目版本文件（`package.json` / `pyproject.toml` / `Cargo.toml`），读当前版本。

**AskUserQuestion**：
```
Question: 当前版本 X.Y.Z。本次发版如何升级？

Options:
1. patch (X.Y.Z+1) — 仅 bug 修复
2. minor (X.Y+1.0) — 新增功能但向后兼容 ⭐ Phase 通常选这个
3. major (X+1.0.0) — 有破坏性变更
4. 自定义版本号（自由输入）
5. 跳过版本号升级（只打 tag）
```

更新版本号到项目配置文件。

### 6b. 生成对外 Changelog

**对外 Changelog**（用户可见，不同于内部的）：
- 提炼 Step 4 内部 Changelog 的**用户可见变化**
- 隐藏内部重构/测试/工具类改动
- 加迁移指南（如有破坏性变更）

写入 `CHANGELOG.md`（根目录，和内部的 `docs/development/changelog.md` 分开）。

### 6c. git tag

**AskUserQuestion**：
```
Question: 生成 git tag vX.Y.Z？

Options:
1. (Recommended) 生成 annotated tag（含 tag message）
2. 生成 lightweight tag
3. 跳过（仅升版本号不打 tag）
```

```bash
git tag -a v$VERSION -m "Release $VERSION - Phase N [Phase 名称]"
```

## Step 7: 精确 git add + commit

精确 add（**不用** `git add docs/` 宽泛 stage）：

```bash
git add docs/architecture/ docs/development/ docs/roadmap/ docs/architecture/adr/ docs/reports/

# 模式 B 还要加
# git add package.json pyproject.toml CHANGELOG.md
```

**动态 commit message**：
- 模式 A：`docs: Phase N [Phase 名称] 里程碑 — 文档刷新 + ADR [M] 条 + Roadmap`
- 模式 B：`release: v[版本号] — Phase N [Phase 名称] 对外发版`

## Step 8: AskUserQuestion 引导下一步

**MUST 用弹窗**（不散文建议）：

```
Question: Phase N 里程碑完成！下一步？

Options:
1. git push（推送所有 commit / 模式 B 含 --tags）
2. /diagnose（Phase N+1 前架构量化评估，定期体检推荐）
3. 开始规划 Phase N+1（读取或创建 phase-N+1-*.md）
4. 其他（自由输入）
```

选 1 → 询问是否 `git push` / `git push --tags`（模式 B 时）。**MUST NOT 自动 push**。

## Step 9: 输出确认

```
🎉 Phase N [Phase 名称] 里程碑完成（模式：[默认 / --publish]）

━━━━━━━━━━━━━━━━━━━━━━━━
文档刷新：✅ /docs 全量 / ✅ /docs audit（用户选了 / 跳过）
ADR：✅ 新增 [N] 条 / ⏭️ 无需新增
Roadmap：✅ Phase N 标记为完成
内部 Changelog：✅ 新增 [版本号] 条目

[模式 B 额外]
版本号：[X.Y.Z → A.B.C] / 跳过
git tag：[v版本号] / 跳过
对外 Changelog：[用户可见变更 M 条]

━━━━━━━━━━━━━━━━━━━━━━━━

push 状态：✅ 已 push / ⏭️ 用户选择稍后
下一步：[按 Step 8 选择输出]
```

</workflow>
````

**用法示例**：

```bash
# Phase 内部里程碑（默认，大多数场景）
/release

# Phase 完成 + 对外发版
/release --publish
```

**与其他命令的关系**：

| 场景 | 用哪个 |
|------|-------|
| 日常文档刷新 | `/docs` |
| 深度文档审计 | `/docs audit` |
| Phase 内部里程碑 | **`/release`** |
| Phase + 对外发版 | **`/release --publish`** |
| 临时 hotfix 发版 | 直接 `git tag` + 手动改 Changelog（/release 太重） |
| 发版前架构量化 | `/diagnose`（独立会话） |

**/release vs /docs 的区别**：
- `/docs`（日常）：随时可用，保持文档同步（不动 Roadmap 状态、不升版本）
- `/release`（里程碑）：Phase 完成才跑，一次性整理 + 推进 Roadmap + 可选发版

**和 /done 的链路**：
- /done Step 7 检测到 Roadmap Phase 全部完成 → AskUserQuestion 弹窗询问是否跑 /release
- 用户选 "现在执行 /release" → /done 直接调用 /release（默认模式 A）
- 如需对外发版 → /release 跑完后，用户再手动 `/release --publish`（罕见场景）或在 Step 8 引导里选

---

### 2.9 /nbp2 — AI 生图 Prompt 助手（Nano Banana Pro 2）

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

> **注**：价格/速度/Model ID 数据截至 2026-04，以 [Google 官方](https://ai.google.dev/) 最新定价为准。

## 核心差异 — 工作流策略

- **Pro**：精雕细琢单个 prompt，追求一次到位的最高品质
- **Nano Banana 2**：快速起步 → 迭代精修（速度优势支撑多轮对话式调整）

</context>

<workflow>

## Step 1: 理解用户需求

### 1a. 有参数（`/nbp2 <需求描述>`）

直接从 `$ARGUMENTS` 提取主题，**目标模型默认 NBP2**（性价比高）。如需特殊要求（角色一致性/Pro 模式等），Claude 根据描述推断。

### 1b. 无参数（`/nbp2`）

**MUST 用 AskUserQuestion 一次问清**（避免散文来回）：

```
Question: 要生成什么图片？选择场景 + 目标模型

Header: "生图需求"

Options:
1. 社交媒体封面 / 海报（NBP2 默认）
2. 产品摄影（商业用途）
3. 电影感场景 / 大幅概念图（建议 Pro）
4. 角色 / IP 一致性（多图工作流，需 NBP2）
5. 自定义（自由输入主题 + 需求）
```

选 5 用户自由输入；选 1-4 → Claude 根据类型自动选择模型并询问具体主题。

### 1c. 按需提取四要素

无论哪种输入方式，最终要明确：
1. **画面主题** — 要画什么？
2. **用途场景** — 社交媒体封面？产品图？海报？个人创作？
3. **目标模型** — Pro（最高品质）或 NBP2（快速迭代）？**默认 NBP2**
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

**用法示例**：

```bash
# 有参数（推荐，快速走默认 NBP2）
/nbp2 一个未来感城市夜景海报
/nbp2 杂志封面带 "SPRING 2026" 字样
/nbp2 等距 2.5D 风格的咖啡店插画

# 无参数（AskUserQuestion 弹窗引导）
/nbp2
```

**与其他 skill 的关系**：

/nbp2 是**独立工具 skill**，不对接开发工作流（不像 /implement / /done / /release 等配套使用）。

| 场景 | 用哪个 |
|------|-------|
| 写 Nano Banana Pro / NBP2 生图 prompt | **`/nbp2`** |
| 生成 OG 图 / 社交媒体预览图（SEO 场景） | 项目如启用 `claude-seo:seo-image-gen`，参考对应 skill |
| 项目文档里的示意图 / 架构图 | 不用 /nbp2（用 Mermaid / PlantUML 等代码化工具）|

> /nbp2 专注 Nano Banana 生态。其他生图模型（Midjourney / DALL-E / Stable Diffusion）的 prompt 写法不同，此 skill 不适用。

---

### 2.10 /diagnose — 全维度代码健康诊断

**用途**：独立于功能开发的系统性代码健康诊断。覆盖结构、实现、卫生、战略四层共 13 个维度，输出量化评分 + 完整问题清单 + 分批重构计划。与 `/audit`（项目卫生检查）和 `/docs`（文档一致性守护）互补——`/diagnose` 关注代码架构与长期可维护性。

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
- **Spec Gate 对齐**（v3.23 对接）：扫 `docs/specs/` 中 `status: implementing` / `implemented` 的 spec，检查 `[command: xxx]` Gate 条件对应的测试命令是否存在、是否仍可执行（如 `pnpm test tests/auth/` → 对应测试目录是否有文件）；Gate 引用了测试但实际不存在 → 标记为"假 Gate"

### 卫生层（认知负担）

**D10 死代码** — 是否有不再使用的代码？
- 未使用的函数、组件、导入、变量
- 注释掉的代码块（应删除，git 有历史）
- 已废弃但未清理的功能

**D11 一致性** — 同一件事是否用同一种方式做？
- 同一功能多种实现（如 HTTP 客户端既用 fetch 又用 axios）
- 命名风格不统一（camelCase 和 snake_case 混用）
- 错误处理/日志格式不统一
- **重复模式 → lint 建议**（Addy Osmani "重复犯错升级为 lint 规则"理念）：
  - 发现 2+ 次重复的反模式（如多处 `style={{}}`、多处裸 SQL、多处 `@ts-ignore`）→ 标记为"建议升级为 lint 规则或 `.claude/rules/` 红线"
  - 输出具体 lint 配置建议（如 ESLint `no-restricted-syntax` 规则 / `.claude/rules/*.md` MUST NOT 条款）
  - 该类问题单独列为"lint 建议"维度，不和 P0-P3 混淆

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

**自适应文件类型识别**（不硬编码，从项目上下文推断）：

1. **读 CLAUDE.md "技术栈"段**：识别主要语言（如 "TypeScript + Python"）
2. **读 package.json / pyproject.toml / pom.xml / Cargo.toml**：补充识别
3. **基于识别结果决定扫描的文件扩展名**：
   - TypeScript / JavaScript → `*.ts`, `*.tsx`, `*.js`, `*.jsx`
   - Python → `*.py`
   - Java → `*.java`
   - Go → `*.go`
   - Rust → `*.rs`
   - （根据实际情况扩展）

```bash
# 示例：识别出 TS + Python 后动态构造 find 命令
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/__pycache__/*" -not -path "*/.venv/*" | wc -l

# 顶层目录结构
ls -d */ 2>/dev/null
```

- 识别模块边界（目录划分方式：monorepo `apps/` / 单包 `src/` / 自定义）
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
> **D9 补充**：如 `docs/specs/` 存在 implementing/implemented 的 spec，扫其 `[command: xxx]` Gate 条件对应的测试命令是否存在/可执行（假 Gate 问题列为 P1）。
> **D11 补充**：发现 2+ 次重复的反模式 → 输出到独立的"lint 建议"清单（含具体 lint 配置建议），不和 P0-P3 混淆。
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

将 P0-P2 问题**分三类**处理：

### 5a. 进入 Batch 重构（主体）

1. **同一模块的问题合并到同一 Batch**（减少上下文切换）
2. **有依赖关系的 Batch 标注前置条件**
3. **每个 Batch 预估不超过 1 个会话**
4. **每个 Batch 有明确验收标准**

### 5b. 标记为"不做"（投入产出比低）

满足任一条件 → 明确标记"**不做**"并说明理由（不浪费精力）：
- 修改面大但收益小（如修 1 个 any 要动 20 个文件）
- 即将被废弃的模块（和 Roadmap 对照）
- 成本收益未明（需要更多信息才能决策）

**不是所有问题都值得修**——明确标记反而减少决策负担。

### 5c. lint 建议（D11 产出的独立清单）

不进入 Batch 重构，而是输出到报告的**"lint 建议"章节**，让用户自己评估是否加到 ESLint / `.claude/rules/` 配置。

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

### 🚫 不做（投入产出比低）
[编号]. [问题] — **不做理由**: [修改面大/即将废弃/成本收益未明]

## 🔧 lint 建议（D11 独立清单）

发现以下重复反模式，建议升级为 lint 规则或 `.claude/rules/` 红线：

| 模式 | 出现次数 | 建议 |
|------|---------|------|
| `style={{}}` | 8 处 | ESLint `no-restricted-syntax` 或 `.claude/rules/frontend.md` MUST NOT |
| 裸 SQL 字符串 | 5 处 | `.claude/rules/backend.md` MUST 使用 ORM |

具体配置示例：
```json
// .eslintrc
"no-restricted-syntax": [
  "error",
  { "selector": "JSXAttribute[name.name='style']", "message": "使用 Tailwind/CSS Modules 替代 inline style" }
]
```

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

**lint 建议**：用户自行评估后加到 ESLint / `.claude/rules/` 配置（一次投入，长期防御）。

全部完成后再次运行 `/diagnose` 验证改善效果。
```

## Step 7: AskUserQuestion 引导下一步

**MUST 用 AskUserQuestion**（不散文建议，和其他 skill 保持一致）：

```
Question: 诊断完成，发现 [X] 个 Batch 的重构计划。下一步？

Options:
1. (Recommended) 启动 /implement 批量模式执行 Batch 1（按依赖顺序）
2. 生成 Roadmap TODO（留给后续迭代）
3. 只看报告（稍后手动处理）
4. 重新诊断特定范围（自由输入，如"只看 backend"）
```

**报告文件 MUST 已在 Step 6 写入**（无论用户选择什么），供后续查阅。

## Step 8: 输出确认

```
✅ 代码健康诊断完成

综合健康度: X.X/10 [与上次对比 ↑/→/↓]
扫描范围: [scope]
扫描文件: [N] 个
发现问题: P0 [N] 个 | P1 [N] 个 | P2 [N] 个 | P3 [N] 个
重构计划: [N] 个 Batch，预估 [N] 个会话
lint 建议: [M] 条（重复模式 ≥2 次，建议升级为 lint/rules）

报告: docs/reports/diagnose-YYYY-MM-DD.md
执行状态: ✅ 已启动 /implement Batch 1 / 📝 已写入 Roadmap / ⏭️ 只看报告
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
| `/docs` | 文档与代码一致性 + spec/ADR 准确性 | Phase 完成后、需要深度文档审计时 |
| **`/diagnose`** | **代码架构与可维护性** | **独立会话，定期或迭代前** |

**推荐频率**：

| 项目阶段 | 建议频率 |
|----------|---------|
| 快速迭代期 | 每月 1 次 |
| 稳定维护期 | 每季度 1 次 |
| 大功能开发前 | 开发前跑一次，识别要碰的区域的健康度 |
| 技术债感觉积累了 | 随时 |

---

### 2.11 /fix-permission — 权限拦截自动诊断与修复

**用途**：Claude Code 跳出权限确认弹窗时，用户粘贴拦截信息 → 自动诊断原因 + 添加对应权限规则到 `settings.json`。**独立工具 skill，不对接开发工作流**。

**定位**：**Claude Code 权限系统的自动化修复工具**。专门处理"为什么被拦截 + 应该加什么规则"的诊断，支持三级 settings（用户/项目/项目本地），写入前预演确认。

### v3.29 新增

- **首次写入 03 模板**（之前只在 guides 本地）
- **三级 settings 扫描**：读取 `~/.claude/settings.json`（用户级）+ `./.claude/settings.json`（项目级）+ `./.claude/settings.local.json`（项目本地）
- **AskUserQuestion 选择写入级别**：根据规则性质选最合适的级别
- **写入前预演**：显示将要添加的规则 + 弹窗确认
- **Step 4A 更新**：加 Auto mode / deny 优先 / 更具体规则等解法

### v3.33 新增

- **Web 类拦截诊断**（`Claude wants to fetch content from X` / WebSearch 弹窗）独立小表 + 写入级别建议（**WebFetch domain 首选用户级**，跨项目复用价值大；**WebSearch 零风险全局开**）
- **"Yes, and don't ask again" 沉淀位置陷阱说明**：默认写入 `settings.local.json`，跨项目不复用 → 建议定期提升至用户级
- **`settings.local.json` 残骸清理**：Claude Code 对 for-loop / heredoc 命令拆词错误产生假规则（`Bash(do)` / `Bash(done)` / `Bash(for f:*)` 等），跑完 fix-permission 后扫一眼删掉
- **与 Bundled `/fewer-permission-prompts` 分工**：`/fix-permission` 单条精确诊断 + 用户级写入 vs Bundled 批量补全项目级白名单

### 和其他 skill 的关系

/fix-permission 是**独立工具**，不对接开发工作流（不像 /implement/done/release 等配套使用）。

| 场景 | 用哪个 |
|------|-------|
| 权限弹窗出现时 | **`/fix-permission`** |
| 日常 settings.json 配置调整 | 直接编辑或 `/update-config` 原生命令 |
| Hook 配置 | 见文档 02（Hook 自动化配置）|

**文件路径**: `.claude/skills/fix-permission/SKILL.md`

````markdown
---
name: fix-permission
description: |
  分析权限拦截原因并自动修复。当用户遇到 Claude Code 权限弹窗时使用。
  用户粘贴拦截信息，自动诊断原因、添加对应权限规则到 settings.json（用户/项目/项目本地三级可选）。
  触发关键词：权限拦截、permission、被拦截了、又来了、要确认
argument-hint: "<粘贴拦截信息>"
allowed-tools: Read, Edit, Bash
---

<task>
分析用户遇到的 Claude Code 权限拦截，诊断原因，写入前预演确认，最后添加规则到用户选择的 settings.json 级别。
</task>

<workflow>

## Step 1: 解析拦截信息

从 `$ARGUMENTS` 中提取：
1. **被拦截的命令**（Bash command 后面的内容）
2. **拦截原因**（如 "Compound commands"、"backslash-escaped whitespace" 等）

## Step 2: 诊断原因

### Bash 类拦截

| 拦截提示 | 根因 | 需要的权限规则 |
|---------|------|--------------|
| Compound commands with cd and git | cd && git 复合命令 | `Bash(*)` 或 `Bash(cd * && git *)` |
| backslash-escaped whitespace | 路径含空格/中文 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| command substitution $() | 命令替换 | `Bash(*)` 或 `Bash(for *)` 等 |
| quoted newline followed by # | 多行脚本带注释 | `Bash(*)` 或 `Bash(docker *)` |
| output redirection (>) | 输出重定向 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| pipe command (\|) | 管道命令 | `Bash(cmd1 \| cmd2 *)` 或 `Bash(*)` |
| background process (&) | 后台运行 | `Bash(cmd * &)` 或 `Bash(*)` |
| Permission rule ... requires confirmation | 命令不在 allow 列表 | 添加对应 `Bash(cmd *)` 到 allow |

### Web 类拦截

| 拦截提示 | 根因 | 需要的权限规则 |
|---------|------|--------------|
| Claude wants to fetch content from X | 域名 X 不在 WebFetch allow | `WebFetch(domain:X)`（**首选用户级**，跨项目复用价值大） |
| WebSearch 弹窗 | 全局缺 WebSearch | `WebSearch`（**不带括号 / 无 domain 概念**，零风险全局开） |

> **💡 "Yes, and don't ask again" 的沉淀位置陷阱**
> 用户在弹窗点 "Yes, and don't ask again" 时，规则**默认写入 `./.claude/settings.local.json`**（项目本地，gitignored）。
> - **后果**：跨项目浏览同一批技术博客 / 文档站时，每个新项目都要重新同意一遍
> - **建议**：定期把 `settings.local.json` 里高频 `WebFetch(domain:*)` 提升到用户级 `~/.claude/settings.json`
> - **诊断信号**：用户反馈"经常被同一域名拦截" → 先 `cat ~/.claude/settings.json` 看用户级是否覆盖

## Step 3: 读取三级 settings 配置

```bash
# 用户级（全局）
cat ~/.claude/settings.json 2>/dev/null

# 项目级（版本控制，团队共享）
cat ./.claude/settings.json 2>/dev/null

# 项目本地（gitignore，个人）
cat ./.claude/settings.local.json 2>/dev/null
```

诊断：
- 三个级别哪个已有相关规则？
- 缺的是什么？
- 是否 deny 列表阻止了 allow（deny 优先级高）？

## Step 4: 诊断输出

### 情况 A：`Bash(*)` 已存在于 allow，但仍被拦截

这是 Claude Code 内置安全启发式。几种解法：

1. **更具体的规则**：尝试 `Bash(cmd *)` 替代宽泛的 `Bash(*)`，更具体的规则可能绕过启发式
2. **检查 deny**：`deny` 列表比 `allow` 优先级高，看是否被 deny 拦住
3. **Auto mode**：Shift+Tab 切到 Auto mode，分类器自动判定（安全操作放行）
4. **手动确认**：如果是一次性命令，直接点"Yes, and don't ask again"

### 情况 B：缺少对应权限规则

需要添加规则。**进入 Step 5 选择写入级别**。

### 情况 C：命令在 `deny` 列表中

明确被拒绝的命令（如 `rm -rf /`、`curl | bash`、`wget | sh`、`git push --force`）。

- 如果是安全拦截 → **告知用户，不建议放行**
- 用户确认要放行 → 进入 Step 5 但提示这是**高危操作**

## Step 5: AskUserQuestion 选择写入级别

**仅在情况 B/C 需要写入时询问**：

```
Question: 权限规则写到哪个级别？

Options:
1. (Recommended) 用户级（~/.claude/settings.json）= 所有项目都生效，个人偏好
2. 项目级（./.claude/settings.json）= 只当前项目 + 提交到 git（团队共享）
3. 项目本地（./.claude/settings.local.json）= 只当前项目 + 不提交（个人项目特定）
```

**选择建议**：
- **WebFetch domain** → 用户级（跨项目复用价值大，技术博客 / 文档站浏览模式）
- **WebSearch**（无 domain）→ 用户级（零风险，搜索结果文本不直接抓任意 URL）
- 通用 Bash 命令（`ls`、`git status`）→ 用户级
- 项目特定脚本（`pnpm` / `poetry run` 等）→ 项目级（团队统一）
- 个人实验或敏感配置 → 项目本地

## Step 6: 预演写入规则

显示将要添加的规则 + AskUserQuestion 确认：

```
将在 [用户/项目/项目本地] 级 settings.json 的 permissions.allow 添加：

  "Bash(pnpm install *)"

之前该级别已有 [N] 条规则。添加后总 [N+1] 条。

Question: 确认添加？

Options:
1. (Recommended) 确认添加
2. 调整规则（自由输入更精确的规则）
3. 取消
```

## Step 7: 写入 settings.json

用户确认后，编辑对应级别的 `settings.json`：
- 如文件不存在 → 创建包含基础结构的新文件
- 如文件存在 → 读取 → 合并规则 → 写回（保持 JSON 格式化）

**精确 add**（如项目级）：
```bash
git add .claude/settings.json  # 仅项目级才需要
```

## Step 8: 输出结果

```
✅ 权限规则已添加

━━━━━━━━━━━━━━━━━━━━━━━━
拦截命令: [命令摘要]
拦截原因: [原因分类]
处理方式:
  - 级别: [用户级 / 项目级 / 项目本地]
  - 规则: [具体规则，如 Bash(pnpm install *)]
  - 文件: [路径]
━━━━━━━━━━━━━━━━━━━━━━━━

需要重启 Claude Code 生效（退出后重新 claude）。
下次遇到类似命令将自动放行。
```

</workflow>

## ⚠️ settings.local.json 残骸清理

Claude Code 在用户对包含 for-loop / heredoc / 复杂引号的命令点 "Yes, and don't ask again" 时，会**拆词错误**写入假权限规则，例如：

- `Bash(do)` / `Bash(done)` / `Bash(for f:*)` / `Bash(for file:*)` — for-loop 关键字被当成独立命令
- `Read(//tmp/**)` / `Read(//Users/...)` — 双斜杠路径残留
- `Bash(/tmp/verification_checklist.txt:*)` — 文件路径被当命令名

这些规则**无害但累赘**。可在 `/fix-permission` 跑完后扫一眼 `settings.local.json`，删除明显异常项。

## 与 `/fewer-permission-prompts` 的分工

Anthropic 提供 Bundled Skill `/fewer-permission-prompts`，自动扫 transcript 生成白名单（写到**项目级** `.claude/settings.json`）。两者关系：

| 场景 | 用哪个 |
|------|-------|
| 拦截已发生，**单条规则**精确诊断 + 用户级写入 | **`/fix-permission`** |
| 项目长期使用后**批量补全**项目级白名单 | **`/fewer-permission-prompts`**（Bundled） |
| Web 类（WebFetch domain）跨项目复用 | **`/fix-permission`** → 用户级（`/fewer-permission-prompts` 只写项目级） |
````

**用法示例**：

```bash
# 用户粘贴拦截信息作为参数
/fix-permission Bash command 'pnpm install' requires confirmation. 不在 allow 列表

# 或直接粘贴完整拦截弹窗
/fix-permission 下面这段是拦截提示：[粘贴整段]
```

**settings.json 三级优先级**（参考）：

| 级别 | 文件 | 生效范围 | 版本控制 |
|------|------|---------|---------|
| 用户级 | `~/.claude/settings.json` | 所有项目 | 不提交 |
| 项目级 | `./.claude/settings.json` | 仅当前项目 | **提交** |
| 项目本地 | `./.claude/settings.local.json` | 仅当前项目 | 不提交 |

**优先级**：项目本地 > 项目级 > 用户级（更具体的覆盖通用）。`deny` 比 `allow` 优先（无论哪一级）。

---

### 2.12 /codex — 外部 AI 任务文档生成器

**用途**：为 **Codex / GPT / ChatGPT / Gemini / 其他 Claude 实例** 等任意外部 AI 生成**自包含任务文档**。打包项目上下文 + 任务说明，让外部 AI 读完就能直接执行，无需额外说明。

**定位**：**跨 AI 协作工具**——用于交叉审查、外部意见、不同 AI 互补。独立工具 skill，不对接开发工作流。

> **命名说明**：`codex` 是历史命名（OpenAI 原 Codex 2021 产品已停）。实际适用**任何外部 AI**——因使用习惯保留命名，不改名。

### v3.30 新增

- **首次写入 03 模板**（之前只在 guides 本地）
- **混合使用模式**：有参数快速 / 无参数 AskUserQuestion 引导 7 类任务 / 参数模糊时细化
- **生成文件防覆盖**：`.codex-task.md` 已存在时 AskUserQuestion 询问（覆盖 / 时间戳另存 / 取消）
- **粒度控制**：按源文件数量（<30 / 30-100 / ≥100）三档策略
- **大任务拆分提示**：估算文档 > 50k tokens 时建议拆分
- **Step 1 自适应扫描**（读 CLAUDE.md 技术栈 + package.json，不硬编码）
- **生成文档加 frontmatter**（generated / task_type / estimated_tokens）

### 和其他 skill 的关系

| 场景 | 用哪个 |
|------|-------|
| 让外部 AI（Codex/GPT/Gemini）审查本项目 | **`/codex`** |
| 自己用 Claude 深度审查 | `/diagnose`（架构）或 `/docs audit`（文档一致性）|
| 代码质量快速扫描 | `/audit`（自己用）|

**/codex 的独特价值**：打包**完整上下文**让**另一个 AI** 跳过"理解项目"直接上手。本项目的 Claude 不做分析。

**文件路径**: `.claude/skills/codex/SKILL.md`

````markdown
---
name: codex
description: |
  为 Codex / GPT / ChatGPT / Gemini / 其他 Claude 实例等任意外部 AI 生成自包含的任务文档。
  打包项目上下文 + 任务说明，让外部 AI 读完就能直接执行，无需额外说明。
  触发关键词：codex、让 Codex 看看、交叉审查、cross review、外部 AI、让 GPT 审查
argument-hint: "[任务描述] 或留空进入引导模式"
allowed-tools: Read, Bash, Glob, Grep
---

<task>
根据用户的任务描述 + 当前项目上下文，生成一份自包含的任务文档给外部 AI 执行。

混合使用模式：
- 有参数且明确 → 直接生成
- 无参数 → AskUserQuestion 引导任务类型 + 细化
- 有参数但模糊 → AskUserQuestion 细化

MUST 原则：
- 外部 AI 读完文档即可直接执行，**不需要任何额外说明**
- 防覆盖（已有 .codex-task.md 时 AskUserQuestion 询问）
- 大任务估算 tokens，超出建议拆分
</task>

<workflow>

## Step 0: 解析任务（混合模式）

### 0a. 有参数且明确（快速路径）

如 `/codex 审查登录功能的安全性` → 明确的动作 + 明确的对象 → 直接进入 Step 1。

**明确的判定**：参数含动词（审查 / 对比 / 评审）+ 具体名词（功能名 / 方案名）。

### 0b. 无参数（引导路径）

**AskUserQuestion**：

```
Question: 让外部 AI 做什么？

Options:
1. Bug 审查（全面排查隐藏问题）
2. 代码质量评审（耦合 / 职责 / 重复 / 性能等维度）
3. 安全审查（漏洞扫描 / 敏感信息 / 输入校验）
4. 架构评审（设计质量 + 改进建议）
5. 特定功能审查（后续追问"哪个功能"）
6. 方案对比（A vs B，后续追问具体方案）
7. 自定义（自由输入）
```

选 5/6 → 第二次 AskUserQuestion 或自由输入追问细节。
选 7 → 用户自由输入，Claude 提取任务。

### 0c. 有参数但模糊（细化路径）

如 `/codex 审查一下代码`（太泛） → AskUserQuestion 细化为上述 7 种类型之一。

## Step 1: 收集项目上下文（自适应扫描）

### 1a. 读项目技术栈

```bash
# 优先从 CLAUDE.md 的 "技术栈" 段读
# 或从 package.json / pyproject.toml / pom.xml 推断
```

基于技术栈决定扫描哪些文件类型（不硬编码 `*.ts/*.py`）。

### 1b. 基础信息

```bash
echo "=== 项目信息 ==="
pwd
echo ""
echo "=== Git 状态 ==="
git log --oneline -10
echo ""
git status --short
echo ""
echo "=== 源文件统计 ==="
# 根据识别的技术栈动态 find
```

读取（如存在）：
1. `CLAUDE.md`
2. `docs/architecture/README.md`
3. `docs/architecture/frontend.md` / `backend.md`
4. `package.json` / `pyproject.toml` / `pom.xml`

## Step 2: 粒度控制（按文件数量分档）

统计源文件数量，决定包含哪些代码：

| 源文件数 | 策略 |
|---------|------|
| **< 30** | 全包含（小项目一次性喂给 AI）|
| **30-100** | 包含最近改动（`git diff HEAD~10 --name-only`）+ 任务相关模块 |
| **≥ 100** | **AskUserQuestion** 让用户选择包含哪些模块 |

**≥ 100 文件的 AskUserQuestion**：

```
Question: 项目共 [N] 个源文件，全部包含会超出外部 AI 上下文。选择包含范围：

Options:
1. 只包含最近 1 周改动文件（[M] 个）
2. 只包含 [specific-dir]（核心业务模块）
3. 只包含 [task] 相关的文件（Claude 根据任务推断）
4. 自定义（自由输入路径 glob）
```

### 任务类型 × 粒度映射

| 任务类型 | 优先包含 |
|---------|---------|
| Bug 审查 | 所有关键源文件 + 最近改动 |
| 代码质量 | 核心业务模块 + 工具函数 |
| 安全审查 | 认证/授权/输入处理/数据库访问 |
| 架构评审 | 入口 + 路由 + service + 关键接口 |
| 特定功能审查 | 只读该功能相关文件 + 测试 |
| 方案对比 | 相关现有实现 + 类型定义 |

每个文件标完整路径：
```markdown
### `apps/frontend/src/components/ListPage.tsx`
```tsx
[文件内容]
```
```

## Step 3: 估算 tokens + 大任务拆分提示

```bash
# 粗略估算（1 token ≈ 4 字符 / 1-2 中文字符）
total_chars=$(wc -m < .codex-task-draft.md)
estimated_tokens=$((total_chars / 4))
```

**超过 50k tokens → 提示用户**：

```
⚠️ 预估文档约 [N]k tokens，可能超出 Codex/GPT 默认上下文窗口（~128k）。

Options:
1. 继续生成（用户确保目标 AI 支持长上下文，如 Gemini 1M / Claude 1M）
2. 拆分任务（Claude 建议拆分方式）
3. 减少包含的代码范围（回到 Step 2 选更小范围）
```

## Step 4: 防覆盖检查

检查 `.codex-task.md` 是否已存在：

```bash
ls -la .codex-task.md 2>/dev/null
```

**已存在 → AskUserQuestion**：

```
Question: .codex-task.md 已存在（生成于 [上次时间]，任务：[上次任务简要]）。如何处理？

Options:
1. (Recommended) 覆盖（生成当前任务）
2. 另存为 .codex-task-YYYY-MM-DD-HHMM.md（保留旧文件）
3. 取消（不生成）
```

## Step 5: 生成任务文档

写入目标文件，格式如下：

```markdown
---
generated: YYYY-MM-DD HH:MM
task_type: [bug-审查 / 代码质量 / 安全审查 / 架构评审 / 功能审查 / 方案对比 / 自定义]
estimated_tokens: [估算值]
project: [项目名]
scope: [包含范围，如 "全部源文件" / "最近改动" / "apps/api/ 模块"]
---

# 外部 AI 任务文档

> 本文档由 Claude Code 自动生成，包含执行任务所需的全部上下文。
> 直接阅读并执行，无需额外信息。

## 你的任务

[清晰、具体的任务说明]

### 具体要求
- [要求 1]
- [要求 2]

### 输出格式
[按任务类型指定，如]：
- Bug 审查 → 按严重性分级，每个含：位置、描述、复现条件、修复建议
- 代码质量 → 按维度分类，每个含：位置、问题、改进建议
- 架构评审 → 优势 / 问题 / 改进建议三段式
- 方案对比 → 各方案优缺点对比表 + 推荐

## 项目概况

### 技术栈
[从 CLAUDE.md / 依赖文件提取]

### 目录结构
[精简版目录树，只到模块级]

### 架构概览
[从 docs/architecture/ 提取，或从代码推断]

### 项目约束和规范
[从 CLAUDE.md 提取的关键约束]

### 最近变更
[最近 10 个 commit 摘要]

## 代码

[按模块组织的源代码，每个文件带完整路径]
```

## Step 6: 质量检查

- 任务说明是否清晰、无歧义
- 代码文件是否完整（没有截断）
- 项目上下文是否足以理解代码
- 输出格式要求是否明确
- 估算 tokens 是否合理

## Step 7: 输出确认

```
✅ 外部 AI 任务文档已生成

文件: [.codex-task.md 或带时间戳版本]
任务: [一句话概括]
类型: [bug-审查 / ...]
包含: [N] 个源文件 / [scope]
估算: [M]k tokens

使用方式：
1. 启动外部 AI（Codex / GPT / ChatGPT / Gemini / 其他 Claude）
2. 让它读取 [文件路径]
3. 无需额外说明，它会直接开始执行

完成后将外部 AI 的输出反馈给我，我来落地执行修改。
```

</workflow>
````

**用法示例**：

```bash
# 快速路径（任务明确）
/codex 审查登录功能的安全性
/codex 对比 axios vs fetch 在本项目的替代方案

# 引导路径（无参数，弹窗选类型）
/codex

# 细化路径（参数模糊，弹窗细化）
/codex 审查一下代码
# → 弹窗问"审查哪个维度？"
```

**适用的外部 AI**：

| AI | 适用 | 上下文窗口（2026-04）|
|----|-----|------|
| Codex / GPT-5 | ✅ | 128k-1M |
| ChatGPT（网页版）| ✅ | 32k-128k |
| Gemini 2.5 Pro | ✅（长上下文优势）| 1M-2M |
| 其他 Claude 实例 | ✅（交叉审查）| 200k-1M |
| DeepSeek / Qwen 等 | ✅ | 按各自文档 |

> **核心**：任意读取 markdown + 能生成代码分析的 LLM 都适用。生成的文档是**自包含的**，不依赖特定 AI 的特性。

---

## 3. Anthropic 内置命令（Bundled Skills）

Claude Code 2.x 内置了七个由 Anthropic 维护的 bundled 命令（v2.1.111+ 清单），随版本自动更新，**无需手动配置，直接使用**。

> **v2.1.108+ 新机制**：`/init`、`/review`、`/security-review` 等内置命令现在也可以被**模型通过 Skill tool 自动发现和调用**（此前仅用户输入触发）。这让它们和自定义 Skills 在调用路径上趋同——工作流里提到"做一次安全审查"，Claude 可能直接调 `/security-review` 而不用你手动输入。

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
/loop 1d /audit                # 每天跑一次健康巡检
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

### 3.6 /less-permission-prompts — 减少权限弹窗（v2.1.111+）

**何时用**：Claude Code 频繁弹权限窗打断节奏时，一次性梳理常用只读操作生成白名单。

```bash
/less-permission-prompts
```

**内部机制**：扫描会话 transcript，识别常被用户批准的只读 Bash 和 MCP 工具调用，按优先级生成 `.claude/settings.json` 的 `permissions.allow` 建议清单。和 `/fix-permission` 互补——`/fix-permission` 处理"这次拦截"，`/less-permission-prompts` 做"**历史回溯 + 批量治理**"。

---

### 3.7 /ultrareview — 云端并行代码审查（v2.1.111+）

**何时用**：改动涉及多文件、复杂逻辑、需要多角度 review 时，在提 PR 前跑一遍。

```bash
/ultrareview                   # 审查当前 branch 相对 main 的改动
/ultrareview 123               # 审查 GitHub PR #123
```

**内部机制**：在云端启动**并行多 agent 分析 + 批评**，覆盖代码质量、架构、测试、安全多个视角。v2.1.113 加速启动（parallelized checks）并在启动对话框显示 diffstat。和本地的 `/simplify` 互补——`/simplify` 是"本地 3 agent 并行修复"，`/ultrareview` 是"云端多 agent 深度审查"，后者更重、更全，适合大型改动。

---

### 区分 Bundled 命令 vs 自定义 Skills

| 维度 | Bundled（/simplify /batch /debug /loop /claude-api /less-permission-prompts /ultrareview） | 自定义 Skills |
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
mkdir -p .claude/skills/catchup
mkdir -p .claude/skills/handoff
mkdir -p .claude/skills/spec
mkdir -p .claude/skills/implement
mkdir -p .claude/skills/done
mkdir -p .claude/skills/docs
mkdir -p .claude/skills/release
mkdir -p .claude/skills/nbp2
mkdir -p .claude/skills/diagnose
mkdir -p .claude/skills/fix-permission
mkdir -p .claude/skills/codex
```

### 4.2 文件创建

将上述各 Skill 内容分别写入：
- `.claude/skills/audit/SKILL.md`
- `.claude/skills/catchup/SKILL.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/spec/SKILL.md`
- `.claude/skills/implement/SKILL.md`
- `.claude/skills/done/SKILL.md`
- `.claude/skills/docs/SKILL.md`
- `.claude/skills/release/SKILL.md`
- `.claude/skills/nbp2/SKILL.md`
- `.claude/skills/diagnose/SKILL.md`
- `.claude/skills/fix-permission/SKILL.md`
- `.claude/skills/codex/SKILL.md`

### 4.3 查看已安装的 Skills

```bash
# Claude Code 内部命令
/skills         # 列出所有可用 Skills
```

### 4.4 使用方式

```bash
/audit              # 浅层快速巡检（日常 / PR 前 / 每周）
/audit --deep       # 加构建 + 测试覆盖率（大版本发布前）
/audit --security   # 专项安全扫描（上线前 / 定期）

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

/fix-permission <粘贴拦截信息>   # 权限拦截诊断 + 自动修复 settings.json

/codex <任务描述>                # 为外部 AI 生成自包含任务文档（快速路径）
/codex                           # 无参数，AskUserQuestion 引导任务类型（7 选项）
```

---

**版本**: v3.33
**更新日期**: 2026-04（v3.33）
