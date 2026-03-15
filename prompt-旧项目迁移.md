重要！使用 AI Agent 执行这个任务。

当前项目使用的是**旧版 AI 协作文档系统（v2.x）**，基于 `CONTEXT.md` + `CURRENT.md` + `.claude/commands/` 手动维护体系。需要迁移到新版系统（v3.x），基于 CLAUDE.md 层级 + Auto Memory + Hooks + Skills 自动化体系。

首先阅读以下所有指南，完整理解新系统理念，再开始执行：

- `~/Downloads/00_project/guides/README.md`（目录结构、命令体系、废弃对照表）
- `~/Downloads/00_project/guides/00-日常使用说明.md`
- `~/Downloads/00_project/guides/01-CLAUDE配置架构指南.md`
- `~/Downloads/00_project/guides/02-Hooks自动化配置.md`
- `~/Downloads/00_project/guides/03-Skills命令配置.md`
- `~/Downloads/00_project/guides/04-工作流最佳实践.md`

---

## 迁移核心理念

旧系统：**用文档补偿 AI 的记忆缺陷**（手动维护 CONTEXT.md/CURRENT.md，手动执行 /start /end /checkpoint）

新系统：**让 Claude Code 原生能力自动管理**（CLAUDE.md + Auto Memory + Hooks 自动化）

迁移不是删除旧文件、复制新模板。而是**提取旧系统沉淀的有效项目知识，迁移到新系统的正确位置**。

---

## 知识迁移对照表

| 旧系统 | 新系统 | 迁移方式 |
|--------|--------|---------|
| `docs/ai-context/CONTEXT.md` | 根 `CLAUDE.md` | 提取有效内容，精简重写 |
| `docs/ai-context/CURRENT.md` | Auto Memory + `/tasks`（自动）| 丢弃进度日志，有效任务保留到 session-notes.md |
| `docs/ai-context/`（整个目录） | 不再需要 | 内容提取后删除 |
| `.claude/commands/`（整个目录） | `.claude/skills/` | 升级格式后删除旧目录 |
| `.claude/commands/audit.md` | `.claude/skills/audit/SKILL.md` | 升级格式，保留核心逻辑 |
| `.claude/commands/deep-audit.md` | `.claude/skills/deep-audit/SKILL.md` | 升级格式，保留核心逻辑 |
| `.claude/commands/start.md` | `SessionStart` Hook | 废弃，自动替代 |
| `.claude/commands/end.md` | `Stop` Hook + Auto Memory | 废弃，自动替代 |
| `.claude/commands/checkpoint.md` | Claude 直接 commit | 废弃，自动替代 |
| `.claude/commands/weekly.md` | 不再需要 | 废弃（CLAUDE.md < 200 行不会膨胀，Auto Memory 无需归档） |
| `.claude/commands/monthly.md` | 不再需要 | 废弃（同上） |
| `.claude/commands/fix.md` | `PostToolUse` Hook | 废弃，自动替代 |
| 新增 | `/catchup` Skill | 清空上下文后恢复状态 |
| 新增 | `/handoff` Skill | 提交变更 + 生成交接文档 |
| 新增 | `/spec` Skill | 讨论成果整理为设计文档 |
| 新增 | `/done` Skill | 功能完成收尾检查（Roadmap/Spec 同步 + 部署配置检测） |
| 新增 | `/release` Skill | Phase 完成文档刷新（全量更新开发文档 + Changelog） |
| 新增 | `/nbp2` Skill | AI 生图 Prompt 助手（Nano Banana Pro 2） |

---

## 执行流程

### Phase 1：审计旧系统现状

使用 Explore Subagent 探索旧系统，保持主 context 干净。

```bash
# 查看旧系统文件
find docs/ai-context/ -type f 2>/dev/null
find .claude/commands/ -type f 2>/dev/null
wc -l docs/ai-context/CONTEXT.md 2>/dev/null
wc -l docs/ai-context/CURRENT.md 2>/dev/null
ls .claude/commands/ 2>/dev/null
```

同时探索项目技术栈：

```bash
# 确认当前实际技术栈和版本
cat package.json 2>/dev/null | head -30
cat pyproject.toml 2>/dev/null | head -30
# 确认测试命令和格式化工具
```

