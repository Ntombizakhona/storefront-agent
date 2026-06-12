# Configures the local WooCommerce site for the agent after `wp-env start`.
# Run from the project root:  ./scripts/setup-store.ps1
#
# Uses wp-cli inside the wp-env "cli" container via `npx wp-env run cli`.

$ErrorActionPreference = "Stop"

function Wp([string]$cmd) {
    Write-Host ">> wp $cmd" -ForegroundColor Cyan
    npx wp-env run cli wp $cmd.Split(" ")
}

Write-Host "1) Confirming WooCommerce is active..." -ForegroundColor Green
Wp "plugin list --status=active --field=name"

Write-Host "2) Setting store address / currency (skips onboarding nag)..." -ForegroundColor Green
Wp "option update woocommerce_store_address '123 Market St'"
Wp "option update woocommerce_default_country 'US:CA'"
Wp "option update woocommerce_currency 'USD'"
Wp "option update woocommerce_onboarding_profile '{\"completed\":true}' --format=json"

Write-Host "3) Seeding sample products..." -ForegroundColor Green
Wp "wc product create --name='Match Day Jersey' --type=simple --regular_price=89.99 --manage_stock=true --stock_quantity=50 --user=admin"
Wp "wc product create --name='Stadium Scarf' --type=simple --regular_price=24.99 --manage_stock=true --stock_quantity=200 --user=admin"
Wp "wc product create --name='Limited Edition Ball' --type=simple --regular_price=149.99 --manage_stock=true --stock_quantity=10 --user=admin"

Write-Host "4) Creating an application password for the agent..." -ForegroundColor Green
Write-Host "   Copy the value below into WP_API_PASSWORD in your .env" -ForegroundColor Yellow
Wp "user application-password create admin storefront-agent --porcelain"

Write-Host ""
Write-Host "Done. Next, create WooCommerce REST API keys in the admin UI:" -ForegroundColor Green
Write-Host "  http://localhost:8888/wp-admin  ->  WooCommerce > Settings > Advanced > REST API"
Write-Host "  Create a key with Read/Write, then put it in WOO_CUSTOMER_KEY / WOO_CUSTOMER_SECRET."
Write-Host ""
Write-Host "Admin login: user 'admin', password 'password'"
