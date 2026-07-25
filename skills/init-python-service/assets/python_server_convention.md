# Python Server Convention

This document defines the durable coding and operational conventions for `<PROJECT_NAME>`.
Read it before changing Python service code, packaging, configuration, migrations, tests, logging,
or deployment scripts.

## 1. Project identity

Keep these names distinct and consistent:

```text
Repository directory: <PROJECT_NAME>
Distribution name:    <PROJECT_NAME>
Python import package: <PACKAGE_NAME>
Console Script:       <PROJECT_NAME>
FastAPI instance:     app
Commit environment:   <PROJECT_COMMIT_ENV>
Python version:       <PYTHON_VERSION>
```

Rules:

1. Use `<PROJECT_NAME>` for `[project].name` and the installed Console Script.
2. Use `<PACKAGE_NAME>` for the source directory, imports, Uvicorn target, tests, patch paths,
   Alembic model imports, and wheel contents.
3. Use `<PACKAGE_NAME>.main:main` as the Console Script target.
4. Use `<PACKAGE_NAME>.main:app` as the Uvicorn application target.
5. Do not rename the Python package to `app` merely because the FastAPI instance is named `app`.
6. Do not use `PYTHONPATH` to compensate for incorrect packaging.

## 2. Source layout

Use a single top-level application package:

```text
<PACKAGE_NAME>/
├── main.py
├── bootstrap.py
├── config.py
├── database.py
├── logging.py
├── response.py
└── <business_module>/
    ├── models.py
    ├── schemas.py
    ├── repository.py
    ├── service.py
    └── router.py
```

Only create modules required by the service.

Responsibilities:

- `main.py`: application assembly, lifespan, Router registration, and Console Script entrypoint.
- `bootstrap.py`: startup configuration and resource initialization ordering.
- `config.py`: typed application settings and configuration parsing.
- `database.py`: Engine, Session factory, transaction helpers, dependencies, and disposal.
- `logging.py`: application, Uvicorn, and Alembic logging configuration.
- `response.py`: shared response envelope and exception handlers.
- `router.py`: HTTP protocol adaptation and request/response mapping.
- `service.py`: business workflows and transaction boundaries.
- `repository.py`: persistence queries and database mutations.
- `schemas.py`: API and service boundary data models.
- `models.py`: SQLAlchemy persistence models.

Do not create generic `utils.py`, `common.py`, or `helpers.py` modules. Name shared code after its
actual responsibility.

## 3. Dependency and packaging rules

1. Declare metadata and dependencies in `pyproject.toml` using PEP 621.
2. Build the project with Hatchling.
3. Package only `<PACKAGE_NAME>`.
4. Set a lower bound and a major-version upper bound for runtime dependencies.
5. Keep `.python-version` and `[project].requires-python` aligned with `<PYTHON_VERSION>`.
6. Use editable installation only for local development:

   ```bash
   pip install -e .
   ```

7. Use normal wheel-backed installation for server deployment:

   ```bash
   .venv/bin/python -m pip install --upgrade .
   ```

8. After changing deployed source, reinstall the project before restarting it.
9. Start the service through `.venv/bin/<PROJECT_NAME>`, not through a source file path.
10. Do not rely on the current working directory making source imports accidentally available.

## 4. FastAPI boundaries

1. Keep application assembly in `<PACKAGE_NAME>/main.py`.
2. Use FastAPI lifespan for long-lived startup and shutdown resources.
3. Release database Engines, schedulers, and long-lived HTTP clients during shutdown.
4. Read host and port from typed configuration.
5. Register shared exception handlers centrally.
6. Register business Routers centrally.
7. Keep Nginx, Ingress, and API Gateway prefixes outside Python Router paths.
8. Keep complex business logic out of Router functions.
9. Preserve the shared response envelope:

   ```json
   {
     "success": true,
     "code": 0,
     "message": "OK",
     "data": {}
   }
   ```

10. The root information endpoint must return the project name, a UTC timestamp ending in `Z`,
    and `<PROJECT_COMMIT_ENV>`. Use `unknown` when the commit was not injected.
11. Do not expose stack traces, connection strings, secrets, or internal implementation details in
    HTTP responses.

## 5. Configuration

1. Represent application configuration with typed Pydantic models.
2. Do not read scattered environment variables from business modules.
3. Limit environment variables to bootstrap information and values that must be injected by the
   process environment.
4. Load normal application settings from YAML.
5. Keep `application-example.yaml` synchronized with the supported configuration structure.
6. Never place real credentials in example configuration.
7. Fail startup clearly when required configuration is missing, cannot be downloaded, or is
   malformed.
8. Do not hide production configuration errors behind implicit defaults.
9. If remote configuration is enabled, bootstrap it before both application settings creation and
   Alembic settings creation.
