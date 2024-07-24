
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "storage" {
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci.block_volumes_replication_region
  }
  storage_configuration   = var.storage_configuration
}
