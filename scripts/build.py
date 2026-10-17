#!/usr/bin/env python3
"""Build Twitter.app on macOS; configure signing locally or through environment variables."""
import argparse
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
import platform
import subprocess

from settings import ROOT, signing


@contextmanager
def signing_lock():
    path = Path.home() / 'Library/Caches/ios-app-refresh/signing.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    inherited = os.environ.get('IOS_REFRESH_LOCK_FD')
    if inherited:
        actual, expected = os.fstat(int(inherited)), path.stat()
        if (actual.st_dev, actual.st_ino) != (expected.st_dev, expected.st_ino):
            raise RuntimeError('Invalid inherited signing lock')
        yield
    else:
        with path.open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError('Another app is signing; retry when it finishes')
            yield


def build(generic=False):
    if platform.system() != 'Darwin':
        raise RuntimeError('Build on the Mac, or run scripts/deploy.py from Linux')
    values = signing()
    settings_read = "let $settings = /** @type {HTMLScriptElement} */ (document.querySelector('script#cpftSettings'))"
    script = ROOT / 'Vendor/control-panel-for-twitter/script.js'
    if script.read_text().count(settings_read) != 1:
        raise RuntimeError('Vendored Control Panel settings contract changed; review WebController.swift first')
    with signing_lock():
        subprocess.run([
            'xcodebuild', '-project', 'Twitter.xcodeproj', '-scheme', 'Twitter',
            '-configuration', 'Release', '-sdk', 'iphoneos',
            '-destination', 'generic/platform=iOS' if generic else 'platform=iOS,id=' + values['device'],
            '-destination-timeout', '30',
            '-derivedDataPath', str(ROOT / 'build/DerivedData'),
            'SYMROOT=' + str(ROOT / 'build/native'),
            'DEVELOPMENT_TEAM=' + values['team'], 'PRODUCT_BUNDLE_IDENTIFIER=' + values['bundleId'],
            '-allowProvisioningUpdates', '-allowProvisioningDeviceRegistration', 'build',
        ], cwd=ROOT, check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generic', action='store_true', help='Build for an already provisioned device while it is disconnected')
    args = parser.parse_args()
    try:
        build(args.generic)
    except (ValueError, RuntimeError) as error:
        raise SystemExit(str(error))
