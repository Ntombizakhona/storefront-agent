"""Root agent: Gemini 3 reasoning over Dynatrace + WordPress/WooCommerce MCP.

Built for Google Cloud Agent Builder (ADK). The agent is an MCP *client* that
connects to two partner MCP servers:

  - Dynatrace MCP server  -> observability signals (read)
  - WordPress MCP server  -> store actions (write, behind an approval gate)
"""

import os
import shutil
import sys

from google.adk.agents import LlmAgent
from google.adk.tools import ToolContext
from google.adk.tools.mcp_tool.mcp_toolset import McpToolset, StdioConnectionParams
from mcp import StdioServerParameters

from . import config
from .callbacks import require_human_approval
from .prompts import ROOT_INSTRUCTION
from .telemetry import get_tracer, setup_telemetry

# Export the agent's own traces/metrics to Dynatrace (best-effort; see telemetry.py).
setup_telemetry()

# Resolve the npx executable. On Windows it's 'npx.cmd', and passing bare "npx"
# to a subprocess fails to spawn (the MCP session then errors). shutil.which
# returns the correct full path (incl. .cmd) when Node is installed.
NPX = shutil.which("npx") or ("npx.cmd" if sys.platform == "win32" else "npx")

# Where the WordPress MCP remote writes its own logs (for debugging init).
_WP_MCP_LOG = os.path.join(os.path.dirname(os.path.dirname(__file__)), "wp-mcp-remote.log")


def _clean_env(values: dict[str, str | None]) -> dict[str, str]:
    """Drop unset values so we never pass None into the MCP subprocess env."""
    return {k: v for k, v in values.items() if v}


# --- Dynatrace MCP server (observability / read side) -----------------------
dynatrace_tools = McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command=NPX,
            args=["-y", "@dynatrace-oss/dynatrace-mcp-server"],
            env=_clean_env(
                {
                    "DT_ENVIRONMENT": config.DT_ENVIRONMENT,
                    "DT_PLATFORM_TOKEN": config.DT_PLATFORM_TOKEN,
                    "OAUTH_CLIENT_ID": config.DT_OAUTH_CLIENT_ID,
                    "OAUTH_CLIENT_SECRET": config.DT_OAUTH_CLIENT_SECRET,
                }
            ),
        ),
        timeout=60,
    ),
)

# --- WordPress / WooCommerce MCP server (action / write side) ---------------
wordpress_tools = McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command=NPX,
            args=["-y", "@automattic/mcp-wordpress-remote"],
            env=_clean_env(
                {
                    "WP_API_URL": config.WP_API_URL,
                    "WP_API_USERNAME": config.WP_API_USERNAME,
                    "WP_API_PASSWORD": config.WP_API_PASSWORD,
                    "WOO_CUSTOMER_KEY": config.WOO_CUSTOMER_KEY,
                    "WOO_CUSTOMER_SECRET": config.WOO_CUSTOMER_SECRET,
                    # Force application-password auth (the remote tries OAuth by
                    # default, which fails init against a site without OAuth set up).
                    "OAUTH_ENABLED": "false",
                    # Capture the remote's own logs for debugging init issues.
                    "LOG_FILE": str(_WP_MCP_LOG),
                }
            ),
        ),
        timeout=60,
    ),
)


def approve_pending_changes(tool_context: ToolContext) -> dict:
    """Record the operator's explicit approval for the pending write action.

    Call this only after the human has clearly confirmed they want the change.
    The next write tool call will be allowed exactly once.
    """
    pending = tool_context.state.get("pending_action")
    if not pending:
        return {"status": "no_pending_action", "message": "Nothing is awaiting approval."}
    with get_tracer().start_as_current_span("approve_pending_changes") as span:
        span.set_attribute("approved.tool", pending["tool"])
        tool_context.state["human_approved"] = True
        return {
            "status": "approved",
            "message": f"Approved. You may now retry: {pending['tool']}.",
            "approved_action": pending,
        }


root_agent = LlmAgent(
    model=config.GEMINI_MODEL,
    name="self_healing_storefront",
    description=(
        "Observability-first agent that diagnoses store issues from Dynatrace "
        "and takes approved remediation actions on WordPress/WooCommerce."
    ),
    instruction=ROOT_INSTRUCTION,
    tools=[dynatrace_tools, wordpress_tools, approve_pending_changes],
    before_tool_callback=require_human_approval,
)
