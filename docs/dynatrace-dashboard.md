# A Dynatrace dashboard for the agent

A single screen that shows the agent's self-instrumentation - great for the
demo video. Two ways: build it manually (reliable, ~2 min) or try importing the
JSON in `deploy/dynatrace/agent-dashboard.json`.

Prereqs: the agent has run and emitted data (`TELEMETRY_ENABLED=true`, OTLP
`[ OK ]` in `scripts/check-dynatrace.ps1`); allow ~1-2 min to flush.

## Option A - build it manually (recommended)

1. Open Dashboards:
   `https://wtv74308.apps.dynatrace.com/ui/apps/dynatrace.dashboards`
2. **＋ Create dashboard**.
3. For each tile below: **Add tile** → paste the DQL → pick the visualization →
   set the title. Then arrange/resize.

### Tile 1 — Approval-gate decisions (by outcome)
Visualization: **Bar chart** (or Single value if you split later)
```
timeseries sum(storefront.tool.decisions), by:{decision}
```
Shows allowed vs blocked vs approved - the human-in-the-loop story.

### Tile 2 — Tool activity over time
Visualization: **Line chart**
```
timeseries sum(storefront.tool.decisions), by:{tool}
```

### Tile 3 — Read vs write split
Visualization: **Pie / donut**
```
timeseries sum(storefront.tool.decisions), by:{kind}
```

### Tile 4 — Recent agent spans
Visualization: **Table**
```
fetch spans
| filter service.name == "self-healing-storefront-agent"
| fields start_time, span.name, duration
| sort start_time desc
| limit 25
```

### Tile 5 — Approval gate spans only (the money shot)
Visualization: **Table**
```
fetch spans
| filter service.name == "self-healing-storefront-agent"
| filter span.name == "approval_gate"
| fields start_time, gate.decision = `gate.decision`, tool = `tool.name`
| sort start_time desc
| limit 25
```

Set the dashboard timeframe (top-right) to **Last 2 hours** so your demo runs
are visible. Save.

## Option B - import the JSON (often won't work - prefer Option A)

`deploy/dynatrace/agent-dashboard.json` is a starter, but **Dynatrace's
dashboard document schema changes between releases, so the import frequently
fails validation**. Also note: import it in the **Dashboards** app, not
Notebooks (uploading it to Notebooks gives "not a valid notebook").

If it doesn't load cleanly, don't fight it - use Option A. The per-tile DQL is
identical and always works.

## Demo tip

In the video, after the agent acts, cut to this dashboard. Tile 1 + Tile 5
together tell the whole story: "the agent took an action, a human approved it,
and it's all observable in Dynatrace." See docs/demo-script.md.
