重要！使用 AI Agent 执行这个任务。

你的任务是：**将本 guides 目录下的所有文档更新为当前最新的 Claude Code 规范和最佳实践**。

---

## 执行前提

首先做两件事：

1. **获取当前日期**（通过系统时间或询问用户确认）
2. **读取现有 guides**，了解当前内容的版本和最后更新日期：
   - `~/Downloads/00_project/guides/README.md`（查看版本记录）
   - `~/Downloads/00_project/guides/00-日常使用说明.md`
   - `~/Downloads/00_project/guides/01-CLAUDE配置架构指南.md`
   - `~/Downloads/00_project/guides/02-Hooks自动化配置.md`
   - `~/Downloads/00_project/guides/03-Skills命令配置.md`
   - `~/Downloads/00_project/guides/04-工作流最佳实践.md`
   - `~/Downloads/00_project/guides/prompt-新项目初始化.md`
   - `~/Downloads/00_project/guides/prompt-旧项目迁移.md`
   - `~/Downloads/00_project/guides/prompt-guide版本升级.md`

记录当前 guides 版本和最后更新时间，作为对比基准。

---

## Phase 1：全网信息收集

使用 WebSearch 工具执行以下所有搜索。**每个查询都要执行，不能跳过**，信息越全面越好。

### 1.1 官方权威来源

```
搜索词（逐一执行）：

1. "Claude Code changelog" site:github.com/anthropics/claude-code
2. "Claude Code release notes" site:docs.anthropic.com OR site:code.claude.com
3. "Claude Code" site:code.claude.com/docs new features [当前年份]
4. Claude Code CLAUDE.md hooks skills "best practices" site:docs.anthropic.com [当前年份]
5. Claude Code official documentation updates [当前年份]
```

### 1.2 GitHub 社区与开源项目

```
搜索词（逐一执行）：

6. "awesome-claude-code" site:github.com new features hooks skills
7. Claude Code hooks examples site:github.com [当前年份]
8. Claude Code SKILL.md examples site:github.com [当前年份]
9. Claude Code settings.json configuration site:github.com [当前年份]
10. Claude Code workflow best practices site:github.com [当前年份]
11. Claude Code agent teams worktrees site:github.com [当前年份]
12. "claude-code-config" OR "claude-code-setup" site:github.com [当前年份]
```

### 1.3 开发者博客与深度文章

```
搜索词（逐一执行）：

13. Claude Code best practices [当前年份] site:medium.com
14. Claude Code hooks workflow automation [当前年份] site:medium.com
15. Claude Code tips tricks productivity [当前年份] site:dev.to
16. Claude Code deep dive [当前年份] site:substack.com
17. Claude Code advanced features [当前年份] developer blog
18. "how I use Claude Code" [当前年份]
19. Claude Code productivity workflow [当前年份]
20. Claude Code CLAUDE.md optimization [当前年份]
```

### 1.4 社区讨论（高质量开发者分享）

```
搜索词（逐一执行）：

21. Claude Code site:reddit.com/r/ClaudeAI [当前年份]
22. Claude Code site:reddit.com/r/LocalLLaMA [当前年份]
23. Claude Code site:news.ycombinator.com [当前年份]
24. Claude Code tips site:twitter.com OR site:x.com [当前年份]
25. Claude Code new features announcement site:threads.com [当前年份]
```

### 1.5 特定功能专项搜索

```
搜索词（逐一执行）：

26. Claude Code new hook events [当前年份]
27. Claude Code /simplify /batch usage examples [当前年份]
28. Claude Code agent teams practical guide [当前年份]
29. Claude Code MCP servers recommended [当前年份]
30. Claude Code memory system CLAUDE.md tips [当前年份]
31. Claude Code UserPromptSubmit hook examples [当前年份]
32. Claude Code git worktrees workflow [当前年份]
33. Claude Code Plan Mode best practices [当前年份]
34. Claude Code context management 200k tips [当前年份]
35. Claude Code permissions settings.json examples [当前年份]
```

### 1.6 视频和教程内容摘要

```
搜索词（逐一执行）：

36. Claude Code tutorial complete guide [当前年份]
37. Claude Code advanced tutorial [当前年份]
38. "Claude Code" workflow automation tutorial [当前年份]
```

---

## Phase 2：信息整理与分析

将收集到的信息按以下维度整理。

**维度检查清单**（确保每个领域都有覆盖）：

1. Hook 事件列表（当前 18 个，是否有新增/废弃）
2. Hook Handler 类型和能力（updatedInput / CLAUDE_ENV_FILE / Frontmatter Hooks）
3. Skills/Commands 系统变化
4. CLAUDE.md 配置结构变化
5. Auto Memory 系统变化
6. 内置命令（/simplify / /batch / /loop 等）变化
7. MCP 相关变化
8. Agent Teams 变化
9. GitHub Actions 集成变化
10. 模型名称/推荐变化
11. settings.json 结构变化

### 2.1 新功能和新特性

列出所有 guides 中**尚未涉及**的新功能：

```
# 新功能清单（待加入 guides）
- 功能名称：[描述]
  来源：[URL]
  影响文档：[哪个 guide 文件]
  优先级：[高/中/低]
```

### 2.2 已有内容的修正和更新

列出 guides 中**已有但需要更新**的内容：

```
# 需要更新的内容
- 文档：[文件名]
  位置：[章节名]
  当前内容：[现在写的是什么]
  应更新为：[最新正确内容]
  来源：[URL]
```

