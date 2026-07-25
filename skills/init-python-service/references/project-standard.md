# Python 服务项目初始化标准 Prompt

本文档是一份可直接交给编码 Agent 使用的项目初始化 Prompt。

它适用于独立部署、一个项目使用一个 Python 虚拟环境的 Web 服务。标准基于当前
`melina-lab` 项目的项目命名、Python 打包、配置引导、数据库迁移、日志和服务器启动
方式整理。

使用前，替换“项目变量”中的占位符；未明确要求的业务功能不要提前实现。

## 目录

- [可复制 Prompt](#可复制-prompt)
  - [项目变量](#一项目变量)
  - [目录结构](#二目录结构)
  - [Python 打包](#三python-打包)
  - [FastAPI 入口](#四fastapi-入口)
  - [统一响应和异常](#五统一响应和异常)
  - [配置管理](#六配置管理)
  - [数据库与 Alembic](#七数据库与-alembic)
  - [日志规范](#八日志规范)
  - [服务器启动脚本](#九服务器启动脚本)
  - [本地开发](#十本地开发)
  - [测试与验证](#十一测试与验证)
  - [Git 忽略规则](#十二git-忽略规则)
  - [README](#十三readme)
  - [实施边界](#十四实施边界)
  - [交付要求](#十五交付要求)
- [使用示例](#使用示例)

---

## 可复制 Prompt

请初始化一个可部署的 Python Web 服务项目，并严格遵循以下规范。

### 一、项目变量

- 项目名称：`<PROJECT_NAME>`
  - 必须使用 kebab-case，例如 `order-lab`
- Python 包名：`<PACKAGE_NAME>`
  - 默认将项目名称中的 `-` 替换为 `_`
  - 例如 `order-lab` 对应 `order_lab`
- 项目描述：`<PROJECT_DESCRIPTION>`
- Python 版本：`<PYTHON_VERSION>`
  - 默认使用 `3.12`
- 服务器 Python 路径：`<PYTHON_BIN>`
  - 例如 `/opt/python/3.12.13/bin/python3`
- HTTP 端口：`<SERVER_PORT>`
  - 默认使用 `8000`
- 数据库：`<DATABASE>`
  - 默认使用 MySQL 8
- Git Commit 环境变量：`<PROJECT_COMMIT_ENV>`
  - 将项目名称转换为大写下划线形式并追加 `_COMMIT`
  - 例如 `order-lab` 对应 `ORDER_LAB_COMMIT`

项目中的四种名称必须明确区分：

```text
仓库目录：      <PROJECT_NAME>
发行包名：      <PROJECT_NAME>
Python 代码包： <PACKAGE_NAME>
命令行入口：    <PROJECT_NAME>
FastAPI 实例：  app
```

以 `melina-lab` 为例：

```text
仓库目录：      melina-lab
发行包名：      melina-lab
Python 代码包： melina_lab
命令行入口：    melina-lab
FastAPI 实例：  app
```

不得因为 FastAPI 实例名是 `app`，就把 Python 包目录固定命名为 `app/`。

### 二、目录结构

使用以下基础结构：

```text
<PROJECT_NAME>/
├── AGENTS.md
├── CLAUDE.md
├── python_server_convention.md
├── <PACKAGE_NAME>/
│   ├── __init__.py
│   ├── main.py
│   ├── bootstrap.py
│   ├── config.py
│   ├── database.py
│   ├── logging.py
│   ├── response.py
│   └── <business_module>/
│       ├── __init__.py
│       ├── models.py
│       ├── schemas.py
│       ├── repository.py
│       ├── service.py
│       └── router.py
├── migrations/
│   ├── versions/
│   ├── env.py
│   └── script.py.mako
├── tests/
│   └── __init__.py
├── docs/
│   └── plan/
├── scripts/
├── logs/
├── run/
├── .gitignore
├── .python-version
├── alembic.ini
├── application-example.yaml
├── pyproject.toml
├── README.md
└── start.sh
```

目录约定：

1. `<PACKAGE_NAME>` 是唯一的顶层 Python 业务包。
2. 业务代码按领域放入 `<PACKAGE_NAME>/<business_module>/`。
3. Router、Service、Repository、Schema 和数据库模型按职责分层。
4. 不创建含义模糊的 `utils.py`、`common.py` 或 `helpers.py`；共享代码按实际职责命名。
5. `scripts/` 只放独立运维、验证或数据处理脚本，不放应用运行时业务逻辑。
6. `logs/`、`run/`、`.venv/` 和运行时下载的配置文件不得提交 Git。
7. 如果项目不需要数据库，可以省略 `database.py`、Alembic 和 migration 目录。
8. 如果项目不需要某个基础模块，应直接省略，不要创建空占位实现。
9. `python_server_convention.md` 保存项目初始化后的持续编码规范。
10. 根目录 `AGENTS.md` 必须要求编码 Agent 在修改 Python 服务前读取并遵循
    `python_server_convention.md`。
11. 如果目标项目已经存在 `AGENTS.md`，保留原有规则，只补充缺失的规范引用。
12. 根目录 `CLAUDE.md` 必须通过 `@python_server_convention.md` 导入同一份规范。
13. 如果目标项目已经存在 `CLAUDE.md`，保留原有规则，只补充缺失的导入。
14. 重复初始化时不得重复追加章节或引用。
15. Skill 自身的 `agents/openai.yaml` 只属于 Skill，不得复制到目标项目。

### 三、Python 打包

使用 PEP 621、Hatchling 和 wheel 安装方式。

`pyproject.toml` 至少包含：

```toml
[project]
name = "<PROJECT_NAME>"
version = "0.1.0"
description = "<PROJECT_DESCRIPTION>"
requires-python = ">=<PYTHON_VERSION>"
dependencies = [
    "fastapi>=0.115,<1",
    "pydantic>=2,<3",
    "pyyaml>=6,<7",
    "uvicorn[standard]>=0.34,<1",
]

[project.scripts]
<PROJECT_NAME> = "<PACKAGE_NAME>.main:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["<PACKAGE_NAME>"]
```

打包要求：

1. `[project].name` 使用 kebab-case 项目名。
2. Python 包目录和 import 使用合法的 snake_case 包名。
3. Console Script 名称与项目名称保持一致。
4. 服务器部署不使用 editable install。
5. 服务器使用以下命令安装当前项目：

   ```bash
   .venv/bin/python -m pip install --upgrade .
   ```

6. `pip install` 项目根目录时，允许 pip 根据 `pyproject.toml` 构建临时 wheel 后安装。
7. 安装完成后必须生成 `.venv/bin/<PROJECT_NAME>`。
8. 服务通过 Console Script 启动，不直接执行源码路径。
9. 项目源码修改后必须重新安装，不能依赖当前工作目录碰巧能够 import 源码。
10. 不使用 `PYTHONPATH` 掩盖错误的打包或导入配置。
11. 生产环境中使用独立虚拟环境，避免项目专属包与其他项目发生冲突。
12. 依赖应设置合理的主版本上限，避免不可控的大版本升级。

如果使用 SQLAlchemy 和 MySQL，至少增加：

```toml
"alembic>=1.14,<2",
"pymysql[rsa]>=1.1,<2",
"sqlalchemy>=2.0,<3",
```

### 四、FastAPI 入口

在 `<PACKAGE_NAME>/main.py` 中：

1. 创建 FastAPI 实例：

   ```python
   app = FastAPI(...)
   ```

2. 使用 lifespan 管理应用启动和关闭资源。
3. 在启动阶段完成配置引导和必要资源初始化。
4. 在关闭阶段释放数据库 Engine、调度器和长生命周期 HTTP Client。
5. 提供同步 `main()` 方法，通过 Uvicorn 启动：

   ```python
   uvicorn.run(
       "<PACKAGE_NAME>.main:app",
       host=settings.server.host,
       port=settings.server.port,
       log_config=None,
   )
   ```

6. Uvicorn 的 host 和 port 必须来自配置，不能散落硬编码。
7. 在入口层统一注册异常处理器和业务 Router。
8. Python 内部 Router 不包含 Nginx、Ingress 或 API Gateway 的外层路径前缀。
9. `if __name__ == "__main__": main()` 可以保留用于直接调试，但生产启动入口是
   `.venv/bin/<PROJECT_NAME>`。

提供根信息接口：

```http
GET /
```

响应至少包含：

```json
{
  "success": true,
  "code": 0,
  "message": "OK",
  "data": {
    "app": "<PROJECT_NAME>",
    "ts": "2026-01-01T00:00:00Z",
    "<PROJECT_COMMIT_ENV>": "abcdef0"
  }
}
```

要求：

1. 时间统一使用 UTC。
2. 时间精确到秒，并以 `Z` 结尾。
3. 未注入 Git Commit 环境变量时返回 `unknown`。
4. JSON 字段名保持稳定，不因 Python 内部变量命名方式发生变化。

### 五、统一响应和异常

在 `<PACKAGE_NAME>/response.py` 中定义泛型响应模型，所有业务接口使用统一结构：

```json
{
  "success": true,
  "code": 0,
  "message": "OK",
  "data": {}
}
```

要求：

1. 正常响应和错误响应使用稳定的业务码及结构。
2. 业务异常使用明确的异常类型，不直接抛出含糊的 `Exception`。
3. 在 FastAPI 层集中注册异常处理器。
4. 日志记录完整异常上下文。
5. HTTP 响应不得泄露堆栈、数据库连接、密钥或内部实现。
6. Router 负责 HTTP 协议适配，不承载复杂业务逻辑。

### 六、配置管理

使用 Pydantic 强类型模型管理配置，不允许业务代码直接读取散乱的环境变量。

配置分为两层：

1. 引导配置
   - 可以从环境变量读取。
   - 只负责确定真实应用配置的位置、环境或远程下载方式。
2. 应用配置
   - 从 YAML 加载。
   - 包含 server、database、HTTP Client 和具体业务配置。

提供 `application-example.yaml`，但不得包含真实密钥。

示例基础结构：

```yaml
server:
  host: 0.0.0.0
  port: 8000

database:
  url: mysql+pymysql://user:change-me@127.0.0.1:3306/database?charset=utf8mb4

http:
  timeout-seconds: 30
```

如果项目使用远程配置中心：

1. 启动时先下载配置，再创建应用 Settings。
2. Alembic 执行 migration 前也必须完成相同的配置引导。
3. 环境变量只保存配置中心的引导信息，不重复保存完整业务配置。
4. 运行时下载的 `application-*.yaml` 加入 `.gitignore`。
5. `application-example.yaml` 只是结构示例，不是生产配置。
6. 缺少必需配置、下载失败或 YAML 格式错误时立即终止启动。
7. 不使用隐式默认值掩盖生产配置错误。
8. 禁止把真实 Token、密码或 API Key 写入仓库。

### 七、数据库与 Alembic

如果项目需要数据库：

1. 使用 SQLAlchemy 2.x。
2. 在 `<PACKAGE_NAME>/database.py` 统一管理：
   - Engine；
   - Session factory；
   - FastAPI `get_db`；
   - 事务上下文；
   - Engine 释放。
3. Router 不直接编写数据库查询。
4. Repository 负责数据访问。
5. Service 负责事务边界和业务流程编排。
6. 数据库结构变更必须通过 Alembic migration 完成。
7. `migrations/env.py` 复用应用配置加载流程获取数据库 URL。
8. migration 必须显式导入需要注册到 Metadata 的模型。
9. 禁止在正式应用启动时使用 `create_all()` 代替 migration。
10. `start.sh` 必须在启动服务前执行：

    ```bash
    .venv/bin/alembic -c alembic.ini upgrade head
    ```

11. migration 失败时不得继续启动旧结构上的新应用。

### 八、日志规范

日志固定写入项目根目录的 `logs/`：

- `logs/app.log`：应用、业务、调度和第三方调用日志；
- `logs/uvicorn.log`：Uvicorn 服务及访问日志；
- `logs/alembic.log`：Alembic migration 和 SQLAlchemy 警告。

日志要求：

1. 使用 Python `logging`，不使用 `print()` 记录运行日志。
2. 使用 `RotatingFileHandler`。
3. 单个日志文件默认最大 20 MiB。
4. 默认保留 10 个历史文件。
5. 日志编码使用 UTF-8。
6. 日志格式至少包含时间、级别、Logger 名称和消息。
7. Uvicorn 日志不得重复传播到 `app.log`。
8. Alembic 日志和应用日志使用独立配置入口。
9. Shell 的 `nohup` 输出写入 `/dev/null`，避免 Shell 与 Python 日志处理器同时写同一文件。
10. 不记录 Token、密码、API Key、Cookie 或完整敏感请求。
11. 日志目录不存在时由程序安全创建。

### 九、服务器启动脚本

提供可重复执行的 `start.sh`。

脚本必须：

1. 使用：

   ```bash
   set -Eeuo pipefail
   umask 027
   ```

2. 根据脚本自身路径计算绝对项目根目录。
3. 定义以下路径：
   - `PROJECT_ROOT`
   - `PYTHON_BIN`
   - `VENV_DIR`
   - `RUN_DIR`
   - `LOG_DIR`
   - `PID_FILE`
4. 创建 `run/` 和 `logs/`。
5. 检查指定的服务器 Python 是否存在且可执行。
6. 使用指定 Python 创建或复用 `.venv`。
7. 检查虚拟环境的 Python 主次版本是否符合项目要求。
8. 根据 `run/<PROJECT_NAME>.pid` 查找旧进程。
9. PID 文件内容不是正整数时，删除无效 PID 文件。
10. PID 已不存在时，删除过期 PID 文件。
11. 停止旧进程前，通过命令行确认 PID 确实属于：

    ```text
    <PROJECT_ROOT>/.venv/bin/<PROJECT_NAME>
    ```

12. 先发送正常终止信号并等待，超时后再强制终止。
13. 使用 wheel 流程安装当前项目：

    ```bash
    "${VENV_DIR}/bin/python" -m pip install --upgrade "${PROJECT_ROOT}"
    ```

14. 如果项目使用数据库，在启动前执行全部待应用 migration。
15. 使用以下命令读取当前 Git 短提交号：

    ```bash
    git rev-parse --short HEAD
    ```

16. 无法获取提交号时使用 `unknown`。
17. 将 Git Commit 通过 `<PROJECT_COMMIT_ENV>` 注入新进程。
18. 使用 Console Script 启动：

    ```bash
    nohup "${VENV_DIR}/bin/<PROJECT_NAME>" >/dev/null 2>&1 &
    ```

19. 将新 PID 写入 PID 文件。
20. 启动后等待短暂时间并检查进程是否仍然存活。
21. 启动失败时删除 PID 文件，并提示检查 `logs/`。
22. 脚本重复执行必须能够安全完成停止、安装、迁移和重启。
23. 不默认依赖 Docker，除非项目明确要求容器部署。

正常启动后，`ps -ef` 应能看到类似：

```text
/root/apps/<PROJECT_NAME>/.venv/bin/python \
/root/apps/<PROJECT_NAME>/.venv/bin/<PROJECT_NAME>
```

Python 包名 `<PACKAGE_NAME>` 不需要出现在进程命令行中。它由生成的 Console Script
在内部导入。

### 十、本地开发

README 中提供本地启动步骤：

```bash
python<PYTHON_VERSION> -m venv .venv
source .venv/bin/activate
pip install -e .
alembic upgrade head
<PROJECT_NAME>
```

需要明确说明：

1. 本地开发可以使用 editable install，源码修改立即生效。
2. 服务器使用普通 wheel 安装，源码修改后必须重新执行 `pip install --upgrade`。
3. 虚拟环境负责依赖隔离，wheel 负责项目的构建和安装，两者职责不同且可以同时使用。
4. 本地和服务器都通过同一个 Console Script 启动。

### 十一、测试与验证

至少验证：

1. 项目能够成功构建 wheel。
2. wheel 中包含 `<PACKAGE_NAME>/`，而不是错误的项目根目录或其他包名。
3. wheel 的 metadata 中发行包名是 `<PROJECT_NAME>`。
4. 安装后存在 `.venv/bin/<PROJECT_NAME>`。
5. Console Script 能正确导入 `<PACKAGE_NAME>.main:main`。
6. `main()` 中的 Uvicorn 入口是 `<PACKAGE_NAME>.main:app`。
7. 根信息接口响应结构正确。
8. UTC 时间以 `Z` 结尾。
9. 未注入 Git Commit 时返回 `unknown`。
10. 必需配置缺失时启动明确失败。
11. Alembic 能通过应用配置读取数据库连接。
12. 日志分别写入对应文件。
13. Uvicorn 日志不会重复出现在应用日志中。
14. Router 不包含反向代理外层前缀。
15. `start.sh` 通过 Bash 语法检查。
16. 执行项目约定的测试、格式检查和静态检查。
17. 执行 `git diff --check`。

测试不得依赖真实生产数据库、真实远程配置中心或真实第三方 API。使用临时目录、Mock
或测试替身，并确保测试不会把密钥写入日志和断言失败输出。

### 十二、Git 忽略规则

`.gitignore` 至少包含：

```gitignore
.venv/
__pycache__/
*.py[cod]
.pytest_cache/
.ruff_cache/
logs/
run/
dist/
build/
*.egg-info/
application-*.yaml
.env
```

如果使用 `application-example.yaml`，必须显式保留：

```gitignore
!application-example.yaml
```

### 十三、README

README 至少说明：

1. 项目用途。
2. Python 和数据库版本。
3. 项目名、Python 包名和 Console Script 的对应关系。
4. 本地虚拟环境创建、安装和启动方式。
5. 服务器启动方式。
6. editable install 与普通 wheel 安装的区别。
7. 配置来源和 `application-example.yaml` 的用途。
8. 数据库 migration 执行方式。
9. 日志文件位置和日志滚动规则。
10. 根信息接口。
11. 关键目录结构。
12. 源码修改后为什么需要重新安装项目。
13. `python_server_convention.md` 是后续 Python 服务代码变更的持续规范。

### 十四、实施边界

1. 先创建最小可运行骨架，不提前实现未要求的业务。
2. 不添加 Celery、Redis、消息队列或容器编排，除非需求明确要求。
3. 不把反向代理路径写入 FastAPI Router。
4. 不把真实密钥写入源码、示例配置、测试或日志。
5. 不使用 `.env` 同时维护一份与 YAML 重复的完整应用配置。
6. 不使用 `PYTHONPATH` 修复打包问题。
7. 不依赖当前工作目录碰巧能够导入源码。
8. 不混淆发行包名、Python 包名、Console Script 和 FastAPI 实例名。
9. 所有启动入口、import 路径、测试 patch 路径和 wheel 内容必须一致。
10. 如果创建了实施计划，必须先将最终计划写入 `docs/plan/`，再修改业务代码。
11. 初始化时将 Skill 提供的规范模板写入根目录 `python_server_convention.md`，替换所有
    项目变量。
12. 创建或安全更新 `AGENTS.md`，让后续 Agent 自动读取该规范；不得覆盖已有规则。
13. 创建或安全更新 `CLAUDE.md`，通过 `@python_server_convention.md` 导入同一份规范；
    不得覆盖已有规则。

### 十五、交付要求

完成后输出：

1. 创建或修改的文件列表。
2. 最终目录结构。
3. 项目名称转换结果：

   ```text
   仓库目录：      <PROJECT_NAME>
   发行包名：      <PROJECT_NAME>
   Python 代码包： <PACKAGE_NAME>
   命令行入口：    <PROJECT_NAME>
   FastAPI 实例：  app
   ```

4. 本地安装和启动命令。
5. 服务器安装和启动命令。
6. 实际执行的验证及其结果。
7. 尚未实现的可选能力。
8. 仍需用户提供的配置或外部资源。

不要只描述方案；在权限和环境允许的情况下，直接创建项目文件并完成验证。

---

## 使用示例

初始化 `order-lab` 时，先确定：

```text
PROJECT_NAME=order-lab
PACKAGE_NAME=order_lab
PROJECT_COMMIT_ENV=ORDER_LAB_COMMIT
```

生成的关键结构和配置应为：

```text
order-lab/
└── order_lab/
    └── main.py
```

```toml
[project]
name = "order-lab"

[project.scripts]
order-lab = "order_lab.main:main"

[tool.hatch.build.targets.wheel]
packages = ["order_lab"]
```

```python
uvicorn.run("order_lab.main:app", ...)
```

服务器启动命令最终表现为：

```text
/root/apps/order-lab/.venv/bin/python /root/apps/order-lab/.venv/bin/order-lab
```

这套命名关系与 Python 包内部目录是否出现在 `ps` 命令行中无关。
