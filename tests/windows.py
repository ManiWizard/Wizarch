"""Regression checks for individual restore, address reuse, and geometry safety."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("windows", Path(__file__).resolve().parents[1] / "quickshell/services/windows.py")
windows = importlib.util.module_from_spec(spec)
spec.loader.exec_module(windows)


class WindowControlsTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "windows.json"
        self.monitors = [{"id": 0, "name": "A", "x": 0, "y": 0, "width": 1920, "height": 1080,
                          "scale": 1, "focused": True, "reserved": [8, 8, 8, 8], "activeWorkspace": {"name": "1"}},
                         {"id": 1, "name": "B", "x": 1920, "y": 0, "width": 1920, "height": 1080,
                          "scale": 1, "focused": False, "reserved": [8, 8, 8, 8], "activeWorkspace": {"name": "2"}}]
        self.clients = [{"address": "0xa", "stableId": "A", "pid": 10, "workspace": {"name": "1"}, "monitor": 0,
                         "mapped": True, "floating": True, "pinned": False, "fullscreen": 0, "fullscreenClient": 0,
                         "at": [100, 100], "size": [640, 480]}]
        self.active = "0xa"
        self.calls = []
        self.addCleanup(patch.stopall)
        patch.object(windows, "query", self.query).start()
        patch.object(windows, "dispatch", self.dispatch).start()

    def query(self, what):
        return copy.deepcopy({"clients": self.clients, "monitors": self.monitors, "activewindow": {"address": self.active}}[what])

    def dispatch(self, method, **params):
        self.calls.append((method, params))
        client = next(c for c in self.clients if "address:" + c["address"] == params["window"])
        if method == "window.move" and "workspace" in params:
            name = params["workspace"].removeprefix("name:")
            client["workspace"]["name"] = name
            if name != windows.TRAY:
                client["monitor"] = next(m["id"] for m in self.monitors if m["activeWorkspace"]["name"] == name)
        elif method == "window.move":
            client["at"] = [params["x"], params["y"]]
        elif method == "window.resize":
            client["size"] = [params["x"], params["y"]]
        elif method == "window.float":
            client["floating"] = params["action"] == "on"
        elif method == "window.pin":
            if not client["floating"]:
                raise RuntimeError("Window does not qualify to be pinned")
            client["pinned"] = params["action"] == "on"
        elif method == "window.fullscreen_state":
            client["fullscreen"], client["fullscreenClient"] = params["internal"], params["client"]
        elif method == "focus":
            self.active = client["address"]

    def run_action(self, action, *args):
        controls = windows.Controls(self.path)
        getattr(controls, action)(*args)
        controls.save()

    def test_restore_here_preserves_fullscreen_and_pin(self):
        self.clients[0].update(pinned=True, fullscreen=2, fullscreenClient=2)
        self.run_action("minimize")
        self.assertEqual(self.clients[0]["workspace"]["name"], windows.TRAY)
        self.assertFalse(self.clients[0]["pinned"])
        self.monitors[0]["focused"], self.monitors[1]["focused"] = False, True
        self.run_action("restore")
        self.assertEqual(self.clients[0]["workspace"]["name"], "2")
        self.assertEqual(self.clients[0]["at"], [2020, 100])
        self.assertEqual(self.clients[0]["size"], [640, 480])
        self.assertEqual(self.clients[0]["fullscreen"], 2)
        self.assertTrue(self.clients[0]["pinned"])

    def test_restore_selected_does_not_restore_other_minimized_windows(self):
        self.run_action("minimize")
        self.clients.append(dict(copy.deepcopy(self.clients[0]), address="0xb", stableId="B", pid=11, workspace={"name": "1"}))
        self.active = "0xb"
        self.run_action("minimize")
        self.run_action("restore", "0xa")
        self.assertEqual(self.clients[1]["workspace"]["name"], windows.TRAY)
        self.run_action("restore")
        self.assertEqual(self.clients[1]["workspace"]["name"], "1")

    def test_latest_restore_and_closed_window_cleanup(self):
        self.run_action("minimize")
        self.clients.append(dict(copy.deepcopy(self.clients[0]), address="0xb", stableId="B", pid=11, workspace={"name": "1"}))
        self.active = "0xb"
        self.run_action("minimize")
        self.run_action("restore")
        self.assertEqual(self.active, "0xb")
        self.assertEqual(self.clients[0]["workspace"]["name"], windows.TRAY)
        self.clients.pop(0)
        self.run_action("restore")
        self.assertEqual(json.loads(self.path.read_text())["minimized"], {})

    def test_reused_address_does_not_receive_old_state(self):
        self.run_action("minimize")
        self.clients[0].update(stableId="new", pid=20, floating=False)
        self.run_action("restore")
        self.assertFalse(self.clients[0]["floating"])
        self.assertEqual(self.clients[0]["workspace"]["name"], "1")

    def test_legacy_tray_windows_restore_without_history(self):
        self.clients[0]["workspace"]["name"] = windows.TRAY
        self.run_action("restore")
        self.assertEqual(self.clients[0]["workspace"]["name"], "1")

    def test_no_active_or_invalid_target_is_noop(self):
        self.active = "0x0"
        self.run_action("minimize")
        self.run_action("pop")
        self.run_action("restore", "0xdead")
        self.assertEqual(self.calls, [])

    def test_special_windows_are_not_reminimized(self):
        self.clients[0]["workspace"]["name"] = windows.TRAY
        self.run_action("minimize")
        self.assertEqual(self.calls, [])

    def test_captured_target_survives_focus_change(self):
        self.clients.append(dict(copy.deepcopy(self.clients[0]), address="0xb", stableId="B", pid=11))
        self.active = "0xb"
        self.run_action("pop", "0xa")
        self.assertTrue(self.clients[0]["pinned"])
        self.assertFalse(self.clients[1]["pinned"])
        self.run_action("minimize", "0xa")
        self.assertEqual(self.clients[0]["workspace"]["name"], windows.TRAY)
        self.assertEqual(self.clients[1]["workspace"]["name"], "1")

    def test_popup_returns_to_tiled_or_floating_state(self):
        for floating in (False, True):
            self.clients[0].update(floating=floating, pinned=False, fullscreen=1, fullscreenClient=1, at=[100, 100], size=[640, 480])
            self.run_action("pop")
            self.assertTrue(self.clients[0]["floating"])
            self.assertTrue(self.clients[0]["pinned"])
            self.run_action("pop")
            self.assertEqual(self.clients[0]["floating"], floating)
            self.assertFalse(self.clients[0]["pinned"])
            self.assertEqual(self.clients[0]["fullscreen"], 1)
            if floating:
                self.assertEqual(self.clients[0]["at"], [100, 100])

    def test_minimize_popped_window_then_restore_and_unpop(self):
        self.clients[0]["floating"] = False
        self.run_action("pop")
        self.run_action("minimize")
        self.run_action("restore")
        self.assertTrue(self.clients[0]["pinned"])
        self.run_action("pop")
        self.assertFalse(self.clients[0]["floating"])

    def test_geometry_fits_scaled_rotated_or_removed_monitor(self):
        monitor = dict(self.monitors[1], width=1920, height=1080, scale=2, transform=1)
        size, at = windows.floating_geometry({"size": [800, 2000], "offset": [-100, 9999]}, monitor)
        self.assertEqual(size, [524, 944])
        self.assertEqual(at, [1928, 8])
        self.run_action("minimize")
        self.monitors.pop(1)
        self.run_action("restore")
        self.assertEqual(self.clients[0]["workspace"]["name"], "1")

    def test_failed_move_keeps_recovery_snapshot(self):
        original = self.dispatch
        def failing(method, **params):
            if method == "window.move":
                raise RuntimeError("compositor unavailable")
            original(method, **params)
        with patch.object(windows, "dispatch", failing):
            with self.assertRaises(RuntimeError):
                self.run_action("minimize")
        self.assertIn("0xa", json.loads(self.path.read_text())["minimized"])


if __name__ == "__main__":
    unittest.main()
