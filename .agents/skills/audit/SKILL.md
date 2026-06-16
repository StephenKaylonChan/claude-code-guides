---
name: audit
description: |
  guides 文档项目浅层巡检（5-10 分钟）：代码块语言标注覆盖率、版本号一致性、Roadmap 漂移、未提交 / 未 push 状态、密钥泄漏扫描。
  只发现问题，不改文档（修改走 /implement 或 /docs）。
  触发关键词：巡检、audit、健康检查、快速扫描
argument-hint: "[--deep | --security | 空=标准]"
allowed-tools: Read, Bash, Grep, Glob
disable-model-invocation: true
---

<task>
对 guides 文档项目做浅层快速巡检，只发现问题 + 弹窗询问处理策略。不改文档（修改走 /implement 单点、/docs 结构性）。
</task>

<workflow>

## Step 1: 基本信息

```bash
echo "=== guides 审计 $(date '+%Y-%m-%d %H:%M') ==="
git log --oneline -5
git status --short | head -20
```

## Step 2: 解析参数

| 参数 | 执行 |
|------|------|
| 无参数 | 标准（Step 3）+ 报告（Step 6） |
| `--deep` | 标准 + 建议跑 `/docs` 全量深度审计 |
| `--security` | Step 5 密钥扫描 + 报告 |

## Step 3: 标准巡检

### 3a. 文档质量（代替通用版"代码质量"）

```bash
# 代码块缺语言标注（``` 后空行 → 未标注）
rg -n '^```$' *.md | head -20
# MUST / SHOULD / MUST NOT 分布（若集中在单文档 → 可能风格分裂）
rg -c "MUST NOT|MUST |SHOULD " *.md
# TODO / FIXME 残留
rg -n "TODO|FIXME|XXX" *.md docs/
```

### 3b. 版本号 / Roadmap 一致性

```bash
# 各文档的头/尾版本号
rg "^\*\*版本\*\*: v" *.md
# README 版本记录最新条目
head -100 README.md | rg "^\| v3"
# Phase 4 进度（README + roadmap 文件）
rg "Phase 4.*\d+/\d+" README.md docs/roadmap/
```

逐项对照：任一不一致 → 标记。

### 3c. Skill 模板 vs 本地副本数量对照

```bash
# 03 里定义了几个 skill（2.1-2.X）
rg -c "^### 2\.\d+ /" 03-Skills命令配置.md
# 本地装了几个
ls .Codex/skills/ | wc -l
# 差集（03 定义但本地没装）
```

差集 > 0 → 标记 P1（可能需要补装）。

### 3d. Git 状态

- 未提交文件数（> 10 → 提醒）
- 未推送 commit 数（提醒 push）
- `.idea/` 等 IDE 目录是否该加 `.gitignore`

### 3e. session-notes 新鲜度

```bash
# session-notes.md 修改日期
stat -f "%Sm" .Codex/session-notes.md 2>/dev/null || stat -c "%y" .Codex/session-notes.md
```

超过 14 天未更新 → 可能已过时，提醒跑 /handoff 刷新或清理。

## Step 5: `--security` 专项（guides 定制）

### 5a. 密钥扫描

```bash
if command -v gitleaks &>/dev/null; then
  gitleaks detect --no-git --redact 2>&1 | tail -20
else
  # guides 是文档项目，主要扫 settings.local.json 和可能的 markdown 中的密钥误贴
  rg -iE "(password|secret|api[_-]?key|token)\s*[:=]\s*['\"][^'\"]+['\"]" \
    *.md .Codex/ --glob '!.git' 2>/dev/null | head -10
fi
```

### 5b. 敏感文件检查

- `.Codex/settings.local.json` 是否在 `.gitignore`？
- 未跟踪的 `.env*` 或 `*.key` 文件？

## Step 6: 历史对比 + 输出报告

### 6a. 读上次报告

```bash
LAST_REPORT=$(ls -t docs/reports/audit-*.md 2>/dev/null | head -1)
```

### 6b. 写本次报告

路径：`docs/reports/audit-YYYY-MM-DD.md`

```markdown
# guides 审计报告 — YYYY-MM-DD

**模式**: 标准 / --deep / --security

## 总览

| 维度 | 状态 | 数值 | 上次 | 趋势 |
|------|------|------|------|------|
| 文档质量 | ✅/⚠️/❌ | 未标注代码块 [N] 个 | [M] | ↑/↓/→ |
| 版本一致性 | ✅/⚠️/❌ | [N] 文档落后 | [M] | ... |
| Skill 模板覆盖 | ✅/⚠️/❌ | 03 定义 [N] / 本地装 [M] | ... | ... |
| Git 状态 | ✅/⚠️/❌ | [N] 未提交 / [M] 未推送 | ... | ... |
| session-notes | ✅/⚠️/❌ | 距今 [N] 天 | ... | ... |

## 🔴 P0 立即处理
## 🟡 P1 本周处理
## 🟢 P2 有空再说

## 📈 趋势分析
```

### 6c. AskUserQuestion 引导

```
Question: 发现 P0 [X] / P1 [Y] / P2 [Z] 个问题。下一步？

Options:
1. (Recommended) 只看报告，我自己决定
2. 启动 /implement 批量修单点（版本号 bump、代码块语言标注等）
3. 启动 /docs 全量深度审计（结构性漂移）
4. 只处理 P0
```

## Step 7: 输出确认

```
✅ 审计完成（模式：标准 / --deep / --security）

━━━━━━━━━━━━━━━━━━━━━━━━
问题统计：P0 [X] / P1 [Y] / P2 [Z]
趋势：[恶化 / 持平 / 改善]（对比 [上次日期]）
━━━━━━━━━━━━━━━━━━━━━━━━

报告：docs/reports/audit-YYYY-MM-DD.md
下一步：[根据弹窗选择]
```

</workflow>

<notes>
## guides 项目特殊说明（vs 03 通用版 /audit）

| 通用版 | guides 本地版 |
|--------|---------------|
| 代码 lint / TODO 统计 | 文档代码块语言标注 / MUST 用词分布 |
| 包管理器依赖 / 漏洞扫描 | **跳过**（无依赖） |
| 构建 / 测试覆盖率（--deep） | **转**为"建议跑 /docs 全量" |
| 密钥扫描 | 保留，重点扫 `.Codex/settings.local.json` 和 markdown 误贴 |
| Stale spec（docs/specs/） | **跳过**（guides 无 spec） + 新增"session-notes 新鲜度" |
| Step 0 推断 lint/test 命令 | **跳过**（文档项目无构建命令） |

## 与其他命令的关系

- **/audit**：浅层巡检（5-10 分钟）- 只发现，不改
- **/docs**：深度文档生态审计（30-60 分钟）- 改文档
- **/done**：单次改动收尾一致性（即时）- 改文档

触发 P0/P1 → /implement 修单点 / /docs 修结构
</notes>