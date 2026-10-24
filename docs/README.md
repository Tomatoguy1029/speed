# 文書の運用規定

`docs/` を触る人とエージェントは、作業の前にこの規定を読み、必ず従う。違反は `python3 tools/check_docs.py` で検出し、コミット前のフックと GitHub Actions で止める。

## 1. 置き場

`docs/` には、現行仕様と今後実装する仕様、現在の実装状況を置く。開発に関わる全員が、文書だけでゲームの仕様と実装状況を正しく知れる状態を保つ。

文書は抽象度で配置する。ゲーム全体を定義する企画書・仕様書・設計書は `docs/` 直下の同じ階層に置く。設定・見た目・文言・個別仕様は `game/`、制作手順は `dev/` の下位資料として管理する。

| 置き場 | 置くもの |
|---|---|
| `docs/` | ゲーム全体の企画書・仕様書・設計書と、この文書運用規定 |
| `docs/game/` | 世界観・アート・文言の個別資料と課題 |
| `docs/game/catalog/` | 武器・特性・敵・素材など量産する項目の一覧と、[一覧の運用ルール](game/catalog/rules.md) |
| `docs/game/stages/` | ステージごとの個別仕様（`stage-1.md`〜`stage-5.md`） |
| `docs/game/bosses/` | ボスごとの詳しい仕様。ステージの個別仕様からリンクする |
| `docs/dev/` | 制作手順。ステージ制作の進め方とAI向けの参照 |

置ける文書は次のものだけ。増やすときは、この表と `tools/check_docs.py` を同じ作業で直す。

| 文書 | 中身 |
|---|---|
| [treatment.md](treatment.md) | 企画書。ゲームを知らない人に全体像をイメージさせる数ページの要約 |
| [spec.md](spec.md) | 仕様書。全ステージに共通するゲームの決まり |
| [architecture.md](architecture.md) | 設計書。Godot での作り方 |
| [game/world.md](game/world.md) | 世界観とストーリー。設定と元ネタ |
| [game/art-style.md](game/art-style.md) | デザインとアートスタイル。見た目 |
| [game/graphics-improvements.md](game/graphics-improvements.md) | グラフィック改善ポイント。UIのレイアウト・色・アニメーション・エフェクトの改善要件 |
| [game/text.md](game/text.md) | ゲーム内文言の編集元と反映手順 |
| [game/backlog.md](game/backlog.md) | 課題 |
| `game/catalog/*.md` | 量産する項目の一覧と、その運用ルール。[共有アート素材リスト](game/catalog/art-assets.md)は必要な絵・要照合の候補を洗い出し、依頼・納品・組込・確認の状態を管理する |
| `game/stages/stage-1.md`〜`stage-5.md` | ステージの個別仕様。狙う体験・フェーズ・敵の役割・ボス戦 |
| [game/bosses/monoceros.md](game/bosses/monoceros.md) | いっかくじゅう座の個別仕様。戦闘・行動判断の要件・素材と演出・実装と調整 |
| [game/bosses/centaurus.md](game/bosses/centaurus.md) | ケンタウルス座の個別仕様。核と、戦闘・行動判断の要件・素材と演出の雛形 |
| [game/bosses/canis-major.md](game/bosses/canis-major.md) | おおいぬ座の個別仕様。核と、戦闘・行動判断の要件・素材と演出の雛形 |
| [game/bosses/hydra.md](game/bosses/hydra.md) | うみへび座の個別仕様。戦闘、行動判断の要件、素材と演出 |
| [game/bosses/draco.md](game/bosses/draco.md) | りゅう座の個別仕様。戦闘・行動判断の要件・素材と演出・最終決着 |
| [dev/stage-production.md](dev/stage-production.md) | ステージ制作ガイド。制作者が使う制作・操作・試遊調整の入口 |
| [dev/stage-production-ai.md](dev/stage-production-ai.md) | AI向けの制作参照。編集先・記録分析・変更確認の進め方 |

