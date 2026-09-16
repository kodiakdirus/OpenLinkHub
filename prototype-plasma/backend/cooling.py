"""Validation and local recovery copies for existing fan-curve editing."""
import json
import math
import os
import re
from datetime import datetime, timezone
from pathlib import Path


def fan_points(value):
    if not isinstance(value, list) or not 2 <= len(value) <= 32:
        raise ValueError('Use between 2 and 32 curve points.')
    result = []
    for point in value:
        if not isinstance(point, dict) or set(point) != {'x', 'y'}:
            raise ValueError('Each curve point needs temperature and output.')
        x, y = point['x'], point['y']
        if any(type(v) not in (int, float) or not math.isfinite(v) for v in (x, y)):
            raise ValueError('Curve values must be finite numbers.')
        if not 0 <= x <= 200 or not 0 <= y <= 100:
            raise ValueError('Temperature must be 0–200°C and output 0–100%.')
        if result and (x <= result[-1]['x'] or y < result[-1]['y']):
            raise ValueError('Temperatures must increase; output must not decrease.')
        result.append({'x': x, 'y': y})
    return result


def catalog(payload):
    if not isinstance(payload, dict) or payload.get('code') != 200 or not isinstance(payload.get('data'), dict):
        raise ValueError('The service did not return a cooling-profile catalog.')
    result = {}
    for name, profile in payload['data'].items():
        if not re.fullmatch(r'[A-Za-z0-9]+', name) or not isinstance(profile, dict):
            continue
        try:
            fan_points(profile['points']['1'])
            if not isinstance(profile['points']['0'], list):
                continue
        except (KeyError, ValueError, TypeError):
            continue
        result[name] = profile
    return result


def backup_profile(name, profile):
    root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    folder = root / 'openlinkhub-plasma' / 'cooling-backups'
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    path = folder / f'{name}-{stamp}.json'
    with path.open('x', encoding='utf-8') as stream:
        os.chmod(path, 0o600)
        json.dump({'profile': name, 'before': profile}, stream, indent=2)
    return str(path)
