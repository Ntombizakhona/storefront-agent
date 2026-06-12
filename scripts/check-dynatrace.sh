#!/usr/bin/env bash
# Preflight: are the Dynatrace tokens valid before you run the agent? macOS/Linux.
#
# Usage:
#   ./scripts/check-dynatrace.sh            # reads .env
#   ./scripts/check-dynatrace.sh path/to/.env
#
# Checks:
#   1) OTLP token  -> empty protobuf probe to DT_OTLP_ENDPOINT/v1/metrics (auth)
#   2) Platform token -> trivial DQL query against DT_ENVIRONMENT (best-effort)
set -uo pipefail

ENV_FILE="${1:-.env}"
PASS=1

ok()   { printf '[ OK ] %s\n' "$1"; }
bad()  { printf '[FAIL] %s\n' "$1"; PASS=0; }
warn() { printf '[WARN] %s\n' "$1"; }
info() { printf '       %s\n' "$1"; }

[ -f "$ENV_FILE" ] || { echo "Env file not found: $ENV_FILE"; exit 1; }

# Read a KEY=VALUE from the env file (first match), trimmed.
getval() { grep -E "^$1=" "$ENV_FILE" | head -n1 | sed -E "s/^$1=//" | tr -d '[:space:]'; }

OTLP_ENDPOINT="$(getval DT_OTLP_ENDPOINT)"
OTLP_TOKEN="$(getval DT_OTLP_TOKEN)"
DT_ENV="$(getval DT_ENVIRONMENT)"
PLAT_TOKEN="$(getval DT_PLATFORM_TOKEN)"

# --- 1) OTLP token: empty protobuf probe (reaches the auth layer) -----------
if [ -z "$OTLP_ENDPOINT" ] || [ -z "$OTLP_TOKEN" ]; then
  warn "DT_OTLP_ENDPOINT / DT_OTLP_TOKEN not set - skipping OTLP check."
else
  uri="${OTLP_ENDPOINT%/}/v1/metrics"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 \
    -X POST "$uri" \
    -H "Authorization: Api-Token $OTLP_TOKEN" \
    -H "Content-Type: application/x-protobuf" \
    --data-binary '' || echo 000)"
  case "$code" in
    401|403)
      bad "OTLP token rejected (HTTP $code)."
      info "Use an Access Token (dt0c01...) with scopes openTelemetryTrace.ingest + metrics.ingest -"
      info "NOT a Platform Token (dt0s16...). Create at: Dynatrace > Access Tokens." ;;
    200|202|204|400) ok "OTLP token accepted (HTTP $code)." ;;
    000) bad "OTLP request failed (network/endpoint). Check DT_OTLP_ENDPOINT ($uri)." ;;
    *)   warn "OTLP endpoint returned HTTP $code; token likely OK. Verify DT_OTLP_ENDPOINT ($uri)." ;;
  esac
fi

# --- 2) Platform token: trivial DQL query (best-effort) ---------------------
if [ -z "$DT_ENV" ] || [ -z "$PLAT_TOKEN" ]; then
  warn "DT_ENVIRONMENT / DT_PLATFORM_TOKEN not set - skipping platform-token check."
else
  uri="${DT_ENV%/}/platform/storage/query/v1/query:execute"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 \
    -X POST "$uri" \
    -H "Authorization: Bearer $PLAT_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"query":"fetch logs | limit 1"}' || echo 000)"
  case "$code" in
    401|403) bad "Platform token rejected (HTTP $code) - check token + MCP scopes (docs/dynatrace-setup.md)." ;;
    200|202) ok "Platform token accepted (HTTP $code) - DQL query executed." ;;
    000) bad "Platform request failed (network/endpoint). Check DT_ENVIRONMENT ($uri)." ;;
    *)   warn "Platform API returned HTTP $code (token authenticated). Endpoint may differ by tenant; the MCP server is the real test." ;;
  esac
fi

echo
if [ "$PASS" -eq 1 ]; then echo "Dynatrace preflight passed."; exit 0
else echo "Dynatrace preflight had failures - fix the FAIL items above."; exit 1; fi
