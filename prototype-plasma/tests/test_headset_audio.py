import copy
import sys
import unittest
from unittest.mock import patch, Mock
from pathlib import Path
from PyQt6.QtCore import QCoreApplication
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.controller import BackendController
from backend.audio_session import validate_bands, filter_config, SessionEQ


def settings(revision="a" * 64, level=25, enabled=False):
    return dict(revision=revision, connected=True, battery=70, enabled=enabled, level=level)


class AudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.backend = BackendController()
        self.audio = self.backend.headsetAudio
        self.reads, self.writes, self.ipc = [], [], []
        self.backend._get_document = lambda p, c, **kw: self.reads.append(c)
        self.backend._put_document = lambda p, b, c, **kw: self.writes.append((p,b,c))
        self.audio.ipc = lambda b, c: self.ipc.append((b,c))

    def load(self, value=None):
        self.backend._mode = "live"; self.audio.refresh()
        self.reads.pop()({"apiVersion":"1.0", "kind":"headset-audio", "data":[{"deviceId":"2645", "settings":value or settings()}]}, None)

    def test_demo_never_touches_transport(self):
        self.audio.refresh(); self.audio.apply(); self.audio.applyEQ()
        self.assertEqual(self.reads+self.writes+self.ipc, [])

    def test_stale_revision_retains_draft_and_blocks_writes(self):
        self.load(); self.audio.setEnabled(True); self.audio.setLevel(30)
        self.load(settings("b"*64, 40))
        self.assertTrue(self.audio.stale); self.assertEqual(self.audio.level, 30)
        self.audio.apply(); self.assertEqual(self.writes, [])
        self.audio.revert(); self.assertEqual(self.audio.level, 40)

    def test_submit_once_and_verify_exact_result(self):
        self.load(); self.audio.setLevel(30); self.audio.setEnabled(True)
        self.audio.apply(); self.audio.apply()
        self.assertEqual(len(self.writes),1)
        path, body, callback = self.writes[0]
        self.assertEqual(path,"/api/v1/audio/headsets")
        self.assertEqual(body,dict(deviceId="2645",expectedRevision="a"*64,enabled=True,level=30))
        callback({"apiVersion":"1.0", "kind":"headset-audio-result", "data":{
            "deviceId":"2645","settings":settings("b"*64,30,True),"persistence":"verified"}},None)
        self.assertFalse(self.audio.sidetoneDirty)
        self.assertEqual(self.backend.commandStatus,"succeeded")

    def test_lost_response_preserves_draft_and_never_retries(self):
        self.load(); self.audio.setEnabled(True); self.audio.apply()
        self.writes[0][2](None,"timeout")
        self.assertTrue(self.audio.sidetoneDirty)
        self.assertFalse(self.audio.canApply)
        self.assertEqual(len(self.writes),1)

    def test_legacy_and_missing_response_disable_writes(self):
        self.load(); self.audio.setEnabled(True)
        self.audio.refresh(); self.reads.pop()(None,None)
        self.assertFalse(self.audio.canApply)
        self.assertTrue(self.audio.dirty)

    def test_invalid_ranges(self):
        for field,value in [("level",0),("level",True),("level",101),("battery",101),("connected",1),("revision","")]:
            state=settings();state[field]=value
            self.assertFalse(self.audio.valid(state))
        for bands in [[0]*9, [True]*10, [float("nan")]*10,[13]*10]:
            with self.assertRaises(ValueError): validate_bands(bands)

    def test_eq_revision_conflict_and_failure_keep_draft(self):
        self.backend._mode="live"
        state={"bands":[0.]*10,"enabled":False,"revision":"x"*64}
        self.audio.acceptEQ({"ok":True,"state":state},None)
        self.audio.setBand(1,3)
        self.audio.applyEQ()
        body,callback=self.ipc.pop()
        self.assertEqual(body["expectedRevision"],"x"*64)
        callback({"ok":False,"error":"stale"},None)
        self.assertTrue(self.audio.eqDirty); self.assertFalse(self.audio.canApplyEQ)

    def test_filter_is_stereo_pinned_and_has_headroom(self):
        config=filter_config('target"name',[6]+[0]*9)
        self.assertIn('"node.dont-fallback" = true', config)
        self.assertIn('"audio.position" = [ "FL" "FR" ]', config)
        self.assertIn('"Mult" = 0.501187', config)
        self.assertIn('target\\"name', config)

    def test_helper_rejects_unknown_commands_before_subprocess(self):
        helper=object.__new__(SessionEQ);helper.process=None;helper.bands=[0]*10;helper.target=""
        with self.assertRaises(ValueError):helper.command({"operation":"shell","expectedRevision":helper.state()["revision"]})

    def test_stream_migration_excludes_filter_playback(self):
        from backend import audio_session
        helper=object.__new__(SessionEQ)
        helper.sinks=lambda:[{"name":"hardware","index":7}]
        streams=[{"index":1,"sink":7,"properties":{"node.name":audio_session.SINK+".output"}},
                 {"index":2,"sink":7,"properties":{"node.name":"music"}},
                 {"index":3,"sink":8,"properties":{"node.name":"other-output"}}]
        calls=[]
        def command(*args):
            if args[:4]==("pactl","-f","json","list"):return __import__('json').dumps(streams)
            calls.append(args);return ""
        with patch.object(audio_session,"run",command): helper.move_streams("hardware",audio_session.SINK)
        self.assertEqual(calls,[("pactl","move-sink-input","2",audio_session.SINK)])

    def test_bypass_stops_graph_even_when_audio_server_fails(self):
        helper=object.__new__(SessionEQ);process=Mock();helper.process=process
        helper.sinks=Mock(side_effect=OSError("audio server disconnected"))
        with self.assertRaises(OSError):helper.disable()
        process.terminate.assert_called_once()
        self.assertIsNone(helper.process)

    def test_battery_is_matched_by_hid_identity(self):
        from backend.audio_session import headset_battery
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            entry=Path(directory)/"battery"; (entry/"device").mkdir(parents=True)
            (entry/"device/uevent").write_text("HID_ID=0003:00001B1C:00000A55\n")
            for name,value in [("capacity","97"),("present","1"),("status","Full")]:
                (entry/name).write_text(value)
            self.assertEqual(headset_battery(Path(directory))["percent"],97)
            (entry/"device/uevent").write_text("HID_ID=0003:00001B1C:00001BDC\n")
            self.assertEqual(headset_battery(Path(directory)),{})


if __name__ == "__main__": unittest.main()
