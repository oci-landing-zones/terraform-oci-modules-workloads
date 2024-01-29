# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  found_vcn_duplicates = join(" ; ", [for k, v in { for k, v in { for key1, value1 in { for cluster in var.clusters_configuration["clusters"] : cluster.name => cluster.networking.vcn_id } : value1 => [for key2, value2 in { for cluster in var.clusters_configuration["clusters"] : cluster.name => cluster.networking.vcn_id } : key1 if key1 != key2 && value1 == value2]... } : k => join(", ", flatten(v)) if length(v) > 1 } : "${k} = ${v}"])
}

data "oci_containerengine_cluster_option" "cluster_options" {
  for_each          = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  cluster_option_id = "all"
  compartment_id    = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.clusters_configuration.default_compartment_id)) > 0 ? var.clusters_configuration.default_compartment_id : var.compartments_dependency[var.clusters_configuration.default_compartment_id].id)
}

data "oci_core_subnet" "subnet" {
  for_each  = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  subnet_id = length(regexall("^ocid1.*$", each.value.networking.endpoint_subnet_id)) > 0 ? each.value.networking.endpoint_subnet_id : var.network_dependency["subnets"][each.value.networking.endpoint_subnet_id].id
}

resource "oci_containerengine_cluster" "these" {
  for_each = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  lifecycle {
    ## Check 1: Customer managed key must be provided if CIS profile level is "2".
    precondition {
      condition     = coalesce(each.value.cis_level, var.clusters_configuration.default_cis_level, "1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kube_secret_kms_key_id != null || var.clusters_configuration.default_kube_secret_kms_key_id != null) : var.clusters_configuration.default_kube_secret_kms_key_id != null) : true # false triggers this.
      error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in cluster \"${each.key}\": a customer managed key is required when CIS level is set to 2. Either \"encryption.kube_secret_kms_key_id\" or \"default_kube_secret_kms_key_id\" must be provided."
    }
    ## Check 2: Kubernetes version validation.
    precondition {
      condition     = each.value.kubernetes_version != null ? contains(data.oci_containerengine_cluster_option.cluster_options[each.key].kubernetes_versions, each.value.kubernetes_version) : true
      error_message = "VALIDATION FAILURE in cluster \"${each.key}\": Supported values for kubernetes_version are: ${join(",", data.oci_containerengine_cluster_option.cluster_options[each.key].kubernetes_versions)}"
    }
    ## Check 3: Network validation, only one cluster per vcn.
    precondition {
      condition     = length(local.found_vcn_duplicates) > 0 ? false : true
      error_message = "VALIDATION FAILURE in cluster \"${each.key}\": Cannot specify the same VCN for more than 1 OKE Cluster. Duplicates found: ${local.found_vcn_duplicates}"
    }
    ## Check 4: CNI type validation.
    precondition {
      condition     = lower(each.value.cni_type) == "flannel" || lower(each.value.cni_type) == "native"
      error_message = " VALIDATION FAILURE in cluster \"${each.key}\": Supported values for cni_type are flannel or native."
    }
    ## Check 5: Network validation, private endpoint in private subnet.
    precondition {
      condition     = each.value.networking.public_endpoint == true ? data.oci_core_subnet.subnet[each.key].prohibit_internet_ingress == false ? true : false : true
      error_message = "VALIDATION FAILURE in cluster \"${each.key}\": Cannot specify public endpoint on a private subnet."
    }
  }
  compartment_id     = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.clusters_configuration.default_compartment_id)) > 0 ? var.clusters_configuration.default_compartment_id : var.compartments_dependency[var.clusters_configuration.default_compartment_id].id)
  kubernetes_version = each.value.kubernetes_version != null ? each.value.kubernetes_version : reverse(data.oci_containerengine_cluster_option.cluster_options[each.key].kubernetes_versions)[0]
  name               = each.value.name
  vcn_id             = length(regexall("^ocid1.*$", each.value.networking.vcn_id)) > 0 ? each.value.networking.vcn_id : var.network_dependency["vcns"][each.value.networking.vcn_id].id
  cluster_pod_network_options {
    cni_type = lower(each.value.cni_type) == "native" ? "OCI_VCN_IP_NATIVE" : "FLANNEL_OVERLAY"
  }
  defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.clusters_configuration.default_defined_tags
  freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.clusters_configuration.default_freeform_tags)
  endpoint_config {
    is_public_ip_enabled = each.value.networking.public_endpoint != null ? each.value.networking.public_endpoint : false
    nsg_ids              = each.value.networking.api_nsg_ids != null ? [for nsg in each.value.networking.api_nsg_ids : (length(regexall("^ocid1.*$", nsg))) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id] : []
    subnet_id            = length(regexall("^ocid1.*$", each.value.networking.endpoint_subnet_id)) > 0 ? each.value.networking.endpoint_subnet_id : var.network_dependency["subnets"][each.value.networking.endpoint_subnet_id].id
  }
  dynamic "image_policy_config" {
    for_each = each.value.encryption != null ? each.value.encryption.image_policy_enabled ? [1] : [] : []
    content {
      is_policy_enabled = each.value.encryption.image_policy_enabled
      key_details {
        kms_key_id = each.value.encryption != null ? (each.value.encryption.img_kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.img_kms_key_id)) > 0 ? each.value.encryption.img_kms_key_id : var.kms_dependency[each.value.encryption.img_kms_key_id].id) : (var.clusters_configuration.default_img_kms_key_id != null ? (length(regexall("^ocid1.*$", var.clusters_configuration.default_img_kms_key_id)) > 0 ? var.clusters_configuration.default_img_kms_key_id : var.kms_dependency[var.clusters_configuration.default_img_kms_key_id].id) : null)) : (var.clusters_configuration.default_img_kms_key_id != null ? (length(regexall("^ocid1.*$", var.clusters_configuration.default_img_kms_key_id)) > 0 ? var.clusters_configuration.default_img_kms_key_id : var.kms_dependency[var.clusters_configuration.default_img_kms_key_id].id) : null)
      }
    }
  }
  kms_key_id = each.value.encryption != null ? (each.value.encryption.kube_secret_kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.kube_secret_kms_key_id)) > 0 ? each.value.encryption.kube_secret_kms_key_id : var.kms_dependency[each.value.encryption.kube_secret_kms_key_id].id) : (var.clusters_configuration.default_kube_secret_kms_key_id != null ? (length(regexall("^ocid1.*$", var.clusters_configuration.default_kube_secret_kms_key_id)) > 0 ? var.clusters_configuration.default_kube_secret_kms_key_id : var.kms_dependency[var.clusters_configuration.default_kube_secret_kms_key_id].id) : null)) : (var.clusters_configuration.default_kube_secret_kms_key_id != null ? (length(regexall("^ocid1.*$", var.clusters_configuration.default_kube_secret_kms_key_id)) > 0 ? var.clusters_configuration.default_kube_secret_kms_key_id : var.kms_dependency[var.clusters_configuration.default_kube_secret_kms_key_id].id) : null)
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = each.value.options != null ? each.value.options.add_ons != null ? each.value.options.add_ons.dashboard_enabled : false : false
      is_tiller_enabled               = each.value.options != null ? each.value.options.add_ons != null ? each.value.options.add_ons.tiller_enabled : false : false
    }
    admission_controller_options {
      is_pod_security_policy_enabled = each.value.options != null ? each.value.options.admission_controller != null ? each.value.options.admission_controller.pod_policy_enabled : false : false
    }
    kubernetes_network_config {
      pods_cidr     = each.value.options != null ? each.value.options.kubernetes_network_config != null ? each.value.options.kubernetes_network_config.pods_cidr != null ? each.value.options.kubernetes_network_config.pods_cidr : null : null : null
      services_cidr = each.value.options != null ? each.value.options.kubernetes_network_config != null ? each.value.options.kubernetes_network_config.services_cidr != null ? each.value.options.kubernetes_network_config.services_cidr : null : null : null
    }
    persistent_volume_config {
      defined_tags  = each.value.options != null ? each.value.options.persistent_volume_config != null ? each.value.options.persistent_volume_config.defined_tags != null ? each.value.options.persistent_volume_config.defined_tags : var.clusters_configuration.default_defined_tags : var.clusters_configuration.default_defined_tags : var.clusters_configuration.default_defined_tags
      freeform_tags = merge(local.cislz_module_tag, each.value.options != null ? each.value.options.persistent_volume_config != null ? each.value.options.persistent_volume_config.freeform_tags != null ? each.value.options.persistent_volume_config.freeform_tags : var.clusters_configuration.default_freeform_tags : var.clusters_configuration.default_freeform_tags : var.clusters_configuration.default_freeform_tags)
    }
    service_lb_config {
      defined_tags  = each.value.options != null ? each.value.options.service_lb_config != null ? each.value.options.service_lb_config.defined_tags != null ? each.value.options.service_lb_config.defined_tags : var.clusters_configuration.default_defined_tags : var.clusters_configuration.default_defined_tags : var.clusters_configuration.default_defined_tags
      freeform_tags = merge(local.cislz_module_tag, each.value.options != null ? each.value.options.service_lb_config != null ? each.value.options.service_lb_config.freeform_tags != null ? each.value.options.service_lb_config.freeform_tags : var.clusters_configuration.default_freeform_tags : var.clusters_configuration.default_freeform_tags : var.clusters_configuration.default_freeform_tags)
    }
    service_lb_subnet_ids = each.value.networking.services_subnet_id != null ? [for lb_sub in each.value.networking.services_subnet_id : (length(regexall("^ocid1.*$", lb_sub)) > 0 ? lb_sub : var.network_dependency["subnets"][lb_sub].id)] : []
  }
  type = each.value.is_enhanced == true ? "ENHANCED_CLUSTER" : "BASIC_CLUSTER"
}  
