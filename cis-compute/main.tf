# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_identity_availability_domains" "ads" {
  for_each       = var.instances_configuration["instances"]
  compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.instances_configuration.default_compartment_ocid
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
  accept_app_catalog = { for k, v in var.instances_configuration["instances"] : k => v if v.image_ocid == null }
}

resource "oci_core_app_catalog_listing_resource_version_agreement" "this" {
  for_each = local.accept_app_catalog
  #for_each                 = var.instances_configuration["instances"]
  listing_id               = [for i in local.versions : i.listing_id if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.image_name][0]
  listing_resource_version = [for i in local.versions : i.resource_version if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.image_name][0]
}

resource "oci_core_app_catalog_subscription" "this" {
  for_each = local.accept_app_catalog
  #for_each                 = var.instances_configuration["instances"]
  compartment_id           = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.instances_configuration.default_compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.this[each.key].time_retrieved
}

resource "oci_core_instance" "this" {
  for_each = var.instances_configuration["instances"]

  availability_domain  = data.oci_identity_availability_domains.ads[each.value.hostname].availability_domains[each.value.availability_domain - 1].name
  compartment_id       = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.instances_configuration.default_compartment_ocid
  shape                = each.value.shape
  display_name         = each.value.hostname
  preserve_boot_volume = each.value.preserve_boot_volume != null ? each.value.preserve_boot_volume : true
  defined_tags         = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
  freeform_tags        = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
  # some images don't allow encrypt in transit
  is_pv_encryption_in_transit_enabled = coalesce(var.instances_configuration.default_cis_level,"1") == "2" ? each.value.encrypt_in_transit : each.value.encrypt_in_transit != null ? each.value.encrypt_in_transit : false
  fault_domain                        = format("FAULT-DOMAIN-%s", each.value.fault_domain)


  create_vnic_details {
    assign_public_ip = each.value.assign_public_ip != null ? each.value.assign_public_ip : false
    subnet_id        = each.value.subnet_ocid != null ? each.value.subnet_ocid : var.instances_configuration.default_subnet_ocid
    hostname_label   = each.value.hostname
    nsg_ids          = [for nsg in each.value.network_security_groups : nsg]
  }

  source_details {
    boot_volume_size_in_gbs = each.value.boot_volume_size
    source_type             = "image"
    source_id               = each.value.image_ocid != null ? each.value.image_ocid : [for i in local.versions : i.listing_resource_id if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.image_name][0]
    #kms_key_id = coalesce(var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : try(substr(each.value.kms_key_id, 0, 0))) : each.value.kms_key_id
    kms_key_id = coalesce(var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : var.instances_configuration.default_kms_key_ocid != null ? var.instances_configuration.default_kms_key_ocid : try(substr(var.instances_configuration.default_kms_key_ocid, 0, 0))) : each.value.kms_key_id
  }

  dynamic "shape_config" {
    for_each = length(regexall("Flex", each.value.shape)) > 0 ? [each.value.shape] : []
    content {
      memory_in_gbs = each.value.memory == null || each.value.memory == 0 ? 16 : each.value.memory
      ocpus         = each.value.ocpus == null || each.value.ocpus == 0 ? 1 : each.value.ocpus
    }

  }

  metadata = {
    ssh_authorized_keys = each.value.ssh_public_key != null ? file(each.value.ssh_public_key) : file(var.instances_configuration.default_ssh_public_key_path)
    user_data           = data.template_cloudinit_config.config[each.value.hostname].rendered
  }
}

locals {
  linux_boot_volumes  = [for instance in var.instances_configuration["instances"] : instance.boot_volume_size >= 50 ? null : file(format("\n\nERROR: The boot volume size for linux instance %s is less than 50GB which is not permitted. Please add a boot volume size of 50GB or more", instance.hostname))]
  linux_block_volumes = var.storage_configuration["block_volumes"] != null ? [for block in var.storage_configuration["block_volumes"] : block.block_volume_size >= 50 && block.block_volume_size <= 32768 ? null : file(format("\n\nERROR: Block volume size %s for block volume %s should be between 50GB and 32768GB", block.block_volume_size, block.display_name))] : null
}

data "template_file" "block_volumes_templates" {
  for_each = var.instances_configuration["instances"]
  template = file("${path.module}/userdata/linux_mount.sh")

  vars = {
    length               = (length(split(" ", each.value.attached_storage.device_disk_mappings)) - 1)
    device_disk_mappings = each.value.attached_storage.device_disk_mappings
    block_vol_att_type   = each.value.attached_storage.block_volume_attachment_type
  }
}

data "template_cloudinit_config" "config" {
  for_each      = var.instances_configuration["instances"]
  gzip          = false
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "cloudinit.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.block_volumes_templates[each.value.hostname].rendered
  }
}

