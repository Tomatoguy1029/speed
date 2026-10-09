# 本番の武器一覧

[一覧の運用ルール](rules.md) に従う。管理 ID は demo から引き継ぐ。共通のルール（枠・Lv・係数・段階の色）は [仕様書](../spec.md) の8章。demo の保留・候補（W09〜W16、W18）は本番に登録していない。

数値の正は文書ではなく `.tres`。各武器の数値は `speed/data/weapons/<ID>_<内部ID>.tres` が正で、Godot エディタの「データ編集」（メニューバーの「プロジェクト → ツール」）で見て調整する。

## 採用

| ID | 名称 | 採用状態 | 発動・効果 | ルートへの影響 | 本番の実装状況・コード参照 | demo参照・未決事項 |
|---|---|---|---|---|---|---|
| W01 | ブラスター | 採用 | 進む向きへ自動で撃つ。Lv で威力・連射・弾数・貫通が伸びる。描画中・なぞり中は休む | 通常の移動の向きが撃つ向きになる | 実装済み。`scripts/weapons/forward.gd`、`data/weapons/W01_forward.tres` | [demo W01](../../../demo/docs/weapons.md) `forward` |
| W02 | 散弾砲 | 採用 | 進む向きへ扇状に撃つ | 群れに向けて進み、近い距離で広がりを当てる | 実装済み。`scripts/weapons/scatter.gd`、`data/weapons/W02_scatter.tres` | [demo W02](../../../demo/docs/weapons.md) `scatter` |
| W03 | 吹き飛ばし衝角 | 採用 | 高速で触れた生きた敵を進む向きへ吹き飛ばし、ほかの敵にぶつけてダメージ。倒した大型の敵は破片を扇状に、小型の敵は死体を1つ飛ばす | ほかの敵に船体をぶつけられる向きから入る | 実装済み。`scripts/weapons/knockback.gd`、`data/weapons/W03_knockback.tres` | [demo W03](../../../demo/docs/weapons.md) `knockback` |
| W04 | 接触波動 | 採用 | 高速で触れるたびに、触れた位置から周りへ波動。弾かれた接触でも出る。波動の撃破からは連鎖しない | 密集した群れを通る | 実装済み。`scripts/weapons/contactWave.gd`、`data/weapons/W04_contactWave.tres` | [demo W04](../../../demo/docs/weapons.md) `contactWave` |
| W05 | バリアシステム | 採用 | 周りに定期的な波動を出し、一定間隔で敵の弾を1発防ぐ | 敵や弾に近づくときの状況を変える | 実装済み。`scripts/weapons/barrier.gd`、`data/weapons/W05_barrier.tres` | [demo W05](../../../demo/docs/weapons.md) `barrier` |
| W06 | 追走ドローン | 採用 | 周りを回って近くの敵を撃つ。駆け抜けた線を1機ごとに遅れて追い、触れた敵も攻撃する。Lv で機数が増える | 自機が抜けたあとにも同じ線を掃く | 実装済み。`scripts/weapons/drone.gd`、`data/weapons/W06_drone.tres`。見た目は下の「機体とドローンの見た目」 | [demo W06](../../../demo/docs/weapons.md) `drone` |
| W07 | 軌跡機雷 | 採用 | 高速で実際に通った線に一定の間隔で機雷を残す。少し遅れて有効になり、敵が近づくと爆発する | 敵が後から入る線を残す | 実装済み。`scripts/weapons/mines.gd`、`data/weapons/W07_mines.tres` | [demo W07](../../../demo/docs/weapons.md) `mines` |
| W08 | ソニックブーム | 採用 | 駆け抜け始めと、普段の移動中は一定間隔で、進路ごと大きな衝撃波。同じ波動では各敵に1回 | 撃った地点だけでなく進路も一掃する。T05 とは別 | 実装済み。`scripts/weapons/sonic.gd`、`data/weapons/W08_sonic.tres` | [demo W08](../../../demo/docs/weapons.md) `sonic` |
| W17 | 接触電撃 | 採用 | 普段・高速を問わず敵に触れると、その敵から近くの敵へ電撃がつながる。つながる数は Lv で増える。同じ敵には1回の連鎖で1度だけ。隕石には流れない | 群れのつながった配置を線でまたぎ、触れた所から離れた敵まで処理する | 実装済み。`scripts/weapons/contactArc.gd`、`data/weapons/W17_contactArc.tres` | [demo W17](../../../demo/docs/weapons.md) `contactArc` |
| W23 | 後方ブラスター | 採用 | 自機の背後から進行方向の反対へ自動射撃。Lv2・5で弾数、Lv3で連射速度、Lv4で威力だけが上がる。描画中・なぞり中は休む | 敵から逃げる向きへ進みながら後ろの追跡敵を攻撃する | 実装済み。`scripts/weapons/rear.gd`、`data/weapons/W23_rear.tres`。通常の取得・強化候補 | 本番独自。demo未実装。具体的な数値は仮調整 |

味方の弾と攻撃する破片は惑星と月で止まる。波動・範囲攻撃・ビームは止まらない。


### 機体とドローンの見た目

武器を持つと、機体にその武器のパーツが付く。武器の性能と当たり判定は変わらない。

| 武器 | パーツ |
|---|---|
| W01 ブラスター・W02 散弾砲 | 砲身（`airship_canon.png`）。機体より後ろに描く |
| W03 吹き飛ばし衝角・W05 バリアシステム | 装甲（`airship_armor.png`） |
| W07 軌跡機雷 | 機雷装置（`airship_mine.png`） |
| W17 接触電撃 | 電子プローブ（`airship_electronic_probe.png`） |
| W08 ソニックブーム | 噴射の炎を青い3コマ（`airship_blue_flame.png`）に替え、後方の残光も青にする |
| W23 後方ブラスター | タレット（下記） |

- 同じパーツを使う武器を両方持っても、パーツは1つだけ出す。W23 のタレットは、ほかのパーツの上に重ねる。
- W06 のドローンは `drone.png` を原寸に `config.character_scale` を掛けて表示し、自機からドローンへの向きに向ける。射撃は近くの敵を狙い、見た目の向きには縛られない。経路の上での接触判定にも `config.character_scale` を掛ける。

### W23のLv別強化

取得時だけ自機へ提供PNGのタレットベースと砲塔を装着する。機体→ベース→砲塔の順で重ね、砲塔は取り付け軸を中心に射撃方向へ向く。弾は砲口から発射する。素材は `assets/pixel/airship_turret_base.png` と `airship_turret.png`。

共通の段階別係数は適用せず、`.tres` のLv別配列を使う。前段階の強化は保持する。

| Lv | 強化内容 |
|---|---|
| 1 | 後方へ自動射撃 |
| 2 | 同時発射数が増加 |
| 3 | 発射間隔が短縮 |
| 4 | 1発の威力が上昇 |
| 5 | 同時発射数がさらに増加 |

## 保留・不採用

なし。
