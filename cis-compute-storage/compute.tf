# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_core_images" "these" {
  for_each = var.instances_configuration != null ? {for k, v in var.instances_configuration["instances"] : k => v if v.custom_image != null} : {}
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
    filter {
      name   = "state"
      values = ["AVAILABLE"]
    }
}

#  data "oci_core_image" "these" {
#    for_each = var.instances_configuration != null ? {for k, v in var.instances_configuration["instances"] : k => v if v.image.id != null} : {}
#      image_id = each.value.image.id
#  }

data "oci_identity_availability_domains" "ads" {
  for_each       = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
}

locals {
  oci_core_images_by_name = length(data.oci_core_images.these) > 0 ? { for k, v in data.oci_core_images.these[*].images : v.display_name => {id = v.id, operating_system = v.operating_system } } : {}

  platform_types = ["AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM"]
}

resource "oci_core_instance" "these" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    lifecycle {
      ## Check 1: Customer managed key must be provided if CIS profile level is "2".
      precondition {
        condition = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kms_key_id != null || var.instances_configuration.default_kms_key_id != null) : var.instances_configuration.default_kms_key_id != null) : true # false triggers this.
        error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in instance \"${each.key}\": a customer managed key is required when CIS level is set to 2. Either \"encryption.kms_key_id\" or \"default_kms_key_id\" must be provided."
      }
      # Check 2: Either customer image or marketplace image must be provided.
      precondition {
        condition = each.value.custom_image != null || each.value.marketplace_image != null 
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"custom_image\" or \"marketplace_image\" must be provided. \"custom_image\" takes precedence over \"marketplace_image\"."
      }
      # Check 3: In-transit encryption is only available to paravirtualized boot volumes.
      precondition {
        condition = each.value.encryption != null ? (each.value.boot_volume != null ? (upper(each.value.boot_volume.type) != "PARAVIRTUALIZED" ? each.value.encryption.encrypt_in_transit_on_instance_create == false && each.value.encryption.encrypt_in_transit_on_instance_update == false : true) : true) : true 
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": in-transit encryption (during instance creation and instance update) is only available to instances with PARAVIRTUALIZED boot volume."
      }
      ## Check 4: In-transit encryption is only available to images that have it enabled.
      # precondition {
      #   condition = each.value.encryption != null ? (each.value.encryption.encrypt_in_transit_on_instance_create == true || each.value.encryption.encrypt_in_transit_on_instance_update == true ? (contains(keys(data.oci_core_image.these),each.key) ? (data.oci_core_image.these[each.key].launch_options[0].is_pv_encryption_in_transit_enabled == false ? false : true) : true) : true) : true
      #   error_message = "VALIDATION FAILURE in instance \"${each.key}\": in-transit encryption is not enabled in the underlying image. Unset both \"encryption.encrypt_in_transit_at_instance_create\" and \"encryption.encrypt_in_transit_at_instance_update\" attributes."
      # }
      ## Check 5: Valid platform types.
      precondition {
        condition = each.value.platform_type != null ? contains(local.platform_types, each.value.platform_type) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid value for \"platform_type\" attribute. Valid values are ${join(",",local.platform_types)}."
      }
      ## Check 6: Confidential computing and shielded instances are mutually exclusive.
      precondition {
        condition = each.value.platform_type != null ? (each.value.encryption != null ? (each.value.encryption.encrypt_data_in_use == true ? (each.value.boot_volume != null ? each.value.boot_volume.secure_boot == false && each.value.boot_volume.measured_boot == false : true) : true) : true) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": confidential computing and shielded instances are mutually exclusive. Either set \"encryption.encrypt_data_in_use\" to false or set both \"boot_volume.secure_boot\" and \"boot_volume.measured_boot\" to false."
      }
      ## Check 7: Platform type must be provided if CIS profile level is "2". This is required for enabling Secure Compute.
      precondition {
        condition = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" && each.value.platform_type == null ? false : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": platform type is required when CIS level is set to 2. Make sure to set \"platform_type\" attribute. Valid values are ${join(",",local.platform_types)}."
      }
      ## Check 8: Confidential computing and CIS level profile level "2" are mutually exclusive.
      precondition {
        condition = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? (each.value.encryption != null ? (each.value.encryption.encrypt_data_in_use == true ? false : true) : true) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": confidential computing must be disabled when CIS level is set to 2. CIS level 2 automatically enables shielded instances, which cannot be enabled simultaneously with confidential computing in OCI. Either set \"encryption.encrypt_data_in_use\" to false or set CIS level to \"1\"."
      }
      # Check 9: Check marketplace_image.version
      precondition {
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : v.listing_resource_version],each.value.marketplace_image.version) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid Marketplace image version \"${each.value.marketplace_image.version}\" in \"marketplace_image.version\" attribute. Ensure it is spelled correctly. Valid versions for image name \"${each.value.marketplace_image.name}\" are: ${join(", ",[for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : "\"${v.listing_resource_version}\""])}."
      }
      # Check 10: Check compatible shapes for given image name/version
      precondition {
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listing_resource_version.this[each.key].compatible_shapes : v],each.value.shape) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid image shape \"${each.value.shape}\" in \"shape\" attribute. Ensure it is spelled correctly. Valid shapes for image \"${each.value.marketplace_image.name}\" version \"${each.value.marketplace_image.version}\" are: ${join(", ",[for v in data.oci_core_app_catalog_listing_resource_version.this[each.key].compatible_shapes : "\"${v}\""])}."
      }
    }  
    compartment_id       = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
    availability_domain  = data.oci_identity_availability_domains.ads[each.key].availability_domains[(each.value.placement != null ? each.value.placement.availability_domain : 1) - 1].name
    fault_domain         = format("FAULT-DOMAIN-%s", each.value.placement != null ? each.value.placement.fault_domain : 1)
    shape                = each.value.shape
    display_name         = each.value.name
    preserve_boot_volume = each.value.boot_volume != null ? each.value.boot_volume.preserve_on_instance_deletion : true
    defined_tags         = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
    freeform_tags        = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
    # some images don't allow encrypt in transit
    is_pv_encryption_in_transit_enabled = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? true : (each.value.encryption != null ? each.value.encryption.encrypt_in_transit_on_instance_create : null)
    create_vnic_details {
      private_ip       = each.value.networking != null ? each.value.networking.private_ip : null
      assign_public_ip = each.value.networking != null ? coalesce(each.value.networking.assign_public_ip,false) : false
      subnet_id        = each.value.networking != null ? (each.value.networking.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.networking.subnet_id)) > 0 ? each.value.networking.subnet_id : var.network_dependency["subnets"][each.value.networking.subnet_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)
      hostname_label   = each.value.networking != null ? (coalesce(each.value.networking.hostname,lower(replace(each.value.name," ","")))) : lower(replace(each.value.name," ",""))
      nsg_ids          = each.value.networking != null ? [for nsg in coalesce(each.value.networking.network_security_groups,[]) : (length(regexall("^ocid1.*$", nsg)) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id)] : null
      skip_source_dest_check = each.value.networking != null ? each.value.networking.skip_source_dest_check : false
    }
    source_details {
      boot_volume_size_in_gbs = each.value.boot_volume != null ? each.value.boot_volume.size : 50
      source_type = "image"
      #source_id   = each.value.image.id != null ? each.value.image.id : [for i in local.versions : i.listing_resource_id if i.publisher == each.value.image.publisher_name && i.display_name == each.value.image.name][0]
      source_id   = each.value.custom_image != null ? (each.value.custom_image.ocid != null ? each.value.custom_image.ocid : each.value.custom_image.name != null ? local.oci_core_images_by_name[each.value.custom_image.name].id : "undefined") : (local.mkp_image_details[each.key] != null ? local.mkp_image_details[each.key].mkp_image_ocid : "undefined")
      kms_key_id  = each.value.encryption != null ? (each.value.encryption.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.kms_key_id)) > 0 ? each.value.encryption.kms_key_id : var.kms_dependency[each.value.encryption.kms_key_id].id) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)
    }
    launch_options {
      boot_volume_type = each.value.boot_volume != null ? upper(each.value.boot_volume.type) : "PARAVIRTUALIZED"
      firmware = each.value.boot_volume != null ? (each.value.boot_volume.firmware != null ? upper(each.value.boot_volume.firmware) : null) : null
      network_type = each.value.networking != null ? upper(each.value.networking.type) : "PARAVIRTUALIZED"
      remote_data_volume_type = upper(each.value.volumes_emulation_type)
      is_pv_encryption_in_transit_enabled = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? true : (each.value.encryption != null ? each.value.encryption.encrypt_in_transit_on_instance_update : null)
    }
    dynamic "platform_config" {
      for_each = each.value.platform_type != null || coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? [1] : []
      content {
        type = each.value.platform_type
        is_secure_boot_enabled = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? true : (each.value.boot_volume != null ? (split(".",each.value.shape)[0] == "VM" && each.value.boot_volume.measured_boot == true ? each.value.boot_volume.measured_boot : each.value.boot_volume.secure_boot) : false)
        is_measured_boot_enabled = each.value.boot_volume != null ? each.value.boot_volume.measured_boot : false
        is_trusted_platform_module_enabled = each.value.boot_volume != null ? (split(".",each.value.shape)[0] == "VM" && each.value.boot_volume.measured_boot == true ? each.value.boot_volume.measured_boot : each.value.boot_volume.trusted_platform_module) : false
        is_memory_encryption_enabled = each.value.encryption != null ? each.value.encryption.encrypt_data_in_use : false
      }
    }  
    dynamic "shape_config" {
      for_each = length(regexall("Flex", each.value.shape)) > 0 ? [each.value.shape] : []
      content {
        memory_in_gbs = each.value.flex_shape_settings != null ? each.value.flex_shape_settings.memory : 16
        ocpus         = each.value.flex_shape_settings != null ? each.value.flex_shape_settings.ocpus : 1
      }
    }
    dynamic "agent_config" {
      for_each = each.value.cloud_agent != null ? [1] : []
      content {
        #are_all_plugins_disabled = false
        is_management_disabled = each.value.cloud_agent.disable_management
        is_monitoring_disabled = each.value.cloud_agent.disable_monitoring
        dynamic "plugins_config" {
          for_each = coalesce(each.value.cloud_agent.plugins,[])
            iterator = plugin
            content {
              name = plugin.value.name
              desired_state = plugin.value.enabled ? "ENABLED" : "DISABLED"
            }
        }
      }
    }
    dynamic "instance_options" {
      for_each = coalesce(each.value.cis_level,var.instances_configuration.default_cis_level,"1") == "2" ? [1] : []
      content {
        are_legacy_imds_endpoints_disabled = true
      }
    }
    metadata = {
      ssh_authorized_keys = each.value.ssh_public_key_path != null ? (fileexists(each.value.ssh_public_key_path) ? file(each.value.ssh_public_key_path) : each.value.ssh_public_key_path) : var.instances_configuration.default_ssh_public_key_path != null ? (fileexists(var.instances_configuration.default_ssh_public_key_path) ? file(var.instances_configuration.default_ssh_public_key_path) : var.instances_configuration.default_ssh_public_key_path): null
      user_data           = contains(keys(data.template_file.cloud_config),each.key) ? base64encode(data.template_file.cloud_config[each.key].rendered) : null
    }
    compute_cluster_id   = each.value.cluster_id != null ? (contains(keys(oci_core_compute_cluster.these),each.value.cluster_id) ? oci_core_compute_cluster.these[each.value.cluster_id].id : (length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? each.value.cluster_id : null)) : null
}

