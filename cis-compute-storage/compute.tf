# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#------------------------------
# Platform images data sources
#------------------------------
data "oci_core_images" "these_platform" {
  count = local.deploy_platform_image_by_name ? 1 : 0
  # lifecycle {
  #   precondition {
  #       condition = var.tenancy_ocid != null
  #       error_message = "VALIDATION FAILURE: variable \"tenancy_ocid\" is required when deploying a Compute instance based on a platform image name."
  #     }
  # }
  compartment_id = var.tenancy_ocid
  filter {
    name   = "state"
    values = ["AVAILABLE"]
  }
}

data "oci_core_image_shapes" "these_platform" {
  for_each = length(data.oci_core_images.these_platform) > 0 ? { for i in data.oci_core_images.these_platform[0].images : i.id => { "display_name" : i.display_name } } : {}
  image_id = each.key
}

#------------------------------
# Custom images data source
#------------------------------
data "oci_core_images" "these_custom" {
  for_each = var.instances_configuration != null ? { for k, v in var.instances_configuration["instances"] : k => v if try(v.custom_image.name, null) != null } : {}
  lifecycle {
    precondition {
      condition     = each.value.custom_image.compartment_id != null || var.instances_configuration.default_compartment_id != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"compartment_id\" attribute or \"default_compartment_id\" attribute is required when providing a custom image name."
    }
    postcondition {
      condition     = self.images != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": image \"${each.value.custom_image.name}\" not found in compartment \"${each.value.custom_image.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.custom_image.compartment_id)) > 0 ? each.value.custom_image.compartment_id : var.compartments_dependency[each.value.custom_image.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)}\"."
    }
  }
  compartment_id = each.value.custom_image.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.custom_image.compartment_id)) > 0 ? each.value.custom_image.compartment_id : var.compartments_dependency[each.value.custom_image.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  filter {
    name   = "state"
    values = ["AVAILABLE"]
  }
  filter {
    name   = "display_name"
    values = [each.value.custom_image.name]
  }
}

#------------------------------
# AD data source
#------------------------------
data "oci_identity_availability_domains" "ads" {
  for_each       = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
}

