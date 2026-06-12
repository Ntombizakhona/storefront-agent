# Finding your Dynatrace values

The agent uses Dynatrace two ways, each needing different values:

| `.env` var | Used by | Host style |
|---|---|---|
| `DT_ENVIRONMENT` | Dynatrace MCP server (read) | `https://<env-id>.apps.dynatrace.com` |
| `DT_PLATFORM_TOKEN` | Dynatrace MCP server (read) | platform token |
| `DT_OTLP_ENDPOINT` | self-instrumentation (write/export) | `https://<env-id>.live.dynatrace.com/api/v2/otlp` |
| `DT_OTLP_TOKEN` | self-instrumentation (write/export) | access token (`dt0c01...`) |

> Gotcha: MCP wants the **`.apps`** URL; OTLP ingest wants the **`.live`** URL.
> Same environment ID, different subdomain.

## 0. No tenant yet?

Start a free trial at dynatrace.com. After signup you land on a URL like
`https://abc12345.apps.dynatrace.com` - `abc12345` is your **environment ID**.

## 1. DT_ENVIRONMENT (MCP read)

Your platform URL, exactly as in the browser address bar when logged in:

```
DT_ENVIRONMENT=https://abc12345.apps.dynatrace.com
```

Use the `.apps` URL, not the classic `.live` one (the MCP server rejects
classic URLs).

## 2. DT_PLATFORM_TOKEN (MCP read)

The Dynatrace MCP server authenticates with a **Platform Token**.

1. In Dynatrace, open the profile menu → **My Platform Tokens**
   (or search "Platform Tokens" in the platform).
2. **Create token** → give it a name + expiry.
3. Add the scopes the MCP server requires. The exact list is on the server's
   setup page - copy the current scopes from there rather than guessing, since
   they change between versions:
   - Dynatrace Hub: "Local MCP Server", or
   - the GitHub readme: https://github.com/dynatrace-oss/dynatrace-mcp
   They cover reading Grail data (logs/metrics/spans/events), problems, and
   running DQL (e.g. `storage:*:read`, `environment-api:*`, app-engine run
   scopes). Use the page's copy-paste list.
4. Copy the token value into `.env`:

```
DT_PLATFORM_TOKEN=dt0s16....
```

> Alternative for local dev: the MCP server also supports browser-based OAuth
> (Authorization Code Flow) where you don't predefine a token. A Platform Token
> is simpler for headless/Cloud Run runs, so we use it here.

## 3. DT_OTLP_ENDPOINT (self-instrumentation)

Where the agent ships its own traces/metrics. Built from your environment ID on
the **`.live`** host:

```
DT_OTLP_ENDPOINT=https://abc12345.live.dynatrace.com/api/v2/otlp
```

(The code appends `/v1/traces` and `/v1/metrics`.) If your tenant documents a
different OTLP base under Settings → OpenTelemetry / "Export to Dynatrace", use
that.

## 4. DT_OTLP_TOKEN (self-instrumentation)

A Dynatrace **Access Token** (different from the platform token; starts with
`dt0c01.`). This lives in a *different* place than Platform Tokens.

1. Easiest: use the **search bar** at the top of Dynatrace, type
   **`Access Tokens`**, open that app. (Direct deep link for env `wtv74308`:
   `https://wtv74308.apps.dynatrace.com/ui/apps/dynatrace.classic.tokens` -
   if the path differs in your build, search always works.)
2. **Generate new token** → name it `storefront-agent-otlp`.
3. Required scopes (search + tick each):
   - `openTelemetryTrace.ingest` (traces)
   - `metrics.ingest` (metrics)
   - `logs.ingest` (only if you later export logs)
4. **Generate** and copy the value:

```
DT_OTLP_TOKEN=dt0c01....
```

> Can't find those scopes when creating the token? Your user may not have
> permission to grant them - an admin would need to. This token only powers
> self-instrumentation; set `TELEMETRY_ENABLED=false` to run/demo without it.

## 5. Verify

After filling `.env`:

```
pip install -e ".[telemetry]"
adk web
```

- MCP read works if the agent can answer "check Dynatrace for open problems".
- Self-instrumentation works if, after a few interactions, spans named
  `approval_gate` / `approve_pending_changes` and the metric
  `storefront.tool.decisions` show up in Dynatrace (distributed traces /
  metrics). Allow a minute for the batch exporter to flush.

## Security

- Both tokens are secrets - they live only in `.env` (git-ignored).
- Scope tokens to the minimum needed and set an expiry.
- Revoke from the same screens if a token leaks.
