# 本番の敵一覧

[一覧の運用ルール](rules.md) に従う。type ID は demo から引き継ぐ。レベル・サイズ・エリートの補正、出現、動きの共通ルールは [仕様書](../spec.md) の4.2・11章。

数値の正は `.tres`。基礎値（半径・HP・装甲・速度・接触ダメージ・経験値・行動の値）は `speed/data/enemies/<type ID>.tres`、ボスは `speed/data/bosses/`、出現の重みは `speed/data/phases/` が正で、Godot エディタの「データ編集」（メニューバーの「プロジェクト → ツール」）で見て調整する。

## 通常敵

| type ID      | 名称       | 採用状態 | 本番の実装状況 | 行動・攻撃                                                                       | 出現条件                             | コード・demo参照／未決事項                                                                                 |
| ------------ | ---------- | -------- | -------------- | -------------------------------------------------------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `drifter`    | ドリフター | 採用     | 実装済み       | 追跡と広域移動                                                                   | 全時間帯                             | `scripts/managers/enemy_manager.gd`、`data/enemies/drifter.tres`。[demo](../../../demo/docs/enemies.md)    |
| `swarm`      | スウォーム | 採用     | 実装済み       | 小型の追跡敵                                                                     | 強化期・強化期II・無双期・脱出期     | `scripts/managers/enemy_manager.gd`、`data/enemies/swarm.tres`。[demo](../../../demo/docs/enemies.md)      |
| `darter`     | ダーター   | 採用     | 実装済み       | 近づくと予告してから突進し、しばらく止まる                                       | 無双期以外                           | `scripts/managers/enemy_manager.gd`、`data/enemies/darter.tres`。[demo](../../../demo/docs/enemies.md)     |
| `armored`    | 装甲型     | 採用     | 実装済み       | 装甲の硬い追跡敵。背面に当てると必ずクリティカル                                 | 圧力期・緊張期・脱出期、危険地帯     | `scripts/managers/enemy_manager.gd`、`data/enemies/armored.tres`。[demo](../../../demo/docs/enemies.md)    |
| `splitter`   | 分裂型     | 採用     | 実装済み       | 追跡し、一定間隔で分裂体を生む（上限あり）。撃破時にも分かれる                   | 無双期以外                           | `scripts/managers/enemy_manager.gd`、`data/enemies/splitter.tres`。[demo](../../../demo/docs/enemies.md)   |
| `splitling`  | 分裂体     | 採用     | 実装済み       | 小型の追跡敵                                                                     | 分裂型から生まれる、無双期の通常出現 | `scripts/managers/enemy_manager.gd`、`data/enemies/splitling.tres`。[demo](../../../demo/docs/enemies.md)  |
| `gunner`     | 射撃型     | 採用     | 実装済み       | 距離を保って回り込み、予告のあと弾を撃つ                                         | 圧力期以降（無双期を除く）、危険地帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/gunner.tres`。[demo](../../../demo/docs/enemies.md)     |
| `missile`    | ミサイル艇 | 採用     | 実装済み       | さらに遠い距離を保ち、予告のあと誘導弾を撃つ                                     | 緊張期・脱出期、危険地帯             | `scripts/managers/enemy_manager.gd`、`data/enemies/missile.tres`。[demo](../../../demo/docs/enemies.md)    |
| `battleship` | 戦艦       | 採用     | 実装済み       | 予告のあと扇状に弾をばらまく。背面に当てると必ずクリティカル。エリートにならない | 緊張期・脱出期。同時に出る数に上限   | `scripts/managers/enemy_manager.gd`、`data/enemies/battleship.tres`。[demo](../../../demo/docs/enemies.md) |
| `titan`      | タイタン   | 採用     | 実装済み       | 大型の追跡敵。生成時に大きさが変わる                                             | 無双期以外。同時に出る数に上限       | `scripts/managers/enemy_manager.gd`、`data/enemies/titan.tres`。[demo](../../../demo/docs/enemies.md)      |

### 見た目の実装

- 各敵は `speed/assets/pixel/<type ID>.png` のピクセルスプライトを Nearest で描く（`RenderManager`・`InstanceBatch`）。素材の一覧は [素材README](../../../speed/assets/pixel/README.md)。
- `drifter`・`swarm`・`darter`・`armored`・`splitter`・`splitling` は手描きの PNG を、透明な余白込みの原寸で表示する。エリートも同じ大きさ。基礎半径は各 `.tres` で画像に合わせる。
- `gunner`・`missile`・`battleship`・`titan` は試遊用のスプライト。最終の見た目は未確定。
- 全敵とボスの表示と当たり判定に `config.character_scale` を掛ける。
- `armored` は背面の弱点を示す弧を表示しない。弱点の判定とエリートの輪はある。
- 静止スプライトで、個別のアニメーションはない。

## ボス

| type ID       | 名称           | 採用状態     | 本番の実装状況 | 行動・攻撃                                                                                        | 出現条件                        | コード・demo参照／未決事項                                                                                                                                         |
| ------------- | -------------- | ------------ | -------------- | ------------------------------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `provisional` | ボス戦艦（仮） | 採用（暫定） | 実装済み       | 機体を直接追う。予告のあと扇状に弾を撃つ。形態＝LimboHSM、判断＝Behavior Tree、攻撃＝タイムライン | 決まった時刻に1体。撃破でクリア | `scenes/bosses/provisional_boss.tscn`、`scripts/bosses/`、`data/bosses/provisional.tres`。demo の `boss`。見た目は `battleship.png` を共用。ギミック・弱点は未検討 |

中ボス4体は未実装。

## 障害物

| type ID  | 名称 | 採用状態 | 本番の実装状況 | 行動・攻撃                                                                                                       | 出現条件                                                                   | コード・demo参照／未決事項                                                                                                                          |
| -------- | ---- | -------- | -------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `meteor` | 隕石 | 採用     | 実装済み       | 追跡しない。地帯の岩は固定、漂流と彗星は世界秒で決まった軌道を進み、回転する。描画・なぞり中は敵と同じスロー倍率 | ラン開始時に世界の決まった位置へ配置し、画面の近くだけ有効（仕様書13.1章） | `scripts/managers/field_manager.gd`、`data/enemies/meteor.tres`。撃破で修理キット・回収ビーコン・部品を落とす。光る特別な隕石は本番に登録していない |

### 見た目の実装

- 2種類の画像（`meteor_spritesheet.png`・`meteor2_spritesheet.png`）から、配置の ID で決まった方を原寸で表示する。`config.character_scale` は掛けない。
- 残りの HP に応じて、横3コマを左から右へ切り替える。壊れると右端のコマを破片として飛ばし、回転させながら消す。
- 被弾しても白く光らせない。
- 月と惑星は `moon.png`・`planet.png` を障害物の半径に合わせて表示する。

## 廃止

| type ID | 名称   | 採用状態       | 実装状況                       | 理由・参照                                                                                                                                                                                                                                                  |
| ------- | ------ | -------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `leech` | 減速型 | 不採用（廃止） | 定義・出現・減速処理を削除済み | 近くを通るだけで減速する仕組みは、速度を軸にしたゲームでストレスになるため。旧実装はコミット `7281ad9` の `speed/data/enemies/leech.tres`・`enemy_manager.gd`・`combat_manager.gd`。ID は再利用しない。[demo](../../../demo/docs/enemies.md) には残っている |