**从旧文件中提取有效内容，按类型分类**：

```
从 CONTEXT.md 提取：
├── 技术栈声明（版本号、框架选型）         → 迁移到新 CLAUDE.md
├── 项目结构说明（目录用途）               → 迁移到新 CLAUDE.md
├── 开发规范（约束和规则）                 → 迁移到新 CLAUDE.md（MUST/MUST NOT 语言）
├── 常用命令（build/test/lint/start）      → 迁移到新 CLAUDE.md
├── 协作偏好（个人习惯）                   → 迁移到 ~/.claude/CLAUDE.md
└── 进度/阶段信息                         → 丢弃（Auto Memory 接管）

从 CURRENT.md 提取：
├── 仍然有效的未完成任务                   → 保留到 .claude/session-notes.md
├── 已记录的 Bug/解决方案（仍然有效）      → 迁移到 docs/development/troubleshooting.md
└── 其余滚动日志内容                       → 丢弃

从 .claude/commands/ 提取：
├── audit.md、deep-audit.md              → 升级为 Skills 格式保留（提取核心逻辑）
└── 其余命令（start/end/checkpoint 等）   → 废弃，由 Hooks 替代
```

汇总项目画像：

```
项目类型: [类型]
技术栈: [完整技术栈，含版本号]
包管理器: [工具]
测试命令: [实际命令]
格式化工具: [实际工具]
目录结构: [结构特点]
关键约束: [从旧系统提取的重要规则]
未完成任务: [如果有仍然有效的未完成工作]
```

---

### Phase 2：设计迁移方案

在实施前，明确以下决策：

**新 CLAUDE.md 内容规划**（从旧 CONTEXT.md 提炼，目标 < 150 行）：

```
保留并重写为 MUST/MUST NOT 语言的规范: [列出]
需要更新的技术栈版本（对照实际代码）: [列出]
可以删除的过时内容: [列出]
```

**Hooks 方案**（根据项目技术栈确定）：

```
SessionStart：启动检查脚本需要什么内容？
UserPromptSubmit：是否需要自动注入 session-notes 上下文？
PreToolUse（git commit）：测试命令是什么？
PostToolUse（Write/Edit）：格式化工具和命令是什么？
Stop：是否需要完成通知？
```

**旧文件处理决策**：

```
docs/ai-context/CONTEXT.md: 内容已提取 → 删除
docs/ai-context/CURRENT.md: 内容已处理 → 删除
docs/ai-context/（整个目录）: → 删除
.claude/commands/: 迁移到 skills/ 后 → 删除
```

---

### Phase 3：执行迁移

#### 3.1 创建新 CLAUDE.md（根目录）

**不要用 `/init` 重新生成**，而是基于从旧 CONTEXT.md 提取的内容手动创建：

- 从旧 CONTEXT.md 提炼技术栈、项目结构、常用命令
- 将旧规范改写为 `MUST` / `MUST NOT` 语言（参考文档 01 的模板）
- 删除进度信息、协作日志等动态内容
- 技术栈版本对照实际代码确认准确
- 确保包含**完成标准**章节，分三部分：（1）代码验证（测试通过 + lint 通过 + 边界条件 + 回归验证）（2）文档同步（更新 `docs/roadmap/` checkbox + 更新 `docs/specs/` status 为 `implemented` + 检测部署/环境变量变更并提示更新 deployment.md + 确认代码注释）（3）Spec 实施自检（基于 spec 开发时：每完成 task 勾 `[x]` → 检查 Phase Gate → 提醒 `/done` → 所有 Phase 完成提醒 `/release`）
- 控制在 **150 行以内**

#### 3.2 生成项目路线图（ROADMAP）

使用 Explore Subagent 全面探索项目，结合旧系统中的进度信息，生成路线图。

**探索内容**：
- 所有源代码文件，按模块分类，推断已完成的功能
- git log 提交历史，了解开发脉络
- 旧 CONTEXT.md 和 CURRENT.md 中的进度信息
- package.json / pyproject.toml 等配置
- docs/ 目录中已有的规划文档
- 代码中的 TODO/FIXME 注释

