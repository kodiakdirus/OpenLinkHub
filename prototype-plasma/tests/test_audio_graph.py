import os
from pathlib import Path
import subprocess
import sys
import unittest


class AudioGraphTests(unittest.TestCase):
    def test_dragging_and_apply_in_both_styles(self):
        check=Path(__file__).with_name("qml_audio_graph_check.py")
        for style in ("Basic","org.kde.breeze"):
            with self.subTest(style=style):
                result=subprocess.run([sys.executable,str(check)],capture_output=True,text=True,timeout=15,
                    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_CONTROLS_STYLE=style))
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
