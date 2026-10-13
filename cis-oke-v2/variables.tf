# Copyright (c) 2026 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0.

variable "cluster_configuration" {
  description = "One enhanced cluster. All worker pools in this invocation belong to it."
  type = object({
    cis_level          = optional(string, "1")
    compartment_id     = string
    kubernetes_version = optional(string)
    name               = string
    cluster_type       = optional(string, "enhanced")
    cni_type           = optional(string, "native")
    defined_tags       = optional(map(string))
    freeform_tags      = optional(map(string))
    options = optional(object({
      kubernetes_network_config = optional(object({
        pods_cidr     = optional(string)
        services_cidr = optional(string)
      }))
      persistent_volume_config = optional(object({
        defined_tags  = optional(map(string))
        freeform_tags = optional(map(string))
      }))
      service_lb_config = optional(object({
        defined_tags  = optional(map(string))
        freeform_tags = optional(map(string))
      }))
      openid_connect = optional(object({
        enable_discovery      = optional(bool, false)
        enable_authentication = optional(bool, false)
        ca_certificate        = optional(string)
        signing_algorithms    = optional(list(string))
        client_id             = optional(string)
        configuration_file    = optional(string)
        issuer_url            = optional(string)
        required_claims       = optional(map(string))
        username_claim        = optional(string)
        username_prefix       = optional(string)
        groups_claim          = optional(string)
        groups_prefix         = optional(string)
      }))
    }))

    networking = object({
      vcn_id                 = string
      api_endpoint_nsg_ids   = optional(list(string))
      api_endpoint_subnet_id = string
      service_lb_subnet_ids  = optional(list(string))
    })
    encryption = optional(object({
      kube_secret_kms_key_id = optional(string)
    }))
    image_signing = optional(object({
      image_policy_enabled = optional(bool)
      kms_key_ids          = optional(list(string))
    }))
  })
  default = null

  validation {
    condition = var.cluster_configuration == null ? true : (
      lower(var.cluster_configuration.cni_type) != "native" || try(var.cluster_configuration.options.kubernetes_network_config.pods_cidr, null) == null
    )
    error_message = "Native CNI clusters must omit options.kubernetes_network_config.pods_cidr; pod addresses come from the pod subnet."
  }
  validation {
    condition     = var.cluster_configuration == null ? true : try(length(trimspace(var.cluster_configuration.compartment_id)) > 0, false)
    error_message = "The cluster requires a nonblank compartment_id."
  }
  validation {
    condition = var.cluster_configuration == null ? true : (
      var.cluster_configuration.cluster_type == "enhanced" && contains(["native", "flannel"], lower(var.cluster_configuration.cni_type))
    )
    error_message = "Only enhanced clusters are supported (cluster_type must be enhanced); cni_type must be native/flannel."
  }
  validation {
    condition     = var.cluster_configuration == null ? true : contains(["1", "2"], var.cluster_configuration.cis_level)
    error_message = "Cluster CIS levels must be 1 or 2."
  }
}

