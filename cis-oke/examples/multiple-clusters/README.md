# Multiple clusters with one-cluster CIS OKE instances

Set `deployments` to a map keyed by a stable caller identity (for example `platform`
and `applications`). Each entry contains a flat `cluster_configuration`, optional
`workers_configuration`, and optional compartment/network/KMS dependency maps.
Copy the inputs from [the single-cluster example](../upstream-wrapper) into each
entry. There is no key or cluster reference inside the CIS OKE input itself.

```hcl
deployments = {
  platform = {
    cluster_configuration = {
      name = "platform"
      compartment_id = "COMP"
      networking = {
        vcn_id = "VCN"
        api_endpoint_subnet_id = "API"
        service_lb_subnet_ids = ["LB"]
      }
    }
    compartments_dependency = { COMP = { id = "<compartment-ocid>" } }
    network_dependency = {
      vcns = { VCN = { id = "<vcn-ocid>" } }
      subnets = {
        API = { id = "<api-subnet-ocid>" }
        LB = { id = "<lb-subnet-ocid>" }
      }
    }
  }
  # Add applications = { cluster_configuration = {...}, workers_configuration = {...} }
}
```

Replace placeholders with existing OCI resources. Worker pools and defaults are
local to each entry. Outputs stay nested under caller identities, so the same
pool key can be reused in different clusters. Entries share this root's state and
apply; use separate stacks for independent lifecycle management. All entries use
the configured region. This example creates no networking or IAM and does not
modify the Landing Zone orchestrator.

Run Terraform 1.5.7 init/plan, export the saved plan JSON, and run check_plan.py
once per invocation, using e.g. `--module-address 'module.oke["platform"]'`.
Review legacy address moves before replacing a multi-cluster module invocation;
the single-cluster converter intentionally does not guess a fan-out mapping.
