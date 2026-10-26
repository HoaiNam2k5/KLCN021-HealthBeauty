import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile
import json

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class PreservationTests(unittest.TestCase):
    def fixture(self):
        config = {'Env': ['Jwt__Key=test-only', 'Payments__SePay__Enabled=true'],
                  'Entrypoint': ['dotnet', 'HealthBeauty.Api.dll'], 'Cmd': None, 'WorkingDir': '/app'}
        container = {'Config': dict(config, Labels={'com.docker.compose.service': 'api'})}
        before = {'services': {'api': {'image': 'old', 'environment': {
            'Jwt__Key': 'test-only', 'Payments__SePay__Enabled': 'true'}},
            'sqlserver': {'image': 'sql', 'volumes': ['data:/var/opt/mssql']}}}
        after = copy.deepcopy(before)
        after['services']['api']['image'] = 'new'
        return before, after, {'healthbeauty-api': container}, {'healthbeauty-api': {'Config': config}}

    def test_image_only_change_preserves_configuration(self):
        release.check_config(*self.fixture())

    def test_missing_sepay_or_jwt_is_rejected(self):
        for key in ['Payments__SePay__Enabled', 'Jwt__Key']:
            args = self.fixture()
            del args[1]['services']['api']['environment'][key]
            with self.assertRaises(RuntimeError):
                release.check_config(*args)

    def test_sql_and_mount_changes_are_rejected(self):
        for service, key, value in [('sqlserver', 'image', 'other'), ('api', 'volumes', ['other:/app'])]:
            args = self.fixture()
            args[1]['services'][service][key] = value
            with self.assertRaises(RuntimeError):
                release.check_config(*args)

    def test_current_runtime_environment_drift_is_rejected(self):
        args = self.fixture()
        args[2]['healthbeauty-api']['Config']['Env'] = ['Jwt__Key=different']
        with self.assertRaises(RuntimeError):
            release.check_config(*args)

    def test_hashes_require_nonempty_valid_manifest(self):
        for invalid in ['', 'sha256sum: permission denied', '0' * 63 + '  /app/appsettings.json']:
            with self.assertRaises(RuntimeError):
                release.validate_hashes(invalid)
        valid = '0' * 64 + '  /app/appsettings.json\n'
        self.assertEqual(valid, release.validate_hashes(valid))

    def test_service_modes_are_explicit_and_legacy_states_keep_both(self):
        self.assertEqual(['api'], release.release_services('api'))
        self.assertEqual(['web'], release.release_services('web'))
        self.assertEqual(['api', 'web'], release.selected_services({}))
        for invalid in ['', 'web,api', 'api,sqlserver', 'api,web,caddy', 'api,api']:
            with self.assertRaises(RuntimeError):
                release.release_services(invalid)

    def test_api_only_override_and_rollback_cannot_recreate_web(self):
        state = {'services': ['api'], 'files': ['base.yaml'], 'rollback': 'rollback.yaml',
                 'targets': {'healthbeauty-api': {'service': 'api', 'old': 'api-old', 'new': 'api-new'},
                             'healthbeauty-web': {'service': 'web', 'old': 'web-old', 'new': 'web-old'}},
                 'untouched': {'healthbeauty-web': 'web-id'}, 'settings': 'settings', 'nginx': 'nginx'}
        self.assertEqual({'services': {'api': {'image': 'api-new'}}}, release.image_override(state, 'new'))
        self.assertEqual({'services': {'api': {'image': 'api-old'}}}, release.image_override(state, 'old'))
        with tempfile.TemporaryDirectory() as folder:
            private = Path(folder)
            api = {'Id': 'api-id', 'Image': 'api-old-id', 'Config': {'Env': ['Jwt__Key=fixture']}}
            web = {'Id': 'web-id', 'Image': 'web-old-id', 'Config': {'Env': []}}
            (private / 'api-container.json').write_text(json.dumps(api))
            (private / 'web-container.json').write_text(json.dumps(web))
            with patch.object(release, 'PRIVATE', private), \
                 patch.object(release, 'inspect', side_effect=lambda name: api if name.endswith('-api') else web), \
                 patch.object(release, 'compose') as compose, patch.object(release, 'probe'), \
                 patch.object(release, 'hashes', side_effect=['settings', 'nginx']), patch.object(release, 'save'):
                release.rollback(state)
                self.assertEqual(['base.yaml', 'rollback.yaml'], compose.call_args.args[0])
                self.assertEqual(('up', '-d', '--no-deps', '--no-build', '--pull', 'never', '--force-recreate', 'api'),
                                 compose.call_args.args[1:])

    def test_untouched_drift_stops_activate_and_rollback_before_compose(self):
        state = {'services': ['api'], 'untouched': {'healthbeauty-web': 'original-id'}}
        with patch.object(release, 'load', return_value=state), \
             patch.object(release, 'inspect', return_value={'Id': 'different-id'}), \
             patch.object(release, 'compose') as compose:
            with self.assertRaisesRegex(RuntimeError, 'Untouched service ID changed'):
                release.activate()
            compose.assert_not_called()
            with self.assertRaisesRegex(RuntimeError, 'Untouched service ID changed'):
                release.rollback(state)
            compose.assert_not_called()

    def test_web_only_override_and_rollback_cannot_recreate_api(self):
        state = {'services': ['web'], 'files': ['base.yaml'], 'rollback': 'rollback.yaml',
                 'targets': {'healthbeauty-api': {'service': 'api', 'old': 'api-old', 'new': 'api-old'},
                             'healthbeauty-web': {'service': 'web', 'old': 'web-old', 'new': 'web-new'}},
                 'untouched': {'healthbeauty-api': 'api-id'}, 'settings': 'settings', 'nginx': 'nginx'}
        self.assertEqual({'services': {'web': {'image': 'web-new'}}}, release.image_override(state, 'new'))
        self.assertEqual({'services': {'web': {'image': 'web-old'}}}, release.image_override(state, 'old'))
        with tempfile.TemporaryDirectory() as folder:
            private = Path(folder)
            api = {'Id': 'api-id', 'Image': 'api-old-id', 'Config': {'Env': ['Jwt__Key=fixture']}}
            web = {'Id': 'web-id', 'Image': 'web-old-id', 'Config': {'Env': []}}
            (private / 'api-container.json').write_text(json.dumps(api))
            (private / 'web-container.json').write_text(json.dumps(web))
            with patch.object(release, 'PRIVATE', private), \
                 patch.object(release, 'inspect', side_effect=lambda name: api if name.endswith('-api') else web), \
                 patch.object(release, 'compose') as compose, patch.object(release, 'probe'), \
                 patch.object(release, 'hashes', side_effect=['settings', 'nginx']), patch.object(release, 'save'):
                release.rollback(state)
                self.assertEqual(('up', '-d', '--no-deps', '--no-build', '--pull', 'never', '--force-recreate', 'web'),
                                 compose.call_args.args[1:])

    def test_web_only_api_drift_stops_mutation(self):
        state = {'services': ['web'], 'untouched': {'healthbeauty-api': 'original-id'}}
        with patch.object(release, 'load', return_value=state), \
             patch.object(release, 'inspect', return_value={'Id': 'different-id'}), \
             patch.object(release, 'compose') as compose:
            for operation in [release.activate, lambda: release.rollback(state)]:
                with self.assertRaisesRegex(RuntimeError, 'Untouched service ID changed'):
                    operation()
            compose.assert_not_called()

    def chains(self, api_files, web_files):
        return {name: {'Config': {'Labels': {'com.docker.compose.project': 'demo-api',
                'com.docker.compose.project.config_files': ','.join(str(release.STACK / path) for path in files)}}}
                for name, files in [('healthbeauty-api', api_files), ('healthbeauty-web', web_files)]}

    def test_active_chain_keeps_latest_single_service_override_in_either_direction(self):
        before = ['compose.yaml', 'compose.sepay.yaml', 'compose.release.yaml']
        after = before + ['compose.release.logo.yaml']
        with patch.object(Path, 'is_file', return_value=True):
            for api_files, web_files in [(before, after), (after, before), (after, after)]:
                self.assertEqual([str(release.STACK / path) for path in after],
                                 release.active_compose_files(self.chains(api_files, web_files)))

    def test_divergent_or_untrusted_compose_chains_are_rejected(self):
        with patch.object(Path, 'is_file', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'Divergent'):
                release.active_compose_files(self.chains(['compose.yaml', 'api.yaml'], ['compose.yaml', 'web.yaml']))
            for files in [['compose.yaml', 'compose.yaml'], ['../outside.yaml']]:
                with self.assertRaises(RuntimeError):
                    release.active_compose_files(self.chains(files, ['compose.yaml']))
            value = self.chains(['compose.yaml'], ['compose.yaml'])
            value['healthbeauty-web']['Config']['Labels']['com.docker.compose.project'] = 'another-project'
            with self.assertRaises(RuntimeError):
                release.active_compose_files(value)
        with patch.object(Path, 'is_file', return_value=False):
            with self.assertRaises(RuntimeError):
                release.active_compose_files(self.chains(['missing.yaml'], ['missing.yaml']))


if __name__ == '__main__':
    unittest.main()
