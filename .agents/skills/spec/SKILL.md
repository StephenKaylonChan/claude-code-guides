---
name: spec
description: |
  将讨论成果整理为结构化设计文档。当需求讨论、新版本规划、功能探讨到一定程度时使用。
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

- 如果提供了参数（如 `/spec version-consistency`），用参数作为文件名（kebab-case）
- 如果没有参数，根据讨论主题自动命名
- 检查 `docs/specs/<name>.md` 是否已存在：
  - **已存在** -> 增量更新模式（读取现有内容，合并新讨论成果）
  - **不存在** -> 新建模式

```bash
mkdir -p docs/specs
```

## Step 1: 收敛讨论成果

回顾当前对话，**先归纳共识与分歧**，再提取内容：

### 1a. 共识与分歧梳理

```
讨论收敛总结：
已达成共识：[列出 2-5 条核心决定]
待确认/分歧：[列出尚未敲定的点，如有]
```

如有待确认项，询问用户是否现在确认，或标记为 draft 后续再定。

### 1b. 提取讨论内容

按需提取：
- 背景与目标
- 需要修改/新增的内容
- 涉及的文档和章节
- 讨论过的方案及取舍理由
- 最终确定的方案
- 约束条件和注意事项

## Step 2: 规划实施阶段

将工作拆分为 **1-5 个 Implementation Phases**，每个 Phase 必须满足：

- **独立可交付**：完成后有可验证的产出
- **独立可验证**：有明确的检查条件
- **上下文友好**：单个 Phase 不超过一个上下文窗口

## Step 3: 写入/更新 Spec 文件

**新建模式** — 写入 `docs/specs/<name>.md`：

```markdown
---
title: [功能名称]
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
total_phases: N
active_phase: 1
---

# [功能名称] 设计文档

## 背景与目标

[为什么要做这个改动]

## 内容概要

[核心改动点]

## 实施计划

### Phase 1: [阶段名称]
**Tasks**:
- [ ] [具体任务 1]
- [ ] [具体任务 2]

**Gate**:
- [ ] 所有 Tasks 已勾选
- [ ] 文档版本号一致
- [ ] 交叉引用正确

**On Complete**: 更新 active_phase，建议执行 /done
```

**增量更新模式** — 读取已有文件，将新讨论成果合并到对应模块。

## Step 4: 检查 Roadmap 关联

如果 `docs/roadmap/` 存在：
- 检查当前 spec 对应的工作是否在 Roadmap 中有对应条目
- 如有 -> 在 spec 头部填写关联信息
- 如无 -> 提示用户是否需要添加到 Roadmap

## Step 5: 判断状态

- `draft`：讨论还在进行中
- `approved`：核心方案已确定，可以开始实施

完整状态生命周期：`draft -> approved -> implementing -> implemented -> [deprecated | superseded]`

## Step 6: 输出确认

```
Spec 已生成/更新

文件：docs/specs/<name>.md
状态：草稿 / 已确认
实施阶段：[N] 个 Phase
关联 Roadmap：[有/无]

建议下一步：
- 继续讨论 -> 讨论后再次 /spec 更新
- 开始实施 -> 按 Phase 1 开始执行
- 确认内容 -> 告诉我"确认"，状态改为"已确认"
```

</workflow>
