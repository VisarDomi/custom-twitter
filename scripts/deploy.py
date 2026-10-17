#!/usr/bin/env python3
"""From Linux: sync to your trusted Mac, build in its GUI session, verify, and install in place."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess

from settings import CONFIG, ROOT, load, signing


class Deployment:
    def __init__(self, settings):
        self.settings = settings
        self.signing = signing(settings)
        self.host = settings.get('host')
        self.root = settings.get('remoteRoot')
        if not isinstance(self.host, str) or not self.host or self.host.startswith('-'):
            raise ValueError('Set host to your trusted SSH alias in twitter.local.json')
        if not isinstance(self.root, str) or not self.root.startswith('/') or self.root.rstrip('/') in ('', '/Users', '/tmp'):
            raise ValueError('Set remoteRoot to a dedicated absolute Mac project directory')
        self.root = self.root.rstrip('/')
        self.ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=yes']
        if settings.get('knownHosts'):
            self.ssh += ['-o', 'UserKnownHostsFile=' + str(Path(settings['knownHosts']).expanduser())]
        self.tools = settings.get('iosTools')
        if self.tools and (not isinstance(self.tools, str) or not self.tools.startswith('/')):
            raise ValueError('iosTools must be null or an absolute path on the Mac')

    def mac(self, arguments, **kwargs):
        return subprocess.run(self.ssh + [self.host, shlex.join(arguments)], check=True, **kwargs)

    def python(self, source):
        return self.mac(['/usr/bin/python3', '-'], input=source, text=True)

    def deliver(self, step):
        if self.tools:
            self.mac(['/usr/bin/python3', self.tools + '/renewal/scripts/deliver.py', step,
                      '--repo', 'custom-twitter', '--app', 'twitter', '--bundle', self.signing['bundleId']])

    def sync(self):
        self.python(f'''
from pathlib import Path
root = Path({self.root!r}).resolve()
home = Path.home().resolve()
if root == home or root in home.parents or root in (Path('/Users'), Path('/tmp')):
    raise SystemExit('Refusing to mirror into a home or system directory')
marker = root / '.custom-twitter-mirror'
if root.exists() and any(root.iterdir()) and not marker.exists():
    if not (root / 'Twitter.xcodeproj').is_dir() or not (root / 'Twitter/WebController.swift').is_file():
        raise SystemExit('Destination is not an empty directory or an existing Custom Twitter mirror')
root.mkdir(parents=True, exist_ok=True)
marker.touch()
''')
        # Explicit exclusions preserve output and local settings even on the first sync.
        subprocess.run([
            'rsync', '-az', '--delete', '--exclude=.git/', '--exclude=build/',
            '--exclude=*.local.json', '--exclude=__pycache__/', '--exclude=*.pyc',
            '--exclude=xcuserdata/', '--exclude=project.xcworkspace/',
            '--exclude=Config/Local.xcconfig', '--exclude=.custom-twitter-mirror',
            '-e', shlex.join(self.ssh), str(ROOT) + '/', self.host + ':' + shlex.quote(self.root + '/'),
        ], check=True)
        # Only the settings needed on the Mac, not workstation paths or host configuration.
        mac_settings = dict(self.signing)
        self.python('from pathlib import Path\n'
                    f'p = Path({self.root!r}) / "twitter.local.json"\n'
                    f'p.write_text({(json.dumps(mac_settings, indent=2) + chr(10))!r})\n'
                    'p.chmod(0o600)\n')
        if self.tools:
            self.mac(['/usr/bin/python3', self.tools + '/renewal/scripts/configure-refresh.py',
                      self.root, '--config', self.root + '/twitter.local.json'])

    def build(self):
        self.deliver('begin')
        # Discover the actual desktop user and UID instead of assuming either.
        self.python(f'''
import os, pathlib, pwd, subprocess
root = pathlib.Path({self.root!r})
user = pwd.getpwuid(os.getuid()).pw_name
console = pwd.getpwuid(os.stat('/dev/console').st_uid).pw_name
if user != console: raise SystemExit('Log into the Mac desktop as the SSH build user first')
(root / 'build').mkdir(exist_ok=True)
command = ['sudo', '-n', 'launchctl', 'asuser', str(os.getuid()),
           'sudo', '-n', '-H', '-u', user, '/usr/bin/caffeinate', '-i',
           '/usr/bin/python3', str(root / 'scripts/build.py')]
with (root / 'build/xcode.log').open('w') as log:
    result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
if result.returncode:
    print('\\n'.join((root / 'build/xcode.log').read_text().splitlines()[-40:]))
    raise SystemExit(result.returncode)
print('BUILD SUCCEEDED; build/xcode.log contains the full log')
''')
        self.deliver('built')

    def install(self):
        minimum = self.settings.get('minimumProfileDays', 1)
        if isinstance(minimum, bool) or not isinstance(minimum, (float, int)) or minimum < 0:
            raise ValueError('minimumProfileDays must be a nonnegative number')
        self.python(f'''
import datetime, fnmatch, pathlib, plistlib, subprocess
app = pathlib.Path({self.root!r}) / 'build/native/Release-iphoneos/Twitter.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == {self.signing['bundleId']!r}, 'Wrong bundle ID'
assert info['CFBundleDisplayName'] == 'Twitter', 'Wrong display name'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
assert profile['TeamIdentifier'] == [{self.signing['team']!r}], 'Wrong team'
assert {self.signing['device']!r} in profile.get('ProvisionedDevices', []), 'Device missing from profile'
entitlements = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
assert entitlements['application-identifier'] == {self.signing['team'] + '.' + self.signing['bundleId']!r}, 'Wrong signed identity'
assert fnmatch.fnmatchcase(entitlements['application-identifier'], profile['Entitlements']['application-identifier']), 'Profile does not authorize app'
assert profile['ExpirationDate'] > datetime.datetime.utcnow() + datetime.timedelta(days={minimum!r}), 'Profile expires too soon'
print('Verified bundle, signature, team, device and profile expiry:', profile['ExpirationDate'])
subprocess.run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', {self.signing['device']!r}, str(app)], check=True)
''')
        # Approval follows a completed direct installation, never an OTA publication.
        self.deliver('installed')
        self.mac(['xcrun', 'devicectl', 'device', 'process', 'launch',
                  '--device', self.signing['device'], self.signing['bundleId']])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('steps', nargs='+', choices=['sync', 'build', 'install'])
    args = parser.parse_args()
    if not CONFIG.exists():
        parser.error('Copy twitter.example.json to twitter.local.json and fill in your own settings')
    try:
        deployment = Deployment(load())
        for step in args.steps:
            getattr(deployment, step)()
    except (ValueError, RuntimeError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
