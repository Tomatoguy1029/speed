#!/usr/bin/env python3
"""文書の運用規定（docs/README.md）のチェック。違反があれば一覧を出して終了コード1で終わる。

使い方: python3 tools/check_docs.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# docs/game/ に置ける文書（catalog/ の中は自由）
GAME_DOCS = {"treatment.md", "world.md", "art-style.md", "spec.md", "architecture.md", "backlog.md"}
# 今の状態だけを書く置き場
STATE_DIRS = ["docs/game", "docs/proposals"]
# 廃止した個人の作業ログ
PERSONAL_LOGS = [f"{d}/{n}.md" for d in ("docs/logs", "demo/docs") for n in ("wakida", "shumak", "keporusu")]
# リンク切れを調べる文書
LINK_TARGETS = ["docs", "AGENTS.md", "README.md"]

DATE = re.compile(r"\d{4}-\d{1,2}-\d{1,2}|\d{4}年\d{1,2}月(\d{1,2}日)?|\d{1,2}月\d{1,2}日|最終更新")
NAMES = re.compile(r"Tomatoguy|ShueMaker|keporusu|wakida|shumak", re.IGNORECASE)
SELF_REF = re.compile(r"この(文書|資料|ドキュメント|一覧|章|節)|本文書")
LINK = re.compile(r"\]\(([^)\s]+)\)")
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


def main():
    errors = []

    for d in STATE_DIRS:
        for path in md_files(d):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                for n, line in enumerate(f, 1):
                    text = prose(line)
                    for rule, pat in (("日付・最終更新", DATE), ("作業者の名前", NAMES), ("文書自身についての説明", SELF_REF)):
                        m = pat.search(text)
                        if m:
                            errors.append(f"{path}:{n}: {rule}を書かない（「{m.group(0)}」）")

    game = os.path.join(ROOT, "docs/game")
    for name in sorted(os.listdir(game)):
        if name == "catalog":
            continue
        if name not in GAME_DOCS:
            errors.append(f"docs/game/{name}: docs/game/ に置けない文書（案は docs/proposals/、報告は docs/logs/ へ）")

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

    if errors:
        print("文書の運用規定（docs/README.md）の違反：")
        for e in errors:
            print("  " + e)
        return 1
    print("check_docs: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