### 2.3 已过时或已废弃的内容

列出 guides 中**已经过时**需要删除或标注的内容：

```
# 过时内容
- 文档：[文件名]
  位置：[章节名]
  原因：[为什么过时]
  处理方式：[删除/修改/加注]
```

### 2.4 社区高价值实践

列出社区中发现的**高质量最佳实践**，值得加入 guides：

```
# 社区最佳实践
- 实践描述：[具体做法]
  来源：[开发者/文章 URL]
  建议加入：[哪个 guide 的哪个章节]
```

---

## Phase 3：评估更新范围

在执行更新前，输出完整的更新计划，供确认：

```
## 更新计划（基于 [当前日期] 的信息）

### 信息收集摘要
- 搜索执行：[N] 个查询
- 有效信息源：[N] 个
- 高质量源：[列出最重要的 3-5 个来源]

### 将更新的内容

**00-日常使用说明.md**
- [ ] [具体改动描述]

**01-CLAUDE配置架构指南.md**
- [ ] [具体改动描述]

**02-Hooks自动化配置.md**
- [ ] [具体改动描述]

**03-Skills命令配置.md**
- [ ] [具体改动描述]

**04-工作流最佳实践.md**
- [ ] [具体改动描述]

**README.md**
- [ ] 版本号更新为 vX.X
- [ ] 更新日期更新为 [当前日期]

**prompt-新项目初始化.md**
- [ ] [检查文档引用、目录结构、Skills 列表是否需要同步更新]

**prompt-旧项目迁移.md**
- [ ] [检查迁移对照表、目录结构是否需要同步更新]

**prompt-guide版本升级.md**
- [ ] [检查 Hook 事件列表、Skills 检查项、新功能知识是否需要同步更新]

### 不更新的内容（已是最新）
- [列出已经是最新、无需修改的部分]

### 无法确认的内容（信息不足）
- [列出搜索结果模糊、需要进一步确认的内容]
```

确认更新计划后，进入 Phase 4 执行。

---

## Phase 4：执行更新

按照更新计划，逐一修改各文档：

**执行原则**：
- 保持文档原有结构和风格
- 新增内容融入已有章节，不破坏文档整体逻辑
- 如果是新的大型功能，可以新增章节
- 过时内容直接删除（不保留注释）
- 每个文档更新完成后，确认行数和格式正确
- CLAUDE.md 相关内容保持 < 150 行（建议）、不超过 200 行（硬性上限）
- 00-日常使用说明.md 是面向用户的简化版，每个 01-04 中新增的用户可感知功能都应在 00 中有对应的使用说明或命令速查条目
- 更新每个文件末尾的"更新日期"

### Phase 4.5：更新后交叉验证

更新完成后，执行以下一致性检查：

- README.md 中的功能描述和文档列表是否与更新后的各文档一致
- 各文档间的交叉引用（章节号、文件名、事件数量等）是否正确
- 所有文件的版本号和更新日期是否统一
- README.md 版本记录中本次更新的描述是否准确
- Prompt 模板中引用的目录结构、Skills 列表、命令列表是否与最新 guides 同步

---

## Phase 5：输出更新报告

```
## guides 规范更新完成

### 更新日期
[当前日期]

### 信息来源质量评估
| 来源类型 | 数量 | 代表性高质量来源 |
|---------|------|----------------|
| 官方文档 | [N] | [URL] |
| GitHub 社区 | [N] | [URL] |
| 开发者博客 | [N] | [URL] |
| 社区讨论 | [N] | [URL] |

### 核心更新内容
[按重要性列出本次更新的核心内容，3-10 条]

### 各文档变更摘要
| 文档 | 变更类型 | 具体内容 |
|------|---------|---------|
| 00-日常使用说明.md | [新增/修改/删除] | [描述] |
| 01-CLAUDE配置架构指南.md | [新增/修改/删除] | [描述] |
| 02-Hooks自动化配置.md | [新增/修改/删除] | [描述] |
| 03-Skills命令配置.md | [新增/修改/删除] | [描述] |
| 04-工作流最佳实践.md | [新增/修改/删除] | [描述] |
| README.md | [新增/修改/删除] | [描述] |
| prompt-新项目初始化.md | [同步更新/无变更] | [描述] |
| prompt-旧项目迁移.md | [同步更新/无变更] | [描述] |
| prompt-guide版本升级.md | [同步更新/无变更] | [描述] |

### 未收录的内容（及原因）
[列出搜索到但决定不加入 guides 的内容，说明原因]

### 建议关注
[列出尚在实验阶段、值得下次更新时重点关注的功能或趋势]

### 下次建议更新时间
[根据 Claude Code 的迭代速度，建议下次运行此 prompt 的时间]
```

---

## 附：信息质量判断标准

执行搜索时，优先采信以下来源：

| 优先级 | 来源类型 | 判断标准 |
|--------|---------|---------|
| P0 | Anthropic 官方文档 / GitHub changelog | 权威，必须采信 |
| P1 | Anthropic 员工的博客/社交媒体 | 一手信息，高可信 |
| P2 | 知名开发者的深度文章（Medium/Substack） | 有具体操作截图/代码的优先 |
| P3 | GitHub 高 star 的 claude-code 相关项目 | star 数和 issue 活跃度为参考 |
| P4 | Reddit/HN 高赞讨论 | 多人验证的实践 |
| 不采信 | 无来源的泛化建议 / 明显过时的内容 | 时效性优先 |
