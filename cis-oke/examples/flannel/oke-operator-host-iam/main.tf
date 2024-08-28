module "operator_dynamic_group" {
  source = "github.com/oracle-quickstart/terraform-oci-cis-landing-zone-iam//dynamic-groups?ref=v0.2.3"
  tenancy_ocid = var.tenancy_ocid
  dynamic_groups_configuration = var.dynamic_groups_configuration
}

module "operator_policy" {
  source = "github.com/oracle-quickstart/terraform-oci-cis-landing-zone-iam//policies?ref=v0.2.3"
  tenancy_ocid = var.tenancy_ocid
  policies_configuration = var.policies_configuration
}  