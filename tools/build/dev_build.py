#!/usr/bin/env python3
"""開発用のC++ビルド。固定SDKの準備、差分ビルド、ライブラリの置き換えを行う。

SDK・中間ファイル・共有キャッシュはユーザーキャッシュに置き、再起動後も全worktreeで使う。
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from runtime_id import runtime_id

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'speed/extensions/run/bin'
RETENTION_SECONDS = 14 * 24 * 3600
OBJECT_CACHE_LIMIT = 2 * 1024 ** 3


class BuildError(Exception):
    pass


def cache_root():
    override = os.environ.get('SPEED_BUILD_CACHE')
    if override:
        return Path(override)
    if sys.platform == 'win32':
        return Path(os.environ['LOCALAPPDATA']) / 'speed-build'
    return Path.home() / '.cache/speed-build'


def target():
    if sys.platform == 'win32':
        return 'windows', 'x86_64'
    machine = platform.machine().lower()
    return 'macos', 'arm64' if machine in ('arm64', 'aarch64') else 'x86_64'


def library_name(system, arch):
    prefix, suffix = ('lib', 'dylib') if system == 'macos' else ('', 'dll')
    return f'{prefix}speed_runtime.{system}.template_release.{arch}.{suffix}'


def record_path(system, arch):
    return BIN / (library_name(system, arch) + '.json')


class Lock:
    """SDKを共有するビルドを1つずつ実行する。プロセスが落ちるとOSが解放する。"""

    def __init__(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file = open(path, 'a+b')

    def _try(self):
        try:
            if sys.platform == 'win32':
                import msvcrt
                self.file.seek(0)
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            return False

    def __enter__(self):
        if not self._try():
            print('別のビルドの完了を待っています…', flush=True)
            while not self._try():
                time.sleep(1)
        return self

    def __exit__(self, *_):
        self.file.close()


def run(command, **options):
    print('> ' + ' '.join(str(part) for part in command), flush=True)
    subprocess.run([str(part) for part in command], check=True, **options)


def ensure_sdk(cache, lock):
    commit = lock['godot_cpp']['commit']
    sdk = cache / 'sdk' / ('godot-cpp-' + commit[:12])
    if (sdk / 'SConstruct').is_file():
        return sdk
    print('固定版のSDKを取得します（初回のみ）', flush=True)
    sdk.parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='fetch-', dir=sdk.parent))
    try:
        run(['git', 'init', '-q', work])
        run(['git', '-C', work, 'remote', 'add', 'origin', lock['godot_cpp']['url']])
        run(['git', '-C', work, 'fetch', '-q', '--depth=1', 'origin', commit])
        run(['git', '-C', work, 'checkout', '-q', '--detach', 'FETCH_HEAD'])
        os.replace(work, sdk)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return sdk


def ensure_scons(cache, lock):
    environment = cache / ('scons-' + lock['scons'])
    scripts = environment / ('Scripts' if sys.platform == 'win32' else 'bin')
    scons = scripts / ('scons.exe' if sys.platform == 'win32' else 'scons')
    if scons.is_file():
        return scons
    print('固定版のSConsを準備します（初回のみ）', flush=True)
    shutil.rmtree(environment, ignore_errors=True)
    run([sys.executable, '-m', 'venv', environment])
    run([scripts / 'python', '-m', 'pip', 'install', '-q', 'scons==' + lock['scons']])
    return scons


def has_compiler(system):
    if system == 'macos':
        return shutil.which('clang++') is not None
    installer = Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
    if not installer.is_file():
        return shutil.which('cl') is not None
    found = subprocess.run([installer, '-latest', '-products', '*', '-requires',
                            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'],
                           capture_output=True, text=True)
    return bool(found.stdout.strip()) or shutil.which('cl') is not None


def compiler_help(system):
    if system == 'macos':
        return 'C++コンパイラーがありません。ターミナルで `xcode-select --install` を実行してください。'
    return 'C++コンパイラーがありません。Visual Studio Installerで「C++によるデスクトップ開発」を入れてください。'


def stop_process(process):
    if sys.platform == 'win32':
        subprocess.run(['taskkill', '/T', '/F', '/PID', str(process.pid)], capture_output=True)
    else:
        os.killpg(process.pid, signal.SIGTERM)


def run_cancellable(command, cancel):
    """cancel ファイルが現れたら、子プロセスごと止める。"""
    options = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if sys.platform == 'win32' else {'start_new_session': True}
    process = subprocess.Popen([str(part) for part in command], **options)
    while process.poll() is None:
        if cancel.exists():
            stop_process(process)
            process.wait()
            raise BuildError('ビルドを中止しました。ライブラリは変更していません。')
        time.sleep(0.2)
    if process.returncode:
        raise BuildError('ビルドに失敗しました。ライブラリは変更していません。')


def publish(library, identifier, source, system, arch):
    """置き換えの途中で失敗しても、元のライブラリが残る順に配置する。"""
    BIN.mkdir(parents=True, exist_ok=True)
    name = library_name(system, arch)
    destination = BIN / name
    pending = BIN / (name + '.pending')
    shutil.copy2(library, pending)
    if sys.platform == 'win32' and destination.exists():
        # 読み込み中のDLLは上書きできないが、名前は変えられる。
        retired = BIN / f'{name}.old-{os.getpid()}'
        os.replace(destination, retired)
    os.replace(pending, destination)
    record = record_path(system, arch)
    pending_record = record.with_suffix('.json.pending')
    pending_record.write_text(json.dumps({'runtime_id': identifier, 'source': source}))
    os.replace(pending_record, record)
    for old in BIN.glob(name + '.old-*'):
        try:
            old.unlink()
        except OSError:
            pass


def prune(cache):
    """もう使わない中間ファイルを片付け、共有キャッシュを上限内に保つ。"""
    now = time.time()
    objects = cache / 'objects'
    if objects.is_dir():
        for directory in objects.iterdir():
            owner = directory / 'worktree.txt'
            if owner.is_file() and (not Path(owner.read_text().strip()).is_dir() or now - owner.stat().st_mtime > RETENTION_SECONDS):
                shutil.rmtree(directory, ignore_errors=True)
    shared = cache / 'objects-shared'
    if not shared.is_dir():
        return
    files = [(path.stat().st_mtime, path.stat().st_size, path) for path in shared.rglob('*') if path.is_file()]
    total = sum(size for _, size, _ in files)
    for modified, size, path in sorted(files, key=lambda row: row[0]):
        if total <= OBJECT_CACHE_LIMIT and now - modified <= RETENTION_SECONDS:
            continue
        path.unlink(missing_ok=True)
        total -= size


def build(jobs, cancel_file=None):
    lock = json.loads((ROOT / 'cpp/dependencies.json').read_text())
    system, arch = target()
    if not has_compiler(system):
        raise BuildError(compiler_help(system))
    cache = cache_root()
    work = cache / 'objects' / hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
    work.mkdir(parents=True, exist_ok=True)
    (work / 'worktree.txt').write_text(str(ROOT))
    cancel = cancel_file or work / 'cancel'
    with Lock(cache / 'build.lock'):
        sdk = ensure_sdk(cache, lock)
        scons = ensure_scons(cache, lock)
        identifier = runtime_id(ROOT / 'cpp')
        output = work / 'output'
        output.mkdir(exist_ok=True)
        run_cancellable([sys.executable, ROOT / 'tools/build/build_run.py', '--sdk', sdk, '--scons', scons,
                         '--platform', system, '--arch', arch, '--output', output, '--build-dir', work / 'scons',
                         '--cache-dir', cache / 'objects-shared', '--jobs', jobs], cancel)
        publish(output / library_name(system, arch), identifier, 'local', system, arch)
        prune(cache)
    if runtime_id(ROOT / 'cpp') != identifier:
        print('ビルド中にC++が変更されました。もう一度ビルドしてください。', flush=True)
    print('ビルドが完了しました: ' + identifier[:12], flush=True)


def status():
    system, arch = target()
    record = record_path(system, arch)
    installed = None
    if record.is_file() and (BIN / library_name(system, arch)).is_file():
        installed = json.loads(record.read_text())
    current = runtime_id(ROOT / 'cpp')
    state = 'missing' if installed is None else 'current' if installed['runtime_id'] == current else 'stale'
    print(json.dumps({'state': state, 'runtime_id': current, 'installed': installed}, ensure_ascii=False))


def main():
    # Godotのビルドパネルは出力をUTF-8で読む。日本語Windowsの既定のcp932を子のPythonまで揃えて置き換える。
    os.environ['PYTHONUTF8'] = '1'
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('status', help='ライブラリとソースの対応を表示する')
    build_command = commands.add_parser('build', help='差分ビルドしてライブラリを置き換える')
    build_command.add_argument('--jobs', type=int, default=max(1, (os.cpu_count() or 2) - 2))
    build_command.add_argument('--cancel-file', type=Path, help='このファイルが現れたらビルドを中止する')
    args = parser.parse_args()
    if args.command == 'status':
        status()
        return 0
    try:
        build(args.jobs, args.cancel_file)
    except (BuildError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
