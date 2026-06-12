"""Human-in-the-loop safety gate.

Read actions (querying Dynatrace, listing products/orders) run freely.
Write/remediation actions (publishing posts, toggling plugins, changing
coupons or inventory) are intercepted and blocked until a human approves.

This keeps the operator "in control", which is an explicit hackathon goal.
"""

from typing import Any, Optional

from google.adk.tools import BaseTool, ToolContext

from . import config, telemetry

# Tool-name fragments that indicate a state-changing action on the store.
# Tune this list to match the actual tool names exposed by your MCP servers.
WRITE_KEYWORDS = (
    "create",
    "update",
    "delete",
    "publish",
    "post",
    "edit",
    "set",
    "toggle",
    "enable",
    "disable",
    "activate",
    "deactivate",
    "install",
    "coupon",
    "order",
    "inventory",
    "stock",
)


def is_write_tool(tool_name: str) -> bool:
    name = tool_name.lower()
    return any(keyword in name for keyword in WRITE_KEYWORDS)


def require_human_approval(
    tool: BaseTool,
    args: dict[str, Any],
    tool_context: ToolContext,
) -> Optional[dict]:
    """ADK before_tool_callback.

    Returning a dict short-circuits the tool call and feeds that dict back to
    the model as the tool result. We use that to demand explicit approval.
    """
    if not config.REQUIRE_APPROVAL:
        return None

    kind = "write" if is_write_tool(tool.name) else "read"
    tracer = telemetry.get_tracer()

    with tracer.start_as_current_span("approval_gate") as span:
        span.set_attribute("tool.name", tool.name)
        span.set_attribute("tool.kind", kind)

        if kind == "read":
            telemetry.record_tool_decision(tool.name, kind, "allowed")
            span.set_attribute("gate.decision", "allowed")
            return None  # read-only: allow

        if tool_context.state.get("human_approved") is True:
            # One-shot approval: consume it so the next write needs fresh consent.
            tool_context.state["human_approved"] = False
            telemetry.record_tool_decision(tool.name, kind, "approved")
            span.set_attribute("gate.decision", "approved")
            return None

        # Block and ask the human to confirm.
        tool_context.state["pending_action"] = {"tool": tool.name, "args": args}
        telemetry.record_tool_decision(tool.name, kind, "blocked")
        span.set_attribute("gate.decision", "blocked")
        return {
            "status": "approval_required",
            "message": (
                f"This is a write action ('{tool.name}') that will change the live "
                f"store. Args: {args}. Tell the user exactly what will change and ask "
                f"them to confirm. Once they approve, call 'approve_pending_changes' "
                f"and then retry this action."
            ),
        }
