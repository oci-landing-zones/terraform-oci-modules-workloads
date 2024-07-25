# OCI Secure Workload Modules

![Landing Zone logo](./landing_zone_300.png)

This repository contains Terraform modules for managing workload resources in OCI (Oracle Cloud Infrastructure). By workload we mean resources that are typically deployed within a landing zone, and may trigger OCI consumption. By secure we mean they are designed to cover the key security features available in the OCI platform. When appropriate, the modules align with CIS OCI Foundations Benchmark recommendations.

The following modules are available:
- [CIS Compute & Storage](./cis-compute-storage/)
- [OKE (Oracle Kubernetes Engine)](./cis-oke/)

Helper modules:
- [Platform Images](./platform-images/) - aids in finding OCI Platform images. Use it to obtain image information for provisioning a Compute instance.
- [Marketplace Images](./marketplace-images/) - aids in finding OCI Marketplace images. Use it to obtain image information for provisioning a Compute instance.

Within each module you find an *examples* folder. Each example is a fully runnable Terraform configuration that you can quickly test and put to use by modifying the input data according to your own needs.  

## CIS OCI Foundations Benchmark Modules Collection

This repository is part of a broader collection of repositories containing modules that help customers align their OCI implementations with the CIS OCI Foundations Benchmark recommendations:
- [Identity & Access Management](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-iam)
- [Networking](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking)
- [Governance](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-governance)
- [Security](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security)
- [Observability & Monitoring](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-observability)
- [Secure Workloads](https://github.com/oracle-quickstart/terraform-oci-secure-workloads) - current repository

The modules in this collection are designed for flexibility, are straightforward to use, and enforce CIS OCI Foundations Benchmark recommendations when possible.

Using these modules does not require a user extensive knowledge of Terraform or OCI resource types usage. Users declare a JSON object describing the OCI resources according to each module’s specification and minimal Terraform code to invoke the modules. The modules generate outputs that can be consumed by other modules as inputs, allowing for the creation of independently managed operational stacks to automate your entire OCI infrastructure.

## Help

Open an issue in this repository.

## Contributing

This project welcomes contributions from the community. Before submitting a pull request, please [review our contribution guide](./CONTRIBUTING.md).

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security vulnerability disclosure process.

## License

Copyright (c) 2023,2024 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

## Known Issues
None.