採用前の案、計測・実装の報告、特定の作業のための計画・タスク一覧・引継ぎは、リポジトリの外（会話や各自のローカル）に置く。

## 2. 書き方

`docs/` の文書では、次を守る。

1. **今の状態だけを書く。** 現行仕様と今後実装する仕様は、内容を直接記述する。「決定事項」「採用案」など、経緯を示す見出しや状態語を付けない。日付、時系列、変更の経緯、「以前は〜だった」、誰が言った・決めたか、作業の過程（どう作ったか・何で生成したか）は書かない。経緯は git のコミットメッセージに残す。
2. **定義は能動的に書く。** 物事は「何であるか」「どこにあるか」「何をするか」で書き、「〜ではない」「〜しない」の形で定義しない。冒頭に概要を書くのはよい。似た文書を区別するときは、もう一方の文書に触れてよい。
3. **同じ内容は1か所だけに書く。** 正の置き場は次のとおりで、ほかの文書からはリンクする。
   - 設定と元ネタ：世界観とストーリー
   - 見た目：デザインとアートスタイル。ボスの個別素材と演出は `game/bosses/` の各ボスの仕様。UIのグラフィック改善要件は[グラフィック改善ポイント](game/graphics-improvements.md)、必要な画像・素材は[共有アート素材リスト](game/catalog/art-assets.md)
   - ゲームの決まり：仕様書。ボスの個別仕様は `game/bosses/`、個別の武器・特性・敵の詳しい仕様は `game/catalog/` の各一覧
   - ステージ固有のゲーム仕様：各ステージの個別仕様。`game/stages/` の `stage-1.md`〜`stage-5.md`（例：[stage-4.md](game/stages/stage-4.md)）。共通の決まりとボスの詳細仕様はそれぞれの正本を参照する
   - 現在使う制作の進め方：[制作ガイド](dev/stage-production.md)。AIへの実装・分析依頼は [AI向け参照](dev/stage-production-ai.md)、ツールの詳細な編集契約と記録形式は設計書
   - 実装パラメータの数値：`speed/data/` の `.tres`（文書には `config.xxx` やデータのファイルで示す）。到達レベル・選択間隔など設計上の目標は、ステージの個別仕様に置き、仮目標と確定目標を区別する
   - ゲーム中の文章（日本語・英語）と敵・英雄・ボスの表示名：[ゲーム内文言](game/text.md)。CSV・リソース表示名は生成結果を使う
   - 企画書だけは、要約としてほかと重なってよい。細かい数値と決まりは書かずにリンクする。
4. **決まっていないことは決めたように書かない。** 未決は「未決」と書く。採用前の案は `docs/` に書かず、リポジトリの外に置く。案が採用されたら、内容を正の置き場へ書く。
   仕様書には目指す挙動・体験と設計上の到達目標を書く。調整の基準として採用した仮目標は、その状態を明記する。実装状況・実測値と設計目標は区別する。
   一覧の採用状態・保留・不採用、実装状況、仮目標、未決事項など、現在の状態を表す情報は残す。未確定の選択肢は、語だけを消して確定仕様に変えない。
5. **直すたびに構成を見直す。** 継ぎ足しで読みにくくしない。

## 3. 作業ログ

個人の作業ログ（作業・判断の履歴）は作らない。経緯は git のコミットメッセージに残す。

## 4. チェック

```bash
python3 tools/check_docs.py
```

検出するもの：

- `docs/` の中の日付・「最終更新」・作業者の名前
- `docs/` の決められた文書以外のファイル
- 個人の作業ログのファイル
- リポジトリの `tasks/`・`docs/proposals/`・`docs/logs/`
- `docs/` と `AGENTS.md`・`README.md` の切れたリンク
- [設計書](architecture.md) 6.2 の敵の列の一覧と、`speed/scripts/data_types/enemy_table.gd` の列の食い違い

コミット前のフックを使うには、クローンごとに1回だけ次を実行する。

```bash
git config core.hooksPath .githooks
```
