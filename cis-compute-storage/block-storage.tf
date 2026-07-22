data "oci_core_volume_backup_policies" "oracle_backup_policies" {}

locals {
  oracle_backup_policies             = tomap({ for policy in data.oci_core_volume_backup_policies.oracle_backup_policies.volume_backup_policies : policy.display_name => policy.id })
  oracle_managed_backup_policy_names = toset(["gold", "silver", "bronze"])

  custom_backup_policies = var.storage_configuration != null ? var.storage_configuration.custom_backup_policies : {}

  volumes_with_backup_policies = { for k, v in(var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}) : k => v if v.backup_policy != null }

  volumes_to_replicate = { for k, v in(var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}) : k => v if v.replication != null }
}

resource "oci_core_volume_backup_policy" "custom" {
  for_each = local.custom_backup_policies
  lifecycle {
    precondition {
      condition     = !contains(local.oracle_managed_backup_policy_names, lower(each.key))
      error_message = "VALIDATION FAILURE in custom backup policy \"${each.key}\": its key conflicts with the Oracle managed backup policy \"${lower(each.key)}\". Choose a different key."
    }
    precondition {
      condition     = length(each.value.schedules) > 0
      error_message = "VALIDATION FAILURE in custom backup policy \"${each.key}\": at least one backup schedule is required."
    }
  }
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  display_name   = coalesce(each.value.display_name, each.key)
  dynamic "schedules" {
    for_each = each.value.schedules
    content {
      backup_type       = schedules.value.backup_type
      period            = schedules.value.period
      retention_seconds = schedules.value.retention_seconds
      offset_type       = schedules.value.offset_type
      offset_seconds    = schedules.value.offset_seconds
      hour_of_day       = schedules.value.hour_of_day
      day_of_week       = schedules.value.day_of_week
      day_of_month      = schedules.value.day_of_month
      month             = schedules.value.month
      time_zone         = schedules.value.time_zone
    }
  }
  defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

data "oci_identity_availability_domains" "bv_ads" {
  for_each       = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

data "oci_identity_availability_domains" "bv_ads_replicas" {
  provider       = oci.block_volumes_replication_region
  for_each       = local.volumes_to_replicate
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_core_volume" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}
  lifecycle {
    precondition {
      condition     = coalesce(each.value.cis_level, var.storage_configuration.default_cis_level, "1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kms_key_id != null || var.storage_configuration.default_kms_key_id != null) : var.storage_configuration.default_kms_key_id != null) : true
      error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in block volume \"${each.key}\": A customer managed key is required when CIS level is set to 2. Either \"encryption.kms_key_id\" or \"default_kms_key_id\" must be provided."
    }
  }
  availability_domain = data.oci_identity_availability_domains.bv_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  compartment_id      = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  display_name        = each.value.display_name
  size_in_gbs         = each.value.volume_size
  vpus_per_gb         = each.value.vpus_per_gb
  kms_key_id          = each.value.encryption != null ? (each.value.encryption.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.kms_key_id)) > 0 ? each.value.encryption.kms_key_id : var.kms_dependency[each.value.encryption.kms_key_id].id) : (var.storage_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.storage_configuration.default_kms_key_id)) > 0 ? var.storage_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)) : (var.storage_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.storage_configuration.default_kms_key_id)) > 0 ? var.storage_configuration.default_kms_key_id : var.kms_dependency[var.storage_configuration.default_kms_key_id].id) : null)
  dynamic "block_volume_replicas" {
    for_each = each.value.replication != null ? [1] : []
    content {
      availability_domain = data.oci_identity_availability_domains.bv_ads_replicas[each.key].availability_domains[each.value.replication.availability_domain - 1].name
      display_name        = "${each.value.display_name}-replica"
    }
  }
  dynamic "source_details" {
    for_each = each.value.source != null ? [1] : []
    content {
      type = each.value.source.type
      id   = each.value.source.id
    }
  }
  defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

locals {
  bv_attachments = flatten([
    for bv_key, bv_value in(var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}) : [
      for attach in(bv_value.attach_to_instances != null ? bv_value.attach_to_instances : []) : {
        key                                 = "${bv_key}.${attach.instance_id}"
        bv_key                              = bv_key
        type                                = attach.attachment_type
        instance_id                         = attach.instance_id
        volume_id                           = oci_core_volume.these[bv_key].id
        device                              = attach.device_name
        is_read_only                        = attach.read_only
        is_pv_encryption_in_transit_enabled = bv_value.encryption != null ? bv_value.encryption.encrypt_in_transit : false
      }
    ]
  ])
}

resource "oci_core_volume_attachment" "these" {
  for_each = { for attach in local.bv_attachments : attach.key => {
    attachment_type                     = attach.type
    instance_id                         = attach.instance_id
    volume_id                           = attach.volume_id
    device                              = attach.device
    is_read_only                        = attach.is_read_only
    is_pv_encryption_in_transit_enabled = attach.is_pv_encryption_in_transit_enabled
    bv_key                              = attach.bv_key
  } }
  lifecycle {
    precondition {
      condition     = contains(keys(oci_core_instance.these), each.value.instance_id) || (var.instances_dependency != null ? contains(keys(var.instances_dependency), each.value.instance_id) : true)
      error_message = "VALIDATION FAILURE when attaching block volume to instance. Instance referred by \"${each.value.instance_id}\" not found."
    }
  }
  attachment_type = each.value.attachment_type
  instance_id     = contains(keys(oci_core_instance.these), each.value.instance_id) ? oci_core_instance.these[each.value.instance_id].id : (contains(keys(var.instances_dependency), each.value.instance_id) ? var.instances_dependency[each.value.instance_id].id : null)
  volume_id       = each.value.volume_id
  device          = each.value.device
  # is_shareable is automatically set to true if there is more than one instance attachment to the same volume. 
  # We are testing the length of a list with block volume keys that are equal to the attachment key (each.bv_key)
  # If there's more than one element, it means the volume is attached to more than one instance and we set is_shareable to true.
  is_shareable                        = length([for a in local.bv_attachments : a.bv_key if a.bv_key == each.value.bv_key]) > 1 ? true : false
  is_read_only                        = each.value.is_read_only
  is_pv_encryption_in_transit_enabled = each.value.is_pv_encryption_in_transit_enabled
}

resource "oci_core_volume_backup_policy_assignment" "these" {
  for_each = local.volumes_with_backup_policies
  lifecycle {
    precondition {
      condition     = contains(local.oracle_managed_backup_policy_names, lower(each.value.backup_policy)) || contains(keys(oci_core_volume_backup_policy.custom), each.value.backup_policy)
      error_message = "VALIDATION FAILURE in block volume ${each.key}: backup policy \"${each.value.backup_policy}\" was not found. Provide an Oracle managed policy name (gold, silver, or bronze) or a custom_backup_policies map key."
    }
  }
  asset_id  = oci_core_volume.these[each.key].id
  policy_id = contains(local.oracle_managed_backup_policy_names, lower(each.value.backup_policy)) ? local.oracle_backup_policies[lower(each.value.backup_policy)] : oci_core_volume_backup_policy.custom[each.value.backup_policy].id
}
