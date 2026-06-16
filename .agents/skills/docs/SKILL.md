---
name: docs
description: |
  guides 文档生态守护者：跨 00-04 + README + prompt-*.md + .Codex/skills/*/SKILL.md 一致性审计与修复。
  四种操作：更新（源头和副本脱节）/ 新增（新功能缺文档）/ 删除（废弃内容残留）/ 审计（跨文档交叉验证）。
  触发关键词：文档守护、docs、文档审计、一致性、同步检查
argument-hint: "[skills | prompts | terms | audit | 空=全量]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disable-model-invocation: true
---

<task>
针对 guides 文档项目执行生态守护。guides 本身即是文档，不存在"代码-文档"矛盾——守护的是"**内部真相源 vs 各处副本**"的一致性：
1. 03 Skill 模板（真相源） vs `.Codex/skills/*/SKILL.md`（本地定制副本）
2. 02/03 文档 vs 3 个 prompt-*.md（发给用户的指引） 
3. AGENTS.md 同步表 vs 实际版本/数量引用散布
4. README 版本记录 vs 各文档 header/footer 版本号
5. Roadmap Phase 进度 vs README 描述

改动 >10 处 → AskUserQuestion 审核；≤10 处直接修。MUST NOT `git push`。
</task>

<workflow>

## Step 0: 确定范围

解析 `$ARGUMENTS`：

| 参数 | 执行范围 |
|------|---------|
| 无参数 | **全量守护**：下方所有 5 个审计项 + 四种操作 |
| `skills` | 03 Skill 模板 vs 本地 `.Codex/skills/*/SKILL.md` 一致性 |
| `prompts` | 02/03 vs `prompt-*.md` 同步（新增 Skill / Hook 是否传达） |
| `terms` | 跨文档术语一致性（如 `@import` vs `@-import`、`MUST` 用法） |
| `audit` | 只生成报告不改动（只读模式） |

```bash
mkdir -p docs/reports
```

## Step 1: 变更锚定

```bash
LAST_DOCS_COMMIT=$(git log --oneline --grep="^docs:\|^feat:\|^chore:.*README" -1 | cut -d' ' -f1)
echo "=== 自 $LAST_DOCS_COMMIT 以来的变更 ==="
git diff --name-only $LAST_DOCS_COMMIT..HEAD 2>/dev/null
git log --oneline $LAST_DOCS_COMMIT..HEAD | head -20
```

若本次会话刚做了大量改动 → 从 `git status` + 未提交 diff 推断变更范围。

## Step 2: 五项审计（按范围执行对应项）

### 2.1 Skill 模板 vs 本地副本（`skills` 或全量）

03-Skills命令配置.md 的 2.1-2.12 是**真相源**，本地 `.Codex/skills/*/SKILL.md` 可以定制，但 `name` / `description` / `allowed-tools` / `argument-hint` 应保持同步。

```bash
# 列已装 skill
ls .Codex/skills/
# 对每个 skill，读 03 里的对应节 frontmatter + 本地 SKILL.md frontmatter 比对
```

**判断**：
- 本地 frontmatter 和 03 源头不一致 → 若本地是故意定制（如 guides 文档版 /implement），MUST 在本地 SKILL.md 的 `<notes>` 里解释；无解释 → 标记脱节
- 03 新增了段落但本地没跟进 → 标记需更新
- 本地比 03 多出的自定义 → 保留，但 `<notes>` 应说明为什么

### 2.2 prompt-*.md 同步（`prompts` 或全量）

3 个 prompt 文件（`prompt-新项目初始化.md` / `prompt-旧项目迁移.md` / `prompt-guide版本升级.md`）应反映 02/03 的当前版本。

```bash
# 版本升级 prompt 是否含最新版本的新功能知识
rg "v3\.\d+" prompt-guide版本升级.md | head -20
# 初始化 / 迁移 prompt 是否引用 02/03 的章节编号仍有效
rg "文档 0[0-4] Section \d+" prompt-*.md
```

**判断**：
- 最新版本（README 里的当前版本）在 prompt-guide版本升级.md 里无条目 → 新增
- 章节引用已移位 → 更新
- 已删除的功能仍被 prompt 引用 → 删除

### 2.3 AGENTS.md 同步表反查（全量）

读 AGENTS.md 的"修改时必须同步的内容"表，对表内每项抽样验证：

- **版本号**：Grep 00-04 + README，确认全部同版本
- **Hook 事件总数**：02 正文数字 vs README 文档列表 vs prompt-更新指南规范 里的数字
- **Skills 总数**：README 版本记录里最近的数字 vs 实际 03 里的 2.1-2.N
- **章节编号**：如新增/删除章节，文档内部目录 + 正文标题是否同步

任一行数字不一致 → 标记修复项。

### 2.4 版本号 / 版本记录 一致性（全量）

```bash
# 每个文档的头/尾版本号
rg "^\*\*版本\*\*: v" *.md
# README 版本记录最新条目
head -50 README.md | rg "^\| v"
```

**判断**：
- 00-04 + README 中有文件版本号落后 → 更新
- README 版本记录缺最新版本条目 → 补
- Phase 4 roadmap 进度（`README.md` + `docs/roadmap/phase-4-*.md`）不一致 → 对齐

### 2.5 术语一致性（`terms` 或全量）

抽检高频术语：

```bash
# @import 方案（v3.31 引入）
rg "@import|@-import|@ import" *.md docs/
# MUST / SHOULD / MUST NOT 用词
rg "^\s*(MUST|SHOULD|MUST NOT)" 00-*.md 01-*.md 02-*.md 03-*.md 04-*.md
# 代码块语言标注缺失（```$ 之后空行）
rg -n '^```$' *.md | head -20
```

## Step 3: 汇总改动数 + 审核

统计 Step 2 的所有修复项：更新 [Y] / 新增 [Z] / 删除 [W] / 审计问题 [V]。

**改动 ≤10 处** → 直接执行（Step 4）。
**改动 >10 处** → AskUserQuestion：

```
Question: 检测到 [X] 处需要修改
- 更新 [Y] 处（源头 vs 副本脱节）
- 新增 [Z] 处（新功能未传达）
- 删除 [W] 处（废弃内容残留）
- 审计问题 [V] 处（术语 / 章节引用）

