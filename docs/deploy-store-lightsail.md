# WooCommerce store on Amazon Lightsail

Lightsail hosts the **store** the agent acts on. (The agent itself is built with
Google Cloud Agent Builder / ADK and runs locally or on Cloud Run - Lightsail
only provides a reachable `WP_API_URL`.)

Two routes:
- **Option 1 - WordPress blueprint (recommended):** one-click WordPress with
  easy HTTPS. Best choice because application passwords expect HTTPS.
- **Option 2 - Docker on a Lightsail instance:** runs the bundled compose stack.

Prereqs: an AWS account. The `aws` CLI is optional; the Lightsail console works
fine.

---

## Option 1: WordPress blueprint (recommended)

### Create the instance
Console: **Lightsail > Create instance > Linux/Unix > Apps + OS > WordPress**.
Pick the smallest plan that fits (the $5-$7 tier is enough for a demo). Create.

Or via CLI:

```bash
aws lightsail create-instances \
  --instance-names storefront-wp \
  --availability-zone us-east-1a \
  --blueprint-id wordpress \
  --bundle-id micro_3_0
```

### Give it a stable address + open HTTPS
- Attach a **static IP**: Lightsail > Networking > Create static IP > attach to
  `storefront-wp`.
- The WordPress blueprint opens ports 80/443 by default. Confirm under the
  instance's **Networking** tab (HTTP 80, HTTPS 443).

### Get the WordPress admin password
The Bitnami WordPress image generates an admin password on first boot. SSH in
(browser SSH button in the console, or your key) and read it:

```bash
cat /home/bitnami/bitnami_application_password
```

Log in at `http://STATIC_IP/wp-admin` (user: `user`).

### Enable HTTPS (important for application passwords)
Point a domain at the static IP if you have one, then run Bitnami's helper:

```bash
sudo /opt/bitnami/bncert-tool
```

It provisions a Let's Encrypt certificate and configures redirects. If you have
no domain, you can demo over HTTP, but application-password auth over plain HTTP
sends credentials unencrypted - only acceptable for a throwaway demo.

### Install WooCommerce
WordPress admin > Plugins > Add New > search **WooCommerce** > Install >
Activate. Run the setup wizard and add a few sample products. Confirm
WordPress 6.9+ / WooCommerce 10.7+ for native MCP support
([WooCommerce MCP docs](https://developer.woocommerce.com/docs/features/mcp/)).

---

## Option 2: Docker on a Lightsail instance

Use this if you'd rather run the exact compose stack from this repo.

1. Create a **Debian** instance (Lightsail > Linux/Unix > OS Only > Debian).
   Use Debian so the Docker repo in `deploy/gce/startup-script.sh` matches.
2. Add the startup script as launch data:

   ```bash
   aws lightsail create-instances \
     --instance-names storefront-docker \
     --availability-zone us-east-1a \
     --blueprint-id debian_12 \
     --bundle-id small_3_0 \
     --user-data file://deploy/gce/startup-script.sh
   ```

   The script installs Docker and brings up WordPress + WooCommerce on port 80.
3. Open port 80 (and 443 if you add TLS): Lightsail > instance > **Networking >
   Add rule > HTTP**. Optionally attach a static IP.
4. Browse to `http://STATIC_IP/wp-admin` and finish the WordPress install.

> Note: the bundled stack ships plain HTTP. For TLS on this route, put Caddy or
> Traefik in front, or prefer Option 1's `bncert-tool`.

---

## Create the credentials the agent needs

Same for both options:

- **Application password:** WordPress admin > `Users > Profile >
  Application Passwords` > add `storefront-agent` > copy the value.
- **Woo REST keys:** `WooCommerce > Settings > Advanced > REST API > Add key`
  (Read/Write) > copy consumer key + secret.

## Point the agent at Lightsail

In your local `.env`:

```
WP_API_URL=https://your-domain-or-static-ip
WP_API_USERNAME=user            # 'user' on the Bitnami blueprint
WP_API_PASSWORD=<application password>
WOO_CUSTOMER_KEY=<consumer key>
WOO_CUSTOMER_SECRET=<consumer secret>
```

Then `adk web` and confirm both MCP servers connect.

---

## Security notes

- Prefer **HTTPS** (Option 1 + `bncert-tool`). Application passwords over plain
  HTTP travel unencrypted - demo-only.
- **Restrict the firewall** to your IP while testing where the console allows
  it, and delete the instance after the demo.
- **Change defaults**: rotate the Bitnami admin password; if using Option 2,
  change the placeholder DB passwords in `startup-script.sh` first.
- Give the Woo REST key the minimum permission your demo needs.
- The agent's writes still pass through the human-approval gate regardless of
  where the store is hosted.
