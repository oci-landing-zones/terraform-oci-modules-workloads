# Repository scope and release direction

Recorded from the Landing Zone maintainer's instructions on 2026-09-18.

## Objective

Refactor `cis-oke` into a validated, supportable Landing Zone wrapper around
https://github.com/oracle-terraform-modules/terraform-oci-oke. The existing
implementation has limited coverage of newer OKE capabilities. Reuse and
contribute to the maintained upstream module instead of duplicating its resource
implementation here.

The wrapper owns clear control-plane and node-pool contracts, dependency
resolution, safe validation, and Landing Zone integration. Upstream owns OKE
resource provisioning. Landing Zone components already own networking, IAM, and
related prerequisites; explicitly disable upstream creation of those resources.

## Release constraints

- Maintainer clarification: retain CIS OKE logic and validations. The refactor
  changes the input contract and the mechanism that creates clusters and pools;
  it does not replace Landing Zone policy with upstream defaults. Input-variable
  changes are expected and must have their own migration instructions, separate
  from Terraform state-address migration.
- New inputs must increase flexibility while representing all previous use cases.
  Preserve independent pool names, per-pool SSH, separate pool/node tags and
  placement detail. Do not narrow the public contract to upstream limitations;
  solve those with adapter composition or upstream changes. Preserving use cases
  does not require preserving the old input syntax unchanged.
- Latest worker-schema direction: closely follow upstream OKE pool objects and
  names. Use a keyed `worker_pools` map with managed/virtual `mode` and a shared
  `worker_pool_defaults` object. Normalize defaults before CIS validation;
  individual pool settings override global settings. Preserve explicit false,
  zero and empty values, and document map/list precedence. Keep Landing Zone
  extensions required for previous use cases. The concrete prototype README
  supersedes earlier proposals for separate pool maps and nested node settings.
- Deliver this refactor as a new major release, with customer migration instructions.
- Preserve existing `cis-oke` capabilities as the first milestone. Add new features
  incrementally afterward. Inventory actual behavior as well as documented inputs.
- Support Terraform 1.5.x. Do not require language features, tooling, or module
  dependencies introduced after 1.5. The precise lower supported version and
  whether to reject newer runtimes are release-policy decisions; do not silently
  equate compatibility with a new minimum of 1.5.
- Existing customers and Terraform state are first-class release concerns.
  Address changes do not inherently require resource recreation or state damage.
  Prefer explicit, tested state migrations and demonstrate preservation of OCIDs.
- Evaluate Terraform `moved` blocks and document their limitations for arbitrary
  customer map keys. Supply reviewable migration mappings and a tested fallback
  using `terraform state mv` where needed.
- Preserve cluster-only, worker-only against existing clusters, combined, and
  multiple-cluster use cases, including managed and virtual node pools.
- Preserve or explicitly document migrations for public inputs, dependency maps,
  output schemas, defaults, tags, and operational update behavior.
- Resolve provisioning gaps through upstream contributions. Do not quietly drop
  features or introduce a permanent duplicate OKE implementation.
- Pin and test an upstream release; do not consume a moving branch in a release.
- Implementation is now authorized on `feat/cis-oke-input-contract`. Use only
  official upstream code, with unsupported cases explicitly blocked; the maintainer
  declined a temporary patched snapshot. Do not deploy or mutate customer state
  as part of implementation. Live migration remains a release qualification step.
- Limit the refactor to `cis-oke` and necessary integration/release documentation;
  avoid unrelated changes to other workload modules.

## Working guidance

Read [the refactoring plan](cis-oke/REFACTORING_PLAN.md) before implementation.
Read [the initial feasibility assessment](cis-oke/FEASIBILITY.md) for the proposed
input changes, preserved validation inventory, and confirmed upstream gaps.
The contract has been promoted into `cis-oke/variables.tf` and the provider-free
`cis-oke/modules/configuration` module. The production wrapper now calls official
upstream submodules. Read the current README and MIGRATION.md; earlier feasibility
notes record the design history and are not the current implementation status.
Keep findings and open decisions distinct from maintainer requirements. Validate
with Terraform 1.5 itself; a permissive `required_version` is not sufficient proof.
Use blocking validation for safety requirements, with actionable messages naming
the affected cluster or pool. Terraform 1.5 `check` warnings alone are insufficient.
Never commit credentials, private keys, customer state, saved plans, or runtime
dependency outputs. Rehearse migration on disposable fixtures before publishing
customer commands; never experiment on customer state.

## Latest review decisions

- Pin both official OKE submodules to the latest release tag (currently v5.5.1).
- Use only the upstream-style flat placement fields; remove the duplicate placement_configs input. Translate supported legacy placements in migration tooling and reject heterogeneous mappings.
- Taints are virtual-node-pool only; reject nonempty resolved taints on managed pools, including inherited global defaults.

- Cluster APIs must always be private; expose no public endpoint switch.
- Remove deprecated Dashboard/Tiller and admission-controller options.
- Separate cluster/PV/service-LB default defined/freeform tags.
- Merge default_api_endpoint_nsg_ids with cluster endpoint NSGs, deduplicating resolved OCIDs; cluster lists cannot remove baseline NSGs.

- Cluster, PV and service-LB tags merge by key: defaults first, target-specific values win; empty maps retain defaults.

