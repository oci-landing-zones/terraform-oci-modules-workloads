# Official upstream wrapper example

Supply existing compartment, VCN, subnet OCIDs, region and an OCI-supported
Kubernetes version, plus OCI provider credentials using your usual provider
configuration. The example creates a private enhanced/native cluster and two
managed pools. Both inherit shared settings; `batch` overrides size and OCPUs.

It creates no networking or IAM. Required network rules, routes and IAM policies
must already exist. For CIS level 2, set the cluster and pool CIS levels and supply
existing KMS keys using the main module's inputs.

Read the module's [limitations](../../README.md) and [migration guide](../../MIGRATION.md).
Run Terraform 1.5.7 init/plan, save the plan, inspect its JSON with
`tools/check_plan.py --module-address module.oke`, and review it before apply.
No existing cluster is implicitly adopted by this example.

For worker-only deployments, omit `clusters_configuration` and use
`cluster_ref = { id = "<existing-cluster-ocid>" }` with an explicit/default pool
compartment. For a virtual pool, use `mode = "virtual-node-pool"`, a supported pod
shape, and a nonempty `pod_nsg_ids` list. Explicit virtual fault domains are blocked
in the currently pinned upstream version.
