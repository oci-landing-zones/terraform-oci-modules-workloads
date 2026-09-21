locals {
  pool_targets = { for k, p in local.pools : k => {
    cluster_type   = local.clusters[local.cluster_key].cluster_type
    cni_type       = lower(local.clusters[local.cluster_key].cni_type)
    version        = coalesce(local.clusters[local.cluster_key].kubernetes_version, reverse(data.oci_containerengine_cluster_option.cluster_options[local.cluster_key].kubernetes_versions)[0])
    compartment_id = local.cluster_settings[local.cluster_key].compartment_id
    cis_level      = local.cluster_settings[local.cluster_key].cis_level
  } }
  pool_settings = { for k, p in local.pools : k => {
    compartment_id     = local.pool_targets[k].compartment_id
    version            = coalesce(p.kubernetes_version, local.pool_targets[k].version, "v0.0.0")
    subnet_id          = local.subnets[p.subnet_id]
    pod_subnet_id      = p.pod_subnet_id == null ? null : local.subnets[p.pod_subnet_id]
    nsg_ids            = distinct([for ref in coalesce(p.nsg_ids, []) : local.nsgs[ref]])
    pod_nsg_ids        = distinct([for ref in coalesce(p.pod_nsg_ids, []) : local.nsgs[ref]])
    kms_key_id         = p.volume_kms_key_id == null ? null : local.keys[p.volume_kms_key_id]
    defined_tags       = coalesce(p.defined_tags, {})
    freeform_tags      = merge(local.cislz_module_tag, coalesce(p.freeform_tags, {}))
    node_defined_tags  = coalesce(p.node_defined_tags, p.defined_tags, {})
    node_freeform_tags = merge(local.cislz_module_tag, coalesce(p.node_freeform_tags, p.freeform_tags, {}))
    ssh_public_key     = p.ssh_public_key
    placement_ads      = coalesce(p.placement_ads, [1])
    placement_fds      = p.placement_fds
    preemptible        = coalesce(p.preemptible_config, { enable = false, is_preserve_boot_volume = false })
  } }
}

data "oci_containerengine_cluster_option" "worker_versions" {
  for_each          = { for k, p in local.pools : k => p if p.mode == "node-pool" }
  cluster_option_id = "all"
  compartment_id    = local.pool_targets[each.key].compartment_id
}
resource "terraform_data" "worker_validation" {
  for_each = local.pools
  input = {
    resource_address        = "module.cluster[${jsonencode(local.cluster_key)}].module.workers[0].${each.value.mode == "node-pool" ? "oci_containerengine_node_pool.tfscaled_workers" : "oci_containerengine_virtual_node_pool.workers"}[${jsonencode(coalesce(each.value.name, each.key))}]"
    defined_tags            = local.pool_settings[each.key].defined_tags
    freeform_tags           = merge({ state_id = local.cluster_key, role = "worker", pool = coalesce(each.value.name, each.key), cluster_autoscaler = "disabled" }, local.pool_settings[each.key].freeform_tags)
    placement_ads_numbers   = local.pool_settings[each.key].placement_ads
    placement_fds           = local.pool_settings[each.key].placement_fds
    subnet_id               = local.pool_settings[each.key].subnet_id
    capacity_reservation_id = each.value.capacity_reservation_id
    gva_secondary_vnics = [for name, vnic in each.value.gva_secondary_vnics : {
      display_name = coalesce(vnic.display_name, name)
      defined_tags = coalesce(vnic.defined_tags, local.pool_settings[each.key].defined_tags)
    }]
    preemptible = local.pool_settings[each.key].preemptible
  }
  lifecycle {
    precondition {
      condition     = each.value.mode != "node-pool" || local.pool_targets[each.key].cis_level != "2" || local.pool_settings[each.key].kms_key_id != null
      error_message = "Pool ${each.key}: CIS level 2 requires a customer-managed worker volume key."
    }
    precondition {
      condition     = each.value.mode != "node-pool" ? true : contains(data.oci_containerengine_cluster_option.worker_versions[each.key].kubernetes_versions, local.pool_settings[each.key].version)
      error_message = "Pool ${each.key}: worker Kubernetes version must be supported by OCI."
    }
    precondition {
      condition = each.value.mode != "node-pool" ? true : (
        split(".", trimprefix(local.pool_settings[each.key].version, "v"))[0] == split(".", trimprefix(local.pool_targets[each.key].version, "v"))[0] &&
        tonumber(split(".", trimprefix(local.pool_settings[each.key].version, "v"))[1]) <= tonumber(split(".", trimprefix(local.pool_targets[each.key].version, "v"))[1]) &&
        tonumber(split(".", trimprefix(local.pool_targets[each.key].version, "v"))[1]) - tonumber(split(".", trimprefix(local.pool_settings[each.key].version, "v"))[1]) <= 2
      )
      error_message = "Pool ${each.key}: workers must be no newer than their control plane and no more than two minor versions behind."
    }
    precondition {
      condition     = each.value.mode != "virtual-node-pool" || local.pool_targets[each.key].cluster_type == "enhanced"
      error_message = "Pool ${each.key}: virtual node pools require an enhanced cluster."
    }
    precondition {
      condition     = each.value.mode != "virtual-node-pool" || local.pool_targets[each.key].cni_type == "native"
      error_message = "Pool ${each.key}: virtual node pools require native CNI."
    }
    precondition {
      condition     = local.pool_targets[each.key].cni_type != "native" || local.pool_settings[each.key].pod_subnet_id != null || length(each.value.gva_secondary_vnics) > 0
      error_message = "Pool ${each.key}: native CNI requires a pod subnet or GVA secondary VNIC profiles."
    }
    precondition {
      condition     = local.pool_settings[each.key].defined_tags == local.pool_settings[each.key].node_defined_tags && local.pool_settings[each.key].freeform_tags == local.pool_settings[each.key].node_freeform_tags
      error_message = "Pool ${each.key}: official upstream v5.5.1 cannot apply different pool and node tags. This configuration is blocked pending upstream support."
    }
    precondition {
      condition     = length(distinct(local.pool_settings[each.key].placement_ads)) == length(local.pool_settings[each.key].placement_ads)
      error_message = "Pool ${each.key}: placement_ads must not contain duplicate AD numbers."
    }
    precondition {
      condition     = alltrue([for ad in local.pool_settings[each.key].placement_ads : ad >= 1 && floor(ad) == ad])
      error_message = "Pool ${each.key}: placement AD numbers must be positive whole numbers; upstream resolves them against the region."
    }
    precondition {
      condition     = length(distinct([for t in coalesce(each.value.taints, []) : t.key])) == length(coalesce(each.value.taints, []))
      error_message = "Pool ${each.key}: official upstream requires unique virtual taint keys. Duplicate keys are blocked."
    }
    precondition {
      condition     = each.value.mode != "virtual-node-pool" ? true : length(coalesce(local.pool_settings[each.key].placement_fds, [])) == 0
      error_message = "Pool ${each.key}: explicit virtual fault domains are blocked by the pinned upstream fault-domain mapping. Only automatic FD placement is supported."
    }
    precondition {
      condition     = each.value.mode != "virtual-node-pool" || length(local.pool_settings[each.key].pod_nsg_ids) > 0
      error_message = "Pool ${each.key}: pinned upstream virtual pools require explicit nonempty pod_nsg_ids; empty NSG lists are blocked."
    }
    precondition {
      condition     = each.value.size == null ? true : (floor(each.value.size) == each.value.size && each.value.size >= (each.value.mode == "virtual-node-pool" ? 1 : 0))
      error_message = "Pool ${each.key}: size must be a whole number, at least zero for managed pools and one for virtual pools."
    }
    precondition {
      condition     = each.value.mode != "node-pool" || each.value.ocpus > 0 && each.value.memory > 0 && each.value.boot_volume_size > 0
      error_message = "Pool ${each.key}: OCPUs, memory and boot volume size must be positive."
    }
    precondition {
      condition     = each.value.size != null
      error_message = "Pool ${each.key}: set size on the pool or default_size. Official upstream requires an explicit size; migrate the deployed size rather than assuming zero."
    }
  }
  depends_on = [terraform_data.dependencies]
}