data "oci_identity_availability_domains" "bv_ads" {
  for_each       = var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}
  compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
}

resource "oci_core_volume" "block" {
  for_each            = var.storage_configuration["block_volumes"] != null ? var.storage_configuration["block_volumes"] : {}
  availability_domain = data.oci_identity_availability_domains.bv_ads[each.value.block_volume_name].availability_domains[each.value.availability_domain - 1].name
  compartment_id      = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
  display_name        = each.value.block_volume_name
  size_in_gbs         = each.value.block_volume_size
  defined_tags        = each.value.defined_tags != null ? each.value.defined_tags : var.storage_configuration.default_defined_tags
  freeform_tags       = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.storage_configuration.default_freeform_tags)
  vpus_per_gb         = each.value.vpus_per_gb
  kms_key_id          = coalesce(var.storage_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : var.storage_configuration.default_kms_key_ocid != null ? var.storage_configuration.default_kms_key_ocid : try(substr(var.storage_configuration.default_kms_key_ocid, 0, 0))) : each.value.kms_key_id
}

resource "oci_core_volume_attachment" "attachment" {
  for_each                            = var.storage_configuration["block_volumes"] != null ? [for bv in var.storage_configuration["block_volumes"] : bv.attach_to_instance != null ? var.storage_configuration["block_volumes"] : {}][0] : null
  attachment_type                     = var.instances_configuration["instances"][each.value.attach_to_instance.instance_key].attached_storage.block_volume_attachment_type
  instance_id                         = oci_core_instance.this[each.value.attach_to_instance.instance_key].id
  volume_id                           = oci_core_volume.block[each.value.block_volume_name].id
  device                              = each.value.attach_to_instance.device_name
  is_pv_encryption_in_transit_enabled = var.instances_configuration["instances"][each.value.attach_to_instance.instance_key].attached_storage.block_volume_attachment_type == "paravirtualized" ? each.value.encrypt_in_transit : false
}

data "oci_identity_availability_domains" "fs_ads" {
  for_each       = var.storage_configuration["file_storage"]["file_system"] != null ? var.storage_configuration["file_storage"]["file_system"] : {}
  compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
}

resource "oci_file_storage_file_system" "this" {
  for_each            = var.storage_configuration["file_storage"]["file_system"] != null ? var.storage_configuration["file_storage"]["file_system"] : {}
  availability_domain = data.oci_identity_availability_domains.fs_ads[each.value.file_system_name].availability_domains[each.value.availability_domain - 1].name
  compartment_id      = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
  display_name        = each.value.file_system_name
  kms_key_id          = coalesce(var.storage_configuration.default_cis_level,"1") == "2" ? (each.value.kms_key_id != null ? each.value.kms_key_id : var.storage_configuration.default_kms_key_ocid != null ? var.storage_configuration.default_kms_key_ocid : try(substr(var.storage_configuration.default_kms_key_ocid, 0, 0))) : each.value.kms_key_id
}

data "oci_identity_availability_domains" "mt_ads" {
  for_each       = var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}
  compartment_id = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
}

resource "oci_file_storage_mount_target" "this" {
  for_each            = var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}
  availability_domain = data.oci_identity_availability_domains.mt_ads[each.value.mount_target_name].availability_domains[each.value.availability_domain - 1].name
  display_name        = each.value.mount_target_name
  compartment_id      = each.value.compartment_ocid != null ? each.value.compartment_ocid : var.storage_configuration.default_compartment_ocid
  subnet_id           = each.value.subnet_ocid != null ? each.value.subnet_ocid : var.storage_configuration.default_subnet_ocid
}


resource "oci_file_storage_export_set" "this" {
  for_each        = var.storage_configuration["file_storage"]["mount_target"] != null ? var.storage_configuration["file_storage"]["mount_target"] : {}
  mount_target_id = oci_file_storage_mount_target.this[each.key].id
  display_name    = each.value.mount_target_name
}


resource "oci_file_storage_export" "this" {
  for_each       = var.storage_configuration["file_storage"]["export"] != null ? var.storage_configuration["file_storage"]["export"] : {}
  export_set_id  = oci_file_storage_export_set.this[each.value.mount_target_key].id
  file_system_id = oci_file_storage_file_system.this[each.value.filesystem_key].id
  path           = each.value.path

  dynamic "export_options" {
    iterator = exp_options
    for_each = each.value.export_options != null ? each.value.export_options : []
    content {
      source                         = exp_options.value.source
      access                         = exp_options.value.access
      identity_squash                = exp_options.value.identity
      require_privileged_source_port = exp_options.value.use_port
    }
  }
}

