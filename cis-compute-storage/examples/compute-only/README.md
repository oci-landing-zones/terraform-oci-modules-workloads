# OCI Landing Zones Compute Module - Compute Only Example

## Introduction

This example shows how to deploy Compute instances in OCI using the [OCI Landing Zones Compute module](../../README.md). It deploys four Compute instances with the following characteristics:
- All instances are deployed in the same compartment and same subnet, defined by *default_compartment_id* and *default_subnet_id* attributes.
- All instances can be accessed over SSH with the private key corresponding to the public key defined by *default_ssh_public_key_path* attribute.
- All instances are placed in the network security groups defined by *networking.network_security_groups* attribute within each instance.

For INSTANCE-1:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle Linux 7 STIG" Marketplace image, as defined by *marketplace_image.name* attribute. Use the [markeplace-images module](../../../marketplace-images/) to find Marketplace images information based on a search filter.
- The instance will **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance requires a customer managed key for boot volume encryption, as defined by *cis_level* attribute.
- The instance boot volume is encrypted with a customer managed key referred by *encryption.kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- The instance has all Cloud Agent plugins enabled, as defined by *cloud_agent.plugins* attribute.
- The instance executes the cloud-init script given in [cloud-init.yaml](./cloud-init.yaml).

For INSTANCE-2:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle-Linux-8.10-2024.08.29-0" platform image, as defined by *platform_image.name* attribute. Use the [platform-images module](../../../platform-images/) to obtain platform images information based on a search filter.
- The instance will have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *silver* backup policy, as defined by *boot_volume.backup_policy* attribute.
- The instance has in-transit encryption enabled, as defined by *encryption.encrypt_in_transit_on_instance_create* attribute.
- The instance is a shielded instance, as defined by *platform_type* and *boot_volume.measured_boot* attributes.
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

For INSTANCE-3:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle-Linux-8.10-2024.08.29-0" platform image, as defined by *platform_image.name* attributes. Use the [platform-images module](../../../platform-images/) to obtain platform images information based on a search filter.
- The instance will have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *gold* backup policy, as defined by *boot_volume.backup_policy* attribute.
- The instance has confidential computing enabled, as defined by *platform_type* and *encryption.encrypt_data_in_use* attributes.
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

For INSTANCE-4:
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on a custom image available in a user-provided compartment, as defined by *custom_image.name* and *custom_image.compartment_id* attributes, respectively.
- The instance will have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is encrypted with an Oracle-managed key (OCI default) as it does not define *encryption.kms_key_id* attribute and there's no applicable *default_kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *gold* backup policy, as defined by *boot_volume.backup_policy* attribute.
- The instance has only default Cloud Agent plugins (management and monitoring) enabled, as *cloud_agent.plugins* attribute is undefined.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [Compute/Storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```