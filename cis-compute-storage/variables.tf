# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {
  description = "The tenancy OCID" # Used when looking up platform images
  default = null
}

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_id      = string,                 # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_subnet_id           = optional(string),       # the default subnet where all Compute instances are defined. It's overriden by the subnet_id attribute within each Compute instance.
    default_ssh_public_key_path = optional(string),       # the default ssh public key path used to access the Compute instance. It's overriden by the ssh_public_key attribute within each Compute instance.
    default_kms_key_id          = optional(string),       # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level           = optional(string)        # the CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags        = optional(map(string)),  # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)),  # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    default_cloud_init_heredoc_script = optional(string), # the default cloud-init script in Terraform heredoc style that is applied to all instances. It has precedence over default_cloud_init_script_file.
    default_cloud_init_script_file    = optional(string), # the default cloud-init script file that is applied to all instances.

    instances = map(object({ # the instances to manage in this configuration.
      cis_level        = optional(string)
      compartment_id   = optional(string) # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      shape            = string           # the instance shape.
      name             = string           # the instance display name.
      platform_type    = optional(string) # the platform type. Assigning this variable enables various platform security features in the Compute service. Valid values: "AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM".
      cluster_id       = optional(string) # the Compute cluster the instance is added to. It can take either a literal cluster OCID or cluster key defined in the clusters_configuration variable.
      marketplace_image = optional(object({ # the marketplace image. You must provider the name, and optionally the version. If version is not provided, the latest available version is used.
        name    = string # the marketplace image name.
        version = optional(string) # the marketplace image version.
      }))
      platform_image = optional(object({ # the platform image. You must provider the name and assign the tenancy_ocid variable.
        ocid = optional(string) # the platform image ocid. It takes precedence over name.
        name = optional(string) # the platform image name.
      }))
      custom_image = optional(object({ # the custom image. You must provider either the ocid or name and compartment_id.
        ocid = optional(string) # the custom image ocid. It takes precedence over name.
        name = optional(string) # the custom image name.
        compartment_id = optional(string) # the custom image compartment. Required if name is used.
      }))
      placement = optional(object({ # placement settings
        availability_domain  = optional(number,1) # the instance availability domain. Default is 1.
        fault_domain         = optional(number,1) # the instance fault domain. Default is 1.
      }))
      boot_volume = optional(object({ # boot volume settings
        type = optional(string,"paravirtualized") # boot volume emulation type. Valid values: "paravirtualized" (default for platform images), "scsi", "iscsi", "ide", "vfio".
        firmware = optional(string) # firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
        size = optional(number,50) # boot volume size. Default is 50GB (minimum allowed by OCI).
        preserve_on_instance_deletion = optional(bool,true) # whether to preserve boot volume after deletion. Default is true.
        secure_boot = optional(bool, false) # prevents unauthorized boot loaders and operating systems from booting.
        measured_boot = optional(bool, false) # enhances boot security by taking and storing measurements of boot components, such as bootloaders, drivers, and operating systems. Bare metal instances do not support Measured Boot.
        trusted_platform_module = optional(bool, false) # used to securely store boot measurements.
        backup_policy = optional(string,"bronze") # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". Default is "bronze".
      }))
      volumes_emulation_type = optional(string,"paravirtualized") # Emulation type for attached storage volumes. Valid values: "paravirtualized" (default for platform images), "scsi", "iscsi", "ide", "vfio". Module supported values for automated attachment: "paravirtualized", "iscsi".
      networking = optional(object({ # networking settings
        type                    = optional(string,"paravirtualized") # emulation type for the physical network interface card (NIC). Valid values: "paravirtualized" (default), "e1000", "vfio".
        private_ip              = optional(string) # a private IP address of your choice to assign to the primary VNIC.
        hostname                = optional(string) # the primary VNIC hostname.
        assign_public_ip        = optional(bool)  # whether to assign the primary VNIC a public IP. Defaults to whether the subnet is public or private.
        subnet_id               = optional(string)   # the subnet where the primary VNIC is created. default_subnet_id is used if this is not defined.
        network_security_groups = optional(list(string))  # list of network security groups the primary VNIC should be placed into.
        skip_source_dest_check  = optional(bool,false) # whether the source/destination check is disabled on the primary VNIC. Default is false.
        secondary_ips           = optional(map(object({ # list of secondary private IP addresses for the primary VNIC.
          display_name  = optional(string) # Secondary IP display name.
          hostname      = optional(string) # Secondary IP host name.
          private_ip    = optional(string) # Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
          defined_tags  = optional(map(string)) # Secondary IP defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags = optional(map(string)) # Secondary IP freeform_tags. default_freeform_tags is used if this is not defined.
        }))) 
        secondary_vnics         = optional(map(object({
          display_name            = optional(string) # the VNIC display name.
          private_ip              = optional(string) # a private IP address of your choice to assign to the VNIC.
          hostname                = optional(string) # the VNIC hostname.
          assign_public_ip        = optional(bool)   # whether to assign the VNIC a public IP. Defaults to whether the subnet is public or private.
          subnet_id               = optional(string)   # the subnet where the VNIC is created. default_subnet_id is used if this is not defined.
          network_security_groups = optional(list(string))  # list of network security groups the VNIC should be placed into.
          skip_source_dest_check  = optional(bool,false) # whether the source/destination check is disabled on the VNIC. Default is false.
          nic_index               = optional(number,0) # the physical network interface card (NIC) the VNIC will use. Defaults to 0. Certain bare metal instance shapes have two active physical NICs (0 and 1).
          secondary_ips           = optional(map(object({ # list of secondary private IP addresses for the VNIC.
            display_name  = optional(string) # Secondary IP display name.
            hostname      = optional(string) # Secondary IP host name.
            private_ip    = optional(string) # Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
            defined_tags  = optional(map(string)) # Secondary IP defined_tags. default_defined_tags is used if this is not defined.
            freeform_tags = optional(map(string)) # Secondary IP freeform_tags. default_freeform_tags is used if this is not defined.
          })))
          security = optional(object({
            zpr_attributes = optional(list(object({
              namespace = optional(string,"oracle-zpr")
              attr_name = string
              attr_value = string
              mode = optional(string,"enforce")
            }))) 
          }))
          defined_tags            = optional(map(string)) # VNIC defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags           = optional(map(string)) # VNIC freeform_tags. default_freeform_tags is used if this is not defined.
        })))
      }))
      security = optional(object({
        apply_to_primary_vnic_only = optional(bool, false)
        zpr_attributes = optional(list(object({
          namespace = optional(string,"oracle-zpr")
          attr_name = string
          attr_value = string
          mode = optional(string,"enforce")
        }))) 
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
      cloud_agent = optional(object({ # Cloud Agent settings
        disable_management = optional(bool,false) # whether the management plugins should be disabled. These plugins are enabled by default in the Compute service.
        disable_monitoring = optional(bool,false) # whether the monitoring plugins should be disabled. These plugins are enabled by default in the Compute service.
        plugins = optional(list(object({ # list of plugins
          name = string # the plugin name. It must be a valid plugin name. The plugin names are available in https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm and in compute-only example(./examples/compute-only/input.auto.tfvars.template) as well.
          enabled = bool #Whether or not the plugin should be enabled. In order to disable a previously enabled plugin, set this value to false. Simply removing the plugin from the list will not disable it.
        })))
      }))
      cloud_init = optional(object({
        heredoc_script = optional(string) # the cloud-init script in Terraform heredoc style that is applied to the instance. It has precedence over script_file.
        script_file = optional(string)    # the cloud-init script file that is applied to the instance.    
      }))
      ssh_public_key_path = optional(string) # the SSH public key path used to access the instance.
      defined_tags        = optional(map(string)) # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags       = optional(map(string)) # instances freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
  default = null
}

variable "storage_configuration" {
  description = "Storage configuration attributes."
  type = object({
    default_compartment_id   = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_id attribute within each object.
    default_kms_key_id       = optional(string),      # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level        = optional(string,"1"),  # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags     = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags    = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.

    block_volumes = optional(map(object({    # the block volumes to manage in this configuration.
      cis_level           = optional(string,"1")
      compartment_id      = optional(string) # the compartment where the block volume is created. default_compartment_id is used if this is not defined.
      display_name        = string           # the name of the block volume.
      availability_domain = optional(number,1)  # the availability domain where to create the block volume.     
      volume_size         = optional(number,50) # the size of the block volume.
      vpus_per_gb         = optional(number,0)  # the number of vpus per gb. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH)
      attach_to_instances = optional(list(object({ # map to where to attach the block volume.
        instance_id = string      # the instance that this volume will be attached to.
        device_name = string      # where to mount the block volume. Should be one of the values from disk_mappings in the instance_configuration.
        attachment_type = optional(string,"paravirtualized") # the block volume attachment type. Valid values: "paravirtualized" (default), "iscsi".
        read_only = optional(bool,false) # whether the attachment is "Read Only" or "Read/Write". Default is false, which means "Read/Write".
      })))
      encryption = optional(object({ # encryption settings
        kms_key_id              = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit      = optional(bool,false)  # whether the block volume should encrypt traffic. Works only with paravirtualized attachment type. Default is false.
      }))
      replication = optional(object({ # replication settings
        availability_domain = number # the availability domain (AD) to replicate the volume. The AD is picked from the region specified by 'block_volumes_replication_region' variable if defined. Otherwise picked from the region specified by 'region' variable.
      }))
      backup_policy = optional(string,"bronze") # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". Default is "bronze".
      defined_tags  = optional(map(string))     # block volume defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags = optional(map(string))     # block volume freeform_tags. default_freeform_tags is used if this is not defined.
    }))),

    file_storage = optional(object({ # file storage settings.
      default_subnet_id = optional(string), # the default subnet used for all file system mount targets. It's overriden by the subnet_id attribute within each mount_target object.
      file_systems = map(object({     # the file systems.
        cis_level           = optional(string,"1")
        compartment_id      = optional(string) # the file system compartment. default_compartment_id is used if this is not defined.
        file_system_name    = string           # the file_system name.
        availability_domain = optional(number,1)  # the file system availability domain..   
        kms_key_id          = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        replication         = optional(object({ # replication settings
          is_target         = optional(bool,false) # whether the file system is a replication target. Default is false
          file_system_target_id = optional(string)  # the file system replication target. It must be an existing unexported file system, in the same or in a different region than the source file system.
          interval_in_minutes = optional(number,60) # time interval (in minutes) between replication snapshots. Default is 60 minutes.
        })) 
        snapshot_policy_id = optional(string) # the snapshot policy identifying key in the snapshots_policy map. A default snapshot policy is associated with file systems without a snapshot policy.
        defined_tags  = optional(map(string)) # file system defined_tags. default_defined_tags is used if this is not defined.
        freeform_tags = optional(map(string)) # file system freeform_tags. default_freeform_tags is used if this is not defined.
      }))
      mount_targets = optional(map(object({ # the mount targets.
        compartment_id      = optional(string) # the mount target compartment. default_compartment_id is used if this is not defined.
        mount_target_name   = string           # the mount target and export set name.
        availability_domain = optional(number,1) # the mount target availability domain.  
        subnet_id           = optional(string) # the mount target subnet. default_subnet_id is used if this is not defined.
        hostname_label      = optional(string) # the hostname for the mount target's IP address, used for DNS resolution. The value is the hostname portion of the private IP address's fully qualified domain name (FQDN).
        network_security_groups = optional(list(string)) # the Network Security Groups for the mount target
        exports = optional(list(object({
          path = string # export path. For example: /foo
          file_system_id = string # the file system identifying key the export applies to. It must be one of the keys in file_systems map of objects.
          options = optional(list(object({ # optional export options.
            source   = string # the source IP or CIDR allowed to access the mount target.
            access   = optional(string, "READ_ONLY") # type of access grants. Valid values (case sensitive): READ_WRITE, READ_ONLY.
            identity = optional(string, "NONE") # UID and GID remapped to. Valid values(case sensitive): ALL, ROOT, NONE.
            use_privileged_source_port = optional(bool, true)   # If true, accessing the file system through this export must connect from a privileged source port.
          })))
        })))
        defined_tags  = optional(map(string)) # mount target defined_tags. default_defined_tags is used if this is not defined.
        freeform_tags = optional(map(string)) # mount target freeform_tags. default_freeform_tags is used if this is not defined.
      })))
      snapshot_policies = optional(map(object({
        name = string
        compartment_id = optional(string)
        availability_domain = optional(number,1)
        prefix = optional(string)
        schedules = optional(list(object({
          period = string # "DAILY", "WEEKLY", "MONTHLY", "YEARLY"
          prefix = optional(string)
          time_zone = optional(string,"UTC")
          hour_of_day = optional(number,23)
          day_of_week = optional(string)
          day_of_month = optional(number)
          month = optional(string)
          retention_in_seconds = optional(number)
          start_time = optional(string)
        })))
        defined_tags  = optional(map(string)) # snapshot policy defined_tags. default_defined_tags is used if this is not defined.
        freeform_tags = optional(map(string)) # snapshot policy freeform_tags. default_freeform_tags is used if this is not defined.
      })))
    }))
  })
  default = null
}

variable "clusters_configuration" {
  description = "Clusters configuration attributes."
  type = object({
    default_compartment_id         = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags           = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags          = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.

    clusters = map(object({                         # the clusters to manage in this configuration.
      type                 = optional(string)       # the cluster type. Valid values: "cluster_network", "compute_cluster". Default is "cluster_network".
      compartment_id       = optional(string)       # the compartment where the cluster is created. default_compartment_ocid is used if this is not defined.
      availability_domain  = optional(number)       # the availability domain for cluster instances. Default is 1.
      name                 = string                 # the cluster display name.
      defined_tags         = optional(map(string))  # clusters defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags        = optional(map(string))  # clusters freeform_tags. default_freeform_tags is used if this is not defined.
      cluster_network_settings = optional(object({  # cluster network settings. Only applicable if type is "cluster_network".
        instance_configuration_id = string          # the instance configuration id to use in this cluster.
        instance_pool = optional(object({           # Cluster instance pool settings.
          name  = optional(string)                  # The instance pool name.
          size  = optional(number)                  # The number of instances in the instance pool. Defauls is 1.
        }))
        networking = object({
          subnet_id = string                          # The subnet where instances primary VNIC is placed.
          ipv6_enable = optional(bool)                # Whether IPv6 is enabled for instances primary VNIC. Default is false.
          ipv6_subnet_cidrs = optional(list(string))  # A list of IPv6 subnet CIDR ranges from which the primary VNIC is assigned an IPv6 address. Only applicable if ipv6_enable for primary VNIC is true. Default is [].
          secondary_vnic_settings = optional(object({ # Secondary VNIC settings
            subnet_id = string                        # The subnet where instances secondary VNIC are created.
            name = optional(string)                   # The secondary VNIC name.
            ipv6_enable = optional(bool)              # Whether IPv6 is enabled for the secondary VNIC. Default is false.
            ipv6_subnet_cidrs = optional(list(string)) # A list of IPv6 subnet CIDR ranges from which the secondary VNIC is assigned an IPv6 address. Only applicable if ipv6_enable for secondary VNIC is true. Default is [].
          }))
        })  
      }))  
    }))
  })
  default = null
}

variable "cluster_instances_configuration" {
  description = "Cluster instances configuration attributes"
  type = object({
    default_compartment_id      = optional(string)       # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    #default_ssh_public_key_path = optional(string)       # the default SSH public key path used to access the workers.
    #default_kms_key_id          = optional(string)       # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    configurations = map(object({                         # the instance configurations to manage in this configuration.
      compartment_id       = optional(string)  # the compartment where the instance configuration is created. default_compartment_id is used if this is not defined.
      name                 = optional(string)  # the instance configuration display name.
      instance_type        = optional(string)  # the instance type. Default is "compute".
      # instance_details     = optional(object({ # The instance details to use as the configuration template. If provided, an instance is created and used as template for all instances in the cluster instance pool.
      #   shape          = optional(string)      # the instance shape. Default is "BM.Optimized3.36".
      #   source_type    = optional(string)
      #   image_id       = optional(string) # the image id used to boot the instance.
      #   compartment_id = optional(string) # the instance compartment. It defaults to the configuration compartment_id if undefined.
      # }))
      template_instance_id = optional(string)       # the existing instance id to use as the configuration template for all instances in the cluster instance pool.
      defined_tags         = optional(map(string))  # instance configuration defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags        = optional(map(string))  # instance configuration freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
  default = null
}

variable "enable_output" {
  description = "Whether Terraform should enable the module output."
  type        = bool
  default     = true
}

variable "module_name" {
  description = "The module name."
  type        = string
  default     = "cis-compute-storage"
}

variable "compartments_dependency" {
  description = "A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the compartment OCID) of string type." 
  type = map(object({
    id = string # the compartment OCID
  }))
  default = null
}

variable "network_dependency" {
  description = "An object containing the externally managed network resources this module may depend on. Supported resources are 'subnets', and 'network_security_groups', represented as map of objects. Each object, when defined, must have an 'id' attribute of string type set with the subnet or NSG OCID."
  type = object({
    subnets = optional(map(object({
      id = string # the subnet OCID
    })))
    network_security_groups = optional(map(object({
      id = string # the NSG OCID
    })))
  })
  default = null
}

variable "kms_dependency" {
  description = "A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the key OCID) of string type." 
  type = map(object({
    id = string # the key OCID.
  }))
  default = null
}

variable "instances_dependency" {
  description = "A map of objects containing the externally managed Compute instances this module may depend on. The objects, when defined, must contain at least an 'id' attribute (representing the instance OCID) of string type." 
  type = map(object({
    id = string # the instance OCID
  }))
  default = null
}


variable "file_system_dependency" {
  description = "A map of objects containing the externally managed file storage resources this module may depend on. This is used when setting file system replication using target file systems managed in another Terraform configuration. All map objects must have the same type and must contain at least an 'id' attribute (representing the file system OCID) of string type." 
  type = map(object({
    id = string # the file system OCID.
  }))
  default = null
}


