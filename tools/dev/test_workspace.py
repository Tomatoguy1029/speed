#!/usr/bin/env python3
"""片付けが消してよいものだけを消すことを確かめる。"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import workspace

DAY = 86400


def git(directory, *arguments):
    subprocess.run(['git', '-C', str(directory), '-c', 'user.name=t', '-c', 'user.email=t@t', *arguments],
                   check=True, capture_output=True)


class CleanTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        os.environ['SPEED_BUILD_CACHE'] = str(base / 'cache')
        self.addCleanup(self.temporary.cleanup)
        self.addCleanup(os.environ.pop, 'SPEED_BUILD_CACHE')
        self.remote = base / 'remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(self.remote)], check=True)
        self.source = base / 'source'
        subprocess.run(['git', 'clone', '-q', str(self.remote), str(self.source)], check=True, capture_output=True)
        (self.source / 'a.txt').write_text('1')
        git(self.source, 'add', 'a.txt')
        git(self.source, 'commit', '-qm', 'first')
        git(self.source, 'push', '-q', 'origin', 'HEAD')
        workspace.ROOT = self.source

    def place(self, name, age_days):
        path = workspace.work_root() / name
        path.parent.mkdir(parents=True, exist_ok=True)
        git(self.source, 'worktree', 'add', '-q', '--detach', str(path), 'HEAD')
        (path / '.git').read_text()
        (path / workspace.MARKER).write_text('{}')
        exclude = self.source / '.git/info/exclude'
        exclude.write_text(workspace.MARKER + '\n')
        return path

    def age(self, path, days):
        stamp = time.time() - days * DAY
        for base, directories, names in os.walk(path):
            directories[:] = [name for name in directories if name != '.git']
            for name in names:
                os.utime(os.path.join(base, name), (stamp, stamp))

    def test_expired_clean_copy_is_removed(self):
        path = self.place('old', 8)
        self.age(path, 8)
        removed, kept = workspace.clean()
        self.assertEqual(removed, [path])
        self.assertFalse(path.exists())

    def test_recent_copy_stays(self):
        path = self.place('new', 0)
        self.age(path, 2)
        self.assertEqual(workspace.clean(), ([], {}))
        self.assertTrue(path.exists())

    def test_uncommitted_change_stays(self):
        path = self.place('dirty', 8)
        (path / 'a.txt').write_text('2')
        self.age(path, 8)
        removed, kept = workspace.clean()
        self.assertEqual(removed, [])
        self.assertEqual(kept[path], '未コミットの変更あり')

    def test_unpushed_commit_stays(self):
        path = self.place('ahead', 8)
        (path / 'a.txt').write_text('2')
        git(path, 'add', 'a.txt')
        git(path, 'commit', '-qm', 'local')
        self.age(path, 8)
        removed, kept = workspace.clean()
        self.assertEqual(removed, [])
        self.assertEqual(kept[path], '未pushのコミットあり')

    def test_recently_used_copy_stays_over_limit(self):
        path = self.place('active', 0)
        removed, kept = workspace.clean(limit_bytes=0)
        self.assertEqual(removed, [])
        self.assertEqual(kept[path], '使用中')

    def test_folder_outside_work_is_ignored(self):
        outside = Path(self.temporary.name) / 'outside'
        outside.mkdir()
        (outside / workspace.MARKER).write_text('{}')
        self.age(outside, 30)
        workspace.clean(limit_bytes=0)
        self.assertTrue(outside.exists())


if __name__ == '__main__':
    unittest.main()
