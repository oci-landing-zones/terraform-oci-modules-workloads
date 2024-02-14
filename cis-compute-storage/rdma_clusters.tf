data "oci_identity_availability_domains" "cluster_ads" {
  for_each       = var.rdma_clusters_configuration != null ? (var.rdma_clusters_configuration.clusters != null ? var.rdma_clusters_configuration.clusters : {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.rdma_clusters_configuration.default_compartment_id)) > 0 ? var.rdma_clusters_configuration.default_compartment_id : var.compartments_dependency[var.rdma_clusters_configuration.default_compartment_id].id)
}

locals {
  cluster_networks = { for k, v in (var.rdma_clusters_configuration != null ? (var.rdma_clusters_configuration.clusters != null ? var.rdma_clusters_configuration.clusters : {}) : {}) : k => v if lower(v.type) == "cluster_network"}
  compute_clusters = { for k, v in (var.rdma_clusters_configuration != null ? (var.rdma_clusters_configuration.clusters != null ? var.rdma_clusters_configuration.clusters : {}) : {}) : k => v if lower(v.type) != "cluster_network"}
}

resource "oci_core_cluster_network" "these" {
  for_each = local.cluster_networks
    lifecycle {
      ## Check 1: cluster_network_settings is required for clusters of type "cluster_network".
      precondition {
        condition = lower(each.value.type) == "cluster_network" && each.value.cluster_network_settings == null ? false : true
        error_message = "VALIDATION FAILURE in cluster \"${each.key}\": \"cluster_network_settings\" is required for clusters of type \"${each.value.type}\"."
      }
    }  
    #Required
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.rdma_clusters_configuration.default_compartment_id)) > 0 ? var.rdma_clusters_configuration.default_compartment_id : var.compartments_dependency[var.rdma_clusters_configuration.default_compartment_id].id)
    instance_pools {
        #Required
        instance_configuration_id = contains(keys(oci_core_instance_configuration.these),each.value.cluster_network_settings.instance_configuration_id) ? oci_core_instance_configuration.these[each.value.cluster_network_settings.instance_configuration_id].id : (length(regexall("^ocid1.*$", each.value.cluster_network_settings.instance_configuration_id)) > 0 ? each.value.cluster_network_settings.instance_configuration_id : null)
        size = each.value.cluster_network_settings.instance_pool != null ? each.value.cluster_network_settings.instance_pool.size : 1

        #Optional
        display_name = each.value.cluster_network_settings.instance_pool != null ? each.value.cluster_network_settings.instance_pool.name : null
        defined_tags = each.value.defined_tags != null ? each.value.defined_tags : var.rdma_clusters_configuration.default_defined_tags
        freeform_tags = each.value.freeform_tags != null ? each.value.freeform_tags : var.rdma_clusters_configuration.default_freeform_tags
    }
    placement_configuration {
      #Required
      availability_domain  = data.oci_identity_availability_domains.cluster_ads[each.key].availability_domains[(each.value.availability_domain != null ? each.value.availability_domain : 1) - 1].name
      primary_vnic_subnets {
        #Required
        subnet_id = length(regexall("^ocid1.*$", each.value.cluster_network_settings.networking.subnet_id)) > 0 ? each.value.cluster_network_settings.networking.subnet_id : var.network_dependency["subnets"][each.value.cluster_network_settings.networking.subnet_id].id
        is_assign_ipv6ip = each.value.cluster_network_settings.networking.ipv6_enable
        dynamic "ipv6address_ipv6subnet_cidr_pair_details" {
          for_each = each.value.cluster_network_settings.networking.ipv6_enable ? each.value.cluster_network_settings.networking.ipv6_subnet_cidrs : []
          content {
            ipv6subnet_cidr = each.key
          }
        }
      }
      dynamic "secondary_vnic_subnets" {
        for_each = each.value.cluster_network_settings.networking.secondary_vnic_settings != null ? [1] : []
        content {
          subnet_id = length(regexall("^ocid1.*$", each.value.cluster_network_settings.networking.secondary_vnic_settings.subnet_id)) > 0 ? each.value.cluster_network_settings.networking.secondary_vnic_settings.subnet_id : var.network_dependency["subnets"][each.value.cluster_network_settings.networking.secondary_vnic_settings.subnet_id].id
          display_name = each.value.cluster_network_settings.networking.secondary_vnic_settings.name
          is_assign_ipv6ip = each.value.cluster_network_settings.networking.secondary_vnic_settings.ipv6_enable
          dynamic "ipv6address_ipv6subnet_cidr_pair_details" {
            for_each = each.value.cluster_network_settings.networking.secondary_vnic_settings.ipv6_enable ? each.value.cluster_network_settings.networking.secondary_vnic_settings.ipv6_subnet_cidrs : []
            content {
              ipv6subnet_cidr = each.key
            }
          }
        }
      }
    }

    #Optional
    # cluster_configuration {
    #     #Required
    #     hpc_island_id = oci_core_hpc_island.test_hpc_island.id

    #     #Optional
    #     network_block_ids = var.cluster_network_cluster_configuration_network_block_ids
    # }
    
    display_name = each.value.name
    defined_tags = each.value.defined_tags != null ? each.value.defined_tags : var.rdma_clusters_configuration.default_defined_tags
    freeform_tags = each.value.freeform_tags != null ? each.value.freeform_tags : var.rdma_clusters_configuration.default_freeform_tags
}

resource "oci_core_compute_cluster" "these" {
  for_each = local.compute_clusters
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.rdma_clusters_configuration.default_compartment_id)) > 0 ? var.rdma_clusters_configuration.default_compartment_id : var.compartments_dependency[var.rdma_clusters_configuration.default_compartment_id].id)
    availability_domain = data.oci_identity_availability_domains.cluster_ads[each.key].availability_domains[(each.value.availability_domain != null ? each.value.availability_domain : 1) - 1].name
    display_name = each.value.name
    defined_tags = each.value.defined_tags != null ? each.value.defined_tags : var.rdma_clusters_configuration.default_defined_tags
    freeform_tags = each.value.freeform_tags != null ? each.value.freeform_tags : var.rdma_clusters_configuration.default_freeform_tags
}