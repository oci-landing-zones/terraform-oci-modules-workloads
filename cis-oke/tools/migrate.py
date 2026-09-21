#!/usr/bin/env python3
"""Convert legacy CIS OKE JSON inputs and emit review-only Terraform moves.

Never runs Terraform, contacts OCI, or writes state. Requires terraform show -json
state for deployed defaults. Output is sensitive configuration: keep it private.
"""
import argparse
import copy
import json
from pathlib import Path
import re

TYPES = {'oci_containerengine_cluster', 'oci_containerengine_node_pool', 'oci_containerengine_virtual_node_pool'}


def hcl_string(value):
    return json.dumps(value, ensure_ascii=False).replace('${', '$${').replace('%{', '%%{')


def inventory(document):
    result = {}
    def walk(module):
        for resource in module.get('resources', []):
            if resource.get('mode') == 'managed':
                result[resource['address']] = resource
        for child in module.get('child_modules', []):
            walk(child)
    if 'values' not in document:
        raise ValueError('Use terraform show -json on STATE, not state pull or a plan JSON.')
    walk(document['values'].get('root_module', {}))
    return result


def check_fields(value, allowed, path):
    unknown = set(value or {}) - set(allowed.split())
    if unknown:
        raise ValueError(f'{path}: unknown fields {sorted(unknown)}; refusing to discard input.')


def block(value, index=0):
    return (value or [{}])[index]


