# CIS OKE: Landing Zone wrapper for the official OKE module

The `cis-oke/` directory implements the 0.3.0 refactor using only official upstream
code. It is a release candidate for new deployments.
Cluster and worker provisioning uses the official OKE root module
pinned to release `v5.5.2` (the latest official release verified
on 2026-10-14; commit `cbf5c71e33b0d804befac54b7dbb1d83a56ea090`).
There is no vendored snapshot, patched provider, or duplicate OCI resource
implementation in the wrapper.

The Landing Zone layer retains typed configuration, shared worker defaults,
reference resolution, CIS policy validation and keyed outputs. Root-module composition explicitly disables VCN, subnet, NSG, IAM, bastion,
operator and extension creation. Those resources must already be managed elsewhere.

## Configuration

`cluster_configuration` is a flat object for exactly one enhanced cluster:
`name`, `compartment_id`, optional `cis_level` (default 1), `networking`, tags and
other cluster options. There is no cluster map, identity key or cluster reference.
`workers_configuration` contains shared `default_*` values and a `worker_pools`
map. Every pool implicitly belongs to this cluster and inherits its compartment
and CIS level. Cluster-only calls may omit workers; workers without a cluster and
external-cluster calls are rejected. Null cluster input permits a disabled/no-op
invocation, but cannot be combined with nonempty worker pools.

```hcl
tenancy_id = "ocid1.tenancy.oc1..<tenancy-id>"
cluster_configuration = {
  name = "platform"
  compartment_id = "COMPARTMENT-KEY"
  networking = {
    vcn_id = "VCN-KEY"
    api_endpoint_subnet_id = "API-SUBNET-KEY"
    service_lb_subnet_ids = ["LB-SUBNET-KEY"]
  }
}
```

The [example catalog](examples/README.md) includes current 0.3.0 and pinned legacy examples.
Use the [single-cluster example](examples/upstream-wrapper) or the
[multi-cluster for_each caller example](examples/multiple-clusters). Caller map
keys determine module-instance identities; they are not CIS OKE input fields.
The orchestrator integration is a separate change and is not included here.

```hcl
workers_configuration = {
  default_shape = "VM.Standard.E4.Flex"
  default_size = 3
  default_ocpus = 2
  default_memory = 32
  default_subnet_id = "WORKER-SUBNET-KEY"
  default_pod_subnet_id = "POD-SUBNET-KEY"
  worker_pools = {
    general = {}
    batch = { size = 5, ocpus = 4 }
  }
}
```

Pools use upstream-style names and `mode = "node-pool"` (default) or
`"virtual-node-pool"`. Only these managed and virtual modes are supported in this
release; other upstream worker modes are rejected. Pools cannot override cluster,
compartment or CIS level. Logical
compartment/network/KMS references resolve through the existing dependency maps;
OCIDs can be supplied directly. Region selection remains the caller's OCI provider
configuration, not a per-pool setting.

Precedence is **shared defaults < pool override**. Defaults are declared in
`variables.tf`, not in an internal fallback map. Null/omitted inheritable pool
fields use the shared values; false and zero remain explicit values. Supported maps merge by
key (local values win), and supported set-like lists combine and deduplicate.
Empty maps/lists retain inherited entries unless explicitly overridden.

Each pool can name collections in `override_defaults`. Named fields
use only their local value: `{}` clears a map and `[]` clears a list. Every named
field must be supported and explicitly non-null; misspellings, scalar fields and
missing local values are rejected. This does not remove module/upstream tracking
tags or labels, and all CIS/upstream constraints still apply.

| Object | Supported `override_defaults` entries |
| --- | --- |
| Worker pool | `defined_tags`, `freeform_tags`, `node_defined_tags`, `node_freeform_tags`, `node_labels`, `nsg_ids`, `pod_nsg_ids` |

For example, a pool can add labels but completely replace inherited NSGs:

```hcl
batch = {
  node_labels       = { workload = "batch" }
  nsg_ids           = ["BATCH-NSG"]
  override_defaults = ["nsg_ids"]
}
```

Nested cluster collection names use paths relative to the cluster object. Worker
collection names are relative to the pool. NSG and signing-key references are
resolved after merging/replacement and deduplicated again by OCID. Replaced
references do not need dependency entries. Other lists and structured settings
retain their field-specific behavior; placement and metadata remain pool-only.
`taints` is virtual-only. Workers inherit the cluster’s CIS level; level `"2"`
requires `volume_kms_key_id` for managed workers.

