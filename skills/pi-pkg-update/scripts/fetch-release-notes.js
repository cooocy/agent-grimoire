#!/usr/bin/env node
// fetch-release-notes.js <pkg> <installed> <latest>
// Reads the installed package's repository info, fetches GitHub releases,
// filters to installed < version <= latest, applies monorepo subpackage
// filtering by repository.directory basename, and prints release notes.
// Prints "(无可用说明)" for a package when no matching releases are found.
// Uses GITHUB_TOKEN env var if present to raise rate limits.

const fs = require("fs");
const path = require("path");
const https = require("https");

const HOME = process.env.HOME;
const NPM_ROOT = path.join(HOME, ".pi/agent/npm/node_modules");

function die(msg) {
  console.error(`ERR ${msg}`);
  process.exit(0); // 0: warn, don't abort the whole skill
}

const [pkg, installed, latest] = process.argv.slice(2);
if (!pkg || !installed || !latest) die("usage: fetch-release-notes.js <pkg> <installed> <latest>");

const pkgJsonPath = path.join(NPM_ROOT, pkg, "package.json");
let pkgJson;
try { pkgJson = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8")); }
catch { die(`cannot read ${pkgJsonPath}`); }

const repo = pkgJson.repository;
if (!repo || !repo.url) die(`no repository.url for ${pkg}`);
const m = repo.url.match(/github\.com[:/]([^/]+)\/([^/.]+)/);
if (!m) die(`repository.url is not a github URL: ${repo.url}`);
const owner = m[1], repoName = m[2];
const subdir = repo.directory ? path.basename(repo.directory) : null;

// semver core compare (ignore prerelease)
function core(v) { return (v.match(/(\d+\.\d+\.\d+)/) || [, v])[1]; }
function cmp(a, b) {
  const ax = core(a).split(".").map(Number);
  const bx = core(b).split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((ax[i] || 0) !== (bx[i] || 0)) return (ax[i] || 0) - (bx[i] || 0);
  }
  return 0;
}

// extract a semver from a tag string
function tagVer(tag) {
  const mm = tag.match(/(\d+\.\d+\.\d+(?:[-+][\w.]+)?)/);
  return mm ? mm[1] : null;
}

// monorepo filter: does this tag belong to our subpackage?
function tagMatchesSubpackage(tag) {
  if (!subdir) return true; // single-package repo
  const t = tag.toLowerCase();
  const s = subdir.toLowerCase();
  // common patterns: pkg@ver, pkg-ver, pkg/ver, pkg ver
  return t.includes(s + "@") || t.includes(s + "-") || t.includes(s + "/") || t.startsWith(s);
}

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    const headers = { "User-Agent": "pi-pkg-update", "Accept": "application/vnd.github+json" };
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    https.get(url, { headers }, (res) => {
      let body = "";
      res.on("data", (d) => (body += d));
      res.on("end", () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
        } else {
          reject(new Error(`HTTP ${res.statusCode} for ${url}`));
        }
      });
    }).on("error", reject);
  });
}

(async () => {
  let releases;
  try {
    releases = await fetchJSON(`https://api.github.com/repos/${owner}/${repoName}/releases?per_page=100`);
  } catch (e) {
    die(`github releases fetch failed: ${e.message}`);
  }

  const kept = [];
  for (const rel of releases) {
    const tag = rel.tag_name || "";
    const ver = tagVer(tag);
    if (!ver) continue;
    if (!tagMatchesSubpackage(tag)) continue;
    // installed < ver <= latest
    if (cmp(ver, installed) <= 0) continue;
    if (cmp(ver, latest) > 0) continue;
    kept.push({ tag, name: rel.name || tag, body: (rel.body || "").trim() });
  }

  if (kept.length === 0) {
    console.log(`${pkg}: (无可用说明)`);
    return;
  }

  // newest first (API returns newest first already; keep that)
  console.log(`# ${pkg}  (${installed} -> ${latest})\n`);
  for (const r of kept) {
    console.log(`## ${r.tag}`);
    if (r.body) console.log(r.body);
    else console.log("_(release has no body)_");
    console.log("");
  }
})().catch((e) => die(e.message));
