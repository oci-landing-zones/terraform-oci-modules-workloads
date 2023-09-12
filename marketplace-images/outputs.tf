# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "marketplace_images" {
  value = var.word_to_search_for_in_image_name != null || length(trimspace(var.word_to_search_for_in_image_name)) > 0 ? local.filtered_images : local.list_images
}