Only general worker settings are shared defaults. Names, image IDs, placement,
capacity reservations, metadata, eviction, cycling, preemption and taints are per
pool. `max_pods_per_node` is per pool and defaults to 31. SSH accepts key content
(`default_ssh_public_key` or pool `ssh_public_key`), not a filesystem-path input;
callers may pass `file("path/to/key.pub")` themselves.

The shared input defaults are `default_mode = "node-pool"`, `default_ocpus = 1`,
`default_memory = 16`, `default_boot_volume_size = 60`, `default_os = "Oracle Linux"`,
`default_os_version = "9"`, and `default_pv_transit_encryption = false`.
Override these globals to set your baseline, then override individual pools as needed.
Shape, size and subnet have no built-in default and must resolve from global or
pool inputs. Terraform applies declared non-null defaults to omitted or null global
values; null pool overrides inherit those effective globals.

Pool-only defaults are also explicit in the input schema: `placement_ads = [1]`,
`eviction_grace_duration = 3600`, `force_node_delete = false`,
`node_cycling_enabled = false`, `node_cycling_max_surge = "1"`, and
`node_cycling_max_unavailable = "0"`. Preemptible nodes are disabled by default.

Memory/boot-volume sizes are GB; eviction duration is seconds.

The full typed schema is in [variables.tf](variables.tf). Normalization is in
[modules/configuration](modules/configuration). A [current example](examples/upstream-wrapper)
shows the complete module call. Legacy examples remain in
[examples/legacy](examples/legacy/). See [module selection](../OKE_VERSIONS.md)
before changing an existing deployment’s source path.

Clusters default to `cluster_type = "enhanced"` and `cni_type = "native"`
(VCN-native CNI). Native CNI requires `pods_cidr` to be omitted (or null); pod
addresses come from the pod subnet. Only enhanced clusters are supported; explicit `basic` is rejected. Flannel remains supported on enhanced clusters.

