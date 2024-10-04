locals {

  mkp_instances = var.instances_configuration != null ? (var.instances_configuration["instances"] != null ? {for k, v in var.instances_configuration["instances"] : k => v if v.marketplace_image != null} : {}) : {}
  
  mkp_image_details = local.mkp_instances == null ? {} : {
    for k, v in local.mkp_instances : k => {
      mkp_image_name                      = v.marketplace_image.name
      mkp_image_version                   = v.marketplace_image.version
      mkp_image_ocid                      = data.oci_core_app_catalog_listing_resource_version.this[k].listing_resource_id
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
  for_each = local.mkp_instances
    agreement_id    = oci_marketplace_listing_package_agreement.these[each.key].agreement_id
    compartment_id  = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.instances_configuration.default_compartment_id)) > 0 ? var.instances_configuration.default_compartment_id : var.compartments_dependency[var.instances_configuration.default_compartment_id].id)
    listing_id      = data.oci_marketplace_listing.this[each.key].id
    package_version = each.value.marketplace_image.version != null ? replace(each.value.marketplace_image.version,"_"," ") : data.oci_marketplace_listing.this[each.key].default_package_version
    signature       = oci_marketplace_listing_package_agreement.these[each.key].signature
}

resource "oci_marketplace_listing_package_agreement" "these" {
  for_each = local.mkp_instances
    lifecycle {
      precondition {
        condition = each.value.marketplace_image != null ? (each.value.marketplace_image.version != null ? contains([for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : v.listing_resource_version],each.value.marketplace_image.version) : true) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid Marketplace image version \"${coalesce(each.value.marketplace_image.version,replace(data.oci_marketplace_listing.this[each.key].default_package_version," ","_"))}\" in \"marketplace_image.version\" attribute. Ensure it is spelled correctly. Valid versions for image name \"${each.value.marketplace_image.name}\" are: ${join(", ",[for v in data.oci_core_app_catalog_listing_resource_versions.these[each.key].app_catalog_listing_resource_versions : "\"${v.listing_resource_version}\""])}."
      }
    }    
    agreement_id    = data.oci_marketplace_listing_package_agreements.these[each.key].agreements.0.id
    listing_id      = data.oci_marketplace_listing.this[each.key].id
    package_version = each.value.marketplace_image.version != null ? replace(each.value.marketplace_image.version,"_"," ") : data.oci_marketplace_listing.this[each.key].default_package_version
}

data "oci_marketplace_listing_package_agreements" "these" {
  for_each = local.mkp_instances
    listing_id      = data.oci_marketplace_listing.this[each.key].id
    package_version = each.value.marketplace_image.version != null ? replace(each.value.marketplace_image.version,"_"," ") : data.oci_marketplace_listing.this[each.key].default_package_version
}

data "oci_marketplace_listing_package" "this" {
  for_each = local.mkp_instances
    listing_id      = data.oci_marketplace_listing.this[each.key].id
    package_version = each.value.marketplace_image.version != null ? replace(each.value.marketplace_image.version,"_"," ") : data.oci_marketplace_listing.this[each.key].default_package_version
}

data "oci_marketplace_listing_packages" "these" {
  for_each = local.mkp_instances
    listing_id = data.oci_marketplace_listing.this[each.key].id
}

data "oci_marketplace_listing" "this" {
  for_each = local.mkp_instances
  lifecycle {  
     precondition {
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name],each.value.marketplace_image.name) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly. Valid values are: ${join(", ",[for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : "\"${v.display_name}\""])}"
      }
    }
    listing_id = data.oci_marketplace_listings.these[each.key].listings.0.id
}

data "oci_marketplace_listings" "these" {
  for_each = local.mkp_instances
    name = [each.value.marketplace_image.name]
}

data "oci_core_app_catalog_listings" "these" {
  for_each = local.mkp_instances
    display_name = each.value.marketplace_image.name
}

data "oci_core_app_catalog_listing_resource_version" "this" {
  for_each = local.mkp_instances
    lifecycle {  
     precondition {
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name],each.value.marketplace_image.name) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly."
      }
    }
    listing_id       = data.oci_core_app_catalog_listings.these[each.key].app_catalog_listings[0].listing_id
    resource_version = coalesce(each.value.marketplace_image.version,replace(data.oci_marketplace_listing.this[each.key].default_package_version," ","_"))
}

resource "oci_core_app_catalog_listing_resource_version_agreement" "these" {
  for_each =  local.mkp_instances
    lifecycle {  
      precondition {
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name],each.value.marketplace_image.name) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly."
      }
    }
    listing_id               = data.oci_core_app_catalog_listings.these[each.key].app_catalog_listings[0].listing_id
    listing_resource_version = coalesce(each.value.marketplace_image.version,replace(data.oci_marketplace_listing.this[each.key].default_package_version," ","_"))
}    

resource "oci_core_app_catalog_subscription" "these" {
  for_each = local.mkp_instances
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
        condition = each.value.marketplace_image != null ? contains([for v in data.oci_core_app_catalog_listings.all.app_catalog_listings : v.display_name],each.value.marketplace_image.name) : true
        error_message = "VALIDATION FAILURE in instance \"${each.key}\": invalid marketplace image name \"${each.value.marketplace_image.name}\" in \"marketplace_image.name\" attribute. Ensure it is spelled correctly."
      }
    }  
    listing_id = data.oci_core_app_catalog_listings.these[each.key].app_catalog_listings[0].listing_id
}

data "oci_core_app_catalog_listings" "all" {} # Used just to inform users about valid marketplace image names in case an invalid image name is provided.