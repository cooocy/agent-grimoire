#!/usr/bin/env bash
# check-outdated.sh — scan installed pi packages, compare to npm latest.
# Pure bash + npm. No LLM. Outputs a table of outdated / pinned packages.
# Exit code: 0 always (warnings printed inline); 1 only on fatal setup error.

set -u

GLOBAL_SETTINGS="${HOME}/.pi/agent/settings.json"
PROJECT_SETTINGS="${PWD}/.pi/settings.json"
NPM_ROOT="${HOME}/.pi/agent/npm/node_modules"

# --- semver compare: returns 0 if equal, 1 if a<b, 2 if a>b (ignores prerelease) ---
semver_cmp() {
  local a="$1" b="$2"
  a="${a%%-*}"; b="${b%%-*}"
  local IFS=.
  local i arr_a arr_b
  read -ra arr_a <<<"$a"
  read -ra arr_b <<<"$b"
  local len=${#arr_a[@]}
  (( ${#arr_b[@]} > len )) && len=${#arr_b[@]}
  for (( i=0; i<len; i++ )); do
    local va=${arr_a[i]:-0}
    local vb=${arr_b[i]:-0}
    # strip leading zeros via arithmetic
    (( 10#$va > 10#$vb )) && return 2
    (( 10#$va < 10#$vb )) && return 1
  done
  return 0
}

# --- extract npm package names from a settings.json packages array ---
# Prints "<pkgname>\t<pinned|unpinned>" per line. Project file wins on dup.
extract_pkgs() {
  local file="$1"
  [ -f "$file" ] || return 0
  # Use node to parse JSON robustly (handles string + object forms).
  node -e '
    const fs = require("fs");
    const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const pkgs = s.packages || [];
    for (const entry of pkgs) {
      let spec, pinned = false;
      if (typeof entry === "string") {
        spec = entry;
      } else if (entry && typeof entry === "object" && entry.source) {
        spec = entry.source;
      } else {
        continue;
      }
      if (!spec.startsWith("npm:")) continue;
      const body = spec.slice(4);
      // npm:@scope/pkg@1.2.3 -> pinned. npm:pkg -> unpinned.
      // package names can contain @ only as the scope prefix; a trailing @ver means pinned.
      const at = body.lastIndexOf("@");
      if (at > 0) {
        const name = body.slice(0, at);
        const ver = body.slice(at + 1);
        if (ver) { console.log(name + "\tpinned"); continue; }
        console.log(name + "\tunpinned");
      } else {
        console.log(body + "\tunpinned");
      }
    }
  ' "$file" 2>/dev/null
}

# --- collect packages: global first, then project overrides by name ---
declare -A PKG_STATE  # name -> "pinned"|"unpinned"
load_pkgs() {
  local name state
  while IFS=$'\t' read -r name state; do
    [ -z "$name" ] && continue
    PKG_STATE["$name"]="$state"
  done < <(extract_pkgs "$GLOBAL_SETTINGS")
  if [ -f "$PROJECT_SETTINGS" ] && [ "$PROJECT_SETTINGS" != "$GLOBAL_SETTINGS" ]; then
    while IFS=$'\t' read -r name state; do
      [ -z "$name" ] && continue
      PKG_STATE["$name"]="$state"
    done < <(extract_pkgs "$PROJECT_SETTINGS")
  fi
}

main() {
  load_pkgs
  if [ ${#PKG_STATE[@]} -eq 0 ]; then
    echo "No npm packages found in settings."
    echo "  checked: $GLOBAL_SETTINGS"
    [ -f "$PROJECT_SETTINGS" ] && echo "  checked: $PROJECT_SETTINGS"
    return 0
  fi

  local outdated_count=0 pinned_count=0
  local -a pinned_lines=() outdated_lines=()
  local names
  # sort names for stable output
  names=$(printf '%s\n' "${!PKG_STATE[@]}" | LC_ALL=C sort)

  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    local state="${PKG_STATE[$pkg]}"
    local installed=""
    local pkg_json="${NPM_ROOT}/${pkg}/package.json"
    if [ -f "$pkg_json" ]; then
      installed=$(node -p "require(process.argv[1]).version" "$pkg_json" 2>/dev/null)
    fi
    if [ -z "$installed" ]; then
      printf 'WARN  %-40s not installed locally (skipped)\n' "$pkg"
      continue
    fi

    if [ "$state" = "pinned" ]; then
      pinned_lines+=("$(printf '%-42s %s (pinned)' "$pkg" "$installed")")
      pinned_count=$((pinned_count+1))
      continue
    fi

    local latest
    latest=$(npm view "$pkg" version 2>/dev/null)
    if [ -z "$latest" ]; then
      printf 'WARN  %-40s npm view failed (skipped)\n' "$pkg"
      continue
    fi

    semver_cmp "$installed" "$latest"; rc=$?
    if [ "$rc" = "1" ]; then
      outdated_lines+=("$(printf '%-42s %-10s -> %-10s' "$pkg" "$installed" "$latest")")
      outdated_count=$((outdated_count+1))
    fi
  done <<<"$names"

  echo "Pi package update check"
  echo "======================="
  if [ "$outdated_count" -gt 0 ]; then
    echo
    echo "Outdated ($outdated_count):"
    printf '%s\n' "${outdated_lines[@]}"
  fi
  if [ "$pinned_count" -gt 0 ]; then
    echo
    echo "Pinned (not auto-updatable; use 'pi install npm:<pkg>@<new-ref>' to move):"
    printf '%s\n' "${pinned_lines[@]}"
  fi
  if [ "$outdated_count" -eq 0 ] && [ "$pinned_count" -eq 0 ]; then
    echo "All npm packages up to date."
  fi
}

main "$@"
