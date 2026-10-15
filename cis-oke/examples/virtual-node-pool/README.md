# Virtual node pool (0.3.0)

Creates one native cluster and a virtual pool. Pod NSGs must be nonempty. Fault-domain placement and cloud-init are intentionally omitted for virtual pools. Workloads must tolerate `workload=virtual:NoSchedule`.

Follow the [shared prerequisites and run instructions](../README.md). Copy
`terraform.tfvars.example` to `terraform.tfvars`, replace all placeholders, and
configure OCI authentication. This example uses the local 0.3.0 module.
