#!/usr/bin/env python3
"""Generate Godot text inputs from docs/game/text.md (Python standard library only)."""
import argparse
import csv
import difflib
import html
import io
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/game/text.md"
CSV_PATH = ROOT / "speed/data/text/strings.csv"


def decode_cell(cell):
    # Decode entities after line breaks so literal <br> remains literal.
    return html.unescape(cell.strip().replace("<br>", "\n"))


def read_table(document, name, header, compatibility=False):
    start, end = f"<!-- {name}:start -->", f"<!-- {name}:end -->"
    if document.count(start) != 1 or document.count(end) != 1:
        raise ValueError(f"{name}: 開始・終了マーカーを1組置いてください")
    begin = document.index(start) + len(start)
    finish = document.index(end)
    if finish < begin:
        raise ValueError(f"{name}: マーカーの順序が逆です")
    lines = document[begin:finish].splitlines()
    rows, raw = [], None
    saw_header = False
    for line in lines:
        if compatibility and line == "```csv-compat" and raw is None:
            raw = []
            continue
        if raw is not None:
            if line == "```":
                extra = list(csv.reader(io.StringIO("\n".join(raw)), strict=True))
                if not extra or any(len(row) <= len(header) for row in extra):
                    raise ValueError("csv-compat は既存の余剰列を持つ行専用です")
                rows.extend(extra)
                raw = None
            else:
                raw.append(line)
            continue
        if not line.strip():
            continue
        if not line.startswith("| ") or not line.endswith(" |"):
            raise ValueError(f"{name}: 表の形式を確認してください: {line[:100]}")
        cells = [decode_cell(cell) for cell in line[1:-1].split("|")]
        if cells == header:
            saw_header = True
            continue
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if len(cells) != len(header):
            raise ValueError(f"{name}: {len(header)} 列が必要です: {line[:100]}")
        rows.append(cells)
    if raw is not None or not saw_header or not rows:
        raise ValueError(f"{name}: 表または互換ブロックが未完です")
    return rows


def csv_bytes(rows):
    # Quote trailing spaces as well as CSV metacharacters, matching the existing input.
    def quote(value):
        if any(c in value for c in ',"\r\n') or value.endswith(" "):
            return '"' + value.replace('"', '""') + '"'
        return value
    return ("\n".join(",".join(quote(value) for value in row) for row in rows) + "\n").encode("utf-8")


def generate(document):
    rows = read_table(document, "csv", ["keys", "ja", "en"], compatibility=True)
    keys = set()
    for row in rows:
        key = row[0]
        if key and (key in keys or key == "keys"):
            raise ValueError(f"翻訳キーが重複しています: {key}")
        keys.add(key)
    outputs = {CSV_PATH: csv_bytes([["keys", "ja", "en"], *rows])}
    resources = read_table(document, "resources", ["resource", "display_name"])
    seen = set()
    for relative, value in resources:
        if not re.fullmatch(r"(?:enemies|heroes|bosses)/[A-Za-z0-9_]+\.tres", relative):
            raise ValueError(f"表示名の対象パスを確認してください: {relative}")
        if relative in seen:
            raise ValueError(f"表示名の対象が重複しています: {relative}")
        seen.add(relative)
        path = ROOT / "speed/data" / relative
        current = path.read_text(encoding="utf-8")
        prefix, marker, body = current.partition("[resource]\n")
        pattern = r'^display_name = "(?:[^"\\\n]|\\.)*"$'
        if not marker or len(re.findall(pattern, body, flags=re.MULTILINE)) != 1:
            raise ValueError(f"{relative}: [resource] の display_name を1つにしてください")
        updated = re.sub(pattern, lambda _: "display_name = " + json.dumps(value, ensure_ascii=False),
                         body, flags=re.MULTILINE)
        outputs[path] = (prefix + marker + updated).encode("utf-8")
    # A new resource also needs a row in the source; direct editor additions must be visible.
    expected = {str(path.relative_to(ROOT / "speed/data"))
                for folder in ("enemies", "heroes", "bosses")
                for path in (ROOT / "speed/data" / folder).glob("*.tres")
                if re.search(r"^display_name = ", path.read_text(encoding="utf-8"), re.MULTILINE)}
    if expected != seen:
        raise ValueError(f"表示名の対象が一致しません。追加: {sorted(expected - seen)}, 削除: {sorted(seen - expected)}")
    return outputs, len(keys - {""}), len(resources)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="書き込まず、生成差分を表示して終了コード1を返す")
    args = parser.parse_args()
    try:
        outputs, keys, resources = generate(SOURCE.read_text(encoding="utf-8"))
        changed = 0
        for path, generated in outputs.items():
            current = path.read_bytes() if path.exists() else b""
            if current == generated:
                continue
            changed += 1
            relative = str(path.relative_to(ROOT))
            if args.check:
                sys.stdout.writelines(difflib.unified_diff(
                    current.decode("utf-8").splitlines(keepends=True),
                    generated.decode("utf-8").splitlines(keepends=True),
                    fromfile=relative, tofile=relative + " (generated)"))
            else:
                path.write_bytes(generated)
                print(f"generated: {relative}")
        print(f"generate_text: {keys} keys, {resources} resource names, {changed} file(s) {'differ' if args.check else 'updated'}")
        return int(args.check and changed > 0)
    except (ValueError, OSError, csv.Error) as error:
        print(f"generate_text: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
