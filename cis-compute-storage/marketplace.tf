# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {

  mkp_instances_from_configuration = var.instances_configuration != null ? (var.instances_configuration["instances"] != null ? { for k, v in var.instances_configuration["instances"] : k => v if local.instance_source_modes[k] == "image" && v.marketplace_image != null } : {}) : {}

  # Keep Marketplace data-source lookups on a dependency-light map whenever the
  # caller provides one. In parent modules the full instance object often also
  # contains subnet, NSG, KMS, or compartment expressions; if those values are
  # pending, Terraform defers Marketplace data sources to apply and then plans
  # needless agreement/subscription replacement. The two lookup paths are kept
  # separate because Terraform's graph tracks references conservatively, even
  # across conditional expressions.
  mkp_images_from_configuration = var.marketplace_images_configuration == null ? {
    for k, v in local.mkp_instances_from_configuration : k => {
      ocid    = try(v.marketplace_image.ocid, null)
      name    = try(v.marketplace_image.name, null)
      version = try(v.marketplace_image.version, null)
    }
  } : {}

  mkp_images_from_light_configuration = var.marketplace_images_configuration != null ? {
    for k, v in var.marketplace_images_configuration : k => {
      ocid    = try(v.ocid, null)
      name    = try(v.name, null)
      version = try(v.version, null)
    }
    if try(local.instance_source_modes[k], "image") == "image"
  } : {}

  mkp_images = merge(local.mkp_images_from_configuration, local.mkp_images_from_light_configuration)

  mkp_instance_compartment_ids = {
    for k, v in local.mkp_instances_from_configuration : k => try(v.compartment_id, null)
  }

  mkp_marketplace_listings = merge(data.oci_marketplace_listings.from_configuration, data.oci_marketplace_listings.these)

  mkp_listing_details = merge(data.oci_marketplace_listing.from_configuration, data.oci_marketplace_listing.this)

  mkp_app_catalog_listings = merge(data.oci_core_app_catalog_listings.from_configuration, data.oci_core_app_catalog_listings.these)

  mkp_app_catalog_listing_resource_versions = merge(data.oci_core_app_catalog_listing_resource_versions.from_configuration, data.oci_core_app_catalog_listing_resource_versions.these)

  mkp_app_catalog_listing_resource_version = merge(data.oci_core_app_catalog_listing_resource_version.from_configuration, data.oci_core_app_catalog_listing_resource_version.this)

  mkp_listing_package_agreements = merge(data.oci_marketplace_listing_package_agreements.from_configuration, data.oci_marketplace_listing_package_agreements.these)

  mkp_listing_package = merge(data.oci_marketplace_listing_package.from_configuration, data.oci_marketplace_listing_package.this)

  mkp_app_catalog_listing_id_from_configuration = {
    for k, v in local.mkp_images_from_configuration : k => data.oci_core_app_catalog_listings.from_configuration[k].app_catalog_listings[0].listing_id
  }

  mkp_app_catalog_listing_id_from_light_configuration = {
    for k, v in local.mkp_images_from_light_configuration : k => data.oci_core_app_catalog_listings.these[k].app_catalog_listings[0].listing_id
  }

  mkp_app_catalog_listing_id = merge(local.mkp_app_catalog_listing_id_from_configuration, local.mkp_app_catalog_listing_id_from_light_configuration)

  mkp_image_resource_version_from_configuration = {
    for k, v in local.mkp_images_from_configuration : k => try(v.ocid, null) != null ? one([
      for rv in data.oci_core_app_catalog_listing_resource_versions.from_configuration[k].app_catalog_listing_resource_versions : rv.listing_resource_version
      if rv.listing_resource_id == v.ocid
    ]) : (v.version != null ? v.version : replace(data.oci_marketplace_listing.from_configuration[k].default_package_version, " ", "_"))
  }

  mkp_image_resource_version_from_light_configuration = {
    for k, v in local.mkp_images_from_light_configuration : k => try(v.ocid, null) != null ? one([
      for rv in data.oci_core_app_catalog_listing_resource_versions.these[k].app_catalog_listing_resource_versions : rv.listing_resource_version
      if rv.listing_resource_id == v.ocid
    ]) : (v.version != null ? v.version : replace(data.oci_marketplace_listing.this[k].default_package_version, " ", "_"))
  }

  mkp_image_resource_version = merge(local.mkp_image_resource_version_from_configuration, local.mkp_image_resource_version_from_light_configuration)

  mkp_package_version_from_configuration = {
    for k, v in local.mkp_images_from_configuration : k => replace(local.mkp_image_resource_version_from_configuration[k], "_", " ")
  }

  mkp_package_version_from_light_configuration = {
    for k, v in local.mkp_images_from_light_configuration : k => replace(local.mkp_image_resource_version_from_light_configuration[k], "_", " ")
  }

  mkp_package_version = merge(local.mkp_package_version_from_configuration, local.mkp_package_version_from_light_configuration)

  mkp_compatible_shapes = {
    for k, v in local.mkp_images : k => local.mkp_app_catalog_listing_resource_version[k].compatible_shapes
  }

  mkp_image_details = {
    for k, v in local.mkp_images : k => {
      mkp_image_name                      = coalesce(try(v.name, null), local.mkp_listing_details[k].name)
      mkp_image_version                   = local.mkp_listing_package[k].app_catalog_listing_resource_version
      mkp_image_ocid                      = local.mkp_listing_package[k].image_id
      mkp_image_time_published            = local.mkp_app_catalog_listing_resource_version[k].time_published
      mkp_image_agreement_id              = oci_marketplace_accepted_agreement.these[k].id
      mkp_image_agreement_name            = oci_marketplace_accepted_agreement.these[k].display_name
      mkp_image_agreement_accept_time     = oci_marketplace_accepted_agreement.these[k].time_accepted
      mkp_image_publisher                 = local.mkp_listing_details[k].publisher[0].name
      mkp_image_publisher_email           = local.mkp_listing_details[k].publisher[0].contact_email
      mkp_image_publisher_phone           = local.mkp_listing_details[k].publisher[0].contact_phone
      mkp_image_license_model_description = local.mkp_listing_details[k].license_model_description
    }
  }
}