**与用户讨论**：
- 将探索结果汇总，与用户确认项目整体规划
- 确认 Phase 划分和每个 Phase 的功能条目（功能模块级粒度，每个 Phase 3-8 项）
- 确认哪些功能已完成、进行中、待开始

**生成文件**：

```bash
mkdir -p docs/roadmap
```

- `docs/roadmap/README.md` — 总览：Phase 列表 + 当前聚焦的 Phase + 进度统计
- `docs/roadmap/phase-N-名称.md` — 每个 Phase 一个文件，含 checkbox 进度

**在 CLAUDE.md 中添加引用**（只引用总览 + 当前 Phase）：
```markdown
@docs/roadmap/README.md
@docs/roadmap/phase-N-名称.md
```

---

#### 3.3 处理旧 CURRENT.md 中的未完成任务

如果旧 CURRENT.md 中有仍然有效的未完成任务，写入 session-notes.md：

```bash
mkdir -p .claude
# 将有效的未完成任务写入 .claude/session-notes.md
```

格式：
```markdown
# 迁移时保留的未完成任务

## 背景
从旧系统 CURRENT.md 迁移，以下任务仍未完成：

## 待完成工作
[从旧 CURRENT.md 提取仍然有效的任务]

## 注意事项
[从旧系统保留的重要注意事项]

---
*运行 /catchup 恢复此上下文*
```

#### 3.4 创建 .claude/ 新目录结构

```
.claude/
├── settings.json              # 权限配置 + Hooks（全新创建）
├── settings.local.json        # 个人本地设置（gitignore）
├── rules/                     # 路径感知规则（按需）
├── skills/
│   ├── audit/SKILL.md         # 从旧 audit.md 升级（保留核心逻辑）
│   ├── deep-audit/SKILL.md    # 从旧 deep-audit.md 升级（保留核心逻辑）
│   ├── catchup/SKILL.md       # 新增
│   ├── handoff/SKILL.md       # 新增（含自动 commit 方案 B）
│   ├── spec/SKILL.md          # 新增（讨论成果整理为设计文档）
│   ├── done/SKILL.md          # 新增（功能完成收尾检查）
│   ├── release/SKILL.md       # 新增（Phase 完成文档刷新）
│   └── nbp2/SKILL.md          # 新增（AI 生图 Prompt 助手）
├── agents/                    # 自定义子代理（可选）
└── hooks/
    ├── session-start.sh
    ├── pre-commit-check.sh
    ├── post-write.sh
    ├── on-stop.sh
    └── on-prompt-submit.sh    # 可选
```

参考文档 `02-Hooks自动化配置.md` 和 `03-Skills命令配置.md` 中的完整模板，根据项目实际技术栈调整所有命令。

重点：`handoff/SKILL.md` 使用**方案 B**：
- 先尝试正常 commit（走测试门禁）
- 测试不过则降级为 `wip:` 前缀 + `--no-verify`
- 然后写 session-notes.md

赋予执行权限：

```bash
chmod +x .claude/hooks/*.sh
```

#### 3.5 创建 docs/ 目录结构

```bash
mkdir -p docs/specs docs/development docs/architecture/adr
```

- `docs/specs/` — `/spec` Skill 生成的设计文档存放目录
- `docs/development/` — 开发文档（参考 `04-工作流最佳实践.md` 第 7 节的模板按需生成）
- `docs/architecture/adr/` — 架构决策记录

根据项目已有的代码和文档，按需生成开发文档初始文件：
- 生成 `docs/development/getting-started.md`（新人上手指南）
- 生成 `docs/development/deployment.md`（如有部署配置）
- 创建 `docs/development/changelog.md` 空模板

> 注意：不需要手写 API 文档和数据库文档 — FastAPI/Spring Boot 自动生成 API 文档，ORM 模型定义本身就是数据库文档。在 CLAUDE.md 中指明源码路径即可。

#### 3.6 创建子目录 CLAUDE.md（Monorepo 才需要）

如果项目是 Monorepo，为各模块创建专属 CLAUDE.md（< 100 行），从旧 CONTEXT.md 中提取模块级规范。

