# CIS OKE major-release refactoring plan

> Implementation update: the official-only wrapper is now implemented on
> `feat/cis-oke-input-contract`. See [README.md](README.md) and
> [MIGRATION.md](MIGRATION.md) for the actual module layout, blocked upstream
> combinations and verification status. The text below records earlier planning;
> speculative root-module addresses are superseded by the migration guide.

Status: proposed implementation plan; no Terraform implementation or customer
state has been changed. Implementation belongs on a separate branch.

The [initial feasibility assessment](FEASIBILITY.md) refines this plan following
the maintainer's clarification: preserve CIS OKE logic and validations while
allowing deliberate changes to input variables and provisioning. Its detailed
findings supersede the preliminary assumptions below where noted.

The [input-contract prototype](design/input-contract/README.md) now provides
concrete new variable definitions preserving previous use-case expressiveness.
It is on `feat/cis-oke-input-contract` and is not connected to provisioning. Its
Terraform 1.5.7 schema checks do not establish upstream runtime compatibility.
The latest iteration uses one upstream-style `worker_pools` map and shared
`worker_pool_defaults`, with executable per-pool overrides. This supersedes earlier
proposals for separate managed/virtual maps or nested node settings in the new
public contract. Preserve old use cases through explicit input conversion.

## Inspection baseline

Inspected on 2026-09-18:

- Landing Zone workloads commit `d7da10394a828f225b4ac19aa5ac14a9838b75ac`:
  `cis-oke/{variables,oke,nodepools,virtualnodepools,outputs,providers}.tf`.
- Upstream OKE commit `627560db54a123e973cd1f18c933ee6d744274ce`, also the
  `v5.5.1` tag: root module wiring, variables, and cluster/workers/network modules.
- Local orchestrator currently references workloads `v0.2.7`; do not assume that
  every customer is on the inspected workloads HEAD. Release fixtures must include
  supported historical releases.

Source references:

