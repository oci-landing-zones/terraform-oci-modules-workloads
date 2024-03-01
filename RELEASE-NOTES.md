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
