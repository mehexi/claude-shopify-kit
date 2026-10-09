# Shopify work — how I work (applies in every chat)

I lead a team building and migrating Shopify stores for clients. When a task touches Shopify (stores, themes, products, apps, migrations, client updates):

**Tools**
- `shopify-project` skill: my project workflow — `/shopify-project init|next|status|chat|update`. Load it for any work inside a Shopify client project (a folder with `.shopify-project.json` + `TASKS.md`) or when starting a new one.
- Shopify's official skills (`shopify-admin`, `shopify-custom-data`, `shopify-liquid`, `shopify-functions`, `shopify-dev`): search the docs and **validate** GraphQL/Liquid before running or pushing it. Never trust memory for Shopify API field names.
- `shopify-dev` MCP server: live shopify.dev docs and schema introspection.
- Shopify CLI (`shopify store auth|execute`, `shopify theme pull|push|check`) for all store and theme access; `tools/gql.py` in each project wraps `shopify store execute`.
- Playwright MCP for checking the storefront (and the admin when there's no API).

**Workflow**
1. `TASKS.md` in the project is the single source of truth: phases from the quote, `[x]/[~]/[ ]/[!]` tasks, Blockers / Open Questions, Activity Log (newest first). Update it after every completed task or answered *project* question; a global hook blocks the turn if store/project work wasn't logged. Don't log unrelated questions.
2. Store data changes are idempotent, re-runnable scripts in `migration/` (look up by handle, update-or-create), with JSON/CSV snapshots beside them. Validate mutations with `shopify-admin` first.
3. Verify on the real store after every change (query back, `curl` URLs/redirects, Playwright screenshots) and record counts.
4. Commit after each task with the task id in the message.
5. Merchant-editable content (menus, page text, prices) lives in the Shopify admin, never hardcoded in the theme. Prefer the theme's built-in sections.
6. Client chats (often via an intermediary, sometimes Bangla) → tasks, blockers and client facts; client updates are plain text drafts that I send myself.

**Autonomy**
Carry tasks through end to end without asking for each step. Stop and ask only for: deleting anything on a store, business decisions (prices, shipping, policies, which products go live, publishing a theme/going live, DNS), anything that costs money, and sending anything to the client. Never tick a "Client approved" line unless I say the client approved or paid.
