# Timing Log Format

Single source of truth for PM activity timing: `product/metrics/timing-log.jsonl`

## Purpose

Track generation times for PM artifacts to:
- Compare AI vs human productivity
- Identify which tasks benefit most from AI assistance
- Track productivity improvements over time

## File Format

JSONL (JSON Lines) - one JSON object per line, append-only.

## Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | ISO8601 string | Yes | When operation completed |
| `command` | string | Yes | Skill or command name (e.g., "/synth", "/req") |
| `iteration` | string | Yes | Iteration name (e.g., "2025-12-02-admin-page") |
| `start` | ISO8601 string | No | When operation started |
| `end` | ISO8601 string | No | When operation ended |
| `duration_seconds` | number | Yes | Wall clock time for full operation |
| `generation_seconds` | number | Yes | AI generation time (may equal duration) |
| `status` | string | Yes | "success" or "error" |
| `metadata` | object | Yes | Skill-specific additional data |

## Example Entry

```json
{
  "timestamp": "2025-12-10T14:30:00Z",
  "command": "/synth",
  "iteration": "2025-12-02-admin-page",
  "start": "2025-12-10T14:27:00Z",
  "end": "2025-12-10T14:30:00Z",
  "duration_seconds": 180,
  "generation_seconds": 180,
  "status": "success",
  "metadata": {
    "themes_identified": 4,
    "pain_points": 6,
    "source": "skill"
  }
}
```

## Metadata by Command

| Command | Typical Metadata Fields |
|---------|------------------------|
| `/synth` | `themes_identified`, `pain_points` |
| `/req` | `stories_created`, `story_ids`, `template`, `granularity`, `story_generation_times` |
| `/map` | `board_id`, `board_url`, `total_items_created`, `story_cards` |
| `/rel` | `stories_released`, `story_ids` |
| `/iter` | `interview_conducted` |
| `/jira` | `tickets_created` |

## Usage

### Appending Entries

Use the `append-timing.sh` script:

```bash
./scripts/append-timing.sh "/synth" "2025-12-02-admin-page" 180 '{"themes_identified": 4}'
```

### Reading Entries

```bash
# All entries
cat product/metrics/timing-log.jsonl

# Filter by command
grep '"/synth"' product/metrics/timing-log.jsonl

# Parse with jq
cat product/metrics/timing-log.jsonl | jq -s 'map(select(.command == "/synth"))'
```

## Notes

- `generation_seconds` equals `duration_seconds` for most PM tasks since they're primarily AI generation
- For `/iter`, use `setup_seconds` to distinguish iteration setup time from ongoing work
- Entries with `status: "error"` should include error details in metadata
- The `source` field in metadata can indicate "skill" vs "slash_command" vs "direct_request"
