# Initial feasibility assessment

> Implementation update: the official-only wrapper is now implemented on
> `feat/cis-oke-input-contract`. See [README.md](README.md) and
> [MIGRATION.md](MIGRATION.md) for the actual module layout, blocked upstream
> combinations and verification status. The text below records earlier planning;
> speculative root-module addresses are superseded by the migration guide.

2026-09-18. Source-level assessment of the commits recorded in
[REFACTORING_PLAN.md](REFACTORING_PLAN.md). No infrastructure changes.

Follow-up: the maintainer requires new flexible inputs that preserve all prior
use cases after conversion. A [typed contract prototype](design/input-contract/README.md)
now implements the upstream-style worker schema and has passed 19 plan-based cases on Terraform
1.5.7. This verifies the input surface only; upstream provisioning gaps below
remain implementation work, not reasons to restrict the public schema.

## Verdict

The refactoring is feasible in principle, but upstream v5.5.1 is not a drop-in
replacement for all existing CIS OKE behavior. Most input translation is routine;
several provisioning and update differences require upstream work before full
parity can be claimed. Proceed with contract design and a bounded prototype on a
feature branch. Do not begin a broad resource replacement before resolving the
gaps below.

Preserve the CIS OKE policy, validation, defaults and dependency-resolution layer.
Change its public inputs deliberately where that improves clarity, then delegate
provisioning to upstream. A major release permits input migration, but changing
an input name must not silently change the policy it represents.

## Proposed contract direction

Retain the two top-level envelopes `clusters_configuration` and
`workers_configuration`, and the three dependency maps. They fit separate
control-plane and worker deployments and reduce orchestrator integration churn.
The latest maintainer direction replaces the earlier separate-map proposal with
one typed `worker_pools` map using upstream-style flattened fields and a
managed/virtual `mode`. Shared `worker_pool_defaults` supplies the same fields;
individual pool values override them. Resolve old managed/virtual key collisions
explicitly during migration.

The following table records earlier proposals. The concrete
[contract mapping](design/input-contract/README.md) supersedes its worker field
names and nesting; the capability and validation requirements remain.

| Current field | Proposed public field | Conversion / rationale |
| --- | --- | --- |
| `is_enhanced` | `cluster_type = "basic" / "enhanced"` | Boolean becomes an explicit enum; retain the legacy default `basic` |
| `cni_type = "native" / "flannel"` | Retain these public values | Translate `native` to upstream `npn` internally; no customer rename needed |
| Pool `cluster_id` accepting either a key or OCID | `cluster_ref = { key = "C" }` or `{ id = "ocid...", compartment_id = "..." }` | Exactly one key/id; distinguish target-cluster lookup compartment from pool compartment |
| `node_config_details.image` accepting an OCID or OS version | `node_config_details.image = { id = "..." }` or `{ oracle_linux_version = "8.8" }` | Explicit selector, mutually exclusive; omission retains existing selection logic |
| `ssh_public_key_path` accepting file path or key text | Separate `ssh_public_key` and `ssh_public_key_path` | Reject both together; converter preserves the currently effective value |
| `flex_shape_settings.memory`, `ocpus` | `memory_in_gbs`, `ocpus` | Make memory units explicit; preserve 16 GB / 1 OCPU fallback |
| `boot_volume_size` | `boot_volume_size_in_gbs` | Explicit units, same 60 GB default |
| `node_eviction.grace_duration` | `grace_duration_seconds` | Same seconds and 3600-second default; do not inherit upstream's 300 seconds |
| `node_cycling.enable_cycling`, `max_surge`, `max_unavailable` | Keep initially | Already a useful typed contract; preserve enhanced-cluster gating |
| Optional `size` | Keep optional until null behavior is characterized | Do not introduce upstream's size default without recording the difference |
| `name`, pool/node tags, placement list | Preserve separate fields | Existing expressiveness is required; upstream limitations are not a reason to collapse these fields |
| Compartment, network and KMS key-or-OCID references | Keep initially, except explicit cluster reference above | They are a consistent Landing Zone dependency convention |

These are design proposals, not implemented variable names. Avoid renaming every
field to resemble upstream. No unrestricted `upstream_options` escape hatch: it
would undermine the validated contract and resource ownership boundary.

For defaults, explicitly specify precedence: per-resource value, configuration
default, existing module fallback. The current per-resource `cis_level` default
of `"1"` can hide `default_cis_level`; capture this as a regression and resolve it
as a documented correction, not an unnoticed change. Retain existing automatic
version/image selection for new deployments; the migration converter should
materialize the deployed choices to avoid an incidental upgrade.

Illustrative conversion of one managed pool, omitting unchanged surrounding
fields:

