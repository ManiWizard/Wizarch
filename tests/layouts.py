"""Workspace targeting, persistence, and safe generated-rule regression checks."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("layouts", Path(__file__).resolve().parents[1] / "quickshell/services/layouts.py")
layouts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layouts)


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.config = Path(self.folder.name)
        self.workspaces = [{"id": 1, "name": "1", "tiledLayout": "dwindle"},
                           {"id": 20, "name": "wizarch-3-A", "tiledLayout": "dwindle"}]
        self.commands = []
        self.addCleanup(patch.stopall)
        patch.object(layouts.subprocess, "check_output", self.hyprctl).start()

    def hyprctl(self, args, **kwargs):
        self.commands.append(args)
        if args[1] == "workspaces":
            return json.dumps(self.workspaces)
        return "ok\n"

    def test_captured_named_workspace_is_saved_independently(self):
        # Another workspace is first/active; only the captured name is targeted.
        self.assertEqual(layouts.toggle("name:wizarch-3-A", self.config), "scrolling")
        self.assertIn('workspace = "name:wizarch-3-A"', self.commands[-1][2])
        store = self.config / "wizarch/workspace-layouts.json"
        self.assertEqual(json.loads(store.read_text()), {"name:wizarch-3-A": "scrolling"})
        self.assertIn('layout = "scrolling"', (self.config / "hypr/wizarch-layouts.lua").read_text())
        self.workspaces[1]["tiledLayout"] = "scrolling"
        self.assertEqual(layouts.toggle("name:wizarch-3-A", self.config), "dwindle")
        self.assertEqual(json.loads(store.read_text()), {})

    def test_unrelated_workspace_choice_survives_and_closed_workspace_uses_history(self):
        layouts.toggle("1", self.config)
        layouts.toggle("name:wizarch-3-A", self.config)
        self.workspaces.pop()
        self.assertEqual(layouts.toggle("name:wizarch-3-A", self.config), "dwindle")
        self.assertEqual(json.loads((self.config / "wizarch/workspace-layouts.json").read_text()), {"1": "scrolling"})

    def test_invalid_selectors_do_not_dispatch(self):
        for selector in ("0", "-1", "+1", "special:tray", "name:", "name:a\nb", "2147483648"):
            with self.assertRaises(ValueError):
                layouts.toggle(selector, self.config)
        self.assertEqual(self.commands, [])

    def test_rule_escaping_preserves_printable_unicode_and_quotes(self):
        selector = 'name:صفحۀ "Work" $HOME \\ test'
        text = layouts.fragment({selector: "scrolling"})
        self.assertIn('\\"Work\\"', text)
        self.assertIn("صفحۀ", text)
        self.assertIn("$HOME", text)
        self.assertEqual(text.count("hl.workspace_rule"), 1)

    def test_failed_compositor_change_does_not_publish_state(self):
        def fail(args, **kwargs):
            return json.dumps(self.workspaces) if args[1] == "workspaces" else "error: unavailable"
        with patch.object(layouts.subprocess, "check_output", fail):
            with self.assertRaises(RuntimeError):
                layouts.toggle("1", self.config)
        self.assertFalse((self.config / "wizarch/workspace-layouts.json").exists())
        self.assertFalse((self.config / "hypr/wizarch-layouts.lua").exists())

    def test_atomic_failure_preserves_prior_fragment(self):
        target=self.config/'hypr/wizarch-layouts.lua'
        target.parent.mkdir(parents=True);target.write_text('previous')
        with patch.object(layouts.os,'replace',side_effect=OSError('disk full')):
            with self.assertRaises(OSError):layouts.atomic_write(target,'candidate')
        self.assertEqual(target.read_text(),'previous')
        self.assertEqual([p.name for p in target.parent.iterdir()],['wizarch-layouts.lua'])


if __name__ == "__main__":
    unittest.main()
