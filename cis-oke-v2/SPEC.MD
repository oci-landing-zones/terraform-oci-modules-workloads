# CIS OKE v2 specification

The authoritative typed input schema is [variables.tf](variables.tf). See the
[README](README.md) for behavior, [outputs.tf](outputs.tf) for outputs, and the
[configuration module](modules/configuration/) for normalization. Upgrade guidance
is included in the README.

Requires Terraform >=1.4 with Terraform 1.5.x compatibility, and OCI provider
>=8.19.0, <9.0.0. Upstream is pinned in [oke.tf](oke.tf).

The legacy API remains documented in [cis-oke/SPEC.MD](../cis-oke/SPEC.MD).
