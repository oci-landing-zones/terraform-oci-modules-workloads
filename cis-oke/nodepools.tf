# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_containerengine_clusters" "existing" {
  for_each       = var.workers_configuration != null ? coalesce(var.workers_configuration["node_pools"],{}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
}

data "oci_containerengine_cluster_option" "kube_versions" {
  for_each          = var.workers_configuration != null ? coalesce(var.workers_configuration["node_pools"],{}) : {}
  cluster_option_id = "all"
  compartment_id    = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
}

data "oci_containerengine_node_pool_option" "np_option" {
  for_each            = var.workers_configuration != null ? coalesce(var.workers_configuration["node_pools"],{}) : {}
  node_pool_option_id = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? each.value.cluster_id : oci_containerengine_cluster.these[each.value.cluster_id].id
}

data "oci_identity_availability_domains" "ads" {
  for_each       = var.workers_configuration != null ? coalesce(var.workers_configuration["node_pools"],{}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
}

resource "oci_containerengine_node_pool" "these" {
  for_each = var.workers_configuration != null ? coalesce(var.workers_configuration["node_pools"],{}) : {}
  lifecycle {
    ## Check 1: Customer managed key must be provided if CIS profile level is "2".
    precondition {
      condition     = coalesce(each.value.cis_level, var.workers_configuration.default_cis_level, "1") == "2" ? (each.value.node_config_details.encryption != null ? (each.value.node_config_details.encryption.kms_key_id != null || var.workers_configuration.default_kms_key_id != null) : var.workers_configuration.default_kms_key_id != null) : true # false triggers this.
      error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in nodepool \"${each.key}\": a customer managed key is required when CIS level is set to 2. Either \"encryption.kms_key_id\" or \"default_kms_key_id\" must be provided."
    }
    ## Check 2: The kubernetes version of the worker nodes must not run a more recent version or be more than two versions behind than the associated OKE Cluster.
    precondition {
      condition     = each.value.kubernetes_version != null ? length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? (contains(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) && contains(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0]) ? index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) <= index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0]) ? index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0]) - index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) <= 2 ? true : false : false : false) : (contains(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) && contains(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version) ? index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) <= index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version) ? index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version) - index(data.oci_containerengine_cluster_option.kube_versions[each.key].kubernetes_versions, each.value.kubernetes_version) <= 2 ? true : false : false : false) : true
      error_message = "VALIDATION FAILURE in in nodepool \"${each.key}\": The kubernetes version of the worker nodes must not run a more recent version or be more than two versions behind than the associated OKE Cluster. "
    }
    ## Check 3: Image validation with kubernetes version.
    precondition {
      condition     = each.value.node_config_details.image != null ? length(regexall("^ocid1.*$", each.value.node_config_details.image)) > 0 ? length([for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall(each.value.node_config_details.image, source.image_id)) > 0]) > 0 ? true : false : length([for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.source_name if length(regexall("Oracle-Linux-${each.value.node_config_details.image}", source.source_name)) > 0]) > 0 ? true : false : true
      error_message = "VALIDATION FAILURE in in nodepool \"${each.key}\": The image ocid or version is not available for the Worker nodes using that kubernetes_version."
    }
    ## Check 4: Compartment validation when the cluster is not created with terraform.
    precondition {
      condition     = each.value.compartment_id != null ? true : var.workers_configuration.default_compartment_id != null ? true : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? false : true
      error_message = "VALIDATION FAILURE in in nodepool \"${each.key}\": One of the attributes compartment_id or default_compartment_id must be used when specifying an ocid in the cluster_id attribute."
    }
  }
  cluster_id     = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? each.value.cluster_id : oci_containerengine_cluster.these[each.value.cluster_id].id
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : var.workers_configuration.default_compartment_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_compartment_id)) > 0 ? var.workers_configuration.default_compartment_id : var.compartments_dependency[var.workers_configuration.default_compartment_id].id) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? null : oci_containerengine_cluster.these[each.value.cluster_id].compartment_id
  name           = each.value.name
  node_shape     = each.value.node_config_details.node_shape
  defined_tags   = each.value.defined_tags != null ? each.value.defined_tags : var.workers_configuration.default_defined_tags
  freeform_tags  = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.workers_configuration.default_freeform_tags)
  dynamic "initial_node_labels" {
    for_each = each.value.initial_node_labels != null ? each.value.initial_node_labels : var.workers_configuration.default_initial_node_labels != null ? var.workers_configuration.default_initial_node_labels : {}
    iterator = label
    content {
      key   = label.key
      value = label.value
    }
  }
  kubernetes_version = each.value.kubernetes_version != null ? each.value.kubernetes_version : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0] : oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version
  node_config_details {
    dynamic "placement_configs" {
      for_each = each.value.node_config_details.placement != null ? each.value.node_config_details.placement : tolist([(tomap({ 1 = 1 }))])
      iterator = pc
      content {
        availability_domain     = each.value.node_config_details.placement != null ? data.oci_identity_availability_domains.ads[each.key].availability_domains[(pc.value.availability_domain != null ? pc.value.availability_domain : 1) - 1].name : data.oci_identity_availability_domains.ads[each.key].availability_domains[0].name
        subnet_id               = length(regexall("^ocid1.*$", each.value.networking.workers_subnet_id)) > 0 ? each.value.networking.workers_subnet_id : var.network_dependency["subnets"][each.value.networking.workers_subnet_id].id
        capacity_reservation_id = each.value.node_config_details.capacity_reservation_id != null ? each.value.node_config_details.capacity_reservation_id : null
        fault_domains           = each.value.node_config_details.placement != null ? pc.value.fault_domain != null ? [format("FAULT-DOMAIN-%s", pc.value.fault_domain)] : null : null
        dynamic "preemptible_node_config" {
          for_each = each.value.node_config_details.boot_volume != null ? each.value.node_config_details.boot_volume.preserve_boot_volume != null ? [1] : [] : []
          content {
            preemption_action {
              type                    = "TERMINATE"
              is_preserve_boot_volume = each.value.node_config_details.boot_volume != null ? coalesce(each.value.node_config_details.boot_volume.preserve_boot_volume,false) : false
            }
          }
        }
      }
    }
    size                                = each.value.size
    is_pv_encryption_in_transit_enabled = each.value.node_config_details.encryption != null ? each.value.node_config_details.encryption.enable_encrypt_in_transit : null
    kms_key_id                          = each.value.node_config_details.encryption != null ? (each.value.node_config_details.encryption.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.node_config_details.encryption.kms_key_id)) > 0 ? each.value.node_config_details.encryption.kms_key_id : var.kms_dependency[each.value.node_config_details.encryption.kms_key_id].id) : (var.workers_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_kms_key_id)) > 0 ? var.workers_configuration.default_kms_key_id : var.kms_dependency[var.workers_configuration.default_kms_key_id].id) : null)) : (var.workers_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.workers_configuration.default_kms_key_id)) > 0 ? var.workers_configuration.default_kms_key_id : var.kms_dependency[var.workers_configuration.default_kms_key_id].id) : null)
    node_pool_pod_network_option_details {
      cni_type          = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.cluster_pod_network_options[0].cni_type if cluster.id == each.value.cluster_id][0] : oci_containerengine_cluster.these[each.value.cluster_id].cluster_pod_network_options[0].cni_type
      max_pods_per_node = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.cluster_pod_network_options[0].cni_type if cluster.id == each.value.cluster_id][0] == "OCI_VCN_IP_NATIVE" ? each.value.networking.max_pods_per_node != null ? min(max(each.value.networking.max_pods_per_node, 1), 110) : null : null : oci_containerengine_cluster.these[each.value.cluster_id].cluster_pod_network_options[0].cni_type == "OCI_VCN_IP_NATIVE" ? each.value.networking.max_pods_per_node != null ? min(max(each.value.networking.max_pods_per_node, 1), 110) : null : null
      pod_nsg_ids       = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.cluster_pod_network_options[0].cni_type if cluster.id == each.value.cluster_id][0] == "OCI_VCN_IP_NATIVE" ? each.value.networking.pods_nsg_ids != null ? [for nsg in each.value.networking.pods_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : [] : null : oci_containerengine_cluster.these[each.value.cluster_id].cluster_pod_network_options[0].cni_type == "OCI_VCN_IP_NATIVE" ? each.value.networking.pods_nsg_ids != null ? [for nsg in each.value.networking.pods_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : [] : null
      pod_subnet_ids    = length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.cluster_pod_network_options[0].cni_type if cluster.id == each.value.cluster_id][0] == "OCI_VCN_IP_NATIVE" ? length(regexall("^ocid1.*$", each.value.networking.pods_subnet_id)) > 0 ? [each.value.networking.pods_subnet_id] : [var.network_dependency["subnets"][each.value.networking.pods_subnet_id].id] : null : oci_containerengine_cluster.these[each.value.cluster_id].cluster_pod_network_options[0].cni_type == "OCI_VCN_IP_NATIVE" ? length(regexall("^ocid1.*$", each.value.networking.pods_subnet_id)) > 0 ? [each.value.networking.pods_subnet_id] : [var.network_dependency["subnets"][each.value.networking.pods_subnet_id].id] : null
    }
    defined_tags  = each.value.node_config_details.defined_tags != null ? each.value.node_config_details.defined_tags : var.workers_configuration.default_defined_tags
    freeform_tags = merge(local.cislz_module_tag, each.value.node_config_details.freeform_tags != null ? each.value.node_config_details.freeform_tags : var.workers_configuration.default_freeform_tags)
    nsg_ids       = each.value.networking.workers_nsg_ids != null ? [for nsg in each.value.networking.workers_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : []
  }
  node_eviction_node_pool_settings {
    eviction_grace_duration = each.value.node_config_details.node_eviction != null ? each.value.node_config_details.node_eviction.grace_duration != null ? (floor(tonumber(each.value.node_config_details.node_eviction.grace_duration) / 60) > 0 ?
      (each.value.node_config_details.node_eviction.grace_duration >= 3600 ?
        format("PT%dH", 1) :
        (each.value.node_config_details.node_eviction.grace_duration % 60 == 0 ?
          format("PT%dM", floor(each.value.node_config_details.node_eviction.grace_duration / 60)) :
          format("PT%dM%dS", floor(each.value.node_config_details.node_eviction.grace_duration / 60), each.value.node_config_details.node_eviction.grace_duration % 60)
        )
      ) :
      format("PT%dS", each.value.node_config_details.node_eviction.grace_duration)
    ) : "PT1H" : "PT1H"
    is_force_delete_after_grace_duration = each.value.node_config_details.node_eviction != null ? each.value.node_config_details.node_eviction.force_delete != null ? each.value.node_config_details.node_eviction.force_delete : false : false
  }
  dynamic "node_pool_cycling_details" {
    for_each = each.value.node_config_details.node_cycling != null ? length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? length(regexall("^ENHANCED.*$", [for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.type if cluster.id == each.value.cluster_id][0])) > 0 ? [1] : [] : length(regexall("^ENHANCED.*$", oci_containerengine_cluster.these[each.value.cluster_id].type)) > 0 ? [1] : [] : []
    content {
      is_node_cycling_enabled = each.value.node_config_details.node_cycling != null ? each.value.node_config_details.node_cycling.enable_cycling != null ? each.value.node_config_details.node_cycling.enable_cycling : false : false
      maximum_surge           = each.value.node_config_details.node_cycling != null ? each.value.node_config_details.node_cycling.max_surge != null ? each.value.node_config_details.node_cycling.max_surge : 1 : 1
      maximum_unavailable     = each.value.node_config_details.node_cycling != null ? each.value.node_config_details.node_cycling.max_unavailable != null ? each.value.node_config_details.node_cycling.max_unavailable : 0 : 0
    }
  }
  dynamic "node_shape_config" {
    for_each = length(regexall("Flex", each.value.node_config_details.node_shape)) > 0 ? [each.value.node_config_details.node_shape] : []
    content {
      memory_in_gbs = each.value.node_config_details.flex_shape_settings != null ? coalesce(each.value.node_config_details.flex_shape_settings.memory,16) : 16
      ocpus         = each.value.node_config_details.flex_shape_settings != null ? coalesce(each.value.node_config_details.flex_shape_settings.ocpus,1) : 1
    }
  }
  node_source_details {
    image_id                = each.value.node_config_details.image != null ? length(regexall("^ocid1.*$", each.value.node_config_details.image)) > 0 ? each.value.node_config_details.image : each.value.kubernetes_version != null ? element([for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-${each.value.node_config_details.image}-20[0-9]*.*-OKE-${substr(each.value.kubernetes_version, 1, -1)}", source.source_name)) > 0], 0) : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? element([for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-${each.value.node_config_details.image}-20[0-9]*.*-OKE-${substr([for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0], 1, -1)}", source.source_name)) > 0], 0) : element([for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-${each.value.node_config_details.image}-20[0-9]*.*-OKE-${substr(oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version, 1, -1)}", source.source_name)) > 0], 0) : each.value.kubernetes_version != null ? [for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-[0-9].[0-9]-20[0-9]*.*-OKE-${substr(each.value.kubernetes_version, 1, -1)}", source.source_name)) > 0][0] : length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? [for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-[0-9].[0-9]-20[0-9]*.*-OKE-${substr([for cluster in data.oci_containerengine_clusters.existing[each.key].clusters : cluster.kubernetes_version if cluster.id == each.value.cluster_id][0], 1, -1)}", source.source_name)) > 0][0] : [for source in data.oci_containerengine_node_pool_option.np_option[each.key].sources : source.image_id if length(regexall("Oracle-Linux-[0-9].[0-9]-20[0-9]*.*-OKE-${substr(oci_containerengine_cluster.these[each.value.cluster_id].kubernetes_version, 1, -1)}", source.source_name)) > 0][0]
    source_type             = "image"
    boot_volume_size_in_gbs = each.value.node_config_details.boot_volume != null ? coalesce(each.value.node_config_details.boot_volume.size,60) : 60
  }
  node_metadata = {
      user_data = contains(keys(data.template_file.cloud_config),each.key) ? base64encode(data.template_file.cloud_config[each.key].rendered) : null
    }
  ssh_public_key = each.value.node_config_details.ssh_public_key_path != null ? (fileexists(each.value.node_config_details.ssh_public_key_path) ? file(each.value.node_config_details.ssh_public_key_path) : each.value.node_config_details.ssh_public_key_path) : var.workers_configuration.default_ssh_public_key_path != null ? (fileexists(var.workers_configuration.default_ssh_public_key_path) ? file(var.workers_configuration.default_ssh_public_key_path) : var.workers_configuration.default_ssh_public_key_path): null
}

data "template_file" "cloud_config" {
  for_each = var.workers_configuration != null ? {for k, v in var.workers_configuration["node_pools"] : k => v if v.node_config_details.cloud_init != null || var.workers_configuration.default_cloud_init_heredoc_script != null || var.workers_configuration.default_cloud_init_script_file != null} : {}
    template = coalesce(try(each.value.node_config_details.cloud_init.heredoc_script,null), try(file(try(each.value.node_config_details.cloud_init.script_file,null)),null), var.workers_configuration.default_cloud_init_heredoc_script, try(file(var.workers_configuration.default_cloud_init_script_file),null), "__void__")
}