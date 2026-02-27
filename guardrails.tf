# ──────────────────────────────────────────────────────────────────────────────
# Preflight guardrails — cross-variable validation checks
#
# DECISION: All check {} blocks live in the root guardrails.tf.
# Why: Follows the terraform-hcloud-ubuntu-rke2 pattern — root-level checks
#      are addressable by `tofu test` expect_failures. Checks in child modules
#      cannot be referenced by test assertions.
# See: docs/ARCHITECTURE.md — Module Architecture
# ──────────────────────────────────────────────────────────────────────────────

# ── DNS requires Route53 zone ────────────────────────────────────────────────

check "dns_requires_zone" {
  assert {
    condition     = !var.create_dns_record || var.route53_zone_id != ""
    error_message = "create_dns_record is true but route53_zone_id is empty. Provide a valid Route53 hosted zone ID."
  }
}

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
  assert {
    condition     = can(regex("\\.", var.rancher_hostname))
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

# ── AWS credentials must be provided as a pair ───────────────────────────────

# DECISION: Ported from terraform-hcloud-ubuntu-rke2 guardrails.
# Why: Providing only one half of the AWS credential pair is always a mistake.
#      Both empty = use environment/instance profile. Both set = explicit creds.
check "aws_credentials_pair_consistency" {
  assert {
    condition     = (var.aws_access_key == "" && var.aws_secret_key == "") || (var.aws_access_key != "" && var.aws_secret_key != "")
    error_message = "AWS credentials must be provided as a pair: both aws_access_key and aws_secret_key must be set, or both must be empty."
  }
}
