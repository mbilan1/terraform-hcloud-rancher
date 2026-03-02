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
# Why: The rke2 module (terraform-hcloud-ubuntu-rke2) was designed as a root
#      module and contains its own provider {} blocks with arguments (token,
#      region, etc.). Mock providers don't accept provider-specific arguments,
#      causing plan failures. override_module completely skips planning the
#      child module's internals, providing mock outputs directly.
# See: docs/ARCHITECTURE.md — Compromise Log #1

# WORKAROUND: Hetzner provider uses numeric IDs internally, but Terraform
# resource `id` attribute is always a string. With mock providers, the
# auto-generated string IDs (e.g. "72oy3AZL") cannot be coerced to numbers,
# causing plan failures. We override IDs with numeric strings.
# TODO: Remove mock_resource overrides if OpenTofu adds type-aware mock generation

# L3 providers — only for root-level resources (ingress LB, DNS record)
mock_provider "hcloud" {
  mock_resource "hcloud_load_balancer" {
    defaults = {
      id   = "10003"
      ipv4 = "1.2.3.4"
    }
  }
}

mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "kubectl" {}
mock_provider "rancher2" {}

# DECISION: Override the entire rke2_cluster module with mock outputs.
# Why: Avoids evaluating the rke2 module's internal provider {} blocks
#      (which contain hcloud token, AWS region, etc. that mock providers reject).
#      The mock outputs provide the values needed by L4 provider configs and
#      root-level resources (ingress LB network attachment).
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

# WORKAROUND: Also override the inner upstream module to prevent it from being
# evaluated when override_module for the wrapper doesn't fully prevent nested
# submodule planning. OpenTofu still evaluates module.rke2_cluster.module.cluster
# internals even with override_module on the parent wrapper.
# TODO: Remove if OpenTofu fixes override_module to recursively skip submodules
override_module {
  target = module.rke2_cluster.module.cluster

  outputs = {
    cluster_host              = "https://1.2.3.4:6443"
    cluster_ca                = "mock-ca-cert"
    client_cert               = "mock-client-cert"
    client_key                = "mock-client-key"
    kube_config               = "mock-kubeconfig"
    management_network_id     = "10001"
    management_network_name   = "mock-network"
    control_plane_lb_ipv4     = "1.2.3.4"
    ingress_lb_ipv4           = ""
    cluster_master_nodes_ipv4 = ["1.2.3.4"]
    cluster_worker_nodes_ipv4 = []
    cluster_issuer_name       = "letsencrypt-prod"
    etcd_backup_enabled       = false
    longhorn_enabled          = false
    storage_driver            = "local-path"
  }
}

# WORKAROUND: Override the infrastructure submodule inside the upstream rke2 module.
# Why: override_module in OpenTofu 1.10.x does NOT recursively prevent nested
#      submodules from being evaluated. Each nesting level must be explicitly overridden.
#      Without this, hcloud_server.initial_control_plane[0] evaluates to empty tuple.
# TODO: Remove when OpenTofu fixes override_module to recursively skip submodules
override_module {
  target = module.rke2_cluster.module.cluster.module.infrastructure

  outputs = {
    cluster_host          = "https://1.2.3.4:6443"
    cluster_ca            = "mock-ca-cert"
    client_cert           = "mock-client-cert"
    client_key            = "mock-client-key"
    kube_config           = "mock-kubeconfig"
    network_id            = "10001"
    network_name          = "mock-network"
    control_plane_lb_ipv4 = "1.2.3.4"
    ingress_lb_ipv4       = null
    master_nodes_ipv4     = ["1.2.3.4"]
    worker_nodes_ipv4     = []
    worker_node_names     = []
    master_ipv4           = "1.2.3.4"
    ssh_private_key       = "mock-private-key"
    cluster_ready         = "mock-ready-id"
    control_plane_lb_name = "mock-lb"
    _test_counts = {
      ingress_lb           = 0
      additional_masters   = 0
      masters              = 1
      workers              = 0
      cp_ssh_service       = 0
      ssh_key_file         = 0
      dns_record           = 0
      ingress_lb_targets   = 0
      pre_upgrade_snapshot = 0
    }
    _test_firewall = {
      has_udp_8472        = false
      has_udp_51820_51821 = false
      vxlan_not_public    = true
      has_tcp_9345        = false
      has_tcp_10250       = false
      has_tcp_etcd        = false
    }
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
# ║  UT-V05: rancher_hostname — must not be empty                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rancher_hostname_rejects_empty" {
  command = plan

  variables {
    hcloud_api_token = "mock-token"
    rancher_hostname = ""
    admin_password   = "SecurePassword123"
  }

  expect_failures = [var.rancher_hostname]
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
# ║  UT-V08: kubernetes_version — must be rke2 format or empty                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "kubernetes_version_rejects_invalid" {
  command = plan

  variables {
    hcloud_api_token   = "mock-token"
    rancher_hostname   = "rancher.example.com"
    admin_password     = "SecurePassword123"
    kubernetes_version = "1.29.0"
  }

  expect_failures = [var.kubernetes_version]
}

run "kubernetes_version_accepts_empty" {
  command = plan

  variables {
    hcloud_api_token   = "mock-token"
    rancher_hostname   = "rancher.example.com"
    admin_password     = "SecurePassword123"
    kubernetes_version = ""
  }
}

run "kubernetes_version_accepts_rke2_format" {
  command = plan

  variables {
    hcloud_api_token   = "mock-token"
    rancher_hostname   = "rancher.example.com"
    admin_password     = "SecurePassword123"
    kubernetes_version = "v1.34.4+rke2r1"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V09: k8s_api_allowed_cidrs — must not be empty                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "k8s_api_cidrs_rejects_empty_list" {
  command = plan

  variables {
    hcloud_api_token      = "mock-token"
    rancher_hostname      = "rancher.example.com"
    admin_password        = "SecurePassword123"
    k8s_api_allowed_cidrs = []
  }

  expect_failures = [var.k8s_api_allowed_cidrs]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V10: hcloud_network_cidr — must be valid CIDR                         ║
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
# ║  UT-V11: hcloud_network_zone — must be one of allowed zones               ║
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