#### 3.7 清理旧文件

确认以上步骤完成后，删除旧系统文件：

```bash
# 删除旧 AI 记忆文件（内容已迁移到 CLAUDE.md）
rm -rf docs/ai-context/

# 删除旧命令目录（已迁移到 skills/）
rm -rf .claude/commands/
```

#### 3.8 更新 .gitignore

```bash
# 确认以下内容在 .gitignore 中
grep -q "CLAUDE.local.md" .gitignore || echo "CLAUDE.local.md" >> .gitignore
grep -q "settings.local.json" .gitignore || echo ".claude/settings.local.json" >> .gitignore
grep -q "session-notes.md" .gitignore || echo ".claude/session-notes.md" >> .gitignore
```

---

### Phase 4：验证

**结构验证**：

```
[✓] 根 CLAUDE.md 存在，内容准确，< 150 行
[✓] docs/roadmap/ 目录已创建，README.md + Phase 文件已生成
[✓] CLAUDE.md 中已添加 @docs/roadmap/ 引用
[✓] .claude/settings.json 格式正确（jq . .claude/settings.json）
[✓] .claude/hooks/ 所有脚本有执行权限
[✓] .claude/skills/ 8 个 Skill 已创建（含 release、nbp2）
[✓] docs/development/ 目录已创建，按需生成初始文档
[✓] docs/architecture/adr/ 目录已创建
[✓] 旧文件已清理（docs/ai-context/、.claude/commands/）
[✓] .gitignore 已更新
```

**知识迁移验证**：

```
[✓] 旧 CONTEXT.md 中的技术栈信息已在新 CLAUDE.md 中体现（版本号准确）
[✓] 旧 CONTEXT.md 中的开发规范已改写为 MUST/MUST NOT 语言
[✓] 旧 CONTEXT.md 中的常用命令已在新 CLAUDE.md 中体现
[✓] 无价值内容（进度日志、过时信息）已清理
[✓] 有效的未完成任务已保存到 .claude/session-notes.md（如有）
```

手动测试 Hook：

```bash
bash .claude/hooks/session-start.sh

echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
  | bash .claude/hooks/pre-commit-check.sh
echo "退出码: $?"
```

---

### Phase 5：输出迁移报告

输出以下格式的报告：

```
## 旧系统迁移完成

### 迁移前后对比
| 项目 | 旧系统 | 新系统 |
|------|--------|--------|
| AI 记忆 | CONTEXT.md + CURRENT.md（手动） | CLAUDE.md + Auto Memory（自动） |
| 进度跟踪 | CURRENT.md 滚动日志（手动） | docs/roadmap/（/handoff 自动更新） |
| 命令数量 | [X] 个 commands | 8 个 Skills |
| 自动化程度 | 手动触发 /start /end /checkpoint | Hooks 全自动 |

### 知识迁移清单
- [✓] 技术栈声明（版本已核对准确）
- [✓] 项目结构说明
- [✓] 开发规范（已改写为 MUST/MUST NOT）
- [✓] 常用命令
- [如有] [✓] 未完成任务保留到 .claude/session-notes.md

### 清理的旧文件
- docs/ai-context/CONTEXT.md
- docs/ai-context/CURRENT.md
- .claude/commands/（[X] 个旧命令）

### 适配说明
[说明根据项目特点做的调整，例如：测试命令、格式化工具的具体配置]

### 日常使用变化
- 不再需要：/start、/end、/checkpoint、/weekly、/monthly、/fix
- 新的工作流：功能完成 → /simplify → Claude 自动 commit（Hook 验证后）→ 你确认 push
- 功能收尾：/done（手动兜底检查：Roadmap/Spec 状态同步 + 部署配置检测）
- 阶段完成：/release（全量刷新开发文档）→ /deep-audit（代码审计）
- 批量变更：/batch "描述"
- 需求讨论后：/spec（整理讨论成果为设计文档）
- 中断前：/handoff（自动 commit + 写交接文档）
- 上下文管理：/handoff → /clear → /catchup

### 参考
完整使用说明：~/Downloads/00_project/guides/00-日常使用说明.md
```
