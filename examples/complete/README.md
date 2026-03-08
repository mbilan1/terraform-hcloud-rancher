# Complete Example — HA Rancher Management Cluster

Production-ready example with:
- **3-node HA** control plane (etcd quorum)
- **BYO firewall** with restrictive operator-only CIDR rules (ADR-006)
- **Let's Encrypt** TLS (requires real DNS)
- **Packer baked image** support for CIS-hardened nodes (ADR-009)
- **etcd S3 backup** to Hetzner Object Storage (optional)

## Prerequisites

1. **DNS access** — create an A record `rancher.example.com → <ingress LB IP>` after first apply
2. **Hetzner API token** — for the management project (read/write)
3. **Packer snapshot** (optional) — build with `packer-hcloud-rke2` for CIS-hardened nodes

## Quick Start

```bash
export TF_VAR_hcloud_api_token="your-token"
export TF_VAR_admin_password="your-secure-password"
export TF_VAR_rancher_hostname="rancher.example.com"
export TF_VAR_letsencrypt_email="ops@example.com"

tofu init
tofu plan
tofu apply
```

After apply:
1. Note the `ingress_lb_ipv4` output
2. Create DNS A record: `rancher.example.com → <ingress_lb_ipv4>`
3. Wait ~2 minutes for Let's Encrypt certificate
4. Open `https://rancher.example.com`

## With CIS-Hardened Image

```bash
# Build golden image first
cd /path/to/packer-hcloud-rke2
packer build -var "hcloud_token=$HCLOUD_TOKEN" -var "enable_cis_hardening=true" .

# Use the snapshot ID
export TF_VAR_hcloud_image="12345678"  # from Packer output
```

## With etcd S3 Backup

```bash
export TF_VAR_etcd_s3_endpoint="fsn1.your-objectstorage.com"
export TF_VAR_etcd_s3_bucket="rancher-etcd-backup"
export TF_VAR_etcd_s3_access_key="your-access-key"
export TF_VAR_etcd_s3_secret_key="your-secret-key"
```

## Cost Estimate

| Resource | Type | Qty | ~EUR/mo |
|----------|------|-----|---------|
| Control plane | cx43 (8 vCPU, 16 GB) | 3 | 3 × €23.49 = €70.47 |
| Ingress LB | lb11 | 1 | €5.39 |
| Private network | — | 1 | Free |
| **Total** | | | **~€76/mo** |

## See Also

- [examples/minimal/](../minimal/) — single-node dev setup
- [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) — full architecture documentation
