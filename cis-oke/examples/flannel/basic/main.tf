# Legacy example: pinned to the pre-refactor module. See ../../upstream-wrapper.
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oke" {
  source                 = "git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke?ref=d7da10394a828f225b4ac19aa5ac14a9838b75ac"
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}
