# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "marketplace_images" {
  source = "../../"
  word_to_search_for_in_image_name = var.filter_string
}
