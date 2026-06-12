"""Environment configuration for the Self-Healing Storefront agent.

All secrets and endpoints come from environment variables so the same code
runs locally (via a .env file) and on Cloud Run (via service env vars).
"""

import os

from dotenv import load_dotenv

load_dotenv()


def _get(name: str, default: str | None = None) -> str | None:
    value = os.environ.get(name, default)
    return value


# --- Gemini model -----------------------------------------------------------
# Gemini 3 is the model family required by the hackathon.
GEMINI_MODEL: str = _get("GEMINI_MODEL", "gemini-3-pro-preview") or "gemini-3-pro-preview"

# --- Dynatrace MCP server (observability / read side) -----------------------
# Official server: https://github.com/dynatrace-oss/dynatrace-mcp
# Verify exact env var names against the package version you install.
DT_ENVIRONMENT: str | None = _get("DT_ENVIRONMENT")          # e.g. https://abc12345.apps.dynatrace.com
DT_PLATFORM_TOKEN: str | None = _get("DT_PLATFORM_TOKEN")    # platform token or OAuth client below
DT_OAUTH_CLIENT_ID: str | None = _get("DT_OAUTH_CLIENT_ID")
DT_OAUTH_CLIENT_SECRET: str | None = _get("DT_OAUTH_CLIENT_SECRET")

# --- WordPress / WooCommerce MCP server (action / write side) ---------------
# Automattic remote: https://www.npmjs.com/package/@automattic/mcp-wordpress-remote
WP_API_URL: str | None = _get("WP_API_URL")                  # e.g. https://store.example.com
WP_API_USERNAME: str | None = _get("WP_API_USERNAME")
WP_API_PASSWORD: str | None = _get("WP_API_PASSWORD")        # WordPress application password
WOO_CUSTOMER_KEY: str | None = _get("WOO_CUSTOMER_KEY")
WOO_CUSTOMER_SECRET: str | None = _get("WOO_CUSTOMER_SECRET")

# --- Safety -----------------------------------------------------------------
# When true, write/remediation actions require explicit human approval before
# they run. Keep this on for demos so the agent stays "human in control".
REQUIRE_APPROVAL: bool = _get("REQUIRE_APPROVAL", "true").lower() != "false"

# --- Self-instrumentation (agent -> Dynatrace via OTLP) ---------------------
# Exports the agent's OWN traces/metrics to Dynatrace, so the agent is itself
# observable in the same tenant it reads from. Optional and best-effort.
TELEMETRY_ENABLED: bool = _get("TELEMETRY_ENABLED", "true").lower() != "false"
# Dynatrace OTLP base, e.g. https://abc12345.live.dynatrace.com/api/v2/otlp
DT_OTLP_ENDPOINT: str | None = _get("DT_OTLP_ENDPOINT")
# API token with scopes: openTelemetryTrace.ingest, metrics.ingest
DT_OTLP_TOKEN: str | None = _get("DT_OTLP_TOKEN")
OTEL_SERVICE_NAME: str = _get("OTEL_SERVICE_NAME", "self-healing-storefront-agent") or "self-healing-storefront-agent"
OTEL_SERVICE_VERSION: str = _get("OTEL_SERVICE_VERSION", "0.1.0") or "0.1.0"
