#!/usr/bin/env python3
"""文書の運用規定（docs/README.md）のチェック。違反があれば一覧を出して終了コード1で終わる。

使い方: python3 tools/check_docs.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# docs/ の置き場ごとに置ける文書（None はその置き場の .md なら自由）
ALLOWED = {
    "docs": {"README.md", "treatment.md", "spec.md", "architecture.md"},
    "docs/game": {"world.md", "art-style.md", "graphics-improvements.md", "text.md", "backlog.md"},
    "docs/game/catalog": None,
    "docs/game/stages": {f"stage-{n}.md" for n in range(1, 6)},
    "docs/game/bosses": None,
    "docs/dev": {"stage-production.md", "stage-production-ai.md"},
}
# 今の状態だけを書く置き場
STATE_DIRS = ["docs/treatment.md", "docs/spec.md", "docs/architecture.md", "docs/game", "docs/dev"]
# 廃止した個人の作業ログ
PERSONAL_LOGS = [f"demo/docs/{n}.md" for n in ("wakida", "shumak", "keporusu")]
# リポジトリに置かない、作業用の置き場
WORK_DIRS = ["tasks", "docs/proposals", "docs/logs"]
# リンク切れを調べる文書
LINK_TARGETS = ["docs", "AGENTS.md", "README.md"]

DATE = re.compile(r"\d{4}-\d{1,2}-\d{1,2}|\d{4}年\d{1,2}月(\d{1,2}日)?|\d{1,2}月\d{1,2}日|最終更新")
NAMES = re.compile(r"Tomatoguy|ShueMaker|keporusu|wakida|shumak", re.IGNORECASE)
LINK = re.compile(r"\]\(([^)\s]+)\)")
# 列で持つデータのコードと、その列の一覧を載せた設計書の節（表の1列目に列名をコードの書き方で書く）
COLUMN_TABLES = [("speed/scripts/data_types/enemy_table.gd", "docs/architecture.md", "### 6.2 敵の表の列")]
VAR = re.compile(r"^var (\w+)")
TABLE_ROW = re.compile(r"^\|\s*`(\w+)`\s*\|")
CODE_SPAN = re.compile(r"`[^`]*`")


def md_files(rel_dir):
    base = os.path.join(ROOT, rel_dir)
    if os.path.isfile(base):
        return [rel_dir] if rel_dir.endswith(".md") else []
    out = []
    for dirpath, _, files in os.walk(base):
        for f in files:
            if f.endswith(".md"):
                out.append(os.path.relpath(os.path.join(dirpath, f), ROOT))
    return sorted(out)


def prose(line):
    """リンク先とコードを除いた、読まれる文だけを返す。"""
    return CODE_SPAN.sub("", LINK.sub("]()", line))


def column_table_errors():
    """コードで宣言した列と、設計書の列の一覧の食い違い。"""
    errors = []
    for code, doc, heading in COLUMN_TABLES:
        with open(os.path.join(ROOT, code), encoding="utf-8") as f:
            cols = {m.group(1) for line in f if (m := VAR.match(line))}
        listed = set()
        found = False
        with open(os.path.join(ROOT, doc), encoding="utf-8") as f:
            for line in f:
                if line.startswith(heading):
                    found = True
                    continue
                if found and line.startswith("#"):
                    break
                if found and (m := TABLE_ROW.match(line)):
                    listed.add(m.group(1))
        if not found:
            errors.append(f"{doc}: 列の一覧の節（{heading}）が無い")
            continue
        for name in sorted(cols - listed):
            errors.append(f"{doc}: {heading} に {code} の列 `{name}` が無い")
        for name in sorted(listed - cols):
            errors.append(f"{doc}: {heading} の `{name}` が {code} に無い")
    return errors


def main():
    errors = []

    for d in STATE_DIRS:
        for path in md_files(d):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                for n, line in enumerate(f, 1):
                    text = prose(line)
                    for rule, pat in (("日付・最終更新", DATE), ("作業者の名前", NAMES)):
                        m = pat.search(text)
                        if m:
                            errors.append(f"{path}:{n}: {rule}を書かない（「{m.group(0)}」）")

    for dirpath, dirs, files in os.walk(os.path.join(ROOT, "docs")):
        rel = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
        # git が扱わない、ファイルの無いフォルダは見ない
        if not any(f != ".DS_Store" for _, _, fs in os.walk(dirpath) for f in fs):
            dirs[:] = []
            continue
        if rel not in ALLOWED:
            errors.append(f"{rel}/: docs/ に無い置き場（置き場は docs/README.md の1章）")
            dirs[:] = []
            continue
        allowed = ALLOWED[rel]
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            if not name.endswith(".md") or (allowed is not None and name not in allowed):
                errors.append(f"{rel}/{name}: {rel}/ に置けない文書（案・報告・作業の計画はリポジトリの外へ）")

    for d in WORK_DIRS:
        if os.path.exists(os.path.join(ROOT, d)):
            errors.append(f"{d}/: 作業用の計画・案・報告はリポジトリに置かない")

    for path in PERSONAL_LOGS:
        if os.path.exists(os.path.join(ROOT, path)):
            errors.append(f"{path}: 個人の作業ログは廃止。作らない")

    for target in LINK_TARGETS:
        for path in md_files(target):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                for n, line in enumerate(f, 1):
                    for m in LINK.finditer(line):
                        link = m.group(1).split("#")[0]
                        if not link or re.match(r"^[a-z]+:", link) or link.startswith("/"):
                            continue
                        dest = os.path.normpath(os.path.join(os.path.dirname(os.path.join(ROOT, path)), link))
                        if not os.path.exists(dest):
                            errors.append(f"{path}:{n}: リンク切れ（{m.group(1)}）")

    errors += column_table_errors()

    if errors:
        print("文書の運用規定（docs/README.md）の違反：")
        for e in errors:
            print("  " + e)
        return 1
    print("check_docs: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
