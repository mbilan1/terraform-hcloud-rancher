# ──────────────────────────────────────────────────────────────────────────────
# Preflight guardrails — cross-variable validation checks
#
# DECISION: All check {} blocks live in the root guardrails.tf.
# Why: Follows the terraform-hcloud-ubuntu-rke2 pattern — root-level checks
#      are addressable by `tofu test` expect_failures. Checks in child modules
#      cannot be referenced by test assertions.
# See: docs/ARCHITECTURE.md — Module Architecture
# ──────────────────────────────────────────────────────────────────────────────

# ── Management cluster minimum spec ─────────────────────────────────────────

check "management_server_type_warning" {
  # NOTE: This is advisory, not blocking. cx22/cx32 will work but Rancher
  #       may be slow under load (multiple downstream clusters).
  assert {
    condition     = contains(["cx43", "cx53", "cpx41", "cpx42", "cpx51", "cpx52", "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"], var.control_plane_server_type)
    error_message = "Warning: ${var.control_plane_server_type} may be undersized for a Rancher management cluster. Recommended: cx43 (8 vCPU, 16 GB) or larger."
  }
}

# ── Rancher hostname should be a FQDN ───────────────────────────────────────

check "rancher_hostname_is_fqdn" {
  # NOTE: Skip check when hostname is empty (auto-generated from LB IP via sslip.io).
  assert {
    condition     = var.rancher_hostname == "" || can(regex("\\.", var.rancher_hostname))
    error_message = "rancher_hostname should be a fully qualified domain name (e.g. 'rancher.example.com'), not a bare hostname."
  }
}

# ── Let's Encrypt requires email ─────────────────────────────────────────────

# DECISION: Cross-variable check instead of in-variable validation.
# Why: Variable validation blocks cannot reference other variables. The
#      letsencrypt_email variable must accept "" when tls_source != "letsEncrypt".
check "letsencrypt_requires_email" {
  assert {
    condition     = var.tls_source != "letsEncrypt" || var.letsencrypt_email != ""
    error_message = "tls_source is 'letsEncrypt' but letsencrypt_email is empty. Provide a valid email for ACME certificate registration."
  }
}

# ── BYO Ingress LB requires hostname or IP ──────────────────────────────────

# DECISION: Guardrail for BYO ingress LB — must provide hostname or IP.
# Why: When create_ingress_lb = false, auto-hostname generation needs an IP
#      (existing_ingress_lb_ipv4) or the user must provide rancher_hostname
#      directly. Without either, the hostname would be empty/invalid.
check "byo_ingress_lb_requires_hostname_or_ip" {
  assert {
    condition     = var.create_ingress_lb || var.rancher_hostname != "" || var.existing_ingress_lb_ipv4 != ""
    error_message = "When create_ingress_lb = false, you must provide either rancher_hostname or existing_ingress_lb_ipv4 for hostname resolution."
  }
}

# ── Subnet must be contained within network CIDR ────────────────────────────

# DECISION: Validate subnet containment at plan time instead of failing at apply.
# Why: Hetzner API rejects subnets outside the network CIDR, but the error is
#      cryptic. This guardrail provides a clear error message during plan.
check "subnet_within_network_cidr" {
  assert {
    condition = (
      tonumber(split("/", var.subnet_address)[1]) >= tonumber(split("/", var.hcloud_network_cidr)[1]) &&
      cidrhost("${cidrhost(var.subnet_address, 0)}/${split("/", var.hcloud_network_cidr)[1]}", 0) == cidrhost(var.hcloud_network_cidr, 0)
    )
    error_message = "subnet_address (${var.subnet_address}) must be contained within hcloud_network_cidr (${var.hcloud_network_cidr})."
  }
}