resource "oci_marketplace_accepted_agreement" "these" {
  for_each        = local.mkp_images
  agreement_id    = oci_marketplace_listing_package_agreement.these[each.key].agreement_id
  compartment_id  = try(local.mkp_instance_compartment_ids[each.key], null) != null ? (length(regexall("^ocid1.*$", local.mkp_instance_compartment_ids[each.key])) > 0 ? local.mkp_instance_compartment_ids[each.key] : var.compartments_dependency[local.mkp_instance_compartment_ids[each.key]].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  listing_id      = local.mkp_listing_details[each.key].id
  package_version = local.mkp_package_version[each.key]
  signature       = oci_marketplace_listing_package_agreement.these[each.key].signature
}

resource "oci_marketplace_listing_package_agreement" "these" {
  for_each        = local.mkp_images
  agreement_id    = local.mkp_listing_package_agreements[each.key].agreements.0.id
  listing_id      = local.mkp_listing_details[each.key].id
  package_version = local.mkp_package_version[each.key]
}

resource "oci_core_app_catalog_listing_resource_version_agreement" "these" {
  for_each = local.mkp_images
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id               = local.mkp_app_catalog_listing_id[each.key]
  listing_resource_version = local.mkp_image_resource_version[each.key]
}

resource "oci_core_app_catalog_subscription" "these" {
  for_each                 = local.mkp_images
  compartment_id           = try(local.mkp_instance_compartment_ids[each.key], null) != null ? (length(regexall("^ocid1.*$", local.mkp_instance_compartment_ids[each.key])) > 0 ? local.mkp_instance_compartment_ids[each.key] : var.compartments_dependency[local.mkp_instance_compartment_ids[each.key]].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].time_retrieved
}

data "oci_marketplace_listing_package_agreements" "from_configuration" {
  for_each        = local.mkp_images_from_configuration
  listing_id      = data.oci_marketplace_listing.from_configuration[each.key].id
  package_version = local.mkp_package_version_from_configuration[each.key]
}

data "oci_marketplace_listing_package_agreements" "these" {
  for_each        = local.mkp_images_from_light_configuration
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version_from_light_configuration[each.key]
}

data "oci_marketplace_listing_package" "from_configuration" {
  for_each        = local.mkp_images_from_configuration
  listing_id      = data.oci_marketplace_listing.from_configuration[each.key].id
  package_version = local.mkp_package_version_from_configuration[each.key]
}

data "oci_marketplace_listing_package" "this" {
  for_each        = local.mkp_images_from_light_configuration
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version_from_light_configuration[each.key]
}

data "oci_marketplace_listing_packages" "from_configuration" {
  for_each        = local.mkp_images_from_configuration
  listing_id      = data.oci_marketplace_listing.from_configuration[each.key].id
  package_version = local.mkp_package_version_from_configuration[each.key]
}

data "oci_marketplace_listing_packages" "these" {
  for_each        = local.mkp_images_from_light_configuration
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version_from_light_configuration[each.key]
}

data "oci_marketplace_listing" "from_configuration" {
  for_each = local.mkp_images_from_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly. Valid values are: ${join(", ", [for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : "\"${v.display_name}\""])}" : "__void__"
    }
  }
  listing_id = data.oci_marketplace_listings.from_configuration[each.key].listings.0.id
}

