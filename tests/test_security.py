#!/usr/bin/python3 -I
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
import trackpad  # noqa: E402


class UdevEmbed(unittest.TestCase):
    def test_embed_matches_file(self):
        rules = (ROOT / "udev" / "70-xuanping-trackpad-hidraw.rules").read_text()
        script = (ROOT / "bin" / "trackpad-pack").read_text()
        match = re.search(
            r"IFS= read -r -d '' UDEV_RULE << 'EOF' \|\| true\n(.*?)\nEOF\n",
            script,
            re.S,
        )
        self.assertIsNotNone(match)
        embedded = match.group(1) + "\n"
        self.assertEqual(embedded, rules)
        self.assertNotIn("ATTRS{name}", rules)
        self.assertNotIn("ATTRS{product}", rules)
        self.assertIn('TAG+="uaccess"', rules)
        self.assertNotIn("GROUP=", rules)
        self.assertNotIn("pkexec", script)
        self.assertIn("PATH=/usr/bin:/bin", script)
        self.assertNotIn("$(cat <<", script)
        self.assertIn("printf '%s' \"$UDEV_RULE\" | \"$SUDO\"", script)


class AtomicWrite(unittest.TestCase):
    def test_rename_replaces_symlink_without_clobbering_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            victim = Path(tmp) / "victim"
            victim.write_text("must survive\n")
            link = Path(tmp) / "cache.json"
            link.symlink_to(victim)
            dirfd = os.open(tmp, os.O_RDONLY | os.O_DIRECTORY)
            try:
                trackpad.write_atomic(dirfd, "cache.json", b'{"ok":true}\n')
            finally:
                os.close(dirfd)
            self.assertEqual(victim.read_text(), "must survive\n")
            dest = Path(tmp) / "cache.json"
            self.assertFalse(dest.is_symlink())
            self.assertEqual(dest.read_bytes(), b'{"ok":true}\n')
            self.assertEqual(stat.S_IMODE(dest.stat().st_mode), 0o600)

    def test_read_refuses_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            victim = Path(tmp) / "victim"
            victim.write_text('{"lastNotifiedPercent":1}\n')
            os.chmod(victim, 0o600)
            link = Path(tmp) / "notify.json"
            link.symlink_to(victim)
            dirfd = os.open(tmp, os.O_RDONLY | os.O_DIRECTORY)
            try:
                with self.assertRaises(OSError):
                    trackpad.read_bounded(dirfd, "notify.json", 4096)
            finally:
                os.close(dirfd)


class Parsing(unittest.TestCase):
    def test_device_name_rejects_traversal(self):
        self.assertIsNone(trackpad.SAFE_DEVICE_NAME.fullmatch(".."))
        self.assertIsNone(trackpad.SAFE_DEVICE_NAME.fullmatch("../etc/passwd"))
        self.assertIsNone(trackpad.SAFE_DEVICE_NAME.fullmatch("-evil"))
        self.assertTrue(trackpad.SAFE_DEVICE_NAME.fullmatch("apple-inc.-magic-trackpad"))

    def test_hidraw_node(self):
        self.assertTrue(trackpad.HIDRAW_NODE.fullmatch("/dev/hidraw0"))
        self.assertIsNone(trackpad.HIDRAW_NODE.fullmatch("/dev/hidraw0;rm"))
        self.assertIsNone(trackpad.HIDRAW_NODE.fullmatch("/tmp/hidraw0"))

    def test_refuses_root_main(self):
        if os.geteuid() == 0:
            with self.assertRaises(SystemExit):
                trackpad.main(["status"])


class Helpers(unittest.TestCase):
    def test_python_compiles_isolated(self):
        subprocess.check_call(
            ["/usr/bin/python3", "-I", "-S", "-m", "py_compile", str(ROOT / "lib" / "trackpad.py")]
        )

    def test_bash_syntax(self):
        subprocess.check_call(["/usr/bin/bash", "-n", str(ROOT / "bin" / "trackpad-pack")])

    def test_status_is_json(self):
        out = subprocess.check_output(
            ["/usr/bin/python3", "-I", "-S", str(ROOT / "lib" / "trackpad.py"), "status"],
            timeout=8,
        )
        self.assertTrue(out.startswith(b"{"))
        self.assertLessEqual(len(out), 8192)

    def test_drag3fg_disables_tap_and_drag(self):
        orig = trackpad.discover_devices
        trackpad.discover_devices = lambda: ["apple-inc.-magic-trackpad"]
        try:
            on = trackpad.render_lua({"drag3fg": True, "swipe4": False, "macosAccel": False})
            swipe_only = trackpad.render_lua({"drag3fg": False, "swipe4": True, "macosAccel": False})
            none = trackpad.render_lua({"drag3fg": False, "swipe4": False, "macosAccel": False})
        finally:
            trackpad.discover_devices = orig
        self.assertIn("drag_3fg = 1", on)
        self.assertIn("tap_and_drag = false", on)
        self.assertIn("natural_scroll = true", on)
        self.assertIn("scroll_factor = 0.30", on)
        self.assertNotIn("drag_3fg", swipe_only)
        self.assertNotIn("tap_and_drag", swipe_only)
        self.assertIn("natural_scroll = true", swipe_only)
        self.assertIn("scroll_factor = 0.30", swipe_only)
        self.assertIn("return", none)
        self.assertNotIn("tap_and_drag", none)
        self.assertNotIn("natural_scroll", none)
        self.assertNotIn("scroll_factor", none)

    def test_scroll_factor_bounds(self):
        self.assertEqual(trackpad.coerce_scroll_factor(0.3), 0.3)
        self.assertEqual(trackpad.coerce_scroll_factor("0.30"), 0.3)
        self.assertEqual(trackpad.coerce_scroll_factor(2), 2.0)
        self.assertIsNone(trackpad.coerce_scroll_factor("0.300"))
        self.assertIsNone(trackpad.coerce_scroll_factor("1e-1"))
        self.assertIsNone(trackpad.coerce_scroll_factor("0.3;rm"))
        self.assertIsNone(trackpad.coerce_scroll_factor(0))
        self.assertIsNone(trackpad.coerce_scroll_factor(2.01))
        self.assertIsNone(trackpad.coerce_scroll_factor(True))
        lua = trackpad.render_lua
        orig = trackpad.discover_devices
        trackpad.discover_devices = lambda: ["apple-inc.-magic-trackpad"]
        try:
            text = lua({"drag3fg": True, "swipe4": False, "macosAccel": False, "scrollFactor": 0.45})
        finally:
            trackpad.discover_devices = orig
        self.assertIn("scroll_factor = 0.45", text)

    def test_helper_process_pins_environment(self):
        text = (ROOT / "HelperProcess.qml").read_text()
        self.assertIn("clearEnvironment: true", text)
        self.assertIn("environment: root.extraEnv", text)

    def test_service_load_starts_with_status(self):
        text = (ROOT / "Service.qml").read_text()
        start = text.find("Component.onCompleted:")
        self.assertGreaterEqual(start, 0)
        body = text[start : text.find("}", start)]
        self.assertIn("root.refreshStatus()", body)
        self.assertNotIn("applyPack", body)
        self.assertIn("if (!Model.parseStatus(text).requirePresent) root.applyPack()", text)


if __name__ == "__main__":
    unittest.main()
