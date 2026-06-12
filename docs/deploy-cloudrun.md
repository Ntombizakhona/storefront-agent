# Deploy the agent to Cloud Run

Deploys the **ADK agent** (interactive `adk web` UI). The MCP servers run inside
the container via `npx`; the store and Dynatrace stay where they are. This URL
is your hosted submission link.

## Prerequisites (one time)

```bash
gcloud auth login
gcloud config set project observabilityfirst        # your GCP project id
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

> Note: the project (`observabilityfirst`) needs **billing enabled**. The
> AI Studio API key in `.env` is used for the model, so you do NOT need Vertex.

## 1. Put your config in an env-vars file (NOT committed)

Create `env.yaml` in the repo root with your real values (same as `.env`, minus
the Vertex-only lines). Quote every value:

```yaml
GEMINI_MODEL: "gemini-flash-latest"
GOOGLE_GENAI_USE_VERTEXAI: "FALSE"
GOOGLE_API_KEY: "AQ.your-key"
DT_ENVIRONMENT: "https://wtv74308.apps.dynatrace.com"
DT_PLATFORM_TOKEN: "dt0s16...."
DT_OTLP_ENDPOINT: "https://wtv74308.live.dynatrace.com/api/v2/otlp"
DT_OTLP_TOKEN: "dt0c01...."
OTEL_SERVICE_NAME: "self-healing-storefront-agent"
OTEL_SERVICE_VERSION: "0.1.0"
WP_API_URL: "https://observability-first.nkulemabaso.com"
WP_API_USERNAME: "nkulemabaso"
WP_API_PASSWORD: "your-application-password"
WOO_CUSTOMER_KEY: "ck_...."
WOO_CUSTOMER_SECRET: "cs_...."
REQUIRE_APPROVAL: "true"
TELEMETRY_ENABLED: "true"
```

Then keep it out of git:

```bash
echo "env.yaml" >> .gitignore
```

## 2. Deploy

```bash
gcloud run deploy storefront-agent \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --env-vars-file env.yaml \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 1
```

- `--source .` builds the root `Dockerfile` via Cloud Build (first run also
  creates an Artifact Registry repo).
- `--memory 2Gi` / `--cpu 2`: headroom for Python + Node + two MCP subprocesses.
- `--timeout 3600`: agent turns stream (SSE); allow long requests.
- `--max-instances 1`: keeps in-memory sessions on one instance for the demo.

When it finishes, gcloud prints the **Service URL** - that's your hosted link.
Open it; the ADK chat UI loads and you pick `storefront_agent`.

## 3. First request is slow

On the first tool call the container runs `npx` to fetch the Dynatrace and
WordPress MCP servers - give it a minute. Subsequent calls are fast.

## Security (read before sharing the URL)

- `--allow-unauthenticated` makes the agent **publicly drivable** - anyone with
  the URL can prompt it, and it holds your Dynatrace tokens + store write access
  (behind the approval gate, but still). Treat it as disposable.
- Use the throwaway store; keep tokens scoped/short-lived.
- Harden later with Secret Manager (`--set-secrets`) instead of plain env vars,
  and put the service behind IAP/auth.

## Tear down after judging

```bash
gcloud run services delete storefront-agent --region us-central1
```

## Troubleshooting

- Build fails on the package build: ensure `README.md` and `LICENSE` exist at
  the root (the Dockerfile copies them; `pyproject.toml` references them).
- Container won't start: check it listens on `$PORT` (the CMD uses
  `--host 0.0.0.0 --port ${PORT}`).
- Model 429: Pro is free-tier limited - keep `GEMINI_MODEL=gemini-flash-latest`
  or enable billing/Vertex.
- MCP errors in logs: `gcloud run services logs read storefront-agent
  --region us-central1` - same fixes as local (npx, WordPress MCP plugin,
  `OAUTH_ENABLED=false` which is already set in code).