10. Ignore downloaded `application-*.yaml` files while retaining `application-example.yaml`.

## 6. Database and migrations

Apply this section when the service uses a relational database.

1. Use SQLAlchemy 2.x patterns.
2. Keep Engine and Session construction in `<PACKAGE_NAME>/database.py`.
3. Let Repository objects perform persistence operations.
4. Let Service objects own business transaction boundaries.
5. Do not place raw persistence queries in Router functions.
6. Change database structure only through Alembic revisions.
7. Reuse the application configuration path in `migrations/env.py`.
8. Import all persistence models needed by Alembic Metadata.
9. Do not use `create_all()` as a production migration mechanism.
10. Run `alembic upgrade head` before starting a newly installed server build.
11. Stop deployment when a migration fails.
12. Keep migrations deterministic and review generated constraints, indexes, defaults, and
    downgrade behavior.

## 7. Logging and observability

Use these project-local files:

```text
logs/app.log
logs/uvicorn.log
logs/alembic.log
```

Rules:

1. Use Python `logging` instead of `print()` for runtime events.
2. Use UTF-8 `RotatingFileHandler` handlers.
3. Default each file to 20 MiB with 10 retained backups unless the project documents another
   value.
4. Include time, level, Logger name, and message in every entry.
5. Prevent Uvicorn logs from propagating into `app.log`.
6. Keep Alembic and SQLAlchemy migration logging separate from application logging.
7. Let Python own log files; redirect `nohup` stdout and stderr to `/dev/null`.
8. Include enough context to identify the failing operation and upstream dependency.
9. Never log passwords, API keys, authorization headers, cookies, full tokens, or unnecessary
   sensitive request bodies.

## 8. Server startup

Maintain an idempotent `start.sh` that:

1. uses `set -Eeuo pipefail` and `umask 027`;
2. resolves the project root from the script path;
3. creates or reuses `.venv` with `<PYTHON_BIN>`;
4. verifies the virtual environment uses `<PYTHON_VERSION>`;
5. validates PID file contents and process ownership before stopping a process;
6. attempts graceful shutdown before forced termination;
7. installs the current project with normal `pip install --upgrade`;
8. applies pending Alembic migrations when database support is present;
9. reads `git rev-parse --short HEAD`, falling back to `unknown`;
10. injects the value through `<PROJECT_COMMIT_ENV>`;
11. starts `.venv/bin/<PROJECT_NAME>` with `nohup`;
12. records and verifies the new PID;
13. reports the relevant log paths when startup fails.

Do not weaken PID ownership checks or allow migration failure to fall through to application
startup.

## 9. Testing

1. Add tests at the boundary where behavior changes.
2. Keep tests deterministic and isolated from production services.
3. Use temporary directories, mocks, or test doubles for remote configuration and third-party APIs.
4. Do not require real production credentials.
5. Test import and patch paths using `<PACKAGE_NAME>`.
6. When packaging changes, inspect wheel contents and verify the installed Console Script.
7. When routing changes, assert internal paths and ensure reverse-proxy prefixes are absent.
8. When configuration changes, update typed models, example YAML, bootstrap behavior, and tests
   together.
9. When database models change, add or update Alembic revisions and migration tests or offline SQL
   checks as appropriate.
10. When logging changes, verify routing and prevent duplicate records.
11. Run repository-prescribed tests and static checks.
12. Always run `git diff --check` before handoff.
13. If repository instructions prohibit or reserve a command for the user, do not run it; report
    the skipped validation.

## 10. Change discipline

1. Read `AGENTS.md`, `CLAUDE.md`, and repository-local instructions before editing.
2. Preserve unrelated working-tree changes.
3. Make the narrowest change that fully satisfies the request.
4. Do not introduce Celery, Redis, queues, containers, or orchestration unless explicitly required.
5. Do not change external route prefixes, response fields, configuration keys, or database
   semantics incidentally.
6. Keep documentation, example configuration, migrations, and tests synchronized with behavior.
7. If a finalized implementation plan is created, write it to `docs/plan/` before the first code
   change.
8. Use repository commit conventions when committing.
9. Do not commit or push unless requested or required by repository workflow.
10. Report changed files, validations, skipped checks, and remaining external requirements at
    handoff.

## 11. Completion checklist

Before declaring a change complete, confirm:

- project, package, Console Script, and Uvicorn names remain consistent;
- wheel contents contain `<PACKAGE_NAME>/`;
- configuration and examples agree;
- migrations match persistence model changes;
- logs remain separated and secret-safe;
- startup still installs, migrates, injects commit metadata, and launches the Console Script;
- tests cover the changed behavior;
- repository-required checks pass;
- `git diff --check` passes.
