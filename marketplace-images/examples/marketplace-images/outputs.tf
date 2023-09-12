# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "marketplace_images" {
  value = module.marketplace_images.marketplace_images
}

resource "local_file" "marketplace_images" {
  content  = module.marketplace_images.marketplace_images
  filename = "./marketplace_images.txt"
}

output "image_shapes" {
  value = module.marketplace_images.image_shapes
}

resource "local_file" "image_shapes" {
  content  = jsonencode(module.marketplace_images.image_shapes)
  filename = "./image_shapes.txt"
}

