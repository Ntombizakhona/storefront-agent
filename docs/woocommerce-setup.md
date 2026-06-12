# Local WooCommerce setup

A local WordPress + WooCommerce site for the agent to act on, using the
official [`@wordpress/env`](https://developer.wordpress.org/block-editor/reference-guides/packages/packages-env/)
(Docker-based).

## Prerequisites

- Docker Desktop running
- Node.js 20+

## Start the site

From the project root (the `.wp-env.json` here installs WooCommerce):

```bash
npx @wordpress/env start
```

First run pulls images and can take several minutes. When it finishes:

- Site:  http://localhost:8888
- Admin: http://localhost:8888/wp-admin  (user `admin`, password `password`)

Useful lifecycle commands:

```bash
npx @wordpress/env stop      # stop containers
npx @wordpress/env start     # start again
npx @wordpress/env destroy   # remove everything
npx @wordpress/env run cli wp --info   # run wp-cli
```

## Configure the store for the agent

```bash
./scripts/setup-store.ps1
```

This confirms WooCommerce is active, sets basic store options, seeds a few
sample products, and prints an **application password** for the agent.

Then create **WooCommerce REST API keys** in the admin UI:
`WooCommerce > Settings > Advanced > REST API > Add key` (Read/Write).

## Fill in `.env`

```
WP_API_URL=http://localhost:8888
WP_API_USERNAME=admin
WP_API_PASSWORD=<application password from the script>
WOO_CUSTOMER_KEY=<from REST API key>
WOO_CUSTOMER_SECRET=<from REST API key>
```

## Enable WooCommerce MCP

WooCommerce ships native MCP support (Woo 10.7+ on WordPress 6.9+). Confirm it's
enabled for your version per the
[WooCommerce MCP docs](https://developer.woocommerce.com/docs/features/mcp/);
some builds expose it as a developer-preview feature toggle.

## Note on reaching the site from the agent

- Running the agent **locally**: `WP_API_URL=http://localhost:8888` works.
- Running the agent **in Docker / Cloud Run**: `localhost` won't resolve to this
  machine. Use `http://host.docker.internal:8888` from a container, or expose
  the WooCommerce site on a public URL (e.g. a tunnel) for a hosted demo.
