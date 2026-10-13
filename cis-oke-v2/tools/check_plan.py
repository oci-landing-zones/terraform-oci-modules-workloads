#!/usr/bin/env python3
"""Fail closed on destructive OKE migration or ignored desired tag/placement changes."""
import argparse
import json
import re
from pathlib import Path

OKE = {'oci_containerengine_cluster','oci_containerengine_node_pool','oci_containerengine_virtual_node_pool'}


def check(plan, module_address=''):
    prefix = module_address + '.' if module_address else ''
    errors = []
    changes = {r['address']:r for r in plan.get('resource_changes',[]) if r['address'].startswith(prefix)}
    for address,resource in changes.items():
        if resource['mode'] != 'managed':
            continue
        if resource['type'].startswith('oci_') and resource['type'] not in OKE:
            errors.append(f'{address}: unexpected ownership of non-OKE OCI resource')
        if resource['type'] in OKE and 'delete' in resource['change']['actions']:
            errors.append(f'{address}: deletion/replacement is not an approved migration')
    guards = [r for r in changes.values() if r['type'] == 'terraform_data' and 'resource_address' in ((r['change'].get('after') or {}).get('input') or {})]
    for guard in guards:
        wanted = (guard['change'].get('after') or {}).get('input') or {}
        if 'resource_address' not in wanted:
            continue
        address = prefix + wanted['resource_address']
        actual = changes.get(address)
        if actual is None:
            errors.append(f'{address}: expected resource missing from plan')
            continue
        after = actual['change'].get('after') or {}
        unknown = actual['change'].get('after_unknown') or {}
        for name in ['defined_tags', 'freeform_tags']:
            # Empty desired maps can remain computed until create (automatic OCI tags).
            if unknown.get(name):
                if 'create' not in actual['change']['actions']:
                    errors.append(f'{address}: {name} unknown; cannot verify migration')
                continue
            if (after.get(name) or {}) != (wanted.get(name) or {}):
                errors.append(f'{address}: desired {name} differ from plan; upstream ignore_changes may hide the update')
        if actual['type'] == 'oci_containerengine_cluster':
            options = (after.get('options') or [{}])[0]
            network = (options.get('kubernetes_network_config') or [{}])[0]
            for field in ['pods_cidr', 'services_cidr']:
                if wanted.get(field) is not None and network.get(field) != wanted[field]:
                    errors.append(f'{address}: desired {field} absent/different in plan; upstream ignores network config updates')
        if actual['type'] in ['oci_containerengine_node_pool', 'oci_containerengine_virtual_node_pool']:
            virtual = actual['type'] == 'oci_containerengine_virtual_node_pool'
            if not virtual and 'gva_secondary_vnics' in wanted:
                desired_vnics = wanted['gva_secondary_vnics']
                planned_vnics = after.get('secondary_vnics') or []
                unknown_vnics = unknown.get('secondary_vnics') or []
                if len(desired_vnics) != len(planned_vnics):
                    errors.append(f'{address}: desired GVA profiles differ from plan')
                for index, (desired, planned) in enumerate(zip(desired_vnics, planned_vnics)):
                    details = (planned.get('create_vnic_details') or [{}])[0]
                    pending = unknown_vnics[index] if isinstance(unknown_vnics, list) and index < len(unknown_vnics) else {}
                    tags_unknown = (pending.get('create_vnic_details') or [{}])[0].get('defined_tags')
                    if tags_unknown and 'create' in actual['change']['actions']:
                        continue
                    if tags_unknown or (details.get('defined_tags') or {}) != desired['defined_tags']:
                        errors.append(f'{address}: desired GVA defined_tags differ from plan; upstream may ignore the update')
            nodes = after.get('node_config_details') or [{}]
            placements = after.get('placement_configurations') if virtual else nodes[0].get('placement_configs')
            if placements is None:
                if 'create' not in actual['change']['actions']:
                    errors.append(f'{address}: placement unknown; cannot verify migration')
                continue
            if 'placement_ads_numbers' in wanted:
                matches = [re.search(r'(\d+)$', p['availability_domain']) for p in placements]
                if not all(matches):
                    errors.append(f'{address}: cannot verify upstream AD-number translation')
                    continue
                ads = [int(m.group(1)) for m in matches]
            else:
                ads = [p['availability_domain'] for p in placements]
            if sorted(ads) != sorted(wanted.get('placement_ads_numbers', wanted.get('placement_ads', []))):
                errors.append(f'{address}: desired AD placement differs from plan')
            for p in placements:
                if p.get('subnet_id') != wanted['subnet_id']:
                    errors.append(f'{address}: desired placement subnet differs from plan')
                desired_fds = (wanted.get('placement_fds') or []) if virtual else wanted.get('placement_fds')
                if desired_fds is not None and sorted(p.get('fault_domain' if virtual else 'fault_domains') or []) != sorted(desired_fds):
                    errors.append(f'{address}: desired fault domains differ from plan')
                if not virtual and 'capacity_reservation_id' in wanted and p.get('capacity_reservation_id') != wanted['capacity_reservation_id']:
                    errors.append(f'{address}: desired capacity reservation differs from plan')
                if not virtual and 'preemptible' in wanted:
                    actual_preempt = p.get('preemptible_node_config') or []
                    if bool(actual_preempt) != wanted['preemptible']['enable']:
                        errors.append(f'{address}: desired preemptible placement differs from plan')
                    elif actual_preempt:
                        action = (actual_preempt[0].get('preemption_action') or [{}])[0]
                        if action.get('is_preserve_boot_volume') != wanted['preemptible']['is_preserve_boot_volume']:
                            errors.append(f'{address}: desired boot-volume preservation differs from plan')
    if not guards and any(r.get('type') in OKE for r in changes.values()):
        errors.append('No wrapper validation guards found; verify --module-address and the target module version')
    return errors


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('plan_json',type=Path)
    p.add_argument('--module-address',default='')
    args=p.parse_args()
    errors=check(json.loads(args.plan_json.read_text()),args.module_address)
    if errors:
        p.exit(1,'Plan blocked:\n'+'\n'.join('- '+e for e in errors)+'\n')
    print('Plan checks passed. Review all remaining in-place changes before apply; this is not a live migration rehearsal.')


if __name__=='__main__':main()
