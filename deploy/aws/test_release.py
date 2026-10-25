import copy
import importlib.util
from pathlib import Path
import unittest

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


if __name__ == '__main__':
    unittest.main()
