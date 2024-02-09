# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oke" {
  source                 = "../../"
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}

module "operator_instance" {
  source = "../../../cis-compute-storage/"
  providers = {
    oci                                  = oci
    oci.block_volumes_replication_region = oci
  }
  instances_configuration = var.instances_configuration
}
