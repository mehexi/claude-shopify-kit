#!/usr/bin/env bash
# Install the Shopify kit for Claude Code at user level (every chat on this PC):
#   - shopify-project skill (linked to this repo, so `git pull` updates it) + global TASKS.md guard hook
#   - all of Shopify's official agent skills from github.com/Shopify/agent-skills (patched to run on current Node)
#   - MCP servers: shopify-dev (@shopify/dev-mcp) and playwright
#   - ~/.claude/CLAUDE.md imports the workflow; ~/.claude/settings.json gets hooks, permissions, telemetry opt-out
#   - Shopify CLI if missing
# Re-run any time to update. Works on Linux, macOS and Windows (Git Bash).
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/claude-shopify-kit"
say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }

say "Checking requirements"
for c in git node npm; do command -v $c >/dev/null || { echo "Missing: $c — install it first (Node 20+)"; exit 1; }; done
command -v python3 >/dev/null || command -v python >/dev/null || warn "Python 3 not found — tools/gql.py and next_task.py need it"
if ! command -v shopify >/dev/null; then say "Installing Shopify CLI"; npm install -g @shopify/cli@latest; fi
command -v claude >/dev/null || warn "claude CLI not on PATH — MCP servers will be skipped; re-run after installing Claude Code"

mkdir -p "$CLAUDE_DIR/skills" "$DATA"

say "Linking shopify-project skill"
dest="$CLAUDE_DIR/skills/shopify-project"
if [ -e "$dest" ] && [ ! -L "$dest" ]; then mv "$dest" "$dest.bak.$(date +%s)"; warn "Old copy moved to $dest.bak.*"; fi
rm -f "$dest"; ln -s "$KIT/skills/shopify-project" "$dest" 2>/dev/null || cp -r "$KIT/skills/shopify-project" "$dest"
chmod +x "$KIT/skills/shopify-project/scripts/"* "$KIT/skills/shopify-project/hooks/"* 2>/dev/null || true

say "Installing Shopify official skills"
if [ -d "$DATA/agent-skills/.git" ]; then git -C "$DATA/agent-skills" pull -q --ff-only
else git clone -q --depth 1 https://github.com/Shopify/agent-skills.git "$DATA/agent-skills"; fi
SHIM="$KIT/skills/shopify-project/scripts/require-shim.mjs"
for src in "$DATA/agent-skills"/shopify-*/; do
  s="$(basename "$src")"; d="$CLAUDE_DIR/skills/$s"
  [ -f "$src/SKILL.md" ] && [[ "$s" != *-test ]] || continue
  rm -rf "$d"; cp -r "$src" "$d"
  # Their bundled scripts use require/__filename inside ESM and crash on Node 22+; preload the shim.
  [ -d "$d/scripts" ] && node - "$SHIM" "$d"/scripts/*.js <<'JS'
const fs = require("fs"), { pathToFileURL } = require("url");
const [shim, ...files] = process.argv.slice(2);
const line = `import ${JSON.stringify(pathToFileURL(shim).href)};`;
for (const f of files) {
  const lines = fs.readFileSync(f, "utf8").split("\n");
  if (lines.some((l) => l.includes("require-shim.mjs"))) continue;
  lines.splice(lines[0].startsWith("#!") ? 1 : 0, 0, line);
  fs.writeFileSync(f, lines.join("\n"));
}
JS
  if [ -f "$d/package.json" ]; then
    # Their lockfiles point at Shopify's private registry — install from the public one instead.
    rm -f "$d/package-lock.json"
    (cd "$d" && npm install --omit=dev --silent --no-audit --no-fund --legacy-peer-deps --registry https://registry.npmjs.org/) \
      || warn "$s: npm install failed — its validate.js won't work until fixed"
  fi
  echo "    $s"
done

say "Global CLAUDE.md (imports the workflow)"
md="$CLAUDE_DIR/CLAUDE.md"; touch "$md"
node - "$md" <<'EOF'
const fs = require("fs"); const f = process.argv[2];
const block = "<!-- shopify-kit:start -->\n@~/.claude/skills/shopify-project/WORKFLOW.md\n<!-- shopify-kit:end -->";
let s = fs.readFileSync(f, "utf8");
s = /<!-- shopify-kit:start -->[\s\S]*?<!-- shopify-kit:end -->/.test(s)
  ? s.replace(/<!-- shopify-kit:start -->[\s\S]*?<!-- shopify-kit:end -->/, block)
  : (s.trimEnd() ? s.trimEnd() + "\n\n" : "") + block + "\n";
fs.writeFileSync(f, s);
EOF

say "Global settings.json (hooks, permissions, telemetry opt-out)"
node - "$CLAUDE_DIR/settings.json" <<'EOF'
const fs = require("fs"); const f = process.argv[2];
let s = {}; try { s = JSON.parse(fs.readFileSync(f, "utf8")); fs.copyFileSync(f, f + ".bak"); } catch {}
const hook = (m) => `node "$HOME/.claude/skills/shopify-project/hooks/tasks-guard.mjs" ${m}`;
const mine = (e) => JSON.stringify(e).includes("shopify-project/hooks/tasks-guard");
s.hooks ??= {};
for (const [ev, mode, matcher] of [["UserPromptSubmit", "prompt"], ["PostToolUse", "tool", "Bash|mcp__playwright__.*"], ["Stop", "stop"]]) {
  s.hooks[ev] = (s.hooks[ev] || []).filter((e) => !mine(e));
  s.hooks[ev].push({ ...(matcher ? { matcher } : {}), hooks: [{ type: "command", command: hook(mode) }] });
}
s.permissions ??= {};
const add = (k, xs) => { s.permissions[k] = [...new Set([...(s.permissions[k] || []), ...xs])]; };
add("allow", ["Bash(shopify *)", "Bash(python3 tools/*)", "Bash(python tools/*)",
  "Bash(bash ~/.claude/skills/shopify-project/scripts/*)", "Bash(node ~/.claude/skills/shopify-*/scripts/*)",
  "Read(~/.claude/skills/**)"]);
add("ask", ["Bash(shopify theme delete*)", "Bash(shopify theme publish*)", "Bash(git push --force*)", "Bash(git push -f*)",
  "Bash(git reset --hard*)", "Bash(git clean*)", "Bash(SHOPIFY_ALLOW_DELETE=1*)"]);
s.env = { ...(s.env || {}), OPT_OUT_INSTRUMENTATION: "true" };
fs.writeFileSync(f, JSON.stringify(s, null, 2) + "\n");
EOF

if command -v claude >/dev/null; then
  say "MCP servers (user scope)"
  has() { claude mcp list 2>/dev/null | grep -q "^$1:"; }
  has shopify-dev || claude mcp add --scope user shopify-dev -e OPT_OUT_INSTRUMENTATION=true -- npx -y @shopify/dev-mcp@latest
  has playwright || claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest
fi

say "Done. Restart Claude Code, then per store:"
echo "    shopify store auth --store <store>.myshopify.com --scopes <scopes>"
echo "    /shopify-project init <project-dir> <store>.myshopify.com [theme-dir]"
