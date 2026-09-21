# Normalize before CIS checks and before translating to upstream inputs.
# Null means inherit, while false, zero and empty collections are explicit values.
locals {
  worker_pool_fallbacks = {
    mode                         = "node-pool"
    ocpus                        = 1
    memory                       = 16
    boot_volume_size             = 60
    os                           = "Oracle Linux"
    eviction_grace_duration      = 3600
    force_node_delete            = false
    node_cycling_enabled         = false
    node_cycling_max_surge       = "1"
    node_cycling_max_unavailable = "0"
  }
  worker_defaults = var.workers_configuration == null ? null : {
    for field, value in var.workers_configuration : trimprefix(field, "default_") => value if startswith(field, "default_")
  }
  worker_pools = var.workers_configuration == null ? {} : var.workers_configuration.worker_pools
  worker_map_fields = toset([
    "defined_tags", "freeform_tags", "node_defined_tags", "node_freeform_tags",
    "node_labels",
  ])
  # Preserve a typed null for unset attributes without letting optional nulls
  # overwrite configured defaults. The identity key is never derived from a name.
  inherited_worker_pools = {
    for key, pool in local.worker_pools : key => merge(
      { for field, value in pool : field => null },
      local.worker_pool_fallbacks,
      { for field, value in local.worker_defaults : field => value if value != null },
      { for field, value in pool : field => value if value != null },
      {
        cluster_ref = var.workers_configuration.cluster_ref
        image_type  = pool.image_id == null ? "oke" : "custom"
      }
    )
  }
  worker_list_fields = toset(["nsg_ids", "pod_nsg_ids"])
  normalized_worker_pools = {
    for key, pool in local.inherited_worker_pools : key => merge(pool, {
      for field in local.worker_map_fields : field => (
        contains(pool.override_defaults, field) ? local.worker_pools[key][field] : (
          local.worker_pools[key][field] == null && local.worker_defaults[field] == null ? null :
          merge(coalesce(local.worker_defaults[field], {}), coalesce(local.worker_pools[key][field], {}))
        )
      )
      }, {
      for field in local.worker_list_fields : field => distinct(
        contains(pool.override_defaults, field) ? coalesce(local.worker_pools[key][field], []) :
        concat(coalesce(local.worker_defaults[field], []), coalesce(local.worker_pools[key][field], []))
      )
      }, {
      # Custom boot content replaces defaults as a whole, preserving MIME part order.
      # Virtual pools have no boot scripts; inherited managed-pool parts do not apply.
      cloud_init = local.worker_pools[key].cloud_init != null ? local.worker_pools[key].cloud_init : (pool.mode == "virtual-node-pool" ? [] : local.worker_defaults.cloud_init)
    })
  }
}

output "normalized_worker_pools" {
  description = "Resolved schema values only; dependency references and live OCI facts are not resolved."
  value       = local.normalized_worker_pools

  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      !(startswith(upper(coalesce(pool.shape, "unknown")), "BM.") && coalesce(pool.pv_transit_encryption, false))
    ])
    error_message = "In-transit encryption (pv_transit_encryption) is not supported on bare-metal BM shapes. Disable it or select a supported VM shape. Affected pools: ${join(", ", [for key, pool in local.normalized_worker_pools : key if startswith(upper(coalesce(pool.shape, "unknown")), "BM.") && coalesce(pool.pv_transit_encryption, false)])}."
  }

  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      pool.mode == "node-pool" || (length(pool.cloud_init) == 0 && length(pool.gva_secondary_vnics) == 0)
    ])
    error_message = "cloud_init and gva_secondary_vnics are supported only for managed node-pool mode."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      (length(pool.cloud_init) == 0 && pool.disable_default_cloud_init) || !contains(keys(coalesce(pool.node_metadata, {})), "user_data")
    ])
    error_message = "Specify cloud_init or node_metadata.user_data, not both; raw user_data also requires disable_default_cloud_init = true to avoid overriding enabled default scripts."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      length(pool.gva_secondary_vnics) == 0 || try(lower(var.clusters_configuration.clusters[pool.cluster_ref.key].cni_type) == "native", false)
    ])
    error_message = "GVA secondary VNIC profiles require native CNI."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      sum(concat([0], [for vnic in values(pool.gva_secondary_vnics) : vnic.ip_count])) <= 256 &&
      alltrue([for vnic in values(pool.gva_secondary_vnics) :
        contains([1, 2, 4, 8, 16, 32, 64, 128, 256], vnic.ip_count) &&
        trimspace(vnic.subnet_id) != "" &&
        (vnic.nic_index == null ? true : vnic.nic_index >= 0 && floor(vnic.nic_index) == vnic.nic_index)
      ])
    ])
    error_message = "GVA profiles require a subnet, a nonnegative integer nic_index when supplied, and a power-of-two ip_count from 1 to 256; total ip_count per pool must not exceed 256."
  }

  precondition {
    condition = alltrue(flatten([for k, p in local.worker_pools : [for field in p.override_defaults :
      contains(setunion(local.worker_map_fields, local.worker_list_fields), field) && try(p[field] != null, false)
    ]]))
    error_message = "Worker override_defaults supports defined_tags, freeform_tags, node_defined_tags, node_freeform_tags, node_labels, nsg_ids and pod_nsg_ids only; each listed field must have an explicit non-null pool value ({} or [] to clear)."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      pool.mode == "virtual-node-pool" || length(coalesce(pool.taints, [])) == 0
    ])
    error_message = "Taints are supported only for virtual-node-pool mode; do not set taints on managed pools."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      contains(["node-pool", "virtual-node-pool"], pool.mode)
    ])
    error_message = "Supported pool modes are node-pool and virtual-node-pool."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      try(contains(keys(var.clusters_configuration.clusters), pool.cluster_ref.key), false)
    ])
    error_message = "workers_configuration.cluster_ref.key must reference a cluster in clusters_configuration; external clusters are not supported."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      pool.shape != null && pool.subnet_id != null
    ])
    error_message = "Each resolved pool requires shape and subnet_id, supplied globally or per pool."
  }
  precondition {
    condition = alltrue([for pool in values(local.normalized_worker_pools) :
      pool.mode == "virtual-node-pool" ? pool.pod_subnet_id != null : true
    ])
    error_message = "Virtual pools require a resolved pod_subnet_id."
  }
}
