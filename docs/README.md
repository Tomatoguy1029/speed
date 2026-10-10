# 文書の運用規定

`docs/` を触る人とエージェントは、作業の前にこの規定を読み、必ず従う。違反は `python3 tools/check_docs.py` で検出し、コミット前のフックと GitHub Actions で止める。

## 1. 置き場

| 置き場 | 置くもの |
|---|---|
| `docs/game/` | 基盤の資料。決まった今の状態だけを書く |
| `docs/game/catalog/` | 武器・特性・敵など量産する項目の一覧と、[一覧の運用ルール](game/catalog/rules.md) |
| `docs/proposals/` | まだ採用していない案（画面案・外観案など） |
| `docs/logs/` | 計測・実装などの報告 |

`docs/game/` に置ける文書は次のものだけ。増やすときは、この表と `tools/check_docs.py` を同じ作業で直す。

| 文書 | 中身 |
|---|---|
| [treatment.md](game/treatment.md) | 企画書。ゲームを知らない人に全体像をイメージさせる数ページの要約 |
| [world.md](game/world.md) | 世界観とストーリー。設定と元ネタ |
| [art-style.md](game/art-style.md) | デザインとアートスタイル。見た目 |
| [spec.md](game/spec.md) | 仕様書。ゲームの決まり |
| [architecture.md](game/architecture.md) | 設計書。Godot での作り方 |
| [backlog.md](game/backlog.md) | 課題 |
| `catalog/*.md` | 量産する項目の一覧と、その運用ルール |

## 2. 書き方

`docs/game/` と `docs/proposals/` では、次を守る。

1. **今の状態だけを書く。** 日付、時系列、変更の経緯、「以前は〜だった」、誰が言った・決めたか、作業の過程（どう作ったか・何で生成したか）は書かない。経緯は git のコミットメッセージに残す。
2. **文書自身について書かない。** 「この文書は〜」「この章は〜」「更新したら〜する」などは書かない。
3. **同じ内容は1か所だけに書く。** 正の置き場は次のとおりで、ほかの文書からはリンクする。
   - 設定と元ネタ：世界観とストーリー
   - 見た目：デザインとアートスタイル
   - ゲームの決まり：仕様書
   - 数値：`speed/data/` の `.tres`（文書には `config.xxx` やデータのファイルで示す）
   - 企画書だけは、要約としてほかと重なってよい。細かい数値と決まりは書かずにリンクする。
4. **決まっていないことは決めたように書かない。** 未決は「未決」と書く。採用前の案は `docs/game/` に書かず、`docs/proposals/` に置く。案が採用されたら、内容を正の置き場へ移し、案は消す。
5. **直すたびに構成を見直す。** 継ぎ足しで読みにくくしない。

## 3. 作業ログ

個人の作業ログ（作業・判断の履歴）は作らない。`docs/logs/` には計測・実装の報告だけを置く。

## 4. チェック

```bash
python3 tools/check_docs.py
```

検出するもの：

- `docs/game/`・`docs/proposals/` の中の日付・「最終更新」・作業者の名前・文書自身についての説明
- `docs/game/` の決められた文書以外のファイル
- 個人の作業ログのファイル
- `docs/` と `AGENTS.md`・`README.md` の切れたリンク
- [設計書](game/architecture.md) 6.2 の敵の列の一覧と、`speed/scripts/data_types/enemy_table.gd` の列の食い違い

コミット前のフックを使うには、クローンごとに1回だけ次を実行する。

```bash
git config core.hooksPath .githooks
```
