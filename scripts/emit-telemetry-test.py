"""Emit one test span + metric to Dynatrace and force-flush, to confirm ingest.

Run from the project root:  python scripts/emit-telemetry-test.py
Then query Dynatrace (last 15 min):
  fetch spans | filter service.name == "self-healing-storefront-agent"
"""

import time

from storefront_agent import telemetry

active = telemetry.setup_telemetry()
print("telemetry active:", active)
if not active:
    raise SystemExit("Telemetry not active - check DT_OTLP_* and TELEMETRY_ENABLED.")

tracer = telemetry.get_tracer()
with tracer.start_as_current_span("telemetry_preflight") as span:
    span.set_attribute("gate.decision", "approved")
    span.set_attribute("tool.name", "preflight_check")
    time.sleep(0.2)

telemetry.record_tool_decision("preflight_check", "write", "approved")

# Force the batch exporters to flush before the process exits.
from opentelemetry import metrics, trace

trace.get_tracer_provider().force_flush()
metrics.get_meter_provider().force_flush()
print("Flushed. Look for span 'telemetry_preflight' in Dynatrace within ~1 min.")
