# CLAUDE.md 配置架构指南

> Claude Code 原生记忆系统 — 告别手动维护，拥抱自动化记忆

**版本**: v3.4
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [范式转变](#1-范式转变)
2. [两个互补的记忆系统](#2-两个互补的记忆系统)
3. [CLAUDE.md 层级结构](#3-claudemd-层级结构)
4. [内容规范](#4-内容规范)
5. [项目根 CLAUDE.md 模板](#5-项目根-claudemd-模板)
6. [全局 CLAUDE.md 模板](#6-全局-claudemd-模板)
7. [路径感知规则 .claude/rules/](#7-路径感知规则-clauderules)
8. [Auto Memory 管理](#8-auto-memory-管理)
9. [初始化流程](#9-初始化流程)
10. [维护指南](#10-维护指南)

---

## 1. 范式转变

### 旧方案 vs 新方案

| 维度 | 旧方案（2025 年以前） | 新方案（2026 年） |
|------|---------------------|-----------------|
| 记忆机制 | 手动维护 `CONTEXT.md` + `CURRENT.md` | CLAUDE.md 层级 + Auto Memory 原生系统 |
| 每次开始 | 执行 `/start` 命令恢复上下文 | `SessionStart` Hook 自动触发 + Auto Memory 自动恢复 |
| 每日结束 | 执行 `/end` 命令手动更新文档 | `Stop` Hook 自动触发，Auto Memory 自动记录 |
| 进度跟踪 | 手动写 `CURRENT.md` 滚动日志 | Auto Memory 自动维护，`/tasks` 查看任务列表 |
| Token 优化 | 每周归档，手动控制文件大小 | CLAUDE.md < 200 行 + 子目录懒加载 |
| 会话恢复 | 手动执行命令重新加载文档 | Auto Memory 自动恢复，无需手动操作 |

**核心变化**：Claude Code 已内置完善的记忆管理系统。旧方案中 `CONTEXT.md`、`CURRENT.md`、`/start`、`/end`、`/weekly`、`/monthly` 这一整套手工维护体系已被原生能力替代，**无需手动维护 AI 记忆文件**。

---

## 2. 两个互补的记忆系统

### 2.1 CLAUDE.md（你负责维护）

稳定的项目知识，版本控制，团队共享。

**特性**：
- 根目录 `CLAUDE.md` 每次会话自动加载
- 子目录 `CLAUDE.md` **懒加载**（编辑对应目录文件时才加载）
- 超过 **200 行**后遵从度明显下降
- 支持 `@path/to/file` 语法引用外部文件内容（最多 5 层）

### 2.2 Auto Memory（Claude 自动维护）

跨会话学习的偏好和项目知识，完全自动化。

**特性**：
- 存储位置：`~/.claude/projects/<项目 hash>/memory/`
- `MEMORY.md` **前 200 行**每次会话自动加载
- 主题文件（如 `debugging.md`、`patterns.md`）按需加载
- Claude 根据你的纠正和偏好自动更新
- 使用 `/memory` 命令查看和管理

### 2.3 如何分工

| 内容类型 | 存放位置 |
|---------|---------|
| 架构规范、团队约定 | `CLAUDE.md`（版本控制，团队共享） |
| 构建/测试/启动命令 | `CLAUDE.md` |
| 技术栈版本声明 | `CLAUDE.md` |
| 个人开发偏好 | `~/.claude/CLAUDE.md` 或 `CLAUDE.local.md` |
| 跨会话学到的调试技巧 | Auto Memory（Claude 自动维护） |
| 项目阶段进度 | Auto Memory（自动）+ 必要时手动编辑 |
| 临时任务列表 | `/tasks` 命令（内置任务列表，Ctrl+T 查看） |

---

## 3. CLAUDE.md 层级结构

### 3.1 文件位置与加载优先级

```
/Library/Application Support/ClaudeCode/CLAUDE.md   ← 企业托管（最高优先级，不可覆盖）
~/.claude/CLAUDE.md                                  ← 全局个人偏好（所有项目）
./CLAUDE.md                                          ← 项目规范（团队共享，版本控制）
./.claude/CLAUDE.md                                  ← 项目规范（备选位置）
./CLAUDE.local.md                                    ← 个人本地配置（gitignore）
./src/CLAUDE.md                                      ← 子目录规范（懒加载）
./.claude/rules/frontend.md                          ← 路径感知规则（匹配时加载）
```

**规则**：更具体的范围优先。多个文件同时存在时，内容合并，具体规则覆盖通用规则。

### 3.2 Monorepo 推荐目录结构

```
project-root/
├── CLAUDE.md                      # 必读：项目总览、共享命令、Git 规范（< 150 行）
├── CLAUDE.local.md                # gitignore：个人本地环境配置
│
├── .claude/
│   ├── settings.json              # 权限、模型、行为配置
│   ├── settings.local.json        # 个人本地设置（gitignore）
│   ├── rules/
│   │   ├── frontend.md            # 仅编辑 apps/web/** 时加载
│   │   └── backend.md             # 仅编辑 apps/api/** 时加载
│   ├── skills/                    # 自定义命令（见《03-Skills命令配置》）
│   ├── agents/                    # 自定义子代理
│   └── hooks/
│       └── hooks.json             # 自动化钩子（见《02-Hooks自动化配置》）
│
├── apps/
│   ├── web/
│   │   └── CLAUDE.md              # 懒加载：前端专属规范（< 100 行）
│   └── api/
│       └── CLAUDE.md              # 懒加载：后端专属规范（< 100 行）
│
├── packages/
│   └── shared/
│       └── CLAUDE.md              # 懒加载：共享包规范（< 50 行）
│
└── docs/
    ├── roadmap/                   # 项目路线图（@引用当前 Phase）
    ├── specs/                     # 功能设计文档（/spec 生成）
    └── architecture/              # ADR 等架构文档
```

**Token 预算参考**：

| 文件 | 目标行数 | 估算 Token |
|------|---------|-----------|
| 根 `CLAUDE.md` | < 150 行 | ~1200 |
| `@` 引用文件（roadmap 总览 + 当前 Phase） | 按需 | ~800-1500 |
| 子目录 `CLAUDE.md`（各） | < 100 行 | ~800 |
| `.claude/rules/`（各） | < 60 行 | ~500 |
| 全局 `~/.claude/CLAUDE.md` | < 60 行 | ~500 |
| 会话基线总计 | — | < 6000 |

---

## 4. 内容规范

### 4.1 应该写什么

- **项目结构**：一段话说明各目录用途
- **常用命令**：构建/测试/启动，可直接复制执行
- **硬性约束**：用 `MUST` / `MUST NOT` 语言表达，**附带原因**（why 比 what 更有效，帮助 Claude 在未预料场景中做正确判断）
- **技术栈声明**：框架名 + 版本号
- **关键决策**：团队选型原因（一行即可）

### 4.2 不应该写什么

- ❌ 详细代码示例（用文件路径引用代替：`参考 src/auth/login.ts`）
- ❌ 任务特定的临时指令（放在对话中说即可）
- ❌ 代码格式规则（应在 linter 配置中强制执行）
- ❌ 已过时的功能描述
- ❌ 超过 200 行的内容（拆分到子目录或 `.claude/rules/`）

### 4.3 语言规范

使用 RFC 2119 语义词汇，避免模糊表述：

| 模糊（❌） | 明确（✅） |
|-----------|---------|
| "尽量写测试" | "MUST 提交前运行 `pnpm test`" |
| "保持代码整洁" | "MUST NOT 提交 ESLint errors" |
| "注意安全" | "MUST NOT 硬编码密钥或密码" |
| "用 TypeScript" | "MUST 使用 TypeScript 严格模式（`strict: true`）" |
| "优先用现有库" | "MUST NOT 自造已有成熟库的功能（如日期用 dayjs，HTTP 用 axios）" |

---

## 5. 项目根 CLAUDE.md 模板

```markdown
# [项目名称]

> [一句话描述：这是什么项目，解决什么问题]

## 项目结构

- `apps/web/` — [前端框架] 前端，开发端口 [port]
- `apps/api/` — [后端框架] 后端，API 端口 [port]
- `packages/shared/` — 共享类型定义和工具函数
- `docs/` — 架构文档和 ADR 记录

## 常用命令

```bash
pnpm install          # 安装依赖
pnpm dev              # 启动所有服务（同时启动前后端）
pnpm dev:web          # 仅启动前端
pnpm dev:api          # 仅启动后端
pnpm test             # 运行所有测试
pnpm lint             # 代码检查
pnpm lint:fix         # 自动修复可修复的问题
pnpm build            # 生产构建
```

## 技术栈

- **前端**: React 18, TypeScript 5.x, Vite 6, Tailwind CSS 4, Zustand
- **后端**: FastAPI 0.11x, Python 3.12, SQLAlchemy 2.0, Alembic
- **数据库**: PostgreSQL 17
- **包管理**: pnpm 10

## 开发约束

- MUST 提交前运行 `pnpm test`，测试不通过禁止提交
- MUST 使用 TypeScript 严格模式（`strict: true`），禁止 `any` 类型
- MUST NOT 硬编码密钥、密码或敏感配置（使用环境变量）
- MUST NOT 修改测试文件以适配错误的实现（先修复实现）
- MUST NOT 自造已有成熟库的功能
- SHOULD 每个 PR 只做一件事，保持 diff 可读

## Git 提交规范

```
<type>(<scope>): <subject>

type: feat | fix | docs | refactor | perf | test | chore
示例: feat(auth): 添加 JWT 刷新机制
```

## 关键架构决策

- 状态管理：Zustand（非 Redux，避免模板代码）
- API 通信：REST（非 GraphQL，业务复杂度不需要）
- 认证：JWT + Refresh Token（非 Session，支持移动端）
- 详细 ADR 记录见 `docs/architecture/adr/`

## 引用文档

@docs/roadmap/README.md
@docs/roadmap/phase-2-核心业务.md
```

---

## 6. 全局 CLAUDE.md 模板

存放于 `~/.claude/CLAUDE.md`，适用于所有项目的个人偏好，保持 **60 行以内**：

```markdown
# 全局开发偏好

## 工作节奏

- MUST 编码前先说明方案，等待确认再实施
- MUST 每个独立步骤完成后等待我的反馈
- SHOULD 说明每次改动的原因（why，不只是 what）

## 代码风格

- 注释使用中文
- 优先可读性，变量命名要有意义
- 不需要在每个函数上加 JSDoc（除非逻辑不自明）

## 工具偏好

- 包管理器: pnpm
- Git 提交: 使用 HEREDOC 格式，遵循 Conventional Commits
- 不要自动 `git push`，提交后等我确认
```

---

## 7. 路径感知规则 `.claude/rules/`

将专属规范按文件路径划分，仅在 Claude 编辑对应文件时加载，减少无关上下文：

### 前端规则示例 `.claude/rules/frontend.md`

```markdown
---
paths:
  - "apps/web/src/**/*.tsx"
  - "apps/web/src/**/*.ts"
---

## 前端规范

- MUST 使用函数式组件（禁止 class 组件）
- MUST 使用 Zustand 管理全局状态（禁止 Redux 或 React Context）
- MUST 将 API 调用封装在 `hooks/` 目录的自定义 Hook 中
- MUST NOT 在组件内直接调用 fetch/axios
- SHOULD 组件文件不超过 200 行，超过则拆分
- 命名：组件 PascalCase，文件名与组件名一致
- 样式：Tailwind CSS utility-first，避免自定义 CSS
```

### 后端规则示例 `.claude/rules/backend.md`

```markdown
---
paths:
  - "apps/api/**/*.py"
---

## 后端规范

- MUST 使用 async/await（禁止同步阻塞函数）
- MUST 在 router 层用 Pydantic schema 做参数校验
- MUST 使用 FastAPI Depends 做依赖注入
- MUST NOT 在 router 中直接写 SQL（封装到 repository 层）
- SHOULD 每个 API 模块有对应的 pytest 测试文件
- 错误响应统一格式：`{"error": {"code": str, "message": str}}`
```

---

## 8. Auto Memory 管理

### 8.1 查看和操作

```bash
# Claude Code 内部命令
/memory         # 查看所有 CLAUDE.md 文件状态和 Auto Memory 开关
```

### 8.2 Memory 目录结构

Claude 自动在以下位置维护记忆文件：

```
~/.claude/projects/<git-repo-hash>/memory/
├── MEMORY.md           # 索引文件，前 200 行自动加载
├── debugging.md        # 调试技巧（按需加载）
└── patterns.md         # 代码模式偏好（按需加载）
```

### 8.3 何时手动介入

| 情况 | 处理方式 |
|------|---------|
| Claude 反复犯同一个错误 | 将正确做法写入 `CLAUDE.md`（MUST NOT 语言） |
| 你纠正了某个偏好 | Auto Memory 自动记录，无需操作 |
| 发现 Auto Memory 记录了错误信息 | `/memory` 命令进入编辑 |
| 项目架构发生重大变化 | 手动更新 `CLAUDE.md`，不依赖 Auto Memory |
| 想在团队间共享某条知识 | 从 Auto Memory 提取，写入版本控制的 `CLAUDE.md` |

### 8.4 禁用 Auto Memory

```json
// .claude/settings.json
{
  "autoMemoryEnabled": false
}
```

或环境变量：`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`

---

## 9. 初始化流程

### 新项目初始化

```bash
# 1. 进入项目根目录，启动 Claude Code
claude

# 2. 自动生成 CLAUDE.md 草稿
/init
# Claude 会扫描代码库，发现构建命令、测试框架、项目结构，生成草稿

# 3. 手动精简草稿到 150 行以内
# 重点：删除泛化内容，保留项目特有的约束

# 4. 创建子目录 CLAUDE.md（如果是 Monorepo）

# 5. 创建路径感知规则
mkdir -p .claude/rules
# 创建 frontend.md、backend.md 等

# 6. 配置 .claude/settings.json（权限设置）

# 7. 将 CLAUDE.local.md 加入 .gitignore
echo "CLAUDE.local.md" >> .gitignore
echo ".claude/settings.local.json" >> .gitignore
```

### 从旧方案迁移

```bash
# 旧 CONTEXT.md 内容迁移策略：
# ✅ 提取"技术栈"部分 → 根 CLAUDE.md 技术栈章节
# ✅ 提取"开发规范"部分 → 用 MUST/MUST NOT 语言重写
# ✅ 提取"项目结构"部分 → 根 CLAUDE.md 项目结构章节
# ✅ 提取"协作偏好"部分 → ~/.claude/CLAUDE.md
# ❌ 丢弃"进度/日志"部分 → 由 Auto Memory 自动接管
# ❌ 丢弃"待办任务"部分 → 使用 /tasks 内置任务列表

# 清理旧文件
rm docs/ai-context/CONTEXT.md
rm docs/ai-context/CURRENT.md
# 旧的 docs/ai-context/ 目录可以删除
```

---

## 10. 维护指南

### 每月检查清单

- [ ] `CLAUDE.md` 技术栈版本是否仍然准确？
- [ ] 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- [ ] 行数是否接近 200 行？需要拆分到子目录？
- [ ] Auto Memory 是否有需要"固化"到 `CLAUDE.md` 的内容？
- [ ] `@import` 引用的文件是否仍然有效？

### 信号与响应

| 信号 | 响应 |
|------|------|
| Claude 反复忽略某条规定 | 用更强的 `MUST NOT` 语言重写；检查是否超过 200 行导致忽略 |
| Claude 反复问同样的背景问题 | 将答案加入 `CLAUDE.md` |
| 同一个 Bug 出现两次 | 在 `CLAUDE.md` 加入防范约束 |
| Claude 上下文加载很慢 | 检查 `@import` 引用的文件大小；检查是否有不必要的大文件引用 |

---

**版本**: v3.4
**更新日期**: 2026-03