```hcl
# Old fragment
cluster_id = "CLUSTER-A"
node_config_details = {
  node_shape = "VM.Standard.E4.Flex"
  image = "8.8"
  boot_volume_size = 60
  node_eviction = { grace_duration = 3600, force_delete = false }
}

# Proposed new fragment
cluster_ref = { key = "CLUSTER-A" }
node_config_details = {
  node_shape = "VM.Standard.E4.Flex"
  image = { oracle_linux_version = "8.8" }
  boot_volume_size_in_gbs = 60
  node_eviction = { grace_duration_seconds = 3600, force_delete = false }
}
```

The converter must preserve resource keys, report ambiguity and unsupported
fields, and produce a field-by-field change report. It must not guess file
contents or current image/version choices from a configuration alone. HCL users
need a manual mapping guide; JSON/YAML users can also receive converted documents.

## Preserve all current blocking validations

The source contains 12 lifecycle preconditions. Retain their policy intent and
resource-specific diagnostics when their owning OCI resource blocks disappear.

| ID | Current source | Requirement retained |
| --- | --- | --- |
| C1 | `oke.tf` | CIS level 2 requires a customer-managed secret-encryption key |
| C2 | `oke.tf` | Requested Kubernetes version is supported by OCI |
| C3 | `oke.tf` | One configured cluster per VCN |
| C4 | `oke.tf` | Accepted CNI values are native or flannel |
| C5 | `oke.tf` | Public endpoint cannot use a subnet prohibiting internet ingress |
| M1 | `nodepools.tf` | CIS level 2 requires a worker volume encryption key |
| M2 | `nodepools.tf` | Worker version is supported, not newer than the cluster, and no more than two versions behind under the existing policy |
| M3 | `nodepools.tf` | Requested image OCID/OS version passes the existing OKE image eligibility checks |
| M4 | `nodepools.tf` | Explicit/default worker compartment required for an external cluster |
| V1 | `virtualnodepools.tf` | Virtual pools require an enhanced cluster |
| V2 | `virtualnodepools.tf` | Explicit/default worker compartment required for an external cluster |
| V3 | `virtualnodepools.tf` | Virtual pools require native CNI |

Retain the surrounding logic too: key resolution, tag fallback, node version
inheritance, image lookup, AD/FD conversion, max-pod handling, SSH path-or-content
resolution during conversion, OIDC gating, and enhanced-only cycling. Existing
logic currently suppresses some options instead of rejecting them; inventory that
behavior and document any proposed stricter validation separately.

Proposed validation placement: variable validations for self-contained input
rules, existing OCI data lookups for live facts, and dedicated wrapper validation
guards with lifecycle preconditions for cross-input policy. Terraform 1.5 has no
module-call lifecycle preconditions. A built-in `terraform_data` guard is a viable
candidate, with the upstream call consuming validated configuration and explicit
dependency edges. It adds helper state but no OCI infrastructure. It requires
Terraform 1.4+, so retaining 1.3 support would need a different guard mechanism.

Keep separate control-plane and worker validation stages. Do not make a cluster
depend on worker checks that depend on the cluster's computed ID: that creates a
cycle. Known invalid input must fail at plan; facts unknown until creation may
defer checks until apply, before the dependent pool is provisioned. Verify this
ordering in the prototype. Avoid broad dependencies that defer all upstream data
lookups unnecessarily.

