# OCI Landing Zones Compute Module - Volume Group Only Example

## Introduction

This example shows how to deploy Volume Group and its backup in OCI using the [OCI Landing Zones Compute module](../../README.md). 

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