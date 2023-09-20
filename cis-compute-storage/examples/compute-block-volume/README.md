# CIS OCI Compute/Storage Example - Compute instances and Block volumes

## Introduction

This example shows how to deploy Compute instances and Block volumes in OCI using the [cis-compute-storage module](../../). It deploys one Compute instance and one block volume with the following characteristics:
- The instance boot volume is encrypted with a customer managed key defined by *default_kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- The block volume is attached to the instance (but not mounted).
- The block volume is encrypted with an Oracle-managed key (per OCI default).
- The block volume is set to be backed up per Oracle-managed *bronze* backup policy.
- The block volume is replicated to another region, specified by *block_volume_replication_region* variable. Notice that the replicated block volumes are not destroyed upon *terraform destroy*. In order to destroy replicated block volumes, it is first necessary to manually terminate the replication. 

**Note:** Block volumes encrypted with a customer managed key cannot be replicated to another region.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

Note that you must provide the image *name* and *publisher_name* for provisioning the Compute instance. Use the [marketplace-images module](../../../marketplace-images/) to obtain Marketplace images information based on a search filter. It will also return the image OCID that can be used instead of the image name/publisher pair.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [cis-compute-storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```