# ステージ制作のAI向け参照

[制作ガイド](stage-production.md)を使う制作者から、実装・データ編集・記録分析を受け取るAIの参照先と確認手順。最初に[AGENTS.md](../../AGENTS.md)と[文書規定](../README.md)を読み、担当ステージの仕様、対象データ、依頼範囲を確認する。ステージ4は[個別仕様](../game/stages/stage-4.md)を入口とする。敵・ボスの案を出すときは[制作ガイドの設計の進め方](stage-production.md#4-敵とボスを設計する)に従う。

## 編集先を選ぶ

以下のパスは本番プロジェクトの `speed/` からの相対パス。

| 依頼 | 編集・確認する場所 | 参照する定義 |
|---|---|---|
| フェーズ・雑魚の曲線・強敵の出現 | `data/stages/stage_*.tres` | `scripts/data_types/stage_def.gd`・`phase_def.gd`・`spawn_curve.gd`・`spawn_clip.gd`、[出現仕様](../game/spec.md#113-出現と補充) |
| 群れの形と出現位置 | `data/formations/*.tscn` | `scripts/encounters/` の `EnemyFormation`・`FormationLayout`・`FormationMarker`・`FormationEntry`、[配置の構造](architecture.md#81-定義データresource) |
| 強敵の同時攻撃 | ステージの `phases[].attack_budget`・`enemy_attack_values`、クリップの `attack_priority`・`formation_values` | [攻撃の管理](../game/spec.md#117-敵の攻撃の形)、`scripts/encounters/attack_director.gd` |
| 敵の基本値と行動 | `data/enemies/<type ID>.tres`、`scripts/managers/enemy_manager.gd`、種類別の `scripts/enemies/` | `scripts/data_types/enemy_def.gd`、[敵一覧](../game/catalog/enemies.md)と実装を照合する |
| 成長とドロップ | `data/config.tres`、対象敵と時間帯のデータ | [成長](../game/spec.md#9-成長)・[ドロップ](../game/spec.md#10-ドロップと回収)、`scripts/managers/build_manager.gd`・`pickup_manager.gd` |
| ボス | 対象の `data/bosses/`・`scenes/bosses/`・`scripts/bosses/` | ボスの個別仕様と[AI・技・演出の分担](architecture.md#61-敵とボスの-ai) |
| 敵の絵・攻撃の描画 | `assets/pixel/`、`scripts/managers/render_manager.gd`、対象の描画処理 | [アートスタイル](../game/art-style.md)・[素材の入口](../../speed/assets/pixel/README.md)。ヒュドラは[個別素材と演出](../game/bosses/hydra.md#8-素材と演出) |

ステージの `phases` が参照するリソースを辿って編集する。専用時間帯はステージ内部にも保存でき、`data/phases/s4_*.tres` の存在だけでは通常ランへの適用を判断できない。雑魚の曲線を持つステージでは、時間帯の `mix`・`pop_from`・`pop_to` より曲線を確認する。

HPは `EnemyDef.base_hp()` の計算結果で確認する。星の基準対象は `config.rank_hits`・`base_attack` と敵の `toughness` を使い、`hp` 欄と実効HPを区別する。サイズ・エリートなどの補正は[敵の共通仕様](../game/spec.md#111-見た目と強さ)へ辿る。武器・特性の威力は、保存値・攻撃力に対する倍率・成長後の計算値を分ける。

ステージリソースの `scene_path` を使うときは、実ファイルと呼び出し箇所を確認する。ステージ4の当該パスは参照先シーンが存在せず、現在の確認入口は制作ガイドにある通常起動とタイムラインを使う。

## プレイ記録を読む

記録の保存先・各行の形式・開始条件の判定は[設計書14.3](architecture.md#143-プレイの記録)を正とする。分析の前に、そこにある区分で各ファイルを通常バランス分析・区間検証・前半欠落・出自不明に分け、対象に採った範囲と除外理由を示す。

1. **基準を照合する。** ステージ番号、記録形式、`run_start`、`recording_start`、`missing_prefix`、終了の有無を読む。開始時のステージハッシュと現データを比較し、不一致は別の設定として扱う。このハッシュが照合する範囲はステージファイル本体で、敵・武器・共通設定の一致は別に確認する。
2. **フェーズで切る。** 記録内の `bands`・`band` と各行のラン秒を使う。変更後のフェーズ境界を古い記録へ無断で当てはめる扱いを避ける。成長はステージ仕様の到達レベル・選択間隔・ボス前の装備完成度と比較する。仮目標も設計上の基準として、実測との差を示す。目標が未決・要確認の箇所は実測値だけを報告する。
3. **感想と数を対応づける。** 下表の指標を、該当区間の感想と併せて読む。記録にない値は現コードからの計算・推定として分け、観測が欠けた区間は欠測として扱う。
4. **変更案を出す。** 目指す仕様と実測の差から、根拠の時刻・フェーズ、触るファイルと項目、現在値→候補値、狙う変化、再試遊の確認点を短く示す。仕様の到達目標と、そこへ近づけるための実装パラメータを分け、数値・設計の合意を得てから編集する。

| 調べること | 主に見る記録 |
|---|---|
| 成長の速さ・拾い損ね | `levelup`、`sample` のレベル・取得/ドロップ/残存XP、`big_crystal` の時刻・段・量・落とした敵 |
| 敵の密度と圧力 | `sample` の敵数・画面内数・被弾原因、`clip_group`・`clip_group_end` |
| 強敵が何で倒れたか | `strong` の生存時間・体当たり回数・`by_cause`・`killed_by`、`sample.kills_by`・`dealt` |
| 攻撃の重なり | `sample.attack_budget_max` と該当時間帯の設定、被弾原因、実際の試遊の感想 |
| 処理の重さ | `performance` を、ラン秒・実秒・ボーナス・ラン状態・ヒットストップと対応づける |

`sample` の区間集計と累計を区別し、同じ累計を重ねて合算する扱いを避ける。`dealt` は倒しきった余りも含むため、実効HPへ与えたダメージと区別する。強敵のHPや攻撃が出なかった原因は、必要な記録・実装・画面の確認が揃った範囲で判断する。

必要XPを変える案は、[結晶と大きい結晶の量の決まり](../game/spec.md#10-ドロップと回収)も照合する。通常の結晶と大きい結晶の影響を分け、供給量・取得機会・回収方法のどこが原因かを確認する。

## 編集後に確認する

- 依頼されたステージ・敵だけを編集する。全ステージ共通値の変更が必要なら、その影響も相談する。出現数を変える案と攻撃の重なりを変える案は、それぞれ対象を明示する。
- 編成の種類とステージ/クリップの種類を照合し、タイムラインの警告、保存後のリソース読み込み、変更に応じた短い画面確認を行う。ゲームの自動テスト・長時間自動プレイは依頼時に実行する。
- 素材・見た目・挙動の仮実装と、試遊による品質確認を分けて報告する。実験場の書き出しを本番へ反映する場合は[採用手順](../game/spec.md#201-敵ルート実験場)を使う。
- 文書を変えたら `python3 tools/check_docs.py` を実行する。敵・武器・特性の仕様を変えた作業では[一覧ルール](../game/catalog/rules.md)に沿って同じ作業で更新する。
