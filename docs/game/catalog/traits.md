# 本番の特性一覧

[一覧の運用ルール](rules.md) に従う。管理 ID は demo から引き継ぐ。共通のルール（枠・重ね数・段階の色）は [仕様書](../../spec.md) の8章。demo の候補・保留・不採用（T15〜T30）は本番に登録していない。

表示用の名前・説明は [ゲーム内文言](../text.md) を正とする。

数値の正は文書ではなく `.tres`。各特性の数値は `speed/data/traits/<ID>_<内部ID>.tres` が正で、Godot エディタの「データ編集」（メニューバーの「プロジェクト → ツール」）で見て調整する。各特性のLv4・5の現在値は試遊で確認する調整値。能力値を変える特性（T07〜T12、T14、T31）は、2重ね目以降の増分を `per_stack` に持ち、1重ね目が異なる場合は `first_stack` に持つ。T09 は4・5重ね目の `late_per_stack` と上限 `max` も使う。

## 採用

| ID | 名称 | 採用状態 | 発動・効果 | ルート・成長への影響 | 本番の実装状況・コード参照 | demo参照・重ね掛け・未決事項 |
|---|---|---|---|---|---|---|
| T01 | 終端爆縮 | 採用 | 線の終点（弾かれた地点を含む）で爆発 | 終点を密集地点にする | 実装済み。`scripts/traits/endBlast.gd`、`data/traits/T01_endBlast.tres` | [demo T01](../../../demo/docs/traits.md) `endBlast`。最大5重ね |
| T03 | 余韻の渦 | 採用 | 線の終点に、敵を吸い寄せる渦を残す。ボスは引き寄せない | 次の群れ作りにも終点を使う | 実装済み。`scripts/traits/vortex.gd`、`data/traits/T03_vortex.tres` | [demo T03](../../../demo/docs/traits.md) `vortex`。最大5重ね |
| T04 | 満タン突撃 | 採用 | 満タンから始めた線をなぞっている間は、装甲を無視して攻撃力が上がる。線が終わると戻る | 早く撃つか、満タンで硬い敵を抜くか | 実装済み。`scripts/traits/fullCharge.gd`、`data/traits/T04_fullCharge.tres` | [demo T04](../../../demo/docs/traits.md) `fullCharge`。最大5重ね |
| T05 | 連鎖ソニック | 採用 | 1回の突進で一定数を倒すたびに衝撃波。衝撃波の撃破からは次を起こさない。雑魚を払う役で、3重ねまでは衝撃波が出る間隔が縮み、4・5重ねでは間隔を保ちながら範囲と威力が伸びる。W08 とは別 | 多く倒せる線を選ぶ | 実装済み。`scripts/traits/killSonic.gd`、`data/traits/T05_killSonic.tres` | [demo T05](../../../demo/docs/traits.md) `killSonic`。最大5重ね |
| T06 | クリティカルランス | 採用 | クリティカルのたびに進む向きへ貫く光の槍。槍からは再び発動しない | 命中した先に別の敵が並ぶ線 | 実装済み。`scripts/traits/critBeam.gd`、`data/traits/T06_critBeam.tres`。発動時だけ `scripts/render/light_lance.gd` と `shaders/light_lance.gdshader` で白金色のピクセル調の槍とドット光跡を飛ばす。到達後は描画側の `HOLD_TIME` の間だけ形を保ち、`FADE_TIME` で発動ごとに消す | [demo T06](../../../demo/docs/traits.md) `critBeam`。最大5重ね |
| T07 | 急速充填 | 採用 | ゲージの充填が速くなる | 次の高速攻撃が早く使える | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T07_quickCharge.tres` | [demo T07](../../../demo/docs/traits.md) `quickCharge`。最大5重ね |
| T08 | 大容量チャージ | 採用 | ゲージの容量が増え、1回で描ける長さと勢いが伸びる。回数のストックではない | 1回で長い線を通る | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T08_capacity.tres` | [demo T08](../../../demo/docs/traits.md) `capacity`。最大5重ね |
| T09 | クリティカル率 | 採用 | クリティカルが出やすくなる（上限あり） | T06 の発動が増える | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T09_critRate.tres` | [demo T09](../../../demo/docs/traits.md) `critRate`。最大5重ね |
| T10 | 最高速度 | 採用 | 最高速度が上がる。威力は上がらない | 移動と描ける長さが伸びる | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T10_speed.tres` | [demo T10](../../../demo/docs/traits.md) `speed`。最大5重ね |
| T11 | 攻撃力 | 採用 | すべての攻撃の攻撃力の倍率が上がる | 倒せる・装甲を抜ける敵が変わる | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T11_attack.tres` | [demo T11](../../../demo/docs/traits.md) `attack`。最大5重ね |
| T12 | 広域回収 | 採用 | 回収範囲が広がる | アイテムに近づく必要が減る | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T12_pickup.tres` | [demo T12](../../../demo/docs/traits.md) `pickup`。最大5重ね |
| T13 | 反応波動 | 採用 | 実際にダメージを受けたとき、周りを押し返す波動 | 被弾のあとの周りを押し返す | 実装済み。`scripts/traits/reactive.gd`、`data/traits/T13_reactive.tres` | [demo T13](../../../demo/docs/traits.md) `reactive`。最大5重ね |
| T14 | 軌跡延長 | 採用 | 描ける長さが伸びる。容量・最高速度とは別の倍率 | 複数の群れを1回で通る | 実装済み。`LoadoutSystem.refresh_stats()`、`data/traits/T14_length.tres` | [demo T14](../../../demo/docs/traits.md) `length`。最大5重ね |
| T31 | 高速持続（仮名） | 採用 | 突進後の保持時間と減速時間を同じ倍率で伸ばす | 突破後に高速で移動できる時間が伸びる | 実装済み。`LoadoutSystem.refresh_stats()`、`ShipSystem._step()`、`data/traits/T31_glideDuration.tres` | 最大5重ね。名称・数値の品質確認は未完了 |

