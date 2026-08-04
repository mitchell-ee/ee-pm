# Migrations

One file per migration. `setup` §7 runs them; nothing else does.

**These files ship with the plugin.** They live at
`${CLAUDE_PLUGIN_ROOT}/skills/setup/migrations/` — inside the plugin's versioned install
directory, never in the user's project. A migration is invoked by absolute path from there, and
operates *on* the project's `product/` tree. If this directory looks empty or absent, re-resolve
`${CLAUDE_PLUGIN_ROOT}`; searching the project for `migrations/` will always come up empty and
that is not evidence of a packaging problem.

A migration exists because **the plugin changed a convention and existing project data is now
stale**. The plugin cannot run code when it is updated — there is no install hook — so migration
is *lazy*: the version marker in the project's `CLAUDE.md` makes the gap visible the next time
any skill runs, and `/ee-pm:setup` applies the fix.

## Naming

```
{version-that-introduced-the-change}-{slug}.{sh|md}
```

`.sh` for mechanical transforms, `.md` for ones needing PM judgment. The version is **when the
convention changed**, not when the migration was written — a migration added late for an
already-released version still names that version, and still applies, because selection is by
data shape rather than version arithmetic (see below).

## Header

Every migration opens with:

```
**Applies when:** <the data shape that makes this migration relevant>
**Guard:** <what to check; what a no-op looks like>
**Requires:** <migrations that must run before this one, or —>
**Precedes:** <migrations that must run after, or omit>
```

`Requires:` is honored **before** version order. Version numbers do not reliably encode
dependency: a `0.6.0` migration can produce data that a `0.7.0` one fixes up, and the sort only
happens to get that right. Declare it rather than relying on the numbers.

## The contract

Every migration MUST be:

1. **Guarded** — inspect the data first; act only if the old shape is present. A migration that
   finds nothing to do is a success, not a failure.
2. **Idempotent** — running it twice changes nothing the second time. This is what makes
   "run every migration between the project's version and the plugin's" safe, and what makes a
   retroactively-added migration safe on a project that already passed that version.
3. **Dry-run by default** — `--dry-run` prints what would change and writes nothing; `--apply`
   performs it. §7 always runs dry first and shows the PM before asking for approval.
4. **Explicit about no-ops** — print `nothing to do` and exit 0 when the guard finds nothing.
   A silent no-op is indistinguishable from a silent failure; that ambiguity is exactly how a
   stale Miro sidecar goes unnoticed.
5. **History-preserving** — use `git mv` for moves and renames.
6. **Target-guarded when it creates files** — before writing `product/personas/{slug}.md`, check
   whether it already exists and skip if so. A guard on the *source* is not enough: a PM may have
   done the transform by hand, and re-running must never clobber authored content.

## Guards fail open, never closed

A migration that cannot tell whether it applies must **do nothing and say so**, not guess. The
cost of a skipped migration is a `§7.3` check failure and a clear prompt; the cost of a wrong
guess is corrupted project data with a version marker vouching for it.

## Idempotence is the whole design

There is **no record of which migrations have run**. There is no state file, no applied-list, no
bookkeeping to drift out of sync. §7 runs **every** migration in version order — not just the
ones newer than the project's marker — and each one decides for itself whether it applies.

Running the full set is what makes a **retroactively-added migration** work: a `0.6.0` migration
written after projects already reached 0.6.0 would never be selected by a newer-than filter, and
those projects would stay broken. The version marker is a prompt trigger ("you're behind, run
setup"), never the selector.

That works only because guards key on **data shape**, not on version numbers:

- The priority migration matches `Critical|High|Medium|Low` in a priority field. After it runs,
  the fields say `P0..P3`, which is not in its input alphabet — so a second run matches nothing.
- The sidecar rekey matches keys with **exactly two digits**. Once widened to four, the pattern
  no longer matches. A project migrated by hand is already at the fixed point and the script
  correctly does nothing.
- The context-collapse migration is guarded on `product/context/` existing. Once removed, it is
  a no-op by construction.
- The persona migration acts only on personas *lacking* frontmatter. Once they have it, it
  skips them — the transform needs PM judgment, but the guard makes re-running harmless.

**Anchor guards on structure, never on bare words.** `Priority: High` is a field; `High` inside a
sentence is prose. A migration that does a blanket text substitution is not idempotent, it is
destructive — it will keep finding new things to "fix" on every run. Match on the field
(`^\*\*Priority\*\*:`, `^priority:`) or the JSON key position, never on the value alone.

## The validation gate

Migrations do not decide whether a project is current — **§7.3 does, by inspecting the data.**
After every migration runs, setup validates the result (personas have slugs, ref-ids are the right
width, sidecar keys match, priority fields use the current scale) and stamps the version marker
**only if the data is actually correct**.

This matters for migration authors: if you change a convention and ship no migration for it, the
matching §7.3 check fails, the project stays unstamped, and every skill keeps prompting. That is
the intended behavior — the gap stays visible instead of being certified away. So when you add a
convention change, add both the migration **and** its check.

## Writing a new one

- Start from the closest existing migration; the guard is the part to get right.
- Test the guard against data that is **already migrated** — the no-op path is the one that runs
  most often and the one most likely to be wrong.
- Test it against a **fixture project**, not a real one. Build a throwaway repo holding the old
  data shape, run the migration, and check both the transform and the re-run no-op.
- Include a trap in the fixture: a value that *looks* migratable but isn't — `Priority: High` (a
  field, convert it) next to "High-volume imports" (prose, leave it), or an assumption's
  `Importance: High` (Torres quadrant vocabulary, not a priority). A migration that fails this is
  doing a bare word replace and is not idempotent.
- Add a row to the table in `setup/SKILL.md` §7, and a check to §7.3 if the convention needs one.
