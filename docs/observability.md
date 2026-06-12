# Viewing the agent in Dynatrace (self-instrumentation)

The agent exports its *own* traces and metrics to Dynatrace via OTLP (see
`storefront_agent/telemetry.py`). This is the "observability-first" loop: the
agent reads from Dynatrace **and** is observable in the same tenant.

Service name (set via `OTEL_SERVICE_NAME`): **`self-healing-storefront-agent`**.

## Prerequisites

- `DT_OTLP_ENDPOINT` + `DT_OTLP_TOKEN` set, and `TELEMETRY_ENABLED=true`
  (verify with `scripts/check-dynatrace.ps1`).
- You've sent a few messages in the ADK UI, so spans/metrics exist.
- Allow ~1-2 minutes for the batch exporter to flush before data appears.

## What's emitted

Traces (spans):
- ADK's built-in spans for the agent invocation and each tool call
  (including the Dynatrace and WooCommerce MCP tool calls).
- Custom spans from this project:
  - `approval_gate` - attributes `tool.name`, `tool.kind` (read/write),
    `gate.decision` (allowed/blocked/approved).
  - `approve_pending_changes` - attribute `approved.tool`.

Metrics:
- `storefront.tool.decisions` (counter) with dimensions `tool`, `kind`,
  `decision`.

## View traces

Dynatrace platform (`https://<env-id>.apps.dynatrace.com`):
1. Top search bar -> **Distributed Tracing** (or **Services**).
2. Find service **`self-healing-storefront-agent`** and open a recent trace.
3. Expand spans to see the agent run, tool calls, and the `approval_gate` /
   `approve_pending_changes` spans.

DQL (in a **Notebook**):

```
fetch spans
| filter service.name == "self-healing-storefront-agent"
| sort start_time desc
| limit 100
```

## View the metric

1. Search bar -> **Metrics** (or **Data Explorer**).
2. Search **`storefront.tool.decisions`**; split by `decision`, `kind`, `tool`.

DQL (Notebook):

```
timeseries sum(storefront.tool.decisions), by:{decision, kind, tool}
```


## Troubleshooting

- Nothing appears: re-run `scripts/check-dynatrace.ps1` (OTLP must be `[ OK ]`),
  confirm `TELEMETRY_ENABLED=true`, and that you actually triggered tool calls.
- Wait longer: the SDK batches; spans can take a minute or two.
- Wrong host: OTLP uses the **`.live`** endpoint, not `.apps` (see
  docs/dynatrace-setup.md).
