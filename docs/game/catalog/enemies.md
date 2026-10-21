# 本番の敵一覧

[一覧の運用ルール](rules.md) に従う。type ID は demo から引き継ぐ。星と HP の属性による HP、サイズ・エリートの補正、出現、動きの共通ルールは [仕様書](../spec.md) の4.2・11章。

数値の正は `.tres`。基礎値（半径・HP・装甲・速度・経験値・倒し方・行動の値）は `speed/data/enemies/<type ID>.tres`、ボスは `speed/data/bosses/`、出現の重みは `speed/data/phases/` が正で、Godot エディタの「データ編集」（メニューバーの「プロジェクト → ツール」）で見て調整する。

強敵の攻撃の重なりは、出現タイムラインの時間帯の予算と、ステージの種類ごとの個体value（`enemy_attack_values`）と、クリップの攻撃優先度（`attack_priority`）と任意の共有overrideで調整する。[攻撃の管理](../spec.md#117-敵の攻撃の形)を参照。

## 通常出現する敵

| type ID      | 名称       | 採用状態 | 本番の実装状況 | 行動・攻撃                                                                       | 出現条件                             | コード・demo参照／未決事項                                                                                 |
| ------------ | ---------- | -------- | -------------- | -------------------------------------------------------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `drifter`    | ドリフター | 採用     | 実装済み       | 機体へまっすぐ追跡                                                               | 全時間帯                             | `scripts/managers/enemy_manager.gd`、`data/enemies/drifter.tres`。[demo](../../../demo/docs/enemies.md)    |
| `swarm`      | スウォーム | 採用     | 実装済み       | 小型の追跡敵                                                                     | 強化期・強化期II・無双期・脱出期     | `scripts/managers/enemy_manager.gd`、`data/enemies/swarm.tres`。[demo](../../../demo/docs/enemies.md)      |
| `darter`     | ダーター   | 採用     | 実装済み       | 近づくと予告してから突進し、しばらく止まる                                       | 無双期以外                           | `scripts/managers/enemy_manager.gd`、`data/enemies/darter.tres`。[demo](../../../demo/docs/enemies.md)     |
| `armored`    | 装甲型     | 採用     | 実装済み       | 装甲の硬い追跡敵。背面に当てると必ずクリティカル                                 | 圧力期・緊張期・脱出期、危険地帯     | `scripts/managers/enemy_manager.gd`、`data/enemies/armored.tres`。[demo](../../../demo/docs/enemies.md)    |
| `splitter`   | 分裂型     | 採用     | 実装済み       | 追跡し、一定間隔で分裂体を生む（上限あり）。撃破時にも分かれる                   | 無双期以外                           | `scripts/managers/enemy_manager.gd`、`data/enemies/splitter.tres`。[demo](../../../demo/docs/enemies.md)   |
| `splitling`  | 分裂体     | 採用     | 実装済み       | 小型の追跡敵                                                                     | 分裂型から生まれる、無双期の通常出現 | `scripts/managers/enemy_manager.gd`、`data/enemies/splitling.tres`。[demo](../../../demo/docs/enemies.md)  |
| `gunner`     | 射撃型     | 採用     | 実装済み       | 距離を保って回り込み、予告のあと弾を撃つ                                         | 圧力期以降（無双期を除く）、危険地帯 | `scripts/managers/enemy_manager.gd`、`data/enemies/gunner.tres`。[demo](../../../demo/docs/enemies.md)     |
| `missile`    | ミサイル艇 | 採用     | 実装済み       | さらに遠い距離を保ち、予告のあと誘導弾を撃つ                                     | 緊張期・脱出期、危険地帯             | `scripts/managers/enemy_manager.gd`、`data/enemies/missile.tres`。[demo](../../../demo/docs/enemies.md)    |
| `titan`      | タイタン   | 採用     | 実装済み       | 大型の追跡敵。生成時に大きさが変わる                                             | 無双期以外。同時に出る数に上限       | `scripts/managers/enemy_manager.gd`、`data/enemies/titan.tres`。[demo](../../../demo/docs/enemies.md)      |
| `battleship` | 戦艦 | 採用 | 実装済み | 追跡し、予告のあと扇状に弾を撃つ。背面が弱点 | 緊張期・脱出期 | `data/enemies/battleship.tres`、`enemy_manager.gd` |

## 調整用に保持する敵

追加版の敵は専用の[敵・ルート実験場](../spec.md#201-敵ルート実験場)から呼び出し、単体と混成を調整してから通常出現へ採用する。共有 ID の種類は上の通常構成でも使い、追加版の設定を実験用に保持する。ステージ1〜5の通常出現は共通の元の時間帯を使う。

区分と星の数の決まりは [仕様書](../spec.md) の11.1。星2〜5の敵は、目印の星を持つことがある（仕様書 13.1）。エリートの扱いは仕様書 11.2。強敵と大物は、種類ごとに同時に出る数の上限を持つ（仕様書 11.3）。通常ステージは共通の6時間帯を使う。追加版の `speed/data/phases/s<ステージ>_*.tres` は調整用に保持する。

| type ID | 名称 | 星 | 採用状態 | 本番の実装状況 | 行動・攻撃 | 倒し方 | 特徴・備考 | 調整対象のステージ（通常出現は保留） | コード・データ参照 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `rocket` | ミサイル | 1 | 採用 | 実装済み | 出た向きのまま一直線に飛ぶ。機体に近づくと爆発する。飛ぶ時間が過ぎると消える | — | — | 1〜5 | `data/enemies/rocket.tres`、`enemy_manager.gd` の `_rocket` |
| `bomber` | 自爆する雑魚 | 1 | 採用 | 実装済み | 追ってきて、近づくと2回明滅して爆発する | 明滅し終わる前に貫けば、爆発させずに倒せる | — | 1・2・3・5 | `data/enemies/bomber.tres`、`_bomber`。外観は [デザインとアートスタイル](../art-style.md#42-敵) |
| `volatile` | 誘爆する雑魚 | 1 | 採用 | 実装済み | 追ってくる。倒すと少し遅れて爆発し、周りの敵も機体も巻き込む。誘爆は連鎖する | — | — | 2〜5 | `data/enemies/volatile.tres`、`on_enemy_death` |
| `splitter` | 分裂する雑魚 | 1 | 採用 | 実装済み | 通常出現では追跡中にも分裂体を生み、撃破時に2体へ分かれる。追加版の生存中は分裂せず撃破時に2〜3体へ分かれる設定も保持する | 分かれた体もすべて倒す | — | 元の通常出現。追加版は `data/lab/enemy_variants.json` に保持 | `data/enemies/splitter.tres`・`splitling.tres` |
| `splitling` | 分裂体 | 1 | 採用 | 実装済み | 分裂する雑魚から生まれ、機体を追う | — | — | 2・4・5の分裂時 | `data/enemies/splitling.tres`（行動は `chase`） |
| `beamer` | ビームの敵 | 2 | 採用 | 実装済み | 距離を保ち、止まって砲口に光を集めてからビームを撃つ | — | — | 1・2・3・5 | `data/enemies/beamer.tres`、`_beamer` |
| `pulser` | 波動の敵 | 2 | 採用 | 実装済み | 距離を保ち、止まって1枚だけの輪を出す。切れ目はなく、届く距離は短い | — | — | 1・4・5 | `data/enemies/pulser.tres`、`_pulser` |
| `missile` | ホーミングミサイルの敵 | 2 | 採用 | 実装済み | 遠い距離を保ち、予告のあとホーミングミサイルを撃つ | — | — | 2・4・5 | `data/enemies/missile.tres` |
| `spreader` | 拡散弾の敵 | 2 | 採用 | 実装済み | 追ってきて、予告のあと扇状に弾をばらまく | — | — | 3・4・5 | `data/enemies/spreader.tres`（行動は `battleship`） |
| `pump` | ポンプ座 | 3 | 採用 | 実装済み | 周りの敵と遅い自機を吸い寄せてから、前方へ一気に吐き出す | 吸っている間だけ口が開き、倒せる | — | 1・2 | `data/enemies/pump.tres`、`enemy_manager.gd` の `_pump` |
| `telescope` | ぼうえんきょう座 | 3 | 採用 | 実装済み | レンズが光って予告してから、細く速い弾を撃つ | — | HP は柔らかめ（星3の標準より体当たり1回少ない） | 1 | `data/enemies/telescope.tres`、`enemy_manager.gd` の行動 `sniper`。外観は [デザインとアートスタイル](../art-style.md#42-敵) |
| `triangle` | みなみのさんかく座 | 3 | 採用 | 実装済み | 3つの星の間に光の膜を張る。膜に触れると被弾する | 頂点の星を1つ貫くと膜が消え、中の核を狙える | — | 3・4 | `data/enemies/triangle.tres`・`triangle_star.tres`、`enemy_manager.gd` の `_triangle`。外観は[敵の描画](../art-style.md#42-敵) |
| `shield` | たて座 | 4 | 採用 | 実装済み | 機体を追ってゆっくり向き直る。前面の青白い盾が弾を反射する。反射弾の発生間隔に上限がある | 前面の盾は通常移動の接触も隕石と同じように押し戻し、高速の体当たりも弾く。側面・背面の本体へ通常攻撃が通る。装甲を突破する高速体当たりで背面を貫くと一撃で倒れ、盾を奪う。奪った盾は一定時間、全方向の敵の攻撃を防いで勢いを保つ。背面から貫くルートの先では弾幕へ踏み込める | — | 1・5 | `data/enemies/shield.tres`（盾の持続時間・反射弾の値）、`enemy_manager.gd`・`combat_manager.gd`・`ship_manager.gd`。実験場で各値を調整できる |
| `ruler` | じょうぎ座 | 4 | 採用 | 実装済み | 長い直線の光の壁を置く | — | — | 1・3 | `data/enemies/ruler.tres`、`enemy_manager.gd` の `_ruler` |
| `crow` | からす座 | 4 | 採用 | 実装済み | 周りで倒された敵の残骸を集めて塊にし、1個投げてくる。本体を倒すと塊が砕けて破片が飛ぶ | — | — | 2・4 | `data/enemies/crow.tres`、`enemy_manager.gd` の `_crow` |
| `lynx` | やまねこ座 | 4 | 採用 | 実装済み | 前方の短い距離を扇形に爪で薙ぐ。殻が割れている間は、爪を振るう間隔が短くなる | 殻に耐久がある。体当たりなら1回、弾や武器なら集中して当て続けると割れる。割れている数秒のうちにもう1回当てると倒れる。攻撃が当たらない時間が続くと殻の傷は戻る | — | 2・3 | `data/enemies/lynx.tres`、`enemy_manager.gd` の `_lynx` |
| `reticle` | レチクル座 | 4 | 採用 | 実装済み。大きい経験値カプセルの報酬は採用・未実装（量は未決） | ぼうえんきょう座に付き従い、視線を遮る小隕石を予告後のビームで壊す。支援先がいなくなると退却する | — | — | 2・3 | `data/enemies/reticle.tres`、`enemy_manager.gd` の `_reticle`。外観は [デザインとアートスタイル](../art-style.md#42-敵)。設定は[星の力](../world.md#5-星の力と機体の強化) |
| `cross` | みなみじゅうじ座 | 4 | 採用 | 実装済み | 構えて光を集め、十字にレーザーを撃つ | — | — | 3・5 | `data/enemies/cross.tres`、`enemy_manager.gd` の `_beamer` |
| `clock` | とけい座 | 5 | 採用 | 実装済み | 長針と短針が刃として回り続ける。2本の速さが違う | — | — | 1 | `data/enemies/clock.tres`、`enemy_manager.gd` の `_clock` |
| `dolphin` | いるか座 | 5 | 採用 | 実装済み | 何層もの輪を出し、層ごとに切れ目がずれている。届く距離が長い | — | HP は硬め（星5の標準より体当たり1回多い） | 2・4 | `data/enemies/dolphin.tres`、`enemy_manager.gd` の `_pulser`。外観は[敵の描画](../art-style.md#42-敵) |
| `crab` | かに座 | 5 | 採用 | 実装済み | ハサミを開いてから前方を挟む | 挟んだ直後は正面からでも割れる | — | 4 | `data/enemies/crab.tres`、`enemy_manager.gd` の `_crab`。外観は[敵の描画](../art-style.md#42-敵) |
| `marlin` | かじき座 | 5 | 採用 | 実装済み | 高速で泳ぎ抜けながら、横へ扇状にしぶきを撒く | — | — | 4 | `data/enemies/marlin.tres`、`enemy_manager.gd` の `_marlin` |
| `auriga` | ぎょしゃ座 | 5 | 採用 | 実装済み | 車輪の跡が燃えて残る | — | — | 5 | `data/enemies/auriga.tres`、`enemy_manager.gd` の `_auriga` |
| `corona` | みなみのかんむり座 | 6 | 採用 | 実装済み・数値は試遊用の仮値。HPは[星ごとの暫定設定](../spec.md#111-見た目と強さ) | 冠が近くの雑魚を小さな渦で率いて接近し、予告後にその個体を進行方向へ投げる（[仕様書 11.8](../spec.md#118-みなみのかんむり座)） | 渦の群れを突き抜けてまとめて倒すと次の投擲の弾薬が減る。通常の戦闘判定を使う | — | 4・5 | `data/enemies/corona.tres`、`data/formations/corona_solo.tscn`、`scripts/enemies/corona_vortex.gd`。外観は[仮の冠](../art-style.md#46-みなみのかんむり座) |
| `phoenix` | ほうおう座 | 7 | 採用 | 実装済み。HPは[星ごとの暫定設定](../spec.md#111-見た目と強さ) | 飛んだ跡に炎を残す。倒すと周りを焼き払い、近いと自分も焼かれる | — | — | 3 | `data/enemies/phoenix.tres`、`enemy_manager.gd` の `_phoenix` |
| `cepheus` | ケフェウス座 | 7 | 採用 | 実装済み。HPは[星ごとの暫定設定](../spec.md#111-見た目と強さ) | 号令で、周りの強敵が一斉に攻撃する | — | — | 5 | `data/enemies/cepheus.tres`、`enemy_manager.gd` の `_cepheus` |
| `aquarius` | みずがめ座 | 10 | 採用 | 実装済み。HPは[星ごとの暫定設定](../spec.md#111-見た目と強さ) | 太い水流を流し続け、敵と遅い自機を押し流す | — | — | 4 | `data/enemies/aquarius.tres`、`enemy_manager.gd` の `_aquarius`。外観は[敵の描画](../art-style.md#42-敵) |
| `aquila` | わし座 | 10 | 採用 | 実装済み。HPは[星ごとの暫定設定](../spec.md#111-見た目と強さ) | 通り道に沿って雷を落とす | — | — | 5 | `data/enemies/aquila.tres`、`enemy_manager.gd` の `_aquila`。雷撃の見た目は [デザインとアートスタイル](../art-style.md#37-雷撃) |

### 見た目の実装

- 各敵は `speed/assets/pixel/<type ID>.png` のピクセルスプライトを Nearest で描く（`RenderManager`・`InstanceBatch`）。素材の一覧は [素材README](../../../speed/assets/pixel/README.md)。
- `splitter`・`splitling` の本体は手描きの PNG を、透明な余白込みの原寸で表示する。エリートも同じ大きさ。基礎半径は各 `.tres` で画像に合わせる。
- `missile` は試遊用のスプライト。最終の見た目は未確定。
- `corona` は [仮の冠](../art-style.md#46-みなみのかんむり座) を使う。
- それ以外で絵（`speed/assets/pixel/<type ID>.png`）がまだない種類は、敵の定義の形（`shape`：丸・菱形・六角形・矢じり・四角）の図形を、敵の色で描く。png を置くと絵に替わる。
- 全敵とボスの表示と当たり判定に `config.character_scale` を掛ける。
- 静止スプライトで、個別のアニメーションはない。

## ボス

| type ID       | 名称           | 採用状態     | 本番の実装状況 | 行動・攻撃                                                                                        | 出現条件                        | コード・demo参照／未決事項                                                                                                                                         |
| ------------- | -------------- | ------------ | -------------- | ------------------------------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `provisional` | ボス戦艦（仮） | 採用（暫定） | 実装済み       | 機体を直接追う。予告のあと扇状に弾を撃つ。形態＝LimboHSM、判断＝Behavior Tree、攻撃＝タイムライン | 決まった時刻に1体。撃破でクリア | `scenes/bosses/provisional_boss.tscn`、`scripts/bosses/`、`data/bosses/provisional.tres`。demo の `boss`。見た目は `battleship.png` を共用。ギミック・弱点は未検討 |
| `hydra` | うみへび座 | 採用 | 実装済み。南の渦壁は条件付き採用・未実装 | 首全滅で不死の首を露出し、体当たりで貫くと3・5・7・9本の順に進み、最後の段階で撃破する。次の頭の撃破で倒れた全首の再生猶予を延ばし、火で再生を抑える。胴体表面に根元を固定し、北は自機周辺を予告・狙い固定して複数首で集中攻撃する。BT で距離・方向・生存首・重み・技別クールダウンを調整し、羅針盤で北・東・西の大技を予告する。技の後に攻めどきを設ける（[仕様書 12.3](../spec.md#123-中ボス)） | 通常出現を保留し、調整用に保持する | `scenes/bosses/hydra_boss.tscn`、`scenes/bosses/hydra_boss_bt.tres`、`scripts/bosses/hydra_boss.gd`、`scripts/bosses/hydra_neck.gd`、`data/bosses/hydra.tres`。追尾首は弱点として保持し専用攻撃を休止する。`scenes/bosses/hydra_presentation.tscn` に差し替え用の仮演出を接続。`gyms/hydra_trial.tscn` で試遊する。南の回避難度と最終外観は未決。BT と演出の編集方法は[設計書 6.1](../architecture.md#61-敵とボスの-ai) |
| 仮ID `monoceros` | いっかくじゅう座 | 採用 | 未実装 | 地形に角が刺さる突進（仕様書12.3） | ステージ1 | 本番の実装は `provisional`。角の仕掛けと数値の調整が必要 |

通常ステージ1〜5は `provisional` を使う。各星系の主の組み込みは調整後に行う。

## 障害物

| type ID  | 名称 | 採用状態 | 本番の実装状況 | 行動・攻撃                                                                                                       | 出現条件                                                                   | コード・demo参照／未決事項                                                                                                                          |
| -------- | ---- | -------- | -------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `meteor` | 隕石 | 採用     | 実装済み       | 追跡しない。固い障害物で、普段の速さでは上を通り抜けられない（仕様書7.2）。地帯の岩は固定、漂流は世界秒で決まった軌道を進み、回転する。彗星はラン中に画面の端の近くをまっすぐ横切る。描画・なぞり中は敵と同じスロー倍率 | 地帯と漂流はラン開始時に世界の決まった位置へ配置し、画面の近くだけ有効。彗星はときどき現れる（仕様書13.1章） | `scripts/managers/field_manager.gd`、`data/enemies/meteor.tres`。撃破で修理キット・回収ビーコン・部品を落とす。レアな彗星は彗星限定の武器のカプセルを必ず落とす |
| `iron` | 鉄のがれき | 採用 | 実装済み | 動かない。装甲がとても高い固い障害物で、十分な攻撃力なら割れる。ぶつかると火花が出る | ラン開始時に塊で配置し、画面の近くだけ有効（置き方は仮。仕様書13.1章） | `scripts/managers/field_manager.gd`、`data/enemies/iron.tres`。見た目は仮の図形 |
| `saw` | 回る丸鋸 | 採用 | 実装済み | その場で回る。触れると機体の進んでいた向きへ飛んでいき、その先の敵を巻き込む。1回で壊れる。攻撃では壊れない | ラン開始時に散らして配置し、画面の近くだけ有効（置き方は仮。仕様書13.1章） | `scripts/managers/field_manager.gd`、`combat_manager.gd` の `_launch_saw`、`data/enemies/saw.tres`。見た目は仮の図形 |

### 見た目の実装

- 2種類の画像（`meteor_spritesheet.png`・`meteor2_spritesheet.png`）から、配置の ID で決まった方を原寸で表示する。`config.character_scale` は掛けない。
- 残りの HP に応じて、横3コマを左から右へ切り替える。壊れると右端のコマを破片として飛ばし、回転させながら消す。
- 被弾しても白く光らせない。
- 月と惑星は `moon.png`・`planet.png` を障害物の半径に合わせて表示する。

## 出現状態の参照

`drifter`・`swarm`・`darter`・`armored`・`gunner`・`battleship`・`titan` は上の通常出現表を参照する。

## 廃止

| type ID | 名称   | 採用状態       | 実装状況                       | 理由・参照                                                                                                                                                                                                                                                  |
| ------- | ------ | -------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `leech` | 減速型 | 不採用（廃止） | 定義・出現・減速処理を削除済み | 近くを通るだけで減速する仕組みは、速度を軸にしたゲームでストレスになるため。旧実装はコミット `7281ad9` の `speed/data/enemies/leech.tres`・`enemy_manager.gd`・`combat_manager.gd`。ID は再利用しない。[demo](../../../demo/docs/enemies.md) には残っている |
