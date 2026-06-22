# product/

Your PM artifacts live here. This is an empty scaffold — the skills create and read files under this tree.

```
product/
├── context/        durable, cross-iteration artifacts
│                   (personas, backlog, opportunity-solution-tree, assumption-maps)
└── iterations/     per-iteration work, one folder per iteration
    └── YYYY-MM-DD-{iteration-slug}/
        ├── interviews/
        ├── synthesis.md
        ├── stories/
        ├── story-maps/
        ├── prototypes/
        └── decisions.md
```

Run `/vcw:framework-setup` once to establish `context/`, then `/vcw:iteration-setup` per iteration to scaffold an iteration folder. Each Miro artifact keeps a `miro-metadata.json` sidecar next to it, recording the board ID and the shape/connector IDs the absorb pass diffs against.
