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
            r"UDEV_RULE=\$\(cat << 'EOF'\n(.*)\nEOF\n\)",
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


if __name__ == "__main__":
    unittest.main()
