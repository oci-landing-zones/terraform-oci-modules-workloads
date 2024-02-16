# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "clusters_configuration" {
  description = "Cluster configuration attributes."
  type = object({
    default_compartment_id         = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_img_kms_key_id         = optional(string)       # the default KMS key to assign as the master encryption key for images. It's overriden by the img_kms_key_id attribute within each object.
    default_kube_secret_kms_key_id = optional(string)       # the default KMS key to assign as the master encryption key for kubernetes secrets. It's overriden by the kube_secret_kms_key_id attribute within each object.
    default_cis_level              = optional(string, "1")  # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags           = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags          = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    clusters = map(object({                                 # the clusters to manage in this configuration.
      cis_level          = optional(string, "1")
      compartment_id     = optional(string)            # the compartment where the cluster is created. default_compartment_ocid is used if this is not defined.
      kubernetes_version = optional(string)            # the kubernetes version. If not specified the latest version will be selected.
      name               = string                      # the cluster display name.
      is_enhanced        = optional(bool, false)       # if the cluster is enhanced. It is designed to work only on Native CNI. Default is false.
      cni_type           = optional(string, "flannel") # the CNI type of the cluster. Can be either "flannel" or "native". Default is "flannel".
      defined_tags       = optional(map(string))       # clusters defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags      = optional(map(string))       # clusters freeform_tags. default_freeform_tags is used if this is not defined.
      options = optional(object({                      # optional attributes for the cluster.
        add_ons = optional(object({                    # configurable cluster addons.
          dashboard_enabled = optional(bool, false)    # if the dashboard is enabled. Default to false.
          tiller_enabled    = optional(bool, false)    # if the tiller is enabled. Default to false.
        }))
        admission_controller = optional(object({     # configurable cluster admission controllers. 
          pod_policy_enabled = optional(bool, false) # if the pod policy is enabled. Default to false.
        }))
        kubernetes_network_config = optional(object({ # pods and services network configuration for kubernetes.
          pods_cidr     = optional(string)            # the CIDR block for Kubernetes pods. Optional, defaults to 10.244.0.0/16.
          services_cidr = optional(string)            # the CIDR block for Kubernetes services. Optional, defaults to 10.96.0.0/16.
        }))
        persistent_volume_config = optional(object({ # configuration to be applied to block volumes created by Kubernetes Persistent Volume Claims (PVC).
          defined_tags  = optional(map(string))      # PVC defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags = optional(map(string))      # PVC freeform_tags. default_freeform_tags is used if this is not defined.
        }))
        service_lb_config = optional(object({   # configuration to be applied to load balancers created by Kubernetes services
          defined_tags  = optional(map(string)) # LB defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags = optional(map(string)) # LB freeform_tags. default_freeform_tags is used if this is not defined.
        }))
      }))
      networking = object({                         # cluster networking settings.
        vcn_id             = string                 # the vcn where the cluster will be created.
        public_endpoint    = optional(bool)         # if the api endpoint is public. default to false.
        api_nsg_ids        = optional(list(string)) # the nsgs used by the api endpoint.
        endpoint_subnet_id = string                 # the subnet for the api endpoint.
        services_subnet_id = optional(list(string)) # the subnets for the services(Load Balancers).
      })
      encryption = optional(object({              # encryption settings
        kube_secret_kms_key_id = optional(string) # # the KMS key to assign as the master encryption key for kube secrets. default_kube_secret_kms_key_id is used if this is not defined.
      }))
      image_signing = optional(object({
        image_policy_enabled = optional(bool)   # whether the image verification policy is enabled. default to false.
        img_kms_key_id       = optional(string) # the KMS key to assign as the master encryption key for images. default_img_kms_key_id is used if this is not defined.
      }))
    }))
  })
  default = null
}

