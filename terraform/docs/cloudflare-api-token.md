# Cloudflare API Token

Terraform uses an API token (not a Global API Key) scoped to only the permissions it needs.

---

## Permissions required

| Resource | Permission |
|----------|-----------|
| Zone → Zone | Read |
| Zone → Firewall Services | Edit |

Scope both to **Specific zone → abbottland.io**.

---

## Creating the token

1. Go to [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Click **Create Custom Token** (no built-in template covers exactly these permissions)
4. Set **Token name**: `terraform-abbottland`
5. Under **Permissions**, add:
   - Zone → Zone → **Read**
   - Zone → Firewall Services → **Edit**
6. Under **Zone Resources**, select **Specific zone → abbottland.io**
7. Click **Continue to summary → Create Token**
8. Copy the token — it is only shown once

---

## Adding to tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# set cloudflare_api_token and cloudflare_zone_id
```

Zone ID for `abbottland.io` is in the Cloudflare dashboard under **Overview → API → Zone ID** (right sidebar).

---

## Verifying the token

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer <your-token>" | jq .
```

Expected: `"status": "active"`.
