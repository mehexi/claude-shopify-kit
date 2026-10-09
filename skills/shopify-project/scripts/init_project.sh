#!/usr/bin/env bash
# Scaffold (or upgrade) a Shopify client project for the shopify-project workflow.
#   init_project.sh <dir> <store>.myshopify.com [theme-dir]
# Creates CLAUDE.md / TASKS.md / .shopify-project.json only if missing; always refreshes tools/.
# The TASKS.md guard hook is global (installed by the kit's install.sh) and activates on .shopify-project.json.
set -euo pipefail
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
dir="${1:?usage: init_project.sh <dir> <store> [theme-dir]}"; store="${2:?store domain required}"; theme="${3:-}"
mkdir -p "$dir"/{tools,migration}
dir="$(cd "$dir" && pwd)"; name="$(basename "$dir")"; today="$(date +%F)"
rel() { node -e 'console.log(require("path").relative(process.argv[1], process.argv[2]) || ".")' "$1" "$2"; }
if [ -n "$theme" ]; then mkdir -p "$theme"; theme="$(cd "$theme" && pwd)"; fi

render() { sed -e "s|__NAME__|$name|g" -e "s|__STORE__|$store|g" -e "s|__DATE__|$today|g" \
               -e "s|__THEME_LINE__|${theme:+code in \`$theme\`; live theme id: <fill in>}|g" "$1"; }
for f in CLAUDE.md TASKS.md; do
  if [ -e "$dir/$f" ]; then echo "keep   $f (exists)"; else render "$SKILL/kit/$f.tmpl" > "$dir/$f"; echo "create $f"; fi
done

cp "$SKILL/scripts/gql.py" "$SKILL/scripts/next_task.py" "$dir/tools/"
chmod +x "$dir/tools/"*.py
echo "update tools/gql.py tools/next_task.py"

if [ ! -e "$dir/.shopify-project.json" ]; then
  td=""; [ -n "$theme" ] && td="$(rel "$dir" "$theme")"
  printf '{\n  "store": "%s",\n  "theme_dir": "%s",\n  "live_theme_id": null\n}\n' "$store" "$td" > "$dir/.shopify-project.json"
  echo "create .shopify-project.json"
fi

touch "$dir/.gitignore"
for p in .playwright-mcp/ .claude/settings.local.json '*.zip' __pycache__/; do
  grep -qxF "$p" "$dir/.gitignore" || echo "$p" >> "$dir/.gitignore"
done

if [ -n "$theme" ]; then
  [ -e "$theme/.shopify-project.json" ] || printf '{\n  "tracker": "%s"\n}\n' "$(rel "$theme" "$dir")" > "$theme/.shopify-project.json"
  [ -e "$theme/CLAUDE.md" ] || printf '# %s — theme\n\nPart of the %s project. Full rules: `%s/CLAUDE.md` — read it first.\nAfter every completed task update `%s/TASKS.md` as described there.\n' \
    "$name" "$name" "$(rel "$theme" "$dir")" "$(rel "$theme" "$dir")" > "$theme/CLAUDE.md"
  [ -d "$theme/.git" ] || git -C "$theme" init -q
fi
[ -d "$dir/.git" ] || git -C "$dir" init -q
echo "Kit ready in $dir."
