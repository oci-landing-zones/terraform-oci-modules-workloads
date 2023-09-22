# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {
  description = "Tenancy OCID."
  type        = string
}

variable "image_name_filter" {
  description = "Word to filter returned images."
  type        = string
  default     = ""
}