variable "workers_configuration" {
  description = "Worker Nodes configuration attributes"
  type = object({
    default_cis_level           = optional(string, "1")  # the CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_compartment_id      = optional(string)       # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    default_ssh_public_key_path = optional(string)       # the default SSH public key path used to access the workers.
    default_kms_key_id          = optional(string)       # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_initial_node_labels = optional(map(string))  # the default initial node labels, a list of key/value pairs to add to nodes after they join the Kubernetes cluster.
    node_pools = optional(map(object({                   # the node pools to manage in this configuration.
      cis_level           = optional(string, "1")
      kubernetes_version  = optional(string)       # the kubernetes version for the node pool. it cannot be 2 versions older behind of the cluster version or newer. If not specified, the version of the cluster will be selected.
      cluster_id          = string                 # the cluster where the node pool will be created.
      compartment_id      = optional(string)       # the compartment where the node pool is created. default_compartment_ocid is used if this is not defined.
      name                = string                 # the node pool display name.
      defined_tags        = optional(map(string))  # node pool defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags       = optional(map(string))  # node pool freeform_tags. default_freeform_tags is used if this is not defined.
      initial_node_labels = optional(map(string))  # a list of key/value pairs to add to nodes after they join the Kubernetes cluster.
      size                = optional(number)       # the number of nodes that should be in the node pool.
      networking = object({                        # node pool networking settings.
        workers_nsg_ids   = optional(list(string)) # the nsgs to be used by the nodes.
        workers_subnet_id = string                 # the subnet for the nodes.
        pods_subnet_id    = optional(string)       # the subnet for the pods. only applied to native CNI.
        pods_nsg_ids      = optional(list(string)) # the nsgs to be used by the pods. only applied to native CNI.
        max_pods_per_node = optional(number)       # the maximum number of pods per node. only applied to native CNI.
      })
      node_config_details = object({                    # the configuration of nodes in the node pool.
        ssh_public_key_path     = optional(string)      # the SSH public key path used to access the workers. if not specified default_ssh_public_key_path will be used.
        defined_tags            = optional(map(string)) # nodes defined_tags. default_defined_tags is used if this is not defined.
        freeform_tags           = optional(map(string)) # nodes freeform_tags. default_freeform_tags is used if this is not defined.
        image                   = optional(string)      # the image for the nodes. Can be specified as ocid or as an Oracle Linux Version. Example: "8.8". If not specified the latest Oracle Linux image will be selected.
        node_shape              = string                # the shape of the nodes.
        capacity_reservation_id = optional(string)      # the OCID of the compute capacity reservation in which to place the compute instance.
        flex_shape_settings = optional(object({         # flex shape settings
          memory = optional(number, 16)                 # the nodes memory for Flex shapes. Default is 16GB.
          ocpus  = optional(number, 1)                  # the nodes ocpus number for Flex shapes. Default is 1.
        }))
        boot_volume = optional(object({                # the boot volume settings.
          size                 = optional(number, 60)  # the boot volume size.Default is 60.
          preserve_boot_volume = optional(bool, false) # whether to preserve the boot volume after the nodes are terminated.
        }))
        encryption = optional(object({                 # the encryption settings.
          enable_encrypt_in_transit = optional(bool)   # whether to enable the encrypt in transit. Default is false.
          kms_key_id                = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        }))
        placement = optional(list(object({       # placement settings.
          availability_domain = optional(number) # the nodes availability domain. Default is 1.
          fault_domain        = optional(number) # the nodes fault domain. Default is 1.
        })))
        node_eviction = optional(object({   # node eviction settings.
          grace_duration = optional(number) # duration after which OKE will give up eviction of the pods on the node. Can be specified in seconds. Default is 60 minutes.
          force_delete   = optional(bool)   # whether the nodes should be deleted if you cannot evict all the pods in grace period.
        }))
        node_cycling = optional(object({     # node cycling settings. Available only for Enhanced clusters.
          enable_cycling  = optional(bool)   # whether to enable node cycling. Default is false.
          max_surge       = optional(string) # maximum additional new compute instances that would be temporarily created and added to nodepool during the cycling nodepool process. OKE supports both integer and percentage input. Defaults to 1, Ranges from 0 to Nodepool size or 0% to 100%.
          max_unavailable = optional(string) # maximum active nodes that would be terminated from nodepool during the cycling nodepool process. OKE supports both integer and percentage input. Defaults to 0, Ranges from 0 to Nodepool size or 0% to 100%.
        }))
      })
    })))
    virtual_node_pools = optional(map(object({
      cluster_id                  = string                # the cluster where the virtual node pool will be created.
      compartment_id              = optional(string)      # the compartment where the virtual node pool is created. default_compartment_ocid is used if this is not defined.
      name                        = string                # the virtual node pool display name.
      defined_tags                = optional(map(string)) # virtual node pool defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags               = optional(map(string)) # virtual node pool freeform_tags. default_freeform_tags is used if this is not defined.
      virtual_nodes_defined_tags  = optional(map(string)) # defined_tags that apply to virtual nodes. default_defined_tags is used if this is not defined.
      virtual_nodes_freeform_tags = optional(map(string)) # freeform_tags that apply to virtual nodes. default_freeform_tags is used if this is not defined.
      initial_node_labels         = optional(map(string)) # a list of key/value pairs to add to virtual nodes after they join the Kubernetes cluster.
      size                        = optional(number)      # the number of virtual nodes that should be in the virtual node pool.
      pod_shape                   = string                # the shape assigned to pods. It can be one of Pod.Standard.A1.Flex, Pod.Standard.E3.Flex, Pod.Standard.E4.Flex.
      networking = object({                               # virtual node pool networking settings.
        workers_nsg_ids   = optional(list(string))        # the nsgs to be used by the virtual nodes.
        workers_subnet_id = string                        # the subnet for the virtual nodes.
        pods_subnet_id    = string                        # the subnet for the pods.
        pods_nsg_ids      = optional(list(string))        # the nsgs to be used by the pods.
      })
      placement = optional(list(object({       # placement settings.
        availability_domain = optional(number) # the virtual nodes availability domain. Default is 1.
        fault_domain        = optional(number) # the virtual nodes fault domain. Default is 1.
      })))
      taints = optional(list(object({ # the taints will be applied to the Virtual Nodes for Kubernetes scheduling.
        effect = optional(string)     # the effect of the pair.
        key    = optional(string)     # the key of the pair.
        value  = optional(string)     # the value of the pair.
      })))
    })))
  })
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
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    instances = map(object({                             # the instances to manage in this configuration.
      cis_level      = optional(string)
      compartment_id = optional(string)   # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      shape          = string             # the instance shape.
      name           = string             # the instance display name.
      platform_type  = optional(string)   # the platform type. Assigning this variable enables various platform security features in the Compute service. Valid values: "AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM".
      image = object({                    # the base image. You must provider either the id or (name and publisher name).
        id             = optional(string) # the base image id for creating the instance. It takes precedence over name and publisher_name.
        name           = optional(string) # the image name to search for in marketplace.
        publisher_name = optional(string) # the publisher name of the image name.
      })
      placement = optional(object({               # placement settings
        availability_domain = optional(number, 1) # the instance availability domain. Default is 1.
        fault_domain        = optional(number, 1) # the instance fault domain. Default is 1.
      }))
      boot_volume = optional(object({                                       # boot volume settings
        type                          = optional(string, "paravirtualized") # boot volume emulation type. Valid values: "paravirtualized" (default for platform images), "scsi", "iscsi", "ide", "vfio".
        firmware                      = optional(string)                    # firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
        size                          = optional(number, 50)                # boot volume size. Default is 50GB (minimum allowed by OCI).
        preserve_on_instance_deletion = optional(bool, true)                # whether to preserve boot volume after deletion. Default is true.
        secure_boot                   = optional(bool, false)               # prevents unauthorized boot loaders and operating systems from booting.
        measured_boot                 = optional(bool, false)               # enhances boot security by taking and storing measurements of boot components, such as bootloaders, drivers, and operating systems. Bare metal instances do not support Measured Boot.
        trusted_platform_module       = optional(bool, false)               # used to securely store boot measurements.
        backup_policy                 = optional(string, "bronze")          # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". Default is "bronze".
      }))
      volumes_emulation_type = optional(string, "paravirtualized")    # Emulation type for attached storage volumes. Valid values: "paravirtualized" (default for platform images), "scsi", "iscsi", "ide", "vfio". Module supported values for automated attachment: "paravirtualized", "iscsi".
      networking = optional(object({                                  # networking settings
        type                    = optional(string, "paravirtualized") # emulation type for the physical network interface card (NIC). Valid values: "paravirtualized" (default), "e1000", "vfio".
        private_ip              = optional(string)                    # a private IP address of your choice to assign to the primary VNIC.
        hostname                = optional(string)                    # the primary VNIC hostname.
        assign_public_ip        = optional(bool)                      # whether to assign the primary VNIC a public IP. Defaults to whether the subnet is public or private.
        subnet_id               = optional(string)                    # the subnet where the primary VNIC is created. default_subnet_id is used if this is not defined.
        network_security_groups = optional(list(string))              # list of network security groups the primary VNIC should be placed into.
        skip_source_dest_check  = optional(bool, false)               # whether the source/destination check is disabled on the primary VNIC. Default is false.
        secondary_ips = optional(map(object({                         # list of secondary private IP addresses for the primary VNIC.
          display_name  = optional(string)                            # Secondary IP display name.
          hostname      = optional(string)                            # Secondary IP host name.
          private_ip    = optional(string)                            # Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
          defined_tags  = optional(map(string))                       # Secondary IP defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags = optional(map(string))                       # Secondary IP freeform_tags. default_freeform_tags is used if this is not defined.
        })))
        secondary_vnics = optional(map(object({
          display_name            = optional(string)       # the VNIC display name.
          private_ip              = optional(string)       # a private IP address of your choice to assign to the VNIC.
          hostname                = optional(string)       # the VNIC hostname.
          assign_public_ip        = optional(bool)         # whether to assign the VNIC a public IP. Defaults to whether the subnet is public or private.
          subnet_id               = optional(string)       # the subnet where the VNIC is created. default_subnet_id is used if this is not defined.
          network_security_groups = optional(list(string)) # list of network security groups the VNIC should be placed into.
          skip_source_dest_check  = optional(bool, false)  # whether the source/destination check is disabled on the VNIC. Default is false.
          nic_index               = optional(number, 0)    # the physical network interface card (NIC) the VNIC will use. Defaults to 0. Certain bare metal instance shapes have two active physical NICs (0 and 1).
          secondary_ips = optional(map(object({            # list of secondary private IP addresses for the VNIC.
            display_name  = optional(string)               # Secondary IP display name.
            hostname      = optional(string)               # Secondary IP host name.
            private_ip    = optional(string)               # Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
            defined_tags  = optional(map(string))          # Secondary IP defined_tags. default_defined_tags is used if this is not defined.
            freeform_tags = optional(map(string))          # Secondary IP freeform_tags. default_freeform_tags is used if this is not defined.
          })))
          defined_tags  = optional(map(string)) # VNIC defined_tags. default_defined_tags is used if this is not defined.
          freeform_tags = optional(map(string)) # VNIC freeform_tags. default_freeform_tags is used if this is not defined.
        })))
      }))
      encryption = optional(object({                                  # encryption settings
        kms_key_id                            = optional(string)      # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit_on_instance_create = optional(bool, null)  # whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable at instance creation time only.
        encrypt_in_transit_on_instance_update = optional(bool, null)  # whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable at instance update time only.
        encrypt_data_in_use                   = optional(bool, false) # whether the instance encrypts data in-use (in memory) while being processed. A.k.a confidential computing.
      }))
      flex_shape_settings = optional(object({ # flex shape settings
        memory = optional(number, 16)         # the instance memory for Flex shapes. Default is 16GB.
        ocpus  = optional(number, 1)          # the instance ocpus number for Flex shapes. Default is 1.
      }))
      cloud_agent = optional(object({              # Cloud Agent settings
        disable_management = optional(bool, false) # whether the management plugins should be disabled. These plugins are enabled by default in the Compute service.
        disable_monitoring = optional(bool, false) # whether the monitoring plugins should be disabled. These plugins are enabled by default in the Compute service.
        plugins = optional(list(object({           # list of plugins
          name    = string                         # the plugin name. It must be a valid plugin name. The plugin names are available in https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm and in compute-only example(./examples/compute-only/input.auto.tfvars.template) as well.
          enabled = bool                           #Whether or not the plugin should be enabled. In order to disable a previously enabled plugin, set this value to false. Simply removing the plugin from the list will not disable it.
        })))
      }))
      ssh_public_key_path = optional(string)      # the SSH public key path used to access the instance.
      defined_tags        = optional(map(string)) # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags       = optional(map(string)) # instances freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
  default = null
}

### Bastion variables
variable "bastions_configuration" {
  description = "Bastion configuration attributes."
  type = object({
    default_compartment_id        = optional(string)       # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags          = optional(map(string))  # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags         = optional(map(string))  # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    default_subnet_id             = optional(string)       # the default subnet_id. It`s overriden by the subnet_id attribute in each object.
    default_cidr_block_allow_list = optional(list(string)) # the default cidr block allow list. It`s overriden by the cidr_block_allow_list attribute in each object.
    bastions = map(object({
      bastion_type               = optional(string, "standard") # type of bastion. Allowed value is "STANDARD".
      compartment_id             = optional(string)             # the compartment where the bastion is created. default_compartment_ocid is used if this is not defined.
      subnet_id                  = optional(string)             # the subnet id where the bastion will be created. default_subnet_id is used if this is not defined.
      defined_tags               = optional(map(string))        # bastions defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags              = optional(map(string))        # bastions freeform_tags. default_freeform_tags is used if this is not defined.
      cidr_block_allow_list      = optional(list(string))       # list of cidr blocks that will be able to connect to bastion. default_cidr_block_allow_list is used if this is not defined.
      enable_dns_proxy           = optional(bool, true)         # bool to enable dns_proxy on the bastion.
      max_session_ttl_in_seconds = optional(number)             # maximum allowd time to live for a session on the bastion.
      name                       = string                       # bastion name
    }))
  })
  default = null
}

variable "sessions_configuration" {
  description = "Sessions configuration attributes."
  type = object({
    default_ssh_public_key = optional(string) # the default ssh_public_key path. It's overriden by the ssh_public_key attribute within each object.
    default_session_type   = optional(string) # the default session_type. It's overriden by the session_type attribute within each object.
    sessions = map(object({
      bastion_id             = string           # the ocid or the key of Bastion where the session will be created.
      ssh_public_key         = optional(string) # the ssh_public_key path used by the session to connect to target. The default_ssh_public_key is used if this is not defined.
      ssh_private_key        = optional(string) # the ssh_private_key path used by terraform to generate the command to connect to the target resource.
      session_type           = optional(string) # session type of the session. Supported values are MANAGED_SSH and PORT_FORWARDING. The default_session_type is used if this is not defined.
      target_resource        = string           # Either the FQDN, OCID or IP of the target resource to connect the session to.
      target_user            = optional(string) # User of the target that will be used by session. It is required only with MANAGED_SSH. 
      target_port            = number           # Port number that will be used by the session.
      session_ttl_in_seconds = optional(number) # Session time to live
      session_name           = string           # Session name
    }))
  })
  default = null
}
