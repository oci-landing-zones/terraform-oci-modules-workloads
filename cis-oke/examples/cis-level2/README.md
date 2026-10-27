# CIS level 2 managed pool (0.3.0)

Creates a CIS level 2 cluster and managed pool with existing cluster-secret and worker-volume encryption keys. Supply key OCIDs (not Vault OCIDs). The Landing Zone must already grant the cluster and worker services the required KMS access. All pools inherit CIS level 2 and the cluster compartment.

Follow the [shared prerequisites and run instructions](../README.md). Copy
`terraform.tfvars.example` to `terraform.tfvars`, replace all placeholders, and
configure OCI authentication. This example uses the local 0.3.0 module.
