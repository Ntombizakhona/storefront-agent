#!/usr/bin/env bash
# Preflight: is a WooCommerce store ready for the agent? macOS/Linux.
#
# Usage:
#   ./scripts/check-store.sh https://observability-first.nkulemabaso.com
#
# Checks: (1) strict HTTPS cert valid for the host, (2) wp-json reachable,
# (3) WooCommerce + Abilities API namespaces present.
set -uo pipefail

URL="${1:?Usage: check-store.sh <store-url>}"
BASE="${URL%/}"
PASS=1

ok()   { printf '[ OK ] %s\n' "$1"; }
bad()  { printf '[FAIL] %s\n' "$1"; PASS=0; }
info() { printf '       %s\n' "$1"; }

# 1) Strict HTTPS (curl validates the cert; --fail surfaces HTTP errors).
if curl -fsS -o /dev/null --max-time 30 "$BASE/wp-json/"; then
  ok "Valid HTTPS + wp-json reachable"
else
  bad "HTTPS/cert or wp-json problem reaching $BASE/wp-json/"
  info "If it's a cert mismatch, issue/AutoSSL a cert covering the subdomain."
fi

# 2+3) Namespaces (-k so we still report even on an invalid cert).
body="$(curl -fsS -k --max-time 30 "$BASE/wp-json/" 2>/dev/null || true)"
if [ -n "$body" ]; then
  if printf '%s' "$body" | grep -q '"wc/v3"\|"wc/store"'; then
    ok "WooCommerce REST present (wc/*)"
  else
    bad "WooCommerce REST namespaces (wc/v3, wc/store) not found"
  fi
  if printf '%s' "$body" | grep -q '"wp-abilities/v1"'; then
    ok "Abilities API present (wp-abilities/v1)"
  else
    bad "Abilities API (wp-abilities/v1) not found - update WordPress/WooCommerce"
  fi
else
  bad "Could not read wp-json body"
fi

echo
if [ "$PASS" -eq 1 ]; then
  echo "Store looks agent-ready. Set WP_API_URL=$BASE in .env, add credentials, then 'adk web'."
  exit 0
else
  echo "Store not ready yet - fix the FAIL items above."
  exit 1
fi
