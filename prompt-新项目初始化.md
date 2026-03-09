重要！使用 AI Agent 执行这个任务。

你正在为一个**全新项目**配置 Claude Code 协作系统。项目此前没有任何 AI 协作配置。

首先阅读以下所有指南，完整理解整套体系，再开始执行：

- `~/Downloads/00_project/guides/README.md`（目录结构、命令体系、废弃对照表）
- `~/Downloads/00_project/guides/00-日常使用说明.md`
- `~/Downloads/00_project/guides/01-CLAUDE配置架构指南.md`
- `~/Downloads/00_project/guides/02-Hooks自动化配置.md`
- `~/Downloads/00_project/guides/03-Skills命令配置.md`
- `~/Downloads/00_project/guides/04-工作流最佳实践.md`

---

## 执行流程

### Phase 1：探索当前项目

使用 Explore Subagent 探索项目，保持主 context 干净。

探索重点：

1. **项目类型**：Web 应用 / API 服务 / 工具库 / CLI / Monorepo？
2. **技术栈全景**：前端框架、后端框架、数据库、包管理器、构建工具及版本号
3. **目录结构**：单应用还是 Monorepo？关键目录的用途
4. **现有配置**：package.json / pyproject.toml / pom.xml 中的脚本和依赖
5. **测试框架**：用什么测试工具？测试命令是什么？
6. **代码风格工具**：ESLint / Prettier / Black / 其他？
7. **开发阶段**：初始化 / 原型 / 生产运行中

汇总项目画像：

```
项目类型: [具体类型]
技术栈: [前端] + [后端] + [数据库]
包管理器: [npm/yarn/pnpm/bun/pip/maven]
测试命令: [pnpm test / pytest / mvn test / ...]
格式化工具: [prettier / black / gofmt / ...]
目录结构: [单应用/Monorepo，关键目录]
开发阶段: [初始化/MVP/生产]
特殊之处: [任何需要特殊处理的地方]
```

---

### Phase 2：设计适配方案

根据项目特点，在实施前明确以下决策：

**CLAUDE.md 层级设计**：

```
根 CLAUDE.md（< 150 行）：放什么内容？
子目录 CLAUDE.md：Monorepo 才需要，每个 app 放什么？
.claude/rules/：是否需要路径感知规则？前端/后端各用什么路径 glob？
```

**Hooks 选择**：

```
SessionStart：启动时检查 git 状态？检查 .env 文件存在？
UserPromptSubmit：是否需要每次 prompt 自动注入 session-notes 上下文？
PostToolUse（Write/Edit）：需要自动格式化吗？格式化工具和命令是什么？
PreToolUse（Bash git commit）：测试门禁命令是什么？
Stop：是否需要完成通知？（macOS / Linux）
```

**Skills 选择**：

```
必须：audit、deep-audit、catchup、handoff（含自动 commit 逻辑）、spec（讨论成果整理）、done（功能完成收尾）
可选：是否有项目特定的高频操作值得封装为命令？
```

**Agent Teams**（可选）：

```
是否有大型并行开发需求？如有，在 settings.json 中启用：
"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}
```

---

### Phase 3：生成项目路线图（ROADMAP）

使用 Explore Subagent 全面探索项目的代码、文档、git log、配置文件等，自动生成项目路线图。

#### 3.1 创建目录结构

```bash
mkdir -p docs/roadmap
```

#### 3.2 探索并生成路线图

让 Claude 用 subagent 探索以下内容，建立项目全貌：

- **已有代码**：扫描所有源文件，按模块分类，推断已完成的功能
- **git log**：分析提交历史，了解开发脉络
- **package.json / pyproject.toml**：了解依赖和脚本
- **docs/ 目录**：是否有已有的规划文档
- **Issues / TODO**：扫描代码中的 TODO/FIXME 注释

#### 3.3 与用户讨论

将探索结果汇总，与用户讨论：
- 项目整体目标和功能规划
- Phase 划分方式（按功能模块 / 按时间阶段 / 按优先级）
- 每个 Phase 的具体功能条目（功能模块级粒度，每个 Phase 3-8 项）

#### 3.4 生成文件

根据讨论结果，生成以下文件：

