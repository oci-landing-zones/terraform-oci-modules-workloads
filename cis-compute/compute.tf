# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_identity_availability_domains" "ads" {
  for_each       = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
}

data "oci_core_app_catalog_listings" "existing" {}

locals {
  listings = {
    for i in data.oci_core_app_catalog_listings.existing.app_catalog_listings :
    i.display_name => { "display_name" : i.display_name, "publisher_name" : i.publisher_name, "listing_id" : i.listing_id }...
  }
  helper = {
    for i in local.listings :
    format("%s: %s", i[0].publisher_name, i[0].display_name) => i[0].listing_id
  }

  versions = {
    for key, value in data.oci_core_app_catalog_listing_resource_versions.existing :
    key => { "publisher" : split(":", key)[0], "display_name" : split(": ", key)[1], "listing_id" : value.app_catalog_listing_resource_versions[0].listing_id, "listing_resource_id" : value.app_catalog_listing_resource_versions[0].listing_resource_id, "resource_version" : value.app_catalog_listing_resource_versions[0].listing_resource_version } if length(value.app_catalog_listing_resource_versions) != 0
  }
}

data "oci_core_app_catalog_listing_resource_versions" "existing" {
  for_each   = local.helper
    listing_id = each.value
}

locals {
  accept_app_catalog = { for k, v in (var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : k => v if v.image.id == null }
}

resource "oci_core_app_catalog_listing_resource_version_agreement" "these" {
  for_each = local.accept_app_catalog
  #for_each                 = var.instances_configuration["instances"]
    listing_id               = [for i in local.versions : i.listing_id if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.name][0]
    listing_resource_version = [for i in local.versions : i.resource_version if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.name][0]
}

resource "oci_core_app_catalog_subscription" "these" {
  for_each = local.accept_app_catalog
  #for_each                 = var.instances_configuration["instances"]
    compartment_id           = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
    #compartment_id           = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.instances_configuration.default_compartment_ocid
    eula_link                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].eula_link
    listing_id               = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_id
    listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_resource_version
    oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].oracle_terms_of_use_link
    signature                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].signature
    time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].time_retrieved
  }

