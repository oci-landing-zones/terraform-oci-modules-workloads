# OCI Landing Zones Compute Module - Replica File System Example

## Introduction

This example shows how to deploy a file system used as a replica file system in OCI using the [OCI Landing Zones Compute module](../../README.md). The replica file system has the following characteristics:
- It is deployed in the region defined by the *region* attribute.
- It is deployed in the compartment defined by *default_compartment_id* attribute.
- It is configured as replication target, as defined by *replication.is_target* attribute.
- The replica file system OCID (in the output) is used in the configuration of the file system set as the source file system. See [storage-only example](../storage-only/) for such configuration.

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