- New cluster defaults are enhanced and VCN-native CNI; migration must preserve explicit legacy behavior.

- Reject a non-null pods_cidr when cluster CNI is native, including the default CNI.

- Latest review: replace worker_pool_defaults with top-level default_* worker settings, following the cluster envelope. Only managed (node-pool) and virtual-node-pool modes are supported in this release.

## Latest worker contract decisions

- One global worker cluster_ref.key must name a cluster in clusters_configuration; no per-pool cluster, compartment or CIS settings. Derive compartment and CIS level from that cluster.
- External cluster references and worker-only configurations are explicitly blocked for this release.
- No default name/image ID or public image_type; infer custom only from a pool image_id. Default OS is Oracle Linux 9.
- Max pods is pool-only, default 31. Placement, capacity reservation, metadata, eviction, cycling, preemption and taints are pool-only.
- Remove SSH-path inputs entirely; accept public-key content.

## Collection inheritance (latest decision)

- Add override_defaults to each cluster and worker pool. Supported maps merge by key and supported set-like lists union/deduplicate by default.
- Listed collection paths replace inherited values; require explicit non-null local values, including {} / [] for clearing. Reject unsupported paths and scalar targets.
- Cluster paths cover cluster/PV/service-LB tags, endpoint NSGs and signing keys. Pool paths cover pool/node tags, node labels and worker/pod NSGs.
- Normalize before dependency resolution; resolve/deduplicate OCIDs after collection composition. Preserve upstream tracking metadata and safety validations.

## Upstream root composition

- Image selection and AD-number translation belong to official upstream root code, not this wrapper. Keep Kubernetes version validation.
- Use one root module per configured cluster; disable ancillary OCI creation explicitly. Update state mappings when module nesting changes.
- Verify effective SSH/transit-encryption behavior in pinned upstream source and offline plans; do not silently accept per-pool overrides that upstream discards.

## Cloud-init and GVA

- Expose upstream-style per-pool cloud_init MIME parts while keeping upstream default boot scripts disabled. Preserve legacy raw node_metadata.user_data, reject simultaneous multipart and raw user data, and keep empty user data when neither is specified.
- Expose official v5.5.1 gva_secondary_vnics on managed pools with native CNI. Resolve VNIC subnet/NSG references through Landing Zone dependencies; require explicit per-profile subnets. No additional global default variables.
- Validate per-profile power-of-two IP counts and the combined 256-address per-node budget. GVA replaces ordinary pod network options in upstream. Keep ancillary network/IAM and Kubernetes deployment outside this module.

## Default boot scripts (latest review)

- Upstream default cloud-init scripts are enabled by default. Expose workers_configuration.default_disable_default_cloud_init (false) and per-pool disable_default_cloud_init (null inherits; explicit false re-enables).
- Custom MIME parts remain available whether default scripts are enabled or disabled. Raw node_metadata.user_data requires default scripts disabled and no custom MIME parts to prevent silent replacement. Migration explicitly disables defaults on legacy managed pools.

- Global custom boot parts use default_cloud_init, with identical MIME schema to pool cloud_init. Managed pools append local parts after global parts (ordered, no deduplication), or replace/clear via override_defaults = ["cloud_init"]. Virtual pools do not inherit global boot parts. Normalize once per pool before passing upstream to avoid duplicate parts.

- Latest correction: pool cloud_init replaces default_cloud_init as a whole, never concatenates. Omitted/null inherits, [] clears. Remove cloud_init from override_defaults. Retain the MIME-part list representation and part order.

- Reject BM node-pool shapes with effective pv_transit_encryption enabled, including inherited settings. Do not let upstream silently disable unsupported encryption.

- Enhanced clusters only for this release. Reject explicit basic inputs and basic-cluster migrations; require a separately reviewed upgrade before migration. Keep enhanced flannel support.

## Plan-time discovery dependency constraint

- Do not make the upstream root module depend on validation resources or pass compartment_id through a validation resource. Use resolved configuration locals so upstream AD discovery can finish at plan time and its fault-domain for_each keys remain known.
- Retain blocking validation preconditions. Test ordinary plans, with real provider data-read semantics for discovery, and a negative control reproducing the old module-wide dependency failure. No targeted/staged applies as a workaround.

## Single-cluster strategy (supersedes earlier cluster-envelope decisions)

- Each invocation takes one flat cluster_configuration and optional workers_configuration. All pools belong to that cluster, inheriting compartment and CIS. No public cluster key, clusters map, or cluster_ref; do not retain compatibility with unpublished refactor versions.
- Remove cluster-level default_* and override_defaults fields; cluster/PV/LB tags and endpoint NSGs are explicit. Worker defaults and collection semantics remain unchanged. Expose cluster (singular), retaining keyed pool/node outputs.
- Scope this change to CIS OKE and caller examples; do not modify the orchestrator. Show for_each composition with outputs nested by caller identity.
- Legacy conversion requires a single cluster, materializes its defaults and validates pool ownership. Reject multi-cluster conversion unless a separately reviewed fan-out migration is supplied.

- Enforce IMDSv2-only for all managed nodes through node_metadata.areLegacyImdsEndpointsDisabled = "true". No opt-out; reject conflicting input metadata. Preserve custom metadata/cloud-init. Existing nodes require replacement/cycling, not just a pool update.
