#!/usr/bin/env python3
"""Optional paid monthly-renewal registration for the separate ios-tools runner."""
import argparse
import json

from settings import ROOT, load


def manifest(team, device, settings):
    bundle = settings.get('bundleId')
    if not bundle:
        raise ValueError('Set bundleId in the Mac mirror\'s twitter.local.json before registering renewal')
    return dict(repo='custom-twitter', apps=[dict(
        name='twitter', root=str(ROOT), app='build/native/Release-iphoneos/Twitter.app',
        bundleIds=[bundle],
        inputs=['Twitter', 'Twitter.xcodeproj', 'Config', 'Resources', 'Vendor', 'scripts/build.py',
                'scripts/settings.py', 'twitter.local.json'],
        build=['/usr/bin/python3', 'scripts/build.py'],
        environment={'DEVELOPMENT_TEAM': team, 'SIGNING_DEVICE': device, 'BUNDLE_ID': bundle},
    )])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--team', required=True)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(manifest(args.team, args.device, load())))
    except ValueError as error:
        parser.error(str(error))