### 各特性の重ね掛け

各列は取得後のLvを表す。`n` は列のLv（1、2、3、4、5）で、発動型の各パラメータは `.tres` の `<項目>_base + <項目>_per × n` を使う。能力値型はLv1に `first_stack`（未指定なら `per_stack`）、Lv2以降に `per_stack`、T09のLv4・5に `late_per_stack` を足す。数値と各パラメータの正は上記の `.tres` に置く。

| ID | Lv1 | Lv2 | Lv3 | Lv4 | Lv5 |
|---|---|---|---|---|---|
| T01 | 終点の爆発 | 爆発の範囲・威力増 | 範囲・威力増 | 範囲・威力増 | 範囲・威力増 |
| T03 | 終点の渦 | 渦の範囲・寿命・吸引力増 | 3項目増 | 3項目増 | 3項目増 |
| T04 | 満タン時の装甲無視・威力増 | 威力倍率増 | 威力倍率増 | 威力倍率増 | 威力倍率増 |
| T05 | 突進中の撃破で衝撃波 | 必要撃破数が減り、範囲・威力増 | 必要撃破数が減り、範囲・威力増 | 必要撃破数は下限を保ち、範囲・威力増 | 必要撃破数は下限を保ち、範囲・威力増 |
| T06 | クリティカル時の槍 | 槍の長さ・幅・威力増 | 3項目増 | 3項目増 | 3項目増 |
| T07 | 充填速度増 | 充填速度増 | 充填速度増 | 充填速度増 | 充填速度増 |
| T08 | ゲージ容量増 | 容量増 | 容量増 | 容量増 | 容量増 |
| T09 | クリティカル率増 | `per_stack` 分増 | `per_stack` 分増 | `late_per_stack` 分増 | `late_per_stack` 分増 |
| T10 | 最高速度増 | 最高速度増 | 最高速度増 | 最高速度増 | 最高速度増 |
| T11 | 攻撃力増 | 攻撃力増 | 攻撃力増 | 攻撃力増 | 攻撃力増 |
| T12 | 回収範囲増 | 回収範囲増 | 回収範囲増 | 回収範囲増 | 回収範囲増 |
| T13 | 被弾時の波動 | 波動の範囲・威力増 | 範囲・威力増 | 範囲・威力増 | 範囲・威力増 |
| T14 | 軌跡の長さ増 | 軌跡の長さ増 | 軌跡の長さ増 | 軌跡の長さ増 | 軌跡の長さ増 |
| T31 | 高速保持・減速の時間増 | 両時間増 | 両時間増 | 両時間増 | 両時間増 |

T05の発生間隔は `max(kills_min, kills_base + kills_per × n)` で求める。衝撃波による撃破は次の衝撃波の発生条件に使わず、1回の突進ごとに撃破数を数え直す。T06の槍は発動間隔 `cooldown` を全Lvで共有し、槍から次の槍を発動しない。T09の追加強化はLv5到達後も `max` までの残りを使う。

### T31 高速持続

時間倍率の数値は試遊用の暫定値。カード・装備枠の仮アイコンは最高速度の共通素材を使う。[demo T23](../../../demo/docs/traits.md) は衝突後の加速持続と射出への持ち越しを扱う別項目。

## 保留・不採用

なし。

## 廃止

| ID | 名称 | 状態・理由 | 実装状況 |
|---|---|---|---|
| T02 | 交差爆破 | 不採用（廃止） | 定義・発動処理・カードプレビューを削除し、取得・強化候補から除外。管理IDは再利用しない。[demo T02](../../../demo/docs/traits.md) は変更していない |

### T09と通常育成完了後の強化

所持特性の育成が完了してから[追加クリティカル率](../../spec.md#通常育成完了後の追加強化)を取得できる。武器の共通ダメージ処理は既存の体当たりから渡されたクリティカル判定を使う。
