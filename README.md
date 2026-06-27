# Agent Grimoire

我的 Agent 魔法书：用于沉淀技能、提示词、工作流与自动化实践。

## 项目结构

```
agent-grimoire/
├── prompts/                         # 通用提示词与项目约定
├── skills/                          # Agent Skills
├── link_skills.fish                 # Skills 链接脚本
└── README.md
```

## Prompts

`prompts/` 用于存放可复用的提示词和项目协作约定，可按项目需要引用或复制到对应的 Agent 配置中。

当前包含：

- `commit_conventions.md`：Git 提交类型与提交信息格式。
- `frontend_convention.md`：前端项目的通用开发和协作规范。
- `java_convention.md`：Java 项目的通用架构、编码和协作规范。

## Skills

`skills/` 用于存放可被 Agent 加载的技能。运行 `link_skills.fish` 后，每个技能会以软链接形式安装到支持的 Agent 目录中。

## 安装

1. 克隆项目：
   ```bash
   git clone <repository-url>
   ```

2. 运行链接脚本：
   ```bash
   fish link_skills.fish
   ```

   该脚本会将 `skills/` 目录下的所有技能链接到：
   - `~/.claude/skills/`
   - `~/.codex/skills/`
   - `~/.config/opencode/skills/`
