# Hosted WooCommerce store (no local Docker)

The fastest way to get a real `WP_API_URL` for the agent: run WordPress +
WooCommerce on a managed host instead of this machine. Any host works
(InstaWP, wordpress.com Business, Hostinger/cPanel, Kinsta, etc.). The agent
only needs a reachable URL plus credentials.

## 1. Stand up WordPress + WooCommerce

Pick one:

- **InstaWP** (quickest for a demo): create a free site, then add the
  **WooCommerce** plugin from the plugins screen. You get a public URL like
  `https://your-site.instawp.xyz`.
- **wordpress.com** (Business plan or higher, required for custom plugins):
  install **WooCommerce** from Plugins.
- **cPanel / managed host**: use the WordPress one-click installer, then
  install WooCommerce from the WordPress admin.

Requirements for MCP support:
- WordPress **6.9+** (for the Abilities API)
- WooCommerce **10.7+** (for native MCP)

Complete the WooCommerce setup wizard far enough to have an active store, and
add a few sample products so the agent has data to act on.

## 2. Create the credentials the agent needs

### a) WordPress application password (for the WordPress MCP / REST)
In the WordPress admin:
`Users > Profile > Application Passwords` → name it `storefront-agent` →
**Add New Application Password** → copy the generated value.

> If the section is missing, your host may disable it. Application passwords
> require HTTPS. On some hosts you enable it via a plugin or `wp-config.php`.

### b) WooCommerce REST API keys (for store data)
`WooCommerce > Settings > Advanced > REST API > Add key`:
- Description: `storefront-agent`
- User: an admin
- Permissions: **Read/Write**
- Copy the **Consumer key** and **Consumer secret** (shown once).

## 3. Enable the WordPress MCP endpoint (required)

The agent's write side uses `@automattic/mcp-wordpress-remote`, a bridge to an
MCP endpoint that must exist on the site. WooCommerce REST being active is NOT
enough on its own - you must install the plugin that exposes the endpoint:

1. WP admin → Plugins → Add New → search **"WordPress MCP"** (Automattic
   `wordpress-mcp`), or upload the zip from
   https://github.com/Automattic/wordpress-mcp → **Activate**.
2. **Settings → MCP Settings**:
   - **Enable MCP functionality**
   - **Enable tools**, including **write/CRUD tools** (default is read-only;
     publishing notices/coupons needs create/update enabled)
   - Enable **WooCommerce** tools if a toggle is present
3. Keep the application password (2a) and Woo keys (2b) - the remote
   authenticates with them.

Verify: `GET /wp-json/` should now include an `mcp`/`wpmcp` route. Without the
plugin the agent logs `WordPress connection failed during initialization`.

## 4. Point the agent at the hosted store

In your local `.env`:

```
WP_API_URL=https://your-store.example.com
WP_API_USERNAME=your-admin-username
WP_API_PASSWORD=<application password from step 2a>
WOO_CUSTOMER_KEY=<consumer key from step 2b>
WOO_CUSTOMER_SECRET=<consumer secret from step 2b>
```

Then run the agent locally to verify both MCP servers connect:

```bash
adk web
```

## 5. Security notes

- The store is publicly reachable, so treat the application password and Woo
  keys as secrets — keep them in `.env` (git-ignored), never commit them.
- Give the Woo REST key the **minimum** permission the demo needs. Use
  Read/Write only because the agent performs write remediations; if you only
  demo read flows, downgrade to Read.
- Application passwords can be revoked instantly from the same admin screen if
  a key leaks.

## Why hosted instead of local here

Local Docker on the current machine couldn't initialize MariaDB in a reasonable
time (constrained I/O, `io_uring` disabled). A managed host sidesteps that
entirely and also gives you the public URL the hackathon submission requires.
If you later want a self-hosted store, use the GCE path in
[deploy-store-gce.md](deploy-store-gce.md).
