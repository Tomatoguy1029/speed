# 本番の敵一覧

最終更新：2026-10-08。対象はGodot本番。[共通の運用ルール](catalog.md) に従い、追加・変更・採否判断・実装の同じ作業で更新する。

2026-10-07、demo描画版の敵（通常敵11種・暫定ボス・隕石）を本番の仕様として引き継ぐと決めた（[wakida.md](wakida.md) の100）。type IDはdemoから引き継ぐ。レベル・サイズ・エリートの補正、出現、動きの共通ルールは [仕様書](spec.md) の9〜11章。

**数値はドキュメントで管理しない**（[catalog.md](catalog.md)）。基礎値（半径・HP・装甲・速度・接触ダメージ・経験値・行動の値）は `speed/data/enemies/<type ID>.tres`、ボスは `speed/data/bosses/`、出現の重みは `speed/data/phases/` が正で、Godot エディタの「データ」画面で見て調整する。

## 通常敵

| type ID | 名称 | 採用状態 | 本番の実装状況 | 行動・攻撃 | 出現条件 | コード・demo参照／未決事項 |
|---|---|---|---|---|---|---|
| `drifter` | ドリフター | 採用 | 実装済み | 追跡と広域移動 | 全時間帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/drifter.tres`。[demo](../demo/docs/enemies.md) |
| `swarm` | スウォーム | 採用 | 実装済み | 小型の追跡敵 | 強化期・強化期II・無双期・脱出期 | `scripts/managers/enemy_manager.gd`、`data/enemies/swarm.tres`。[demo](../demo/docs/enemies.md) |
| `darter` | ダーター | 採用 | 実装済み | 近づくと予告してから突進し、しばらく止まる | 無双期以外 | `scripts/managers/enemy_manager.gd`、`data/enemies/darter.tres`。[demo](../demo/docs/enemies.md) |
| `armored` | 装甲型 | 採用 | 実装済み | 装甲の硬い追跡敵。背面に当てると必ずクリティカル | 圧力期・緊張期・脱出期、危険地帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/armored.tres`。[demo](../demo/docs/enemies.md) |
| `splitter` | 分裂型 | 採用 | 実装済み | 追跡し、一定間隔で分裂体を生む（上限あり）。撃破時にも2体に分かれる | 無双期以外 | `scripts/managers/enemy_manager.gd`、`data/enemies/splitter.tres`。[demo](../demo/docs/enemies.md) |
| `splitling` | 分裂体 | 採用 | 実装済み | 小型の追跡敵 | 分裂型から生まれる、無双期の通常出現 | `scripts/managers/enemy_manager.gd`、`data/enemies/splitling.tres`。[demo](../demo/docs/enemies.md) |
| `leech` | 減速型 | 採用 | 実装済み | 周りのオーラの中で機体を減速させる。貫くと勢いを吸う | 圧力期・緊張期・脱出期 | `scripts/managers/enemy_manager.gd`、`data/enemies/leech.tres`。[demo](../demo/docs/enemies.md) |
| `gunner` | 射撃型 | 採用 | 実装済み | 距離を保って回り込み、予告のあと弾を撃つ | 圧力期以降（無双期を除く）、危険地帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/gunner.tres`。[demo](../demo/docs/enemies.md) |
| `missile` | ミサイル艇 | 採用 | 実装済み | さらに遠い距離を保ち、予告のあと誘導弾を撃つ | 緊張期・脱出期、危険地帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/missile.tres`。[demo](../demo/docs/enemies.md) |
| `battleship` | 戦艦 | 採用 | 実装済み | 予告のあと扇状に弾をばらまく。背面に当てると必ずクリティカル。エリートにならない | 緊張期・脱出期。同時に出る数に上限 | `scripts/managers/enemy_manager.gd`、`data/enemies/battleship.tres`。[demo](../demo/docs/enemies.md) |
| `titan` | タイタン | 採用 | 実装済み | 大型の追跡敵。生成時に大きさが変わる | 無双期以外。同時に出る数に上限 | `scripts/managers/enemy_manager.gd`、`data/enemies/titan.tres`。[demo](../demo/docs/enemies.md) |

## ボス

| type ID | 名称 | 採用状態 | 本番の実装状況 | 行動・攻撃 | 出現条件 | コード・demo参照／未決事項 |
|---|---|---|---|---|---|---|
| `provisional` | ボス戦艦（仮） | 採用（暫定） | 実装済み | 機体を直接追う。予告のあと扇状に弾を撃つ。形態＝LimboHSM、判断＝Behavior Tree、攻撃＝タイムライン | 決まった時刻に1体。撃破でクリア | `scenes/bosses/provisional_boss.tscn`、`scripts/bosses/`、`data/bosses/provisional.tres`。demo の `boss`。ギミック・弱点は未検討 |

## 障害物

| type ID | 名称 | 採用状態 | 本番の実装状況 | 行動・攻撃 | 出現条件 | コード・demo参照／未決事項 |
|---|---|---|---|---|---|---|
| `meteor` | 隕石 | 採用 | 実装済み | 追跡しない。地帯の岩は固定、漂流と彗星は決まった軌道で動く | ラン開始時に世界の決まった位置へ配置し、画面の近くだけ有効（仕様書11章） | `scripts/managers/field_manager.gd`、`data/enemies/meteor.tres`。撃破で修理キット・回収ビーコン・部品を落とす。光る特別な隕石（`meteor_special`）は本番に登録していない |
