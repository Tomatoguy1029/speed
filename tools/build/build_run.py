#!/usr/bin/env python3
"""固定したSDKとAPIでラン拡張をビルドする。SDKは作業ツリーの外へ用意する。"""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[2]
    lock = json.loads((root / 'cpp/dependencies.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, required=True, help='固定コミットのgodot-cpp')
    parser.add_argument('--scons', default='scons', help='固定版SConsの実行ファイル')
    parser.add_argument('--platform', choices=['macos', 'windows'], required=True)
    parser.add_argument('--arch', choices=['arm64', 'x86_64'], required=True)
    parser.add_argument('--output', type=Path, help='共有ライブラリの出力先')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    if args.platform == 'windows' and args.arch != 'x86_64':
        parser.error('Windowsの対象はx86_64です')
    if not args.sdk.is_dir():
        parser.error('SDKがありません。dependencies.jsonの公式URLと完全コミットを使って取得してください')
    subprocess.run([sys.executable, str(root / 'tools/build/generate_run_schema.py'), '--check'], check=True)
    command = [args.scons, '-C', str(root / 'cpp'), '-j', str(args.jobs),
               'godot_cpp_dir=' + str(args.sdk.resolve()), 'platform=' + args.platform,
               'arch=' + args.arch, 'target=template_release', 'precision=' + lock['precision']]
    if args.output:
        command.append('output_dir=' + str(args.output.resolve()))
    return subprocess.call(command)


if __name__ == '__main__':
    sys.exit(main())
