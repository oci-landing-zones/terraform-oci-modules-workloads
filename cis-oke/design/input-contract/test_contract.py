"""Exercise the proposed contract with Terraform 1.5; no OCI calls or applies."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2] / 'modules/configuration'
TF = os.environ.get('TERRAFORM_BIN', 'terraform')


def run(*args):
    return subprocess.run([TF, f'-chdir={ROOT}', *args], text=True, capture_output=True)


def assert_preserved(source, target, path='contract', exact_empty=False):
    # Terraform object conversion can silently drop unknown fields: reject that.
    if exact_empty and source == {}:
        assert target == {}, (path, target)
    if path.endswith('.override_defaults'):
        assert set(source) == set(target), (path, source, target)
        return
    if isinstance(source, dict):
        for key, value in source.items():
            assert key in target, f'{path}.{key} was dropped'
            assert_preserved(value, target[key], f'{path}.{key}', exact_empty)
    elif isinstance(source, list):
        assert len(source) == len(target), path
        for index, value in enumerate(source):
            assert_preserved(value, target[index], f'{path}[{index}]', exact_empty)
    else:
        assert source == target, (path, source, target)


def fixture():
    return {
        'clusters_configuration': {'default_compartment_id':'COMP', 'clusters':{'C':{
            'name':'test', 'networking':{'vcn_id':'VCN','api_endpoint_subnet_id':'API','service_lb_subnet_ids':['LB']},
        }}},
        'workers_configuration': {'cluster_ref':{'key':'C'}, 'default_shape':'VM.Standard.E4.Flex',
            'default_subnet_id':'WORKERS', 'default_size':3,
            'worker_pools':{'P':{},'V':{'mode':'virtual-node-pool','shape':'Pod.Standard.E4.Flex','pod_subnet_id':'PODS'}}},
    }


def check(name, config, error=None, expected=None, collections=None):
    with tempfile.TemporaryDirectory(prefix='cis-oke-contract-') as tmp:
        inputs, plan = Path(tmp) / 'inputs.tfvars.json', Path(tmp) / 'plan'
        inputs.write_text(json.dumps(config))
        result = run('plan', '-input=false', '-refresh=false', '-no-color', f'-var-file={inputs}', f'-out={plan}')
        if error:
            assert result.returncode != 0, f'{name}: unexpectedly accepted'
            assert error in " ".join((result.stdout + result.stderr).split()), result.stdout + result.stderr
        else:
            assert result.returncode == 0, result.stdout + result.stderr
            result = run('show', '-json', str(plan))
            assert result.returncode == 0, result.stderr
            data = json.loads(result.stdout)
            assert not data.get('resource_changes'), 'Contract must never provision resources'
            value = data['planned_values']['outputs']['contract']['value']
            assert_preserved(config, value)
            for key, cluster in (config.get('clusters_configuration') or {}).get('clusters', {}).items():
                actual = value['clusters_configuration']['clusters'][key]
                assert actual['cluster_type'] == (cluster.get('cluster_type') or 'enhanced')
                assert actual['cni_type'] == (cluster.get('cni_type') or 'native')
            if expected is not None:
                normalized = data['planned_values']['outputs']['normalized_worker_pools']['value']
                assert_preserved(expected, normalized, 'normalized_worker_pools', True)
            if collections is not None:
                assert collections == data['planned_values']['outputs']['cluster_collections']['value']
        print(f'PASS {name}')


if __name__ == '__main__':
    version = json.loads(run('version', '-json').stdout)['terraform_version']
    assert version.startswith('1.5.'), version
    assert run('init', '-backend=false', '-input=false', '-no-color').returncode == 0
    check('empty', {}, expected={})
    full=fixture()
    check('managed and virtual defaults', full, expected={'P':{'mode':'node-pool','os':'Oracle Linux','os_version':'9','max_pods_per_node':31,'image_type':'oke','cluster_ref':{'key':'C'}}})
    check('cluster only', {'clusters_configuration':full['clusters_configuration']})
    override=copy.deepcopy(full)
    override['workers_configuration'].update({'default_memory':32, 'default_node_labels':{'team':'platform','tier':'general'}, 'default_ssh_public_key':'shared'})
    override['workers_configuration']['worker_pools']['P'].update({'size':0,'memory':64,'node_labels':{'tier':'batch'}, 'ssh_public_key':'specific','force_node_delete':False,'image_id':'custom-image','max_pods_per_node':42,'placement_ads':[2],'node_metadata':{'user_data':'abc'}})
    override['workers_configuration']['worker_pools']['P']['disable_default_cloud_init']=True
    check('pool overrides and inferred custom image', override, expected={'P':{'size':0,'memory':64,'node_labels':{'team':'platform','tier':'batch'},'ssh_public_key':'specific','image_type':'custom','max_pods_per_node':42,'placement_ads':[2],'node_metadata':{'user_data':'abc'}}})
    override['workers_configuration']['worker_pools']['P'].update({'node_labels':{},'image_id':None})
    check('empty maps inherit and null image selects OKE', override, expected={'P':{'node_labels':{'team':'platform','tier':'general'},'image_type':'oke'}})
    virtual=copy.deepcopy(full)
    virtual['workers_configuration']['worker_pools']['V']['taints']=[{'key':'dedicated','value':'batch','effect':'NoSchedule'}]
    check('virtual taints supported',virtual)
    for mode in ['instance','cluster-network','unsupported']:
        invalid=copy.deepcopy(full);invalid['workers_configuration']['default_mode']=mode
        check('unsupported mode '+mode, invalid, 'Supported pool modes')
    invalid=copy.deepcopy(virtual)
    invalid['workers_configuration']['worker_pools']['P']['taints']=virtual['workers_configuration']['worker_pools']['V']['taints']
    check('managed taints rejected',invalid,'Taints are supported only')
    invalid=copy.deepcopy(full);invalid['workers_configuration']['cluster_ref']={'key':'ocid1.cluster.oc1..external'}
    check('external cluster rejected',invalid,'external clusters are not supported')
    invalid=copy.deepcopy(full);invalid.pop('clusters_configuration')
    check('worker-only cluster reference rejected',invalid,'external clusters are not supported')
    invalid=copy.deepcopy(full);invalid['workers_configuration'].pop('default_shape')
    check('missing shape rejected',invalid,'requires shape and subnet_id')
    invalid=copy.deepcopy(full);invalid['workers_configuration']['worker_pools']['V'].pop('pod_subnet_id')
    check('virtual pod subnet required',invalid,'Virtual pools require')
    for cni in ['native','NATIVE',None]:
        invalid=copy.deepcopy(full)
        c=invalid['clusters_configuration']['clusters']['C']
        if cni is not None:c['cni_type']=cni
        c['options']={'kubernetes_network_config':{'pods_cidr':'10.244.0.0/16'}}
        check('native CIDR rejected '+str(cni),invalid,'Native CNI clusters must omit')
    flannel=copy.deepcopy(full);flannel['clusters_configuration']['clusters']['C'].update({'cluster_type':'basic','cni_type':'flannel','options':{'kubernetes_network_config':{'pods_cidr':'10.244.0.0/16'}}})
    check('basic cluster rejected',flannel,'Only enhanced clusters are supported')
    flannel['clusters_configuration']['clusters']['C']['cluster_type']='enhanced'
    check('enhanced flannel preserved',flannel)
    for compartment in [None,'   ']:
        invalid=copy.deepcopy(full);invalid['clusters_configuration']['default_compartment_id']=compartment
        check('missing or blank cluster compartment '+str(compartment),invalid,'Each cluster requires compartment_id')
    for field,value,error in [('cluster_type','bad','Only enhanced clusters are supported'),('cis_level','3','Cluster CIS levels')]:
        invalid=copy.deepcopy(full);invalid['clusters_configuration']['clusters']['C'][field]=value
        check('invalid cluster '+field,invalid,error)
    # Assert removed public knobs cannot accidentally return in a later schema edit.
    schema=(ROOT/'variables.tf').read_text().split('variable "workers_configuration"')[1].split('variable "enable_output"')[0]
    for field in ['default_name','default_cis_level','default_cluster_ref','default_compartment_id','default_image_id','image_type','ssh_public_key_path','default_max_pods_per_node','default_placement_ads','default_placement_fds','default_capacity_reservation_id','default_node_metadata','default_eviction_grace_duration','default_force_node_delete','default_node_cycling_enabled','default_node_cycling_max_surge','default_node_cycling_max_unavailable','default_preemptible_config','default_taints']:
        assert field not in schema, field
    print('PASS removed public knobs stay absent')

    merging=fixture()
    merging['workers_configuration'].update({'default_nsg_ids':['A','B'],'default_pod_nsg_ids':['POD'], 'default_node_labels':{'team':'platform','tier':'default'}})
    merging['workers_configuration']['worker_pools']['P'].update({'nsg_ids':['B','C'],'pod_nsg_ids':[], 'node_labels':{'tier':'pool'}})
    check('worker collections merge and deduplicate',merging,expected={'P':{'nsg_ids':['A','B','C'],'pod_nsg_ids':['POD'],'node_labels':{'team':'platform','tier':'pool'}}})
    merging['workers_configuration']['worker_pools']['P'].update({'override_defaults':['nsg_ids','pod_nsg_ids','node_labels'],'nsg_ids':['C','C'],'node_labels':{},'pod_nsg_ids':[]})
    check('worker replacement and explicit clearing',merging,expected={'P':{'nsg_ids':['C'],'pod_nsg_ids':[],'node_labels':{}}})
    for field in ['unknown','shape','placement_ads','node_metadata','freeform_tags']:
        bad=fixture();bad['workers_configuration']['worker_pools']['P']['override_defaults']=[field]
        check('invalid worker override '+field,bad,'Worker override_defaults supports')
    # Cover all cluster map and list paths, including empty replacement values.
    cm=fixture();cc=cm['clusters_configuration'];c=cc['clusters']['C']
    c['options']={'persistent_volume_config':{},'service_lb_config':{}}
    expected_maps={}
    for target, container, prefix in [('cluster',c,''),('pv',c['options']['persistent_volume_config'],'options.persistent_volume_config.'),('service_lb',c['options']['service_lb_config'],'options.service_lb_config.')]:
        for kind in ['defined','freeform']:
            field=kind+'_tags';cc['default_'+target+'_'+field]={'baseline':'keep','collision':'default'}
            container[field]={'collision':'local','extra':'value'}
            expected_maps[prefix+field]={'baseline':'keep','collision':'local','extra':'value'}
    cc['default_api_endpoint_nsg_ids']=['A','B'];c['networking']['api_endpoint_nsg_ids']=['B','C']
    cc['default_image_signing_key_ids']=['K1'];c['image_signing']={'kms_key_ids':['K1','K2']}
    check('all cluster collections merge',cm,collections={'C':{'maps':expected_maps,'lists':{'networking.api_endpoint_nsg_ids':['A','B','C'],'image_signing.kms_key_ids':['K1','K2']}}})
    c['override_defaults']=list(expected_maps)+['networking.api_endpoint_nsg_ids','image_signing.kms_key_ids']
    for container in [c,c['options']['persistent_volume_config'],c['options']['service_lb_config']]:
        container['defined_tags']={};container['freeform_tags']={}
    c['networking']['api_endpoint_nsg_ids']=[];c['image_signing']['kms_key_ids']=[]
    check('all cluster collections cleared explicitly',cm,collections={'C':{'maps':{k:{} for k in expected_maps},'lists':{'networking.api_endpoint_nsg_ids':[],'image_signing.kms_key_ids':[]}}})
    for field in ['unknown','networking.service_lb_subnet_ids','defined_tags','options.persistent_volume_config.freeform_tags','networking.api_endpoint_nsg_ids','image_signing.kms_key_ids']:
        bad=fixture();bad['clusters_configuration']['clusters']['C']['override_defaults']=[field]
        check('invalid cluster override '+field,bad,'Cluster override_defaults must name')

    wm=fixture();fields=['defined_tags','freeform_tags','node_defined_tags','node_freeform_tags','node_labels']
    for field in fields:
        wm['workers_configuration']['default_'+field]={'global':'keep','collision':'old'}
        wm['workers_configuration']['worker_pools']['P'][field]={'local':'add','collision':'new'}
    check('all worker maps merge by key',wm,expected={'P':{field:{'global':'keep','local':'add','collision':'new'} for field in fields}})
    wm['workers_configuration']['worker_pools']['P']['override_defaults']=fields
    for field in fields:wm['workers_configuration']['worker_pools']['P'][field]={}
    check('all worker maps clear explicitly',wm,expected={'P':{field:{} for field in fields}})

    custom=fixture()
    custom['workers_configuration']['worker_pools']['P'].update({
        'cloud_init':[{'content':'#!/bin/sh\necho example','filename':'init.sh'}],
        'gva_secondary_vnics':{'data':{'subnet_id':'DATA','nsg_ids':['NSG'],'application_resources':['example.com/data'],'nic_index':0,'ip_count':32,'assign_ipv6ip':True,'ipv6_cidrs':['2001:db8::/64'],'defined_tags':{'Test.role':'data'}}},
    })
    check('cloud-init and GVA fields survive schema conversion',custom,expected={'P':{'cloud_init':[{'content':'#!/bin/sh\necho example','filename':'init.sh','content_type':'text/x-shellscript','merge_type':'list(append)+dict(no_replace,recurse_list)+str(append)'}]}})

    boot=fixture()
    check('boot scripts enabled by default',boot,expected={'P':{'disable_default_cloud_init':False}})
    boot['workers_configuration']['default_disable_default_cloud_init']=True
    boot['workers_configuration']['worker_pools']['P']['disable_default_cloud_init']=False
    check('pool boot switch overrides global disable',boot,expected={'P':{'disable_default_cloud_init':False},'V':{'disable_default_cloud_init':True}})
    boot['workers_configuration']['worker_pools']['P']['disable_default_cloud_init']=None
    check('null boot switch inherits global',boot,expected={'P':{'disable_default_cloud_init':True}})

    raw=fixture()
    raw['workers_configuration']['worker_pools']['P']['node_metadata']={'user_data':'encoded'}
    check('raw data cannot replace enabled boot defaults',raw,'raw user_data also requires')

    global_boot=fixture()
    part={'content':'#!/bin/sh\necho global','content_type':'text/x-shellscript','filename':'global.sh','merge_type':'list(append)+dict(no_replace,recurse_list)+str(append)'}
    local_part=dict(part,content='#!/bin/sh\necho local',filename='local.sh')
    global_boot['workers_configuration']['default_cloud_init']=[part]
    global_boot['workers_configuration']['worker_pools']['P']['cloud_init']=[local_part]
    check('local boot parts replace globals',global_boot,expected={'P':{'cloud_init':[local_part]},'V':{'cloud_init':[]}})
    global_boot['workers_configuration']['worker_pools']['P']['cloud_init']=None
    check('null cloud-init inherits globals',global_boot,expected={'P':{'cloud_init':[part]}})
    global_boot['workers_configuration']['worker_pools']['P'].pop('cloud_init')
    check('omitted cloud-init inherits globals',global_boot,expected={'P':{'cloud_init':[part]}})
    global_boot['workers_configuration']['worker_pools']['P']['cloud_init']=[local_part]
    check('pool replaces global boot parts',global_boot,expected={'P':{'cloud_init':[local_part]}})
    global_boot['workers_configuration']['worker_pools']['P']['cloud_init']=[]
    check('pool clears global boot parts',global_boot,expected={'P':{'cloud_init':[]}})
    global_boot['workers_configuration']['worker_pools']['P'].update({'cloud_init':None,'disable_default_cloud_init':True,'node_metadata':{'user_data':'raw'}})
    check('global boot parts conflict with raw data',global_boot,'Specify cloud_init or node_metadata.user_data')

    invalid_cloud_override=fixture()
    invalid_cloud_override['workers_configuration']['worker_pools']['P'].update({'cloud_init':[], 'override_defaults':['cloud_init']})
    check('cloud-init cannot use override_defaults',invalid_cloud_override,'Worker override_defaults supports')

    bm=fixture()
    bm['workers_configuration']['worker_pools']['P'].update({'shape':'BM.Standard.E5.192','pv_transit_encryption':True})
    check('BM with pool encryption blocked',bm,'Affected pools: P')
    bm['workers_configuration']['worker_pools']['P'].pop('pv_transit_encryption')
    bm['workers_configuration']['default_pv_transit_encryption']=True
    check('BM with inherited encryption blocked',bm,'not supported on bare-metal BM shapes')
    bm['workers_configuration']['worker_pools']['P']['pv_transit_encryption']=False
    check('BM explicitly disables inherited encryption',bm,expected={'P':{'pv_transit_encryption':False}})
    bm['workers_configuration'].pop('default_pv_transit_encryption')
    bm['workers_configuration']['worker_pools']['P'].pop('pv_transit_encryption')
    check('BM without encryption accepted',bm)
    bm['workers_configuration']['default_shape']='BM.Standard.E5.192'
    bm['workers_configuration']['worker_pools']['P'].pop('shape')
    bm['workers_configuration']['worker_pools']['P']['pv_transit_encryption']=True
    check('inherited BM shape with encryption blocked',bm,'Affected pools: P')
    bm['workers_configuration']['worker_pools']['P']['shape']='VM.Standard.E5.Flex'
    check('VM encryption accepted',bm,expected={'P':{'pv_transit_encryption':True}})
