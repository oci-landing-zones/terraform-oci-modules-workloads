# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_identity_availability_domains" "fs_ads" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_system"] != null ? var.storage_configuration["file_storage"]["file_system"] : {}) : {}) : {}
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_file_storage_file_system" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_system"] != null ? var.storage_configuration["file_storage"]["file_system"] : {}) : {}) : {}
    availability_domain = data.oci_identity_availability_domains.fs_ads[each.key].availability_domains[each.value.availability_domain - 1].name
    #compartment_id      = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
    display_name        = each.value.file_system_name
    kms_key_id          = coalesce(each.value.cis_level,var.storage_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.kms_key_id)) > 0 ? each.value.kms_key_id : var.kms_dependency[each.value.kms_key_id].id) : var.storage_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.storage_configuration.default_kms_key_id)) > 0 ? var.storage_configuration.default_kms_key_id : var.kms_dependency[var.storage_configuration.default_kms_key_id].id) : try(substr(var.storage_configuration.default_kms_key_id, 0, 0))) : null
    #kms_key_id          = coalesce(var.storage_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : var.storage_configuration.default_kms_key_ocid != null ? var.storage_configuration.default_kms_key_ocid : try(substr(var.storage_configuration.default_kms_key_ocid, 0, 0))) : each.value.kms_key_id
}

data "oci_identity_availability_domains" "mt_ads" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}) : {}) : {}
    #compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_file_storage_mount_target" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}) : {}) : {}
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
    availability_domain = data.oci_identity_availability_domains.mt_ads[each.key].availability_domains[each.value.availability_domain - 1].name
    display_name        = each.value.mount_target_name
    #compartment_id      = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
    #subnet_id           = each.value.subnet_ocid != null ? each.value.subnet_ocid : var.storage_configuration.default_subnet_ocid
    subnet_id           = each.value.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.subnet_id)) > 0 ? each.value.subnet_id : var.network_dependency[each.value.subnet_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_subnet_id)) > 0 ? var.storage_configuration.default_subnet_id : var.network_dependency[var.storage_configuration.default_subnet_id].id)
}


resource "oci_file_storage_export_set" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}) : {}) : {}
    mount_target_id = oci_file_storage_mount_target.these[each.key].id
    display_name    = each.value.mount_target_name
}

locals {
  exports = flatten([
    for mt_key, mt in (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}) : {}): [
      for exp_key, exp in (mt["exports"] != null ? mt["exports"] : {}) : {
        mt_key  = mt_key
        exp_key = exp_key
        path    = exp.path
        file_system_id = exp.file_system_key
        options = exp.options
      } 
    ]
  ])
}

resource "oci_file_storage_export" "these" {
  for_each = { for export in local.exports : export.exp_key => {
                                                                  mt_key         = export.mt_key
                                                                  path           = export.path
                                                                  file_system_id = export.file_system_id
                                                                  options        = export.options
                                                                }}  

    export_set_id  = oci_file_storage_export_set.these[each.value.mt_key].id
    file_system_id = oci_file_storage_file_system.these[each.value.file_system_id].id
    path           = each.value.path

    dynamic "export_options" {
      for_each = each.value.options != null ? each.value.options : []
      iterator = option
      content {
        source                         = option.value.source
        access                         = option.value.access
        identity_squash                = option.value.identity
        require_privileged_source_port = option.value.use_port
      }
    }
}