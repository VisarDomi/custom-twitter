"""Local build/deploy settings. No account sessions or signing keys belong here."""
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'twitter.local.json'


def load():
    return json.loads(CONFIG.read_text()) if CONFIG.exists() else {}


def signing(settings=None):
    settings = load() if settings is None else settings
    values = {
        'team': os.environ.get('DEVELOPMENT_TEAM') or settings.get('team'),
        'device': os.environ.get('SIGNING_DEVICE') or settings.get('device'),
        'bundleId': os.environ.get('BUNDLE_ID') or settings.get('bundleId'),
    }
    for key, value in values.items():
        if not isinstance(value, str) or not value or value.startswith('YOUR_'):
            raise ValueError('Set ' + key + ' in twitter.local.json or the corresponding build environment')
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', values['bundleId']):
        raise ValueError('bundleId must be a reverse-DNS application identifier')
    if values['bundleId'] == 'com.example.CustomTwitter':
        raise ValueError('Choose your own unique bundleId instead of com.example.CustomTwitter')
    return values
