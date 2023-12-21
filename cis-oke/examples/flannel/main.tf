
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oke" {
  source = "../.."
  providers = {
    oci = oci
  }
  cluster_configuration = var.cluster_configuration
  worker_configuration  = var.worker_configuration
}
