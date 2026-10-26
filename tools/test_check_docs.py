"""Explicit plan files are allowed; other work files remain prohibited."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check_docs


class WorkDirectoriesTest(unittest.TestCase):
    def check_files(self, *files):
        with tempfile.TemporaryDirectory() as directory:
            for name in files:
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('')
            with patch.object(check_docs, 'ROOT', directory):
                return check_docs.work_directory_errors()

    def test_only_requested_plan_files_are_allowed(self):
        self.assertEqual(self.check_files('tasks/plan.md', 'tasks/todo.md'), [])

    def test_other_task_documents_are_rejected(self):
        self.assertTrue(self.check_files('tasks/notes.md'))
        self.assertTrue(self.check_files('tasks/nested/plan.md'))

    def test_other_work_directories_remain_rejected(self):
        self.assertTrue(self.check_files('docs/proposals/example.md'))
        self.assertTrue(self.check_files('docs/logs/example.md'))


if __name__ == '__main__':
    unittest.main()
