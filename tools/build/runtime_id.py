#!/usr/bin/env python3
"""C++ソースの内容からOSに依存しない識別子（runtime id）を計算する。

同じ計算を speed/addons/runtime_library/runtime_id.gd も実装する。
"""
import hashlib
from pathlib import Path
import sys

FIXED_FILES = ('SConstruct', 'dependencies.json')
SOURCE_SUFFIXES = ('.h', '.cpp')
EXCLUDED_DIRECTORIES = ('godot-cpp',)


def source_paths(cpp):
    """cpp からの相対パスを `/` 区切りで昇順に返す。"""
    paths = [name for name in FIXED_FILES if (cpp / name).is_file()]
    for path in cpp.rglob('*'):
        relative = path.relative_to(cpp)
        if path.suffix in SOURCE_SUFFIXES and path.is_file() and relative.parts[0] not in EXCLUDED_DIRECTORIES:
            paths.append(relative.as_posix())
    return sorted(paths, key=lambda text: text.encode())


def file_hash(path):
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def runtime_id(cpp):
    cpp = Path(cpp)
    manifest = ''.join(name + ':' + file_hash(cpp / name) + '\n' for name in source_paths(cpp))
    return hashlib.sha256(manifest.encode()).hexdigest()


if __name__ == '__main__':
    print(runtime_id(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / 'cpp'))
