# ──────────────────────────────────────────────────────────────────────────────
# State migration — moved blocks
#
# DECISION: moved blocks map old root-level LB resources to for_each keyed versions.
# Why: The ingress LB was refactored from count-indexed resources to for_each
#      keyed resources (BYO composable-primitive pattern from rke2-core).
#      These moved blocks prevent resource destruction on existing deployments.
# TODO: Remove after all known deployments have migrated.
# ──────────────────────────────────────────────────────────────────────────────

moved {
  from = hcloud_load_balancer.ingress
  to   = hcloud_load_balancer.ingress["main"]
}

moved {
  from = hcloud_load_balancer_network.ingress
  to   = hcloud_load_balancer_network.ingress["main"]
}

moved {
  from = hcloud_load_balancer_target.ingress_masters
  to   = hcloud_load_balancer_target.ingress["main"]
}

moved {
  from = hcloud_load_balancer_service.ingress_http
  to   = hcloud_load_balancer_service.http["main"]
}

moved {
  from = hcloud_load_balancer_service.ingress_https
  to   = hcloud_load_balancer_service.https["main"]
}

# DECISION: kubectl_manifest resources are removed (deployed via cloud-init now).
# Why: NodeDriver and UIPlugin were previously created by alekc/kubectl provider
#      as kubectl_manifest resources. They are now deployed via RKE2 deploy
#      controller from cloud-init manifests. The resources should be removed
#      from state with `tofu state rm` on existing deployments, or they will
#      show as "destroy" on the next plan.
# NOTE: moved blocks cannot map to "removed" — operators must run:
#       tofu state rm 'module.rancher.kubectl_manifest.hetzner_node_driver[0]'
#       tofu state rm 'module.rancher.kubectl_manifest.hetzner_ui_extension[0]'
