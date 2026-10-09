# Client communication

## Ingesting a chat export (`chat <file>`)
Save the export in the project root (e.g. `chat.md`, append newer exports with a dated heading). Then read it and extract:
1. **Requests** → new task (next free id in the right phase) or a sub-item of an existing one. Mark "out of scope of quote" when it isn't covered.
2. **Answers** to open questions → tick the 1.2 sub-items, remove the blocker, apply the answer.
3. **New questions/uncertainties** → Blockers / Open Questions, phrased so the user can forward them verbatim.
4. **Durable client facts** (SKU model, fulfillment, preferences, approval steps) → CLAUDE.md **Client model**.
Messages may be in Bangla/Banglish from an intermediary — translate the intent; quote the client's own English words when they define requirements.
Log one Activity Log line ("Reviewed client chat: …") and commit.

## Client progress update (`update`)
Plain text (it gets pasted into WhatsApp/email): no markdown tables, no headings with #, short lines.

```
Hi <name>,

Quick update on the <store> Shopify build:

Done
- <outcome in client language, with counts: "All 135 old website links now redirect to the new pages">

In progress
- <item> — <what's left>

Need from you
1. <question, answerable in one line>

Next
- <next 1–3 things and roughly when>

<preview link + storefront password if relevant>
```
Use the client's words, not Shopify jargon (say "pack sizes", not "variants", unless the client uses it). Never promise dates the user didn't give. Draft only — the user sends it. Log the draft in the Activity Log.
