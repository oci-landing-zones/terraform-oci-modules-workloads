# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_core_images" "these" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_image_shapes" "these" {
  for_each = {for i in data.oci_core_images.these.images : i.id => {"display_name" : i.display_name}}
    image_id = each.key
}

locals {
  
  all_platform_images = [
    for i in data.oci_core_images.these.images :
     { "display_name" : i.display_name, "publisher_name" : "Oracle", "id" : i.id, "operating_system" : i.operating_system,  "operating_system_version" : i.operating_system_version, "encryption_in_transit" : i.launch_options[0].is_pv_encryption_in_transit_enabled, "state" : i.state, "shapes" : [for s in data.oci_core_image_shapes.these[i.id].image_shape_compatibilities : s.shape]}
  ]

  filtered_images = join("\n", compact([
    for i in local.all_platform_images :
    length(regexall(upper(var.image_name_filter), upper(i.display_name))) > 0 ?
    format(" Display Name: %s\n Publisher Name: %s\n Id: %s\n Operating System: %s\n Operating System Version: %s\n Is encryption in transit enabled? %s\n State: %s\n Compatible shapes: %s\n", i.display_name, "Oracle", i.id, i.operating_system, i.operating_system_version, i.encryption_in_transit, i.state, join(", ",i.shapes)) :
    null
  ]))
}

