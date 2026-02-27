# ──────────────────────────────────────────────────────────────────────────────
# Unit Tests: Cross-Variable Guardrails (check blocks)
#
# DECISION: All tests use command = plan with mock_provider to run offline
#           without cloud credentials, at zero cost, in ~1 second.
# Why: tofu test with mock providers evaluates check blocks during plan phase.
# See: docs/ARCHITECTURE.md
# ──────────────────────────────────────────────────────────────────────────────

# ── Mock providers ──────────────────────────────────────────────────────────

# ── Mock providers & module overrides ────────────────────────────────────────
#
# DECISION: Use override_module for module.rke2_cluster instead of mocking all
#           its internal providers individually.
# Why: The rke2 module contains provider {} blocks with arguments (token, region)
#      that mock providers don't accept. override_module skips the child module's
#      internals entirely.
# See: tests/variables.tftest.hcl for detailed rationale.

mock_provider "hcloud" {
  mock_resource "hcloud_load_balancer" {
    defaults = {
      id   = "10003"
      ipv4 = "1.2.3.4"
    }
  }
}

mock_provider "aws" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "kubectl" {}
mock_provider "rancher2" {}

override_module {
  target = module.rke2_cluster

  outputs = {
    cluster_host          = "https://1.2.3.4:6443"
    cluster_ca            = "mock-ca-cert"
    client_cert           = "mock-client-cert"
    client_key            = "mock-client-key"
    kube_config           = "mock-kubeconfig"
    network_id            = "10001"
    control_plane_lb_ipv4 = "1.2.3.4"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G01: dns_requires_zone                                                ║
# ║  create_dns_record = true without route53_zone_id → warning                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "dns_requires_zone_rejects_missing_zone" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    create_dns_record = true
    route53_zone_id   = ""
  }

  expect_failures = [check.dns_requires_zone]
}

run "dns_requires_zone_accepts_with_zone" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    create_dns_record = true
    route53_zone_id   = "Z1234567890"
  }
}

run "dns_requires_zone_accepts_no_dns" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    create_dns_record = false
    route53_zone_id   = ""
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G02: letsencrypt_requires_email                                        ║
# ║  tls_source = "letsEncrypt" without email → warning                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "letsencrypt_requires_email_rejects_empty" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    tls_source        = "letsEncrypt"
    letsencrypt_email = ""
  }

  expect_failures = [check.letsencrypt_requires_email]
}

run "letsencrypt_requires_email_accepts_with_email" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    tls_source        = "letsEncrypt"
    letsencrypt_email = "admin@example.com"
  }
}

run "letsencrypt_skipped_when_rancher_tls" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    tls_source        = "rancher"
    letsencrypt_email = ""
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G03: aws_credentials_pair_consistency                                  ║
# ║  COMPROMISE: Cannot unit-test this check block in isolation.               ║
# ║  Why: The rke2 module (nested inside module.rke2_cluster.module.cluster)   ║
# ║       has an identical check block that also fires. override_module does    ║
# ║       not suppress check blocks in nested modules, and expect_failures     ║
# ║       cannot reference module-internal checks. The check block works       ║
# ║       correctly at runtime — only the test is impossible.                  ║
# ║  TODO: Re-enable when OpenTofu supports expect_failures for module checks  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Positive tests still verify the check does NOT fire on valid input:
run "aws_credentials_accepts_both_set" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    aws_access_key   = "AKIAEXAMPLE"
    aws_secret_key   = "secretkey123"
  }
}

run "aws_credentials_accepts_both_empty" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    aws_access_key   = ""
    aws_secret_key   = ""
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G04: management_server_type_warning                                    ║
# ║  Undersized server type → advisory warning                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "server_type_warns_undersized" {
  command = plan

  variables {
    hcloud_api_token          = "mock-token"
    rancher_hostname          = "rancher.example.com"
    admin_password            = "SecurePassword123"
    control_plane_server_type = "cx22"
  }

  expect_failures = [check.management_server_type_warning]
}

run "server_type_accepts_cx43" {
  command = plan

  variables {
    hcloud_api_token          = "mock-token"
    rancher_hostname          = "rancher.example.com"
    admin_password            = "SecurePassword123"
    control_plane_server_type = "cx43"
  }
}

run "server_type_accepts_cpx42" {
  command = plan

  variables {
    hcloud_api_token          = "mock-token"
    rancher_hostname          = "rancher.example.com"
    admin_password            = "SecurePassword123"
    control_plane_server_type = "cpx42"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G05: rancher_hostname_is_fqdn                                         ║
# ║  Bare hostname (no dot) → advisory warning                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "hostname_warns_bare_name" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher"
    admin_password   = "SecurePassword123"
  }

  expect_failures = [check.rancher_hostname_is_fqdn]
}

run "hostname_accepts_fqdn" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
  }
}
