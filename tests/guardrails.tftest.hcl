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