data "oci_marketplace_listing" "this" {
  for_each = local.mkp_images_from_light_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly. Valid values are: ${join(", ", [for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : "\"${v.display_name}\""])}" : "__void__"
    }
  }
  listing_id = data.oci_marketplace_listings.these[each.key].listings.0.id
}

data "oci_marketplace_listings" "from_configuration" {
  for_each = local.mkp_images_from_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.ocid, null) != null || try(each.value.name, null) != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"marketplace_image.ocid\" or \"marketplace_image.name\" must be provided."
    }
    postcondition {
      condition     = length(self.listings) > 0
      error_message = try(each.value.ocid, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": marketplace image OCID \"${each.value.ocid}\" did not resolve to a Marketplace listing." : "VALIDATION FAILURE in instance \"${each.key}\": marketplace image name \"${each.value.name}\" did not resolve to a Marketplace listing."
    }
  }
  image_id = try(each.value.ocid, null)
  name     = try(each.value.ocid, null) == null && try(each.value.name, null) != null ? [each.value.name] : []
}

data "oci_marketplace_listings" "these" {
  for_each = local.mkp_images_from_light_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.ocid, null) != null || try(each.value.name, null) != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"marketplace_image.ocid\" or \"marketplace_image.name\" must be provided."
    }
    postcondition {
      condition     = length(self.listings) > 0
      error_message = try(each.value.ocid, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": marketplace image OCID \"${each.value.ocid}\" did not resolve to a Marketplace listing." : "VALIDATION FAILURE in instance \"${each.key}\": marketplace image name \"${each.value.name}\" did not resolve to a Marketplace listing."
    }
  }
  image_id = try(each.value.ocid, null)
  name     = try(each.value.ocid, null) == null && try(each.value.name, null) != null ? [each.value.name] : []
}

data "oci_core_app_catalog_listings" "from_configuration" {
  for_each     = local.mkp_images_from_configuration
  display_name = coalesce(try(each.value.name, null), data.oci_marketplace_listing.from_configuration[each.key].name)
}

data "oci_core_app_catalog_listings" "these" {
  for_each     = local.mkp_images_from_light_configuration
  display_name = coalesce(try(each.value.name, null), data.oci_marketplace_listing.this[each.key].name)
}

data "oci_core_app_catalog_listing_resource_version" "from_configuration" {
  for_each = local.mkp_images_from_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id       = local.mkp_app_catalog_listing_id_from_configuration[each.key]
  resource_version = local.mkp_image_resource_version_from_configuration[each.key]
}

data "oci_core_app_catalog_listing_resource_version" "this" {
  for_each = local.mkp_images_from_light_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id       = local.mkp_app_catalog_listing_id_from_light_configuration[each.key]
  resource_version = local.mkp_image_resource_version_from_light_configuration[each.key]
}

data "oci_core_app_catalog_listing_resource_versions" "from_configuration" {
  for_each = local.mkp_images_from_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id = local.mkp_app_catalog_listing_id_from_configuration[each.key]
}

data "oci_core_app_catalog_listing_resource_versions" "these" {
  for_each = local.mkp_images_from_light_configuration
  lifecycle {
    precondition {
      condition     = try(each.value.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.name) : true
      error_message = try(each.value.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id = local.mkp_app_catalog_listing_id_from_light_configuration[each.key]
}

data "oci_core_app_catalog_listings" "all" {} # Used just to inform users about valid marketplace image names in case an invalid image name is provided.
