# TODO — follow-ups found during the Miro DSL connector fix

Issues discovered while implementing `TODO-miro-dsl.md` (native connectors + worker
toolsets) that are **out of scope for that fix** and deferred here. Each is confirmed
against the live `mcp.miro.com` MCP unless noted.

## 1. `create-story-map.md` misdescribes the `layout_create` contract

`skills/story-map/reference/create-story-map.md` Step 2 (~lines 48–66) says
`layout_create` "takes a `board_name` plus the list of items" and "returns the new
`board_id`" — i.e. it treats `layout_create` as creating the board itself.

**The live MCP doesn't work that way.** `mcp__miro-official__layout_create` takes
`miro_url` (an existing board URL) + `dsl` text; it does **not** create a board.
Board creation is a separate tool, `mcp__miro-official__board_create` (name only,
returns an empty board). So the real create flow is: `board_create` → capture the
board URL → `layout_create` items into it.

- Confirmed: `board_create` schema takes only `name`/`description`; `layout_create`
  schema requires `miro_url` + `dsl`.
- Same latent issue likely in the OST and assumption-map create references — grep
  all three for "`board_name`" / "returns the new `board_id`" framing and reconcile
  to the `board_create` → `layout_create` two-step.
- Check whether the board workers even have `board_create` in their `tools:`
  frontmatter — if not, the create flow can't actually mint a board and this needs
  wiring, not just doc edits. (As of this fix the three board workers list
  `layout_get_dsl/read/create/update` + `context_get` but **not** `board_create`.)
