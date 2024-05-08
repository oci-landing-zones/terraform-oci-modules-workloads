# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "clusters_configuration" {
  description = "Cluster configuration attributes."
  type = object({
    default_compartment_id         = optional(string)       # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_img_kms_key_id         = optional(string)       # the default KMS key to assign as the master encryption key for images. It's overriden by the img_kms_key_id attribute within each object.
    default_kube_secret_kms_key_id = optional(string)       # the default KMS key to assign as the master encryption key for kubernetes secrets. It's overriden by the kube_secret_kms_key_id attribute within each object.
    default_cis_level              = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags           = optional(map(string))  # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags          = optional(map(string))  # the default freeform tags. It's overriden by the freeform_tags attribute within each object.

    clusters = map(object({ # the clusters to manage in this configuration.
      cis_level          = optional(string)
      compartment_id     = optional(string)            # the compartment where the cluster is created. default_compartment_ocid is used if this is not defined.
      kubernetes_version = optional(string)            # the kubernetes version. If not specified the latest version will be selected.
      name               = string                      # the cluster display name.
      is_enhanced        = optional(bool)              # if the cluster is enhanced. It is designed to work only on Native CNI. Default is false.
      cni_type           = optional(string)            # the CNI type of the cluster. Can be either "flannel" or "native". Default is "flannel".
      defined_tags       = optional(map(string))       # clusters defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags      = optional(map(string))       # clusters freeform_tags. default_freeform_tags is used if this is not defined.
      options = optional(object({                      # optional attributes for the cluster.
        add_ons = optional(object({                    # configurable cluster addons.
          dashboard_enabled = optional(bool)           # if the dashboard is enabled. Default to false.
          tiller_enabled    = optional(bool)           # if the tiller is enabled. Default to false.
        }))
        admission_controller = optional(object({     # configurable cluster admission controllers. 
          pod_policy_enabled = optional(bool)        # if the pod policy is enabled. Default to false.
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

      networking = object({                             # cluster networking settings.
        vcn_id                 = string                 # the vcn where the cluster will be created.
        is_api_endpoint_public = optional(bool)         # if the api endpoint is public. default to false.
        api_endpoint_nsg_ids   = optional(list(string)) # the nsgs used by the api endpoint.
        api_endpoint_subnet_id = string                 # the subnet for the api endpoint.
        services_subnet_id     = optional(list(string)) # the subnets for the services(Load Balancers).
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
    default_cis_level           = optional(string)       # the CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_compartment_id      = optional(string)       # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags        = optional(map(string))  # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string))  # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
    default_ssh_public_key_path = optional(string)       # the default SSH public key path used to access the workers.
    default_kms_key_id          = optional(string)       # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_initial_node_labels = optional(map(string))  # the default initial node labels, a list of key/value pairs to add to nodes after they join the Kubernetes cluster.

    node_pools = optional(map(object({ # the node pools to manage in this configuration.
      cis_level           = optional(string)
      kubernetes_version  = optional(string)      # the kubernetes version for the node pool. it cannot be 2 versions older behind of the cluster version or newer. If not specified, the version of the cluster will be selected.
      cluster_id          = string                # the cluster where the node pool will be created.
      compartment_id      = optional(string)      # the compartment where the node pool is created. default_compartment_ocid is used if this is not defined.
      name                = string                # the node pool display name.
      defined_tags        = optional(map(string)) # node pool defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags       = optional(map(string)) # node pool freeform_tags. default_freeform_tags is used if this is not defined.
      initial_node_labels = optional(map(string)) # a list of key/value pairs to add to nodes after they join the Kubernetes cluster.
      size                = optional(number)      # the number of nodes that should be in the node pool.

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
          memory = optional(number)                     # the nodes memory for Flex shapes. Default is 16GB.
          ocpus  = optional(number)                     # the nodes ocpus number for Flex shapes. Default is 1.
        }))
        boot_volume = optional(object({                # the boot volume settings.
          size                 = optional(number)      # the boot volume size.Default is 60.
          preserve_boot_volume = optional(bool)        # whether to preserve the boot volume after the nodes are terminated.
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
    })), {})

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

      networking = object({                        # virtual node pool networking settings.
        workers_nsg_ids   = optional(list(string)) # the nsgs to be used by the virtual nodes.
        workers_subnet_id = string                 # the subnet for the virtual nodes.
        pods_subnet_id    = string                 # the subnet for the pods.
        pods_nsg_ids      = optional(list(string)) # the nsgs to be used by the pods.
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
    })), {})
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
  default     = "cis-oke"
}

variable "compartments_dependency" {
  description = "A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the compartment OCID) of string type."
  type        = map(any)
  default     = null
}

variable "network_dependency" {
  description = "A map of objects containing the externally managed network resources this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the network resource OCID) of string type."
  type        = map(any)
  default     = null
}

variable "kms_dependency" {
  description = "A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the key OCID) of string type."
  type        = map(any)
  default     = null
}


