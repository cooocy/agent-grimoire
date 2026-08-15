---
name: pi-pkg-update
description: Check installed pi packages for available updates, extract and merge per-package changelogs from GitHub release notes, let the user pick which packages to update, then run `pi update <pkg>` for each picked package. Use when the user asks to check pi package / plugin updates, see what changed in newer versions, update plugins, or review a package outdated list.
---

# pi-pkg-update

Check installed pi npm packages for updates, surface a merged changelog, let the user choose, and update only the chosen packages one by one. Never run `pi update --all`, `pi update --extensions`, or `pi update --models`.

## Step 1 — Check what is outdated

Run the bundled checker. It reads `~/.pi/agent/settings.json` and `.pi/settings.json`, compares each `npm:<pkg>` against the npm registry, and prints an outdated table. It is pure bash + npm, no LLM.

```bash
bash ~/.pi/agent/skills/pi-pkg-update/scripts/check-outdated.sh
```

Parse the output:
- **Outdated (N):** these are candidates. Each line: `<pkg>  <installed> -> <latest>`.
- **Pinned:** version-locked in settings (`npm:pkg@x.y.z`); not auto-updatable. Tell the user to use `pi install npm:<pkg>@<new-ref>` manually if they want to move one.
- **All npm packages up to date.** → report this and stop. Nothing else to do.

If there is nothing outdated, stop after telling the user.

## Step 2 — Collect release notes per outdated package

For **each** outdated (non-pinned) package, run the fetcher, which reads that package's `repository` field, hits the GitHub Releases API, filters tags to the `installed < version <= latest` range, and applies monorepo subpackage filtering using `repository.directory`'s basename. It prints the matching release bodies, or `(无可用说明)` when no matching releases exist.

```bash
node ~/.pi/agent/skills/pi-pkg-update/scripts/fetch-release-notes.js <pkg> <installed> <latest>
```

Notes:
- The fetcher honors `GITHUB_TOKEN` if set (raises the 60 req/hr unauthenticated limit). One request per distinct repo; monorepo subpackages share a repo so they reuse the same fetch.
- If the fetcher prints `ERR ...` (network failure, rate limit), record that package as "fetch failed" and continue with the rest. Do not abort the whole run.
- A repo with more than 100 releases may have older in-range entries beyond the first page; this is an accepted v1 limitation. If a package shows `(无可用说明)` but you suspect pagination, say so plainly — do not fabricate notes.

## Step 3 — Merge and present the changelog

Combine the collected release notes into one concise changelog for the user. This is the LLM step:

- Group by package. Header per package: `### <pkg>  (<installed> -> <latest>)`.
- Inside each package, keep release entries newest-first with their version anchor (`## v25.2.1` etc.).
- Condense: drop pure meta/chore noise, collapse repeated lines, keep concrete behavior changes (Added / Changed / Fixed / Breaking). Preserve the meaning — do not invent changes not present in the source notes.
- For a package with `(无可用说明)` or a fetch failure, print a single line under its header: `_(无可用说明)_` or `_(release notes 获取失败，见上)_`.
- Keep it scannable. This is for a human deciding whether to update.

Show the merged changelog to the user before asking them to pick.

## Step 4 — Let the user choose

Use the `ask_user` tool with **multiSelect** to list every outdated non-pinned package. The user may select any subset, including none (they just wanted to see the changelog).

- Header: "要更新哪些包？"
- One option per outdated package. Label = package name; description = `<installed> -> <latest>` plus a one-line hint from the changelog if a notable change exists (e.g. breaking change), otherwise leave short.
- `allowSkip` true is fine — "Type something" / selecting none means skip all.

If the user selects nothing / skips, stop. Tell them nothing was updated.

## Step 5 — Update the chosen packages

For **each** selected package, run exactly:

```bash
pi update npm:<pkg>
```

Run them one at a time. After each, report success or failure based on the command output. Do not run `pi update --all`, `--extensions`, `--models`, or `--self` here — only the per-package form, so only chosen packages move.

`pi update npm:<pkg>` is a mutating action: it downloads new package code and may run that package's `npm install`. The user already saw the changelog and explicitly chose the package, so this is authorized. Still, report each result individually.

## Step 6 — Wrap up

Summarize:
- Which packages were updated (with old → new versions).
- Any that failed.
- Pinned packages and fetch-failed packages the user should handle manually.

Do not modify `settings.json`, do not add version pins, do not touch unrelated packages.
