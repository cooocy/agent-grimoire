# Agent Grimoire

我的 Agent 魔法书：用于沉淀技能、提示词、工作流与自动化实践。

## 项目结构

```
agent-grimoire/
├── skills/                    # skills 目录
├── link_skills.fish           # skills 链接脚本
└── README.md
```

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
