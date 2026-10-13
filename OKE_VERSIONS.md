# OKE module versions

Both module generations ship in this repository. Choose the source subdirectory
explicitly; repository release numbers and the `v2` module generation are separate.

| | Legacy | New generation |
| --- | --- | --- |
| Directory | [`cis-oke/`](cis-oke/) | [`cis-oke-v2/`](cis-oke-v2/) |
| Implementation | Original OCI resources | Official OKE module, pinned to v5.5.1 |
| Cluster input | `clusters_configuration` | `cluster_configuration` |
| Scope | Existing cluster/pool contracts | One enhanced private cluster per invocation |
| Cluster output | `clusters` map | `cluster` object |
| Maintenance | Security, critical bug and compatibility fixes | Feature development |

The legacy directory, including its examples and provider constraints, is restored
unchanged from `v0.2.8` (`d7da10394a828f225b4ac19aa5ac14a9838b75ac`). Existing
consumers can retain their source path, configuration and Terraform resource
addresses. Keep a tested Git ref pinned; consumers using an older release should
still review changes between their release and v0.2.8.

For example, the legacy source at its baseline release is:

```hcl
source = "git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke?ref=v0.2.8"
```

The new module is available for testing on the feature branch once these changes
are pushed:

```hcl
source = "git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke-v2?ref=feat/cis-oke-v1.0.0-refactor"
```

Pin a reviewed commit for repeatable testing and a published release tag for
production. The new module remains a release candidate, with upstream limitations
and live migration qualification still outstanding. Its [single-cluster example](cis-oke-v2/examples/upstream-wrapper/)
and [multiple-cluster caller example](cis-oke-v2/examples/multiple-clusters/) use
relative sources to test this checkout. Legacy examples remain under `cis-oke/`.
The orchestrator is unchanged and continues to use legacy.

## Migration is opt-in

Staying on `cis-oke/` does not require migration to the new implementation. To
adopt `cis-oke-v2/`, follow its [migration guide](cis-oke-v2/MIGRATION.md): translate
inputs, review generated state moves, and inspect the saved plan before applying.
Changing the source path alone is insufficient. Do not add a second module call
to manage the same existing cluster; migrate its ownership deliberately.

The directory split itself does not alter v2's Terraform resource addresses when
the caller's module address is retained. Testers already using the unpublished
refactor at `//cis-oke` must update their source to `//cis-oke-v2` and reinitialize
before planning; the old path now selects legacy again.

## Maintenance and validation

Keep the implementations and their provider requirements independent. Review fixes
for each generation rather than automatically applying v2 policy or API changes
to legacy. This split creates no release tag or maintenance branch. A `release/0.2`
branch can be cut when an independent legacy patch release is needed.

With Terraform 1.5.7 on PATH, validate the modules separately from the repository root:

```sh
terraform -chdir=cis-oke init -backend=false
terraform -chdir=cis-oke validate
terraform -chdir=cis-oke-v2 init -backend=false
terraform -chdir=cis-oke-v2 validate
python3 cis-oke-v2/design/input-contract/test_contract.py
python3 cis-oke-v2/tests/test_offline.py
python3 -m unittest discover -s cis-oke-v2/tests -p test_migration.py
```

The v2 tests support `TERRAFORM_BIN` for an explicit Terraform 1.5 binary. Offline
tests use disposable data fixtures with real provider schemas; they do not apply
resources or qualify a live migration. Validate legacy fixes against the legacy
examples and supported provider versions separately.
