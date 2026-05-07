# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Drop-in replacement for marketplace.tf.
# Terraform cannot load this file together with marketplace.tf because both define the same
# locals, data sources, and resources. Keep only one implementation active in the module.

locals {

  mkp_instances = var.instances_configuration != null ? (var.instances_configuration["instances"] != null ? { for k, v in var.instances_configuration["instances"] : k => v if v.marketplace_image != null } : {}) : {}

  mkp_app_catalog_listing_id = local.mkp_instances == null ? {} : {
    for k, v in local.mkp_instances : k => data.oci_core_app_catalog_listings.these[k].app_catalog_listings[0].listing_id
  }

  mkp_image_resource_version = local.mkp_instances == null ? {} : {
    for k, v in local.mkp_instances : k => try(v.marketplace_image.ocid, null) != null ? one([
      for rv in data.oci_core_app_catalog_listing_resource_versions.these[k].app_catalog_listing_resource_versions : rv.listing_resource_version
      if rv.listing_resource_id == v.marketplace_image.ocid
    ]) : (v.marketplace_image.version != null ? v.marketplace_image.version : replace(data.oci_marketplace_listing.this[k].default_package_version, " ", "_"))
  }

  mkp_package_version = local.mkp_instances == null ? {} : {
    for k, v in local.mkp_instances : k => replace(local.mkp_image_resource_version[k], "_", " ")
  }
  mkp_image_details = local.mkp_instances == null ? {} : {
    for k, v in local.mkp_instances : k => {
      mkp_image_name                      = coalesce(try(v.marketplace_image.name, null), data.oci_marketplace_listing.this[k].name)
      mkp_image_version                   = data.oci_marketplace_listing_package.this[k].app_catalog_listing_resource_version
      mkp_image_ocid                      = data.oci_marketplace_listing_package.this[k].image_id
      mkp_image_time_published            = data.oci_core_app_catalog_listing_resource_version.this[k].time_published
      mkp_image_agreement_id              = oci_marketplace_accepted_agreement.these[k].id
      mkp_image_agreement_name            = oci_marketplace_accepted_agreement.these[k].display_name
      mkp_image_agreement_accept_time     = oci_marketplace_accepted_agreement.these[k].time_accepted
      mkp_image_publisher                 = data.oci_marketplace_listing.this[k].publisher[0].name
      mkp_image_publisher_email           = data.oci_marketplace_listing.this[k].publisher[0].contact_email
      mkp_image_publisher_phone           = data.oci_marketplace_listing.this[k].publisher[0].contact_phone
      mkp_image_license_model_description = data.oci_marketplace_listing.this[k].license_model_description
    }
  }
}

resource "oci_marketplace_accepted_agreement" "these" {
  for_each        = local.mkp_instances
  agreement_id    = oci_marketplace_listing_package_agreement.these[each.key].agreement_id
  compartment_id  = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version[each.key]
  signature       = oci_marketplace_listing_package_agreement.these[each.key].signature
}

resource "oci_marketplace_listing_package_agreement" "these" {
  for_each        = local.mkp_instances
  agreement_id    = data.oci_marketplace_listing_package_agreements.these[each.key].agreements.0.id
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version[each.key]
}

data "oci_marketplace_listing_package_agreements" "these" {
  for_each        = local.mkp_instances
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version[each.key]
}

data "oci_marketplace_listing_package" "this" {
  for_each        = local.mkp_instances
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version[each.key]
}

data "oci_marketplace_listing_packages" "these" {
  for_each        = local.mkp_instances
  listing_id      = data.oci_marketplace_listing.this[each.key].id
  package_version = local.mkp_package_version[each.key]
}

data "oci_marketplace_listing" "this" {
  for_each = local.mkp_instances
  lifecycle {
    precondition {
      condition     = try(each.value.marketplace_image.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.marketplace_image.name) : true
      error_message = try(each.value.marketplace_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly. Valid values are: ${join(", ", [for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : "\"${v.display_name}\""])}" : "__void__"
    }
  }
  listing_id = data.oci_marketplace_listings.these[each.key].listings.0.id
}

data "oci_marketplace_listings" "these" {
  for_each = local.mkp_instances
  lifecycle {
    precondition {
      condition     = try(each.value.marketplace_image.ocid, null) != null || try(each.value.marketplace_image.name, null) != null
      error_message = "VALIDATION FAILURE in instance \"${each.key}\": either \"marketplace_image.ocid\" or \"marketplace_image.name\" must be provided."
    }
    postcondition {
      condition     = length(self.listings) > 0
      error_message = try(each.value.marketplace_image.ocid, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": marketplace image OCID \"${each.value.marketplace_image.ocid}\" did not resolve to a Marketplace listing." : "VALIDATION FAILURE in instance \"${each.key}\": marketplace image name \"${each.value.marketplace_image.name}\" did not resolve to a Marketplace listing."
    }
  }
  image_id = try(each.value.marketplace_image.ocid, null)
  name     = try(each.value.marketplace_image.ocid, null) == null && try(each.value.marketplace_image.name, null) != null ? [each.value.marketplace_image.name] : []
}

data "oci_core_app_catalog_listings" "these" {
  for_each     = local.mkp_instances
  display_name = coalesce(try(each.value.marketplace_image.name, null), data.oci_marketplace_listing.this[each.key].name)
}

data "oci_core_app_catalog_listing_resource_version" "this" {
  for_each = local.mkp_instances
  lifecycle {
    precondition {
      condition     = try(each.value.marketplace_image.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.marketplace_image.name) : true
      error_message = try(each.value.marketplace_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id       = local.mkp_app_catalog_listing_id[each.key]
  resource_version = local.mkp_image_resource_version[each.key]
}

resource "oci_core_app_catalog_listing_resource_version_agreement" "these" {
  for_each = local.mkp_instances
  lifecycle {
    precondition {
      condition     = try(each.value.marketplace_image.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.marketplace_image.name) : true
      error_message = try(each.value.marketplace_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id               = local.mkp_app_catalog_listing_id[each.key]
  listing_resource_version = local.mkp_image_resource_version[each.key]
}

resource "oci_core_app_catalog_subscription" "these" {
  for_each                 = local.mkp_instances
  compartment_id           = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.these[each.key].time_retrieved
}

data "oci_core_app_catalog_listing_resource_versions" "these" {
  for_each = local.mkp_instances
  lifecycle {
    precondition {
      condition     = try(each.value.marketplace_image.name, null) != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name], each.value.marketplace_image.name) : true
      error_message = try(each.value.marketplace_image.name, null) != null ? "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly." : "__void__"
    }
  }
  listing_id = local.mkp_app_catalog_listing_id[each.key]
}

data "oci_core_app_catalog_listings" "all" {} # Used just to inform users about valid marketplace image names in case an invalid image name is provided.



