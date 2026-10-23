# Cluster only (0.3.0)

Creates one private enhanced/native control plane and no worker pools. Add workers to this same invocation later; external-cluster worker invocations are unsupported.

Follow the [shared prerequisites and run instructions](../README.md). Copy
`terraform.tfvars.example` to `terraform.tfvars`, replace all placeholders, and
configure OCI authentication. This example uses the local 0.3.0 module.
