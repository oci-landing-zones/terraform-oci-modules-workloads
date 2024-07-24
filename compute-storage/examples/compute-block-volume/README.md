# OCI Compute & Storage Module - Compute instances and Block volumes Example

## Introduction
This example shows how to deploy Compute instances and Block volumes in OCI using the [compute-storage module](../../). It deploys three Compute instances and two Block volumes with the following characteristics:
- All instances are deployed in the same compartment and same subnet, defined by *default_compartment_id* and *default_subnet_id* attributes.
- All instances boot volumes are encrypted with a customer-managed key defined by *default_kms_key_id* attribute.
- All instances can be accessed over SSH with the private key corresponding to the public key defined by *default_ssh_public_key_path* attribute.
- All instances are placed in the network security groups defined by *networking.network_security_groups* attribute within each instance.

For INSTANCE-1:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle Linux 7 STIG" Marketplace image published by "Oracle Linux", as defined by *image.name* and *image.publisher_name* attributes. Use the [markeplace-images module](../../../marketplace-images/) to find Marketplace images information based on a search filter.
- The instance will **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

For INSTANCE-2:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle-Linux-8.8-2023.08.31-0" image published, as defined by *image.id* attributes. Use the [platform-images module](../../../platform-images/) to obtain platform images information based on a search filter.
- The instance will have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *silver* backup policy, as defined by *boot_volume.backup_policy* attribute.
- The instance has in-transit encryption enabled, as defined by *encryption.encrypt_in_transit_on_instance_create* attribute.
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

For INSTANCE-3:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle-Linux-8.8-2023.08.31-0" image published, as defined by *image.id* attributes. Use the [platform-images module](../../../platform-images/) to obtain platform images information based on a search filter.
- The instance will have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *gold* backup policy, as defined by *boot_volume.backup_policy* attribute.
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

For BV-1:
- The block volume is attached to "INSTANCE-1" instance, as defined by *attach_to_instances.instance_id* attribute.
- The block volume does not support in-transit encryption, as *encryption.encrypt_in_transit* attribute is undefined.
- The block volume is set to be backed up per Oracle-managed *bronze* backup policy, as defined by *backup_policy* attribute.
- The block volume is replicated to another region, defined by *block_volume_replication_region* variable. The volume replica is placed in availability domain 1, as defined by *replication.availability_domain* attribute.

For BV-2:
- The block volume is attached to "INSTANCE-2" and "INSTANCE-3" instances, as defined by *attach_to_instances.instance_id* attributes. Note that are two elements in the *attach_to_instances* list, one to each instance attachment. As a consequence, the module automatically sets the attachments as shareable. "INSTANCE-1" attachment is in read-only mode, while "INSTANCE-2" is read/write, as defined by *attach_to_instances.read-only* attribute.
- The block volume enables in-transit encryption, as defined by *encryption.encrypt_in_transit* attribute.
- The block volume is set to be backed up per Oracle-managed *silver* backup policy, as defined by *backup_policy* attribute.
- The block volume is not replicated to another region, as *replication.availability_domain* attribute is undefined.

**Note:** Block volumes encrypted with a customer managed key cannot be replicated to another region.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

Note that you must provide the image *name* and *publisher_name* for provisioning the Compute instance. Use the [marketplace-images module](../../../marketplace-images/) to obtain Marketplace images information based on a search filter. It will also return the image OCID that can be used instead of the image name/publisher pair.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [compute-storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```