from copy import deepcopy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PyQt6.QtCore import QCoreApplication
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.controller import BackendController
from backend.cooling import fan_points, backup_profile

PROFILE = {'sensor': 2, 'zeroRpm': False, 'points': {'0': [{'x': 0, 'y': 70}, {'x': 100, 'y': 100}], '1': [{'x': 0, 'y': 20}, {'x': 60, 'y': 100}]}}
POINTS = [{'x': 0, 'y': 30}, {'x': 50, 'y': 100}]
def envelope(profile):
    return {'code': 200, 'status': 0, 'data': {'Radiator20': deepcopy(profile)}}

class CoolingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])
    def setUp(self):
        self.client = BackendController()
        self.client._mode = 'live'
        self.client._cooling_profiles = {'Radiator20': deepcopy(PROFILE)}
        self.reads, self.writes = [], []
        self.client._get_document = lambda path, callback: self.reads.append((path, callback))
        self.client._put_document = lambda path, body, callback: self.writes.append((path, body, callback))
        self.backup = patch('backend.controller.backup_profile', return_value='/tmp/previous.json').start()
        self.addCleanup(patch.stopall)
    def save(self):
        self.client.saveFanCurve('Radiator20', json.dumps(POINTS))
    def test_demo_does_not_read_or_write(self):
        self.client._mode = 'demo'
        self.client.loadCoolingProfiles(); self.save()
        self.assertFalse(self.reads or self.writes)
    def test_stale_profile_never_writes(self):
        self.save()
        changed = deepcopy(PROFILE); changed['sensor'] = 1
        self.reads.pop()[1](envelope(changed), None)
        self.assertFalse(self.writes)
        self.backup.assert_not_called()
        self.assertIn('changed elsewhere', self.client.coolingMessage)
    def test_backup_failure_prevents_write(self):
        self.backup.side_effect = OSError('disk full')
        self.save(); self.reads.pop()[1](envelope(PROFILE), None)
        self.assertFalse(self.writes)
        self.assertFalse(self.client.coolingBusy)
    def test_save_fan_only_and_require_full_readback(self):
        self.save(); self.reads.pop()[1](envelope(PROFILE), None)
        path, body, callback = self.writes.pop()
        self.assertEqual(path, '/api/temperatures/updateGraph')
        self.assertEqual(body, {'profile': 'Radiator20', 'updateType': 1, 'points': POINTS})
        self.backup.assert_called_once_with('Radiator20', PROFILE)
        callback({'status': 1}, None)
        self.assertTrue(self.client.coolingBusy)
        expected = deepcopy(PROFILE); expected['points']['1'] = POINTS
        self.reads.pop()[1](envelope(expected), None)
        self.assertEqual(self.client.commandStatus, 'verified')
        self.assertEqual(self.client.coolingProfiles['Radiator20']['points']['0'], PROFILE['points']['0'])
    def test_http_success_with_unchanged_curve_is_not_success(self):
        self.save(); self.reads.pop()[1](envelope(PROFILE), None)
        self.writes.pop()[2]({'status': 0}, None)
        self.reads.pop()[1](envelope(PROFILE), None)
        self.assertEqual(self.client.commandStatus, 'unverified')
    def test_timeout_readback_does_not_retry_mutation(self):
        self.save(); self.reads.pop()[1](envelope(PROFILE), None)
        self.writes[0][2](None, 'timeout')
        expected = deepcopy(PROFILE); expected['points']['1'] = POINTS
        self.reads.pop()[1](envelope(expected), None)
        self.assertEqual(len(self.writes), 1)
        self.assertEqual(self.client.commandStatus, 'verified')
    def test_mode_change_cancels_pending_precheck(self):
        self.save(); callback = self.reads.pop()[1]
        self.client.setMode('demo'); callback(envelope(PROFILE), None)
        self.assertFalse(self.writes)
    def test_duplicate_click_sends_one_precheck(self):
        self.save(); self.save()
        self.assertEqual(len(self.reads), 1)
    def test_invalid_points_never_start_command(self):
        for points in ([], [{'x': 0, 'y': 20}, {'x': 0, 'y': 50}], [{'x': 0, 'y': 50}, {'x': 60, 'y': 20}], [{'x': 0, 'y': 20}, {'x': 60, 'y': 101}], [{'x': 0, 'y': 20}, {'x': float('nan'), 'y': 100}]):
            with self.assertRaises(ValueError): fan_points(points)
        self.assertFalse(self.reads or self.writes)
    def test_recovery_copy_contains_original_and_is_private(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict('os.environ', {'XDG_STATE_HOME': folder}):
            path = Path(backup_profile('Radiator20', PROFILE))
            self.assertEqual(json.loads(path.read_text())['before'], PROFILE)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

if __name__ == '__main__': unittest.main()
