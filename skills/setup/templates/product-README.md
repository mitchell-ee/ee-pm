# product/

Your PM artifacts live here. This is an empty scaffold — the skills create and read files under this tree.

```
product/
├── personas/       one file per persona, keyed by slug
├── assumptions/    assumption-NNNN-{slug}.md — tested against a solution
├── opportunity-solution-tree/
│   ├── outcomes/       outcome-NNNN-{slug}.md
│   ├── opportunities/  opportunity-NNNN-{slug}.md
│   └── solutions/      solution-NNNN-{slug}.md
├── assumption-maps/    SOL-NNNN-{slug}/miro-metadata.json
├── screens/        baseline specs for screens that already exist
├── backlog.md      the story queue — this repo IS the record of work
├── design-principles.md
├── glossary.md
├── product-strategy.md
├── product-as-built.md
└── iterations/     per-iteration work, one folder per iteration
    └── YYYY-MM-DD-{iteration-slug}/
        ├── interviews/
        ├── synthesis.md
        ├── stories/
        ├── story-maps/
        ├── prototypes/
        └── decisions.md
```

**Durable context sits directly under `product/`**; only per-iteration work is nested. (Through
0.5.x there was an extra `product/context/` layer — 0.6.0 removed it. `/ee-pm:setup` detects the
old layout and offers to migrate.)

Not every file above is required — create what your practice actually produces. Run
`/ee-pm:framework-setup` once to establish durable context, then `/ee-pm:iteration-setup` per
iteration to scaffold an iteration folder. Each Miro artifact keeps a `miro-metadata.json` sidecar
next to it, recording the board ID and the shape/connector IDs the absorb pass diffs against.
