# Migration to the official-upstream wrapper

The refactor changes both inputs and resource addresses. A `moved` block handles
addresses only; it does not translate configuration or prevent provider-driven
replacements. This guide and tooling are a review workflow, not a guarantee that
all existing deployments can migrate to official upstream v5.5.1 unchanged.
Read the [blocked combinations](README.md#explicit-upstream-limitations) first.

## Prepare the baseline

1. Record the old module and provider versions, workspace/backend and caller module
   address. Pause concurrent applies and securely back up the state.
2. Obtain a clean old-code plan. Do not combine this refactor with Kubernetes,
   image, network or provider upgrades unless separately reviewed.
3. Export JSON inputs using the old module's `clusters_configuration` and
   `workers_configuration` envelopes. HCL users can use the field mapping in the
   contract guide or produce an equivalent JSON document. The tool does not parse
   arbitrary HCL or merge multiple facade files.
4. Export the old state using `terraform show -json > old-state.json`. This file
   can contain secrets. Keep it outside version control and restrict access.

New clusters default to enhanced/VCN-native. Only enhanced clusters are supported. The converter rejects basic clusters in
legacy inputs or deployed state. Upgrade them and update the legacy configuration
before migration. Explicit legacy CNI settings, including flannel, are preserved.

The converted input uses a flat `cluster_configuration`, not a clusters map.
There is no cluster identity key or worker `cluster_ref`. The converter requires
exactly one legacy cluster; multi-cluster callers must first be split into
separate module invocations with explicitly reviewed source/destination moves.
It will not discard another cluster or fabricate migration state.

Legacy compartment, encryption and tag defaults are materialized into the single
cluster object, including PV/service-LB tag maps. Explicit legacy tag maps still
replace defaults, including empty maps. The resulting cluster has no default
fields or `override_defaults`. Dashboard/Tiller must already be disabled, and
public API endpoints are rejected. Native CNI still forbids a pods CIDR.

Worker defaults remain top-level `default_*` fields alongside `worker_pools`.
The converter materializes supported legacy values per pool and checks every
pool belongs to the one configured cluster. It rejects external clusters and
pool compartments that differ from the cluster.
Worker CIS level is inherited from the cluster; migration refuses to downgrade a
level-2 pool to a level-1 cluster policy. Review any increase in required KMS
coverage before applying. SSH key content and deployed image IDs are preserved;
image type is inferred from each pool image ID.

Keep existing `node_metadata.user_data` during migration. The converter sets
`disable_default_cloud_init = true` on migrated managed pools to preserve their
previous boot behavior; newly authored pools enable upstream scripts by default. The new per-pool
`cloud_init` MIME parts are an alternative, not an additional input to combine
with raw user data. GVA profiles are optional and default to empty; introduce GVA
in a separately reviewed pool update after state migration. Upstream ignores
some secondary-VNIC defined-tag changes, so continue using the plan checker.

## Generate review artifacts

From your checkout of the workloads repository:

```sh
python3 cis-oke/tools/migrate.py \
  --config /private/path/old-inputs.json \
  --state-json /private/path/old-state.json \
  --module-address 'module.oke[0]' \
  --output-dir /private/path/oke-migration-review
```

Omit `--module-address` only when the old CIS OKE resources were at the Terraform
root. Use the actual nested address (for example the orchestrator's
`module.oci_lz_oke[0]`), not the display name of the cluster.

The output directory must not already exist. It contains converted JSON inputs,
a move manifest, explicit `migration.tf` declarations and `REVIEW.txt`. The tool
never runs Terraform, invokes a shell, contacts OCI, or changes state. Files are
created with restricted permissions. It refuses unknown legacy configuration
fields, missing source resources, occupied destinations and unmapped legacy
resources rather than guessing.

The converter materializes deployed image/version/size/tag/SSH values where
needed. Review each report item: source state can legitimately differ from desired
configuration. Legacy per-object CIS level defaults to 1; correcting an ineffective
global level-2 setting is an explicit policy change and may require KMS keys.
Virtual-pool key collisions receive an explicit new key. Uniform legacy placement
entries become `placement_ads`, `placement_fds` and `preemptible_config`; the
converter refuses heterogeneous settings or duplicate ADs instead of discarding them. Previous implicit virtual
fault-domain placement must be reviewed even if no placement was written in tfvars.

## Verify and apply a reviewed plan

1. Update the module source to this branch/release and use the converted input
   document. Pass `providers = { oci = oci }` explicitly from the caller on
   Terraform 1.5. Review all blocked combinations before proceeding. There is no
   support for external-cluster references in this release.
2. Place the generated `migration.tf` in the **caller root** containing the module
   address used during generation. Do not put root-qualified moves inside the
   reusable child module. Terraform 1.5 cannot generate moves dynamically.
3. Initialize with the tested provider set and run a saved plan under Terraform
   1.5.7. Export it using `terraform show -json plan.out > plan.json`.
4. Run the checker against the module scope:

   ```sh
   python3 cis-oke/tools/check_plan.py /private/path/plan.json \
     --module-address 'module.oke[0]'
   ```

   Treat errors as blockers. In particular, address moves do not defeat upstream
   `ignore_changes`; desired tag, CIDR or placement changes may require an upstream
   fix. The checker catches selected contract mismatches, not every OCI behavior.
5. Review all in-place changes too, especially injected tags/labels/metadata,
   encryption, eviction/cycling and node shape/image settings. Any replacement,
   unexpected deletion, image upgrade or node cycling requires a separate plan.
6. Apply only the saved, reviewed plan. Verify unchanged resource OCIDs, OKE and
   workload health, output documents and a stable subsequent plan.

A disposable legacy v0.2.8 enhanced/native CIS1 cluster with one managed pool
completed this workflow on Terraform 1.16.3 and OCI provider 8.29.0. Cluster,
pool, instance and Kubernetes node identities were preserved; the worker remained
Ready and all eight system pods were healthy. Preparation included the reviewed
tag alignment described below. The follow-up plan retained the known eviction
duration formatting drift (`PT1H` versus `PT60M`). This limited fixture is not a
guarantee for other estates, virtual pools or workload continuity; repeat the
workflow for each deployment. Existing workers were not cycled.

## Address layout

Within the CIS OKE module:

| Previous | New |
| --- | --- |
| `oci_containerengine_cluster.these["C"]` | `module.cluster["cluster"].module.cluster[0].oci_containerengine_cluster.k8s_cluster` |
| `oci_containerengine_node_pool.these["P"]` | `module.cluster["cluster"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["pool-name"]` |
| `oci_containerengine_virtual_node_pool.these["V"]` | `module.cluster["cluster"].module.workers[0].oci_containerengine_virtual_node_pool.workers["pool-name"]` |

Here `C` is the referenced cluster key. Pool display names are upstream instance keys. Future name changes also need
explicit moves, and name updates may still be ignored upstream. Keep the outer
Landing Zone identity stable. The helper validation resources and upstream random state-ID resource are new
state entries, not imported OCI infrastructure. No move is required for data sources.

For installations where declarative moves cannot be used, the reviewed manifest
can guide individually quoted `terraform state mv` commands. Do not combine both
methods for the same resource or remove/reimport resources as the default approach.
This implementation deliberately does not execute state commands.

## Rollback

Before applying, rollback means returning to the old code/inputs and discarding the
unapplied new plan/move file. After applying, restore old code and use reviewed
reverse address mappings only after inspecting any real infrastructure changes.
Blindly restoring a stale state backup after an apply is not a safe rollback.
Do not move resources between backends as part of this migration.

## Caller outputs and pre-release configurations

The cluster output is now `cluster` (a single object), replacing `clusters` (a map).
Pool/node outputs remain keyed maps. For caller `for_each` composition, keep outputs
nested under caller keys as shown in `examples/multiple-clusters`; repeated pool
keys across clusters will then remain distinct. The orchestrator has not been
updated in this branch.

Earlier unpublished refactor inputs must be rewritten to `cluster_configuration`:
select one cluster, materialize its inherited defaults, remove cluster
`override_defaults`, and remove workers `cluster_ref`. No compatibility alias is
provided. This major version has not been deployed, so those intermediate API
shapes and their state addresses are not maintained.

Managed pools now enforce IMDSv2-only for newly created nodes. Remove an explicit
`areLegacyImdsEndpointsDisabled = "false"` metadata setting before migrating and
verify custom images/scripts support IMDSv2. Plan controlled node replacement or
cycling to cover existing nodes; a node-pool metadata update alone does not
change the metadata endpoint setting on existing instances.

## Existing Tags and Migration Preflight

The plan checker remains strict by default. A tenancy-default defined tag may
exist on a resource even when it is absent from the Terraform inputs. Review
each such key and, when it must remain externally managed, pass the repeatable
`--preserve-defined-tag NAMESPACE.KEY` option to `tools/check_plan.py`. This
allows only that unconfigured key with exactly the same value in the before
and after plan. It does not allow new/changed tags, override configured values,
or relax freeform-tag checks. Do not use it for a tag you intend to remove.

For example, a reviewed default tag can be retained with:

```sh
python3 cis-oke/tools/check_plan.py plan.json \
  --module-address 'module.oke[0]' \
  --preserve-defined-tag Company.CostCenter
```

An absent capacity reservation may be serialized as either null or an empty
string. The checker treats those representations as equivalent; any nonempty
reservation change remains an error.

Official upstream v5.5.1 ignores pool-level freeform-tag updates. Consequently,
a legacy pool lacking the wrapper's tracking tags can fail migration checks
even though its address move is valid. Do not suppress that failure. Either
adopt an upstream fix or perform a separately reviewed preparation step:

1. Inspect the target plan's worker validation input to identify the effective
   tracking tags for this pool. Do not copy another pool's name or state ID.
2. Merge those tags into the legacy pool's freeform tags, preserving customer
   tags and explicitly reviewing any conflicting values. Align the node-template
   tags too: the current wrapper requires equal pool/node tag inputs.
3. Plan and apply this tag-only update using the legacy module, with cycling
   disabled. Require no replacements or unrelated changes. Verify the existing
   worker identity and obtain a new clean legacy baseline/state backup.
4. Carry the aligned tags into the new input and rerun the migration plan and
   checker. The original state-address migration remains a separate operation.

This preparation changes pool and future-node template tags; it does not prove
existing instances were retagged or adopted IMDSv2. Record it in the migration
review. Do not use CLI retagging outside Terraform to conceal configuration drift.