locals {
  upstream_pools = { for key, pool in local.pools : key => merge(
    { for field, value in pool : field => value if value != null && !contains(["override_defaults", "placement_ads", "placement_fds", "taints", "image_type", "image_id", "defined_tags", "freeform_tags", "node_defined_tags", "node_freeform_tags", "node_labels", "node_metadata", "volume_kms_key_id", "subnet_id", "pod_subnet_id", "nsg_ids", "pod_nsg_ids"], field) },
    {
      create                   = true
      autoscale                = false
      allow_autoscaler         = false
      ignore_initial_pool_size = false
      compartment_id           = local.pool_settings[key].compartment_id
      size                     = coalesce(pool.size, 0)
      subnet_id                = local.pool_settings[key].subnet_id
      pod_subnet_id            = local.pool_settings[key].pod_subnet_id
      nsg_ids                  = local.pool_settings[key].nsg_ids
      pod_nsg_ids              = pool.mode == "virtual-node-pool" && length(local.pool_settings[key].pod_nsg_ids) == 0 ? ["blocked"] : local.pool_settings[key].pod_nsg_ids
      image_type               = pool.image_type
      image_id                 = pool.image_id
      kubernetes_version       = local.pool_settings[key].version
      volume_kms_key_id        = local.pool_settings[key].kms_key_id
      placement_ads            = local.pool_settings[key].placement_ads
      placement_fds            = pool.mode == "virtual-node-pool" ? [] : local.pool_settings[key].placement_fds
      preemptible_config       = local.pool_settings[key].preemptible
      defined_tags             = local.pool_settings[key].defined_tags
      freeform_tags            = local.pool_settings[key].freeform_tags
      node_labels              = coalesce(pool.node_labels, {})
      # Preserve upstream rendering whenever default scripts or custom parts are enabled.
      node_metadata = merge(pool.disable_default_cloud_init && length(pool.cloud_init) == 0 ? { user_data = "" } : {}, coalesce(pool.node_metadata, {}))
      cloud_init    = pool.disable_default_cloud_init && length(pool.cloud_init) == 0 ? [{ content = "#cloud-config\n{}\n", content_type = "text/cloud-config" }] : [for part in pool.cloud_init : { for k, v in part : k => v if v != null }]
      gva_secondary_vnics = { for name, vnic in pool.gva_secondary_vnics : name => merge(
        { for k, v in vnic : k => v if v != null },
        { subnet_id = local.subnets[vnic.subnet_id], nsg_ids = distinct([for ref in vnic.nsg_ids : local.nsgs[ref]]) }
      ) }
      force_node_action    = false
      node_cycling_enabled = pool.node_cycling_enabled
      taints               = zipmap([for t in coalesce(pool.taints, []) : coalesce(t.key, "invalid")], [for t in coalesce(pool.taints, []) : { value = t.value, effect = coalesce(t.effect, "NoSchedule") }])
    }
  ) }
}