resource "oci_core_volume_backup_policy_assignment" "these_boot_volumes" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    asset_id  = oci_core_instance.these[each.key].boot_volume_id
    policy_id = local.oracle_backup_policies[lower(each.value.boot_volume != null ? each.value.boot_volume.backup_policy : "bronze")]
}

data "template_file" "cloud_config" {
  for_each = var.instances_configuration != null ? {for k, v in var.instances_configuration["instances"] : k => v if v.cloud_init != null || var.instances_configuration.default_cloud_init_heredoc_script != null || var.instances_configuration.default_cloud_init_script_file != null} : {}
    template = coalesce(try(each.value.cloud_init.heredoc_script,null), try(file(try(each.value.cloud_init.script_file,null)),null), var.instances_configuration.default_cloud_init_heredoc_script, try(file(var.instances_configuration.default_cloud_init_script_file),null), "__void__")
}

/* data "template_file" "block_volumes_templates" {
  for_each = var.instances_configuration != null ? {for k, v in var.instances_configuration["instances"] : k => v if v.device_mounting != null} : {}
    template = file("${path.module}/userdata/linux_mount.sh")
    vars = {
      length        = (length(split(" ", each.value.device_mounting.disk_mappings)) - 1)
      disk_mappings = each.value.device_mounting.disk_mappings
      block_vol_att_type = each.value.device_mounting.emulation_type != null ? lower(each.value.device_mounting.emulation_type) : "paravirtualized"
    }
}
*/  

