# 計測の読み方

形式の正本は[設計書14.3](../../../../docs/dev/architecture.md#143-プレイの記録)。以下は調整判断のための読み方であり、入力録画の測定版と実在する項目を照合して使う。

## 照合する実装と測定版

リポジトリルートから辿る。改修で移動していればシンボルと呼び出し元を `rg` で追う。

- [play_recorder.gd](../../../../speed/scripts/dev/play_recorder.gd)：JSONL出力・区間集計・F9・性能窓・ライブ調整通知。
- [recording_identity.gd](../../../../speed/scripts/dev/recording_identity.gd)：初期条件・コード/データ/実効値の識別。
- `speed/scripts/runtime/run_simulation.gd`・`run_session.gd`：開始時の条件、ラン/世界時計、イベントの接続。
- `speed/scripts/managers/run_manager.gd`、`speed/addons/stage_launcher/`・`spawn_timeline/`：開始経路。
- [loadout_system.gd](../../../../speed/scripts/runtime/systems/loadout_system.gd)・[pickup_system.gd](../../../../speed/scripts/runtime/systems/pickup_system.gd)・[ship_system.gd](../../../../speed/scripts/runtime/systems/ship_system.gd)：装備差分・XP・実被弾の発生元。
- 同じ systems 内の `spawn_system.gd`・`combat_system.gd`・`enemy_system.gd`・`boss_system.gd`：出現、命中/撃破、局所設定の適用。ゲーム内イベントの存在とrecorderが保存する内容を区別する。

現行は `schema_version=4`・`measurement_version=1`。schema 4だけでは追加計測の有無を判別できない。ヘッダーの版・条件と `loadout`・`hurt`・`xp_*`・調整通知の実在を調べ、項目のない録画はその目的の精度を下げる。新形式でもイベントが観測区間内に発生しなければ行は出ないため、型の不在だけで機能の未対応や発生0を断定しない。未対応の測定版を現行とみなさず、対応する実装を確認するか、解釈できる範囲を限定する。

## ステージ固有の変更先を確かめる

[StageDef.enemy_tuning](../../../../speed/scripts/data_types/stage_def.gd) は敵ID → 項目名 → 数値の疎な上書きを持つ。RuntimeStageが引き継ぎ、EnemySystemがラン専用のEnemyDef複製へ解決する。[StageEnemyTuning](../../../../speed/scripts/data_types/stage_enemy_tuning.gd) の許可項目を確認し、標準HP・装甲・移動等と、該当敵の数値 `params.*` を調整対象にする。`hp` は星の計算後の標準HP、`params.*` は行動値の絶対値で、未指定は共通値を使う。報酬等の除外項目も確認する。共通敵定義の直接編集で局所調整を代用しない。

`enemy_attack_values/priorities`、時間帯の `attack_budget`、クリップの `formation_values/attack_priority` は攻撃の同時実行枠・優先度。攻撃ダメージや射程の上書きに使わない。クリップの `interval` は群れの出現間隔で、敵の `params.fire_interval` と区別する。クリップ別の任意戦闘値上書きを実装済みとみなさない。

## 目的別に使える指標と限界

| 調整目的 | 観測・集計できること | 推定に留まること・注意点 |
|---|---|---|
| ステージの密度・忙しさ | `sample.enemies/in_view/by_star`、種類別区間撃破数、クリップ群の出現/終了、被弾と攻撃予算の最大使用量 | 全雑魚の出現台帳・位置履歴、攻撃開始/終了・予算待ち理由は残らない。予算最大値だけで重なった攻撃を特定しない |
| 敵攻撃力・危険な攻撃 | `hurt` の時刻・単発量・原因/発生元・直後HPから、実被弾の回数と分布を集計できる | 攻撃試行数や無効化された攻撃の全件数がなく、命中率・回避率は出せない。発生元の空欄を敵へ割り当てない。致死超過分を実効HP減少と区別する |
| 成長の速さ・選択機会 | `levelup` の到達秒、`pick` の候補/選択、`loadout` の実変更、XP供給/取得/残存、記録された必要XP式と能力値 | 適格な開始条件と調整目標を必要な範囲で照合する。選択保留とXP獲得の遅れを分け、レベルと装備・機体の強さを別軸にする |
| XP出所・大結晶の寄与 | `xp_drop/collect/transfer/existing` で結晶ID・出所・供給/取得・方法・合流・運搬を追える。大結晶は段・敵種も持つ | 出所混在や観測前由来不明を保持する。供給と取得を区別し、合流前XPや運搬後の再ドロップを新規供給に重ねない |
| 強敵の硬さ・処理速度 | `strong` の出現秒・生存ラン秒、体当たり回数、原因別ダメージ、とどめ原因 | `strong` 行に個体ID・実効HP・サイズ/エリート補正はない。途中録画前の出現は追跡されない。終了未観測を撃破時間に含めない |
| 武器・特性の寄与 | 開始装備＋`loadout` で装備区間を復元し、`dealt/kills_by`・`strong.by_cause` を対応づける | 与ダメージは超過分を含む。発射数・全命中台帳・敵別実効ダメージがなく、命中率・単独の因果効果は出せない。原因IDと武器IDの対応を実装で確認する |
| 性能 | 実時間窓のフレーム間隔、閾値超過数、ヒットストップ等の観測、書込時点のオブジェクト数 | CPU/GPU原因、実行機器・描画環境の一致、窓内最大物体数、入力遅延、フレーム時間の分位点は分からない |
| 再現性・ライブ調整 | `conditions`・`identity` のコード/データ/実効値ハッシュ、設定・強化・能力値・乱数、敵設定変更/保存の履歴 | 識別は記録された範囲に限る。空のリビジョン、後読み込みや記録対象外の実行中変更、操作入力の再生を補完しない |

## 実行条件とライブ調整の区間

`run_start.conditions` はラン初期化、`recording_start.conditions` は録画開始時の値として分ける。`identity` のディスク上のコード/データハッシュと、読み込み済みScript本文・実効資源のハッシュを区別する。`build_revision` は環境で指定した場合だけ存在し得る値で、空なら不明。`source_files_available` と各一覧の欠落を確認する。`rng_seed/rng_state` は文字列として比較し、入力なしにランを再現できるとは扱わない。

`stage_file_sha256_at_start` の対象は実際の `resource_path`。通常ランの生成済み `.content/` RuntimeStageと編集元 `data/stages/` を取り違えず、全依存の一致は `identity` の観測範囲と照合する。録画開始後の全設定変更が網羅されるとは仮定しない。

敵の設定区間は `recording_start.conditions.enemy_tuning` から始め、`enemy_tuning_changed.values` で辞書全体を置き換える。空辞書は全解除。適用時刻は `event_t/event_world_t`、通知処理時刻は `t/world_t` と分け、同じラン秒は世界秒と行順も読む。実適用時刻が `null` なら通知時刻を正確な適用時刻とせず境界不明を残す。`enemy_tuning_saved` は保存の観測であり、適用履歴へ二重に加えない。境界を跨ぐsampleは設定混在として扱う。

## 数を読むときの注意

### 成長とXP

`sample.xp_picked/xp_dropped` は区間量、`xp_field` は時点の地面の結晶XP。開始時の `xp_gained/xp_dropped` は録画前を含む累計なので、観測区間の合計と分ける。欠けた前半の内訳を復元しない。

追加計測がある録画は `xp_drop` の結晶IDを `xp_collect` へつなぐ。機体取得は `id`、ビーコン取得は `gems` 内の `[id, XP]` を使う。`merged_from` は古い結晶の合流元IDなので、`xp` 総量を毎回新規供給として足さず `added_xp` と出所を読む。`xp_transfer` はからす座への運搬で機体の取得と区別し、敵個体IDから `crow_carry` の再ドロップへつなぐ。出所が混ざる経路の内訳を根拠なく一つへ割り当てない。

途中録画の `xp_existing` は地面/運搬中の残存を引き継ぐが、`origin=unobserved` を保ち、生成時刻や元の敵を補わない。供給・取得・残存の差をそのまま消失量と断定しない。

`big_crystal`・`end.big_crystals`・`xp_drop` は同じ供給を複数の粒度で表し得るので、主に使う系列を選び他は照合に使う。追加計測のない録画では大結晶の供給までを分析し、取得対応を創作しない。旧形式の `xp_capsule_spawn/collect/lost`・`capsule_config`・`xp_capsules` は別の仕組みとして分析し、現行結晶へ変換しない。

### ビルドと原因別の戦闘量

`loadout` の `kind/id/previous/current/source` を時刻・行順に適用する。`current=0` は解除。初期選択・通常カード・おまけ・彗星取得/交換・直接変更・全解除を追い、取得時の `definition_sha256` も条件の照合に使う。`previous` と復元状態が合わなければ欠測や開始条件の差として示す。`pick` は候補と選択を読むために使い、選択段や `bonus` を装備差分へ重ねない。追加計測のない旧録画では初期武器やおまけ対象等が欠けるため、過去の装備を最終装備から埋めない。

英雄の力や記録対象外の変更を完全な履歴とみなさない。原因IDには武器以外の体当たり・特性・連鎖等も含まれるので該当実装へ辿る。原因別の区間量/観測時間を示す場合も、超過分込みの出力量と明記し、敵HPへ与えた実効DPSや武器単独の強さへ読み替えない。

`dealt` と `strong.weapon_damage/by_cause` は重複する集計。`hurt` と `sample.damage` も重複するので別系列として照合する。強敵の「武器」ダメージにはrecorderが `ram/bump/touch` 以外として数えた原因が入る。`rams` は体当たり命中回数で、ダメージ量ではない。`finale` 撃破は除外され、ボス最終撃破は専用処理なので種類別撃破や `strong` を完全なボス台帳にしない。

強敵の `alive` はrecorderの追跡状態で、ボーナス等で撃破せず消えた個体の実在保証にはならない。`clip_group_end` も群の有効個体がなくなった通知であり、全員を攻撃で撃破したと断定しない。`strong.life` はラン秒の差で、ボーナス等を含む実経過秒とは異なる。終了未観測は打ち切りとして分ける。

### 時間と性能

総FPSは `sum(frames) / sum(duration_real)`、平均フレーム時間は `1000 * sum(duration_real) / sum(frames)`。閾値超過率・ヒットストップ観測率は各回数合計/総フレーム数を使う。窓のFPSや割合を単純平均しない。窓の最大フレーム時間を分位点へ変換できない。

`real_t` は書込時刻、性能窓は `window_start_real/window_end_real`、`duration_real` は観測間隔の合計。`objects_at_write/bonus_at_write` は書込時点で、窓全体の最大・平均・状態を保証しない。ヒットストップ観測率は停止時間率ではなく、描画FPS低下の原因と決めない。

## 不足の優先順位を選ぶ

今回の問いを妨げる不足を、入力録画の実在項目から選ぶ。追加計測済みの装備差分・実被弾・XP経路・条件識別を未実装として挙げない。旧録画の不足なら新しい版での録画を提案し、新形式でも攻撃試行・全個体HP/命中履歴・入力等が必要な問いは、その判断に必要な最小限の追加観測を示す。既存の集計と感想で足りる場合は詳細記録を一律に必須としない。追加計測や実装は依頼範囲内で行う。
