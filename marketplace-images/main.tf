# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

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

  list_images = join("\n", [for i in local.versions : format("Publisher: %s\n Image name: %s\n Listing resource id: %s\n Resource version: %s\n\n\n", i.publisher, i.display_name, i.listing_resource_id, i.resource_version)])

  filtered_images = join("\n", compact([
    for i in local.versions :
    length(regexall(var.word_to_search_for_in_image_name, i.display_name)) > 0 ?
    format("Publisher: %s\nImage name: %s\nListing resource id: %s\nResource version: %s\n", i.publisher, i.display_name, i.listing_resource_id, i.resource_version) :
    null
  ]))
}

data "oci_core_app_catalog_listing_resource_versions" "existing" {
  for_each   = local.helper
  listing_id = each.value
}