References: [Terraform 1.5 terraform_data](https://developer.hashicorp.com/terraform/language/v1.5.x/resources/terraform-data)
and [lifecycle preconditions](https://developer.hashicorp.com/terraform/language/v1.5.x/meta-arguments/lifecycle).

## Confirmed integration gaps

Evidence below refers to files in upstream commit
`627560db54a123e973cd1f18c933ee6d744274ce`.

| Finding | Evidence | Recommended treatment |
| --- | --- | --- |
| Pool map key is also its display name | `modules/workers/nodepools.tf`: `name = each.key`; virtual equivalent uses `display_name = each.key` | Upstream optional per-pool name; preserve stable LZ keys separately. Keying by names would introduce collisions and rename-related state changes |
| Managed pools share one SSH public key per workers-module instance | `modules/workers/nodepools.tf`: `ssh_public_key = var.ssh_public_key` | Upstream per-pool override. One module per pool is a possible workaround, but adds repeated root-module machinery |
| Pool and node tags share the same values | Managed resource assigns `each.value.defined_tags/freeform_tags` at both levels; virtual resource does the same | Upstream separate node-tag overrides; preserve both current tag contracts |
| Placement loses per-entry distinctions | Worker resource iterates ADs and applies the same FD/preemption settings to each | Upstream explicit placement override list; do not flatten heterogeneous placements into a cross-product |
| Tag/name/placement updates can be ignored | Cluster/workers lifecycle `ignore_changes` declarations | Upstream-supported lifecycle design is needed for update parity. Parent wrapper cannot override a child's lifecycle |
| Cluster LB subnet list becomes one required subnet | `modules/cluster/cluster.tf` uses `compact([var.service_lb_subnet_id])` and non-null precondition | Upstream plural/optional input while preserving old upstream input compatibility |
| Legacy dashboard/Tiller/PSP inputs absent | `modules/cluster/cluster.tf` options | Establish which supported customer combinations remain valid; upstream support or explicit maintainer-approved deprecation |
| Cluster resource object is not exported | `modules/cluster/outputs.tf` exposes ID, endpoints and OIDC endpoint | Add upstream full object output, or assess a read-back adapter against every legacy output field |
| Upstream injects tags, labels and metadata | `modules/workers/locals.tf`, `nodepools.tf` | Explicitly reconcile injected values; disable default cloud-init and preserve user data. Additional values are observable changes |
| Eviction defaults differ | Worker defaults: 300 seconds, force-delete/action true | Explicitly carry legacy 3600 seconds and force-delete false; investigate newly emitted force-action field |
| Virtual taints change representation | Legacy list with `key`; upstream dynamic block uses `taints.key` | Translate to keyed map only if unique; duplicate keys must be examined, not silently collapsed |
| Root OCI version understates effective minimum | Root `>= 8.14.0`; cluster/workers children `>= 8.19.0` | Test effective provider set with Terraform 1.5.7 and existing orchestrator provider constraints |

These findings mean that an unmodified upstream release cannot currently be
declared fully equivalent. Input redesign handles ambiguity and naming; it cannot
restore an unsupported resource field or override upstream lifecycle semantics.

## Module composition recommendation

Keep one logical adapter per cluster, preserving existing cluster keys. Prefer
the upstream root module after the parity gaps are addressed, because its public
interface includes existing-cluster support and the documented ownership toggles.
Prototype the combined path first; compare split control-plane and worker-only
calls if validation dependencies require it. Never allow a worker-only call to
claim ownership of an existing control plane.

Do not select one module per pool solely to hide the SSH-key gap: it does not fix
separate tags, placements or ignored updates and increases repeated discovery.
Direct cluster/workers submodules reduce dependency overhead, but inherit these
same resource-level gaps. Choose that option only with an explicit maintained
submodule contract and evidence from the prototype.

Use caller-known keys for module iteration and a deterministic managed/virtual
pool namespace internally. Resolve external-cluster configuration from a stable
reference key if its OCID is unknown during planning. Do not group pools by an
apply-time-computed OCID. Region/provider configuration is per wrapper invocation;
multi-region support is not a new feature of this refactor.

## Two independent customer migrations

1. **Configuration migration:** translate variables, resolve ambiguous inputs,
   materialize effective defaults where needed, preserve dependency references,
   and review all behavior differences. This happens before generating the new
   desired configuration.
2. **State migration:** map the old resources to their new upstream addresses
   using the selected module layout and stable keys. Generate explicit `moved`
   declarations or reviewed `state mv` commands. Moves do not translate inputs,
   restore omitted options, or neutralize replacement-causing differences.

Deliver both from one inventory, with separate outputs: converted configuration,
change report, address manifest and move declarations. Never mutate customer state
as part of conversion. The candidate addresses in REFACTORING_PLAN.md remain
illustrative until module composition is proven.

## Bounded implementation plan and decision gates

| Stage | Deliverable | Completion gate |
| --- | --- | --- |
| 1. Contract | Revised typed schema, field mapping, complete logic/validation inventory | All 12 checks and surrounding behavior accounted for; no silent field loss |
| 2. Prototype | Feature-branch cluster-only, combined and worker-only roots using pinned upstream | Terraform 1.5.7 init/validate/plan; prove dependencies and ownership controls |
| 3. Upstream parity | Small contributions for names/SSH/tags/placements/LB/output/lifecycle gaps | Required behavior available in a pinned revision; no permanent local resource fork |
| 4. Adapter | Normalization, validation guards, upstream calls and output mapping | Positive/negative cases, multiple clusters, managed/virtual key collisions |
| 5. Migration | Input converter/guide plus generated explicit address moves | Existing fixture OCIDs unchanged; no unapproved replacement or node cycling |
| 6. Release | Major-release notes, examples and orchestrator integration guidance | Stable post-migration plans and update-behavior tests on the supported matrix |

The critical path is upstream parity and lifecycle behavior, followed by migration
qualification. Basic translation is lower risk. Do not schedule the major release
based only on successfully creating a new cluster.

Initial verification was source inspection and runtime discovery. A subsequent
standalone input-contract prototype passed init, validate and 19 plan-based cases
under Terraform 1.5.7. The installed default remains 1.16.3. No upstream OCI plan
or migration rehearsal has been performed; those remain explicit gates.
