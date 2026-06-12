# Architecture

The Self-Healing Storefront agent is a Gemini 3 reasoning layer (built with
Google Cloud Agent Builder / ADK) that acts as an MCP client to two partner
MCP servers.

```
   ┌──────────────────── Gemini 3 + ADK agent ─────────────────────┐
   │   observe → diagnose → decide → act → verify                   │
   │   (human approval gate before any write)                       │
   └──┬──────────────┬───────────────────────────────┬─────────────┘
      │ read         │ self-instrument (OTLP)         │ write (approved)
      ▼              ▼                                 ▼
┌──────────────┐  ┌──────────────────────┐  ┌────────────────────────────┐
│  Dynatrace   │  │  Dynatrace (same      │  │ WordPress / WooCommerce MCP │
│  MCP server  │  │  tenant): agent's own │  │ posts, banners, coupons,    │
│  problems,   │  │  traces + metrics     │  │ inventory, plugin state     │
│  traces,...  │  └──────────────────────┘  └────────────────────────────┘
└──────────────┘
```

The agent is observability-first in **both** directions: it reads store health
from Dynatrace, and exports its *own* traces/metrics back to the same Dynatrace
tenant (see [observability.md](observability.md)).

## The loop

1. **Observe:** pull live signals from Dynatrace (open problems, error rates,
   latency, traffic surges, affected services).
2. **Diagnose:** Gemini 3 explains the most likely root cause, citing evidence.
3. **Decide:** propose the smallest safe, reversible action.
4. **Act:** execute via WordPress/WooCommerce MCP, but only after explicit
   human approval (`approve_pending_changes`).
5. **Verify:** re-check Dynatrace to confirm the signal is recovering.

## Human-in-the-loop

`storefront_agent/callbacks.py` intercepts every tool call. Read tools pass
through. Write tools are blocked and return an `approval_required` result until
the operator confirms and the agent calls `approve_pending_changes`. Approval
is one-shot, so each change is consented to individually.

## Dynatrace & WooCommerce

 This design uses
Dynatrace as the observability "senses" and WordPress/WooCommerce as the
"hands", forming a closed observe→act loop.