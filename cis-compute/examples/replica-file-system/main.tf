
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "compute" {
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci.replication_region
  }
  instances_configuration = var.instances_configuration
  storage_configuration   = var.storage_configuration
}
