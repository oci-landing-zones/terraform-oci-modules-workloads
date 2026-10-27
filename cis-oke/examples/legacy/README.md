# Legacy OKE examples

These examples preserve the v0.2.9 configuration and output contracts. Every OKE
module call is pinned to `v0.2.9`, never to the current checkout. Other module pins
and historical behavior are retained; these are not examples of the 0.3.0 security
contract. Keep existing deployments pinned to their tested legacy tag. Version
0.3.0 is for new deployments and supplies no in-place upgrade procedure.

- [Native CNI](native/basic/), [with local access](native/basic-access-from-localhost/), [with an operator host](native/basic-access-from-operator-host/).
- [Flannel](flannel/basic/), [with local access](flannel/basic-access-from-localhost/), [with an operator host](flannel/basic-access-from-operator-host/).
- [Operator IAM helper](flannel/oke-operator-host-iam/).

These historical examples may provision bastion, compute and IAM resources in
addition to OKE. Review their original prerequisites and provider constraints.
Use a Kubernetes version and image available in your region; historical values in
the templates are not a current support recommendation.

See [current 0.3.0 examples](../README.md) for new deployments.
