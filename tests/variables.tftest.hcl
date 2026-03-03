# ──────────────────────────────────────────────────────────────────────────────
# Unit Tests: Variable Validations
#
# DECISION: All tests use command = plan with mock_provider to run offline
#           without cloud credentials, at zero cost, in ~2 seconds.
# Why: tofu test with mock providers evaluates validation and check blocks
#      during the plan phase. No real infrastructure is created.
# See: docs/ARCHITECTURE.md
# ──────────────────────────────────────────────────────────────────────────────

# ── Mock providers & module overrides ────────────────────────────────────────
#
# DECISION: Use override_module for module.rke2_cluster instead of mocking all
#           its internal providers individually.
# Why: override_module completely skips planning the child module's internals,
#      providing mock outputs directly.
# See: docs/ARCHITECTURE.md — Compromise Log #1

# WORKAROUND: Hetzner provider uses numeric IDs internally, but Terraform
# resource `id` attribute is always a string. With mock providers, the
# auto-generated string IDs (e.g. "72oy3AZL") cannot be coerced to numbers,
# causing plan failures. We override IDs with numeric strings.
# TODO: Remove mock_resource overrides if OpenTofu adds type-aware mock generation

# DECISION: Only two mock providers — hcloud + rancher2.
# Why: kubectl provider was eliminated. All L4 resources (NodeDriver, UIPlugin)
#      are deployed via cloud-init manifests. Only hcloud (for _ingress_lb
#      submodule) and rancher2 (for rancher2_bootstrap) need mocking.
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

mock_provider "rancher2" {}

# DECISION: Override module.rke2_cluster (wrapper) with mock outputs matching rke2-core API.
# Why: rke2-core is a proper module and uses the root hcloud mock_provider, so its
#      resources would be mocked automatically. However, override_module is still used
#      for the wrapper level to ensure deterministic output values flow into
#      providers.tf (initial_master_ipv4 builds the K8s API URL).
override_module {
  target = module.rke2_cluster

  outputs = {
    network_id          = "10001"
    initial_master_ipv4 = "1.2.3.4"
    cluster_ready       = true
  }
}

# WORKAROUND: Also override module.rke2_cluster.module.cluster (rke2-core root).
# Why: override_module in OpenTofu 1.10.x is NOT recursive. The wrapper module
#      calls module.cluster (rke2-core). Without this override, rke2-core's
#      submodules (_control_plane, _readiness) are still evaluated during plan.
# TODO: Remove if OpenTofu fixes override_module to recursively skip submodules
override_module {
  target = module.rke2_cluster.module.cluster

  outputs = {
    network_id                           = "10001"
    network_subnet_id                    = "10002"
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
#      Without these, rke2-core's _firewall/_network/_control_plane submodules
#      are still planned, causing "Invalid index" errors when for_each resources
#      have no instances (mock_provider doesn't pre-populate for_each maps).
# TODO: Remove all level 3 overrides if OpenTofu adds recursive override_module

override_module {
  target = module.rke2_cluster.module.cluster.module.network

  outputs = {
    network_id          = "10001"
    subnet_id           = "10002"
    hcloud_network_cidr = "10.0.0.0/16"
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
# ║  UT-V01: Default values pass validation                                   ║
# ║  Verifies the module is valid with only required variables set.            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "defaults_pass_validation" {
  command = plan

  variables {
    hcloud_api_token = "mock-token-for-testing"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V02: cluster_name — rejects invalid characters                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "cluster_name_rejects_uppercase" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    cluster_name     = "MyCluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_rejects_hyphens" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    cluster_name     = "my-cluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_rejects_too_long" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    cluster_name     = "abcdefghijklmnopqrstu"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_accepts_valid" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    cluster_name     = "rancher"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V03: management_node_count — rejects 2 (split-brain)                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "node_count_rejects_two" {
  command = plan

  variables {
    hcloud_api_token      = "mock-token"
    rancher_hostname      = "rancher.example.com"
    admin_password        = "SecurePassword123"
    management_node_count = 2
  }

  expect_failures = [var.management_node_count]
}

run "node_count_accepts_one" {
  command = plan

  variables {
    hcloud_api_token      = "mock-token"
    rancher_hostname      = "rancher.example.com"
    admin_password        = "SecurePassword123"
    management_node_count = 1
  }
}

run "node_count_accepts_three" {
  command = plan

  variables {
    hcloud_api_token      = "mock-token"
    rancher_hostname      = "rancher.example.com"
    admin_password        = "SecurePassword123"
    management_node_count = 3
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V04: admin_password — rejects short passwords                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "admin_password_rejects_short" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "short"
  }

  expect_failures = [var.admin_password]
}

run "admin_password_accepts_12_chars" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "123456789012"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V05: rancher_hostname — empty means auto-generate, whitespace rejected ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rancher_hostname_accepts_empty" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = ""
    admin_password   = "SecurePassword123"
  }
}

run "rancher_hostname_rejects_whitespace" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = " rancher.example.com "
    admin_password   = "SecurePassword123"
  }

  expect_failures = [var.rancher_hostname]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V06: rancher_version — must be semver                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rancher_version_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    rancher_version  = "latest"
  }

  expect_failures = [var.rancher_version]
}

run "rancher_version_accepts_semver" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    rancher_version  = "2.13.3"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V07: tls_source — must be one of allowed values                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "tls_source_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    tls_source       = "acme"
  }

  expect_failures = [var.tls_source]
}

run "tls_source_accepts_rancher" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    tls_source       = "rancher"
  }
}

run "tls_source_accepts_letsencrypt" {
  command = plan

  variables {
    hcloud_api_token  = "mock-token"
    rancher_hostname  = "rancher.example.com"
    admin_password    = "SecurePassword123"
    tls_source        = "letsEncrypt"
    letsencrypt_email = "admin@example.com"
  }
}

run "tls_source_accepts_secret" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    tls_source       = "secret"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V08: rke2_version — must be rke2 format or empty                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rke2_version_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    rke2_version     = "1.29.0"
  }

  expect_failures = [var.rke2_version]
}

run "rke2_version_accepts_empty" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    rke2_version     = ""
  }
}

run "rke2_version_accepts_rke2_format" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = "rancher.example.com"
    admin_password   = "SecurePassword123"
    rke2_version     = "v1.32.2+rke2r1"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V09: hcloud_network_cidr — must be valid CIDR                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "network_cidr_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token    = "mock-token"
    rancher_hostname    = "rancher.example.com"
    admin_password      = "SecurePassword123"
    hcloud_network_cidr = "not-a-cidr"
  }

  expect_failures = [var.hcloud_network_cidr]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V10: hcloud_network_zone — must be one of allowed zones               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "network_zone_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token    = "mock-token"
    rancher_hostname    = "rancher.example.com"
    admin_password      = "SecurePassword123"
    hcloud_network_zone = "asia-pacific"
  }

  expect_failures = [var.hcloud_network_zone]
}