**`docs/roadmap/README.md`**（总览）：
```markdown
# 项目路线图

## 当前阶段：Phase N

| Phase | 状态 | 进度 |
|-------|------|------|
| Phase 1 — [名称] | ✅ 完成 / 🏗️ 进行中 / ⏳ 未开始 | N/M |
| Phase 2 — [名称] | ... | N/M |
```

**`docs/roadmap/phase-N-名称.md`**（每个 Phase 一个文件）：
```markdown
# Phase N — [名称]

> [一句话描述这个阶段的目标]

## 功能清单

- [x] ✅ YYYY/MM/DD [已完成的功能]
- [-] 🏗️ YYYY/MM/DD [进行中的功能]
- [ ] [待办功能]
```

#### 3.5 在 CLAUDE.md 中添加引用

在后续生成的 CLAUDE.md 中加入当前 Phase 的引用：
```markdown
@docs/roadmap/README.md
@docs/roadmap/phase-N-名称.md
```

只引用总览 + 当前 Phase，已完成的 Phase 不引用。

---

### Phase 4：生成并精简 CLAUDE.md

运行内置命令生成草稿：

```bash
/init
```

对生成的草稿进行精简和改造：

- 删除泛化内容，只保留项目特有的信息
- 将规范语言改为 `MUST` / `MUST NOT` 表述（参考文档 01 的语言规范）
- 确保包含：项目结构说明、常用命令（含测试/构建/启动）、技术栈（含版本号）、关键约束、Git 提交规范（Conventional Commits）、关键架构决策
- **完成标准**章节分两部分：（1）代码验证（测试通过 + lint 通过 + 边界条件 + 回归验证）（2）文档同步（更新 `docs/roadmap/` checkbox + 更新 `docs/specs/` status 为 `implemented` + 确认代码注释）
- 控制在 **150 行以内**
- Monorepo 则还需为各 app 子目录创建专属 CLAUDE.md（< 100 行）

---

### Phase 5：创建 .claude/ 目录结构

```
.claude/
├── settings.json              # 权限配置 + Hooks
├── settings.local.json        # 个人本地设置（gitignore）
├── rules/                     # 路径感知规则（按需）
│   ├── frontend.md
│   └── backend.md
├── skills/
│   ├── audit/SKILL.md
│   ├── deep-audit/SKILL.md
│   ├── catchup/SKILL.md
│   ├── handoff/SKILL.md       # 含自动 commit 逻辑（方案B）
│   ├── spec/SKILL.md          # 讨论成果整理为设计文档
│   └── done/SKILL.md          # 功能完成收尾检查
├── agents/                    # 自定义子代理（可选）
└── hooks/
    ├── session-start.sh
    ├── pre-commit-check.sh
    ├── post-write.sh
    ├── on-stop.sh
    └── on-prompt-submit.sh    # 可选，自动注入 session-notes
```

#### 5.1 配置 settings.json

参考文档 `02-Hooks自动化配置.md` 中的完整配置示例，根据项目技术栈调整：

- `permissions.allow`：允许 Claude 自动执行的 git 和构建命令
- `permissions.ask`：需要弹出确认的操作（`git push *`）
- `permissions.deny`：直接拒绝的危险操作（`git push --force *`、`git reset --hard *`）
- `hooks`：按 Phase 2 的决策配置各 Hook

注意：`UserPromptSubmit`、`InstructionsLoaded`、`ConfigChange`、`WorktreeCreate`、`WorktreeRemove`、`TeammateIdle`、`TaskCompleted`、`SessionEnd`、`SubagentStart`、`Setup` 不支持 matcher 字段。

#### 5.2 创建 Hook 脚本

参考文档 `02-Hooks自动化配置.md` 中的模板，根据项目调整：

- `session-start.sh`：显示 git 状态、检查 .env 文件、显示未推送 commit 数
- `pre-commit-check.sh`：提交前运行测试（用 Phase 1 确认的测试命令）
- `post-write.sh`：写文件后自动格式化（用 Phase 1 确认的格式化工具）
- `on-stop.sh`：完成通知（macOS 用 osascript，Linux 用 notify-send）
- `on-prompt-submit.sh`（如需要）：读取 .claude/session-notes.md 注入为上下文

赋予执行权限：

```bash
chmod +x .claude/hooks/*.sh
```

#### 5.3 创建 Skills

参考文档 `03-Skills命令配置.md` 中的完整内容，按项目调整：

