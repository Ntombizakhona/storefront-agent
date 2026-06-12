# Self-hosted WooCommerce on a GCE VM

Run the exact compose stack on a small Google Compute Engine VM. On a normal
cloud disk it comes up in ~2-3 minutes (vs. never finishing on the constrained
local machine). Two ways: `gcloud` (quick) or Terraform (repeatable).

Prereqs: a Google Cloud project with billing, and either the `gcloud` CLI or
Terraform installed and authenticated (`gcloud auth login`).

---

## Option 1: gcloud (one VM + one firewall rule)

```bash
PROJECT=your-project-id
ZONE=us-central1-a

# Create the VM; the startup script installs Docker and runs the store.
gcloud compute instances create storefront-woocommerce \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB \
  --tags=storefront \
  --metadata-from-file=startup-script=deploy/gce/startup-script.sh

# Allow HTTP. Restrict --source-ranges to YOUR_IP/32 for a safer demo.
gcloud compute firewall-rules create storefront-allow-http \
  --project="$PROJECT" \
  --allow=tcp:80 \
  --target-tags=storefront \
  --source-ranges=0.0.0.0/0

# Get the public IP -> this is your WP_API_URL (http://IP).
gcloud compute instances describe storefront-woocommerce \
  --project="$PROJECT" --zone="$ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Wait ~2-3 minutes after creation for the startup script to finish (Docker
install + image pulls + WooCommerce activation). Check progress:

```bash
gcloud compute ssh storefront-woocommerce --zone="$ZONE" --project="$PROJECT" \
  --command="sudo grep store-startup-complete /var/log/syslog; sudo docker compose -f /opt/store/docker-compose.yml ps"
```

---

## Option 2: Terraform

```bash
cd deploy/gce
terraform init
terraform apply -var="project_id=your-project-id"
# or safer: -var="allowed_ingress_cidr=YOUR_IP/32"
```

`terraform output store_url` prints the URL to use as `WP_API_URL`.

Tear down when done:

```bash
terraform destroy -var="project_id=your-project-id"
```

---

## Finish store setup

1. Open `http://EXTERNAL_IP/wp-admin` and complete the WordPress install
   (set admin user/password).
2. WooCommerce is already installed/activated by the startup script; run its
   setup wizard and add a few sample products.
3. Create credentials (same as a managed host):
   - Application password: `Users > Profile > Application Passwords`.
   - Woo REST keys: `WooCommerce > Settings > Advanced > REST API` (Read/Write).
4. Put them in your local `.env`:
   ```
   WP_API_URL=http://EXTERNAL_IP
   WP_API_USERNAME=admin
   WP_API_PASSWORD=<application password>
   WOO_CUSTOMER_KEY=<consumer key>
   WOO_CUSTOMER_SECRET=<consumer secret>
   ```

---

## Security notes (read before exposing publicly)

- **This is an unauthenticated, internet-reachable WordPress.** That's fine for
  a short-lived hackathon demo, but treat it as disposable and delete it after.
- **Lock down ingress**: set `--source-ranges` / `allowed_ingress_cidr` to your
  own IP (`x.x.x.x/32`) instead of `0.0.0.0/0` wherever possible.
- **No HTTPS by default.** WordPress application passwords are intended for
  HTTPS. Over plain HTTP the credentials travel unencrypted — acceptable only
  for a throwaway demo. For anything real, put the VM behind a load balancer
  with a managed certificate, or use Caddy/Traefik for TLS, then use the
  `https://` URL.
- **Change default DB passwords** in `startup-script.sh` before any non-demo
  use; the values there are placeholders.
- The agent's write actions still go through the human-approval gate, so the
  agent can't change the store without your confirmation regardless of host.
