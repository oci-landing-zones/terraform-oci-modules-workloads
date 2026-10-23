# GVA managed pool (0.3.0)

Creates a native cluster and managed pool with one secondary VNIC profile, plus a harmless custom cloud-config part alongside the upstream boot scripts. GVA replaces the ordinary pod networking configuration, so no ordinary pod subnet is supplied. GVA VNICs are private and IPv4-only. Check shape VNIC limits and subnet capacity. This example does not install Multus or workload network attachments.

Follow the [shared prerequisites and run instructions](../README.md). Copy
`terraform.tfvars.example` to `terraform.tfvars`, replace all placeholders, and
configure OCI authentication. This example uses the local 0.3.0 module.
