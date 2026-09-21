# CIS OKE input contract

The production schema is in `../../variables.tf` and normalization is in
`../../modules/configuration`. Files here mirror the schema for design reference;
`test_contract.py` tests the production configuration module with Terraform 1.5.

## Cluster and worker relationship

`clusters_configuration.clusters` can contain multiple clusters. One
`workers_configuration` references exactly one of them using a required global
`cluster_ref = { key = "CLUSTER-A" }`. That reference cannot be overridden per
pool. External OCIDs and worker-only deployments are blocked for this release.
All pools inherit their cluster's compartment and CIS level. Managed workers on
CIS level 2 require a volume KMS key.

## Shared defaults and per-pool values

Shared fields use top-level `default_*` names beside the keyed `worker_pools` map.
Only `node-pool` (managed) and `virtual-node-pool` modes are supported.

```hcl
workers_configuration = {
  cluster_ref = { key = "CLUSTER-A" }
  default_shape = "VM.Standard.E4.Flex"
  default_size = 3
  default_subnet_id = "WORKERS"
  default_pod_subnet_id = "PODS"
  default_node_labels = { team = "platform" }
  worker_pools = {
    general = {}
    batch = { size = 5, node_labels = { tier = "batch" } }
  }
}
```

Precedence is built-in fallback, shared defaults, then non-null pool values.
Explicit false, zero and empty collections remain meaningful. Worker tag and label
maps merge by key, with pool values winning. NSG lists merge and deduplicate.
Empty collections retain defaults. Name a supported collection in the object’s
`override_defaults` to replace it; supply `{}` or `[]` to clear it. The listed
field must be explicitly non-null. See the supported-path table in
`../../README.md`. Other lists retain field-specific semantics. Pool metadata has
no shared default.

Names, image IDs, max pods, AD/FD placement, capacity reservations, metadata,
eviction, cycling, preemption and taints are pool-specific. Max pods defaults to
31. Taints are virtual-only. SSH accepts public-key content only; callers may
use Terraform `file()` to supply it.

Image type is internal: OKE discovery when pool `image_id` is null, otherwise
custom. Oracle Linux 9 is the default; major-version discovery includes minor
releases. Shared OS settings may be overridden per pool.

## Migration

See `../../MIGRATION.md` and `../../tools/migrate.py`. Legacy heterogeneous
placements, cross-compartment pools, external clusters and multiple worker cluster
references require a separately reviewed migration; they are not silently dropped.
The converter freezes deployed image and SSH values and refuses unsupported maps.
