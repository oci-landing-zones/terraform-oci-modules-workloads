# OCI Compute & Storage Module - Compute instances and Block volumes with External Dependencies Example

## Introduction

This example shows how to deploy Compute instances and Block volumes in OCI using the [compute-storage module](../../README.md). It obtains its dependencies from OCI Object Storage objects, specified in *oci_compartments_dependency*, *oci_network_dependency*, *oci_kms_dependency* and *oci_compute_dependency* variables. 

As this example needs to read from an OCI Object Storage bucket, the following extra permissions are required for the executing user, in addition to the permissions required by the [compute-storage module](../..) itself.

```
allow group <group> to read objectstorage-namespaces in tenancy
allow group <group> to read buckets in compartment <bucket-compartment-name>
allow group <group> to read objects in compartment <bucket-compartment-name> where target.bucket.name = '<bucket-name>'
```
Note: *\<bucket-name\>* is the bucket specified in the dependency variables. *\<bucket-compartment-name\>* is *\<bucket-name\>*'s compartment.

The example deploys one Compute instance and two Block volumes with the following characteristics:
- The instance boot volume is encrypted with a customer managed key referred by *default_kms_key* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- Block volume "BV-1" is attached to and mounted on the locally managed instance "INSTANCE-1".
- Block volume "BV-1" is encrypted with an Oracle-managed key (per OCI default).
- Block volume "BV-1" is set to be backed up per Oracle-managed *bronze* backup policy.
- Block volume "BV-1" is replicated to another region, specified by *block_volume_replication_region* variable. Notice that the replicated block volumes are not destroyed upon *terraform destroy*. In order to destroy replicated block volumes, it is first necessary to manually terminate the replication. 
- Block volume "BV-2" is attached to and mounted on the externally managed instance "INSTANCE-2". The instance is brought over via *oci_compute_dependency* variable.
- Block volume "BV-2" is encrypted with customer managed key, specified by *kms_key_id* variable. The encryption key is brought over via *oci_kms_dependency* variable.
- Block volume "BV-2" is set to be backed up per Oracle-managed *gold* backup policy.
- Block volume "BV-2" is not replicated to another region, as block volumes encrypted with a customer-managed key cannot be cross-region replicated.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

Note that you must provide the image *name* and *publisher_name* for provisioning the Compute instance. Use the [marketplace-images module](../../../marketplace-images/) to obtain Marketplace images information. It will also return the image OCID that can be used instead of the image name/publisher pair.

## External Dependencies

The OCI Object Storage objects with external dependencies are expected to have structures like the following:
- **oci_compartments_dependency**
```
{
  "APP-CMP" : {
    "id" : "ocid1.compartment.oc1..aaaaaa...zrt"
  }
}
```
- **oci_network_dependency**
```
{
  "subnets" : {
    "APP-SUBNET" : {
      "id" : "ocid1.subnet.oc1.iad.aaaaaaaax...e7a"
    }
  },
  "network_security_groups" : {  
    "APP-NSG" : {
      "id" : "ocid1.networksecuritygroup.oc1.iad.aaaaaaaa...xlq"
    }
  }  
} 
```  
- **oci_kms_dependency**
```
{
	"APP-KEY": {
		"id": "ocid1.key.oc1.iad.ejsppeqvaafyi.abuwcl...yna"
	}
}
```
- **oci_compute_dependency**
```
{
	"INSTANCE-2": {
		"id": "ocid1.instance.oc1.iad.anuwc...ftq"
	}
}
```

Note the identifying references like *APP-CMP*, *APP-SUBNET*, *APP-NSG*, *APP-KEY* and *INSTANCE-2*. These are the values that should be used when replacing *\<REPLACE-BY-\*-REFERENCE\>* placeholders in *input.auto.tfvars.template*.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace *\<REPLACE-BY-\*\>* placeholders with appropriate values. 
   
Refer to [compute-storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```