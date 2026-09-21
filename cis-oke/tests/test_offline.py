"""Plan the real wrapper/upstream resource code with deterministic data lookups.

Only OCI data sources are substituted in a disposable copy. Providers and OCI
resource schemas are real; no apply or real OCI request is performed. This tests
Terraform wiring, not live OCI reconciliation or replacement-free migration.
"""
import copy
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TF = os.environ.get('TERRAFORM_BIN', 'terraform')
spec = importlib.util.spec_from_file_location('check_plan', ROOT / 'tools/check_plan.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


def command(directory, *args, check=True):
    result = subprocess.run([TF, f'-chdir={directory}', *args], capture_output=True, text=True)
    if check and result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return result


def replace_data(directory, replacements):
    for file in directory.glob('*.tf'):
        text = file.read_text()
        for address, local in replacements.items():
            kind, name = address.split('.')[1:]
            text = re.sub(r'^data "' + kind + '" "' + name + r'" \{.*?^\}\n', '', text, flags=re.M | re.S)
            text = text.replace(address, local)
        file.write_text(text)


def config():
    return {
        'clusters_configuration': {'default_compartment_id': 'COMP', 'clusters': {'C': {
            'name': 'test-cluster', 'cluster_type': 'enhanced', 'cni_type': 'native', 'kubernetes_version': 'v1.33.1',
            'networking': {'vcn_id': 'VCN', 'api_endpoint_subnet_id': 'API', 'service_lb_subnet_ids': ['LB']},
        }}},
        'workers_configuration': {
            'cluster_ref': {'key': 'C'}, 'default_shape': 'VM.Standard.E4.Flex', 'default_size': 2,
            'default_disable_default_cloud_init': True, 'default_subnet_id': 'WORKERS', 'default_pod_subnet_id': 'PODS', 'default_pod_nsg_ids': ['POD-NSG'],
        'worker_pools': {'P': {}, 'V': {'mode': 'virtual-node-pool', 'shape': 'Pod.Standard.E4.Flex'}}},
        'compartments_dependency': {'COMP': {'id': 'ocid1.compartment.oc1..test'}},
        'network_dependency': {
            'vcns': {'VCN': {'id': 'ocid1.vcn.oc1..test'}},
            'network_security_groups': {'POD-NSG': {'id': 'ocid1.networksecuritygroup.oc1..test'}},
            'subnets': {k: {'id': 'ocid1.subnet.oc1..' + k.lower()} for k in ['API', 'LB', 'WORKERS', 'PODS']},
        },
    }


def main():
    version = json.loads(command(ROOT, 'version', '-json').stdout)['terraform_version']
    assert version.startswith('1.5.'), version
    with tempfile.TemporaryDirectory(prefix='cis-oke-offline-') as temp:
        base = Path(temp)
        subject = base / 'subject'
        shutil.copytree(ROOT, subject, ignore=shutil.ignore_patterns('.terraform*', 'tests', 'design', '*.tfstate*'))
        upstream = ROOT / '.terraform/modules/cluster'
        assert (upstream / 'data-images.tf').exists(), 'Run Terraform init in cis-oke first'
        shutil.copytree(upstream, base / 'upstream')
        for file in subject.glob('*.tf'):
            file.write_text(file.read_text().replace('git::https://github.com/oracle-terraform-modules/terraform-oci-oke.git?ref=v5.5.1', '../upstream'))
        # Reuse the installed official VCN dependency without registry lookup.
        file = base / 'upstream/module-network.tf'
        text = file.read_text().replace('source  = "oracle-terraform-modules/vcn/oci"', 'source = ' + json.dumps('../registry-vcn')).replace('  version = "4.0.0"', '')
        file.write_text(text)
        for name, installed in [('registry-vcn','cluster.vcn'),('registry-drg','cluster.drg'),('registry-logging','cluster.vcn.logging')]:
            shutil.copytree(ROOT / '.terraform/modules' / installed, base / name)
        for directory in [base / 'upstream',base / 'registry-vcn']:
            for file in directory.glob('*.tf'):
                text=file.read_text()
                text=re.sub(r'source\s*= "oracle-terraform-modules/drg/oci"\s*version\s*= "[^"]+"', 'source = "../registry-drg"',text)
                text=text.replace('github.com/oracle-terraform-modules/terraform-oci-logging','../registry-logging')
                file.write_text(text)
        replace_data(subject, {
            'data.oci_containerengine_cluster_option.cluster_options': 'local.fixture_cluster_options',
            'data.oci_containerengine_cluster.managed': 'local.fixture_managed',
            'data.oci_containerengine_cluster_option.worker_versions': 'local.fixture_worker_versions',
        })
        (subject / 'fixture.tf').write_text('''locals {
  fixture_cluster_options = {for k,c in local.clusters : k => { kubernetes_versions = ["v1.31.1", "v1.32.1", "v1.33.1"] }}
  fixture_managed = {for k,c in local.clusters : k => {id = module.cluster[k].cluster_id, name = c.name}}
  fixture_worker_versions = {for k,p in local.pools : k => {kubernetes_versions = ["v1.31.1", "v1.32.1", "v1.33.1"]}}
}
''')
        replace_data(base / 'upstream', {
            'data.oci_identity_availability_domains.all':'local.fixture_ads',
            'data.oci_containerengine_node_pool_option.oke':'local.fixture_catalog',
            'data.oci_containerengine_clusters.existing_cluster':'local.fixture_existing',
            'data.oci_containerengine_cluster_kube_config.private':'local.fixture_kubeconfig',
            'data.oci_containerengine_cluster_kube_config.public':'local.fixture_public',
            'data.oci_core_vcn.oke':'local.fixture_vcn',
            'data.oci_core_images.operator':'local.fixture_unused',
            'data.oci_core_images.bastion':'local.fixture_unused',
        })
        (base / 'upstream/fixture.tf').write_text('''locals {
  fixture_ads = {availability_domains=[{name="TEST:AD-1"},{name="TEST:AD-2"}]}
  fixture_catalog = [{sources=[
    {image_id="ocid1.image.oc1..old",source_name="Oracle-Linux-9.5-2025.01.01-0-OKE-1.33.1-100"},
    {image_id="ocid1.image.oc1..test",source_name="Oracle-Linux-9.6-2025.02.01-0-OKE-1.33.1-200"},
    {image_id="ocid1.image.oc1..arm",source_name="Oracle-Linux-9.6-aarch64-2025.03.01-0-OKE-1.33.1-300"},
    {image_id="ocid1.image.oc1..gpu",source_name="Oracle-Linux-9.6-GPU-2025.04.01-0-OKE-1.33.1-400"}
  ]}]
  fixture_existing = []
  fixture_public = []
  fixture_kubeconfig = [{content=yamlencode({clusters=[{cluster={server="https://10.0.0.1:6443",certificate-authority-data="dGVzdA=="}}]})}]
  fixture_vcn = [{cidr_blocks=["10.0.0.0/16"], ipv6cidr_blocks=[], byoipv6cidr_blocks=[], ipv6private_cidr_blocks=[]}]
  fixture_unused = []
}
''')
        workers = base / 'upstream/modules/workers'
        replace_data(workers, {
            'data.oci_identity_fault_domains.all': 'local.fixture_fds',
            'data.oci_core_shapes.oke': 'local.fixture_shapes',
            'data.oci_core_image.workers': 'local.fixture_images',
        })
        (workers / 'fixture.tf').write_text('''locals {
  fixture_fds = {for k,v in var.ad_numbers_to_names : k => {fault_domains = [{name="FAULT-DOMAIN-1"}, {name="FAULT-DOMAIN-2"}, {name="FAULT-DOMAIN-3"}]}}
  fixture_shapes = {shapes = []}
  fixture_images = {for k,p in local.enabled_worker_pools : k => {operating_system="Oracle Linux", operating_system_version="9.6"}}
}
''')
        network = base / 'upstream/modules/network'
        replace_data(network, {'data.oci_core_services.all_oci_services':'local.fixture_services','data.oci_waas_edge_subnets.waf_cidr_blocks':'local.fixture_waf'})
        (network / 'fixture.tf').write_text('locals {\n fixture_services = {services=[{cidr_block="all-test-services"}]}\n fixture_waf = []\n}\n')
        # A generated throwaway key configures the provider without real credentials.
        subprocess.run(['openssl', 'genrsa', '-out', str(base / 'dummy.pem'), '2048'], check=True, capture_output=True)
        (subject / 'provider_fixture.tf').write_text('''provider "oci" {
  auth = "APIKey"
  tenancy_ocid = "ocid1.tenancy.oc1..offline"
  user_ocid = "ocid1.user.oc1..offline"
  fingerprint = "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00"
  region = "us-ashburn-1"
  private_key_path = ''' + json.dumps(str(base / 'dummy.pem')) + '\n}\n')
        # No OCI data source may survive the fixture transformation.
        for directory in [subject, base / 'upstream', workers, network]:
            for file in directory.glob('*.tf'):
                assert not re.search(r'^data "oci_', file.read_text(), re.M), file
        command(subject, 'init', '-backend=false', '-input=false', '-no-color', f'-plugin-dir={ROOT / ".terraform/providers"}')
        command(subject, 'validate', '-no-color')

        def plan(name, inputs, expected_error=None, resources=None):
            if os.environ.get('ONLY_CASE') and name not in os.environ['ONLY_CASE'].split('|'):
                return
            path = base / 'input.tfvars.json'
            path.write_text(json.dumps({k:v for k,v in inputs.items() if k != 'expected_image'}))
            result = command(subject, 'plan', '-input=false', '-refresh=false', '-no-color', f'-var-file={path}', f'-out={base / "plan"}', check=False)
            if expected_error:
                assert result.returncode != 0 and expected_error in " ".join((result.stdout + result.stderr).split()), result.stdout + result.stderr
            else:
                assert result.returncode == 0, result.stdout + result.stderr
                document = json.loads(command(subject, 'show', '-json', str(base / 'plan')).stdout)
                if name == 'custom cloud-init':
                    assert len([r for r in document.get('resource_changes', []) if r['type'] == 'cloudinit_config']) == 1
                actual = [r['type'] for r in document.get('resource_changes', []) if r['mode'] == 'managed' and r['type'].startswith('oci_')]
                assert sorted(actual) == sorted(resources or []), actual
                assert not checker.check(document), checker.check(document)
                for resource in document.get('resource_changes', []):
                    if resource['type'] == 'cloudinit_config' and name.startswith('boot defaults '):
                        parts = resource['change']['after']['part']
                        assert len(parts) > 1, parts
                        assert any(p.get('filename') == '50-oke-config.yml' for p in parts), parts
                        if name == 'boot defaults with custom parts':
                            assert any(p.get('filename') == 'custom.yaml' for p in parts), parts
                    if resource['type'] == 'cloudinit_config' and name == 'global custom cloud-init':
                        parts = resource['change']['after']['part']
                        assert [part['filename'] for part in parts] == ['custom.yaml'], parts
                    if resource['type'] == 'cloudinit_config' and name == 'custom cloud-init':
                        parts = resource['change']['after']['part']
                        assert len(parts) == 1, parts
                        assert parts[0]['content'] == '#cloud-config\nwrite_files: []\n', parts
                        assert parts[0]['filename'] == 'custom.yaml', parts
                    if resource['type'] == 'oci_containerengine_cluster':
                        after = resource['change']['after']
                        endpoint = after['endpoint_config'][0]
                        assert endpoint['is_public_ip_enabled'] is False
                        if name == 'merged endpoint NSGs and distinct tag defaults':
                            assert set(endpoint['nsg_ids']) == {'ocid1.networksecuritygroup.oc1..test', 'ocid1.networksecuritygroup.oc1..extra'}
                            options = after['options'][0]
                            for target, values in [('cluster', after), ('pv', options['persistent_volume_config'][0]), ('service_lb', options['service_lb_config'][0])]:
                                for kind in ['defined', 'freeform']:
                                    tags = values[kind + '_tags']
                                    key = (lambda name: 'Test.' + name) if kind == 'defined' else (lambda name: name)
                                    assert tags[key('inherited')] == target
                                    assert tags[key('collision')] == 'override'
                                    assert tags[key('added')] == target
                        if name == 'replacement excludes inherited dependencies':
                            assert set(endpoint['nsg_ids']) == {'ocid1.networksecuritygroup.oc1..test'}
                            assert 'inherited' not in after['freeform_tags']
                            assert after['freeform_tags']['local'] == 'yes'
                    if resource['type'] == 'oci_containerengine_node_pool':
                        after = resource['change']['after']
                        if name == 'replacement excludes inherited dependencies':
                            assert after['node_config_details'][0]['nsg_ids'] == ['ocid1.networksecuritygroup.oc1..test']
                        if name.startswith('upstream image'):
                            assert after['node_source_details'][0]['image_id'] == inputs['expected_image']
                        if name == 'uniform per-pool SSH and encryption':
                            assert after['ssh_public_key'] == 'ssh-rsa example'
                            assert after['node_config_details'][0]['is_pv_encryption_in_transit_enabled'] is True
                        assert after['compartment_id'] == 'ocid1.compartment.oc1..test'
                        if after['node_shape'].endswith('.Flex'):
                            assert after['node_shape_config'][0]['memory_in_gbs'] == 16
                        assert after['node_eviction_node_pool_settings'][0]['is_force_delete_after_grace_duration'] is False
                        if name in ['custom cloud-init', 'global custom cloud-init']:
                            metadata = after.get('node_metadata') or {}
                            assert metadata.get('user_data') is None, metadata
                            pending = resource['change']['after_unknown'].get('node_metadata')
                            assert pending is True or isinstance(pending, dict) and pending.get('user_data') is True, pending
                        if name == 'GVA profiles':
                            vnics = after['secondary_vnics']
                            assert len(vnics) == 1, vnics
                            details = vnics[0]['create_vnic_details'][0]
                            assert details['subnet_id'] == 'ocid1.subnet.oc1..pods', details
                            assert details['nsg_ids'] == ['ocid1.networksecuritygroup.oc1..test'], details
                            assert details['application_resources'] == ['example.com/data'], details
                            assert details['ip_count'] == 32, details
                            assert details['display_name'] == 'data', details
                            assert details['assign_public_ip'] is False, details
                        if 'node_metadata' in after:
                            if name == 'raw user data':
                                assert after['node_metadata']['user_data'] == 'IyEvYmluL3NoCg=='
                            elif name not in ['custom cloud-init','global custom cloud-init'] and not name.startswith('boot defaults '):
                                assert after['node_metadata']['user_data'] == ''
                        else:
                            assert resource['change']['after_unknown']['node_metadata']
            print('PASS', name, flush=True)

        plan('empty configuration', {}, resources=[])
        full = config()
        plan('combined managed/virtual pools; only OKE OCI resources', full, resources=['oci_containerengine_cluster', 'oci_containerengine_node_pool', 'oci_containerengine_virtual_node_pool'])
        managed=copy.deepcopy(full)
        managed['workers_configuration']['worker_pools']={'P':{}}
        resources=['oci_containerengine_cluster','oci_containerengine_node_pool']
        enabled=copy.deepcopy(managed)
        enabled['workers_configuration'].pop('default_disable_default_cloud_init')
        plan('boot defaults enabled implicitly',enabled,resources=resources)
        overridden=copy.deepcopy(managed)
        overridden['workers_configuration']['worker_pools']['P']['disable_default_cloud_init']=False
        plan('boot defaults pool re-enables global disable',overridden,resources=resources)
        disabled=copy.deepcopy(enabled)
        disabled['workers_configuration']['worker_pools']['P']['disable_default_cloud_init']=True
        plan('pool disables boot defaults',disabled,resources=resources)
        cloud=copy.deepcopy(managed)
        cloud['workers_configuration']['worker_pools']['P']['cloud_init']=[{'content':'#cloud-config\nwrite_files: []\n','content_type':'text/cloud-config','filename':'custom.yaml'}]
        plan('custom cloud-init',cloud,resources=resources)
        global_cloud=copy.deepcopy(cloud)
        global_cloud['workers_configuration']['default_cloud_init']=[{'content':'#!/bin/sh\necho global','filename':'global.sh'}]
        plan('global custom cloud-init',global_cloud,resources=resources)
        combined=copy.deepcopy(cloud)
        combined['workers_configuration'].pop('default_disable_default_cloud_init')
        plan('boot defaults with custom parts',combined,resources=resources)
        raw=copy.deepcopy(managed)
        raw['workers_configuration']['worker_pools']['P']['node_metadata']={'user_data':'IyEvYmluL3NoCg=='}
        plan('raw user data',raw,resources=resources)
        conflict=copy.deepcopy(cloud)
        conflict['workers_configuration']['worker_pools']['P']['node_metadata']={'user_data':''}
        plan('conflicting cloud-init',conflict,'Specify cloud_init or node_metadata.user_data')
        gva=copy.deepcopy(managed)
        gva['workers_configuration'].pop('default_pod_subnet_id')
        gva['workers_configuration']['worker_pools']['P']['gva_secondary_vnics']={'data':{'subnet_id':'PODS','nsg_ids':['POD-NSG','ocid1.networksecuritygroup.oc1..test'],'application_resources':['example.com/data'],'ip_count':32}}
        plan('GVA profiles',gva,resources=resources)
        invalid=copy.deepcopy(gva)
        invalid['clusters_configuration']['clusters']['C']['cni_type']='flannel'
        plan('GVA requires native',invalid,'GVA secondary VNIC profiles require native CNI')
        invalid=copy.deepcopy(gva)
        invalid['workers_configuration']['worker_pools']['P']['gva_secondary_vnics']['data']['ip_count']=3
        plan('GVA IP count validation',invalid,'power-of-two ip_count')
        invalid=copy.deepcopy(gva)
        profiles=invalid['workers_configuration']['worker_pools']['P']['gva_secondary_vnics']
        profiles['data']['ip_count']=256
        profiles['extra']=copy.deepcopy(profiles['data'])
        plan('GVA total IP budget',invalid,'total ip_count per pool')
        invalid=copy.deepcopy(full)
        invalid['workers_configuration']['worker_pools']['V']['cloud_init']=cloud['workers_configuration']['worker_pools']['P']['cloud_init']
        plan('virtual cloud-init blocked',invalid,'supported only for managed node-pool mode')
        invalid=copy.deepcopy(full)
        invalid['workers_configuration']['worker_pools']['V']['gva_secondary_vnics']=gva['workers_configuration']['worker_pools']['P']['gva_secondary_vnics']
        plan('virtual GVA blocked',invalid,'supported only for managed node-pool mode')
        for label, pool_input, image in [
            ('latest x86', {}, 'test'),
            ('ARM', {'shape':'VM.Standard.A1.Flex'}, 'arm'),
            ('GPU', {'shape':'VM.GPU.A10.1'}, 'gpu'),
            ('custom', {'image_id':'ocid1.image.oc1..custom'}, 'custom'),
        ]:
            selection=copy.deepcopy(full)
            selection['workers_configuration']['worker_pools']['P'].update(pool_input)
            selection['expected_image']='ocid1.image.oc1..'+image
            plan('upstream image '+label,selection,resources=['oci_containerengine_cluster','oci_containerengine_node_pool','oci_containerengine_virtual_node_pool'])
        uniform=copy.deepcopy(full)
        uniform['workers_configuration']['worker_pools']['P'].update({'ssh_public_key':'ssh-rsa example','pv_transit_encryption':True})
        uniform['workers_configuration']['worker_pools']['Q']=copy.deepcopy(uniform['workers_configuration']['worker_pools']['P'])
        plan('uniform per-pool SSH and encryption',uniform,resources=['oci_containerengine_cluster','oci_containerengine_node_pool','oci_containerengine_node_pool','oci_containerengine_virtual_node_pool'])
        mixed=copy.deepcopy(uniform);mixed['workers_configuration']['worker_pools']['Q']['ssh_public_key']='ssh-rsa different'
        plan('different per-pool SSH blocked',mixed,'requires the same SSH key')
        mixed=copy.deepcopy(uniform);mixed['workers_configuration']['worker_pools']['Q']['pv_transit_encryption']=False
        plan('different per-pool encryption blocked',mixed,'requires the same SSH key')
        zero=copy.deepcopy(full)
        zero['workers_configuration']['worker_pools']={'P':{'size':0}}
        plan('zero-total pool outputs blocked',zero,'upstream hides pool outputs')
        merged = copy.deepcopy(full)
        merged['clusters_configuration']['default_api_endpoint_nsg_ids'] = ['POD-NSG']
        merged['clusters_configuration']['clusters']['C']['networking']['api_endpoint_nsg_ids'] = ['POD-NSG', 'ocid1.networksecuritygroup.oc1..extra']
        cluster_input = merged['clusters_configuration']['clusters']['C']
        cluster_input['options'] = {'persistent_volume_config': {}, 'service_lb_config': {}}
        for target, values in [('cluster', cluster_input), ('pv', cluster_input['options']['persistent_volume_config']), ('service_lb', cluster_input['options']['service_lb_config'])]:
            for kind in ['defined', 'freeform']:
                key = (lambda name: 'Test.' + name) if kind == 'defined' else (lambda name: name)
                merged['clusters_configuration'][f'default_{target}_{kind}_tags'] = {key('inherited'):target, key('collision'):'default'}
                values[kind + '_tags'] = {key('collision'):'override', key('added'):target}
        plan('merged endpoint NSGs and distinct tag defaults', merged, resources=['oci_containerengine_cluster', 'oci_containerengine_node_pool', 'oci_containerengine_virtual_node_pool'])
        replaced = copy.deepcopy(full)
        replaced['clusters_configuration'].update({'default_api_endpoint_nsg_ids':['UNRESOLVED-IGNORED'], 'default_image_signing_key_ids':['UNRESOLVED-KEY'], 'default_cluster_freeform_tags':{'inherited':'no'}})
        replaced['clusters_configuration']['clusters']['C'].update({'override_defaults':['networking.api_endpoint_nsg_ids','image_signing.kms_key_ids','freeform_tags'], 'freeform_tags':{'local':'yes'}, 'image_signing':{'kms_key_ids':[]}})
        replaced['clusters_configuration']['clusters']['C']['networking']['api_endpoint_nsg_ids']=['POD-NSG','ocid1.networksecuritygroup.oc1..test']
        replaced['workers_configuration']['default_nsg_ids']=['UNRESOLVED-IGNORED']
        for pool in replaced['workers_configuration']['worker_pools'].values():
            pool.update({'override_defaults':['nsg_ids'],'nsg_ids':['POD-NSG','ocid1.networksecuritygroup.oc1..test']})
        plan('replacement excludes inherited dependencies', replaced, resources=['oci_containerengine_cluster','oci_containerengine_node_pool','oci_containerengine_virtual_node_pool'])
        cluster = copy.deepcopy(full); cluster.pop('workers_configuration')
        plan('cluster only', cluster, resources=['oci_containerengine_cluster'])
        for name, mutate, error in [
            ('CIS cluster key', lambda c: c['clusters_configuration'].update({'default_cis_level':'2'}), 'CIS level 2 requires a customer-managed secret-encryption key'),
            ('CIS worker key', lambda c: c['clusters_configuration']['clusters']['C'].update({'cis_level':'2', 'encryption':{'kube_secret_kms_key_id':'ocid1.key.oc1..secret'}}), 'CIS level 2 requires a customer-managed worker volume key'),
            ('unsupported distinct tags', lambda c: c['workers_configuration']['worker_pools']['P'].update({'node_freeform_tags':{'different':'true'}}), 'cannot apply different pool and node tags'),
            ('unsupported LB list', lambda c: c['clusters_configuration']['clusters']['C']['networking'].update({'service_lb_subnet_ids':[]}), 'requires exactly one service_lb_subnet_ids'),
            ('basic cluster rejected', lambda c: c['clusters_configuration']['clusters']['C'].update({'cluster_type':'basic'}), 'Only enhanced clusters are supported'),
            ('unsupported cluster version', lambda c: c['clusters_configuration']['clusters']['C'].update({'kubernetes_version':'v1.99.0'}), 'kubernetes_version is not supported by OCI'),
            ('invalid CNI', lambda c: c['clusters_configuration']['clusters']['C'].update({'cni_type':'unknown'}), 'cni_type native/flannel'),
            ('virtual requires native', lambda c: c['clusters_configuration']['clusters']['C'].update({'cni_type':'flannel'}), 'virtual node pools require native CNI'),
            ('unsupported worker version', lambda c: c['workers_configuration']['worker_pools']['P'].update({'kubernetes_version':'v1.30.1',  'image_id':'ocid1.image.oc1..test'}), 'worker Kubernetes version must be supported'),
            ('duplicate placements', lambda c: c['workers_configuration']['worker_pools']['P'].update({'placement_ads':[1,1]}), 'must not contain duplicate AD numbers'),
            ('managed taints', lambda c: c['workers_configuration']['worker_pools']['P'].update({'taints':[{'key':'dedicated','value':'batch','effect':'NoSchedule'}]}), 'Taints are supported only for virtual-node-pool'),
            ('explicit virtual FDs', lambda c: c['workers_configuration']['worker_pools']['V'].update({'placement_fds':['FAULT-DOMAIN-1']}), 'explicit virtual fault domains are blocked'),
            ('empty virtual pod NSGs', lambda c: c['workers_configuration']['worker_pools']['V'].update({'pod_nsg_ids':[], 'override_defaults':['pod_nsg_ids']}), 'virtual pools require explicit nonempty pod_nsg_ids'),
        ]:
            invalid = copy.deepcopy(full); mutate(invalid); plan(name, invalid, error)
        newer = copy.deepcopy(full)
        newer['clusters_configuration']['clusters']['C']['kubernetes_version'] = 'v1.31.1'
        newer['workers_configuration']['worker_pools']['P'].update({'kubernetes_version':'v1.32.1',  'image_id':'ocid1.image.oc1..test'})
        plan('worker newer than control plane', newer, 'workers must be no newer than their control plane')
        duplicate = copy.deepcopy(full)
        duplicate['clusters_configuration']['clusters']['D'] = copy.deepcopy(duplicate['clusters_configuration']['clusters']['C'])
        plan('one cluster per resolved VCN', duplicate, 'only one configured cluster per resolved VCN')


if __name__ == '__main__':
    main()
