"""Self-instrumentation: export the agent's own traces + metrics to Dynatrace.

This closes the "observability-first" loop. The agent doesn't just *read* from
Dynatrace - it also *reports* its own behavior (tool calls, the approval gate,
remediation outcomes) back into the same Dynatrace tenant via OTLP/HTTP.

Setup is best-effort and fully optional:
  - If the OpenTelemetry libraries aren't installed, or the Dynatrace OTLP
    endpoint/token aren't configured, telemetry is silently skipped and the
    agent runs normally.
  - Once a global TracerProvider is set, Google ADK's built-in OpenTelemetry
    instrumentation also exports agent/tool spans to Dynatrace automatically.

Dynatrace OTLP ingest:
  endpoint: https://<env-id>.live.dynatrace.com/api/v2/otlp
  header:   Authorization: Api-Token dt0c01....
  token scopes: openTelemetryTrace.ingest, metrics.ingest
"""

import logging

from . import config

logger = logging.getLogger(__name__)

_initialized = False
_tool_decision_counter = None  # lazily created metric instrument


def setup_telemetry() -> bool:
    """Configure OTLP export to Dynatrace. Returns True if telemetry is active."""
    global _initialized, _tool_decision_counter
    if _initialized:
        return True

    if not config.TELEMETRY_ENABLED:
        logger.info("Self-instrumentation disabled (TELEMETRY_ENABLED=false).")
        return False

    if not (config.DT_OTLP_ENDPOINT and config.DT_OTLP_TOKEN):
        logger.info(
            "Self-instrumentation skipped: set DT_OTLP_ENDPOINT and DT_OTLP_TOKEN "
            "to export the agent's traces/metrics to Dynatrace."
        )
        return False

    try:
        from opentelemetry import metrics, trace
        from opentelemetry.exporter.otlp.proto.http.metric_exporter import (
            OTLPMetricExporter,
        )
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import (
            OTLPSpanExporter,
        )
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
    except ImportError:
        logger.warning(
            "OpenTelemetry libraries not installed; self-instrumentation off. "
            "Install with: pip install '.[telemetry]'"
        )
        return False

    endpoint = config.DT_OTLP_ENDPOINT.rstrip("/")
    headers = {"Authorization": f"Api-Token {config.DT_OTLP_TOKEN}"}
    resource = Resource.create(
        {
            "service.name": config.OTEL_SERVICE_NAME,
            "service.version": config.OTEL_SERVICE_VERSION,
        }
    )

    # Traces -> Dynatrace
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint=f"{endpoint}/v1/traces", headers=headers)
        )
    )
    trace.set_tracer_provider(tracer_provider)

    # Metrics -> Dynatrace
    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=f"{endpoint}/v1/metrics", headers=headers)
    )
    metrics.set_meter_provider(
        MeterProvider(resource=resource, metric_readers=[metric_reader])
    )

    meter = metrics.get_meter("storefront_agent")
    _tool_decision_counter = meter.create_counter(
        name="storefront.tool.decisions",
        description="Agent tool invocations by kind and approval-gate decision.",
        unit="1",
    )

    _initialized = True
    logger.info("Self-instrumentation active -> exporting to Dynatrace at %s", endpoint)
    return True


def get_tracer():
    """Return an OTel tracer (a no-op tracer if telemetry isn't active)."""
    try:
        from opentelemetry import trace

        return trace.get_tracer("storefront_agent")
    except ImportError:
        return _NoopTracer()


def record_tool_decision(tool_name: str, kind: str, decision: str) -> None:
    """Emit a metric data point for an approval-gate decision.

    kind:     "read" | "write"
    decision: "allowed" | "blocked" | "approved"
    """
    if _tool_decision_counter is None:
        return
    try:
        _tool_decision_counter.add(
            1, {"tool": tool_name, "kind": kind, "decision": decision}
        )
    except Exception:  # never let telemetry break the agent
        logger.debug("Failed to record tool decision metric", exc_info=True)


class _NoopSpan:
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def set_attribute(self, *_args, **_kwargs):
        pass


class _NoopTracer:
    def start_as_current_span(self, *_args, **_kwargs):
        return _NoopSpan()
