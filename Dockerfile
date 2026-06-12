# Cloud Run container for the Self-Healing Storefront agent.
# Node is required because the MCP servers (Dynatrace, WordPress) run via `npx`.
FROM python:3.12-slim

# Install Node.js (for npx-based MCP servers).
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the package source BEFORE installing so the build backend can build it.
COPY pyproject.toml README.md LICENSE ./
COPY storefront_agent ./storefront_agent
RUN pip install --no-cache-dir ".[deploy,telemetry]"

ENV PORT=8080
# npx/npm must write to a writable path on Cloud Run's ephemeral FS.
ENV npm_config_cache=/tmp/.npm
EXPOSE 8080

# Serve the interactive ADK web UI (chat + trace view) on Cloud Run's port.
# `adk web` discovers the `storefront_agent` package in the working dir.
CMD ["sh", "-c", "adk web --host 0.0.0.0 --port ${PORT}"]
