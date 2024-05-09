# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_containerengine_clusters" "vpool" {
  for_each       = var.workers_configuration != null ? coalesce(var.workers_configuration["virtual_node_pools"], {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
}

data "oci_identity_availability_domains" "vpool_ads" {
  for_each       = var.workers_configuration != null ? coalesce(var.workers_configuration["virtual_node_pools"], {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
}

resource "oci_containerengine_virtual_node_pool" "these" {
  for_each = var.workers_configuration != null ? coalesce(var.workers_configuration["virtual_node_pools"], {}) : {}
  lifecycle {
    ## Check 1. Enhanced Cluster validation when creating virtual node pools.
    precondition {
      condition     = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.vpool[each.key].clusters : cluster.type if cluster.id == each.value.cluster_id][0] == "ENHANCED_CLUSTER" : oci_containerengine_cluster.these[each.value.cluster_id].type == "ENHANCED_CLUSTER"
      error_message = "VALIDATION FAILURE in virtual node pool \"${each.key}\": Virtual node pools only work on enhanced clusters"
    }
    ## Check 2: Compartment validation when the cluster is not created with terraform.
    precondition {
      condition     = each.value.compartment_id != null ? true : var.workers_configuration.default_compartment_id != null ? true : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? false : true
      error_message = "VALIDATION FAILURE in virtual node pool \"${each.key}\": One of the attributes compartment_id or default_compartment_id must be used when specifying an ocid in the cluster_id attribute."
    }
  }
  cluster_id     = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? each.value.cluster_id : oci_containerengine_cluster.these[each.value.cluster_id].id
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
  display_name   = each.value.name
  dynamic "placement_configurations" {
    for_each = each.value.placement != null ? each.value.placement : tolist([(tomap({ 1 = 1 }))])
    iterator = pc
    content {
      availability_domain = each.value.placement != null ? data.oci_identity_availability_domains.vpool_ads[each.key].availability_domains[(pc.value.availability_domain != null ? pc.value.availability_domain : 1) - 1].name : data.oci_identity_availability_domains.vpool_ads[each.key].availability_domains[0].name
      fault_domain        = each.value.placement != null ? pc.value.fault_domain != null ? [format("FAULT-DOMAIN-%s", pc.value.fault_domain)] : each.value.size > 3 ? [for num in range(1, 4) : format("FAULT-DOMAIN-%s", num)] : [for num in range(1, each.value.size + 1) : format("FAULT-DOMAIN-%s", num)] : each.value.size > 3 ? [for num in range(1, 4) : format("FAULT-DOMAIN-%s", num)] : [for num in range(1, each.value.size + 1) : format("FAULT-DOMAIN-%s", num)]
      subnet_id           = length(regexall("^ocid1.*$", each.value.networking.workers_subnet_id)) > 0 ? each.value.networking.workers_subnet_id : var.network_dependency["subnets"][each.value.networking.workers_subnet_id].id
    }
  }
  defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.workers_configuration.default_defined_tags
  freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.workers_configuration.default_freeform_tags)
  dynamic "initial_virtual_node_labels" {
    for_each = each.value.initial_node_labels != null ? each.value.initial_node_labels : var.workers_configuration.default_initial_node_labels != null ? var.workers_configuration.default_initial_node_labels : {}
    iterator = label
    content {
      key   = label.key
      value = label.value
    }
  }
  nsg_ids = each.value.networking.workers_nsg_ids != null ? [for nsg in each.value.networking.workers_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : []
  pod_configuration {
    shape     = each.value.pod_shape
    subnet_id = length(regexall("^ocid1.*$", each.value.networking.pods_subnet_id)) > 0 ? each.value.networking.pods_subnet_id : var.network_dependency["subnets"][each.value.networking.pods_subnet_id].id
    nsg_ids   = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.vpool[each.key].clusters : cluster.cluster_pod_network_options[0].cni_type if cluster.id == each.value.cluster_id][0] == "OCI_VCN_IP_NATIVE" ? each.value.networking.pods_nsg_ids != null ? [for nsg in each.value.networking.pods_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : [] : null : oci_containerengine_cluster.these[each.value.cluster_id].cluster_pod_network_options[0].cni_type == "OCI_VCN_IP_NATIVE" ? each.value.networking.pods_nsg_ids != null ? [for nsg in each.value.networking.pods_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : [] : null
  }
  size = each.value.size
  dynamic "taints" {
    for_each = each.value.taints != null ? each.value.taints : []
    iterator = taint
    content {
      effect = taint.value.effect
      key    = taint.value.key
      value  = taint.value.value
    }
  }
  virtual_node_tags {
    defined_tags  = each.value.virtual_nodes_defined_tags != null ? each.value.virtual_nodes_defined_tags : var.workers_configuration.default_defined_tags
    freeform_tags = merge(local.cislz_module_tag, each.value.virtual_nodes_freeform_tags != null ? each.value.virtual_nodes_freeform_tags : var.workers_configuration.default_freeform_tags)
  }
}