data "oci_core_vnic_attachments" "these" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id) 
    instance_id    = oci_core_instance.these[each.key].id
}

locals {
  secondary_vnics = flatten([
    for inst_key, inst_value in (var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for vnic_key, vnic_value in (inst_value.networking != null ? (inst_value.networking.secondary_vnics != null ? inst_value.networking.secondary_vnics : {}) : {}) : {
        key              = "${inst_key}.${vnic_key}"
        inst_key         = inst_key
        display_name     = vnic_value.display_name
        private_ip       = vnic_value.private_ip
        hostname         = vnic_value.hostname
        assign_public_ip = vnic_value.assign_public_ip
        subnet_id               = vnic_value.subnet_id
        network_security_groups = vnic_value.network_security_groups
        skip_source_dest_check  = vnic_value.skip_source_dest_check
        nic_index               = vnic_value.nic_index
        defined_tags            = vnic_value.defined_tags
        freeform_tags           = vnic_value.freeform_tags
      } 
    ]
  ])

  primary_vnic_secondary_ips = flatten([
    for inst_key, inst_value in (var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for ip_key, ip_value in (inst_value.networking != null ? (inst_value.networking.secondary_ips != null ? inst_value.networking.secondary_ips : {}) : {}) : {
        key           = "${inst_key}.${ip_key}"
        vnic_id       = data.oci_core_vnic_attachments.these[inst_key].vnic_attachments[0].vnic_id
        display_name  = ip_value.display_name
        private_ip    = ip_value.private_ip
        hostname      = ip_value.hostname
        defined_tags  = ip_value.defined_tags
        freeform_tags = ip_value.freeform_tags
      } 
    ]
  ])

  secondary_vnics_secondary_ips = flatten([
    for inst_key, inst_value in (var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for vnic_key, vnic_value in (inst_value.networking != null ? (inst_value.networking.secondary_vnics != null ? inst_value.networking.secondary_vnics : {}) : {}) : [
        for ip_key, ip_value in (vnic_value.secondary_ips != null ? vnic_value.secondary_ips : {}) : {
          key           = "${inst_key}.${vnic_key}.${ip_key}"
          vnic_id       = oci_core_vnic_attachment.these["${inst_key}.${vnic_key}"].vnic_id
          display_name  = ip_value.display_name
          private_ip    = ip_value.private_ip
          hostname      = ip_value.hostname
          defined_tags  = ip_value.defined_tags
          freeform_tags = ip_value.freeform_tags
        }
      ] 
    ]
  ])
}
resource "oci_core_vnic_attachment" "these" {
  for_each = { for v in local.secondary_vnics : v.key => {
                                                            inst_key         = v.inst_key
                                                            display_name     = v.display_name
                                                            private_ip       = v.private_ip
                                                            hostname         = v.hostname
                                                            assign_public_ip = v.assign_public_ip
                                                            subnet_id               = v.subnet_id
                                                            network_security_groups = v.network_security_groups
                                                            skip_source_dest_check  = v.skip_source_dest_check
                                                            nic_index               = v.nic_index
                                                            defined_tags            = v.defined_tags
                                                            freeform_tags           = v.freeform_tags
                                                         } }
    display_name = each.value.display_name
    instance_id  = oci_core_instance.these[each.value.inst_key].id
    nic_index    = each.value.nic_index
    create_vnic_details {
      display_name     = each.value.display_name
      assign_public_ip = each.value.assign_public_ip
      private_ip       = each.value.private_ip
      hostname_label   = each.value.hostname
      subnet_id        = each.value.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.subnet_id)) > 0 ? each.value.subnet_id : var.network_dependency["subnets"][each.value.subnet_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)
      nsg_ids          = [for nsg in coalesce(each.value.network_security_groups,[]) : (length(regexall("^ocid1.*$", nsg)) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id)]
      skip_source_dest_check = each.value.skip_source_dest_check
      defined_tags     = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
      freeform_tags    = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
    }
}

data "oci_core_vnic" "these" {
  for_each = oci_core_vnic_attachment.these
    vnic_id = each.value.vnic_id
}

resource "oci_core_private_ip" "these" {
  for_each = { for v in concat(local.primary_vnic_secondary_ips, local.secondary_vnics_secondary_ips) : v.key => {
                                                                                                                  vnic_id       = v.vnic_id
                                                                                                                  display_name  = v.display_name
                                                                                                                  private_ip    = v.private_ip
                                                                                                                  hostname      = v.hostname
                                                                                                                  defined_tags  = v.defined_tags
                                                                                                                  freeform_tags = v.freeform_tags
                                                                                                                } }
    display_name   = each.value.display_name
    ip_address     = each.value.private_ip
    vnic_id        = each.value.vnic_id
    hostname_label = each.value.hostname
    defined_tags   = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
    freeform_tags  = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
}
