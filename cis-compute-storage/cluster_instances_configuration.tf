# locals {
#   supported_shapes = {
#     (lower("BM.HPC2.36"))       : "BM.HPC2.36"
#     (lower("BM.GPU.A100-v2.8")) : "BM.GPU.A100-v2.8"
#     (lower("BM.GPU4.8"))        : "BM.GPU4.8"
#     (lower("BM.Optimized3.36")) : "BM.Optimized3.36"
#   }
# }

data "oci_core_instance" "these" {
  for_each = var.cluster_instances_configuration != null ? (var.cluster_instances_configuration.configurations != null ? ({for k, v in var.cluster_instances_configuration.configurations : k => v if v.template_instance_id != null}): {}) : {}  
    instance_id = contains(keys(oci_core_instance.these),each.value.template_instance_id) ? oci_core_instance.these[each.value.template_instance_id].id : length(regexall("^ocid1.*$", each.value.template_instance_id)) > 0 ? each.value.template_instance_id : var.instances_dependency[each.value.template_instance_id].id
}

resource "oci_core_instance_configuration" "these" {
  for_each = var.cluster_instances_configuration != null ? (var.cluster_instances_configuration.configurations != null ? var.cluster_instances_configuration.configurations : {}) : {}
#   lifecycle {
#       ## Check 1: supported shapes check for NEW instances
#       precondition {
#         condition = each.value.instance_details != null ? (contains(keys(local.supported_shapes),lower(coalesce(each.value.instance_details.shape,"BM.Optimized3.36")))) : true
#         error_message = "VALIDATION FAILURE in instance configuration \"${each.key}\": invalid \"${each.value.instance_details != null ? lower(coalesce(each.value.instance_details.shape,"BM.Optimized3.36")) : ""}\" instance shape. Supported instance shape values for cluster networks are ${join(", ",[for v in values(local.supported_shapes): "\"${v}\""])}, case insensitive."
#       }
#       ## Check 1: supported shapes check for EXISTING instances
#       precondition {
#         condition = each.value.template_instance_id != null ? (contains(keys(local.supported_shapes),lower(data.oci_core_instance.these[each.key].shape))) : true
#         #error_message = "VALIDATION FAILURE in instance configuration \"${each.key}\": the instance shape of provided \"template_instance_id\" attribute (\"${coalesce(each.value.template_instance_id,"__void__")}\") is invalid: \"${contains(keys(local.supported_shapes),lower(data.oci_core_instance.these[each.key].shape)) ? data.oci_core_instance.these[each.key].shape : ""}\". Supported instance shape values for cluster networks are ${join(", ",[for v in values(local.supported_shapes): "\"${v}\""])}."
#         error_message = "VALIDATION FAILURE in instance configuration \"${each.key}\": the instance shape of provided \"template_instance_id\" attribute (\"${coalesce(each.value.template_instance_id,"__void__")}\") is invalid. Supported instance shape values for cluster networks are ${join(", ",[for v in values(local.supported_shapes): "\"${v}\""])}."
#       }
#     }
    #Required
    compartment_id = each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.cluster_instances_configuration.default_compartment_id)) > 0 ? var.cluster_instances_configuration.default_compartment_id : var.compartments_dependency[var.cluster_instances_configuration.default_compartment_id].id)

    #Optional
    display_name = each.value.name
    defined_tags = each.value.defined_tags != null ? each.value.defined_tags : var.cluster_instances_configuration.default_defined_tags
    freeform_tags = each.value.freeform_tags != null ? each.value.freeform_tags : var.cluster_instances_configuration.default_freeform_tags

    # instance_id and source are relevant when the instance configuration is created based on a EXISTING instance (when instance_details attribute is not provided)
    instance_id = contains(keys(oci_core_instance.these),each.value.template_instance_id) ? oci_core_instance.these[each.value.template_instance_id].id : (length(regexall("^ocid1.*$", each.value.template_instance_id)) > 0 ? each.value.template_instance_id : var.instances_dependency[each.value.template_instance_id].id)
    source = each.value.template_instance_id != null ? "INSTANCE" : "NONE"

    ### instance_details {
        #Required
        ###vinstance_type = coalesce(each.value.instance_type,"compute")

        #Optional
        # block_volumes {

        #     #Optional
        #     attach_details {
        #         #Required
        #         type = var.instance_configuration_instance_details_block_volumes_attach_details_type

        #         #Optional
        #         device = var.instance_configuration_instance_details_block_volumes_attach_details_device
        #         display_name = var.instance_configuration_instance_details_block_volumes_attach_details_display_name
        #         is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_block_volumes_attach_details_is_pv_encryption_in_transit_enabled
        #         is_read_only = var.instance_configuration_instance_details_block_volumes_attach_details_is_read_only
        #         is_shareable = var.instance_configuration_instance_details_block_volumes_attach_details_is_shareable
        #         use_chap = var.instance_configuration_instance_details_block_volumes_attach_details_use_chap
        #     }
        #     create_details {

        #         #Optional
        #         autotune_policies {
        #             #Required
        #             autotune_type = var.instance_configuration_instance_details_block_volumes_create_details_autotune_policies_autotune_type

        #             #Optional
        #             max_vpus_per_gb = var.instance_configuration_instance_details_block_volumes_create_details_autotune_policies_max_vpus_per_gb
        #         }
        #         availability_domain = var.instance_configuration_instance_details_block_volumes_create_details_availability_domain
        #         backup_policy_id = data.oci_core_volume_backup_policies.test_volume_backup_policies.volume_backup_policies.0.id
        #         block_volume_replicas {
        #             #Required
        #             availability_domain = var.instance_configuration_instance_details_block_volumes_create_details_block_volume_replicas_availability_domain

        #             #Optional
        #             display_name = var.instance_configuration_instance_details_block_volumes_create_details_block_volume_replicas_display_name
        #         }
        #         compartment_id = var.compartment_id
        #         defined_tags = {"Operations.CostCenter"= "42"}
        #         display_name = var.instance_configuration_instance_details_block_volumes_create_details_display_name
        #         freeform_tags = {"Department"= "Finance"}
        #         is_auto_tune_enabled = var.instance_configuration_instance_details_block_volumes_create_details_is_auto_tune_enabled
        #         kms_key_id = oci_kms_key.test_key.id
        #         size_in_gbs = var.instance_configuration_instance_details_block_volumes_create_details_size_in_gbs
        #         source_details {
        #             #Required
        #             type = var.instance_configuration_instance_details_block_volumes_create_details_source_details_type

        #             #Optional
        #             id = var.instance_configuration_instance_details_block_volumes_create_details_source_details_id
        #         }
        #         vpus_per_gb = var.instance_configuration_instance_details_block_volumes_create_details_vpus_per_gb
        #     }
        #     volume_id = oci_core_volume.test_volume.id
        # }

        # launch_details is relevant when the instance configuration is created based on a NEW instance (when instance_details attribute is provided).
        ### dynamic "launch_details" {
          ### for_each = each.value.instance_details != null ? [1] : []
          ### content {
            #Optional
            # agent_config {

            #     #Optional
            #     are_all_plugins_disabled = var.instance_configuration_instance_details_launch_details_agent_config_are_all_plugins_disabled
            #     is_management_disabled = var.instance_configuration_instance_details_launch_details_agent_config_is_management_disabled
            #     is_monitoring_disabled = var.instance_configuration_instance_details_launch_details_agent_config_is_monitoring_disabled
            #     plugins_config {

            #         #Optional
            #         desired_state = var.instance_configuration_instance_details_launch_details_agent_config_plugins_config_desired_state
            #         name = var.instance_configuration_instance_details_launch_details_agent_config_plugins_config_name
            #     }
            # }
            # availability_config {

            #     #Optional
            #     is_live_migration_preferred = var.instance_configuration_instance_details_launch_details_availability_config_is_live_migration_preferred
            #     recovery_action = var.instance_configuration_instance_details_launch_details_availability_config_recovery_action
            # }
            # availability_domain = var.instance_configuration_instance_details_launch_details_availability_domain
            # capacity_reservation_id = oci_core_capacity_reservation.test_capacity_reservation.id
            ### compartment_id = each.value.instance_details.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.instance_details.compartment_id)) > 0 ? each.value.instance_details.compartment_id : var.compartments_dependency[each.value.instance_details.compartment_id].id) : (each.value.compartment_id != null ? (length(regexall("^ocid1.*$", each.value.compartment_id)) > 0 ? each.value.compartment_id : var.compartments_dependency[each.value.compartment_id].id) : (length(regexall("^ocid1.*$", var.cluster_instances_configuration.default_compartment_id)) > 0 ? var.cluster_instances_configuration.default_compartment_id : var.compartments_dependency[var.cluster_instances_configuration.default_compartment_id].id))

            #     #Optional
            #     assign_ipv6ip = var.instance_configuration_instance_details_launch_details_create_vnic_details_assign_ipv6ip
            #     assign_private_dns_record = var.instance_configuration_instance_details_launch_details_create_vnic_details_assign_private_dns_record
            #     assign_public_ip = var.instance_configuration_instance_details_launch_details_create_vnic_details_assign_public_ip
            #     defined_tags = {"Operations.CostCenter"= "42"}
            #     display_name = var.instance_configuration_instance_details_launch_details_create_vnic_details_display_name
            #     freeform_tags = {"Department"= "Finance"}
            #     hostname_label = var.instance_configuration_instance_details_launch_details_create_vnic_details_hostname_label
            #     ipv6address_ipv6subnet_cidr_pair_details {

            #         #Optional
            #         ipv6address = var.instance_configuration_instance_details_launch_details_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6address
            #         ipv6subnet_cidr = var.instance_configuration_instance_details_launch_details_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6subnet_cidr
            #     }               
            #     nsg_ids = var.instance_configuration_instance_details_launch_details_create_vnic_details_nsg_ids
            #     private_ip = var.instance_configuration_instance_details_launch_details_create_vnic_details_private_ip
            #     skip_source_dest_check = var.instance_configuration_instance_details_launch_details_create_vnic_details_skip_source_dest_check
            #     subnet_id = oci_core_subnet.test_subnet.id
            # }
            # dedicated_vm_host_id = oci_core_dedicated_vm_host.test_dedicated_vm_host.id
            # defined_tags = {"Operations.CostCenter"= "42"}
            # display_name = var.instance_configuration_instance_details_launch_details_display_name
            # extended_metadata = var.instance_configuration_instance_details_launch_details_extended_metadata
            # fault_domain = var.instance_configuration_instance_details_launch_details_fault_domain
            # freeform_tags = {"Department"= "Finance"}
            # instance_options {

            #     #Optional
            #     are_legacy_imds_endpoints_disabled = var.instance_configuration_instance_details_launch_details_instance_options_are_legacy_imds_endpoints_disabled
            # }
            # ipxe_script = var.instance_configuration_instance_details_launch_details_ipxe_script
            # is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_launch_details_is_pv_encryption_in_transit_enabled
            # launch_mode = var.instance_configuration_instance_details_launch_details_launch_mode
            # launch_options {

            #     #Optional
            #     boot_volume_type = var.instance_configuration_instance_details_launch_details_launch_options_boot_volume_type
            #     firmware = var.instance_configuration_instance_details_launch_details_launch_options_firmware
            #     is_consistent_volume_naming_enabled = var.instance_configuration_instance_details_launch_details_launch_options_is_consistent_volume_naming_enabled
            #     is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_launch_details_launch_options_is_pv_encryption_in_transit_enabled
            #     network_type = var.instance_configuration_instance_details_launch_details_launch_options_network_type
            #     remote_data_volume_type = var.instance_configuration_instance_details_launch_details_launch_options_remote_data_volume_type
            # }
            # metadata = var.instance_configuration_instance_details_launch_details_metadata
            # platform_config {
            #     #Required
            #     type = var.instance_configuration_instance_details_launch_details_platform_config_type

            #     #Optional
            #     are_virtual_instructions_enabled = var.instance_configuration_instance_details_launch_details_platform_config_are_virtual_instructions_enabled
            #     config_map = var.instance_configuration_instance_details_launch_details_platform_config_config_map
            #     is_access_control_service_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_access_control_service_enabled
            #     is_input_output_memory_management_unit_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_input_output_memory_management_unit_enabled
            #     is_measured_boot_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_measured_boot_enabled
            #     is_memory_encryption_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_memory_encryption_enabled
            #     is_secure_boot_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_secure_boot_enabled
            #     is_symmetric_multi_threading_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_symmetric_multi_threading_enabled
            #     is_trusted_platform_module_enabled = var.instance_configuration_instance_details_launch_details_platform_config_is_trusted_platform_module_enabled
            #     numa_nodes_per_socket = var.instance_configuration_instance_details_launch_details_platform_config_numa_nodes_per_socket
            #     percentage_of_cores_enabled = var.instance_configuration_instance_details_launch_details_platform_config_percentage_of_cores_enabled
            # }
            # preemptible_instance_config {

            #     #Optional
            #     preemption_action {
            #         #Required
            #         type = var.instance_configuration_instance_details_launch_details_preemptible_instance_config_preemption_action_type

            #         #Optional
            #         preserve_boot_volume = var.instance_configuration_instance_details_launch_details_preemptible_instance_config_preemption_action_preserve_boot_volume
            #     }
            # }
            # preferred_maintenance_action = var.instance_configuration_instance_details_launch_details_preferred_maintenance_action
            ### shape = local.supported_shapes[lower(each.value.instance_details.shape)]
            # shape_config {

            #     #Optional
            #     baseline_ocpu_utilization = var.instance_configuration_instance_details_launch_details_shape_config_baseline_ocpu_utilization
            #     memory_in_gbs = var.instance_configuration_instance_details_launch_details_shape_config_memory_in_gbs
            #     nvmes = var.instance_configuration_instance_details_launch_details_shape_config_nvmes
            #     ocpus = var.instance_configuration_instance_details_launch_details_shape_config_ocpus
            #     vcpus = var.instance_configuration_instance_details_launch_details_shape_config_vcpus
            # }
            ### source_details {
              ### source_type = coalesce(each.value.instance_details.source_type,"image")

            #     #Optional
            #     boot_volume_id = oci_core_boot_volume.test_boot_volume.id
            #     boot_volume_size_in_gbs = var.instance_configuration_instance_details_launch_details_source_details_boot_volume_size_in_gbs
            #     boot_volume_vpus_per_gb = var.instance_configuration_instance_details_launch_details_source_details_boot_volume_vpus_per_gb
               ### image_id = lower(coalesce(each.value.instance_details.source_type,"image")) == "image" ? each.value.instance_details.image_id : null
            #     kms_key_id = oci_kms_key.test_key.id
            #     instance_source_image_filter_details {

            #         #Optional
            #         compartment_id = var.compartment_id
            #         defined_tags_filter = var.instance_configuration_instance_details_launch_details_source_details_instance_source_image_filter_details_defined_tags_filter
            #         operating_system = var.instance_configuration_instance_details_launch_details_source_details_instance_source_image_filter_details_operating_system
            #         operating_system_version = var.instance_configuration_instance_details_launch_details_source_details_instance_source_image_filter_details_operating_system_version
            #     }
            ### }
          ### }
            
        ### }
        # options {

        #     #Optional
        #     block_volumes {

        #         #Optional
        #         attach_details {
        #             #Required
        #             type = var.instance_configuration_instance_details_options_block_volumes_attach_details_type

        #             #Optional
        #             device = var.instance_configuration_instance_details_options_block_volumes_attach_details_device
        #             display_name = var.instance_configuration_instance_details_options_block_volumes_attach_details_display_name
        #             is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_options_block_volumes_attach_details_is_pv_encryption_in_transit_enabled
        #             is_read_only = var.instance_configuration_instance_details_options_block_volumes_attach_details_is_read_only
        #             is_shareable = var.instance_configuration_instance_details_options_block_volumes_attach_details_is_shareable
        #             use_chap = var.instance_configuration_instance_details_options_block_volumes_attach_details_use_chap
        #         }
        #         create_details {

        #             #Optional
        #             autotune_policies {
        #                 #Required
        #                 autotune_type = var.instance_configuration_instance_details_options_block_volumes_create_details_autotune_policies_autotune_type

        #                 #Optional
        #                 max_vpus_per_gb = var.instance_configuration_instance_details_options_block_volumes_create_details_autotune_policies_max_vpus_per_gb
        #             }
        #             availability_domain = var.instance_configuration_instance_details_options_block_volumes_create_details_availability_domain
        #             backup_policy_id = data.oci_core_volume_backup_policies.test_volume_backup_policies.volume_backup_policies.0.id
        #             compartment_id = var.compartment_id
        #             defined_tags = {"Operations.CostCenter"= "42"}
        #             display_name = var.instance_configuration_instance_details_options_block_volumes_create_details_display_name
        #             freeform_tags = {"Department"= "Finance"}
        #             kms_key_id = oci_kms_key.test_key.id
        #             size_in_gbs = var.instance_configuration_instance_details_options_block_volumes_create_details_size_in_gbs
        #             source_details {
        #                 #Required
        #                 type = var.instance_configuration_instance_details_options_block_volumes_create_details_source_details_type

        #                 #Optional
        #                 id = var.instance_configuration_instance_details_options_block_volumes_create_details_source_details_id
        #             }
        #             vpus_per_gb = var.instance_configuration_instance_details_options_block_volumes_create_details_vpus_per_gb
        #         }
        #         volume_id = oci_core_volume.test_volume.id
        #     }
        #     launch_details {

        #         #Optional
        #         agent_config {

        #             #Optional
        #             are_all_plugins_disabled = var.instance_configuration_instance_details_options_launch_details_agent_config_are_all_plugins_disabled
        #             is_management_disabled = var.instance_configuration_instance_details_options_launch_details_agent_config_is_management_disabled
        #             is_monitoring_disabled = var.instance_configuration_instance_details_options_launch_details_agent_config_is_monitoring_disabled
        #             plugins_config {

        #                 #Optional
        #                 desired_state = var.instance_configuration_instance_details_options_launch_details_agent_config_plugins_config_desired_state
        #                 name = var.instance_configuration_instance_details_options_launch_details_agent_config_plugins_config_name
        #             }
        #         }
        #         availability_config {

        #             #Optional
        #             recovery_action = var.instance_configuration_instance_details_options_launch_details_availability_config_recovery_action
        #         }
        #         availability_domain = var.instance_configuration_instance_details_options_launch_details_availability_domain
        #         capacity_reservation_id = oci_core_capacity_reservation.test_capacity_reservation.id
        #         compartment_id = var.compartment_id
        #         create_vnic_details {

        #             #Optional
        #             assign_ipv6ip = var.instance_configuration_instance_details_launch_details_create_vnic_details_assign_ipv6ip
        #             assign_private_dns_record = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_assign_private_dns_record
        #             assign_public_ip = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_assign_public_ip
        #             defined_tags = {"Operations.CostCenter"= "42"}
        #             display_name = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_display_name
        #             freeform_tags = {"Department"= "Finance"}
        #             hostname_label = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_hostname_label
        #             ipv6address_ipv6subnet_cidr_pair_details {

        #                 #Optional
        #                 ipv6address = var.instance_configuration_instance_details_launch_details_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6address
        #                 ipv6subnet_cidr = var.instance_configuration_instance_details_launch_details_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6subnet_cidr
        #             }
        #             nsg_ids = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_nsg_ids
        #             private_ip = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_private_ip
        #             skip_source_dest_check = var.instance_configuration_instance_details_options_launch_details_create_vnic_details_skip_source_dest_check
        #             subnet_id = oci_core_subnet.test_subnet.id
        #         }
        #         dedicated_vm_host_id = oci_core_dedicated_vm_host.test_dedicated_vm_host.id
        #         defined_tags = {"Operations.CostCenter"= "42"}
        #         display_name = var.instance_configuration_instance_details_options_launch_details_display_name
        #         extended_metadata = var.instance_configuration_instance_details_options_launch_details_extended_metadata
        #         fault_domain = var.instance_configuration_instance_details_options_launch_details_fault_domain
        #         freeform_tags = {"Department"= "Finance"}
        #         instance_options {

        #             #Optional
        #             are_legacy_imds_endpoints_disabled = var.instance_configuration_instance_details_options_launch_details_instance_options_are_legacy_imds_endpoints_disabled
        #         }
        #         ipxe_script = var.instance_configuration_instance_details_options_launch_details_ipxe_script
        #         is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_options_launch_details_is_pv_encryption_in_transit_enabled
        #         launch_mode = var.instance_configuration_instance_details_options_launch_details_launch_mode
        #         launch_options {

        #             #Optional
        #             boot_volume_type = var.instance_configuration_instance_details_options_launch_details_launch_options_boot_volume_type
        #             firmware = var.instance_configuration_instance_details_options_launch_details_launch_options_firmware
        #             is_consistent_volume_naming_enabled = var.instance_configuration_instance_details_options_launch_details_launch_options_is_consistent_volume_naming_enabled
        #             is_pv_encryption_in_transit_enabled = var.instance_configuration_instance_details_options_launch_details_launch_options_is_pv_encryption_in_transit_enabled
        #             network_type = var.instance_configuration_instance_details_options_launch_details_launch_options_network_type
        #             remote_data_volume_type = var.instance_configuration_instance_details_options_launch_details_launch_options_remote_data_volume_type
        #         }
        #         metadata = var.instance_configuration_instance_details_options_launch_details_metadata
        #         platform_config {
        #             #Required
        #             type = var.instance_configuration_instance_details_options_launch_details_platform_config_type

        #             #Optional
        #             are_virtual_instructions_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_are_virtual_instructions_enabled
        #             is_access_control_service_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_access_control_service_enabled
        #             is_input_output_memory_management_unit_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_input_output_memory_management_unit_enabled
        #             is_measured_boot_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_measured_boot_enabled
        #             is_memory_encryption_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_memory_encryption_enabled
        #             is_secure_boot_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_secure_boot_enabled
        #             is_symmetric_multi_threading_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_symmetric_multi_threading_enabled
        #             is_trusted_platform_module_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_is_trusted_platform_module_enabled
        #             numa_nodes_per_socket = var.instance_configuration_instance_details_options_launch_details_platform_config_numa_nodes_per_socket
        #             percentage_of_cores_enabled = var.instance_configuration_instance_details_options_launch_details_platform_config_percentage_of_cores_enabled
        #         }
        #         preemptible_instance_config {

        #             #Optional
        #             preemption_action {
        #                 #Required
        #                 type = var.instance_configuration_instance_details_options_launch_details_preemptible_instance_config_preemption_action_type

        #                 #Optional
        #                 preserve_boot_volume = var.instance_configuration_instance_details_options_launch_details_preemptible_instance_config_preemption_action_preserve_boot_volume
        #             }
        #         }
        #         preferred_maintenance_action = var.instance_configuration_instance_details_options_launch_details_preferred_maintenance_action
        #         shape = var.instance_configuration_instance_details_options_launch_details_shape
        #         shape_config {

        #             #Optional
        #             baseline_ocpu_utilization = var.instance_configuration_instance_details_options_launch_details_shape_config_baseline_ocpu_utilization
        #             memory_in_gbs = var.instance_configuration_instance_details_options_launch_details_shape_config_memory_in_gbs
        #             nvmes = var.instance_configuration_instance_details_options_launch_details_shape_config_nvmes
        #             ocpus = var.instance_configuration_instance_details_options_launch_details_shape_config_ocpus
        #             vcpus = var.instance_configuration_instance_details_options_launch_details_shape_config_vcpus
        #         }
        #         source_details {
        #             #Required
        #             source_type = var.instance_configuration_instance_details_options_launch_details_source_details_source_type

        #             #Optional
        #             boot_volume_id = oci_core_boot_volume.test_boot_volume.id
        #             boot_volume_size_in_gbs = var.instance_configuration_instance_details_options_launch_details_source_details_boot_volume_size_in_gbs
        #             boot_volume_vpus_per_gb = var.instance_configuration_instance_details_options_launch_details_source_details_boot_volume_vpus_per_gb
        #             image_id = oci_core_image.test_image.id
        #             instance_source_image_filter_details {

        #                 #Optional
        #                 compartment_id = var.compartment_id
        #                 defined_tags_filter = var.instance_configuration_instance_details_options_launch_details_source_details_instance_source_image_filter_details_defined_tags_filter
        #                 operating_system = var.instance_configuration_instance_details_options_launch_details_source_details_instance_source_image_filter_details_operating_system
        #                 operating_system_version = var.instance_configuration_instance_details_options_launch_details_source_details_instance_source_image_filter_details_operating_system_version
        #             }
        #         }
        #     }
        #     secondary_vnics {

        #         #Optional
        #         create_vnic_details {

        #             #Optional
        #             assign_ipv6ip = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_assign_ipv6ip
        #             assign_private_dns_record = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_assign_private_dns_record
        #             assign_public_ip = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_assign_public_ip
        #             defined_tags = {"Operations.CostCenter"= "42"}
        #             display_name = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_display_name
        #             freeform_tags = {"Department"= "Finance"}
        #             hostname_label = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_hostname_label
        #             ipv6address_ipv6subnet_cidr_pair_details {

        #                 #Optional
        #                 ipv6address = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6address
        #                 ipv6subnet_cidr = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_ipv6address_ipv6subnet_cidr_pair_details_ipv6subnet_cidr
        #             }
        #             nsg_ids = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_nsg_ids
        #             private_ip = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_private_ip
        #             skip_source_dest_check = var.instance_configuration_instance_details_options_secondary_vnics_create_vnic_details_skip_source_dest_check
        #             subnet_id = oci_core_subnet.test_subnet.id
        #         }
        #         display_name = var.instance_configuration_instance_details_options_secondary_vnics_display_name
        #         nic_index = var.instance_configuration_instance_details_options_secondary_vnics_nic_index
        #     }
        # }
        # secondary_vnics {

        #     #Optional
        #     create_vnic_details {

        #         #Optional
        #         assign_private_dns_record = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_assign_private_dns_record
        #         assign_public_ip = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_assign_public_ip
        #         defined_tags = {"Operations.CostCenter"= "42"}
        #         display_name = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_display_name
        #         freeform_tags = {"Department"= "Finance"}
        #         hostname_label = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_hostname_label
        #         nsg_ids = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_nsg_ids
        #         private_ip = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_private_ip
        #         skip_source_dest_check = var.instance_configuration_instance_details_secondary_vnics_create_vnic_details_skip_source_dest_check
        #         subnet_id = oci_core_subnet.test_subnet.id
        #     }
        #     display_name = var.instance_configuration_instance_details_secondary_vnics_display_name
        #     nic_index = var.instance_configuration_instance_details_secondary_vnics_nic_index
        # }
    ### }
}