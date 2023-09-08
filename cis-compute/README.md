# Oracle Cloud Infrastructure (OCI) Terraform CIS Compute & Storage (Block Volumes and File System) Module

![Landing Zone logo](../landing_zone_300.png)

This module manages Compute instances, Block Storage and File System Storage in Oracle Cloud Infrastructure (OCI). These resources and their associated resources can be deployed together in the same configuration or separately. The module enforces CIS Benchmark recommendations and provides features for strong cyber resilience posture, including storage backups and replication. Additionally, the module supports bringing in external dependencies that managed resources depend on, including compartments, subnets, encryption keys, and others.

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Requirements](#requirements)
- [Module Functioning](#functioning)
  - [Compute](#compute)
  - [Block Storage](#block-storage)
  - [File Storage](#file-storage)
  - [External Dependencies](#ext-dep)
- [Related Documentation](#related)
- [Known Issues](#issues)

## <a name="requirements">Requirements</a>
### IAM Permissions

This module requires the following OCI IAM permissions in the compartments where instances, block volumes, and file systems are defined. 

For deploying Compute instances:
```
Allow group <GROUP-NAME> to manage instance-family in compartment <INSTANCE-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME> ??
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```

For deploying Block Storage volumes:
```
Allow group <GROUP-NAME> to manage volume-family in compartment <BLOCK-VOLUME-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```

For deploying File Storage file systems:
```
Allow group <GROUP-NAME> to manage file-family in compartment <FILE-SYSTEM-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME> ??
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```

### Terraform Version > 1.3.x

This module relies on [Terraform Optional Object Type Attributes feature](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#optional-object-type-attributes), which has been promoted and no longer experimental in versions greater than 1.3.x. The feature shortens the amount of input values in complex object types, by having Terraform automatically inserting a default value for any missing optional attributes.

## <a name="functioning">Module Functioning</a>

The module defines two top level attributes used to manage instances and storage: 
- **instances_configuration**: for managing Compute instances.
- **storage_configuration**: for managing storage, including Block Storage and File System Storage.

### <a name="compute">Compute</a>

Compute instances are managed using the **instances_configuration** object. It contains a set of attributes starting with the prefix **default_** and one attribute named **instances**. The **default_** attribute values are applied to all instances within **instances**, unless overriden at the instance level.

The *default_* attributes are the following:
- **default_compartment_id**: the default compartment for all instances. It can be overriden by *compartment_id* attribute in each instance.
- **default_subnet_id**: the default subnet for all instances. It can be overriden by *subnet_id* attribute in each instance.
- **default_ssh_public_key_path**: the default SSH public key path used to access all instances. It can be overriden by the *ssh_public_key* attribute in each instance.
- **default_kms_key_id**: the default encryption key for all instances. It can be overriden by *kms_key_id* attribute in each instance.
- **default_cis_level**: the default CIS OCI Benchmark profile level for all instances. Level "2" enforces usage of customer managed keys for boot volume encryption. Default is "1". It can be overriden by *cis_level* attribute in each instance.
- **default_defined_tags**: the default defined tags for all instances. It can be overriden by *defined_tags* attribute in each instance.
- **default_freeform_tags**: the default freeform tags for all instances. It can be overriden by *freeform_tags* attribute in each instance.

The instances themselves are defined within the **instances** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.
- **compartment_id**: the instance compartment. *default_compartment_id* is used if undefined.
- **cis_level**: the CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **shape**: the instance shape.
- **name**: the instance name.
- **ssh_public_key_path**: the SSH public key path used to access the instance. *default_ssh_public_key_path* is used if undefined.
- **defined_tags**: the instance defined tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: the instance freeform tags. *default_freeform_tags* is used if undefined.
- **image**: the instance base image. You must provider either the id or (name and publisher name). See section [Obtaining Compute Images Information from OCI Marketplace](#marketplace-images) below about how to get Marketplace images.
  - **id**: the image id for the instance. It takes precedence over name and publisher.
  - **name**: the image name to search for in OCI Marketplace. 
  - **publisher**: the image's publisher name.
- **placement**: instance placement settings.
  - **availability_domain**: the instance availability domain. Default is 1.
  - **fault_domain**: the instance fault domain. Default is 1.
- **boot_volume**: boot volume settings.
  - **type**: boot volume emulation type. Valid values: "PARAVIRTUALIZED", "SCSI", "ISCSI", "IDE", "VFIO". Default is "PARAVIRTUALIZED".
  - **firmware**: firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
  - **size**: boot volume size. Default is 50 (in GB, the minimum allowed by OCI).
  - **preserve_on_instance_deletion**: whether to preserve boot volume after deletion. Default is true.
  - **backup_policy**: the Oracle managed backup policy for the boot volume. Valid values: "gold", "silver", "bronze". Default is "bronze".
- **device_mounting**: # device mounting settings. See section [Device Mounting](#device-mounting) below for details.
  - **disk_mappings**: device disk mappings to storage volumes. If providing multiple mappings, separate the mappings with a blank space.
  - **emulation_type**: emulation type for attached storage volumes. Valid values: "PARAVIRTUALIZED" (default), "SCSI", "ISCSI", "IDE", "VFIO". Module supported values for automated attachment: "PARAVIRTUALIZED", "ISCSI".
- **networking**: # networking settings. 
  - **type**: emulation type for the physical network interface card (NIC). Valid values: "PARAVIRTUALIZED" (default), "VFIO" (SR-IOV networking), "E1000" (compatible with Linux e1000 driver).
  - **hostname**: the instance hostname.
  - **assign_public_ip**: whether to assign the instance a public IP. Default is false.
  - **subnet_id**: the subnet where the instance is created. *default_subnet_id* is used if undefined.
  - **network_security_groups**: list of network security groups the instance should be placed into.
- **encryption**: encryption settings. See section [In Transit Encryption](#in-transit-encryption) for important information.
  - **kms_key_id**: the encryption key for boot volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2".
  - **encrypt_in_transit_at_instance_creation**: whether to enable in-transit encryption for the data volume's paravirtualized attachment. Default is true. Applicable during instance **creation** time only.
  - **encrypt_in_transit_at_instance_update**: whether to enable in-transit encryption for the data volume's paravirtualized attachment. Default is true. Applicable during instance **update** time only.
- **flex_shape_settings**: flex shape settings.
  - **memory**: the instance memory for Flex shapes. Default is 16 (in GB).
  - **ocpus**: the number of OCPUs for Flex shapes. Default is 1.

#### <a name="marketplace-images">Obtaining Compute Images Information from OCI Marketplace</a>
Helper module [marketplace-images](../marketplace-images/) aids in finding Compute instances in OCI Marketplace based on a search string. See [this example](../marketplace-images/examples/marketplace-images/) for finding images containing "CIS" in their names. It outputs information like:
```
Publisher: Center for Internet Security
Image name: CIS CentOS Linux 6 Benchmark - Level 1
Listing resource id: ocid1.image.oc1..aaaaaaaasxmjh33hefbbfbstzr6xmtfxfi4vkqeq5xg5kpghdxw3msnn4ycq
Resource version: 2.0.2.13

Publisher: Center for Internet Security
Image name: CIS CentOS Linux 7 Benchmark - Level 1
Listing resource id: ocid1.image.oc1..aaaaaaaaxmhng6g2j5vi7o4wb5sopjz73zhsiswrvpgq4b3rnemlqupuq3pa
Resource version: 3.1.2.6
...
```
Use the *Listing resource id* or *Image name and Publisher* to seed image.id or image.name and image.publisher attributes.

#### <a name="device-mounting">Device Mounting</a>

#### <a name="in-transit-encryption">In Transit Encryption</a>
As stated in https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm#BlockVolumeEncryption:

*"In-transit encryption for boot and block volumes is only available for virtual machine (VM) instances launched from platform images, along with bare metal instances that use the following shapes: BM.Standard.E3.128, BM.Standard.E4.128, BM.DenseIO.E4.128. It is not supported on other bare metal instances. To confirm support for certain Linux-based custom images and for more information, contact Oracle support."*

Additionally, in-transit encryption is only available to paravirtualized volumes (boot and block volumes).

### <a name="storage">Storage</a>

Storage is managed using the **storage_configuration** object. It contains a set of attributes starting with the prefix **default_** and two attribute named **block_volumes** and **file_storage**. The **default_** attribute values are applied to all storage units within **block_volumes** and **file_storage**, unless overriden at the storage unit level.

The *default_* attributes are the following:
- **default_compartment_id**: the default compartment for all storage units. It can be overriden by *compartment_id* attribute in each unit.
- **default_subnet_id**: the default subnet for all file system mount targets. It can be overriden by *subnet_id* attribute in each mount target.
- **default_kms_key_id**: the default encryption key for all storage units. It can be overriden by *kms_key_id* attribute in each unit.
- **default_cis_level**: the default CIS OCI Benchmark profile level for all storage units. Level "2" enforces usage of customer managed keys for storage encryption. Default is "1". It can be overriden by *cis_level* attribute in each unit.
- **default_defined_tags**: the default defined tags for all storage units. It can be overriden by *defined_tags* attribute in each unit.
- **default_freeform_tags**: the default freeform tags for all storage units. It can be overriden by *freeform_tags* attribute in each unit.

#### <a name="block-volumes">Block Volumes</a>
Block volumes are defined using the **block_volumes** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id**: the volume compartment. *default_compartment_id* is used if undefined.
- **cis_level**: the CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **display_name**: the volume display name.
- **availability_domain**: the volume availability domain. Default is 1.
- **volume_size**: the volume size. Default is 50 (GB).
- **vpus_per_gb**: the number of VPUs per GB of volume. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH). Default is 0.
- **defined_tags**: the volume defined tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: the volume freeform tags. *default_freeform_tags* is used if undefined.
- **attach_to_instance**: 
  - **instance_id**: the instance that the volume attaches to. It must be one of the identifying keys in the *instances* map or in the *instances_dependency* object.
  - **device_name**: the device name where to mount the block volume. It must be one of the *disk_mappings* value in the *instances* map or in the *instances_dependency* object.
- **encryption**: encryption settings
  - **kms_key_id**: the encryption key for volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2".
  - **encrypt_in_transit**: whether traffic encryption should be enabled for the volume. It only works if the device emulation type is paravirtualized.
- **replication**: replication settings
  - **availability_domain**: the availability domain (AD) to replicate the volume. The AD is picked from the region set by the module client to *block_volumes_replication_region* provider alias. Check [here](./examples/storage-only/) for an example with cross-region replication.
- **backup_policy**: the Oracle managed backup policy for the volume. Valid values: "gold", "silver", "bronze". Default is "bronze".

#### <a name="file-storage">File Storage</a>
The **file_storage** attribute defines the file systems, mount targets and snapshot policies for OCI File Storage service. 
<<<TO COMPLETE>>>

### <a name="ext-dep">External Dependencies</a>
An optional feature, external dependencies are resources managed elsewhere that resources managed by this module may depend on. The following dependencies are supported:
- **compartments_dependency**: A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the compartment OCID.
- **network_dependency**: A map of objects containing the externally managed network resources (including subnets) this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the subnet OCID.
- **kms_dependency**: A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the encryption key OCID.
- **instances_dependency**: A map of objects containing the externally managed instances this module may depend on. All map objects must have the same type and must contain at least the following attributes:
  - an *id* attribute with the instance OCID.
  - a *remote_data_volume_type* attribute with the emulation type.
  - a *is_pv_encryption_in_transit_enabled* attribute informing whether the instance supports in-transit encryption.
- **file_system_dependency**: A map of objects containing the externally managed file systems this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the file system OCID.

## <a name="related">Related Documentation</a>
<<<TO COMPLETE>>>

## <a name="issues">Known Issues</a>
None.
