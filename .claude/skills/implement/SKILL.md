---
name: implement
description: |
  有纪律地实施一个文档小改动（单 Section 表述优化、字词修正、小版本 bump、单 Skill 描述微调等）。
  针对 guides 文档项目定制：跨 00-04 多文档同步改动 → 升级到 /spec 或直接讨论方向再动手。
  触发关键词：实施、改一下、修正、微调、单点修改
argument-hint: "<改动描述> 或留空进入批量模式"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
guides 文档项目的有纪律单改动：MUST 先扫描现有模式（已存在的章节风格、表格格式、术语），MUST 在 commit 前做全局一致性自检（版本号/数量引用）。
</task>

<workflow>

## Step 0: 接收任务

**单任务模式**（有参数）：`/implement 01 Section 9.3 措辞优化` → 进入 Step 1
**批量模式**（无参数）：询问要处理哪些改动，每个独立走完整 Step 1-6。

## Step 1: 复杂度评估（硬阈值）

**任一触发 → 建议升级到 /spec 或先讨论**：

| 硬阈值 | 为什么 |
|--------|--------|
| 涉及 ≥2 个 00-04 文档同步修改 | 多文档协同需要先规划影响面 |
| 新增或重构一整个 Section | 结构改动应该先对齐方向 |
| 涉及版本号 bump（小版本 +1） | 走 /spec 或直接讨论，不走 /implement |
| 新增 Skill / Hook 事件 / 改 Frontmatter 规范 | 牵动 02/03 + README + prompt-* 同步 |
| 改动会让"同步表"里某行变更 | CLAUDE.md 同步表指向的是重量级改动 |

触发时输出：
> 这个改动涉及 [具体触发项]，建议 /spec 或先讨论方向。要继续还是切换？

用户坚持继续 → 尊重判断。

## Step 2: 模式扫描（MUST，动手前）

**核心原则**：改文档前 MUST 确认"guides 里是否已有同类表达/结构"。防止同一术语 3 种写法、同一小节 2 种编号风格。

### 扫描步骤

1. **识别关键词**：从改动描述提取（术语 / Skill 名 / Section 标题关键词）
2. **Grep 现有用法**：
   ```bash
   # 术语一致性
   # 例：rg "disable-model-invocation" --glob "*.md" -n
   # Skill/Section 编号
   # 例：rg "^### 2\.\d+ /" 03-Skills命令配置.md
   ```
3. **列出匹配位置**（透明决策）
4. **判断**：
   - 找到相似 → MUST 说明"为什么不沿用"或"怎么对齐"
   - 未找到 → 明确记录"guides 无同类表达，新增为 X"
   - 发现多种风格并存 → 提醒"这里已有风格分裂，本次要统一到哪种？"

### 文档敏感区识别

- 改的内容是否在 CLAUDE.md 同步表覆盖范围（版本号/Hook 数/Skills 数/章节编号/新版本功能）？是 → 升级 /spec
- 改的段落是否被其他文档/prompt-* 引用？若有，MUST 同步检查
- 是否在代码块内？代码块须标注语言（bash/json/markdown/yaml）
- 是否表格？表格中英文列宽 MUST 对齐

## Step 3: 执行改动

| 复杂度 | 流程 |
|--------|------|
| **简单**（1 文档内单处） | Edit → Verify → Commit |
| **中等**（1 文档内多处） | Read → Edit × N → Verify → Commit |
| **涉及代码块示例** | Read 周围上下文 → Edit → Verify 代码块语法标注 → Commit |

遵循 guides CLAUDE.md 编写规范（MUST/MUST NOT/SHOULD；表格对齐；代码块标注；跨文档引用格式）。

## Step 4: Verify（文档项目版）

- **版本号一致性**：若改了带版本号的段落，Grep 确认本文档内版本号自洽（header/footer 一致）
- **跨文档引用**：若改的段落被其他文件引用（如 "详见文档 0X Section Y"），Grep 确认引用仍有效
- **代码块语言标注**：新加或改过的 `​``` 块必须带语言（bash/json/markdown/yaml）
- **表格对齐**：视觉检查；中英文混排用空格补齐
- **MUST/SHOULD 用词**：约束强度用词符合 RFC 2119

## Step 5: Commit 前自检（MUST）

### 三红灯（任一触发 → 暂停汇报）

- 我是否**顺手重写了用户没要求的段落**（顺势优化）？
- 我是否**改动了版本号但未进入 /spec 或 /done 流程**？
- 我是否**改变了 Skill 模板 / Frontmatter 结构但没同步 03 源头**？（会让 03 成为过时真相源）

### 同步表反查

打开 CLAUDE.md 的"修改时必须同步的内容"表，逐行对照本次改动：**任一行被触及 → 停下来走 /spec 或先讨论**。不要闷头同步。

### Tidy First 分 commit（文档项目版）

若本次同时包含：
- **格式变动**（排版调整、表格对齐、代码块加语言标注、术语统一）
- **内容变动**（新增/修改论述、规则、示例）

→ MUST 拆两个 commit：先 `refactor(docs): ...` 再 `docs: ...` 或 `feat: ...`。

## Step 6: Commit

- Conventional Commits（`docs:` / `chore:` / `refactor:` / `fix:`）
- guides 常用格式：`{type}: vX.Y 一句话概括`（带本版本号）
- 若本次改动与 Phase 4 roadmap 条目关联 → 末尾提示"如需更新 roadmap，执行 `/done <描述>`"

## 批量模式

| 情况 | 动作 |
|------|------|
| 某个改动触发硬阈值 | 停下汇报，问用户"升级 /spec 还是跳过？" |
| 用户说"暂停"/"停一下" | 立即报告进度 |
| 上下文 > 60% | 提醒剩余数，建议 /handoff |

**批量 ≠ 简化**：每个改动走完整 Step 1-6。

## 输出格式

**单任务完成**：
```
✓ [hash] docs: 01 Section 9.3 措辞优化
  改动: 01-CLAUDE配置架构指南.md
  模式扫描: 沿用既有"`@import` 方案"术语（01:L423, README:L66）
```

**批量完成汇总**：
```
✅ 完成 3/4：
1. ✓ [hash] docs: 01 Section 9.3 措辞优化
2. ✓ [hash] chore: README 排版修复
3. ✓ [hash] docs: 02 Hook 示例代码块加 bash 标注
4. ⏭️ 跳过 — 涉及 00/02/03 三文档同步，建议 /spec
```

</workflow>

<notes>
## guides 项目特殊说明

- **文档项目没有测试/lint/类型检查**，对应步骤在 Step 4 转化为"一致性 Grep + 视觉检查"
- **/done 是文档一致性守护**（全局版本号/数量引用/Roadmap 联动）；/implement 是"单点纪律实施"。关系：/implement 完成后若触发 Roadmap 关联 → 提示跑 /done
- **CLAUDE.md 同步表是硬分流器**：表内项目一旦触发 → 升级 /spec；表外的小改动 → /implement 即可
- **不引入 ADR 概念**：guides 作为文档项目没有架构决策记录需求；通用版 /implement 的 Step 7 ADR 触发在本版本移除
</notes>