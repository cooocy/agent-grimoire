---
name: init-python-service
description: Initialize or standardize independently deployed Python FastAPI services with project-specific package names, PEP 621 and Hatchling packaging, virtual environments, wheel installation, console scripts, typed YAML configuration, optional SQLAlchemy and Alembic, rotating logs, and an idempotent server startup script. Use when creating, scaffolding, initializing, or restructuring a Python or FastAPI backend/service, or when applying the melina-lab project conventions to another Python service.
---

# Init Python Service

Create a minimal, deployable Python service whose repository name, distribution name, import
package, Console Script, and FastAPI application are explicit and internally consistent.

## Workflow

### 1. Inspect the target

1. Read repository instructions such as `AGENTS.md` and `CLAUDE.md` before changing files.
2. Inspect existing packaging, source layout, startup scripts, configuration, migrations, tests,
   and uncommitted changes.
3. Distinguish a new project from an existing project. Preserve compatible conventions and user
   changes when standardizing existing code.
4. Follow repository plan gates. If a finalized plan is required, persist it before the first
   implementation change.

### 2. Resolve names and scope

Determine these values:

```text
PROJECT_NAME=<kebab-case distribution and Console Script name>
PACKAGE_NAME=<snake_case Python import package>
PROJECT_COMMIT_ENV=<UPPER_SNAKE_CASE project name plus _COMMIT>
PYTHON_VERSION=<required major.minor version>
PYTHON_BIN=<server interpreter path>
```

Derive `PACKAGE_NAME` by replacing `-` with `_` unless the user specifies another valid Python
identifier. Derive `PROJECT_COMMIT_ENV` by replacing `-` with `_`, uppercasing the result, and
appending `_COMMIT`.

Keep this invariant:

```text
Repository directory: PROJECT_NAME
Distribution name:    PROJECT_NAME
Python import package: PACKAGE_NAME
Console Script:       PROJECT_NAME
FastAPI instance:     app
```

Do not infer that the Python package should be named `app` merely because the FastAPI instance is
named `app`.

Resolve optional capabilities from the request and repository context:

- Include SQLAlchemy and Alembic only when the service needs a relational database.
- Include remote configuration bootstrap only when the deployment model requires it.
- Include schedulers, external clients, and business modules only when requested.
- Default to the smallest runnable service when requirements are incomplete.
- Ask only when an unknown choice would materially change the architecture or external behavior.

### 3. Load the standard

Read [references/project-standard.md](references/project-standard.md) completely before creating
or restructuring a project. Apply its required rules and only the optional sections relevant to
the resolved scope.

Use [assets/python_server_convention.md](assets/python_server_convention.md) as the source template
for the target repository's ongoing coding convention. Replace all project placeholders before
writing it to the target.

Treat the reference as the detailed source of truth for:

- directory layout and naming;
- PEP 621, Hatchling, wheel, and Console Script configuration;
- FastAPI entrypoint and application information endpoint;
- typed configuration and bootstrap ordering;
- SQLAlchemy and Alembic boundaries;
- rotating log files;
- idempotent non-Docker server startup;
- local development, tests, Git ignores, and README content.

### 4. Implement

1. Create the minimum files needed for the selected scope.
2. Use `PACKAGE_NAME` consistently in directories, imports, Uvicorn targets, tests, patches,
   Alembic imports, and wheel targets.
3. Use `PROJECT_NAME` consistently for the distribution and Console Script.
4. Install production code through a wheel-backed normal `pip install`, not editable mode.
5. Keep local editable installation as a documented development convenience only.
6. Keep reverse-proxy prefixes outside FastAPI routers.
7. Keep secrets out of source, examples, tests, logs, and generated reports.
8. Do not introduce unrelated infrastructure or speculative business functionality.
9. Materialize `assets/python_server_convention.md` as `python_server_convention.md` in the target
   repository root, replacing `PROJECT_NAME`, `PACKAGE_NAME`, `PROJECT_COMMIT_ENV`,
   `PYTHON_VERSION`, and other resolved placeholders.
10. Ensure both target root instruction files load the same convention:
    - In `AGENTS.md`, tell coding agents to read and follow
      `[python_server_convention.md](python_server_convention.md)` before changing Python service
      code.
    - In `CLAUDE.md`, add `@python_server_convention.md` under a short Python server convention
      section so Claude Code imports the file.
    - Create a minimal instruction file when either file does not exist.
    - When either file exists, preserve all existing instructions and add only the missing
      reference.
    - Do not add duplicate sections or references on repeated initialization.
    - Do not copy the Skill's `agents/openai.yaml` into the target repository.

For an existing project, make narrow edits and preserve behavior unless the user explicitly asks
for a migration or redesign.

### 5. Validate

Choose checks proportionate to the project and repository instructions. For a complete new service,
verify at least:

1. packaging metadata and Python version alignment;
2. wheel construction and wheel contents;
3. installation into an isolated virtual environment;
4. generated `.venv/bin/PROJECT_NAME` Console Script;
5. import of `PACKAGE_NAME.main:main`;
6. Uvicorn target `PACKAGE_NAME.main:app`;
7. root information response and `unknown` commit fallback;
8. configuration failure behavior;
9. Alembic configuration and migration loading when database support is present;
10. log routing and rotation;
11. Bash syntax for `start.sh`;
12. repository tests and configured static checks;
13. target `python_server_convention.md` contains no unresolved placeholders;
14. target `AGENTS.md` references `python_server_convention.md`;
15. target `CLAUDE.md` imports `python_server_convention.md`;
16. `git diff --check`.

Do not run checks prohibited by repository instructions. Report skipped checks and why.

### 6. Hand off

Report:

1. files created or modified;
2. final directory structure;
3. resolved name mapping;
4. local and server startup commands;
5. validations run and their results;
6. optional features intentionally omitted;
7. configuration or external resources still required;
8. convention, `AGENTS.md`, and `CLAUDE.md` files created or updated.

Do not claim completion if packaging, imports, and startup targets disagree.

## Reference

- [Project initialization standard](references/project-standard.md): complete requirements,
  examples, and acceptance checklist. Read it for every project initialization or standardization
  task.
- [Python server convention template](assets/python_server_convention.md): durable coding rules to
  materialize in the target repository with resolved project names.
