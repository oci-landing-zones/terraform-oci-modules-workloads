# CIS OKE: Landing Zone wrapper for the official OKE module

This branch implements the major-release refactor using only official upstream
code. It is an implementation candidate, **not yet a release-qualified migration**.
Cluster and worker provisioning uses the official OKE root module
pinned to release `v5.5.1` (the latest official release verified
on 2026-09-18; commit `627560db54a123e973cd1f18c933ee6d744274ce`).
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

Precedence is **CIS fallback < shared defaults < pool override**. Null/omitted
fields inherit; false and zero remain explicit values. Supported maps merge by
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

Memory/boot-volume sizes are GB; eviction duration is seconds.

The full typed schema is in [variables.tf](variables.tf). Normalization is in
[modules/configuration](modules/configuration). The detailed [contract guide](design/input-contract/README.md)
explains fields and migration mappings. A [current example](examples/upstream-wrapper)
shows the complete module call. Older examples are explicitly pinned to the
pre-refactor module, so their legacy templates remain usable.

Clusters default to `cluster_type = "enhanced"` and `cni_type = "native"`
(VCN-native CNI). Native CNI requires `pods_cidr` to be omitted (or null); pod
addresses come from the pod subnet. Only enhanced clusters are supported; explicit `basic` is rejected. Flannel remains supported on enhanced clusters.

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
in the OKE catalog. Migration pins deployed images rather than selecting new ones.

## Explicit upstream limitations

The maintainer selected **official upstream only**. The following cases are blocked by wrapper validation or the migration converter
pending official upstream support:

- Missing or multiple service load-balancer subnets; upstream needs exactly one.
- Different tags on a pool and its nodes.
- Heterogeneous legacy per-AD settings: the flat upstream schema cannot express
  them, so the migration converter refuses those mappings. Duplicate AD entries
  are rejected.
- Duplicate virtual taint keys.
- Explicit virtual fault-domain placement. The pinned upstream lookup uses AD
  names against a numerically keyed map and falls back to `FD-*` rather than OCI's
  `FAULT-DOMAIN-*`; passing the requested FDs would be silently lost. Automatic FD
  placement works, but is not a silent substitute for an existing placement.
- Empty virtual pod NSG lists; upstream's `coalescelist` path either inherits
  worker NSGs or errors when both lists are empty.
- Different managed-pool SSH keys or transit-encryption settings within one
  cluster: v5.5.1's effective worker implementation reads the global SSH key and
  recomputes transit encryption from the global flag. Equal per-pool values are
  forwarded through those globals; virtual pools are excluded from this check.
- Duplicate pool names within a cluster.
- A nonempty set of pools whose total size is zero: upstream suppresses detailed
  pool outputs in that case, so the wrapper cannot preserve its output contract.
- An omitted pool size; migrate the deployed size instead of accepting a new
  zero-size default.

Upstream ignores some subsequent changes to cluster defined tags/network CIDRs
and pool names/tags/placements. Terraform alone may therefore report a successful
no-op for a desired change. **Run [check_plan.py](tools/check_plan.py) on every
saved migration/update plan before apply.** It rejects destructive OKE changes,
unexpected OCI resource ownership and detectable ignored tag/placement/CIDR
updates, including AD numbers that upstream filtered out as unavailable. It does not replace review of all provider diffs or qualify live OCI
migration. Unsupported ignored updates remain a release blocker; no claim is made
that the parent module can override an upstream lifecycle block.

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

`gva_secondary_vnics` is a per-pool map matching the pinned upstream VNIC profile
fields. Each profile requires `subnet_id` (a Landing Zone dependency key or OCID);
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
pool's CNI options. Shape VNIC limits, subnet address capacity, IPv6 subnet support
and required network/IAM configuration remain deployment prerequisites owned by
the Landing Zone. The wrapper does not install Multus or create Kubernetes network
attachments. See [OCI GVA documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengAttaching_Multiple_VNICs.htm).

The schema also exposes upstream's optional `display_name`, `assign_public_ip`,
`assign_ipv6ip`, `ipv6_addresses`, `ipv6_cidrs`, `skip_source_dest_check`, and VNIC
`defined_tags`/`freeform_tags`. Public IP and IPv6 assignment default to false;
source/destination-check skipping defaults to true, matching upstream.
The plan checker detects ignored GVA defined-tag changes as well as pool tags.

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

- Terraform 1.5.7 init/validate against the actual pinned upstream root module.
- Provider-free schema/default tests against the production configuration module.
- Offline plan scenarios use actual upstream resource code and actual OCI provider schemas,
  substituting only OCI data-source responses in a disposable test copy. They
  verify OKE-only resource ownership and positive/negative validation paths.
  AD/FD discovery uses real HTTP data sources against a loopback fixture, preserving
  deferred-read and unknown-key behavior. A negative control restores the former
  module-wide dependency and must reproduce the invalid-for_each error.
- Migration-tool and plan-checker tests verify mapping, ambiguity/orphan detection,
  preserved deployed selections and ignored/destructive update rejection.

```sh
terraform init -backend=false
terraform validate
TERRAFORM_BIN=/path/to/terraform-1.5.7 python3 design/input-contract/test_contract.py
TERRAFORM_BIN=/path/to/terraform-1.5.7 python3 tests/test_offline.py
python3 -m unittest discover -s tests -p test_migration.py
```

A read-only, empty-state OCI-backed plan succeeded on 2026-09-21 with Terraform
1.5.7 and OCI provider 8.29.0: enhanced/native CIS1, one E5 Flex managed pool,
existing compartment/network dependencies. This was repeated successfully with the
flat single-cluster API. It planned six additions (cluster,
node pool, three validation resources and upstream random state ID), with no
changes/deletions, and passed the plan checker. No targeting or staged apply was
used. No infrastructure apply, existing-customer state mutation or live migration
rehearsal has been performed. Live provider reconciliation, full historical-release coverage,
output-consumer compatibility and the upstream limitations above must be resolved
or explicitly scoped before publishing the major release. See [MIGRATION.md](MIGRATION.md).

Bare-metal (`BM.*`) shapes cannot enable `pv_transit_encryption`. This is a blocking
validation after global defaults and pool overrides are resolved. Use a supported
VM shape or disable in-transit encryption for the BM pool.
