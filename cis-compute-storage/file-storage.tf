# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_identity_availability_domains" "fs_ads" {
  for_each       = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_systems"] != null ? var.storage_configuration["file_storage"]["file_systems"] : {}) : {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_file_storage_file_system" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_systems"] != null ? var.storage_configuration["file_storage"]["file_systems"] : {}) : {}) : {}
  lifecycle {
    precondition {
      condition     = coalesce(each.value.cis_level, var.storage_configuration.default_cis_level, "1") == "2" ? each.value.kms_key_id != null || var.storage_configuration.default_kms_key_id != null : true
      error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in file storage ${each.key}: A customer managed key is required when CIS level is set to 2. Either kms_key_id or default_kms_key_id must be provided."
    }
  }
  availability_domain           = data.oci_identity_availability_domains.fs_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  compartment_id                = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  display_name                  = each.value.file_system_name
  kms_key_id                    = each.value.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.kms_key_id)) > 0 ? each.value.kms_key_id : var.kms_dependency[each.value.kms_key_id].id) : var.storage_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.storage_configuration.default_kms_key_id)) > 0 ? var.storage_configuration.default_kms_key_id : var.kms_dependency[var.storage_configuration.default_kms_key_id].id) : null
  filesystem_snapshot_policy_id = each.value.snapshot_policy_id != null ? oci_file_storage_filesystem_snapshot_policy.these[each.value.snapshot_policy_id].id : (contains(keys(oci_file_storage_filesystem_snapshot_policy.defaults), each.key) ? oci_file_storage_filesystem_snapshot_policy.defaults[each.key].id : null)
  defined_tags                  = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags                 = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

data "oci_identity_availability_domains" "mt_ads" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_targets"] != null ? var.storage_configuration["file_storage"]["mount_targets"] : {}) : {}) : {}
  #compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_file_storage_mount_target" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_targets"] != null ? var.storage_configuration["file_storage"]["mount_targets"] : {}) : {}) : {}
  lifecycle {
    precondition {
      condition     = each.value.subnet_id != null || var.storage_configuration.file_storage.default_subnet_id != null
      error_message = "VALIDATION FAILURE in file system mount target \"${each.key}\": no subnet found for mount target. Either \"subnet_id\" or \"file_storage.default_subnet_id\" must be provided."
    }
  }
  compartment_id      = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  availability_domain = data.oci_identity_availability_domains.mt_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  display_name        = each.value.mount_target_name
  subnet_id           = each.value.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.subnet_id)) > 0 ? each.value.subnet_id : var.network_dependency["subnets"][each.value.subnet_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.file_storage.default_subnet_id)) > 0 ? var.storage_configuration.file_storage.default_subnet_id : var.network_dependency["subnets"][var.storage_configuration.file_storage.default_subnet_id].id)
  hostname_label      = each.value.hostname_label
  nsg_ids             = [for nsg in coalesce(each.value.network_security_groups, []) : (length(regexall("^ocid1.*$", nsg)) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id)]
  defined_tags        = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags       = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}


resource "oci_file_storage_export_set" "these" {
  for_each        = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_targets"] != null ? var.storage_configuration["file_storage"]["mount_targets"] : {}) : {}) : {}
  mount_target_id = oci_file_storage_mount_target.these[each.key].id
  display_name    = each.value.mount_target_name
}

locals {
  exports = flatten([
    for mt_key, mt in(var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["mount_targets"] != null ? var.storage_configuration["file_storage"]["mount_targets"] : {}) : {}) : {}) : [
      for exp in(mt["exports"] != null ? mt["exports"] : []) : {
        mt_key         = mt_key
        exp_key        = "${mt_key}.${exp.file_system_id}" #exp_key
        path           = exp.path
        file_system_id = exp.file_system_id
        options        = exp.options
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
  } }

  lifecycle {
    precondition {
      condition     = var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_systems"] != null ? (contains(keys(var.storage_configuration["file_storage"]["file_systems"]), each.value.file_system_id) == true ? true : false) : false) : false
      error_message = "VALIDATION FAILURE in file system mount target \"${each.key}\": file_system_id \"${each.value.file_system_id}\" not defined within \"file_systems\" attribute."
    }
  }
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
      require_privileged_source_port = option.value.use_privileged_source_port
    }
  }
}

