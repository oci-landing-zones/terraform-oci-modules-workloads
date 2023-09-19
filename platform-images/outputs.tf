# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "all_images" {
  value = data.oci_core_images.these
}  

output "filtered_images" {
  value = local.filtered_images
}