如何处理？

Options:
1. (Recommended) 全部修（已 review 报告）
2. 只修 P0（版本号 / 数量引用 / Skill 模板脱节）
3. 只生成报告（完全手动处理）
4. 自定义范围（自由输入）
```

报告路径：`docs/reports/docs-YYYY-MM-DD.md`。

## Step 4: 执行修改 + 提交

按 guides AGENTS.md 规范修改：
- 表格对齐、代码块带语言标注、MUST/SHOULD 用词
- 批量 Edit 前 MUST 先 Read（Read-before-Edit 合约）
- 版本号 Edit 时带 2 行上下文避免多匹配（session-notes 里的坑）

```bash
git add 00-*.md 01-*.md 02-*.md 03-*.md 04-*.md README.md AGENTS.md prompt-*.md .Codex/skills/ docs/
git commit -m "docs: vX.Y 文档生态守护 — [N] 处更新 + [M] 处新增 + [W] 处删除"
```

**MUST NOT `git push`**。

## Step 5: 输出报告

```
✅ guides 文档生态守护完成（范围：[全量 / skills / prompts / terms / audit]）

━━━━━━━━━━━━━━━━━━━━━━━━
变更锚定：自 [hash] 以来 [N] 个 commit

五项审计结果：
- 2.1 Skill 模板 vs 本地副本：[N] 处脱节 [✅修 / ⏭️报告]
- 2.2 prompt-*.md 同步：[N] 处需更新
- 2.3 AGENTS.md 同步表反查：[N] 处数字不一致
- 2.4 版本号 / 版本记录：[N] 处落后
- 2.5 术语一致性：[N] 处术语分裂

四种操作统计：
- 更新 [Y] 处 ✅
- 新增 [Z] 处 ✅
- 删除 [W] 处 ✅
- 审计问题 [V] 处
━━━━━━━━━━━━━━━━━━━━━━━━

文档改动清单：
- README.md: [更新 N 处]
- 00-日常使用说明.md: ...
- 01-Codex配置架构指南.md: ...
- 02-Hooks自动化配置.md: ...
- 03-Skills命令配置.md: ...
- 04-工作流最佳实践.md: ...
- AGENTS.md: ...
- prompt-*.md: ...
- .Codex/skills/*/SKILL.md: [同步 N 个]

历史趋势：
- 上次审计 [日期]：X 处问题
- 本次：Y 处问题（↑恶化 / →持平 / ↓改善）

报告：docs/reports/docs-YYYY-MM-DD.md
下一步：git push（如需）
```

</workflow>

<notes>
## guides 项目特殊说明（vs 03 通用版 /docs）

| 通用版 | guides 本地版 |
|--------|---------------|
| "代码-文档一致性" | "源头-副本一致性"（03 Skill vs 本地 SKILL.md；AGENTS.md 同步表 vs 散布数字）|
| Spec 描述 vs 代码实现审计 | **跳过**（guides 的 docs/specs/ 实际空，无 spec 文件）|
| ADR 有效性检查 | **跳过**（guides 没 ADR）|
| Gate `[command]` 可执行性 | **跳过**（guides 没 Gate）|
| `docs/architecture/` + `docs/development/` 层次 | 换为 guides 独有的 00-04 + prompt-*.md + README |
| Step 7 commit 按 feat:/refactor:/docs: 动态生成 | guides 惯例：`docs: vX.Y ...` 或 `chore: vX.Y ...` |

## 与其他命令的关系

- **/done**：快速全局一致性排查（版本号 / 数量引用 / Roadmap 状态），用于**单次改动收尾**
- **/docs**：**周期性深度审计**，覆盖跨 prompt / skills / terms / 版本记录 5 项
- /done 侧重即时一致性，/docs 侧重结构性漂移。建议节奏：日常 /done，每次版本迭代跑一次 /docs 全量
</notes>