variable "workers_configuration" {
  description = "Top-level default_* settings plus keyed worker_pools. Pool values override defaults; null inherits. See README for collection semantics."
  type = object({

    default_mode                       = optional(string)
    default_disable_default_cloud_init = optional(bool, false)
    # Custom MIME parts inherited by managed pools unless pool cloud_init is supplied.
    # Same part fields and semantics as worker_pools.cloud_init (documented below).
    default_cloud_init = optional(list(object({
      content      = string
      content_type = optional(string, "text/x-shellscript")
      filename     = optional(string)
      merge_type   = optional(string, "list(append)+dict(no_replace,recurse_list)+str(append)")
    })), [])
    default_kubernetes_version    = optional(string)
    default_shape                 = optional(string)
    default_size                  = optional(number)
    default_ocpus                 = optional(number)
    default_memory                = optional(number)
    default_boot_volume_size      = optional(number)
    default_os                    = optional(string, "Oracle Linux")
    default_os_version            = optional(string, "9")
    default_subnet_id             = optional(string)
    default_nsg_ids               = optional(list(string))
    default_pod_subnet_id         = optional(string)
    default_pod_nsg_ids           = optional(list(string))
    default_pv_transit_encryption = optional(bool)
    default_volume_kms_key_id     = optional(string)
    default_ssh_public_key        = optional(string)
    default_defined_tags          = optional(map(string))
    default_freeform_tags         = optional(map(string))
    default_node_defined_tags     = optional(map(string))
    default_node_freeform_tags    = optional(map(string))
    default_node_labels           = optional(map(string))
    worker_pools = optional(map(object({
      # Supported collection paths to replace instead of merge; explicit {} / [] clears.
      override_defaults = optional(set(string), [])

      # Only node-pool (managed) and virtual-node-pool are supported.
      mode                    = optional(string)
      name                    = optional(string)
      kubernetes_version      = optional(string)
      shape                   = optional(string)
      size                    = optional(number)
      ocpus                   = optional(number)
      memory                  = optional(number)
      boot_volume_size        = optional(number)
      image_id                = optional(string)
      os                      = optional(string)
      os_version              = optional(string)
      subnet_id               = optional(string)
      nsg_ids                 = optional(list(string))
      pod_subnet_id           = optional(string)
      pod_nsg_ids             = optional(list(string))
      max_pods_per_node       = optional(number, 31)
      placement_ads           = optional(list(number))
      placement_fds           = optional(list(string))
      capacity_reservation_id = optional(string)
      pv_transit_encryption   = optional(bool)
      volume_kms_key_id       = optional(string)
      ssh_public_key          = optional(string)
      defined_tags            = optional(map(string))
      freeform_tags           = optional(map(string))
      node_defined_tags       = optional(map(string))
      node_freeform_tags      = optional(map(string))
      node_labels             = optional(map(string))
      node_metadata           = optional(map(string))
      # Managed pools only. Null inherits the global setting; false enables default scripts.
      disable_default_cloud_init = optional(bool)
      # Omitted/null inherits default_cloud_init; a supplied list replaces it, [] clears it.
      cloud_init = optional(list(object({
        content = string
        # MIME type selects how cloud-init processes this part. Common choices:
        # - text/x-shellscript (default): executable script with a shebang (e.g. #!/bin/bash),
        #   run once per instance during cloud-init's final stage.
        # - text/cloud-config: YAML configuration (e.g. packages, write_files, runcmd);
        #   use this for declarative node setup. Include the #cloud-config header.
        # - text/cloud-boothook: early-boot script, run every boot; make it idempotent.
        # - text/x-shellscript-per-boot: script run on every boot.
        # - text/x-shellscript-per-instance: script run once for each instance identity.
        # - text/x-shellscript-per-once: script run once, tracked by cloud-init's semaphore.
        # Other handlers depend on the image's cloud-init version; list them on a node
        # with: cloud-init devel make-mime --list-types. Upstream accepts text/[a-z-]+.
        # https://docs.cloud-init.io/en/latest/explanation/format/mime.html
        content_type = optional(string, "text/x-shellscript")
        filename     = optional(string)
        # MIME Merge-Type policy for cloud-config YAML, not shell-script concatenation
        # or Terraform override_defaults. Syntax: list(options)+dict(options)+str(options).
        # List options: append/prepend add items at the end/start; replace overwrites;
        # no_replace retains an existing list. Choose the behavior needed for runcmd, etc.
        # Dict options: no_replace keeps existing values; replace allows new values to win;
        # allow_delete permits removal of keys absent from the incoming dictionary.
        # Recursion options: recurse_dict (on by default), recurse_list (off by default;
        # recurse_array is an alias), recurse_str (off by default) enable nested merging.
        # String option: append concatenates strings when string merging is reached.
        # The default below appends lists and retains existing dictionary values while
        # allowing nested lists to merge; it also selects append for string merging.
        # Example replacement policy: list(replace)+dict(replace)+str().
        # A part's policy governs merging subsequent cloud-config parts; MIME order matters.
        # https://docs.cloud-init.io/en/latest/reference/merging.html
        merge_type = optional(string, "list(append)+dict(no_replace,recurse_list)+str(append)")
      })))
      gva_secondary_vnics = optional(map(object({
        subnet_id              = string
        display_name           = optional(string)
        nic_index              = optional(number)
        application_resources  = optional(list(string))
        ip_count               = optional(number, 16)
        nsg_ids                = optional(list(string), [])
        skip_source_dest_check = optional(bool, true)
        assign_public_ip       = optional(bool, false)
        assign_ipv6ip          = optional(bool, false)
        ipv6_addresses         = optional(list(string), [])
        ipv6_cidrs             = optional(list(string), [])
        defined_tags           = optional(map(string))
        freeform_tags          = optional(map(string))
      })), {})
      eviction_grace_duration      = optional(number)
      force_node_delete            = optional(bool)
      node_cycling_enabled         = optional(bool)
      node_cycling_max_surge       = optional(string)
      node_cycling_max_unavailable = optional(string)
      preemptible_config = optional(object({
        enable                  = optional(bool, false)
        is_preserve_boot_volume = optional(bool, false)
      }))
      # Virtual node pools only; nonempty taints are rejected for managed pools.
      taints = optional(list(object({
        key    = optional(string)
        value  = optional(string)
        effect = optional(string)
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
  type = map(object({
    id = string
  }))
  default = null
}

variable "network_dependency" {
  description = "An object containing the externally managed network resources this module may depend on. Supported resources are 'vcns', 'subnets', and 'network_security_groups', represented as map of objects. Each object, when defined, must have an 'id' attribute of string type set with the VCN, subnet, or NSG OCID."
  type = object({
    vcns = optional(map(object({
      id = string
    })))
    subnets = optional(map(object({
      id = string
    })))
    network_security_groups = optional(map(object({
      id = string
    })))
  })
  default = null
}

variable "kms_dependency" {
  description = "A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the key OCID) of string type."
  type = map(object({
    id = string
  }))
  default = null
}
