# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#--------------------------------------------------------------------------------------------------------------------------------------
# 1. Rename this file to <project-name>.auto.tfvars, where <project-name> is a name of your choice.
# 2. Provide values for "Tenancy Connectivity Variables".
#--------------------------------------------------------------------------------------------------------------------------------------

#---------------------------------------
# Tenancy Connectivity Variables
#---------------------------------------

# tenancy_ocid         = "<tenancy OCID>"            # Get this from OCI Console (after logging in, go to top-right-most menu item and click option "Tenancy: <your tenancy name>").
# user_ocid            = "<user OCID>"               # Get this from OCI Console (after logging in, go to top-right-most menu item and click option "My profile").
# fingerprint          = "<PEM key fingerprint>"     # The fingerprint can be gathered from your user account. In the "My profile page, click "API keys" on the menu in left hand side).
# private_key_path     = "<path to the private key>" # This is the full path on your local system to the API signing private key.
# private_key_password = ""                          # This is the password that protects the private key, if any.
# region               = "<your tenancy region>"     # This is your region, where all other events are created. It can be the same as home_region.

tenancy_ocid         = "ocid1.tenancy.oc1..aaaaaaaa3pbmdv223ttwv4wjvmn4jvcw4gxc3skym74itutnnoisg5zrbnuq" 
user_ocid            = "ocid1.user.oc1..aaaaaaaaw3evukcrc5a72revdr6gj4bfay6ilsyuwu75fmbx3t6xw2qxa5pa" #stack-compute-admin-user
fingerprint          = "ec:12:aa:28:1f:47:99:c2:1d:86:74:f6:d7:b3:c8:cf"  
private_key_path     = "../stack-compute-admin-user_cislzground.pem"
private_key_password = ""  
region               = "us-ashburn-1"

filter_string = "CIS"