- [Upstream source at inspected commit](https://github.com/oracle-terraform-modules/terraform-oci-oke/tree/627560db54a123e973cd1f18c933ee6d744274ce)
- [Terraform 1.5 refactoring documentation](https://developer.hashicorp.com/terraform/language/v1.5.x/modules/develop/refactoring)
- [Moved block reference](https://developer.hashicorp.com/terraform/language/block/moved)

## Recommended architecture

Keep `cis-oke` as the public Landing Zone entrypoint. Retain the typed
`clusters_configuration`, `workers_configuration`, compartment/network/KMS
dependency envelopes and stable caller-supplied keys where practical, while
redesigning ambiguous nested input fields with explicit migration mappings.
Normalize defaults and resolve
dependency keys once, validate the resolved contract, then translate to upstream
inputs. Avoid exposing upstream's broad untyped worker map directly to customers.

Prototype one pinned upstream root-module instance per configured cluster, with
its managed and virtual pools grouped by cluster. Use separate instances with
`create_cluster = false` and the existing cluster OCID for worker-only targets.
Construct instance keys from configuration-known keys, never from newly computed
OCIDs. Distinguish managed/virtual pool keys if the two legacy maps contain the
same key. Preserve the original keys in public outputs and migration manifests.

Before freezing this layout, compare it with consuming upstream `modules/cluster`
and `modules/workers` directly. The root module is the preferred public integration
surface, but introduces provider aliases, extra providers, network lookups, and
utility behavior. Submodules avoid some overhead but have a larger internal
contract to maintain. Record the decision after a minimal Terraform 1.5 prototype;
do not maintain both implementations.

The wrapper must fail invalid requests with errors identifying the cluster/pool
key and field. Validate structure and enums in variables; use blocking
preconditions for resolved cross-input and live OCI facts. Wire those checks ahead
of provisioning. Do not use warning-only `check` blocks as safety gates or rely on
post-1.5 cross-variable validation features.

## Capability and compatibility inventory

| Surface | Current behavior to preserve | Upstream mapping / investigation |
| --- | --- | --- |
| Cluster ownership | Multiple clusters; cluster-only and combined stacks | One upstream instance per stable cluster key; explicit empty worker maps |
| External clusters | Worker pools can reference an existing OCID | `create_cluster = false`, `cluster_id`; discover actual type, version and CNI; separate cluster and worker compartments |
| Cluster networking | Flannel/native, private/public endpoint, VCN/subnet/NSG references, pod/service CIDRs | Translate `native` to `npn`; map both public endpoint flags explicitly |
| Security | CIS level 2 KMS requirement, secret encryption, signed images | `cluster_kms_key_id`, `use_signed_images`, `image_signing_keys`; retain wrapper checks |
| OIDC | Discovery and token authentication, claims, certificate, configuration file | Upstream supports these; convert legacy required-claims map to expected collection |
| Service networking | Optional list of service LB subnets | Upstream cluster takes one subnet and requires a non-null value: parity gap for omitted/multiple subnets |
| Legacy options | Dashboard, Tiller, pod-security-policy fields | Not exposed by inspected upstream cluster; establish still-supported OCI behavior, contribute if applicable, or document an explicit agreed deprecation; never silently discard |
| Managed pools | Version/image selection, flex shapes, size, boot volume, metadata and SSH input | Translate explicitly; retain path-or-key SSH behavior and custom base64 user data |
| Pool networking | Per-pool worker/pod subnet, NSGs, native max pods | Test per-pool overrides and prevent upstream defaults from introducing extra networks/NSGs |
| Placement | AD/FD placements, capacity reservation, placement-specific preemption | Upstream uses AD collections and pool-level settings; heterogeneous per-placement behavior requires a detailed gap check |
| Pool lifecycle | Encryption, eviction, enhanced-cluster cycling | Explicit values required: legacy eviction default is 3600 seconds, upstream inspected default is 300 |
| Virtual pools | Enhanced/native restrictions, labels, taints, pod shape, placements, node and pool tags | Upstream virtual pools exist; verify every field, defaults and tag scope |
| Tags and updates | Defaults and Landing Zone module tags | Upstream adds state/role tags and ignores some tag/placement changes; create-time equality alone is insufficient |
| Outputs | Keyed full-resource `clusters`, `node_pools`, `virtual_node_pools`; `nodes` grouped by pool/name | Upstream cluster outputs are narrower. Prefer upstream output additions; otherwise document exact schema changes and adapters |

Also preserve Kubernetes/image validation, public-endpoint/subnet checks,
compartment requirements for external clusters, and existing one-cluster-per-VCN
policy until deliberately changed. Compare numeric Kubernetes versions rather than
assuming OCI's returned version list is a semantic version sequence. Record
legacy quirks separately from desired behavior: null configurations, default CIS
level precedence, implicit latest-version/image selection, max-pod clamping and
eviction-duration conversion need regression cases. Do not preserve accidental
errors as the supported contract.

The current `enable_output` suppresses three resource-map outputs but not `nodes`.
Make this behavior an explicit compatibility decision. Verify the orchestrator's
`oke_resources` and serialized dependency documents, not just direct module users.

## Enforce the Landing Zone ownership boundary

For a root-module integration, explicitly configure and test:

- `create_vcn = false`, `create_drg = false`; no DRG attachment side effects.
- Existing subnet IDs with creation disabled for every relevant upstream subnet
  role, and NSG creation disabled for all roles. Upstream uses per-entry `create`
  string controls; validate the exact `never` settings against the pinned release.
  Disabling VCN creation alone is insufficient.
- `create_iam_resources = false`, `create_iam_tag_namespace = false`,
  `create_iam_defined_tags = false`, and individual IAM policy switches set to
  `never`. Existing KMS and tag resources remain Landing Zone responsibilities.
- `create_bastion = false`, `create_operator = false`; disable extensions,
  readiness/SSH utilities, and explicit add-on management for the parity milestone.
  Leave OKE's service-managed defaults alone.
- Only `node-pool` and `virtual-node-pool` modes initially; disable autoscaler
  ownership and upstream default cloud-init unless required for exact legacy parity.
- Explicit configuration for metadata, tags, versions, images and placement;
  investigate every upstream-injected default before adopting it.

Assert from plan JSON that no network, IAM, bastion/operator, or unrelated compute
resource is created, changed, or destroyed. Any additional Terraform helper
resources must be understood and documented. Enumerate read-only OCI permissions
needed even when upstream resource creation is disabled.

## Terraform and provider compatibility gate

Both inspected root modules declare Terraform `>= 1.3.0`; this is a promising
starting point, not proof of runtime compatibility. Upstream v5.5.1 requires OCI
`>= 8.14.0` at its root, but its cluster/workers children raise the effective
minimum to `>= 8.19.0`. It also requires Helm `>= 3.0.1`, cloudinit, null,
random and time, and an `oci.home`
alias. Even disabled features can leave provider installation requirements.

Run init/validate and representative plans under Terraform 1.5.7, including all
transitive modules/providers. Decide and document the minimum supported version;
if retaining 1.3 support, test it separately. Do not introduce a new minimum or
upper-bound constraint merely as a side effect of this refactor. Publish a tested
provider matrix and fixture lockfiles; reusable module lockfiles do not constrain
consuming root configurations. Validate home-region alias handling with the
orchestrator. Resolve incompatibilities upstream or select a tested release.

Tests must not depend on the stable Terraform test framework introduced after
1.5; use fixture roots, CLI commands and assertions over `terraform show -json`.

## State migration strategy

Resource-address changes do not inherently corrupt state. The same three OCI
resource types exist upstream, making same-type moves plausible. Configuration
and provider-schema changes can still cause replacements after a move.

For the proposed root-module layout, the following relative mappings illustrate
the target addresses observed in upstream v5.5.1. Wrapper module names and pool
keys remain proposals until the prototype is frozen:

| Existing address | Proposed address |
| --- | --- |
| `oci_containerengine_cluster.these["C"]` | `module.oke["C"].module.cluster[0].oci_containerengine_cluster.k8s_cluster` |
| `oci_containerengine_node_pool.these["P"]` | `module.oke["C"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["P"]` |
| `oci_containerengine_virtual_node_pool.these["V"]` | `module.oke["C"].module.workers[0].oci_containerengine_virtual_node_pool.workers["V"]` |

`moved` blocks work with Terraform 1.5, but their addresses are static: they cannot
loop over arbitrary customer keys or derive a pool's parent cluster dynamically.
Provide a generator that reads a supplied configuration plus state inventory and
emits explicit root-level moves with the complete caller module prefix. It must
validate one-to-one mappings, resource types, existing destinations, pool/cluster
relationships and name collisions; emit a reviewable manifest without applying it.
Test moves into externally sourced modules on 1.5 before promising this path.
Offer a reviewed, properly quoted `terraform state mv` command file as a fallback.
Do not suggest state removal/reimport as the default procedure.

Customer migration runbook to deliver:

1. Record the old module/provider versions, workspace/backend, resource OCIDs,
   and full state addresses. Back up state securely and pause competing applies.
2. Achieve a clean baseline plan with the old code. Pin current Kubernetes/image
   choices to avoid unrelated upgrades; separate provider upgrades where possible.
3. Update the source version and translated configuration; generate and inspect
   the address manifest and explicit moves for that exact caller layout.
4. Initialize the tested dependency set and plan with Terraform 1.5. Reject any
   unapproved replacement/deletion, unrelated ownership changes, or node cycling.
5. Apply only the reviewed plan, verify original OCIDs and cluster/node health,
   and require a subsequent stable plan. Document expected in-place differences.
6. Keep move declarations for supported upgrade paths. Document rollback with
   old configuration plus reverse mappings; restoring stale state after real
   infrastructure changes is not a safe generic rollback.

Test cluster-only, managed and virtual pools, multiple clusters, external-cluster
worker-only stacks, duplicate names with distinct keys, and nested orchestrator
module prefixes. Do not combine splitting backends with the initial migration.
If a real feature gap requires recreation, document it as a blocked/exceptional
case before release rather than claiming universal zero-downtime migration.

## Implementation sequence on a separate branch

1. **Freeze the baseline.** Inventory every input/default/output and current
   resource address; select supported source releases and capture fixture plans.
   Decide release versioning for this multi-module repository.
2. **Prove upstream integration.** On a feature branch, build a minimal 1.5
   prototype for a private cluster, managed pool, virtual pool and external
   cluster. Verify ownership controls, aliases and output availability. Decide
   root versus submodule consumption and pin the tested upstream release.
3. **Close parity gaps upstream.** Track LB subnet cardinality, full cluster
   outputs, placement/preemption granularity, legacy options and lifecycle
   ignore behavior. Accepted removal needs an explicit release decision; missing
   behavior must not disappear silently.
4. **Build normalization and validation.** Preserve public keys and dependency
   maps; resolve defaults once, enforce contracts and implement adapter mappings.
   Add positive and negative fixtures for null/empty and invalid configurations.
5. **Replace resource ownership.** Wire upstream modules and output adapters;
   preserve cluster-only/worker-only/multi-cluster composition. Update examples
   and prove the orchestrator/dependency-file contract.
6. **Deliver migration tooling and guide.** Generate explicit mapping files,
   rehearse moves and fallback commands, exercise interruption/rollback, and
   inspect replacement-sensitive fields with the actual pinned OCI provider.
7. **Qualify the major release.** Run compatibility and functional migration
   tests; publish breaking changes, tested versions, ownership/prerequisite
   guidance, supported source releases and the migration runbook. Coordinate
   the orchestrator version bump separately.

## Release acceptance and outstanding decisions

Release requires verified baseline feature coverage (or explicitly accepted
deprecations), blocking validation failures for invalid contracts, Terraform 1.5
plans, no unintended Landing Zone resource ownership, tested output compatibility,
and replacement-free migration for supported fixtures with unchanged OCIDs.
Validate update behavior too: resize, version updates, tags, placement, encryption,
metadata and cycling. Upstream `ignore_changes` can mask missing support even when
a migration plan appears clean.

Outstanding decisions: root versus submodule integration; selected upstream
release after parity contributions; minimum Terraform version and any upper cap;
provider version policy; repository-wide major tag versus a submodule release
scheme; supported historical migration sources; treatment of obsolete options and
other proven incompatibilities.

The standalone input-contract follow-up passed Terraform 1.5.7 initialization,
validation and contract plans. No upstream live plans, deployment or state
migration have run. Upstream compatibility and no-replacement behavior remain
release gates, not claims of completed validation.
