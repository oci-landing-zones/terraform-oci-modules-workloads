# Single-cluster input contract

The production schema is in `../../variables.tf` and the provider-free normalization
module is in `../../modules/configuration`. The files here mirror the schema for
inspection; `test_contract.py` exercises the production module directly.

Use a flat `cluster_configuration` with no map/key and `workers_configuration`
with implicit cluster ownership. Worker defaults, collection overrides, custom
cloud-init replacement, GVA and blocking policy checks are covered by the tests.
See the [module README](../../README.md), [single-cluster example](../../examples/upstream-wrapper)
and [multi-cluster caller example](../../examples/multiple-clusters).

Run with Terraform 1.5.7:

```sh
TERRAFORM_BIN=/path/to/terraform-1.5.7 python3 test_contract.py
```