- `audit/SKILL.md`：检查命令用项目实际的 lint/test 命令
- `deep-audit/SKILL.md`：扫描路径用项目实际目录结构
- `catchup/SKILL.md`：读取 CLAUDE.md 和 session-notes.md 恢复状态
- `handoff/SKILL.md`：**使用方案 B** — 先尝试正常 commit（走测试门禁），失败则降级为 `wip:` 前缀 + `--no-verify`，然后写 session-notes.md
- `spec/SKILL.md`：将需求讨论成果整理为结构化设计文档，写入 `docs/specs/`
- `done/SKILL.md`：功能完成收尾检查（验证 + Roadmap 更新 + Spec 状态更新）

#### 5.4 创建路径感知规则（Monorepo 或前后端分离项目）

参考文档 `01-CLAUDE配置架构指南.md` 中的模板，创建 `.claude/rules/frontend.md` 和 `.claude/rules/backend.md`，在 frontmatter 中用 `paths:` 指定生效路径。

#### 5.5 创建 docs/ 目录结构

```bash
mkdir -p docs/roadmap docs/specs
```

- `docs/roadmap/` — Phase 3 已创建路线图文件
- `docs/specs/` — `/spec` Skill 生成的设计文档存放目录

#### 5.6 更新 .gitignore

确保以下内容在 .gitignore 中：

```
CLAUDE.local.md
.claude/settings.local.json
.claude/session-notes.md
```

---

### Phase 6：验证

```
[✓] CLAUDE.md 存在，内容准确，行数 < 150
[✓] docs/roadmap/ 目录已创建，README.md + Phase 文件已生成
[✓] CLAUDE.md 中已添加 @docs/roadmap/README.md 和当前 Phase 引用
[✓] .claude/settings.json 格式正确（可用 jq . .claude/settings.json 验证）
[✓] .claude/hooks/ 所有脚本有执行权限（ls -la .claude/hooks/）
[✓] .claude/skills/ 6 个 Skill 已创建（audit / deep-audit / catchup / handoff / spec / done）
[✓] .gitignore 包含 CLAUDE.local.md、session-notes.md 等
[✓] Monorepo：各子目录 CLAUDE.md 已创建
[✓] 按需：.claude/rules/ 路径配置正确
```

手动测试 Hook 脚本是否正常运行：

```bash
# 测试 session-start
bash .claude/hooks/session-start.sh

# 测试 pre-commit-check（模拟 git commit 输入）
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
  | bash .claude/hooks/pre-commit-check.sh
echo "退出码: $?"

# 测试 post-write（模拟写文件）
echo '{"tool_name":"Write","tool_input":{"path":"src/test.ts"}}' \
  | bash .claude/hooks/post-write.sh
```

---

### Phase 7：输出初始化报告

输出以下格式的报告：

```
## Claude Code 协作系统初始化完成

### 项目画像
- 类型: [项目类型]
- 技术栈: [完整技术栈 + 版本号]
- 结构: [单应用/Monorepo]

### 已配置内容
- CLAUDE.md: [行数] 行（根目录）
- 路线图: docs/roadmap/（[N] 个 Phase 文件）
- 子目录 CLAUDE.md: [数量] 个（如有）
- .claude/rules/: [数量] 个规则文件（如有）
- Hooks 已启用: [SessionStart / PreToolUse / PostToolUse / Stop / UserPromptSubmit（如有）]
- Skills: audit / deep-audit / catchup / handoff / spec / done
- Agent Teams: [已启用 / 未启用]

### 适配说明
[说明与标准模板的差异及原因，例如：测试命令用 pytest 而非 pnpm test]

### 日常使用
- 开始开发：直接说需求（Hook 自动运行）
- 功能完成：/simplify 审查 → 你手动 commit → 你确认 push
- 功能收尾：/done（手动兜底检查：Roadmap/Spec 状态同步）
- 批量跨文件变更：/batch "描述"
- 需求讨论后：/spec（整理讨论成果为设计文档）
- 中断前：/handoff（自动 commit + 写交接文档）
- 接续任务：/catchup
- 上下文接近 70%：/handoff → /clear → /catchup
- 每周：/audit
- 阶段完成：/deep-audit

### 参考
完整使用说明：~/Downloads/00_project/guides/00-日常使用说明.md
```
