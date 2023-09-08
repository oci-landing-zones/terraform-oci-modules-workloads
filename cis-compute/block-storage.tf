locals {
  oracle_backup_policies = {
    gold   = "ocid1.volumebackuppolicy.oc1..aaaaaaaagcremuefit7dpcnjpdrtphjk4bwm3emm55t6cghctt2m6iyyjdva"
    silver = "ocid1.volumebackuppolicy.oc1..aaaaaaaa7hwv7iscewqqcmyqe2zuzfce6setvckhbxduswtxf6ctew7e54ja"
    bronze = "ocid1.volumebackuppolicy.oc1..aaaaaaaadrzfwjb5tflixtmy5axp2kx65uqakgnupfogabzjhtn5x5dfra6q"
  }
  volumes_with_backup_policies = {for k, v in (var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}) : k => v if v.backup_policy != null} 

  volumes_to_replicate = {for k, v in (var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}) : k => v if v.replication != null} 
}

data "oci_identity_availability_domains" "bv_ads" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

data "oci_identity_availability_domains" "bv_ads_replicas" {
  provider = oci.block_volumes_replication_region
  for_each = local.volumes_to_replicate
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_core_volume" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}) : {}
  lifecycle {
      precondition {
        condition = coalesce(each.value.cis_level,var.storage_configuration.default_cis_level,"1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kms_key_id != null || var.storage_configuration.default_kms_key_id != null) : var.storage_configuration.default_kms_key_id != null) : true
        error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in block volume ${each.key}: A customer managed key is required when CIS level is set to 2. Either encryption.kms_key_id or default_kms_key_id must be provided."
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
    defined_tags  = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
    freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
}

resource "oci_core_volume_attachment" "these" {
  for_each = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? [for bv in var.storage_configuration["block_volumes"] : bv.attach_to_instance != null ? var.storage_configuration["block_volumes"] : {}][0] : {}) : {}
    lifecycle {
      precondition {
        condition = contains(keys(oci_core_instance.these),each.value.attach_to_instance.instance_id) || (var.instances_dependency != null ? contains(keys(var.instances_dependency),each.value.attach_to_instance.instance_id) : true)
        error_message = "VALIDATION FAILURE when attaching block volume to instance. Instance referred by \"${each.value.attach_to_instance.instance_id}\" not found."
      }
    }
    #attachment_type                     = lower(var.instances_configuration["instances"][each.value.attach_to_instance.instance_id].device_mounting.emulation_type)
    attachment_type                     = contains(keys(oci_core_instance.these),each.value.attach_to_instance.instance_id) ? oci_core_instance.these[each.value.attach_to_instance.instance_id].launch_options[0].remote_data_volume_type : (contains(keys(var.instances_dependency),each.value.attach_to_instance.instance_id) ? var.instances_dependency[each.value.attach_to_instance.instance_id].launch_options[0].remote_data_volume_type : null)
    instance_id                         = contains(keys(oci_core_instance.these),each.value.attach_to_instance.instance_id) ? oci_core_instance.these[each.value.attach_to_instance.instance_id].id : (contains(keys(var.instances_dependency),each.value.attach_to_instance.instance_id) ? var.instances_dependency[each.value.attach_to_instance.instance_id].id : null)
    volume_id                           = oci_core_volume.these[each.key].id
    device                              = each.value.attach_to_instance.device_name
    #is_pv_encryption_in_transit_enabled = upper(var.instances_configuration["instances"][each.value.attach_to_instance.instance_id].device_mounting.emulation_type) == "PARAVIRTUALIZED" ? (each.value.encryption != null ? each.value.encryption.encrypt_in_transit : true) : true
    is_pv_encryption_in_transit_enabled = contains(keys(oci_core_instance.these),each.value.attach_to_instance.instance_id) ? oci_core_instance.these[each.value.attach_to_instance.instance_id].is_pv_encryption_in_transit_enabled : (contains(keys(var.instances_dependency),each.value.attach_to_instance.instance_id) ? var.instances_dependency[each.value.attach_to_instance.instance_id].is_pv_encryption_in_transit_enabled : false)
}

resource "oci_core_volume_backup_policy_assignment" "these" {
  for_each = local.volumes_with_backup_policies
    lifecycle {
      precondition {
        condition = contains(keys(local.oracle_backup_policies),lower(each.value.backup_policy))
        error_message = "VALIDATION FAILURE in block volume ${each.key}: Invalid backup policy name \"${each.value.backup_policy}\". Valid values are: \"gold\", \"silver\" or \"bronze\" (case insensitive)."
      }
    }
    asset_id  = oci_core_volume.these[each.key].id
    policy_id = local.oracle_backup_policies[lower(each.value.backup_policy)]
}
