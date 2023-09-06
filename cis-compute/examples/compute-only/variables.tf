# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "block_volumes_replication_region" { 
  description = "The replication region for block volumes. Leave unset if replication occurs to an availability domain within the block volume region."
  default = null
}

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_id      = string,                # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_subnet_id           = optional(string),      # the default subnet where all Compute instances are defined. It's overriden by the subnet_id attribute within each Compute instance.
    default_ssh_public_key_path = optional(string),      # the default ssh public key path used to access the Compute instance. It's overriden by the ssh_public_key attribute within each Compute instance.
    default_kms_key_id          = optional(string),      # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level           = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.

    instances = map(object({ # the instances to manage in this configuration.
      cis_level        = optional(string)
      compartment_id   = optional(string)           # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      shape            = string                     # the instance shape.
      name             = string                     # the instance display name.
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
        type = optional(string) # boot volume emulation type. Valid values: "PARAVIRTUALIZED" (default for platform images), "SCSI", "ISCSI", "IDE", "VFIO".
        firmware = optional(string) # firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
        size = optional(number,50) # boot volume size. Default is 50GB (minimum allowed by OCI).
        preserve_on_instance_deletion = optional(bool,true) # whether to preserve boot volume after deletion. Default is true.
        backup_policy = optional(string,"bronze") # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". Default is "bronze".
      }))
      attached_storage = optional(object({ # storage settings. Attributes required by the cloud init script to attach block volumes.
        device_disk_mappings = string # device mappings to mount block volumes. If providing multiple mapping, separate the mappings with a blank space.
        emulation_type = optional(string) # Emulation type for attached storage volumes. Valid values: "paravirtualized" (default for platform images), "scsi", "iscsi", "ide", "vfio". Module supported values for automated attachment: "paravirtualized", "scsi".
      }))
      networking = optional(object({ # networking settings
        type                    = optional(string)
        hostname                = optional(string) # the instance hostname.
        assign_public_ip        = optional(bool,false)     # whether to assign the instance a public IP. Default is false.
        subnet_id               = optional(string)   # the subnet where the instance is created. default_subnet_id is used if this is not defined.
        network_security_groups = optional(list(string))  # list of network security groups the instance should be placed into.
      }))
      encryption = optional(object({ # encryption settings
        kms_key_id         = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit = optional(bool,true)   # if the boot volume should encrypt in transit traffic. Default is true.
      }))
      flex_shape_settings = optional(object({ # flex shape settings
        memory = optional(number,16) # the instance memory for Flex shapes. Default is 16GB.
        ocpus  = optional(number,1)  # the instance ocpus number for Flex shapes. Default is 1.
      }))
      ssh_public_key = optional(string) # the SSH public key used to access the instance.
      defined_tags  = optional(map(string)) # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags = optional(map(string)) # instances freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
  default = null
}