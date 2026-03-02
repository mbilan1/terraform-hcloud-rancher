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
  mock_resource "hcloud_network" {
    defaults = {
      id = "10001"
    }
  }
  mock_resource "hcloud_network_subnet" {
    defaults = {
      id = "10002"
    }
  }
  mock_resource "hcloud_firewall" {
    defaults = {
      id = "20001"
    }
  }
  mock_resource "hcloud_server" {
    defaults = {
      id           = "30001"
      ipv4_address = "1.2.3.4"
    }
  }
  mock_resource "hcloud_server_network" {
    defaults = {
      id = "30002"
      ip = "10.0.1.1"
    }
  }
}

mock_provider "kubectl" {}
mock_provider "rancher2" {}

override_module {
  target = module.rke2_cluster

  outputs = {
    network_id          = "10001"
    initial_master_ipv4 = "1.2.3.4"
    cluster_ready       = true
  }
}

# WORKAROUND: Override rke2-core submodule to prevent plan-time evaluation.
# Why: override_module in OpenTofu 1.10.x is NOT recursive.
# TODO: Remove if OpenTofu fixes override_module to recursively skip submodules
override_module {
  target = module.rke2_cluster.module.cluster

  outputs = {
    network_id                           = "10001"
    network_subnet_id                    = "10002"
    firewall_control_plane_ids           = ["20001"]
    firewall_worker_ids                  = ["20002"]
    control_plane_server_ids             = { "cp-0" = "30001" }
    control_plane_ipv4_addresses         = { "cp-0" = "1.2.3.4" }
    control_plane_private_ipv4_addresses = { "cp-0" = "10.0.1.1" }
    initial_master_ipv4                  = "1.2.3.4"
    cluster_token                        = "mock-cluster-token"
    cluster_ready                        = true
  }
}

# WORKAROUND: Level 3 overrides for rke2-core internal submodules.
# Why: override_module is NOT recursive in OpenTofu 1.10.x. Each nested module
#      requires its own override_module to prevent plan-time evaluation.
# TODO: Remove if OpenTofu adds recursive override_module

override_module {
  target = module.rke2_cluster.module.cluster.module.network

  outputs = {
    network_id          = "10001"
    subnet_id           = "10002"
    hcloud_network_cidr = "10.0.0.0/16"
  }
}

override_module {
  target = module.rke2_cluster.module.cluster.module.firewall

  outputs = {
    control_plane_firewall_ids = ["20001"]
    worker_firewall_ids        = ["20002"]
  }
}

override_module {
  target = module.rke2_cluster.module.cluster.module.control_plane

  outputs = {
    server_ids                    = { "cp-0" = "30001" }
    server_ipv4_addresses         = { "cp-0" = "1.2.3.4" }
    server_private_ipv4_addresses = { "cp-0" = "10.0.1.1" }
    initial_master_key            = "cp-0"
    initial_master_ipv4           = "1.2.3.4"
    initial_master_private_ipv4   = "10.0.1.1"
  }
}

override_module {
  target = module.rke2_cluster.module.cluster.module.readiness

  outputs = {
    cluster_ready = true
    api_ready_id  = "mock-ready-id"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G01: letsencrypt_requires_email                                        ║
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
# ║  UT-G02: management_server_type_warning                                    ║
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
# ║  UT-G03: rancher_hostname_is_fqdn                                         ║
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