locals {

  #------------------------------
  # Platform images
  #------------------------------

  deploy_platform_image_by_name = var.instances_configuration != null ? length([for v in var.instances_configuration["instances"] : v if try(v.platform_image.name, null) != null]) > 0 : false

  platform_images = length(data.oci_core_images.these_platform) > 0 ? [
    for i in data.oci_core_images.these_platform[0].images : {
      display_name             = i.display_name
      id                       = i.id
      operating_system         = i.operating_system
      operating_system_version = i.operating_system_version
      encryption_in_transit    = i.launch_options[0].is_pv_encryption_in_transit_enabled
      state : i.state
      shapes : [for s in data.oci_core_image_shapes.these_platform[i.id].image_shape_compatibilities : s.shape]
      # min_memory : [for s in data.oci_core_image_shapes.these_platform[i.id].image_shape_compatibilities : try(s.memory_constraints.min_in_gbs,0)]
      # max_memory : [for s in data.oci_core_image_shapes.these_platform[i.id].image_shape_compatibilities : try(s.memory_constraints.max_in_gbs,0)]
      # min_ocpu   : [for s in data.oci_core_image_shapes.these_platform[i.id].image_shape_compatibilities : try(s.ocpu_constraints.min,0)]
      # max_ocpu   : [for s in data.oci_core_image_shapes.these_platform[i.id].image_shape_compatibilities : try(s.ocpu_constraints.max,0)]
    }
  ] : []

  platform_images_by_name = { for i in local.platform_images : i.display_name => { id = i.id, operating_system = i.operating_system, shapes = i.shapes /*, min_memory = i.min_memory, max_memory = i.max_memory, min_ocpu = i.min_ocpu, max_ocpu = i.max_ocpu*/ } }
  platform_images_by_id   = { for i in local.platform_images : i.id => { display_name = i.display_name, operating_system = i.operating_system, shapes = i.shapes /*, min_memory = i.min_memory, max_memory = i.max_memory, min_ocpu = i.min_ocpu, max_ocpu = i.max_ocpu*/ } }

  #------------------------------
  # Custom images
  #------------------------------

  custom_images = length(data.oci_core_images.these_custom) > 0 ? flatten([
    for k, v in data.oci_core_images.these_custom : [
      for i in v.images : {
        key              = k
        display_name     = i.display_name
        id               = i.id
        operating_system = i.operating_system
      }
    ]
  ]) : []

  custom_images_by_name = { for i in local.custom_images : "${i.key}.${i.display_name}" => { id = i.id, operating_system = i.operating_system } }

  platform_types = ["AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM"]

  zpr_provided_attributes = { for k, v in(var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : k => [for a in v.security.zpr_attributes : "${a.namespace}.${a.attr_name}"] if try(v.security.zpr_attributes, null) != null }

}

resource "oci_core_instance" "these" {
  for_each = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  lifecycle {
    ## Check 1: Customer managed key must be provided if CIS profile level is "2".
    precondition {
      condition     = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? (each.value.encryption != null ? (each.value.encryption.kms_key_id != null || var.instances_configuration.default_kms_key_id != null) : var.instances_configuration.default_kms_key_id != null) : true # false triggers this.
      error_message = "VALIDATION FAILURE (CIS Storage 4.1.2) in instance \"${each.key}\": a customer managed key is required when CIS level is set to 2. Either \"encryption.kms_key_id\" or \"default_kms_key_id\" must be provided."
    }
    # Check 2: Either custom image or marketplace image or platform image must be provided.
    precondition {
      condition     = each.value.marketplace_image != null || each.value.platform_image != null || each.value.custom_image != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"marketplace_image\" or \"platform_image\" or \"custom_image\" must be provided. Precedence, from higher to lower, is \"marketplace_image\", \"platform_image\", \"custom_image\"."
    }
    # Check 3: In-transit encryption is only available to paravirtualized boot volumes.
    precondition {
      condition     = each.value.encryption != null ? (each.value.boot_volume != null ? (upper(each.value.boot_volume.type) != "PARAVIRTUALIZED" ? each.value.encryption.encrypt_in_transit_on_instance_create == false && each.value.encryption.encrypt_in_transit_on_instance_update == false : true) : true) : true
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": in-transit encryption (during instance creation and instance update) is only available to instances with PARAVIRTUALIZED boot volume."
    }
    ## Check 4: In-transit encryption is only available to images that have it enabled.
    # precondition {
    #   condition = each.value.encryption != null ? (each.value.encryption.encrypt_in_transit_on_instance_create == true || each.value.encryption.encrypt_in_transit_on_instance_update == true ? (contains(keys(data.oci_core_image.these),each.key) ? (data.oci_core_image.these[each.key].launch_options[0].is_pv_encryption_in_transit_enabled == false ? false : true) : true) : true) : true
    #   error_message = "VALIDATION FAILURE in instance \"${each.key}\": in-transit encryption is not enabled in the underlying image. Unset both \"encryption.encrypt_in_transit_at_instance_create\" and \"encryption.encrypt_in_transit_at_instance_update\" attributes."
    # }
    ## Check 5: Valid platform types.
    precondition {
      condition     = each.value.platform_type != null ? contains(local.platform_types, each.value.platform_type) : true
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid value for \"platform_type\" attribute. Valid values are ${join(",", local.platform_types)}."
    }
    ## Check 6: Confidential computing and shielded instances are mutually exclusive.
    precondition {
      condition     = each.value.platform_type != null ? (each.value.encryption != null ? (each.value.encryption.encrypt_data_in_use == true ? (each.value.boot_volume != null ? each.value.boot_volume.secure_boot == false && each.value.boot_volume.measured_boot == false : true) : true) : true) : true
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": confidential computing and shielded instances are mutually exclusive. Either set \"encryption.encrypt_data_in_use\" to false or set both \"boot_volume.secure_boot\" and \"boot_volume.measured_boot\" to false."
    }
    ## Check 7: Platform type must be provided if CIS profile level is "2". This is required for enabling Secure Compute.
    precondition {
      condition     = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" && each.value.platform_type == null ? false : true
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": platform type is required when CIS level is set to 2. Make sure to set \"platform_type\" attribute. Valid values are ${join(",", local.platform_types)}."
    }
    ## Check 8: Confidential computing and CIS level profile level "2" are mutually exclusive.
    precondition {
      condition     = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? (each.value.encryption != null ? (each.value.encryption.encrypt_data_in_use == true ? false : true) : true) : true
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": confidential computing must be disabled when CIS level is set to 2. CIS level 2 automatically enables shielded instances, which cannot be enabled simultaneously with confidential computing in OCI. Either set \"encryption.encrypt_data_in_use\" to false or set CIS level to \"1\"."
    }
    # Check 9: Check marketplace_image.version
    # precondition {
    #   condition = try(each.value.marketplace_image.name,null) != null ? (each.value.marketplace_image.version != null ? contains([for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : v.listing_resource_version],each.value.marketplace_image.version) : true) : true
    #   error_message = try(each.value.marketplace_image.name,null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid Marketplace image version \"${coalesce(each.value.marketplace_image.version,replace(data.oci_marketplace_listing.this[each.key].default_package_version," ","_"))}\" in \"marketplace_image.version\" attribute. Ensure it is spelled correctly. Valid versions for image name \"${each.value.marketplace_image.name}\" are: ${join(", ",[for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : "\"${v.listing_resource_version}\""])}." : "__void__"
    # }
    # Check 10: Check compatible shapes for given marketplace image name/version
    precondition {
      condition     = try(each.value.marketplace_image.name, null) != null ? contains(data.oci_core_app_catalog_listing_resource_version.this[each.key].compatible_shapes, each.value.shape) : true
      error_message = try(each.value.marketplace_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid image shape \"${each.value.shape}\" in \"shape\" attribute. Ensure it is spelled correctly. Valid shapes for marketplace image \"${each.value.marketplace_image.name}\" version \"${coalesce(each.value.marketplace_image.version, replace(data.oci_marketplace_listing.this[each.key].default_package_version, " ", "_"))}\" are: ${join(", ", [for v in data.oci_core_app_catalog_listing_resource_version.this[each.key].compatible_shapes : "\"${v}\""])}." : "__void__"
    }
    # Check 11: Check compatible shapes for given platform image ocid - DISABLED because it uses oci_core_images data source that limits images to the latest three per platform.
    # precondition {
    #   condition = try(each.value.platform_image.ocid,null) != null ? contains(local.platform_images_by_id[each.value.platform_image.ocid].shapes,each.value.shape) : true
    #   error_message = try(each.value.platform_image.ocid,null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid image shape \"${each.value.shape}\" in \"shape\" attribute. Ensure it is spelled correctly. Valid shapes for platform image \"${try(each.value.platform_image.ocid,"")}\" are: ${join(", ",[for v in local.platform_images_by_id[each.value.platform_image.ocid].shapes : "\"${v}\""])}." : "__void__"
    # }
    # Check 12: Check compatible shapes for given platform image name
    precondition {
      condition     = try(each.value.platform_image.name, null) != null ? contains(local.platform_images_by_name[each.value.platform_image.name].shapes, each.value.shape) : true
      error_message = try(each.value.platform_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid image shape \"${each.value.shape}\" in \"shape\" attribute. Ensure it is spelled correctly. Valid shapes for platform image \"${try(each.value.platform_image.name, "")}\" are: ${join(", ", [for v in local.platform_images_by_name[each.value.platform_image.name].shapes : "\"${v}\""])}." : "__void__"
    }
    # Check 13: Check custom image (by name) exists
    precondition {
      condition     = try(each.value.custom_image.name, null) != null ? contains(keys(local.custom_images_by_name), "${each.key}.${each.value.custom_image.name}") : true
      error_message = try(each.value.custom_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": custom image \"${each.value.custom_image.name}\" not found in compartment \"${coalesce(each.value.custom_image.compartment_id, var.instances_configuration.default_compartment_id)}\"." : "__void__"
    }
    # Check 14: Check compatible settings for flexible platform shapes
    # precondition {
    #   condition = try(each.value.platform_image.name,null) != null && length(regexall("FLEX",upper(each.value.shape))) > 0 && each.value.flex_shape_settings != null ? local.platform_images_by_name[each.value.platform_image.name].min_ocpu <= try(each.value.flex_shape_settings.ocpus,0) && local.platform_images_by_name[each.value.platform_image.name].max_ocpu >= try(each.value.flex_shape_settings.ocpus,0) : true
    #   error_message = try(each.value.platform_image.name,null) != null && length(regexall("FLEX",upper(each.value.shape))) > 0 && each.value.flex_shape_settings != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid ocpu setting \"${each.value.flex_shape_settings.ocpus}\" in \"flexible_shape_settings.ocpu\" attribute for \"${try(each.value.platform_image.name,"")}\". Number of ocpus range from \"${try(local.platform_images_by_name[each.value.platform_image.name].min_ocpu,"")}\" to \"${try(local.platform_images_by_name[each.value.platform_image.name].max_ocpu,"")}\"." : "__void__"
    # }
    # Check 15: Check ZPR attributes dupes
    precondition {
      condition     = try(each.value.security.zpr_attributes, null) != null ? length(distinct([for a in each.value.security.zpr_attributes : "${a.namespace}.${a.attr_name}"])) == length([for a in each.value.security.zpr_attributes : "${a.namespace}.${a.attr_name}"]) : true
      error_message = try(each.value.security.zpr_attributes, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\" for \"security.zpr-attributes\" attribute: ZPR attribute assigned more than once. \"namespace/attr_name\" pairs must be unique." : "__void__"
      #error_message = try(each.value.security.zpr_attributes,null) != null ? "VALIDATION FAILURE in instance \"${each.key}\" for \"security.zpr-attributes\" attribute: ZPR attribute assigned more than once. ${[for a in each.value.security.zpr_attributes : "${a.namespace}.${a.attr_name}" if contains(local.zpr_provided_attributes[each.key],) ]} \"namespace/attr_name\" pairs must be unique." : "__void__"
    }
  }
  compartment_id       = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  availability_domain  = data.oci_identity_availability_domains.ads[each.key].availability_domains[(each.value.placement != null ? each.value.placement.availability_domain : 1) - 1].name
  fault_domain         = format("FAULT-DOMAIN-%s", each.value.placement != null ? each.value.placement.fault_domain : 1)
  shape                = each.value.shape
  security_attributes  = try(each.value.security.zpr_attributes, null) != null ? try(each.value.security.apply_to_primary_vnic_only, false) == false ? merge([for a in each.value.security.zpr_attributes : { "${a.namespace}.${a.attr_name}.value" : a.attr_value, "${a.namespace}.${a.attr_name}.mode" : a.mode }]...) : null : null
  display_name         = each.value.name
  preserve_boot_volume = each.value.boot_volume != null ? each.value.boot_volume.preserve_on_instance_deletion : true
  defined_tags         = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
  freeform_tags        = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
  # some images don't allow encrypt in transit
  is_pv_encryption_in_transit_enabled = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? true : (each.value.encryption != null ? each.value.encryption.encrypt_in_transit_on_instance_create : null)
  create_vnic_details {
    private_ip             = each.value.networking != null ? each.value.networking.private_ip : null
    assign_public_ip       = each.value.networking != null ? coalesce(each.value.networking.assign_public_ip, false) : false
    subnet_id              = each.value.networking != null ? (each.value.networking.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.networking.subnet_id)) > 0 ? each.value.networking.subnet_id : var.network_dependency["subnets"][each.value.networking.subnet_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)
    hostname_label         = each.value.networking != null ? (coalesce(each.value.networking.hostname, lower(replace(each.value.name, " ", "")))) : lower(replace(each.value.name, " ", ""))
    nsg_ids                = each.value.networking != null ? [for nsg in coalesce(each.value.networking.network_security_groups, []) : (length(regexall("^ocid1.*$", nsg)) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id)] : null
    skip_source_dest_check = each.value.networking != null ? each.value.networking.skip_source_dest_check : false
    security_attributes    = try(each.value.security.zpr_attributes, null) != null ? try(each.value.security.apply_to_primary_vnic_only, false) == true ? merge([for a in each.value.security.zpr_attributes : { "${a.namespace}.${a.attr_name}.value" : a.attr_value, "${a.namespace}.${a.attr_name}.mode" : a.mode }]...) : null : null
  }
  source_details {
    boot_volume_size_in_gbs = each.value.boot_volume != null ? each.value.boot_volume.size : 50
    boot_volume_vpus_per_gb = each.value.boot_volume != null ? each.value.boot_volume.vpus_per_gb : 10
    source_type             = "image"
    source_id               = each.value.marketplace_image != null ? (local.mkp_image_details[each.key] != null ? local.mkp_image_details[each.key].mkp_image_ocid : "undefined") : (each.value.platform_image != null ? (each.value.platform_image.ocid != null ? each.value.platform_image.ocid : each.value.platform_image.name != null ? local.platform_images_by_name[each.value.platform_image.name].id : "undefined") : (each.value.custom_image != null ? (each.value.custom_image.ocid != null ? each.value.custom_image.ocid : each.value.custom_image.name != null ? local.custom_images_by_name["${each.key}.${each.value.custom_image.name}"].id : "undefined") : "undefined"))
    kms_key_id              = each.value.encryption != null ? (each.value.encryption.kms_key_id != null ? (length(regexall("^ocid1.*$", each.value.encryption.kms_key_id)) > 0 ? each.value.encryption.kms_key_id : var.kms_dependency[each.value.encryption.kms_key_id].id) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)) : (var.instances_configuration.default_kms_key_id != null ? (length(regexall("^ocid1.*$", var.instances_configuration.default_kms_key_id)) > 0 ? var.instances_configuration.default_kms_key_id : var.kms_dependency[var.instances_configuration.default_kms_key_id].id) : null)
  }
  launch_options {
    boot_volume_type                    = each.value.boot_volume != null ? upper(each.value.boot_volume.type) : "PARAVIRTUALIZED"
    firmware                            = each.value.boot_volume != null ? (each.value.boot_volume.firmware != null ? upper(each.value.boot_volume.firmware) : null) : null
    network_type                        = each.value.networking != null ? upper(each.value.networking.type) : "PARAVIRTUALIZED"
    remote_data_volume_type             = upper(each.value.volumes_emulation_type)
    is_pv_encryption_in_transit_enabled = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? true : (each.value.encryption != null ? each.value.encryption.encrypt_in_transit_on_instance_update : null)
  }
  dynamic "platform_config" {
    for_each = each.value.platform_type != null || coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? [1] : []
    content {
      type                               = each.value.platform_type
      is_secure_boot_enabled             = coalesce(each.value.cis_level, var.instances_configuration.default_cis_level, "1") == "2" ? true : (each.value.boot_volume != null ? (split(".", each.value.shape)[0] == "VM" && each.value.boot_volume.measured_boot == true ? each.value.boot_volume.measured_boot : each.value.boot_volume.secure_boot) : false)
      is_measured_boot_enabled           = each.value.boot_volume != null ? each.value.boot_volume.measured_boot : false
      is_trusted_platform_module_enabled = each.value.boot_volume != null ? (split(".", each.value.shape)[0] == "VM" && each.value.boot_volume.measured_boot == true ? each.value.boot_volume.measured_boot : each.value.boot_volume.trusted_platform_module) : false
      is_memory_encryption_enabled       = each.value.encryption != null ? each.value.encryption.encrypt_data_in_use : false
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
        for_each = coalesce(each.value.cloud_agent.plugins, [])
        iterator = plugin
        content {
          name          = plugin.value.name
          desired_state = plugin.value.enabled ? "ENABLED" : "DISABLED"
        }
      }
    }
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = coalesce(each.value.disable_legacy_imds_endpoints, var.instances_configuration.default_disable_legacy_imds_endpoints, true)
  }

  metadata = {
    ssh_authorized_keys = each.value.ssh_public_key_path != null ? (fileexists(each.value.ssh_public_key_path) ? file(each.value.ssh_public_key_path) : each.value.ssh_public_key_path) : var.instances_configuration.default_ssh_public_key_path != null ? (fileexists(var.instances_configuration.default_ssh_public_key_path) ? file(var.instances_configuration.default_ssh_public_key_path) : var.instances_configuration.default_ssh_public_key_path) : null
    user_data           = contains(keys(data.template_file.cloud_config), each.key) ? base64encode(data.template_file.cloud_config[each.key].rendered) : null
  }
  compute_cluster_id = each.value.cluster_id != null ? (contains(keys(oci_core_compute_cluster.these), each.value.cluster_id) ? oci_core_compute_cluster.these[each.value.cluster_id].id : (length(regexall("^ocid1.*$", each.value.cluster_id)) > 0 ? each.value.cluster_id : null)) : null
}

