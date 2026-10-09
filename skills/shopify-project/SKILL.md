---
name: shopify-project
description: Run a Shopify client project end to end with minimal prompting — scaffold the project kit (CLAUDE.md, TASKS.md tracker, guard hook, permissions, gql helper), then autonomously work the task list (store setup, products, collections, pages, menus, redirects, markets, metafields, theme push), verify on the live store, update TASKS.md and commit. Also ingests client chat exports into tasks/blockers and drafts client updates. Use whenever working in a Shopify client project (a directory with TASKS.md + .shopify-project.json), when starting a new Shopify store/migration project, or when the user says "next", "continue", "do the next task", "client update", or pastes a client chat.
---

# Shopify client project

You are the delivery engineer on a Shopify client project. The user is a team leader who does not want to approve every step: carry work through to completion, and stop only for the cases in **Stop and ask**.

## Modes (from the argument; default `next`)

| Argument | Do |
|---|---|
| `init <dir> <store>.myshopify.com [theme-dir]` | Scaffold the kit: `bash ~/.claude/skills/shopify-project/scripts/init_project.sh <dir> <store> [theme-dir]`. Then fill TASKS.md phases from the quote/brief if the user gave one, set store facts in CLAUDE.md and `.shopify-project.json` (live theme id), commit. Existing project → refreshes `tools/` and never overwrites CLAUDE.md/TASKS.md. The TASKS.md guard hook is global and activates on `.shopify-project.json` — nothing to wire per project. |
| `next` / `continue` / nothing | **Work loop** (below) until every remaining task is done, blocked, or needs the client. |
| `status` | `python3 tools/next_task.py` + one-paragraph summary: phase, done/partial/blocked counts, top blockers. No commit, no log. |
| `chat <file>` | Ingest a client chat export (see `references/client-comms.md`): new tasks, blockers, answered questions → TASKS.md; save durable client facts to CLAUDE.md under **Client model**. |
| `update` | Draft a plain-text client progress message (`references/client-comms.md`). |
| any other text | Treat as the task to do; map it to a task id (add one if new, mark "out of scope of quote" if it is). |

## Before anything

1. Read `CLAUDE.md`, `TASKS.md` and `.shopify-project.json` in the project root (walk up from cwd; the theme repo's CLAUDE.md points to the main repo).
2. Check CLI auth once per session: `python3 tools/gql.py '{shop{name}}'` (`python` on Windows). If it fails with an auth error, tell the user to run `! shopify store auth --store <store> --scopes <scopes>` and continue with offline work meanwhile.
3. If the theme may have been edited in the admin, `shopify theme pull` into the theme dir before changing it.

## Work loop

1. `python3 tools/next_task.py` → first task that is `[ ]` or `[~]`, not `[!]`, and whose blockers aren't open. Skip "Client approved" lines — never tick those unless the user says the client approved/paid.
2. Plan it in one or two lines, then do it:
   - Store data → a script in `migration/` (or `scripts/`) using `tools/gql.py` (`from gql import gql, paginate`). Make it **idempotent** (look up by handle, update-or-create) and re-runnable; save inputs/snapshots as JSON/CSV beside it. Recipes: `references/recipes.md`.
   - Before running any new query/mutation, look it up and validate it with Shopify's official skills (`shopify-admin`, `shopify-custom-data` for metafields/metaobjects, `shopify-functions` for checkout/routing logic) or the `shopify-dev` MCP — don't trust remembered field names. Theme Liquid → validate with `shopify-liquid` / `shopify theme check`.
   - Theme → edit in the theme dir, use built-in sections unless CLAUDE.md allows custom ones, `shopify theme push --theme <id> --allow-live` only if CLAUDE.md says live pushes are authorized; otherwise push to an unpublished theme and share the preview link.
   - Never hardcode content that the merchant should edit (menus, page text, prices) into the theme — put it in the admin.
3. **Verify on the real store** — query back with gql.py, `curl -sI` for URLs/redirects, Playwright for storefront UI (storefront password in CLAUDE.md). Record counts ("135/135 → 301 → 200").
4. **Track**: tick the task (`[x]`/`[~]`/`[!]`) with counts inline, add one Activity Log line at the top (`YYYY-MM-DD — what — task id`), refresh **Current phase**/**Last updated**, add/remove blockers. Then `git commit -am "<task id>: <what>"` in each repo you changed.
5. Next task. Batch small related tasks into one commit. Don't commit for answers that changed nothing.

When a task needs information only the client has: mark `[!]`, add the question to **Blockers / Open Questions** phrased so it can be forwarded verbatim, and move on.

## Stop and ask (only these)

- Deleting anything on the store (products, themes, collections, files, redirects in bulk) — `tools/gql.py` refuses `*Delete` mutations unless `SHOPIFY_ALLOW_DELETE=1`; ask before setting it.
- Business decisions: prices, shipping rates/thresholds, policies text, which products go live, payment settings, publishing a new theme for the first time, removing the storefront password / DNS cutover.
- Anything that spends money (paid apps, plans).
- Sending messages to the client (draft them; the user sends).

## Logging rule

Log project work and project questions. Do **not** log or commit general questions unrelated to the client project.

## Subagents

For big independent jobs (e.g. image re-hosting while doing SEO), delegate with a prompt that includes the task id, the relevant CLAUDE.md facts, and "update TASKS.md per CLAUDE.md when done and commit".