Managed pools always set `node_metadata.areLegacyImdsEndpointsDisabled = "true"`,
requiring IMDSv2-only access on new managed nodes. It cannot be disabled by input;
conflicting metadata is rejected. Existing nodes require replacement/cycling for
this pool setting to take effect; updating the pool alone does not retrofit them.
Use images and bootstrap scripts compatible with IMDSv2. See
[Oracle's managed-node IMDS guidance](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengconfiguringimds.htm).

Cluster API endpoints are always private. There is no public-endpoint input.
Deprecated Dashboard, Tiller and pod-security-policy switches are no longer exposed.

Cluster tags are explicit `defined_tags`/`freeform_tags`. PV and service-LB tags
are explicit maps under `options.persistent_volume_config` and
`options.service_lb_config`. There are no cluster-level `default_*` fields or
`override_defaults`; compose shared values in the caller if needed. Module and
upstream tracking metadata is still added separately.

`networking.api_endpoint_nsg_ids` is the complete endpoint NSG list. It resolves
dependency keys/OCIDs and deduplicates resolved OCIDs; `[]` requests no endpoint
NSGs. Cluster image-signing keys are also explicit and deduplicated.

## Provisioning and validation

Each cluster calls the official OKE root module, with its pools supplied together.
Upstream owns image discovery, architecture/GPU/version selection, and AD-number
translation. The wrapper supplies numeric `placement_ads` and normalized inputs;
it does not query ADs or implement image selection. Cluster-only configurations
remain supported. Pool names must be unique within a cluster because upstream
uses them as resource keys. Renaming a pool requires address-move and plan review.

The wrapper retains the applicable original validation policies: cluster and managed
worker CIS level-2 keys, supported cluster version,
CNI values, supported worker version/skew,
inherited cluster compartment/CIS policy, and enhanced/native
requirements for virtual pools. Configuration checks occur before provisioning;
checks requiring facts from a newly created cluster can defer to apply before
creating its workers. The helper `terraform_data` resources enforce these gates.

Version skew is compared numerically by major/minor, avoiding dependence on OCI
list ordering. Upstream handles image selection and its failure diagnostics.
The default OS is Oracle Linux 9; image type is inferred from a pool image ID.
An explicit image ID is passed to upstream as custom, without requiring membership
in the OKE catalog.

## Tenancy and newly created compartments

Supply the required top-level `tenancy_id` as a tenancy OCID known at plan time,
independently of the workload compartment. Upstream uses it to discover regional
availability domains. A compartment dependency ID may be unknown until apply, so
compartment and OKE resources can be created in a single plan. Provider
authentication settings do not automatically populate module inputs.

## Explicit upstream limitations

The maintainer selected **official upstream only**. The following cases are blocked by wrapper validation
pending official upstream support:

- Missing or multiple service load-balancer subnets; upstream needs exactly one.
- Different tags on a pool and its nodes.
- Heterogeneous per-AD settings: the flat upstream schema cannot express
  them. Duplicate AD entries are rejected.
- Duplicate virtual taint keys.
- Explicit virtual fault-domain placement. The pinned upstream lookup uses AD
  names against a numerically keyed map and falls back to `FD-*` rather than OCI's
  `FAULT-DOMAIN-*`; passing the requested FDs would be silently lost. Automatic FD
  placement works, but is not a silent substitute for an existing placement.
- Empty virtual pod NSG lists; upstream's `coalescelist` path either inherits
  worker NSGs or errors when both lists are empty.
- Different managed-pool SSH keys or transit-encryption settings within one
  cluster: v5.5.2's effective worker implementation reads the global SSH key and
  recomputes transit encryption from the global flag. Equal per-pool values are
  forwarded through those globals; virtual pools are excluded from this check.
- Duplicate pool names within a cluster.
- A nonempty set of pools whose total size is zero: upstream suppresses detailed
  pool outputs in that case, so the wrapper cannot preserve its output contract.
- An omitted pool size; specify a pool size or a global default size.

Upstream ignores some subsequent changes to cluster defined tags/network CIDRs
and pool names/tags/placements. Terraform alone may therefore report a successful
no-op for a desired change. Review both the requested configuration and the saved
plan before updates: a successful plan does not prove that ignored fields will
change. The wrapper cannot override upstream lifecycle blocks. Updating these
ignored fields is not supported by this wrapper.

Upstream also adds tracking tags, labels and metadata, including state/pool
identity. These are observable differences to review. Upstream default cloud-init
scripts are enabled by default for managed pools. Set
`workers_configuration.default_disable_default_cloud_init = true` to disable them
globally. A pool's `disable_default_cloud_init` overrides that setting; explicit
`false` re-enables the scripts, and null/omitted inherits the global value.

Use `workers_configuration.default_cloud_init` for custom MIME parts shared by
all managed pools. Its part schema is identical to pool `cloud_init`. An omitted
or null pool value inherits global parts. A supplied pool value replaces the entire
global configuration; `cloud_init = []` clears it. No concatenation or deduplication
is performed, and `cloud_init` is not supported in `override_defaults`. Virtual
pools do not inherit these boot scripts.
The `disable_default_cloud_init` switches only affect upstream's built-in scripts,
not your global or pool custom parts.

Managed pools can also supply `cloud_init`, a list of upstream-style MIME parts
(`content`, `content_type`, optional `filename` and `merge_type`). Custom parts are
included alongside enabled defaults and remain included when defaults are disabled.
The upstream module renders and encodes these parts into node user data.
Alternatively, use base64 `node_metadata.user_data` with default scripts disabled
and no `cloud_init` parts; validation prevents it from silently replacing enabled
scripts. With defaults disabled and neither input supplied, node user data stays
empty and an internal no-op part satisfies the cloudinit provider.

`merge_type` is cloud-init's policy for merging cloud-config YAML from MIME parts;
it is unrelated to Terraform's `override_defaults`. The upstream-compatible default
`list(append)+dict(no_replace,recurse_list)+str(append)` appends lists, preserves
existing dictionary values while recursively merging lists, and enables string
appending. It does not merge shell-script text into a single script. See the
[cloud-init merge documentation](https://docs.cloud-init.io/en/latest/reference/merging.html).
Cloud-init changes affect newly booted nodes; review node replacement/cycling for
existing pools.

### Managed-pool GVA and cloud-init

`gva_secondary_vnics` is a per-pool map exposing the supported IPv4 fields of
the pinned upstream VNIC profile. IPv6 configuration is not supported.
Each profile requires `subnet_id` (a Landing Zone dependency key or OCID);
`nsg_ids` also resolves keys/OCIDs and deduplicates. Profiles are explicit pool
configuration, without new global defaults or `override_defaults` paths. Their
NSG lists are independent of ordinary pod NSGs. Omitted profile tags inherit pool
tags through upstream; explicit tag maps replace them.

```hcl
worker_pools = {
  APP = {
    cloud_init = [{
      content_type = "text/cloud-config"
      filename     = "custom.yaml"
      content      = "#cloud-config\nwrite_files: []\n"
    }]
    gva_secondary_vnics = {
      data = {
        subnet_id             = "PODS-DATA"
        nsg_ids               = ["PODS-DATA-NSG"]
        application_resources = ["example.com/data"] # Optional; omit for NAD selection.
        ip_count              = 32
        nic_index             = 0
      }
    }
  }
}
```

GVA requires managed pools with native CNI. Each `ip_count` defaults to 16 and
must be a power of two from 1 to 256; their sum per node cannot exceed 256.
The ordinary `pod_subnet_id` is not required for a GVA pool: upstream uses the
secondary profiles and omits ordinary pod subnet/NSG/max-pod settings in that
pool's CNI options. Shape VNIC limits, subnet address capacity,
and required network/IAM configuration remain deployment prerequisites owned by
the Landing Zone. The wrapper does not install Multus or create Kubernetes network
attachments. See [OCI GVA documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengAttaching_Multiple_VNICs.htm).

The schema also exposes upstream's optional `display_name`,
`skip_source_dest_check`, and VNIC `defined_tags`/`freeform_tags`.
GVA public IP assignment is always disabled and cannot be configured;
source/destination-check skipping defaults to true, matching upstream.
Upstream also ignores subsequent GVA defined-tag changes.

## Outputs and dependencies

`cluster` returns the single cluster object. `node_pools`, `virtual_node_pools`
and `nodes` remain keyed by pool identity. The old `clusters` map output is removed. Cluster attributes are read back using the OCI cluster data source
because upstream exports only selected attributes. Pool objects come from upstream
and include OCI attributes plus upstream configuration fields. This is not a claim
of byte-identical serialized resource objects; downstream consumers must be checked
against the fields they actually use. Legacy `nodes` remains available regardless
of `enable_output`; the other three outputs honor that flag.

Requires Terraform >=1.4 (for built-in validation guards) and OCI provider >=8.19,
<9. Tested locally with **Terraform 1.5.7, OCI 8.29.0, cloudinit 2.4.1**. Cloudinit
is required by the official workers submodule even though boot scripts are
disabled. The root module also loads Helm, null, random, time and transitive HTTP provider
dependencies, even with ancillary features disabled. Its `oci.home` alias is
mapped internally to the supplied OCI provider; IAM writes are disabled.
For Terraform 1.5, pass `providers = { oci = oci }` explicitly when calling the
wrapper, as shown in the example. It
creates an auxiliary random state-ID resource. Callers should lock tested provider
versions in their root configuration.

Read-only permissions are needed for cluster options, clusters/kubeconfigs, node-pool
options, VCNs, services, availability/fault domains, images and shapes, in addition to OKE creation
permissions. No deployment credentials are stored in this repository.

## Verification and release status

Use Terraform 1.5.7 to validate the module against the pinned upstream release:

```sh
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

For functional validation, configure one of the [current examples](examples/README.md)
and review its Terraform plan against the intended OCI environment before applying.
Configuration validation alone does not verify live OCI behavior.

### Upgrading existing deployments

Existing deployments should remain pinned to their tested pre-0.3.0 Git tag,
such as `v0.2.9`. Version 0.3.0 is for new deployments; it changes inputs, outputs
and Terraform resource addresses. No in-place upgrade procedure, input converter
or state migration tooling is supplied. Changing only the Git ref is not a
supported upgrade, and a new module call must not manage an existing cluster.

Bare-metal (`BM.*`) shapes cannot enable `pv_transit_encryption`. This is a blocking
validation after global defaults and pool overrides are resolved. Use a supported
VM shape or disable in-transit encryption for the BM pool.
