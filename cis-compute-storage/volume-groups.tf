# Copyright (c) 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  volume_groups_to_replicate = { for k, v in(var.storage_configuration != null ? (var.storage_configuration["volume_groups"] != null ? var.storage_configuration["volume_groups"] : {}) : {}) : k => v if v.replication != null }
}

data "oci_identity_availability_domains" "vg_ads" {
  for_each       = var.storage_configuration != null ? (var.storage_configuration["volume_groups"] != null ? var.storage_configuration["volume_groups"] : {}) : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

data "oci_identity_availability_domains" "vg_ads_replicas" {
  provider       = oci.block_volumes_replication_region
  for_each       = local.volume_groups_to_replicate
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
}

resource "oci_core_volume_group" "these" {
  for_each            = var.storage_configuration != null ? (var.storage_configuration["volume_groups"] != null ? var.storage_configuration["volume_groups"] : {}) : {}
  availability_domain = data.oci_identity_availability_domains.vg_ads[each.key].availability_domains[each.value.availability_domain - 1].name
  compartment_id      = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.storage_configuration.default_compartment_id)) > 0 ? var.storage_configuration.default_compartment_id : var.compartments_dependency[var.storage_configuration.default_compartment_id].id)
  source_details {
    #Required
    type                    = each.value.type
    volume_ids              = each.value.type == "volumeIds" ? each.value.volume_ids != null ? each.value.volume_ids : null : null
    volume_group_backup_id  = each.value.type == "volumeGroupBackupId" ? each.value.volume_group_backup_id != null ? each.value.volume_group_backup_id : null : null
    volume_group_id         = each.value.type == "volumeGroupId" ? each.value.volume_group_id != null ? each.value.volume_group_id : null : null
    volume_group_replica_id = each.value.type == "volumeGroupReplicaId" ? each.value.volume_group_replica_id != null ? each.value.volume_group_replica_id : null : null
  }

  #Optional
  backup_policy_id           = each.value.backup_policy_id != null ? each.value.backup_policy_id : null
  cluster_placement_group_id = each.value.cluster_placement_group_id != null ? each.value.cluster_placement_group_id : null
  defined_tags               = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags              = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
  display_name               = each.value.display_name != null ? each.value.display_name : "volume-group"
  xrc_kms_key_id             = each.value.kms_key != null ? each.value.kms_key : null

  dynamic "volume_group_replicas" {
    for_each = each.value.replication != null ? [1] : []
    content {
      availability_domain = data.oci_identity_availability_domains.vg_ads_replicas[each.key].availability_domains[each.value.replication.availability_domain - 1].name
      display_name        = each.value.display_name != null ? "${each.value.display_name}-replica" : "volume-group-replica"
    }
  }
}

resource "oci_core_volume_group_backup" "these" {
  for_each = { for k, v in var.storage_configuration != null ? var.storage_configuration.volume_groups : {} : k => v
    if v.backup.enable_backup == true ## enable_backup must be true to create a volume group backup
  }
  volume_group_id = oci_core_volume_group.these[each.key].id
  type            = each.value.backup.type != null ? each.value.backup.type : "INCREMENTAL"
  display_name    = each.value.display_name != null ? "${each.value.display_name}-backup" : "volume-group-backup"
}