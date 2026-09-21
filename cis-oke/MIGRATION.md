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

The old cluster `default_defined_tags`/`default_freeform_tags` are copied to the
new cluster, PV and service-LB default pairs. Collections now merge by default.
The converter emits `override_defaults` for explicit legacy cluster/PV/service-LB
tag maps and signing-key lists, preserving their previous replacement behavior.
When migrating manually, name these paths explicitly to prevent previously
suppressed global entries from being added. Clearing requires an explicit empty
value together with its `override_defaults` entry. Dashboard/Tiller settings must be
disabled before migration; their fields and the legacy admission-controller
switch are removed from converted inputs. Public API endpoints are unsupported:
the converter rejects both configured and deployed public endpoints. Plan any
transition to a private endpoint separately. Endpoint NSG defaults are additive;
a cluster-specific empty list removes the baseline only with
`override_defaults = ["networking.api_endpoint_nsg_ids"]`.

Worker defaults now live directly in `workers_configuration` as `default_*`
fields, alongside `worker_pools`. There is no nested defaults object. The converter
materializes supported legacy values per pool and supplies one global
`cluster_ref = { key = "..." }`. It rejects external clusters, pools spanning
multiple clusters, and deployed pool compartments that differ from the cluster.
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

No generated plan has been applied as part of this implementation. Disposable live
fixtures must pass this workflow before it is recommended for a customer estate.

## Address layout

Within the CIS OKE module:

| Previous | New |
| --- | --- |
| `oci_containerengine_cluster.these["C"]` | `module.cluster["C"].module.cluster[0].oci_containerengine_cluster.k8s_cluster` |
| `oci_containerengine_node_pool.these["P"]` | `module.cluster["C"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["pool-name"]` |
| `oci_containerengine_virtual_node_pool.these["V"]` | `module.cluster["C"].module.workers[0].oci_containerengine_virtual_node_pool.workers["pool-name"]` |

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