resource "oci_core_instance" "these" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    lifecycle {
      precondition {
        condition = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null || var.instances_configuration.default_kms_key_id != null ? true : false) : true # false triggers this.
        error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in instance ${each.key}: A customer managed key is required when CIS level is set to 2. Either encryption.kms_key_id or default_kms_key_id must be provided."
      }
      precondition {
        condition = each.value.image.id != null || (each.value.image.name != null && each.value.image.publisher_name != null) 
        error_message = "VALIDATION FAILURE in instance ${each.key}: Either image.id or (image.name and image.publisher_name) must be provided. image.id takes precedence over the pair image.name/image.publisher_name."
      }
      precondition {
        condition = each.value.attached_storage != null ? (contains(["paravirtualized","iscsi"], lower(each.value.attached_storage.attachment_type)) ? true : false) : true
        error_message = "VALIDATION FAILURE in instance ${each.key}: \"${each.value.attached_storage.attachment_type}\" value is invalid for attached_storage.attachment_type attribute. Valid values are \"paravirtualized\" or \"iscsi\" (case insensitive). "
      }
    }  
    compartment_id       = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
    #availability_domain  = data.oci_identity_availability_domains.ads[each.key].availability_domains[coalesce((each.value.placement != null ? each.value.placement.availability_domain : 1), 1) - 1].name
    availability_domain  = data.oci_identity_availability_domains.ads[each.key].availability_domains[(each.value.placement != null ? each.value.placement.availability_domain : 1) - 1].name
    #fault_domain         = format("FAULT-DOMAIN-%s", coalesce((each.value.placement != null ? each.value.placement.fault_domain : 1),1))
    fault_domain         = format("FAULT-DOMAIN-%s", each.value.placement != null ? each.value.placement.fault_domain : 1)
    shape                = each.value.shape
    display_name         = each.value.hostname
    preserve_boot_volume = each.value.boot_volume != null ? each.value.boot_volume.preserve_on_instance_deletion : true
    defined_tags         = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
    freeform_tags        = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
    # some images don't allow encrypt in transit
    is_pv_encryption_in_transit_enabled = each.value.encryption != null ? each.value.encryption.encrypt_in_transit : true
    create_vnic_details {
      assign_public_ip = each.value.networking != null ? coalesce(each.value.networking.assign_public_ip,false) : false
      subnet_id        = each.value.networking != null ? (each.value.networking.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.networking.subnet_id)) > 0 ? each.value.networking.subnet_id : var.network_dependency[each.value.networking.subnet_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency[var.instances_configuration.default_subnet_id].id)) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency[var.instances_configuration.default_subnet_id].id)
      hostname_label   = each.value.hostname
      nsg_ids          = each.value.networking != null ? [for nsg in coalesce(each.value.networking.network_security_groups,[]) : nsg] : null
    }
    source_details {
      boot_volume_size_in_gbs = each.value.boot_volume != null ? each.value.boot_volume.size : 50
      source_type = "image"
      source_id   = each.value.image.id != null ? each.value.image.id : [for i in local.versions : i.listing_resource_id if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.name][0]
      #kms_key_id = coalesce(var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : try(substr(each.value.kms_key_id, 0, 0))) : each.value.kms_key_id
      kms_key_id  = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.kms_key_id)) > 0 ? each.value.encryption.kms_key_id : var.kms_dependency[each.value.encryption.kms_key_id].id) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id): null)) : null
      #kms_key_id = each.value.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.kms_key_id)) > 0 ? each.value.kms_key_id : var.kms_dependency[each.value.kms_key_id].id) : null
    }
    dynamic "shape_config" {
      for_each = length(regexall("Flex", each.value.shape)) > 0 ? [each.value.shape] : []
      content {
        memory_in_gbs = each.value.flex_shape_settings != null ? each.value.flex_shape_settings.memory : 16
        ocpus         = each.value.flex_shape_settings != null ? each.value.flex_shape_settings.ocpus : 1
      }
    }
    metadata = {
      ssh_authorized_keys = each.value.ssh_public_key != null ? file(each.value.ssh_public_key) : file(var.instances_configuration.default_ssh_public_key_path)
      user_data           = data.template_cloudinit_config.config[each.key].rendered
    }
}

/* locals {
  linux_boot_volumes  = [for instance in var.instances_configuration["instances"] : instance.boot_volume_size >= 50 ? null : file(format("\n\nERROR: The boot volume size for linux instance %s is less than 50GB which is not permitted. Please add a boot volume size of 50GB or more", instance.hostname))]
  linux_block_volumes = var.storage_configuration != null ? (var.storage_configuration["block_volumes"] != null ? [for block in var.storage_configuration["block_volumes"] : block.block_volume_size >= 50 && block.block_volume_size <= 32768 ? null : file(format("\n\nERROR: Block volume size %s for block volume %s should be between 50GB and 32768GB", block.block_volume_size, block.display_name))] : null) : null
} */

data "template_file" "block_volumes_templates" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    template = file("${path.module}/userdata/linux_mount.sh")
    vars = {
      length               = (length(split(" ", each.value.attached_storage.device_disk_mappings)) - 1)
      device_disk_mappings = each.value.attached_storage.device_disk_mappings
      block_vol_att_type   = lower(each.value.attached_storage.attachment_type)
    }
}

data "template_cloudinit_config" "config" {
  for_each      = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    gzip          = false
    base64_encode = true

    # Main cloud-config configuration file.
    part {
      filename     = "cloudinit.sh"
      content_type = "text/x-shellscript"
      content      = data.template_file.block_volumes_templates[each.key].rendered
    }
  }