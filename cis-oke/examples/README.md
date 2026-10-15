# CIS OKE examples

## Release 0.3.0

These examples call `source = "../.."`, so they exercise the module in this
checkout. Each invocation owns one enhanced cluster with a private API endpoint.

| Example | Demonstrates |
| --- | --- |
| [Cluster only](cluster-only/) | Control plane without workers |
| [Managed pools](upstream-wrapper/) | Global defaults, per-pool sizing and label replacement |
| [Virtual pool](virtual-node-pool/) | Native CNI, pod NSGs and virtual-node taints |
| [CIS level 2](cis-level2/) | Cluster-secret and worker-volume KMS keys |
| [GVA](gva/) | Private IPv4 secondary VNICs and global custom cloud-init |
| [Multiple clusters](multiple-clusters/) | Caller `for_each`, dependency keys and separate pool ownership |

### Prerequisites

Use Terraform 1.5.7 and configure OCI provider authentication through your normal
OCI configuration/environment. Supply existing compartment, VCN, subnet, NSG and
(where requested) KMS key OCIDs, plus a Kubernetes version supported in your region.
Replace every placeholder in the supplied `terraform.tfvars.example`; it is a
configuration template, not deployable as-is. Confirm the selected shapes are
available in your region and have capacity.

The Landing Zone must already provide network routing, security rules and IAM
permissions. These current examples create no networking, bastion, operator host
or IAM resources. Kubernetes administration requires connectivity to the private
API endpoint. Managed pools require images compatible with IMDSv2; upstream boot
scripts are enabled by default. Read the [module limitations](../README.md#explicit-upstream-limitations).

### Run and review

From one example directory:

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and replace every placeholder before continuing.
terraform init
terraform validate
terraform plan -out=plan.out
terraform show -json plan.out > plan.json
python3 ../../tools/check_plan.py plan.json --module-address module.oke
```

For `multiple-clusters`, run the checker separately for each caller instance:

```sh
python3 ../../tools/check_plan.py plan.json --module-address 'module.oke["platform"]'
python3 ../../tools/check_plan.py plan.json --module-address 'module.oke["applications"]'
```

Review the complete saved plan before applying it. Keep tfvars containing secrets,
state and saved plans out of Git. These examples create new clusters; they do not
adopt existing ones. Existing deployments need the module's [upgrade procedure](../README.md#upgrading-existing-deployments), including reviewed state moves.

For remote consumption, replace the relative source with
`git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke?ref=release-0.3.0`
for release testing. Use a published release tag or reviewed commit for repeatability.

## Legacy

The [legacy examples](legacy/) retain the v0.2.9 native/flannel configurations,
including their bastion and operator-host variants. Their OKE sources are pinned
to `v0.2.9` so they remain independent of the refactor in this checkout. They use
the old contracts and can provision additional infrastructure; follow their own
instructions and prerequisites.
