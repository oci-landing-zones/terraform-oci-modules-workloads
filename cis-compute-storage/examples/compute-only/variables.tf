# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_id      = string,                # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_subnet_id           = optional(string),      # the default subnet where all Compute instances are defined. It's overriden by the subnet_id attribute within each Compute instance.
    default_ssh_public_key_path = optional(string),      # the default ssh public key path used to access the Compute instance. It's overriden by the ssh_public_key attribute within each Compute instance.
    default_kms_key_id          = optional(string),      # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level           = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.

    instances = map(object({ # the instances to manage in this configuration.
      cis_level        = optional(string)
      compartment_id   = optional(string) # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      shape            = string           # the instance shape.
      name             = string           # the instance display name.
      platform_type    = optional(string) # the platform type. Assigning this variable enables various platform security features in the Compute service. Valid values: "AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM".
      image = object({ # the base image. You must provider either the id or (name and publisher name).
        id = optional(string) # the base image id for creating the instance. It takes precedence over name and publisher_name.
        name = optional(string) # the image name to search for in marketplace.
        publisher_name = optional(string) # the publisher name of the image name.
      })
      placement = optional(object({ # placement settings
        availability_domain  = optional(number,1) # the instance availability domain. Default is 1.
        fault_domain         = optional(number,1) # the instance fault domain. Default is 1.
      }))
      boot_volume = optional(object({ # boot volume settings
        type = optional(string,"PARAVIRTUALIZED") # boot volume emulation type. Valid values: "PARAVIRTUALIZED" (default for platform images), "SCSI", "ISCSI", "IDE", "VFIO".
        firmware = optional(string) # firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
        size = optional(number,50) # boot volume size. Default is 50GB (minimum allowed by OCI).
        preserve_on_instance_deletion = optional(bool,true) # whether to preserve boot volume after deletion. Default is true.
        secure_boot = optional(bool, false) # prevents unauthorized boot loaders and operating systems from booting.
        measured_boot = optional(bool, false) # enhances boot security by taking and storing measurements of boot components, such as bootloaders, drivers, and operating systems. Bare metal instances do not support Measured Boot.
        trusted_platform_module = optional(bool, false) # used to securely store boot measurements.
        backup_policy = optional(string,"bronze") # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". Default is "bronze".
      }))
      volumes_emulation_type = optional(string,"PARAVIRTUALIZED") # Emulation type for attached storage volumes. Valid values: "PARAVIRTUALIZED" (default for platform images), "SCSI", "ISCSI", "IDE", "VFIO". Module supported values for automated attachment: "PARAVIRTUALIZED", "ISCSI".
      networking = optional(object({ # networking settings
        type                    = optional(string,"PARAVIRTUALIZED") # emulation type for the physical network interface card (NIC). Valid values: "PARAVIRTUALIZED" (default), "E1000", "VFIO".
        hostname                = optional(string) # the instance hostname.
        assign_public_ip        = optional(bool,false)  # whether to assign the instance a public IP. Default is false.
        subnet_id               = optional(string)   # the subnet where the instance is created. default_subnet_id is used if this is not defined.
        network_security_groups = optional(list(string))  # list of network security groups the instance should be placed into.
      }))
      encryption = optional(object({ # encryption settings
        kms_key_id = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit_on_instance_create = optional(bool,null) # whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable at instance creation time only.
        encrypt_in_transit_on_instance_update = optional(bool,null) # whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable at instance update time only.
        encrypt_data_in_use = optional(bool, false) # whether the instance encrypts data in-use (in memory) while being processed. A.k.a confidential computing.
      }))
      flex_shape_settings = optional(object({ # flex shape settings
        memory = optional(number,16) # the instance memory for Flex shapes. Default is 16GB.
        ocpus  = optional(number,1)  # the instance ocpus number for Flex shapes. Default is 1.
      }))
      cloud_agent = optional(object({
        disable_management = optional(bool,false)
        disable_monitoring = optional(bool,false)
        plugins = optional(list(object({
          name = string
          enabled = bool
        })))
      }))
      ssh_public_key_path = optional(string) # the SSH public key path used to access the instance.
      defined_tags        = optional(map(string)) # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags       = optional(map(string)) # instances freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
  default = null
}