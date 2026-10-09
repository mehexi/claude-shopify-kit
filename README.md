# claude-shopify-kit

My Shopify workflow for Claude Code, installable on any PC. After install, **every** Claude chat on that machine knows how I run Shopify projects and has the tools to do it.

## Install / update

```bash
git clone https://github.com/mehexi/claude-shopify-kit.git ~/claude-shopify-kit
bash ~/claude-shopify-kit/install.sh        # re-run after `git pull` to update
```

Needs git, Node 20+, Python 3, Claude Code. Windows: run from Git Bash. Private repo: run `gh auth login` (or use a token) on the new PC first.

Then restart Claude Code and authorize each store once:

```bash
shopify store auth --store <store>.myshopify.com --scopes read_products,write_products,...
```

## What it installs (all user-level)

| Piece | Where | What it does |
|---|---|---|
| `shopify-project` skill | `~/.claude/skills/shopify-project` → this repo | `/shopify-project init\|next\|status\|chat\|update` — autonomous task loop over `TASKS.md`, client chat ingestion, client updates |
| Workflow rules | `~/.claude/CLAUDE.md` imports `WORKFLOW.md` | Every chat knows the workflow, tools and when to stop and ask |
| TASKS.md guard hook | `~/.claude/settings.json` | Inside a Shopify project (folder with `.shopify-project.json`), blocks the end of a turn if files or the store changed but `TASKS.md` wasn't updated. Does nothing elsewhere |
| Shopify official skills | `~/.claude/skills/shopify-{admin,custom-data,liquid,functions,dev}` | Docs search + GraphQL/Liquid validation (from github.com/Shopify/agent-skills) |
| MCP servers | user scope | `shopify-dev` (@shopify/dev-mcp), `playwright` |
| Shopify CLI | global npm | if missing |
| Permissions | `~/.claude/settings.json` | `shopify`/project tools run without prompts; theme delete/publish, force-push, `reset --hard`, deletes on the store always ask |

Telemetry from Shopify's skills and MCP is turned off (`OPT_OUT_INSTRUMENTATION=true`).

## New client project

In Claude: `/shopify-project init ~/Projects/shopify/<client> <store>.myshopify.com ~/Projects/shopify/<client>-theme`

Creates `CLAUDE.md`, `TASKS.md` (3-phase template), `.shopify-project.json`, `tools/gql.py` (Admin GraphQL through the Shopify CLI, refuses deletes unless `SHOPIFY_ALLOW_DELETE=1`), `tools/next_task.py`. A separate theme repo gets `.shopify-project.json` with `{"tracker": "../<client>"}` so its work is logged in the main tracker.

## Layout

```
install.sh
skills/shopify-project/
  SKILL.md            workflow the agent follows
  WORKFLOW.md         short rules imported into every chat
  hooks/tasks-guard.mjs
  scripts/            init_project.sh, gql.py, next_task.py
  kit/                CLAUDE.md / TASKS.md templates
  references/         GraphQL recipes, client comms
```
