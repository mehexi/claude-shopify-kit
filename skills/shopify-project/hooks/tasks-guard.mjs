#!/usr/bin/env node
// Global Claude Code hook: in a Shopify project (a folder with .shopify-project.json above the cwd), work that
// changes project files or the store must be logged in TASKS.md before Claude ends its turn. Outside such
// projects it does nothing.
//   tasks-guard.mjs prompt (UserPromptSubmit) — mark turn start
//   tasks-guard.mjs tool   (PostToolUse)      — flag store changes: shopify CLI writes, gql.py mutations,
//                                              project scripts, Playwright actions inside admin.shopify.com
//   tasks-guard.mjs stop   (Stop)             — block if work happened but TASKS.md wasn't updated
// A theme repo points at the main repo with {"tracker": "../main-repo"} in its .shopify-project.json.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const mode = process.argv[2];
let input = {};
try { input = JSON.parse(fs.readFileSync(0, "utf8") || "{}"); } catch {}
const state = path.join(os.tmpdir(), "claude-tasks-guard", String(input.session_id || "default"));
fs.mkdirSync(state, { recursive: true });
const S = (f) => path.join(state, f);
const readJson = (f, d) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return d; } };

// Locate the project for a directory: { tracker, watched[] } or null.
function project(dir) {
  for (let d = path.resolve(dir || process.cwd()); ; d = path.dirname(d)) {
    const cfgFile = path.join(d, ".shopify-project.json");
    if (fs.existsSync(cfgFile)) {
      const cfg = readJson(cfgFile, {});
      const tracker = cfg.tracker ? path.resolve(d, cfg.tracker) : d;
      const tcfg = cfg.tracker ? readJson(path.join(tracker, ".shopify-project.json"), {}) : cfg;
      const watched = [d, tracker];
      if (tcfg.theme_dir) watched.push(path.resolve(tracker, tcfg.theme_dir));
      return { tracker, watched: [...new Set(watched)] };
    }
    if (path.dirname(d) === d) return null;
  }
}

// Remember every project touched this turn (Claude may cd between repos).
function remember(p) {
  if (!p) return;
  const known = readJson(S("projects.json"), {});
  known[p.tracker] = [...new Set([...(known[p.tracker] || []), ...p.watched])];
  fs.writeFileSync(S("projects.json"), JSON.stringify(known));
}

const STORE_WRITE = /shopify +(theme +(push|publish|delete|rename)|store +execute.*--allow-mutations|app +deploy)|gql\.py[^|;&]*(mutation|@)|(python3?|node) +[^ ]*(migration|scripts)[\/\\]/;

if (mode === "prompt") {
  fs.writeFileSync(S("turn-start"), "");
  for (const f of ["remote", "projects.json"]) fs.rmSync(S(f), { force: true });
  remember(project(input.cwd));
} else if (mode === "tool") {
  const p = project(input.cwd);
  if (!p) process.exit(0);
  remember(p);
  const tool = input.tool_name || "";
  const ti = input.tool_input || {};
  if (tool === "Bash") {
    if (STORE_WRITE.test(ti.command || "")) fs.writeFileSync(S("remote"), "");
  } else if (tool.startsWith("mcp__playwright__")) {
    if (tool === "mcp__playwright__browser_navigate") {
      if (String(ti.url || "").includes("admin.shopify.com")) fs.writeFileSync(S("in-admin"), "");
      else fs.rmSync(S("in-admin"), { force: true });
    } else if (fs.existsSync(S("in-admin")) && /click|type|fill_form|select_option|press_key|file_upload|drag|drop/.test(tool)) {
      fs.writeFileSync(S("remote"), "");
    }
  }
} else if (mode === "stop") {
  if (input.stop_hook_active || !fs.existsSync(S("turn-start"))) process.exit(0);
  remember(project(input.cwd));
  const start = fs.statSync(S("turn-start")).mtimeMs;
  const SKIP = new Set([".git", "node_modules", ".playwright-mcp", "__pycache__"]);
  const changedIn = (dir, depth = 0) => {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return null; }
    for (const e of entries) {
      if (SKIP.has(e.name) || e.name === "TASKS.md") continue;
      const f = path.join(dir, e.name);
      if (e.isDirectory()) { if (depth < 8) { const r = changedIn(f, depth + 1); if (r) return r; } }
      else { try { if (fs.statSync(f).mtimeMs > start) return f; } catch {} }
    }
    return null;
  };
  const remote = fs.existsSync(S("remote"));
  for (const [tracker, watched] of Object.entries(readJson(S("projects.json"), {}))) {
    const tasks = path.join(tracker, "TASKS.md");
    try { if (fs.statSync(tasks).mtimeMs > start) continue; } catch {}
    const changed = watched.map((d) => changedIn(d)).find(Boolean);
    if (changed || remote) {
      const reason = `Shopify project work happened this turn${changed ? ` (e.g. ${changed})` : " (store changed)"} but ${tasks} was not updated. ` +
        "Update the task status, add an Activity Log line (YYYY-MM-DD — what — task ids), refresh Current phase / Last updated, then commit. " +
        "Skip only if this turn was unrelated to the client project and changed nothing on the store.";
      process.stdout.write(JSON.stringify({ decision: "block", reason }));
      break;
    }
  }
}
process.exit(0);
