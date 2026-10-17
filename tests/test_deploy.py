"""Checks for data-preserving deployment, identity selection, and signing coordination."""
from contextlib import nullcontext
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import build
from deploy import Deployment
from renewal import manifest
from settings import signing

VALUES = dict(team='ABCDE12345', device='example-device', bundleId='com.example.MyTwitter')


class DeploymentTests(unittest.TestCase):
    def deployment(self, **extra):
        return Deployment(dict(VALUES, host='ios-build', remoteRoot='/Users/example/Developer/custom-twitter', **extra))

    @patch.dict(os.environ, {}, clear=True)
    def test_rejects_unconfigured_public_default(self):
        with self.assertRaisesRegex(ValueError, 'unique bundleId'):
            signing(dict(VALUES, bundleId='com.example.CustomTwitter'))

    @patch.dict(os.environ, {}, clear=True)
    def test_renewal_owns_configured_identity(self):
        app = manifest(VALUES['team'], VALUES['device'], VALUES)['apps'][0]
        self.assertEqual(app['bundleIds'], [VALUES['bundleId']])
        self.assertEqual(app['environment']['BUNDLE_ID'], VALUES['bundleId'])
        self.assertIn('twitter.local.json', app['inputs'])

    @patch.dict(os.environ, {}, clear=True)
    def test_failed_install_never_approves_or_launches(self):
        deployment = self.deployment(iosTools='/Users/example/Developer/ios-tools')
        deployment.python = Mock(side_effect=subprocess.CalledProcessError(1, ['install']))
        deployment.deliver = Mock()
        deployment.mac = Mock()
        with self.assertRaises(subprocess.CalledProcessError):
            deployment.install()
        deployment.deliver.assert_not_called()
        deployment.mac.assert_not_called()

    @patch.dict(os.environ, {}, clear=True)
    def test_direct_install_approves_only_after_device_command(self):
        deployment = self.deployment()
        events = []
        deployment.python = lambda source: events.append(('install', source))
        deployment.deliver = lambda step: events.append(('approve', step))
        deployment.mac = lambda args: events.append(('launch', args))
        deployment.install()
        self.assertEqual([item[0] for item in events], ['install', 'approve', 'launch'])
        self.assertIn("'install', 'app'", events[0][1])
        self.assertNotIn('uninstall', events[0][1])
        self.assertEqual(events[-1][1][-1], VALUES['bundleId'])

    @patch.dict(os.environ, {}, clear=True)
    def test_standalone_deploy_does_not_call_renewal_tools(self):
        deployment = self.deployment()
        deployment.mac = Mock()
        deployment.deliver('installed')
        deployment.mac.assert_not_called()

    @patch.dict(os.environ, {}, clear=True)
    def test_build_passes_private_identity_without_changing_project(self):
        with patch('build.platform.system', return_value='Darwin'), \
             patch('build.signing', return_value=VALUES), \
             patch('build.signing_lock', return_value=nullcontext()), \
             patch('build.subprocess.run') as run:
            build.build()
        arguments = run.call_args.args[0]
        self.assertIn('PRODUCT_BUNDLE_IDENTIFIER=' + VALUES['bundleId'], arguments)
        self.assertIn('DEVELOPMENT_TEAM=' + VALUES['team'], arguments)

    def test_inherited_lock_must_be_the_shared_lock(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            shared = home / 'Library/Caches/ios-app-refresh/signing.lock'
            shared.parent.mkdir(parents=True)
            shared.touch()
            with (home / 'different-lock').open('w') as wrong:
                with patch('build.Path.home', return_value=home), \
                     patch.dict(os.environ, {'IOS_REFRESH_LOCK_FD': str(wrong.fileno())}):
                    with self.assertRaisesRegex(RuntimeError, 'Invalid inherited'):
                        with build.signing_lock():
                            pass


if __name__ == '__main__':
    unittest.main()