resource "oci_core_volume_backup_policy_assignment" "these_boot_volumes" {
  for_each  = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  asset_id  = oci_core_instance.these[each.key].boot_volume_id
  policy_id = local.oracle_backup_policies[lower(each.value.boot_volume != null ? each.value.boot_volume.backup_policy : "bronze")]
}

data "template_file" "cloud_config" {
  for_each = var.instances_configuration != null ? { for k, v in var.instances_configuration["instances"] : k => v if v.cloud_init != null || var.instances_configuration.default_cloud_init_heredoc_script != null || var.instances_configuration.default_cloud_init_script_file != null } : {}
  template = coalesce(try(each.value.cloud_init.heredoc_script, null), try(file(try(each.value.cloud_init.script_file, null)), null), var.instances_configuration.default_cloud_init_heredoc_script, try(file(var.instances_configuration.default_cloud_init_script_file), null), "__void__")
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
  for_each       = var.instances_configuration != null ? var.instances_configuration["instances"] : {}
  compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  instance_id    = oci_core_instance.these[each.key].id
}

locals {
  secondary_vnics = flatten([
    for inst_key, inst_value in(var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for vnic_key, vnic_value in(inst_value.networking != null ? (inst_value.networking.secondary_vnics != null ? inst_value.networking.secondary_vnics : {}) : {}) : {
        key                     = "${inst_key}.${vnic_key}"
        inst_key                = inst_key
        display_name            = vnic_value.display_name
        private_ip              = vnic_value.private_ip
        hostname                = vnic_value.hostname
        assign_public_ip        = vnic_value.assign_public_ip
        subnet_id               = vnic_value.subnet_id
        network_security_groups = vnic_value.network_security_groups
        skip_source_dest_check  = vnic_value.skip_source_dest_check
        nic_index               = vnic_value.nic_index
        security                = vnic_value.security
        defined_tags            = vnic_value.defined_tags
        freeform_tags           = vnic_value.freeform_tags
      }
    ]
  ])

  primary_vnic_secondary_ips = flatten([
    for inst_key, inst_value in(var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for ip_key, ip_value in(inst_value.networking != null ? (inst_value.networking.secondary_ips != null ? inst_value.networking.secondary_ips : {}) : {}) : {
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
    for inst_key, inst_value in(var.instances_configuration != null ? var.instances_configuration["instances"] : {}) : [
      for vnic_key, vnic_value in(inst_value.networking != null ? (inst_value.networking.secondary_vnics != null ? inst_value.networking.secondary_vnics : {}) : {}) : [
        for ip_key, ip_value in(vnic_value.secondary_ips != null ? vnic_value.secondary_ips : {}) : {
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
    inst_key                = v.inst_key
    display_name            = v.display_name
    private_ip              = v.private_ip
    hostname                = v.hostname
    assign_public_ip        = v.assign_public_ip
    subnet_id               = v.subnet_id
    network_security_groups = v.network_security_groups
    skip_source_dest_check  = v.skip_source_dest_check
    nic_index               = v.nic_index
    security                = v.security
    defined_tags            = v.defined_tags
    freeform_tags           = v.freeform_tags
  } }
  # Check 1: Check ZPR attributes dupes
  lifecycle {
    precondition {
      condition     = try(each.value.security.zpr_attributes, null) != null ? length(toset([for a in each.value.security.zpr_attributes : "${a.namespace}.${a.attr_name}"])) == length([for a in each.value.security.zpr_attributes : "${a.namespace}.${a.attr_name}"]) : true
      error_message = try(each.value.security.zpr_attributes, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": ZPR security attribute assigned more than once. \"security.zpr-attributes.namespace/security.zpr-attributes.attr_name\" pairs must be unique." : "__void__"
    }
  }
  display_name = each.value.display_name
  instance_id  = oci_core_instance.these[each.value.inst_key].id
  nic_index    = each.value.nic_index
  create_vnic_details {
    display_name           = each.value.display_name
    assign_public_ip       = each.value.assign_public_ip
    private_ip             = each.value.private_ip
    hostname_label         = each.value.hostname
    subnet_id              = each.value.subnet_id != null ? (length(regexall("^ocid1.*$", each.value.subnet_id)) > 0 ? each.value.subnet_id : var.network_dependency["subnets"][each.value.subnet_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_subnet_id)) > 0 ? var.instances_configuration.default_subnet_id : var.network_dependency["subnets"][var.instances_configuration.default_subnet_id].id)
    nsg_ids                = [for nsg in coalesce(each.value.network_security_groups, []) : (length(regexall("^ocid1.*$", nsg)) > 0 ? nsg : var.network_dependency["network_security_groups"][nsg].id)]
    skip_source_dest_check = each.value.skip_source_dest_check
    security_attributes    = try(each.value.security.zpr_attributes, null) != null ? merge([for a in each.value.security.zpr_attributes : { "${a.namespace}.${a.attr_name}.value" : a.attr_value, "${a.namespace}.${a.attr_name}.mode" : a.mode }]...) : null
    defined_tags           = each.value.defined_tags != null ? each.value.defined_tags : var.instances_configuration.default_defined_tags
    freeform_tags          = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.instances_configuration.default_freeform_tags)
  }
}

data "oci_core_vnic" "these" {
  for_each = oci_core_vnic_attachment.these
  vnic_id  = each.value.vnic_id
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
