import copy
import importlib.util
from pathlib import Path
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools'


def load(name):
    spec=importlib.util.spec_from_file_location(name, TOOLS / (name+'.py'))
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


migrate=load('migrate')
checker=load('check_plan')


class MigrationTests(unittest.TestCase):
    def fixture(self):
        config={'clusters_configuration':{'default_compartment_id':'COMP','clusters':{'C':{
            'name':'cluster','is_enhanced':True,
            'networking':{'vcn_id':'VCN','api_endpoint_subnet_id':'API','services_subnet_id':['LB']},
        }}},'workers_configuration':{'node_pools':{'P':{
            'cluster_id':'C','name':'pool-name','networking':{'workers_subnet_id':'WORKERS'},
            'node_config_details':{'node_shape':'VM.Standard.E4.Flex'},
        }}}}
        resources=[
            {'address':'module.oke[0].oci_containerengine_cluster.these["C"]','type':'oci_containerengine_cluster','mode':'managed','values':{'id':'cluster-id','type':'ENHANCED_CLUSTER','compartment_id':'ocid1.compartment.oc1..test','kubernetes_version':'v1.33.1'}},
            {'address':'module.oke[0].oci_containerengine_node_pool.these["P"]','type':'oci_containerengine_node_pool','mode':'managed','values':{
                'id':'pool-id','compartment_id':'ocid1.compartment.oc1..test','kubernetes_version':'v1.33.1',
                'node_config_details':[{'size':3}], 'node_source_details':[{'image_id':'image-id'}],
            }},
        ]
        return config, {'values':{'root_module':{'child_modules':[{'resources':resources}]}}}

    def test_pin_deployed_defaults_and_nested_addresses(self):
        c,s=self.fixture(); converted,moves,report=migrate.convert(c,s,'module.oke[0]')
        pool=converted['workers_configuration']['worker_pools']['P']
        self.assertEqual(converted['cluster_configuration']['cni_type'], 'flannel')
        self.assertNotIn('cluster_ref', converted['workers_configuration'])
        for removed in ['cluster_ref','cis_level','compartment_id','image_type','ssh_public_key_path']:
            self.assertNotIn(removed, pool)
        self.assertTrue(pool['disable_default_cloud_init'])
        self.assertEqual(pool['size'],3)
        self.assertEqual(pool['image_id'],'image-id')
        self.assertEqual(pool['kubernetes_version'],'v1.33.1')
        self.assertEqual(moves[1]['to'],'module.oke[0].module.cluster["cluster"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["pool-name"]')
        self.assertTrue(report)
        self.assertIn('node_pools',c['workers_configuration']) # No caller mutation.

    def test_uniform_placement_uses_flat_schema(self):
        c,s=self.fixture()
        c['workers_configuration']['node_pools']['P']['node_config_details']['placement'] = [
            {'availability_domain':1, 'fault_domain':2, 'enable_preemptible_node':True},
            {'availability_domain':2, 'fault_domain':2, 'enable_preemptible_node':True},
        ]
        result,_,_=migrate.convert(c,s,'module.oke[0]')
        pool=result['workers_configuration']['worker_pools']['P']
        self.assertEqual(pool['placement_ads'], [1,2])
        self.assertEqual(pool['placement_fds'], ['FAULT-DOMAIN-2'])
        self.assertTrue(pool['preemptible_config']['enable'])
        self.assertNotIn('placement_configs', pool)

    def test_heterogeneous_placement_rejected(self):
        c,s=self.fixture()
        c['workers_configuration']['node_pools']['P']['node_config_details']['placement'] = [
            {'availability_domain':1,'fault_domain':1}, {'availability_domain':2,'fault_domain':2},
        ]
        with self.assertRaisesRegex(ValueError,'heterogeneous placement'):
            migrate.convert(c,s,'module.oke[0]')

    def test_cluster_defaults_split_and_deprecated_options_removed(self):
        c,s=self.fixture()
        c['clusters_configuration'].update({'default_defined_tags':{'scope.tag':'shared'},'default_freeform_tags':{'owner':'shared'}})
        c['clusters_configuration']['clusters']['C']['options'] = {'add_ons':{'dashboard_enabled':False,'tiller_enabled':False},'admission_controller':{'pod_policy_enabled':True}}
        result,_,_=migrate.convert(c,s,'module.oke[0]')
        cluster=result['cluster_configuration']
        for location in [cluster, cluster['options']['persistent_volume_config'],cluster['options']['service_lb_config']]:
            self.assertEqual(location['defined_tags'], {'scope.tag':'shared'})
            self.assertEqual(location['freeform_tags'], {'owner':'shared'})
        self.assertNotIn('clusters_configuration', result)
        self.assertNotIn('add_ons', cluster['options'])
        self.assertNotIn('admission_controller', cluster['options'])

    def test_basic_cluster_migration_rejected(self):
        c,s=self.fixture()
        c['clusters_configuration']['clusters']['C']['is_enhanced']=False
        with self.assertRaisesRegex(ValueError, 'only enhanced clusters'):
            migrate.convert(c,s,'module.oke[0]')

    def test_deployed_basic_cluster_migration_rejected(self):
        c,s=self.fixture()
        s['values']['root_module']['child_modules'][0]['resources'][0]['values']['type']='BASIC_CLUSTER'
        with self.assertRaisesRegex(ValueError, 'only enhanced clusters'):
            migrate.convert(c,s,'module.oke[0]')

    def test_public_endpoint_migration_rejected(self):
        c,s=self.fixture()
        c['clusters_configuration']['clusters']['C']['networking']['is_api_endpoint_public']=True
        with self.assertRaisesRegex(ValueError,'public API endpoints'):
            migrate.convert(c,s,'module.oke[0]')

    def test_deployed_public_endpoint_migration_rejected(self):
        c,s=self.fixture()
        s['values']['root_module']['child_modules'][0]['resources'][0]['values']['endpoint_config']=[{'is_public_ip_enabled':True}]
        with self.assertRaisesRegex(ValueError,'public API endpoints'):
            migrate.convert(c,s,'module.oke[0]')

    def test_enabled_legacy_addon_migration_rejected(self):
        c,s=self.fixture()
        c['clusters_configuration']['clusters']['C']['options']={'add_ons':{'tiller_enabled':True}}
        with self.assertRaisesRegex(ValueError,'dashboard/Tiller must be disabled'):
            migrate.convert(c,s,'module.oke[0]')

    def test_external_cluster_rejected(self):
        c,s=self.fixture()
        c['workers_configuration']['node_pools']['P']['cluster_id']='ocid1.cluster.oc1..external'
        with self.assertRaisesRegex(ValueError,'External cluster'):
            migrate.convert(c,s,'module.oke[0]')

    def test_worker_compartment_mismatch_rejected(self):
        c,s=self.fixture()
        s['values']['root_module']['child_modules'][0]['resources'][1]['values']['compartment_id']='different'
        with self.assertRaisesRegex(ValueError,'compartment differs'):
            migrate.convert(c,s,'module.oke[0]')

    def test_legacy_tag_replacement_is_materialized(self):
        c,s=self.fixture()
        c['clusters_configuration']['default_defined_tags']={'Test.default':'global'}
        c['clusters_configuration']['clusters']['C']['defined_tags']={}
        result,_,_=migrate.convert(c,s,'module.oke[0]')
        self.assertEqual(result['cluster_configuration']['defined_tags'], {})
        self.assertEqual(result['cluster_configuration']['options']['persistent_volume_config']['defined_tags'], {'Test.default':'global'})
        self.assertNotIn('override_defaults', result['cluster_configuration'])

    def test_multiple_legacy_clusters_rejected(self):
        c,s=self.fixture()
        c['clusters_configuration']['clusters']['D']=copy.deepcopy(c['clusters_configuration']['clusters']['C'])
        with self.assertRaisesRegex(ValueError, 'exactly one legacy cluster'):
            migrate.convert(c,s,'module.oke[0]')

    def test_unknown_field_rejected(self):
        c,s=self.fixture();c['workers_configuration']['node_pools']['P']['node_config_details']['typo']=True
        with self.assertRaisesRegex(ValueError,'unknown fields'):migrate.convert(c,s,'module.oke[0]')

    def test_orphan_rejected(self):
        c,s=self.fixture();c['workers_configuration']['node_pools']={}
        with self.assertRaisesRegex(ValueError,'absent from configuration'):migrate.convert(c,s,'module.oke[0]')

    def test_occupied_destination_rejected(self):
        c,s=self.fixture();r=s['values']['root_module']['child_modules'][0]['resources']
        r.append({'address':'module.oke[0].module.cluster["cluster"].module.cluster[0].oci_containerengine_cluster.k8s_cluster','type':'oci_containerengine_cluster','mode':'managed','values':{}})
        with self.assertRaisesRegex(ValueError,'occupied'):migrate.convert(c,s,'module.oke[0]')

    def test_no_state_guessing(self):
        c,s=self.fixture();s['values']['root_module']={}
        with self.assertRaisesRegex(ValueError,'not found'):migrate.convert(c,s,'module.oke[0]')

    def test_plan_instead_of_state_rejected(self):
        with self.assertRaisesRegex(ValueError,'STATE'):migrate.inventory({'planned_values':{}})

    def test_module_address_injection_rejected(self):
        c,s=self.fixture()
        with self.assertRaisesRegex(ValueError,'module-address'):migrate.convert(c,s,'module.foo\nresource "bad"')

    def test_template_literal_escaping(self):
        self.assertEqual(migrate.hcl_string('${x}-%{if x}'),'"$${x}-%%{if x}"')

    def plan(self):
        return {'resource_changes':[
            {'address':'terraform_data.cluster_validation["C"]','type':'terraform_data','mode':'managed','change':{'actions':['no-op'],'after':{'input':{'resource_address':'module.cluster["C"].oci_containerengine_cluster.k8s_cluster','defined_tags':{},'freeform_tags':{'owner':'new'}}}}},
            {'address':'module.cluster["C"].oci_containerengine_cluster.k8s_cluster','type':'oci_containerengine_cluster','mode':'managed','change':{'actions':['no-op'],'after':{'defined_tags':{},'freeform_tags':{'owner':'new'}},'after_unknown':{}}},
        ]}

    def test_plan_accepts_matching_contract(self):
        self.assertEqual(checker.check(self.plan()),[])

    def test_preserve_reviewed_unchanged_defined_tag(self):
        plan = self.plan()
        change = plan['resource_changes'][1]['change']
        change['before'] = {'defined_tags': {'Default.owner': 'existing'}}
        change['after']['defined_tags'] = {'Default.owner': 'existing'}
        self.assertTrue(checker.check(plan))
        self.assertEqual(checker.check(plan, preserve_defined_tags=['Default.owner']), [])

    def test_preservation_does_not_allow_new_or_changed_tags(self):
        for before in [{}, {'Default.owner': 'old'}]:
            with self.subTest(before=before):
                plan = self.plan()
                change = plan['resource_changes'][1]['change']
                change['before'] = {'defined_tags': before}
                change['after']['defined_tags'] = {'Default.owner': 'new'}
                self.assertTrue(checker.check(plan, preserve_defined_tags=['Default.owner']))

    def test_preservation_does_not_override_requested_tag(self):
        plan = self.plan()
        plan['resource_changes'][0]['change']['after']['input']['defined_tags'] = {'Default.owner': 'new'}
        change = plan['resource_changes'][1]['change']
        change['before'] = {'defined_tags': {'Default.owner': 'old'}}
        change['after']['defined_tags'] = {'Default.owner': 'old'}
        self.assertTrue(checker.check(plan, preserve_defined_tags=['Default.owner']))

    def test_preservation_does_not_relax_freeform_tags(self):
        plan = self.plan()
        plan['resource_changes'][1]['change']['after']['freeform_tags']['extra'] = 'old'
        self.assertTrue(checker.check(plan, preserve_defined_tags=['extra']))

    def test_preservation_does_not_allow_unknown_tags(self):
        plan = self.plan()
        plan['resource_changes'][1]['change']['after_unknown']['defined_tags'] = True
        self.assertTrue(checker.check(plan, preserve_defined_tags=['Default.owner']))

    def test_plan_rejects_ignored_update(self):
        plan=self.plan();plan['resource_changes'][1]['change']['after']['freeform_tags']={'owner':'old'}
        self.assertTrue(any('ignore_changes' in e for e in checker.check(plan)))

    def test_plan_rejects_replacement(self):
        plan=self.plan();plan['resource_changes'][1]['change']['actions']=['delete','create']
        self.assertTrue(any('replacement' in e for e in checker.check(plan)))

    def test_plan_rejects_ignored_placements(self):
        address = 'module.workers["P"].oci_containerengine_node_pool.tfscaled_workers["pool"]'
        plan = {'resource_changes': [
            {'address':'terraform_data.worker_validation["P"]','type':'terraform_data','mode':'managed','change':{'actions':['no-op'],'after':{'input':{'resource_address':address,'defined_tags':{},'freeform_tags':{},'placement_ads':['AD-1'],'placement_fds':['FAULT-DOMAIN-1'],'subnet_id':'subnet','capacity_reservation_id':None,'preemptible':{'enable':False,'is_preserve_boot_volume':False}}}}},
            {'address':address,'type':'oci_containerengine_node_pool','mode':'managed','change':{'actions':['no-op'],'after':{'defined_tags':{},'freeform_tags':{},'node_config_details':[{'placement_configs':[{'availability_domain':'AD-1','subnet_id':'subnet','fault_domains':['FAULT-DOMAIN-1']}]}]},'after_unknown':{}}},
        ]}
        self.assertEqual(checker.check(plan), [])
        placement = plan['resource_changes'][1]['change']['after']['node_config_details'][0]['placement_configs'][0]
        placement['capacity_reservation_id'] = ''
        self.assertEqual(checker.check(plan), [])
        placement.update({'fault_domains':['FAULT-DOMAIN-2'], 'capacity_reservation_id':'old-reservation'})
        errors = checker.check(plan)
        self.assertTrue(any('fault domains' in e for e in errors))
        self.assertTrue(any('capacity reservation' in e for e in errors))

    def test_plan_detects_filtered_numeric_ads(self):
        address='module.cluster["cluster"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["P"]'
        plan={'resource_changes':[
            {'address':'terraform_data.worker_validation["P"]','mode':'managed','type':'terraform_data','change':{'actions':['no-op'],'after':{'input':{'resource_address':address,'placement_ads_numbers':[1,3],'subnet_id':'subnet'}}}},
            {'address':address,'mode':'managed','type':'oci_containerengine_node_pool','change':{'actions':['no-op'],'after':{'node_config_details':[{'placement_configs':[{'availability_domain':'TEST:AD-1','subnet_id':'subnet'}]}]}}},
        ]}
        self.assertTrue(any('desired AD placement' in e for e in checker.check(plan)))

    def test_plan_rejects_ignored_gva_tags(self):
        address='module.cluster["cluster"].module.workers[0].oci_containerengine_node_pool.tfscaled_workers["P"]'
        plan={'resource_changes':[
            {'address':'terraform_data.worker_validation["P"]','mode':'managed','type':'terraform_data','change':{'actions':['no-op'],'after':{'input':{'resource_address':address,'placement_ads_numbers':[1],'subnet_id':'subnet','gva_secondary_vnics':[{'display_name':'data','defined_tags':{'Test.owner':'new'}}]}}}},
            {'address':address,'mode':'managed','type':'oci_containerengine_node_pool','change':{'actions':['no-op'],'after':{'node_config_details':[{'placement_configs':[{'availability_domain':'TEST:AD-1','subnet_id':'subnet'}]}],'secondary_vnics':[{'create_vnic_details':[{'defined_tags':{'Test.owner':'new'}}]}]}}},
        ]}
        self.assertEqual(checker.check(plan), [])
        plan['resource_changes'][1]['change']['after']['secondary_vnics'][0]['create_vnic_details'][0]['defined_tags']={'Test.owner':'old'}
        self.assertTrue(any('GVA defined_tags' in e for e in checker.check(plan)))

    def test_plan_rejects_unrelated_ownership(self):
        plan=self.plan();plan['resource_changes'].append({'address':'oci_core_vcn.bad','type':'oci_core_vcn','mode':'managed','change':{'actions':['create']}})
        self.assertTrue(any('non-OKE' in e for e in checker.check(plan)))


if __name__=='__main__':unittest.main()