locals {
  replicated_file_systems = { for k, v in(var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["file_systems"] != null ? var.storage_configuration["file_storage"]["file_systems"] : {}) : {}) : {}) : k => v if(v.replication != null ? (v.replication.file_system_target_id != null ? true : false) : false) }

}
resource "oci_file_storage_replication" "these" {
  for_each = local.replicated_file_systems
  lifecycle {
    precondition {
      condition     = each.value.replication.is_target == false
      error_message = "VALIDATION FAILURE in file system \"${each.key}\": a file system cannot be replication source and target at the same time. Either set \"file_system_target_id\" with the file system target replica id to make it a source, or set \"is_target\" to true to make it a target."
    }
  }
  compartment_id       = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  display_name         = "${each.value.file_system_name}-replication"
  source_id            = oci_file_storage_file_system.these[each.key].id
  target_id            = length(regexall("^ocid1.*$", each.value.replication.file_system_target_id)) > 0 ? each.value.replication.file_system_target_id : contains(keys(oci_file_storage_file_system.these), each.value.replication.file_system_target_id) ? oci_file_storage_file_system.these[each.value.replication.file_system_target_id].id : var.file_system_dependency[each.value.replication.file_system_target_id].id
  replication_interval = each.value.replication.interval_in_minutes
  defined_tags         = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags        = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

data "oci_identity_availability_domains" "snapshot_ads" {
  for_each       = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["snapshot_policies"] != null ? var.storage_configuration["file_storage"]["snapshot_policies"] : {}) : {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_file_storage_filesystem_snapshot_policy" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? (var.storage_configuration["file_storage"]["snapshot_policies"] != null ? var.storage_configuration["file_storage"]["snapshot_policies"] : {}) : {}) : {}
  #for_each = local.snapshot_policies
  compartment_id      = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  availability_domain = data.oci_identity_availability_domains.snapshot_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  display_name        = each.value.name
  policy_prefix       = each.value.prefix
  dynamic "schedules" {
    iterator = sch
    for_each = each.value.schedules != null ? each.value.schedules : []
    content {
      schedule_prefix               = sch.value["prefix"]
      period                        = sch.value["period"]
      time_zone                     = sch.value["time_zone"]
      hour_of_day                   = sch.value["hour_of_day"]
      day_of_week                   = sch.value["day_of_week"]
      day_of_month                  = sch.value["day_of_month"]
      month                         = sch.value["month"]
      retention_duration_in_seconds = sch.value["retention_in_seconds"]
      time_schedule_start           = sch.value["start_time"]
    }
  }
  defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

locals {
  file_systems_without_snapshot_policy = { for k, v in(var.storage_configuration != null ? (var.storage_configuration["file_storage"] != null ? var.storage_configuration["file_storage"]["file_systems"] : {}) : {}) : k => v if v.snapshot_policy_id == null }
  non_replica_file_systems             = { for k, v in local.file_systems_without_snapshot_policy : k => v if(v.replication != null ? (v.replication.is_target == true ? false : true) : true) }
}

# Default snapshot policies are created for all file systems without a snapshot policy. The policy is created in the same compartment and same availability domain as the file system itself. 
# No policy is created for file systems that are replica targets, as per above non_replica_file_systems variable.
resource "oci_file_storage_filesystem_snapshot_policy" "defaults" {
  for_each            = local.non_replica_file_systems
  availability_domain = data.oci_identity_availability_domains.fs_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  compartment_id      = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  display_name        = "${each.value.file_system_name}-default-snapshot-policy"
  policy_prefix       = each.value.file_system_name
  schedules {
    schedule_prefix               = "weekly"
    period                        = "WEEKLY"
    time_zone                     = "UTC"
    hour_of_day                   = 23
    day_of_week                   = "SUNDAY"
    day_of_month                  = null
    month                         = null
    retention_duration_in_seconds = null
    time_schedule_start           = null
  }
  defined_tags  = null
  freeform_tags = null
}