"""配布物へ検証用の保存先・起動処理が混入する不具合を防ぐ。"""
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('build_run', ROOT / 'tools/build/build_run.py')
build_run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_run)


class PackageTest(unittest.TestCase):
    def test_verification_never_changes_release(self):
        for platform in ('macos', 'windows'):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary).resolve()
                root, destination = base / 'source', base / 'package'
                project = root / 'speed'
                save = project / 'scripts/managers/save_manager.gd'
                main = project / 'scripts/ui/main.gd'
                save.parent.mkdir(parents=True)
                main.parent.mkdir(parents=True)
                original_save = 'const SAVE_PATH := "user://save.json"\nconst SETTINGS_PATH := "user://settings.cfg"\n'
                original_main = 'extends Node\nfunc _ready() -> void:\n\tpass\n'
                save.write_text(original_save)
                main.write_text(original_main)
                (project / 'export_presets.cfg').write_text('[preset.0.options]\napplication/min_macos_version_arm64="13.0"\napplication/min_macos_version_x86_64="13.0"\n[preset.1.options]\n')
                (project / 'extensions/run').mkdir(parents=True)
                (project / 'extensions/run/run_core.gdextension').write_text('')
                checks = project / 'tests/content/check_rules.gd'
                checks.parent.mkdir(parents=True)
                checks.write_text('func _package_runtime() -> void:\n\tquit(0)\n')
                sdk = base / 'sdk'
                sdk.mkdir()
                (sdk / 'LICENSE.md').write_text('license')
                (root / 'cpp').mkdir()
                lock = {'engine': '4.7.2', 'export_templates': '4.7.2.stable', 'macos_deployment_target': '13.0'}
                (root / 'cpp/dependencies.json').write_text(json.dumps(lock))
                templates = base / lock['export_templates']
                templates.mkdir()
                (templates / 'version.txt').write_text(lock['export_templates'])
                (templates / ('macos.zip' if platform == 'macos' else 'windows_release_x86_64.exe')).touch()
                args = SimpleNamespace(package_dir=destination, godot='godot', templates=templates,
                                       platform=platform, sdk=sdk, verify=True, verify_final=True,
                                       rendered=False, verify_loading=False)
                exports = []

                def export(root, project, target, args, verification=False):
                    exports.append((target, verification,
                                    (project / 'scripts/managers/save_manager.gd').read_text(),
                                    (project / 'scripts/ui/main.gd').read_text()))
                    artifact = target / 'export' / ('Speed.zip' if platform == 'macos' else 'Speed.exe')
                    artifact.parent.mkdir(parents=True)
                    artifact.write_bytes(b'package')
                    return artifact

                def build(root, lock, args, arch, output):
                    (output / build_run.library_name(platform, arch)).touch()

                with patch.object(build_run, 'build', side_effect=build), patch.object(build_run, 'run'), \
                     patch.object(build_run.subprocess, 'check_output', side_effect=['4.7.2.stable.official\n', 'revision\n']), \
                     patch.object(build_run, 'runtime_id', return_value='runtime'), \
                     patch.object(build_run, 'export_project', side_effect=export):
                    build_run.package(root, lock, args)
                self.assertEqual(exports[0], (destination, False, original_save, original_main))
                self.assertEqual(exports[1][:2], (destination / 'verification', True))
                self.assertIn(json.dumps(str(destination / 'verification' / 'save.json')), exports[1][2])
                self.assertIn('func _package_runtime(', exports[1][3])
                self.assertEqual(save.read_text(), original_save)
                self.assertEqual(main.read_text(), original_main)
                self.assertEqual(json.loads((destination / 'package.json').read_text())['source_commit'], 'revision')

    def test_mac_export_works_without_personal_launcher(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'package'
            args = SimpleNamespace(platform='macos', godot='/Godot', verify=False,
                                   verify_final=False, rendered=False, verify_loading=False)
            commands = []

            def run(command, env=None):
                commands.append((command, env))
                if '--export-release' in command:
                    artifact = command[command.index('--export-release') + 2]
                    with zipfile.ZipFile(artifact, 'w') as archive:
                        archive.writestr('Speed.app/Contents/MacOS/Speed', b'engine')

            with patch.object(build_run.shutil, 'which', return_value=None), patch.object(build_run, 'run', side_effect=run):
                artifact = build_run.export_project(ROOT, Path('/project'), target, args)
            self.assertTrue(artifact.is_file())
            self.assertEqual(commands[0][0][:3], ['/Godot', '--path', Path('/project')])
            self.assertNotIn('--headless', commands[0][0])
            self.assertIsNone(commands[0][1])


if __name__ == '__main__':
    unittest.main()
