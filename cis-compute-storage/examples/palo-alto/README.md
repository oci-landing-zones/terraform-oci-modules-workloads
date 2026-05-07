# OCI Landing Zones Compute Module - Palo Alto Next-Gen Firewall

## Introduction

This example shows how to deploy Palo Alto Next-Gen Firewall using an OCI Marketplace image.

** NOTE THAT BY DEPLOYING A MARKETPLACE IMAGE USING TERRAFORM YOU ARE IMPLICITLY AGREEING WITH OCI MARKETPLACE TERMS FOR THE PRICING MODEL THAT APPLY TO THE SELECTED IMAGE.**

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