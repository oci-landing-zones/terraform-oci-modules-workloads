# July 29, 2025 Release Notes - 0.2.2
# Updates
1. Reformat the code to adhere to Terraform standards. 

# July 15, 2025 Release Notes - 0.2.1
## Updates in [Compute module](./cis-compute-storage/)
1. Oracle back up policies now have dynamic look up, allowing the code to work for all OCI regions. 
2. *disable_legacy_imds_endpoints* is now an optional input variable. Set to true to disable legacy service endpoints.


# May 02, 2025 Release Notes - 0.2.0
## Updates in [Compute module](./cis-compute-storage/)
1. Marketplace listing check disabled for marketplace images.


# December 18, 2024 Release Notes - 0.1.9
## Updates in [Compute module](./cis-compute-storage/)
1. Compute: logic updated for platform images lookup by name.
2. Block Volumes: precondition check for cross region replication and encryption with customer managed key removed.
3. File Storage: following attributes were added to *mount_targets* attribute: *network_security_groups*, *hostname_label*, *defined_tags*, *freeform_tags*.


# December 04, 2024 Release Notes - 0.1.8
## Updates in [Compute module](./cis-compute-storage/)
1. Support for ZPR (Zero Trust Packet Routing) attributes on Compute instances and secondary VNICs. See *zpr_attributes* attribute in [Compute module documentation](./cis-compute-storage/README.md#compute-1) for details.
2. Disabled precondition check on platform images supported shapes when the platform image OCID is provided as the Compute image source.


# October 14, 2024 Release Notes - 0.1.7
## Updates in [Compute module](./cis-compute-storage/)
1. Marketplace images, platform images and custom images split for clarity in module interface. 
2. Marketplace image's *publisher_name* attribute has been removed and *version* attribute has been introduced. See [Compute section](./README.md#compute) for usage guidance.
3. Marketplace images configured with automatic Marketplace agreements.
4. Module now validates whether provided shape is compatible with provided marketplace or platform image. 


# August 28, 2024 Release Notes - 0.1.6
## Updates
1. All modules now require Terraform binary equal or greater than 1.3.0.
2. *cislz-terraform-module* tag renamed to *ocilz-terraform-module*.


# July 25, 2024 Release Notes - 0.1.5
## Updates    
1. Aligned README.md structure to Oracle's GitHub organizations requirements.

# May 15, 2024 Release Notes - 0.1.4

## New
1. OKE module added, supporting basic and enhanced clusters, with managed node pools and virtual node pools. See [OKE module](./cis-oke/README.md) for details.

## Updates
1. Compute module can now manage cluster networks and compute clusters. See [Clusters](./cis-compute-storage/README.md#clusters-1) for details.
2. Compute module now supports cloud-init scripts passed in as a file or as a string in [Terraform heredoc style](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings). See [Compute](./cis-compute-storage/README.md#compute-1) for details.
3. Compute module now supports SSH public keys passed in as a file or as a string.

# February 29, 2024 Release Notes - 0.1.3

## Updates
### CIS Compute & Storage Module
1. Compute aligns with CIS Benchmark 2.0.0: in additional to encryption at rest, CIS profile level now drives in-transit encryption, secure Boot (Shielded instances), and the availability of legacy Metadata service endpoint.
    - CIS profile level 1 enables in-transit encryption.
    - CIS profile level 2 enables secure boot and disables legacy Metadata service endpoint.
    
2. [Cloud Agent Requirements](./cis-compute-storage/README.md#cloud-agent-requirements) documented.

# October 30, 2023 Release Notes - 0.1.2

## Updates
1. [How to Mount Block Volumes](#0-1-2-bv-mount-doc)
2. [Network dependency aligned with CIS Landing Zone Networking Module Output](#0-1-2-net-dep)

### <a name="0-1-2-bv-mount-doc">How to Mount Block Volumes</a>
Instructions are provided in [README.md](./README.md) for mounting block volumes. The modules does not mount volumes automatically.

### <a name="0-1-2-net-dep">Network dependency aligned with CIS Landing Zone Networking Module Output</a>
*network_dependency* input variable aligns with [CIS Landing Zone Networking](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking) module output. The Networking module outputs resources grouped by resource type ("vcns", "subnets", "network_security_groups", etc.). All modules in this repository have been updated accordingly. This impacts the contents of *network_dependency* variable. See [external-dependencies](./cis-compute-storage/examples/external-dependencies/) for an example.

# October 05, 2023 Release Notes - 0.1.1

## Updates
1. [Secondary VNICs](#0-1-1-compute-secondary-vnics)

### <a name="0-1-1-compute-secondary-vnics">Secondary VNICs</a>
Compute module can configure instances with secondary VNICs and secondary IPs per VNIC.

# September 22, 2023 Release Notes - 0.1.0

## Added
1. [Initial Release](#0-1-0-initial)

### <a name="0-1-0-initial">Initial Release</a>
Modules for Compute, Storage, Platform Images and Marketplace Images

#### [Compute](./cis-compute-storage/)
- CIS profile level drives data at rest encryption configuration.
- Boot volumes encryption with customer managed keys from OCI Vault service.
- In-transit encryption for boot volumes and attached block volumes.
- Data in-use encryption for platform images ([Confidential computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm)).
- [Shielded instances](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm).
- Boot volumes backup with Oracle managed policies.
- [Cloud Agent Plugins](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm).

#### [Block Volumes](./cis-compute-storage/)
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- In-transit encryption for attached Compute instances.
- Cross-region replication for strong cyber resilience posture.
- Backups with Oracle managed policies.
- [Shareable block volume attachments](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/attachingvolumetomultipleinstances.htm).

#### [File Storage](./cis-compute-storage/)
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- Cross-region replication for strong cyber resilience posture.
- Backups with custom snapshot policies.

#### [Platform Images](./platform-images/)
- Aids in finding OCI Platform images.

#### [Marketplace Images](./marketplace-images/)
- Aids in finding OCI Marketplace images.
