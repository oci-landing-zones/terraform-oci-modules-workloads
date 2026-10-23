# OKE versions and release workflow

The OKE module has one source directory: `cis-oke/`. Select the implementation
through the Git ref, not a different directory.

| | Legacy | Refactored module |
| --- | --- | --- |
| Git ref | Pre-0.3.0 tags, such as `v0.2.9` | `release-0.3.0` for release testing |
| Source directory | `cis-oke/` | `cis-oke/` |
| Implementation | Original OCI resources | Official OKE module, pinned to v5.5.2 |
| Cluster input | `clusters_configuration` | `cluster_configuration` |
| Scope | Existing cluster/pool contracts | One enhanced private cluster per invocation |
| Cluster output | `clusters` map | `cluster` object |

Legacy consumers can retain their tested release tag, configuration and resource
addresses. For example:

```hcl
source = "git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke?ref=v0.2.9"
```

For testing the new release:

```hcl
source = "git::https://github.com/oci-landing-zones/terraform-oci-modules-workloads.git//cis-oke?ref=release-0.3.0"
```

Pin a reviewed commit for repeatable testing. Once 0.3.0 is published, use its
published `v0.3.0` tag for production; the release branch itself is mutable.
The [single-cluster example](cis-oke/examples/upstream-wrapper/) and
[multiple-cluster caller example](cis-oke/examples/multiple-clusters/) test this
checkout. Legacy examples are retained under [examples/legacy](cis-oke/examples/legacy/)
with OKE calls pinned to `v0.2.9`, and remain available in historical tags. The orchestrator is
unchanged and continues to use its pinned legacy release.

## Existing deployments

Existing deployments should remain pinned to their tested pre-0.3.0 Git tag,
such as `v0.2.9`. Version 0.3.0 is for new deployments; it changes inputs, outputs
and Terraform resource addresses. No in-place upgrade procedure, input converter
or state migration tooling is supplied. Changing only the Git ref is not a
supported upgrade, and a new module call must not manage an existing cluster.

Testers of the temporary `cis-oke-v2/` layout must change their source back to
`//cis-oke` and reinitialize. This directory-only change does not alter refactored
resource addresses when the caller's module address remains the same.

## Release workflow

1. Create `release-0.3.0` from current `main` (including the v0.2.9 release).
2. Complete and validate the refactor on its feature branch.
3. Merge the completed feature branch into `release-0.3.0` for release testing.
4. Follow the repository's review and publication process to release 0.3.0.

`release.txt` is `0.3.0`; the existing feature branch name does not set the release
version. Creating and updating the release branch does not publish a release tag
or merge the release into `main`. Upstream limitations and outstanding live
qualification are documented in the module README.

## Validation

With Terraform 1.5.7 on PATH, run from the repository root:

```sh
terraform -chdir=cis-oke fmt -check -recursive
terraform -chdir=cis-oke init -backend=false
terraform -chdir=cis-oke validate
```

For functional validation, configure one of the current examples and review its
Terraform plan against the intended OCI environment before applying.
