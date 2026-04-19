---
name: release
description: |
  guides Phase 里程碑工作流：Phase 所有条目完成后的整体收官（全量 /docs + Phase 状态更新 + Phase Changelog）。
  guides 每个小版本（vX.Y+1）的日常发布走 /done + commit 即可，/release 只在 Phase 整体完成时用。
  触发关键词：release、Phase 完成、里程碑、阶段收官
argument-hint: "[空=默认；guides 无 --publish 模式，对外发版不适用]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
guides Phase 里程碑收官（仅在 Phase 整体完成时使用）。
MUST 原则：
1. Phase 所有条目必须全部完成（checkbox 全勾）才能跑 /release
2. 不自动 push
3. 精确 git add（MUST NOT `git add docs/` 宽泛 stage）

guides 与通用 /release 的差异：
- **无 --publish 模式**：guides 无对外发版流程（不发 npm / 不打用户可见 tag），小版本记录在 README 即可
- **无 ADR 检查**：guides 不维护 ADR
- **无版本号 bump**：Phase 完成 ≠ 版本号跳变，小版本 bump 在日常 /done 已处理
</task>

<workflow>

## Step 0: Phase 完成检查

```bash
cat docs/roadmap/README.md
ls docs/roadmap/
```

读当前 Phase 文件（如 `phase-4-持续演进.md`），确认所有 checkbox 勾选状态：

```bash
# 未完成条目数
rg "^\- \[ \]" docs/roadmap/phase-4-*.md | wc -l
# 已完成条目数
rg "^\- \[x\]" docs/roadmap/phase-4-*.md | wc -l
```

**有未完成条目 → AskUserQuestion**：

```
Question: 当前 Phase 还有 [N] 个未完成条目：
- [列出未勾选的条目]

Options:
1. 停止 /release（先完成这些条目）
2. 忽略并继续（Phase 可能不完整）
3. 从 Phase 中移除这些条目（改为"不做"）
```

## Step 1: 全量文档守护

执行 `/docs`（无参数全量）。详细流程见本项目 `.claude/skills/docs/SKILL.md`。

**guides 版 /docs 5 项审计**：
- Skill 模板 vs 本地副本
- prompt-*.md 同步
- CLAUDE.md 同步表反查
- 版本号 / 版本记录一致性
- 术语一致性

## Step 2: 收集 Phase 期间变更

**确定 Phase 开始日期**（两种 fallback）：

```bash
# 1. 优先从 Phase 文件标题或开头的版本范围提取（如 "Phase 4 — 持续演进 (v3.14+)"）
PHASE_START_VERSION=$(head -5 docs/roadmap/phase-4-*.md | grep -oE "v3\.\d+" | head -1)

# 2. 如无，用上次 /release commit 时间
PHASE_START=$(git log --oneline --grep="^release:" -1 --format="%ci" 2>/dev/null)
```

收集 Phase 期间所有版本迭代：

```bash
# 从 README 版本记录里截取 Phase 范围
git log --oneline --grep="^feat:\|^chore:.*v3" | head -50
```

## Step 3: 生成 Phase Changelog

更新 `docs/roadmap/phase-N-*.md` 末尾添加 "Phase 回顾" 段落（按 [Keep a Changelog](https://keepachangelog.com/) 格式）：

```markdown
## Phase N 回顾 — YYYY-MM-DD 完成

**版本范围**: vX.Y - vA.B（共 N 个小版本）

### 主要新增
- vX.Y：[一句话描述]
- vX.Y+1：[...]

### 重要调整
- [/spec 改 /implement、/deep-audit 废弃等定位变化]

### 废弃 / 移除
- [如有]
```

**不生成单独的 CHANGELOG.md**——guides 的 README.md 已有版本记录表，这里只在 Phase 文件里做回顾。

## Step 4: 更新 Roadmap Phase 状态

- 当前 Phase 文件末尾 frontmatter 或文首：`status: completed`，添加完成日期
- `docs/roadmap/README.md`：当前 Phase 状态 `进行中` → `完成`，进度 `X/Y` → `Y/Y ✅`
- 下一个 Phase（如有规划）状态 → `进行中`

## Step 5: 精确 git add + commit

```bash
git add docs/roadmap/ README.md 00-*.md 01-*.md 02-*.md 03-*.md 04-*.md
```

Commit message：
```
release: Phase N [Phase 名称] 里程碑 — 文档刷新 + Roadmap 收官
```

## Step 6: AskUserQuestion 引导下一步

```
Question: Phase N 里程碑完成！下一步？

Options:
1. git push（推送所有 commit）
2. 开始规划 Phase N+1（创建 phase-N+1-*.md 草稿）
3. 先休息，稍后处理
```

**MUST NOT 自动 push**。

## Step 7: 输出确认

```
🎉 Phase N [Phase 名称] 里程碑完成

━━━━━━━━━━━━━━━━━━━━━━━━
/docs 全量守护：✅ [N] 处修复
Phase 回顾：✅ 写入 phase-N-*.md 末尾
Roadmap 状态：✅ Phase N 标记完成（X/Y → Y/Y ✅）
内部 Changelog：✅ README 版本记录已完整（v3.14 - v3.X）
━━━━━━━━━━━━━━━━━━━━━━━━

push 状态：✅ 已 push / ⏭️ 用户选择稍后
下一步：[按 Step 6 选择]
```

</workflow>

<notes>
## guides 项目特殊说明（vs 03 通用版 /release）

| 通用版 | guides 本地版 |
|--------|---------------|
| --publish 模式（版本号 bump + tag + 对外 Changelog）| **移除** — guides 不发外部包 |
| ADR 检查（四类触发） | **移除** — guides 无 ADR |
| major/minor/patch 选择 | **移除** — guides 是文档项目线性小版本 |
| Step 1b /docs audit 深度审计 | 并入 Step 1（guides 的 /docs 已含审计逻辑） |
| CHANGELOG.md 对外文件 | **移除** — guides 只更新 Phase 文件末尾 "Phase 回顾" |
| git tag | **可选** — 一般不打，打也是 `phase-N-done` 这种内部标记 |

## 使用频率预估

guides 目前 Phase 1/2/3 都已完成但历史上**未走过 /release** —— 当前 Phase 4 进度 8/11。

预期首次真正触发 /release 的时机：**Phase 4 进度达 11/11**（还需 3 项：guides 自身配置 ✅ 本次 / Claude Code 新版本跟进 / AGENTS.md Step 2）。

## 与其他命令的关系

| 场景 | 用哪个 |
|------|-------|
| 日常小版本发布（vX.Y+1 bump） | `/done`（已完整处理 README 版本记录 + Roadmap）|
| 日常文档刷新 | `/docs` |
| Phase 整体收官（本 skill 的适用场景） | **`/release`** |

/release 和 /done 的区别：
- `/done`：每次改动收尾，不动 Phase 状态
- `/release`：Phase 整体完成才跑，推进 Phase 状态 + Phase 回顾
</notes>