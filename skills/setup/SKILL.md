---
name: setup
description: Scaffold a project to use the Visual Collaboration with AI (vcw) workflow — create the product/ artifact tree and add the workflow conventions to CLAUDE.md. Non-destructive and idempotent; safe to run in an existing repo. Use once after installing the plugin.
version: 1.0.0
category: product-management
---

# Setup Skill

Prepares the current project to use the Visual Collaboration with AI workflow. It creates the `product/` artifact scaffold and adds the workflow conventions to the project's `CLAUDE.md`.

This skill is **non-destructive and idempotent**. It never overwrites existing files or existing `CLAUDE.md` content, and it is safe to run more than once or in a repo that already has its own `CLAUDE.md` and directories. It always reports what it will do and asks for confirmation before writing anything.

The conventions and scaffold templates live alongside this skill:
- `templates/claude-md-block.md` — the delimited workflow-conventions block to add to `CLAUDE.md`.
- `templates/product-README.md` — the `product/` scaffold README.

## When to use

- Right after installing the `vcw` plugin into a project, to lay down the artifact structure and conventions.
- The PM runs it explicitly (`/vcw:setup`). Nothing scaffolds automatically.

## Procedure

Work against the **user's project root** — `${CLAUDE_PROJECT_DIR}` if set, otherwise the current working directory. Refer to it as `<root>` below.

### 1. Detect current state

Check, without modifying anything:

- Does `<root>/CLAUDE.md` exist?
  - If it exists, does it already contain the line `<!-- BEGIN vcw -->`? (If so, the conventions block is already installed.)
- Does `<root>/product/` exist? If so, what's already in it — is it the empty scaffold, or does it hold real content (files/subdirs other than `context/`, `iterations/`, `README.md`)?
- Does `<root>/product/context/` exist?
- Does `<root>/product/iterations/` exist?

### 2. Plan and report (dry run)

Build a plan from the detection results and **print it to the PM before writing anything**. For each item state the action: **create**, **append**, **skip (already present)**, or **ask first**.

- **`product/` tree:**
  - Missing → plan to create `product/`, `product/context/`, `product/iterations/`, and `product/README.md` (from `templates/product-README.md`).
  - Exists but missing some subdirs → plan to create only the missing subdirs / README; skip what exists.
  - Exists and holds unrelated content (not just the scaffold) → **ask first**: tell the PM what's already there and confirm it's the right place to add `context/` and `iterations/` before touching it. Never overwrite existing files.
- **`CLAUDE.md`:**
  - Missing → plan to create it with the conventions block (`templates/claude-md-block.md`).
  - Exists, already contains `<!-- BEGIN vcw -->` → **skip** (idempotent). Mention it's already installed.
  - Exists, no block → plan to **append** the conventions block. Show the PM the exact block that will be appended (it's delimited by `<!-- BEGIN vcw -->` / `<!-- END vcw -->`, so it can be found and removed later). Never modify their existing content.

If everything is already in place, say so and stop — there's nothing to do.

### 3. Confirm

Ask the PM to confirm the plan. Do not write until they approve. If they decline a specific item, honor that and proceed with the rest.

### 4. Apply

On approval, perform exactly the planned actions:

- Create missing `product/` directories with `mkdir -p`.
- Write `product/README.md` from the template **only if it doesn't already exist**.
- For `CLAUDE.md`:
  - Create from the template block if missing.
  - Append the template block (with a blank line before it) if the file exists without the block.
  - Do nothing if the block is already present.

Never use a destructive write on an existing file. Appending to `CLAUDE.md` means adding to the end, preserving everything above.

### 5. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers use the official hosted Miro MCP (OAuth at connect); the connector REST scripts use a `MIRO_ACCESS_TOKEN` environment variable.
2. **Bring a design system** — the prototyping skills ship with Equal Experts' Kuat as a worked example; point them at your own design system to use it.
3. **Establish product context** — run `/vcw:framework-setup` once.
4. **Start an iteration** — run `/vcw:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project (`product/` and `CLAUDE.md`). It never writes into the plugin's own directory.
- Re-running is safe: a second run detects the installed block and the existing scaffold and skips them.
- To uninstall the conventions, the PM deletes the block between `<!-- BEGIN vcw -->` and `<!-- END vcw -->` in `CLAUDE.md`.
