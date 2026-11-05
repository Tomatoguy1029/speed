#!/usr/bin/env python3
"""検証・撮影・生成に使う一時作業場所を作り、不要になったものを片付ける。

置き場所はユーザーキャッシュの work/ に固定し、その外には触らない。
使用中のもの、未コミットの変更や未pushのコミットがあるものは消さない。
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'build'))
from dev_build import cache_root

ROOT = Path(__file__).resolve().parents[2]
MARKER = '.speed-work.json'
RETENTION_DAYS = 7
LIMIT_GB = 20
ACTIVE_SECONDS = 24 * 3600
GENERATED = ('speed/extensions/run/bin', 'speed/.content', 'speed/.godot')


def work_root():
    return cache_root() / 'work'


def git(directory, *arguments):
    return subprocess.run(['git', '-C', str(directory), *arguments], capture_output=True, text=True)


def directory_size(path):
    total = 0
    for base, _, names in os.walk(path):
        for name in names:
            try:
                total += os.lstat(os.path.join(base, name)).st_size
            except OSError:
                pass
    return total


def last_used(path):
    newest = (path / MARKER).stat().st_mtime
    for base, directories, names in os.walk(path):
        directories[:] = [name for name in directories if name != '.git']
        for name in names:
            try:
                newest = max(newest, os.lstat(os.path.join(base, name)).st_mtime)
            except OSError:
                pass
    return newest


def keep_reason(path, now):
    """消してはいけない理由を返す。消してよければ空文字。"""
    if now - last_used(path) < ACTIVE_SECONDS:
        return '使用中'
    changes = git(path, 'status', '--porcelain')
    if changes.returncode != 0:
        return 'Gitの状態を確認できない'
    if changes.stdout.strip():
        return '未コミットの変更あり'
    remote = git(path, 'branch', '-r', '--contains', 'HEAD')
    if remote.returncode != 0 or not remote.stdout.strip():
        return '未pushのコミットあり'
    return ''


def entries():
    root = work_root()
    if not root.is_dir():
        return []
    return [path for path in root.iterdir() if (path / MARKER).is_file()]


def remove(path):
    if git(ROOT, 'worktree', 'remove', '--force', str(path)).returncode != 0:
        shutil.rmtree(path, ignore_errors=True)


def clean(now=None, retention_days=RETENTION_DAYS, limit_bytes=LIMIT_GB * 1024 ** 3, dry_run=False):
    """期限切れと上限超過だけを消し、(消した, 残した理由) を返す。"""
    now = now or time.time()
    rows = sorted(((last_used(path), directory_size(path), path) for path in entries()), key=lambda row: row[0])
    total = sum(size for _, size, _ in rows)
    removed, kept = [], {}
    for used, size, path in rows:
        if now - used <= retention_days * 86400 and total <= limit_bytes:
            continue
        reason = keep_reason(path, now)
        if reason:
            kept[path] = reason
            continue
        if not dry_run:
            remove(path)
        removed.append(path)
        total -= size
    if not dry_run:
        git(ROOT, 'worktree', 'prune')
    return removed, kept


def create(name, reference, with_generated):
    clean()
    if not all(character.isalnum() or character in '-_' for character in name):
        raise SystemExit('名前には英数字と - _ だけを使ってください')
    path = work_root() / f'{name}-{secrets.token_hex(3)}'
    path.parent.mkdir(parents=True, exist_ok=True)
    added = git(ROOT, 'worktree', 'add', '--detach', str(path), reference)
    if added.returncode != 0:
        raise SystemExit(added.stderr)
    (path / MARKER).write_text(json.dumps({'name': name, 'source': str(ROOT)}))
    # git status に出さず、手元の除外設定も変えない。
    exclude = Path(git(path, 'rev-parse', '--git-path', 'info/exclude').stdout.strip())
    if not exclude.is_absolute():
        exclude = path / exclude
    exclude.parent.mkdir(parents=True, exist_ok=True)
    if MARKER not in (exclude.read_text() if exclude.is_file() else ''):
        with open(exclude, 'a') as file:
            file.write('\n' + MARKER + '\n')
    if with_generated:
        for relative in GENERATED:
            if (ROOT / relative).is_dir():
                shutil.copytree(ROOT / relative, path / relative, dirs_exist_ok=True)
    print(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    make = commands.add_parser('create', help='一時作業場所を作ってパスを表示する')
    make.add_argument('name')
    make.add_argument('--ref', default='HEAD')
    make.add_argument('--with-generated', action='store_true', help='ライブラリ・実行用データ・importキャッシュも複製する')
    drop = commands.add_parser('remove', help='作業の終わった場所を消す')
    drop.add_argument('path', type=Path)
    tidy = commands.add_parser('clean', help='期限切れと上限超過を片付ける')
    tidy.add_argument('--dry-run', action='store_true')
    commands.add_parser('list', help='一時作業場所を表示する')
    args = parser.parse_args()
    if args.command == 'create':
        create(args.name, args.ref, args.with_generated)
    elif args.command == 'remove':
        path = args.path.resolve()
        if path.parent != work_root().resolve() or not (path / MARKER).is_file():
            raise SystemExit('一時作業場所ではありません: ' + str(path))
        changes = git(path, 'status', '--porcelain').stdout.strip()
        remote = git(path, 'branch', '-r', '--contains', 'HEAD').stdout.strip()
        if changes or not remote:
            raise SystemExit('未コミットの変更か未pushのコミットがあります: ' + str(path))
        remove(path)
    elif args.command == 'clean':
        removed, kept = clean(dry_run=args.dry_run)
        for path in removed:
            print('削除: ' + str(path))
        for path, reason in kept.items():
            print(f'保持: {path}（{reason}）')
    else:
        for path in entries():
            print(f'{path}  {directory_size(path) / 1024 ** 3:.2f}GB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
