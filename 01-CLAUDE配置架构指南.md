# CLAUDE.md 配置架构指南

> Claude Code 原生记忆系统 — 告别手动维护，拥抱自动化记忆

**版本**: v3.17
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [两个互补的记忆系统](#1-两个互补的记忆系统)
2. [CLAUDE.md 层级结构](#2-claudemd-层级结构)
3. [内容规范](#3-内容规范)
4. [项目根 CLAUDE.md 模板](#4-项目根-claudemd-模板)
5. [全局 CLAUDE.md 模板](#5-全局-claudemd-模板)
6. [路径感知规则 .claude/rules/](#6-路径感知规则-clauderules)
7. [初始化流程](#7-初始化流程)
8. [维护指南](#8-维护指南)

---

## 1. 两个互补的记忆系统

### 1.1 CLAUDE.md（你负责维护）

稳定的项目知识，版本控制，团队共享。

**特性**：
- 根目录 `CLAUDE.md` 每次会话自动加载
- 子目录 `CLAUDE.md` **懒加载**（编辑对应目录文件时才加载）
- 超过 **200 行**后遵从度明显下降
- 支持 `@path/to/file` 语法引用外部文件内容（最多 5 层）

### 1.2 Auto Memory（Claude 自动维护）

跨会话学习的偏好和项目知识，完全自动化。

**特性**：
- 存储位置：`~/.claude/projects/<项目路径编码>/memory/`
- `MEMORY.md` **前 200 行**每次会话自动加载
- 主题文件（如 `debugging.md`、`patterns.md`）按需加载
- Claude 根据你的纠正和偏好自动更新
- 使用 `/memory` 命令查看和管理

**何时手动介入**：

| 情况 | 处理方式 |
|------|---------|
| Claude 反复犯同一个错误 | 将正确做法写入 `CLAUDE.md`（MUST NOT 语言） |
| 你纠正了某个偏好 | Auto Memory 自动记录，无需操作 |
| 发现 Auto Memory 记录了错误信息 | `/memory` 命令进入编辑 |
| 项目架构发生重大变化 | 手动更新 `CLAUDE.md`，不依赖 Auto Memory |
| 想在团队间共享某条知识 | 从 Auto Memory 提取，写入版本控制的 `CLAUDE.md` |

**禁用**：在 `.claude/settings.json` 中设置 `"autoMemoryEnabled": false`，或环境变量 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`。

### 1.3 如何分工

| 内容类型 | 存放位置 |
|---------|---------|
| 架构规范、团队约定 | `CLAUDE.md`（版本控制，团队共享） |
| 构建/测试/启动命令 | `CLAUDE.md` |
| 技术栈版本声明 | `CLAUDE.md` |
| 个人开发偏好 | `~/.claude/CLAUDE.md` 或 `CLAUDE.local.md` |
| 跨会话学到的调试技巧 | Auto Memory（Claude 自动维护） |
| 项目阶段进度 | `docs/roadmap/` 目录（持久化进度跟踪） |
| 临时任务列表 | `/tasks` 命令（内置任务列表，Ctrl+T 查看） |

---

## 2. CLAUDE.md 层级结构

### 2.1 文件位置与加载优先级

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

### 2.2 Monorepo 推荐目录结构

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
│   ├── skills/                    # 自定义命令（11 个，见《03-Skills命令配置》）
│   ├── agents/                    # 自定义子代理
│   └── hooks/                     # Hook 脚本目录（见《02-Hooks自动化配置》）
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
    ├── development/               # 开发文档（/release 刷新）
    │   ├── getting-started.md     #   手写：新人上手指南
    │   ├── deployment.md          #   手写：部署流程、环境变量、回滚
    │   └── changelog.md           #   自动生成：版本发布记录
    └── architecture/
        ├── README.md              # 架构总览（@引用自动加载，/docs 刷新）
        ├── frontend.md            # 前端架构详细（/docs frontend 刷新）
        ├── backend.md             # 后端架构详细（/docs backend 刷新）
        └── adr/                   # 架构决策记录（/release 检查是否需要新增）
```

**Token 预算参考**：

| 文件 | 目标行数 | 估算 Token |
|------|---------|-----------|
| 根 `CLAUDE.md` | < 150 行 | ~1200 |
| `@` 引用文件（架构文档 + roadmap 总览 + 当前 Phase） | 按需 | ~1200-2500 |
| 子目录 `CLAUDE.md`（各） | < 100 行 | ~800 |
| `.claude/rules/`（各） | < 60 行 | ~500 |
| 全局 `~/.claude/CLAUDE.md` | < 60 行 | ~500 |
| 会话基线总计 | — | < 6000 |

---

## 3. 内容规范

### 3.1 应该写什么

- **项目结构**：一段话说明各目录用途
- **常用命令**：构建/测试/启动，可直接复制执行
- **硬性约束**：用 `MUST` / `MUST NOT` 语言表达，**附带原因**（why 比 what 更有效，帮助 Claude 在未预料场景中做正确判断）
- **技术栈声明**：框架名 + 版本号
- **关键决策**：团队选型原因（一行即可）

### 3.2 不应该写什么

- ❌ 详细代码示例（用文件路径引用代替：`参考 src/auth/login.ts`）
- ❌ 任务特定的临时指令（放在对话中说即可）
- ❌ 代码格式规则（应在 linter 配置中强制执行）
- ❌ 已过时的功能描述
- ❌ 超过 200 行的内容（拆分到子目录或 `.claude/rules/`）

### 3.3 语言规范

使用 RFC 2119 语义词汇，避免模糊表述：

| 模糊（❌） | 明确（✅） |
|-----------|---------|
| "尽量写测试" | "MUST 提交前运行 `pnpm test`" |
| "保持代码整洁" | "MUST NOT 提交 ESLint errors" |
| "注意安全" | "MUST NOT 硬编码密钥或密码" |
| "用 TypeScript" | "MUST 使用 TypeScript 严格模式（`strict: true`）" |
| "优先用现有库" | "MUST NOT 自造已有成熟库的功能（如日期用 dayjs，HTTP 用 axios）" |

---

## 4. 项目根 CLAUDE.md 模板

````markdown
# [项目名称]

> [一句话描述：这是什么项目，解决什么问题]

## 项目结构

- `apps/web/` — [前端框架] 前端，开发端口 [port]
- `apps/api/` — [后端框架] 后端，API 端口 [port]
- `apps/api/routers/` — API 路由定义（自动生成文档：http://localhost:8000/docs）
- `apps/api/models/` — 数据模型定义（ORM）
- `apps/api/migrations/` — 数据库迁移脚本
- `packages/shared/` — 共享类型定义和工具函数
- `docs/` — 开发文档、架构决策记录、项目路线图

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

## 编码红线（任何场景，包括修 Bug，MUST NOT 违反）

- MUST NOT 复制现有函数并微调来修复问题，MUST 修改原函数或提取公共逻辑
- MUST NOT 绕过现有组件/工具函数封装，直接实现重复功能
- MUST NOT 引入临时方案（hardcode、magic number、TODO hack）

> 技术栈专属红线放 `.claude/rules/`，按路径自动加载，不占 CLAUDE.md 行数预算。

## 完成标准

功能实现后，MUST 按顺序完成以下验证再报告"完成"：

### 测试验证
1. 关键用户交互 MUST 有集成测试（测完整操作链路：渲染页面→模拟操作→验证结果）
   - 前端：用 React Testing Library + MSW（MUST NOT mock fetch/axios，MUST 用 MSW 拦截网络层）
   - 后端：用 TestClient（FastAPI）/ MockMvc（Spring Boot）测完整请求链路
2. 纯计算逻辑（日期格式化、金额计算等）有单元测试
3. 运行 `pnpm test`，所有测试通过
4. 运行 `pnpm lint`，无 error
5. 检查边界条件：空值、异常输入、权限不足
6. 确认改动不影响现有功能（回归验证）

### 文档同步（功能完成时）
5. 更新 `docs/roadmap/` 对应条目的 checkbox 状态
6. 如有关联 Spec：
   - Spec 有 Implementation Phases → 更新 `active_phase`（仅当前 Phase 完成时）
   - Spec 所有 Phase 完成 → 更新 status 为 `implemented`
   - Spec 无 Phases（旧结构）→ 直接更新 status 为 `implemented`
7. 确认代码注释反映最终实现

### Spec 实施自检（基于 spec 开发时）
8. 每完成一个 task → 在 spec 文件中勾选 `[x]`
9. 当前 Phase 所有 Tasks 勾完 → 逐条检查 Gate 条件
10. Gate 全通过 → 更新 spec frontmatter 的 `active_phase`，提醒执行 `/done`
11. `/done` 检测：Spec 是否全部完成、Roadmap Phase 是否全部完成

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

@docs/architecture/README.md
@docs/roadmap/README.md
@docs/roadmap/phase-2-核心业务.md
````

---

## 5. 全局 CLAUDE.md 模板

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

## 6. 路径感知规则 `.claude/rules/`

将专属规范按文件路径划分，仅在 Claude 操作对应文件时加载，减少无关上下文。

> **已知限制**：`paths` 规则仅在 Read 操作时触发加载，Write 操作不触发。重要规则不要完全依赖 `paths` 条件，关键约束应放在根 CLAUDE.md 或直接放在 rules 文件中不设 paths 条件。

Rules 文件承担两个职责：**编码规范**（应该怎么写）和**编码红线**（绝对不能怎么写）。红线是代码质量防御的关键层（详见文档 04 Section 10），规范可能被遗忘但 Hook 会兜底，红线则是 CLAUDE.md + Hook 双重保障。

### 前端规则示例 `.claude/rules/frontend.md`

```markdown
---
paths:
  - "apps/web/src/**/*.tsx"
  - "apps/web/src/**/*.ts"
---

## 前端红线（修 Bug 时同样适用）

- MUST NOT 使用 style={{}}，MUST 使用 Tailwind / CSS Modules
- MUST NOT 使用 any / @ts-ignore / @ts-expect-error
- MUST NOT 在组件内定义一次性工具函数，MUST 提取到 hooks/ 或 utils/
- MUST NOT 直接操作 DOM（querySelector 等），MUST 使用 React ref
- MUST NOT 在组件内写数据请求逻辑，MUST 通过 API layer / hooks 封装

## 前端测试规则

- MUST 为关键用户交互写集成测试（渲染完整页面，模拟用户操作，验证页面结果）
- MUST 用 React Testing Library 测用户行为，MUST NOT 测实现细节（state 值、hook 内部）
- MUST 用 MSW mock API 请求，MUST NOT 直接 mock fetch/axios
- MUST 用 userEvent（非 fireEvent）模拟用户操作
- 集成测试覆盖：分页、搜索、筛选、排序、表单提交、CRUD、状态切换、错误提示、空状态

## 前端规范

- MUST 使用函数式组件（禁止 class 组件）
- MUST 使用 Zustand 管理全局状态（禁止 Redux 或 React Context）
- MUST 将 API 调用封装在 `hooks/` 目录的自定义 Hook 中
- SHOULD 组件文件不超过 200 行，超过则拆分
- 命名：组件 PascalCase，文件名与组件名一致
- 样式：Tailwind CSS utility-first，避免自定义 CSS
```

### 后端规则示例 `.claude/rules/backend.md`（FastAPI）

```markdown
---
paths:
  - "apps/api/**/*.py"
---

## 后端红线（修 Bug 时同样适用）

- MUST NOT 在 router 中写业务逻辑，MUST 放 service 层
- MUST NOT 裸写 SQL，MUST 使用 SQLAlchemy ORM
- MUST NOT 在函数内 hardcode 配置值，MUST 使用 Settings / 环境变量
- MUST NOT 用 dict 传递结构化数据，MUST 使用 Pydantic model
- MUST NOT 吞异常（bare except / except Exception: pass）

## 后端测试规则

- MUST 为每个 API 端点写集成测试（用 TestClient 走完整 路由→依赖注入→service→DB→响应 链路）
- MUST NOT 只测 service 函数就当"API 测过了"
- MUST 测试错误场景（参数校验失败、权限不足、资源不存在）的响应格式和状态码

## 后端规范

- MUST 使用 async/await（禁止同步阻塞函数）
- MUST 在 router 层用 Pydantic schema 做参数校验
- MUST 使用 FastAPI Depends 做依赖注入
- SHOULD 每个 API 模块有对应的 pytest 测试文件
- 错误响应统一格式：`{"error": {"code": str, "message": str}}`
```

### 后端规则示例 `.claude/rules/backend-spring.md`（Spring Boot）

```markdown
---
paths:
  - "src/**/*.java"
---

## 后端红线（修 Bug 时同样适用）

- MUST NOT 在 Controller 中写业务逻辑，MUST 放 Service 层
- MUST NOT 裸写 SQL，MUST 使用 JPA / MyBatis 映射
- MUST NOT 在代码中 hardcode 配置值，MUST 使用 @Value / application.yml
- MUST NOT 用 Map 传递结构化数据，MUST 使用 DTO/VO
- MUST NOT 吞异常（catch + 空处理 / 仅打日志不抛出）

## 后端测试规则

- MUST 为每个 API 端点写集成测试（用 MockMvc/WebTestClient 走完整请求链路）
- MUST NOT 只测 Service 方法就当"API 测过了"
- MUST 测试错误场景的响应格式和 HTTP 状态码
```

### 红线编写原则

| 原则 | 说明 |
|------|------|
| **少** | 每个技术栈 5-8 条，不要写成规范手册 |
| **硬** | 用 MUST NOT，不是 SHOULD NOT |
| **具体** | `MUST NOT 使用 style={{}}`，不是"保持代码整洁" |
| **含修 Bug 场景** | 明确写"修 Bug 时同样适用"，否则 Claude 在修 Bug 时会自动"豁免" |
| **配合 Hook** | 最关键的红线在 Stop Hook 中用脚本检查（详见文档 02 Section 5.4），双重保障 |

---

## 7. 初始化流程

新项目初始化通过 `prompt-新项目初始化.md` 执行——在目标项目中启动 Claude Code，@ 引用该 prompt 文件，Claude 会自主完成全部配置。

**初始化会产出的文件**：

| 产出 | 说明 |
|------|------|
| `CLAUDE.md` | 项目规范（精简到 150 行以内） |
| `.claude/settings.json` | 权限 + Hooks 配置 |
| `.claude/hooks/*.sh` | Hook 脚本文件 |
| `.claude/skills/*/SKILL.md` | 自定义 Skills |
| `.claude/rules/*.md` | 路径感知规则 |
| `CLAUDE.local.md` | 个人本地配置（加入 .gitignore） |
| `docs/roadmap/` | 项目路线图（探索后生成） |
| 子目录 `CLAUDE.md` | Monorepo 子模块规范（按需） |

详细步骤见 `prompt-新项目初始化.md`。已有 v3.x 配置的项目同步最新 guide 见 `prompt-guide版本升级.md`。

---

## 8. 维护指南

### 每月检查清单

- [ ] `CLAUDE.md` 技术栈版本是否仍然准确？
- [ ] 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- [ ] 行数是否接近 200 行？需要拆分到子目录？
- [ ] Auto Memory 是否有需要"固化"到 `CLAUDE.md` 的内容？
- [ ] `@` 引用的文件是否仍然有效？

### 信号与响应

| 信号 | 响应 |
|------|------|
| Claude 反复忽略某条规定 | 用更强的 `MUST NOT` 语言重写；检查是否超过 200 行导致忽略 |
| Claude 反复问同样的背景问题 | 将答案加入 `CLAUDE.md` |
| 同一个 Bug 出现两次 | 在 `CLAUDE.md` 加入防范约束 |
| Claude 上下文加载很慢 | 检查 `@` 引用的文件大小；检查是否有不必要的大文件引用 |

---

**版本**: v3.17
**更新日期**: 2026-03（v3.17）
