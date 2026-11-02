#!/usr/bin/env python3
"""固定依存の拡張ビルドと、独立コピーでのGodot共通生成・配布を行う。"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


def run(command):
    subprocess.run([str(part) for part in command], check=True)


def library_name(platform, arch):
    prefix, suffix = ('lib', 'dylib') if platform == 'macos' else ('', 'dll')
    return f'{prefix}speed_runtime.{platform}.template_release.{arch}.{suffix}'


def build(root, lock, args, arch, output):
    run([args.scons, '-C', root / 'cpp', '-j', args.jobs,
         'godot_cpp_dir=' + str(args.sdk.resolve()), 'platform=' + args.platform,
         'arch=' + arch, 'target=template_release', 'precision=' + lock['precision'],
         'output_dir=' + str(output), 'build_dir=' + str(args.build_dir.resolve())])


def prepare_verification(root, project):
    # 公式配布エンジンは外部script/PCKへの切替を無効にするため、
    # 既存確認の本文だけを独立した確認用コピーの起動Scriptへ載せる。
    checks = (root / 'speed/tests/content/check_rules.gd').read_text()
    methods = []
    for name in re.findall(r'^func (_package_\w+)\(', checks, re.M):
        match = re.search(r'^func ' + name + r'\([^\n]*\n.*?(?=^func |\Z)', checks, re.M | re.S)
        if not match:
            raise ValueError('既存の配布確認がありません: ' + name)
        method = re.sub(r'\broot\b', 'get_tree().root', match[0])
        method = re.sub(r'(?<![\w.])quit\(', 'get_tree().quit(', method)
        method = re.sub(r'\bprocess_frame\b', 'get_tree().process_frame', method)
        methods.append(method.rstrip())
    path = project / 'scripts/ui/main.gd'
    text = path.read_text()
    ready = 'func _ready() -> void:\n'
    if ready not in text or 'func _package_runtime(' in text:
        raise ValueError('確認用の起動Scriptを安全に準備できません')
    hook = ('\tif "--package-loading" in OS.get_cmdline_user_args():\n'
            '\t\tcall_deferred("_package_loading")\n'
            '\telif "--package-runtime" in OS.get_cmdline_user_args() or "--package-missing-runtime" in OS.get_cmdline_user_args():\n'
            '\t\tcall_deferred("_package_runtime")\n\t\treturn\n')
    path.write_text(text.replace(ready, ready + hook, 1) + '\n\n' + '\n\n'.join(methods) + '\n')


def package(root, lock, args):
    destination = args.package_dir.resolve()
    if destination == root or root in destination.parents:
        raise ValueError('配布用の作業先はソースツリーの外へ指定してください')
    destination.mkdir(parents=True, exist_ok=True)
    project = destination / 'project'
    if project.exists():
        raise ValueError('配布用のprojectが既にあります。新しい作業先を指定してください')
    version = subprocess.check_output([args.godot, '--headless', '--version'], text=True).strip()
    if not re.match(re.escape(lock['engine']) + r'\.stable(?:\.|$)', version):
        raise ValueError('Godot本体がdependencies.jsonの安定版と一致しません: ' + version)
    templates = args.templates.resolve()
    if templates.name != lock['export_templates'] or (templates / 'version.txt').read_text().strip() != lock['export_templates']:
        raise ValueError('export templateの版がdependencies.jsonと一致しません')
    template = templates / ('macos.zip' if args.platform == 'macos' else 'windows_release_x86_64.exe')
    if not template.is_file():
        raise ValueError('配布対象のexport templateがありません: ' + str(template))
    shutil.copytree(root / 'speed', project,
                    ignore=shutil.ignore_patterns('.godot', '.content', 'bin', '__pycache__'))
    # 配布の確認もプレイヤーの保存先から隔離する。
    save = project / 'scripts/managers/save_manager.gd'
    original_save = save.read_text()
    source = original_save
    for key, filename in [('SAVE_PATH', 'save.json'), ('SETTINGS_PATH', 'settings.cfg')]:
        before = f'const {key} := "user://{filename}"'
        if before not in source:
            raise ValueError('保存先の隔離対象を確認できません: ' + key)
        source = source.replace(before, f'const {key} := {json.dumps(str(destination / filename))}', 1)
    save.write_text(source)
    if args.verify:
        prepare_verification(root, project)
    libraries = project / 'extensions/run/bin'
    libraries.mkdir(parents=True, exist_ok=True)
    arches = ['arm64', 'x86_64'] if args.platform == 'macos' else ['x86_64']
    for arch in arches:
        build(root, lock, args, arch, libraries)
    if args.platform == 'macos':
        universal = libraries / library_name('macos', 'universal')
        run(['lipo', '-create', *[libraries / library_name('macos', arch) for arch in arches], '-output', universal])
        run(['lipo', universal, '-verify_arch', *arches])
        extension = project / 'extensions/run/run_core.gdextension'
        config = extension.read_text()
        for arch in arches:
            config = config.replace(library_name('macos', arch), universal.name)
            (libraries / library_name('macos', arch)).unlink()
        extension.write_text(config)
    licenses = project / 'licenses/run'
    licenses.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.sdk / 'LICENSE.md', licenses / 'GODOT-CPP.txt')
    shutil.copy2(root / 'cpp/dependencies.json', licenses / 'dependencies.json')
    presets = project / 'export_presets.cfg'
    config = presets.read_text()
    section = '[preset.0.options]' if args.platform == 'macos' else '[preset.1.options]'
    config = config.replace(section, section + '\n\ncustom_template/release=' + json.dumps(str(template)) + ('\ndebug/export_console_wrapper=2' if args.platform == 'windows' and args.verify else ''), 1)
    presets.write_text(config)
    engine = [args.godot, '--headless', '--path', project]
    # importで型・資源索引を準備してから、正規の共通生成へ渡す。
    run([*engine, '--editor', '--import', '--log-file', destination / 'import.log'])
    run([*engine, '--script', 'res://tools/content/build_all.gd', '--log-file', destination / 'generate.log', '--', '--force'])
    if not args.verify:
        save.write_text(original_save)
    output = destination / 'export'
    output.mkdir(exist_ok=True)
    preset = 'macOS' if args.platform == 'macos' else 'Windows'
    artifact = output / ('Speed.zip' if args.platform == 'macos' else 'Speed.exe')
    run([*engine, '--editor', '--export-release', preset, artifact, '--log-file', destination / 'export.log'])
    if args.platform == 'macos':
        with zipfile.ZipFile(artifact) as archive:
            archive.extractall(output)
        for executable in output.glob('*.app/Contents/MacOS/*'):
            executable.chmod(executable.stat().st_mode | 0o111)
    run([sys.executable, root / 'speed/tests/integration/export_package.py', output, '--platform', args.platform,
         *(['--runtime'] if args.verify else []), *(['--rendered'] if args.rendered else []),
         *(['--loading'] if args.verify_loading else []), '--script', root / 'speed/tests/content/check_rules.gd'])
    print('配布物: ' + str(artifact))


def main():
    root = Path(__file__).resolve().parents[2]
    lock = json.loads((root / 'cpp/dependencies.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, required=True, help='固定コミットのgodot-cpp')
    parser.add_argument('--scons', default='scons', help='固定版SConsの実行ファイル')
    parser.add_argument('--platform', choices=['macos', 'windows'], required=True)
    parser.add_argument('--arch', choices=['arm64', 'x86_64'], help='単体ビルドのCPU。配布時は対象CPUをすべて作る')
    parser.add_argument('--output', type=Path, help='単体ビルドの共有ライブラリ出力先')
    parser.add_argument('--build-dir', type=Path, default=Path(tempfile.gettempdir()) / 'speed-run-build' / hashlib.sha256(str(root).encode()).hexdigest()[:12], help='ソース外の中間object出力先')
    parser.add_argument('--package-dir', type=Path, help='新しい独立作業先。ビルド・共通生成・exportを順に行う')
    parser.add_argument('--godot', help='dependencies.jsonと一致するGodot本体')
    parser.add_argument('--templates', type=Path, help='version.txtを持つ固定版export templateディレクトリ')
    parser.add_argument('--verify', action='store_true', help='配布エンジンで最小ランとライブラリ欠落時の失敗を確認する')
    parser.add_argument('--rendered', action='store_true', help='Macの配布確認をgodot-bgで描画付き起動する')
    parser.add_argument('--verify-loading', action='store_true', help='Mac配布版で初回・再出撃・装備準備・取消・戻るの時間と回収を確認する')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    if args.rendered and (args.platform != 'macos' or not args.verify):
        parser.error('--rendered はMacの --verify と合わせて指定してください')
    if args.verify_loading and not (args.package_dir and args.verify and args.rendered):
        parser.error('--verify-loading はMac配布の --verify --rendered と合わせて指定してください')
    if args.platform == 'windows' and args.arch not in (None, 'x86_64'):
        parser.error('Windowsの対象はx86_64です')
    if not args.sdk.is_dir():
        parser.error('SDKがありません。dependencies.jsonの公式URLと完全コミットを使って取得してください')
    if args.package_dir and not (args.godot and args.templates):
        parser.error('配布には --godot と --templates が必要です')
    if not args.package_dir and not args.arch:
        parser.error('単体ビルドには --arch が必要です')
    if root == args.build_dir.resolve() or root in args.build_dir.resolve().parents:
        parser.error('中間object出力先はソースツリーの外へ指定してください')
    run([sys.executable, root / 'tools/build/generate_run_schema.py', '--check'])
    if args.package_dir:
        package(root, lock, args)
    else:
        build(root, lock, args, args.arch, (args.output or root / 'speed/extensions/run/bin').resolve())
    return 0


if __name__ == '__main__':
    sys.exit(main())
