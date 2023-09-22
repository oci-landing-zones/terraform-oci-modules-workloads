# September 22, 2023 Release Notes - 0.1.0

## Added
1. [Initial Release](#0-1-0-initial)

### <a name="0-1-0-initial">Initial Release</a>
Modules for Compute, Storage, Plaform Images and Marketplace Images

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