def convert(config, state, module_address=''):
    if module_address and not re.fullmatch(r'module\.[\w-]+(?:\[(?:"(?:[^"\\]|\\.)*"|\d+)\])?(?:\.module\.[\w-]+(?:\[(?:"(?:[^"\\]|\\.)*"|\d+)\])?)*', module_address):
        raise ValueError('Invalid --module-address; expected module.name or a nested indexed module address.')
    prefix = module_address + '.' if module_address else ''
    resources = inventory(state)
    result = copy.deepcopy(config)
    check_fields(config, 'clusters_configuration workers_configuration compartments_dependency network_dependency kms_dependency enable_output module_name', 'root')
    moves, report = [], []
    seen = set()

    def previous(kind, key):
        # terraform show uses JSON-compatible quoted string indices.
        address = f'{prefix}{kind}.these[{json.dumps(key, ensure_ascii=False)}]'
        resource = resources.get(address)
        if resource is None:
            raise ValueError(f'{address}: not found in supplied state; convert only deployed resources with this tool.')
        if resource['type'] != kind:
            raise ValueError(f'{address}: resource type mismatch')
        seen.add(address)
        return address, resource['values']

    def move(old, new):
        if new in resources or any(item['to'] == new for item in moves):
            raise ValueError(f'{new}: destination already occupied or duplicated')
        moves.append({'from': old, 'to': new})

    clusters = result.get('clusters_configuration')
    if clusters:
        check_fields(clusters, 'default_compartment_id default_img_kms_key_id default_kube_secret_kms_key_id default_cis_level default_defined_tags default_freeform_tags clusters', 'clusters_configuration')
        for kind in ['defined', 'freeform']:
            value = clusters.pop(f'default_{kind}_tags', None)
            for target in ['cluster', 'pv', 'service_lb']:
                clusters[f'default_{target}_{kind}_tags'] = copy.deepcopy(value)
        if 'default_img_kms_key_id' in clusters:
            value = clusters.pop('default_img_kms_key_id')
            clusters['default_image_signing_key_ids'] = None if value is None else [value]
        for key, c in clusters['clusters'].items():
            check_fields(c, 'cis_level compartment_id kubernetes_version name is_enhanced cni_type defined_tags freeform_tags options networking encryption image_signing', f'cluster {key}')
            old, deployed = previous('oci_containerengine_cluster', key)
            requested_enhanced = c.pop('is_enhanced', False)
            if not requested_enhanced or deployed.get('type') != 'ENHANCED_CLUSTER':
                raise ValueError(f'Cluster {key}: only enhanced clusters are supported; upgrade the basic cluster and update legacy inputs before migrating.')
            c['cluster_type'] = 'enhanced'
            c['cni_type'] = c.get('cni_type') or 'flannel'
            c['cis_level'] = c.get('cis_level') or '1'
            c['kubernetes_version'] = c.get('kubernetes_version') or deployed['kubernetes_version']
            net = c['networking']
            check_fields(net, 'vcn_id is_api_endpoint_public api_endpoint_nsg_ids api_endpoint_subnet_id services_subnet_id', f'cluster {key}.networking')
            requested_public = net.pop('is_api_endpoint_public', False)
            if requested_public or block(deployed.get('endpoint_config')).get('is_public_ip_enabled', False):
                raise ValueError(f'Cluster {key}: public API endpoints are no longer supported; plan private endpoint migration separately.')
            net['service_lb_subnet_ids'] = net.pop('services_subnet_id', None)
            if len(net['service_lb_subnet_ids'] or []) != 1:
                report.append(f'BLOCKED cluster {key}: upstream requires exactly one LB subnet.')
            if c.get('image_signing'):
                check_fields(c['image_signing'], 'image_policy_enabled img_kms_key_id', f'cluster {key}.image_signing')
                value = c['image_signing'].pop('img_kms_key_id', None)
                if value is not None:
                    c['image_signing']['kms_key_ids'] = [value]
            check_fields(c.get('encryption'), 'kube_secret_kms_key_id', f'cluster {key}.encryption')
            options = c.get('options') or {}
            check_fields(options, 'add_ons admission_controller kubernetes_network_config persistent_volume_config service_lb_config openid_connect', f'cluster {key}.options')
            for opt, fields in {
                'add_ons':'dashboard_enabled tiller_enabled', 'admission_controller':'pod_policy_enabled',
                'kubernetes_network_config':'pods_cidr services_cidr', 'persistent_volume_config':'defined_tags freeform_tags',
                'service_lb_config':'defined_tags freeform_tags',
                'openid_connect':'enable_discovery enable_authentication ca_certificate signing_algorithms client_id configuration_file issuer_url required_claims username_claim username_prefix groups_claim groups_prefix',
            }.items():
                check_fields(options.get(opt), fields, f'cluster {key}.options.{opt}')
            add_ons = options.pop('add_ons', None) or {}
            if any(add_ons.values()):
                raise ValueError(f'Cluster {key}: dashboard/Tiller must be disabled before migration.')
            options.pop('admission_controller', None)
            # Legacy tag maps replaced defaults wholesale. Preserve that behavior
            # explicitly now that collections merge by default.
            c['override_defaults'] = [field for field in ['defined_tags','freeform_tags'] if c.get(field) is not None]
            for target in ['persistent_volume_config','service_lb_config']:
                for field in ['defined_tags','freeform_tags']:
                    if (options.get(target) or {}).get(field) is not None:
                        c['override_defaults'].append(f'options.{target}.{field}')
            if (c.get('image_signing') or {}).get('kms_key_ids') is not None:
                c['override_defaults'].append('image_signing.kms_key_ids')
            move(old, f'{prefix}module.cluster[{json.dumps(key, ensure_ascii=False)}].module.cluster[0].oci_containerengine_cluster.k8s_cluster')
    legacy = config.get('workers_configuration')
    if legacy:
        check_fields(legacy, 'default_cis_level default_compartment_id default_defined_tags default_freeform_tags default_ssh_public_key_path default_kms_key_id default_initial_node_labels node_pools virtual_node_pools', 'workers_configuration')
        pools = {}
        pool_states = {}
        # Materialize effective values to avoid changing the legacy tag/default semantics.
        for kind, mode, resource_type in [('node_pools','node-pool','oci_containerengine_node_pool'), ('virtual_node_pools','virtual-node-pool','oci_containerengine_virtual_node_pool')]:
            for key, old_pool in (legacy.get(kind) or {}).items():
                check_fields(old_pool, 'cis_level kubernetes_version cluster_id compartment_id name defined_tags freeform_tags initial_node_labels size networking node_config_details virtual_nodes_defined_tags virtual_nodes_freeform_tags pod_shape placement taints', f'{kind}.{key}')
                old_address, deployed = previous(resource_type, key)
                new_key = key
                if new_key in pools:
                    new_key = 'virtual-' + key
                if new_key in pools:
                    raise ValueError(f'Cannot disambiguate pool key {key}; choose a mapping manually.')
                if new_key != key:
                    report.append(f'Pool key collision: {kind}.{key} becomes {new_key}.')
                n = old_pool.get('node_config_details') or {}
                check_fields(n, 'ssh_public_key_path defined_tags freeform_tags node_metadata image node_shape capacity_reservation_id flex_shape_settings encryption boot_volume_size placement node_eviction node_cycling', f'{kind}.{key}.node_config_details')
                net = old_pool['networking']
                check_fields(net, 'workers_nsg_ids workers_subnet_id pods_subnet_id pods_nsg_ids max_pods_per_node', f'{kind}.{key}.networking')
                cluster = old_pool['cluster_id']
                if cluster.startswith('ocid1.'):
                    raise ValueError('External cluster references are blocked in this release.')
                p = {'mode':mode, 'name':old_pool['name'], 'cluster_ref':{'id' if cluster.startswith('ocid1.') else 'key':cluster},
                     'compartment_id':old_pool.get('compartment_id') or legacy.get('default_compartment_id') or deployed['compartment_id'],
                     'subnet_id':net['workers_subnet_id'], 'pod_subnet_id':net.get('pods_subnet_id'),
                     'nsg_ids':net.get('workers_nsg_ids'), 'pod_nsg_ids':net.get('pods_nsg_ids'),
                     'defined_tags':deployed.get('defined_tags') or {}, 'freeform_tags':deployed.get('freeform_tags') or {},
                     'node_labels':old_pool.get('initial_node_labels', legacy.get('default_initial_node_labels'))}
                if mode == 'node-pool':
                    check_fields(n.get('flex_shape_settings'), 'memory ocpus', f'pool {key}.flex_shape_settings')
                    check_fields(n.get('encryption'), 'enable_encrypt_in_transit kms_key_id', f'pool {key}.encryption')
                    check_fields(n.get('node_eviction'), 'grace_duration force_delete', f'pool {key}.node_eviction')
                    check_fields(n.get('node_cycling'), 'enable_cycling max_surge max_unavailable', f'pool {key}.node_cycling')
                    d = block(deployed.get('node_config_details'))
                    image = block(deployed.get('node_source_details'))
                    p.update({'cis_level':old_pool.get('cis_level') or '1', 'shape':n['node_shape'],
                              'size':old_pool.get('size') if old_pool.get('size') is not None else d['size'],
                              'kubernetes_version':old_pool.get('kubernetes_version') or deployed['kubernetes_version'],
                              'image_type':'custom', 'image_id':image['image_id'], 'boot_volume_size':n.get('boot_volume_size',60),
                              'memory':(n.get('flex_shape_settings') or {}).get('memory',16),
                              'ocpus':(n.get('flex_shape_settings') or {}).get('ocpus',1),
                              'capacity_reservation_id':n.get('capacity_reservation_id'),
                              'volume_kms_key_id':d.get('kms_key_id'), 'pv_transit_encryption':d.get('is_pv_encryption_in_transit_enabled'),
                              'node_defined_tags':d.get('defined_tags') or {}, 'node_freeform_tags':d.get('freeform_tags') or {},
                              'disable_default_cloud_init':True, 'node_metadata':n.get('node_metadata'), 'ssh_public_key':deployed.get('ssh_public_key'),
                              'max_pods_per_node':net.get('max_pods_per_node'),
                              'eviction_grace_duration':(n.get('node_eviction') or {}).get('grace_duration',3600),
                              'force_node_delete':(n.get('node_eviction') or {}).get('force_delete',False),
                              'node_cycling_enabled':(n.get('node_cycling') or {}).get('enable_cycling',False),
                              'node_cycling_max_surge':str((n.get('node_cycling') or {}).get('max_surge',1)),
                              'node_cycling_max_unavailable':str((n.get('node_cycling') or {}).get('max_unavailable',0))})
                    placements = n.get('placement')
                    suffix = 'oci_containerengine_node_pool.tfscaled_workers'
                else:
                    d = block(deployed.get('virtual_node_tags'))
                    p.update({'shape':old_pool['pod_shape'], 'size':old_pool.get('size') or deployed['size'],
                              'node_defined_tags':d.get('defined_tags') or {}, 'node_freeform_tags':d.get('freeform_tags') or {},
                              'taints':old_pool.get('taints')})
                    for taint in p['taints'] or []:
                        check_fields(taint, 'key value effect', f'pool {key}.taints')
                    placements = old_pool.get('placement')
                    suffix = 'oci_containerengine_virtual_node_pool.workers'
                    report.append(f'REVIEW virtual pool {key}: explicit FDs and empty pod NSGs are blocked; automatic placement must not silently replace existing placement.')
                if placements:
                    normalized = []
                    for pc in placements:
                        check_fields(pc, 'availability_domain fault_domain enable_preemptible_node preemptible_node_action_type preserve_boot_volume_on_preempting', f'pool {key}.placement')
                        normalized.append({
                            'ad': pc.get('availability_domain') or 1,
                            'fd': pc.get('fault_domain') or 1,
                            'enable': pc.get('enable_preemptible_node') or False,
                            'preserve': pc.get('preserve_boot_volume_on_preempting') or False,
                            'action': pc.get('preemptible_node_action_type') or 'TERMINATE',
                        })
                    first = normalized[0]
                    if any(any(pc[f] != first[f] for f in ['fd','enable','preserve','action']) for pc in normalized) or first['action'] != 'TERMINATE':
                        raise ValueError(f'Pool {key}: heterogeneous placement cannot be represented by upstream placement_ads/placement_fds/preemptible_config.')
                    p['placement_ads'] = [pc['ad'] for pc in normalized]
                    if len(set(p['placement_ads'])) != len(p['placement_ads']):
                        raise ValueError(f'Pool {key}: duplicate placement ADs require manual migration.')
                    p['placement_fds'] = [f"FAULT-DOMAIN-{first['fd']}"]
                    if mode == 'node-pool':
                        p['preemptible_config'] = {'enable':first['enable'], 'is_preserve_boot_volume':first['preserve']}
                if p['defined_tags'] != p['node_defined_tags'] or p['freeform_tags'] != p['node_freeform_tags']:
                    report.append(f'BLOCKED pool {key}: pool and node tags differ.')
                pools[new_key] = p
                pool_states[new_key] = deployed
                move(old_address, f'{prefix}module.cluster[{json.dumps(cluster, ensure_ascii=False)}].module.workers[0].{suffix}[{json.dumps(p["name"], ensure_ascii=False)}]')
        cluster_keys = {p['cluster_ref'].get('key') for p in pools.values()}
        if None in cluster_keys:
            raise ValueError('External cluster references are blocked in this release.')
        if len(cluster_keys) > 1:
            raise ValueError('All worker pools must reference one cluster; split the configuration and review state moves separately.')
        if cluster_keys:
            cluster_key = next(iter(cluster_keys))
            if cluster_key not in (clusters or {}).get('clusters', {}):
                raise ValueError('Worker cluster must be included in clusters_configuration.')
            _, cluster_state = previous('oci_containerengine_cluster', cluster_key)
            cluster_level = clusters['clusters'][cluster_key]['cis_level']
            for pool_key, pool in pools.items():
                if pool.get('cis_level', '1') == '2' and cluster_level != '2':
                    raise ValueError('Worker CIS level 2 cannot inherit cluster CIS level 1; review cluster policy before migration.')
                # Existing pools in another compartment cannot silently change ownership.
                pool_state = pool_states[pool_key]
                if pool_state['compartment_id'] != cluster_state['compartment_id']:
                    raise ValueError('Worker compartment differs from the cluster compartment; migration is blocked.')
                for field in ['cluster_ref','cis_level','compartment_id','image_type']:
                    pool.pop(field, None)
            result['workers_configuration'] = {'cluster_ref':{'key':cluster_key}, 'worker_pools':pools}
        else:
            result['workers_configuration'] = None
    orphaned = [a for a,r in resources.items() if a.startswith(prefix) and r['type'] in TYPES and re.fullmatch(re.escape(prefix) + r'oci_containerengine_(?:cluster|node_pool|virtual_node_pool)\.these\[.*\]',a) and a not in seen]
    if orphaned:
        raise ValueError(f'State has legacy resources absent from configuration: {orphaned}')
    report.extend([
        'CIS levels materialized using legacy per-object default 1. Review any intended default_cis_level=2 correction explicitly.',
        'Run Terraform 1.5.7 init/plan and check_plan.py before applying. This tool does not prove no-replacement migration.',
        'Review inherited tags, labels, metadata, placement and upstream ignored updates. Unsupported combinations remain blocked.',
    ])
    return result, moves, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--state-json', type=Path, required=True)
    parser.add_argument('--module-address', default='')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    try:
        config, moves, report = convert(json.loads(args.config.read_text()), json.loads(args.state_json.read_text()), args.module_address)
        args.output_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
        def write(name, value):
            path = args.output_dir / name
            with path.open('x') as stream:
                path.chmod(0o600)
                stream.write(value)
        write('converted.tfvars.json', json.dumps(config, indent=2) + '\n')
        write('moves.json', json.dumps(moves, indent=2) + '\n')
        # Addresses already contain their own quoted indices; escape template markers.
        def literal_address(a):
            return a.replace('${', '$${').replace('%{', '%%{')
        write('migration.tf', '\n'.join('moved {\n  from = ' + literal_address(m['from']) + '\n  to = ' + literal_address(m['to']) + '\n}\n' for m in moves))
        write('REVIEW.txt', '\n'.join(report) + '\n')
        print(f'Wrote review-only inputs and {len(moves)} explicit moves to {args.output_dir}. No state changed.')
    except (ValueError, KeyError, OSError) as exc:
        parser.exit(1, f'Migration stopped: {exc}\n')


if __name__ == '__main__':
    main()
