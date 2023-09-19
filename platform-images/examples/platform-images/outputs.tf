# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "platform_images" {
  value = module.platform_images.all_images
}

resource "local_file" "filtered_images" {
  content  = "${format("List of platform images filtered by \"%s\":\n\n", var.filter_string)}${module.platform_images.filtered_images}"
  filename = "./platform_images.txt"
}

