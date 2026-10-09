# 本番の特性一覧

[一覧の運用ルール](rules.md) に従う。管理 ID は demo から引き継ぐ。共通のルール（枠・重ね数・段階の色）は [仕様書](../spec.md) の8章。demo の候補・保留・不採用（T15〜T30）は本番に登録していない。

数値の正は文書ではなく `.tres`。各特性の数値は `speed/data/traits/<ID>_<内部ID>.tres` が正で、Godot エディタの「データ編集」（メニューバーの「プロジェクト → ツール」）で見て調整する。能力値を変える特性（T07〜T12、T14）は、重ねるごとの効果を `per_stack`（T09 は上限 `max` も）に持つ。

## 採用

| ID | 名称 | 採用状態 | 発動・効果 | ルート・成長への影響 | 本番の実装状況・コード参照 | demo参照・重ね掛け・未決事項 |
|---|---|---|---|---|---|---|
| T01 | 終端爆縮 | 採用 | 線の終点（弾かれた地点を含む）で爆発 | 終点を密集地点にする | 実装済み。`scripts/traits/endBlast.gd`、`data/traits/T01_endBlast.tres` | [demo T01](../../../demo/docs/traits.md) `endBlast`。最大5重ね |
| T03 | 余韻の渦 | 採用 | 線の終点に、敵を吸い寄せる渦を残す。ボスは引き寄せない | 次の群れ作りにも終点を使う | 実装済み。`scripts/traits/vortex.gd`、`data/traits/T03_vortex.tres` | [demo T03](../../../demo/docs/traits.md) `vortex`。最大5重ね |
| T04 | 満タン突撃 | 採用 | 満タンから始めた線をなぞっている間は、装甲を無視して攻撃力が上がる。線が終わると戻る | 早く撃つか、満タンで硬い敵を抜くか | 実装済み。`scripts/traits/fullCharge.gd`、`data/traits/T04_fullCharge.tres` | [demo T04](../../../demo/docs/traits.md) `fullCharge`。最大5重ね |
| T05 | 連鎖ソニック | 採用 | 1回の突進で一定数を倒すたびに衝撃波。衝撃波の撃破からは次を起こさない。W08 とは別 | 多く倒せる線を選ぶ | 実装済み。`scripts/traits/killSonic.gd`、`data/traits/T05_killSonic.tres` | [demo T05](../../../demo/docs/traits.md) `killSonic`。最大5重ね |
| T06 | クリティカルランス | 採用 | クリティカルのたびに進む向きへ貫くビーム。ビームからは再び発動しない | 命中した先に別の敵が並ぶ線 | 実装済み。`scripts/traits/critBeam.gd`、`data/traits/T06_critBeam.tres` | [demo T06](../../../demo/docs/traits.md) `critBeam`。最大5重ね |
| T07 | 急速充填 | 採用 | ゲージの充填が速くなる | 次の高速攻撃が早く使える | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T07_quickCharge.tres` | [demo T07](../../../demo/docs/traits.md) `quickCharge`。最大5重ね |
| T08 | 大容量チャージ | 採用 | ゲージの容量が増え、1回で描ける長さと勢いが伸びる。回数のストックではない | 1回で長い線を通る | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T08_capacity.tres` | [demo T08](../../../demo/docs/traits.md) `capacity`。最大5重ね |
| T09 | クリティカル率 | 採用 | クリティカルが出やすくなる（上限あり） | T06 の発動が増える | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T09_critRate.tres` | [demo T09](../../../demo/docs/traits.md) `critRate`。最大5重ね |
| T10 | 最高速度 | 採用 | 最高速度が上がる。威力は上がらない | 移動と描ける長さが伸びる | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T10_speed.tres` | [demo T10](../../../demo/docs/traits.md) `speed`。最大5重ね |
| T11 | 攻撃力 | 採用 | すべての攻撃の攻撃力の倍率が上がる | 倒せる・装甲を抜ける敵が変わる | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T11_attack.tres` | [demo T11](../../../demo/docs/traits.md) `attack`。最大5重ね |
| T12 | 広域回収 | 採用 | 回収範囲が広がる | アイテムに近づく必要が減る | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T12_pickup.tres` | [demo T12](../../../demo/docs/traits.md) `pickup`。最大5重ね |
| T13 | 反応波動 | 採用 | 実際にダメージを受けたとき、周りを押し返す波動 | 被弾のあとの周りを押し返す | 実装済み。`scripts/traits/reactive.gd`、`data/traits/T13_reactive.tres` | [demo T13](../../../demo/docs/traits.md) `reactive`。最大5重ね |
| T14 | 軌跡延長 | 採用 | 描ける長さが伸びる。容量・最高速度とは別の倍率 | 複数の群れを1回で通る | 実装済み。`BuildManager.refresh_stats()`、`data/traits/T14_length.tres` | [demo T14](../../../demo/docs/traits.md) `length`。最大5重ね |

## 保留・不採用

なし。

## 廃止

| ID | 名称 | 状態・理由 | 実装状況 |
|---|---|---|---|
| T02 | 交差爆破 | 不採用（廃止） | 定義・発動処理・カードプレビューを削除し、取得・強化候補から除外。管理IDは再利用しない。[demo T02](../../../demo/docs/traits.md) は変更していない |
