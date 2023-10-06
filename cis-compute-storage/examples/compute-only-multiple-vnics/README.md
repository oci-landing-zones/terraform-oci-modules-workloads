# CIS OCI Compute Example - Compute with Multiple VNICs and Multiple IP Addresses

## Introduction

This example shows how to deploy Compute instances in OCI using the [cis-compute-storage module](../../). It deploys one Compute instance with the following characteristics:
- The instances is deployed in the compartment and subnet defined by *default_compartment_id* and *default_subnet_id* attributes.
- The instance can be accessed over SSH with the private key corresponding to the public key defined by *default_ssh_public_key_path* attribute.
- The instances is placed in the network security groups defined by *networking.network_security_groups* attribute.
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle Linux 7 STIG" Marketplace image published by "Oracle Linux", as defined by *image.name* and *image.publisher_name* attributes. Use the [markeplace-images module](../../../marketplace-images/) to find Marketplace images information based on a search filter.
- The instance will **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is encrypted with a customer managed key referred by *encryption.kms_key_id* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- The instance primary VNIC is assigned a primary IP address defined by *networking.private_ip*. The IP address must be available in the VNIC subnet.
- The instance has a secondary IP address attached to the primary VNIC, defined by *networking.secondary-ips* attribute. 
   - The IP address is randomly chosen from available addresses in the subnet, as its *primary_ip* attribute is undefined.
- The instance has a secondary VNIC attached, defined by *networking.secondary-vnics* attribute. 
   - The VNIC is created in the subnet defined by its *subnet_id* attribute.
   - The VNIC is placed in the network security groups defined by its *network_security_groups* attribute.
   - The VNIC is assigned a primary IP address defined by its *private_ip* attribute. The IP address must be available in the VNIC subnet.
   - The VNIC will forward packets, as *skip_source_dest_check* is true.
   - The VNIC has a secondary IP address randomly chosen from available addresses in the subnet, as its *primary_ip* attribute is undefined.

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