#!/usr/bin/env python3
"""runtime id がOSの違いで変わらず、ソースの違いで変わることを確かめる。"""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from runtime_id import runtime_id


def write(root, files):
    for name, data in files.items():
        path = Path(root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


class RuntimeIdTest(unittest.TestCase):
    def identifier(self, files):
        with tempfile.TemporaryDirectory() as root:
            write(root, files)
            return runtime_id(root)

    def test_crlf_matches_lf(self):
        self.assertEqual(self.identifier({'SConstruct': b'a\nb\n', 'x/a.cpp': b'c\n'}),
                         self.identifier({'SConstruct': b'a\r\nb\r\n', 'x/a.cpp': b'c\r\n'}))

    def test_content_change_differs(self):
        self.assertNotEqual(self.identifier({'x/a.cpp': b'1'}), self.identifier({'x/a.cpp': b'2'}))

    def test_rename_differs(self):
        self.assertNotEqual(self.identifier({'x/a.cpp': b'1'}), self.identifier({'x/b.cpp': b'1'}))

    def test_sdk_and_other_files_are_ignored(self):
        self.assertEqual(self.identifier({'a.h': b'1'}),
                         self.identifier({'a.h': b'1', 'godot-cpp/b.h': b'2', 'notes.txt': b'3'}))


if __name__ == '__main__':
    unittest.main()
