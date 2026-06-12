"""Self-Healing Storefront agent package.

ADK discovers the agent via `root_agent`, exported here so tools like
`adk web` and `adk run storefront_agent` can find it.
"""

from . import agent
from .agent import root_agent

__all__ = ["agent", "root_agent"]
