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
| [hydra.md](game/hydra.md) | うみへび座の個別仕様。戦闘、行動判断の要件、素材と演出 |
| [architecture.md](game/architecture.md) | 設計書。Godot での作り方 |
| [stage-production.md](game/stage-production.md) | ステージ制作ガイド。制作者が使う制作・操作・試遊調整の入口 |
| [stage-production-ai.md](game/stage-production-ai.md) | AI向けの制作参照。編集先・記録分析・変更確認の進め方 |
| [stage-1.md](game/stage-1.md) | ステージ1の個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [stage-2.md](game/stage-2.md) | ステージ2の個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [stage-3.md](game/stage-3.md) | ステージ3の個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [stage-4.md](game/stage-4.md) | ステージ4の個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [stage-5.md](game/stage-5.md) | ステージ5の個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [backlog.md](game/backlog.md) | 課題 |
| [text.md](game/text.md) | ゲーム内文言の編集元と反映手順 |
| `catalog/*.md` | 量産する項目の一覧と、その運用ルール。[共有アート素材リスト](game/catalog/art-assets.md)は必要な絵・要照合の候補を洗い出し、依頼・納品・組込・確認の状態を管理する |

ルートの [SPEC.md](../SPEC.md) はヒュドラ実装の目的・検証・作業境界の入口とする。個別のゲーム仕様は `docs/game/hydra.md`、実装順とタスクは `tasks/` を参照する。

## 2. 書き方

`docs/game/` と `docs/proposals/` では、次を守る。

1. **今の状態だけを書く。** 日付、時系列、変更の経緯、「以前は〜だった」、誰が言った・決めたか、作業の過程（どう作ったか・何で生成したか）は書かない。経緯は git のコミットメッセージに残す。
2. **定義は能動的に書く。** 物事は「何であるか」「どこにあるか」「何をするか」で書き、「〜ではない」「〜しない」の形で定義しない。冒頭に概要を書くのはよい。似た文書を区別するときは、もう一方の文書に触れてよい。
3. **同じ内容は1か所だけに書く。** 正の置き場は次のとおりで、ほかの文書からはリンクする。
   - 設定と元ネタ：世界観とストーリー
   - 見た目：デザインとアートスタイル。うみへび座の個別素材と演出は [hydra.md](game/hydra.md)
   - ゲームの決まり：仕様書。うみへび座の個別仕様は [hydra.md](game/hydra.md)
   - ステージ固有のゲーム仕様：各ステージの個別仕様。ステージ1〜5は `stage-1.md`〜`stage-5.md`（例：[stage-4.md](game/stage-4.md)）。共通の決まりとボスの詳細仕様はそれぞれの正本を参照する
   - 現在使う制作の進め方：[制作ガイド](game/stage-production.md)。AIへの実装・分析依頼は [AI向け参照](game/stage-production-ai.md)、ツールの詳細な編集契約と記録形式は設計書
   - 実装パラメータの数値：`speed/data/` の `.tres`（文書には `config.xxx` やデータのファイルで示す）。到達レベル・選択間隔など設計上の目標は、ステージの個別仕様に置き、仮目標と確定目標を区別する
   - ゲーム中の文章（日本語・英語）と敵・英雄・ボスの表示名：[ゲーム内文言](game/text.md)。CSV・リソース表示名は生成結果を使う
   - 企画書だけは、要約としてほかと重なってよい。細かい数値と決まりは書かずにリンクする。
4. **決まっていないことは決めたように書かない。** 未決は「未決」と書く。採用前の案は `docs/game/` に書かず、`docs/proposals/` に置く。案が採用されたら、内容を正の置き場へ移し、案は消す。
   仕様書には目指す挙動・体験と設計上の到達目標を書く。調整の基準として採用した仮目標は、その状態を明記する。実装状況・実測値と設計目標は区別する。
5. **直すたびに構成を見直す。** 継ぎ足しで読みにくくしない。

## 3. 作業ログ

個人の作業ログ（作業・判断の履歴）は作らない。`docs/logs/` には計測・実装の報告だけを置く。

## 4. チェック

```bash
python3 tools/check_docs.py
```

検出するもの：

- `docs/game/`・`docs/proposals/` の中の日付・「最終更新」・作業者の名前
- `docs/game/` の決められた文書以外のファイル
- 個人の作業ログのファイル
- `docs/` と `AGENTS.md`・`README.md` の切れたリンク
- [設計書](game/architecture.md) 6.2 の敵の列の一覧と、`speed/scripts/data_types/enemy_table.gd` の列の食い違い

コミット前のフックを使うには、クローンごとに1回だけ次を実行する。

```bash
git config core.hooksPath .githooks
```
