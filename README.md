# Self-Healing Storefront Agent

An **observability-first** AI agent that keeps an online store healthy. It reads
live signals from **Dynatrace**, reasons about root cause with **Gemini 3**, and
takes **approved** remediation actions on a **WordPress/WooCommerce** store —
forming a closed `observe → diagnose → decide → act → verify` loop.

Built with **Google Cloud Agent Builder (ADK)** and integrating **partner MCP
servers** to give the agent its "superpowers".

## Why this is more than a chatbot

- **Uses tools to do work**: queries Dynatrace, then writes changes to WordPress
  (publish a high-demand notice, pause a runaway promo, disable a failing
  plugin, open a status post).
- **Multi-step missions**: it plans across the full incident-response loop.
- **You stay in control**: every write action is blocked behind an explicit
  human approval gate.

## Architecture

See [docs/architecture.md](docs/architecture.md). In short: the ADK agent is an
MCP *client* connected to the Dynatrace MCP server (read) and the
WordPress/WooCommerce MCP server (write).

The agent also exports its own traces/metrics back to Dynatrace
(self-instrumentation) - see [docs/observability.md](docs/observability.md) for
what's emitted and how to view it, and
[docs/dynatrace-dashboard.md](docs/dynatrace-dashboard.md) to build a dashboard. It's **observability-first in both
directions**. It also exports its own traces/metrics back to Dynatrace via
OpenTelemetry (see [docs/observability.md](docs/observability.md)).

## Prerequisites

- Python 3.10+
- Node.js 20+ (the MCP servers run via `npx`)
- A Dynatrace tenant with API access (see [docs/dynatrace-setup.md](docs/dynatrace-setup.md)
  for finding your environment URL and tokens)
- A WordPress site (with WooCommerce) and an application password
- A Google Cloud project (Vertex AI) or a Google AI Studio API key

## Getting a WooCommerce store

The agent needs a reachable store to act on. Pick whichever fits:

- **Managed/hosted WordPress** (fastest, gives a public URL for submission):
  see [docs/hosted-store.md](docs/hosted-store.md).
- **Amazon Lightsail** (one-click WordPress blueprint with easy HTTPS):
  see [docs/deploy-store-lightsail.md](docs/deploy-store-lightsail.md).
- **Self-hosted on a GCE VM** (runs the bundled compose stack in the cloud):
  see [docs/deploy-store-gce.md](docs/deploy-store-gce.md).
- **Local Docker** (needs a machine with normal disk I/O):
  see [docs/woocommerce-setup.md](docs/woocommerce-setup.md).

## Setup

```bash
pip install -e .
cp .env.example .env   # then fill in your values
```

Optional — export the agent's own traces/metrics to Dynatrace:

```bash
pip install -e ".[telemetry]"   # then set DT_OTLP_* in .env
```

Run locally with the ADK dev UI:

```bash
adk web
```

Or a terminal session:

```bash
adk run storefront_agent
```

> Note: MCP package names and env var names evolve. If `npx` can't find a
> server or auth fails, confirm the current package name / variables for the
> [Dynatrace MCP server](https://github.com/dynatrace-oss/dynatrace-mcp) and the
> [Automattic WordPress MCP](https://www.npmjs.com/package/@automattic/mcp-wordpress-remote),
> then adjust `storefront_agent/agent.py` and `.env`.

## Deploy to Cloud Run

Deploys the agent (interactive `adk web` UI). Full step-by-step, including the
env-vars file and security/teardown notes:
**[docs/deploy-cloudrun.md](docs/deploy-cloudrun.md)**.

Quick version:

```bash
gcloud run deploy storefront-agent \
  --source . \
  --region africa-south1 \
  --allow-unauthenticated \
  --env-vars-file env.yaml \
  --memory 2Gi --cpu 2 --timeout 3600 --max-instances 1
```

The root `Dockerfile` bundles Node so the MCP servers run inside the service.

> Security note: `--allow-unauthenticated` makes the agent publicly drivable
> and it holds your tokens + store write access. Treat it as disposable, use a
> throwaway store, and delete the service after judging.

## License

MIT — see [LICENSE](LICENSE).
