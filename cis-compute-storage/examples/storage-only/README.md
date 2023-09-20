# CIS OCI Compute/Storage Example - Storage only

## Introduction

This example shows how to deploy Block volumes and File Storage in OCI using the [cis-compute-storage module](../../). It deploys two block volumes, two file systems, one mount target with two exports, and one file system snapshot policy with the following characteristics:
- All resources are deployed in the same compartment, defined by *default_compartment_id* attribute.
- The file systems have their mount targets (if specified) in the subnet defined by *default_subnet_id* attribute.

For block volume BV-1:
- The block volume is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The block volume is replicated to another region, defined by *block_volume_replication_region* variable. The volume replica is placed in availability domain 1, as defined by *replication.availability_domain* attribute.
- The block volume is set to be backed up per Oracle-managed *bronze* backup policy.

For block volume BV-2:
- The block volume is encrypted with a customer managed key, defined by *encryption.kms_key_id* attribute.
- The block volume is not replicated, as it does not define any settings for the *replication* attribute.
- The block volume is set to be backed up per Oracle-managed *silver* backup policy.

**Note 1:** replicated block volumes are not destroyed upon *terraform destroy*. In order to destroy replicated block volumes, it is first necessary to manually terminate the replication. 
**Note 2:** block volumes encrypted with a customer managed key cannot be replicated to another region.

For file system FS-1:
- The file system is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The file system is replicated to target file system specified by *replication.file_system_target_id* attribute. See [replica-file-system example](../replica-file-system/) for a replica file system configuration example.
- The file system is backed up per policy defined by *snapshot_policy_id* attribute. The value is a pointer to the "SNAPSHOT-POLICY-1" policy defined within *snapshot_policies* attribute. 
- The file system is exported per the settings defined by "EXP-1" export within "MT-1" mount target in *mount_targets* attribute. Note *file_system_id* attribute value is a pointer to "FS-1" file system.

For file system FS-2:
- The file system requires a customer managed key for data encryption, as defined by *cis_level* atrribute.
- The file system is encrypted with a customer managed key, defined by *kms_key_id* attribute.
- The file system is not replicated, as it does not define any settings for the *replication* attribute.
- The file system is backed up per policy defined by *snapshot_policy_id* attribute. The value is a pointer to the "SNAPSHOT-POLICY-1" policy defined within *snapshot_policies* attribute. 
- The file system is exported per the settings defined by "EXP-2" export within "MT-1" mount target in *mount_targets* attribute. Note *file_system_id* attribute value is a pointer to "FS-2" file system.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

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