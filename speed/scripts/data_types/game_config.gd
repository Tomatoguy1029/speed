## 調整値
## ゲーム全体で共通の数値。ランの長さ、機体の動き、ゲージ、戦闘、敵の出方、ドロップ、成長、カメラ、演出などを決める。
## 変えた値は次のランから反映される。
## ---
## 値の正は res://data/config.tres（設計書 8.3）。
## ここに書く既定値はすべて 0 にしておく。Godot は既定値と同じ値を .tres に保存しないため、
## 既定値を実際の値にすると、.tres から数値が消えて「.tres が正」が崩れる。
## 各項目の直前の「##」は、データ編集の画面に出る説明（1行目＝名前、「単位：」の行＝単位、残り＝説明）。
class_name GameConfig
extends Resource

## ランの時間・ボス・クリア報酬
@export_group("ラン")
## ランの制限時間
## これを過ぎるとランは失敗になる。時計は描画中も進み、ポーズ・3択・ヒットストップの間は止まる。
## 単位：実秒
@export var run_time: float
## ボスが出る時刻
## ラン開始からこの時間が経つと、ボスが1体現れる。
## 単位：実秒
@export var boss_time: float
## ボスの HP
## ボスの最大 HP。敵の HP 倍率も掛かる。
## 単位：HP
@export var boss_hp: float
## ボスの装甲
## これより低い攻撃力の体当たりは弾かれる。敵の装甲倍率も掛かる。
## 単位：攻撃力
@export var boss_armor: float
## クリア報酬の部品
## ボスを倒してクリアしたとき、獲得した部品に足す数。
## 単位：個
@export var clear_bonus: int
## 速度表示の換算
## 画面の速度メーターで km/s を出すときに、ゲーム内の速さに掛ける値。見た目だけで、ゲームの動きは変わらない。
## 単位：倍
@export var speed_to_kms: float

## ボス撃破・敗北・被弾などの見せ方。攻撃力や当たり判定には影響しない
@export_group("演出")
## 撃破の再生：記録する長さ
## ボスにトドメを刺す直前の機体の動きを、この長さだけ記録してスローで見せる。
## 単位：実秒
@export var boss_finish_replay_window: float
## 撃破の再生：スローの長さ
## 記録した動きを、この時間をかけてゆっくり再生する。
## 単位：実秒
@export var boss_finish_slow_time: float
## 撃破の再生：寄りの倍率
## スロー再生中、カメラを機体にこの倍率で寄せる。
## 単位：倍
@export var boss_finish_zoom: float
## 撃破：爆発から CLEAR! までの時間
## ボスが爆発して残りの敵が消えたあと、CLEAR! を出すまでの時間。
## 単位：実秒
@export var boss_finish_blast_time: float
## 撃破：CLEAR! の表示時間
## CLEAR! を出してから結果画面に移るまでの時間。
## 単位：実秒
@export var boss_finish_clear_time: float
## 敗北：止まる時間
## 最後の被弾の瞬間に、世界を止めておく時間。
## 単位：実秒
@export var death_freeze_time: float
## 敗北：背景の暗さ
## 敗北の演出中、機体以外を暗くする強さ。0 で暗くしない、1 で真っ黒。
## 単位：割合（0〜1）
@export var death_world_dim: float
## 敗北：爆発の時間
## 機体が爆発して破片が飛ぶ演出の長さ。
## 単位：実秒
@export var death_explosion_time: float
## 敗北：GAME OVER の表示時間
## GAME OVER を出してから結果画面に移るまでの時間。
## 単位：実秒
@export var death_game_over_time: float
## 被弾：赤くなる時間
## 普段の被弾で、機体を赤く光らせる長さ。
## 単位：実秒
@export var ship_hurt_time: float
## 被弾：震えの大きさ
## 普段の被弾で、機体を横に震わせる最大の幅。カメラは揺らさない。
## 単位：px（画面上）
@export var ship_hurt_shake: float
## 弾かれ：火花の数
## 装甲に弾かれたとき、接触面の左右に飛ばす火花の本数。
## 単位：本
@export var block_spark_count: int
## 弾かれ：装甲が光る時間
## 弾いた敵の、接触した側の装甲を光らせる長さ。
## 単位：秒
@export var block_impact_life: float
## クリティカル：炎の数
## クリティカルで貫いたとき、接触位置から出す炎の数。
## 単位：個
@export var weak_flame_count: int
## クリティカル：赤熱の時間
## クリティカルで貫いた敵を赤く光らせる長さ。
## 単位：秒
@export var weak_impact_life: float
## 吹き飛んだ破片：光の跡の時間
## 吹き飛ばした敵の破片が通った跡の光が消えるまでの時間。
## 単位：実秒
@export var corpse_trail_life: float
## 吹き飛んだ破片：光の跡の点数
## 破片1つにつき、光の跡として残す位置の数。多いほど長い跡になる。
## 単位：点
@export var corpse_trail_points: int

## 遊ぶ場所の広さ、惑星・月・宇宙塵、地形にぶつかったとき
@export_group("フィールド")
## フィールドの半径
## 遊べる範囲（円）の半径。外へ出ようとすると押し戻される。
## 単位：単位（距離）
@export var field_radius: float
## 惑星の半径
## 中心の惑星の大きさ。惑星は障害物で、通り抜けられない。
## 単位：単位（距離）
@export var planet_radius: float
## 安全な区域の内側
## 中心からこの距離までは、惑星に近いほど危険度が上がる（強い敵・ドロップが増える）。
## 単位：単位（距離）
@export var zone_inner: float
## 安全な区域の外側
## 中心からこの距離より外は、外縁に近いほど危険度が上がる。内側との間は危険度0。
## 単位：単位（距離）
@export var zone_outer: float
## 開始位置
## ラン開始時に機体を置く、中心からの距離。
## 単位：単位（距離）
@export var start_radius: float
## 月の数
## 惑星の周りを回る月の数。月も障害物。
## 単位：個
@export var moon_count: int
## 月の回る速さ
## 月が惑星の周りを回る角度の速さ。
## 単位：ラジアン/世界秒
@export var moon_orbit_speed: float
## 宇宙塵の雲の数
## フィールドに置く宇宙塵の雲の数。中では機体が減速する。
## 単位：個
@export var dust_count: int
## 宇宙塵の抵抗
## 宇宙塵の中で機体にかかる減速の強さ。大きいほど早く遅くなる（なぞり後の勢いの間は無効）。
## 単位：毎秒の減衰率
@export var dust_drag: float
## 外縁の押し戻し
## フィールドの外へ出たとき、中へ押し戻す力の基本の強さ。外へ出るほど強くなる。
## 単位：単位/秒²
@export var boundary_push: float
## 地形の跳ね返り
## 惑星・月にぶつかったときの跳ね返りの強さ。0 で跳ね返らず止まる、1 で同じ速さで跳ね返る。
## 単位：割合（0〜1）
@export var crash_restitution: float
## 地形の衝突ダメージ
## 惑星・月にぶつかったとき、ぶつかる速さが 200 を超えた分に掛けてダメージにする。
## 単位：HP/速さ
@export var crash_damage: float

## 機体の基本の能力、マウス・タッチでの動かし方、速さの落ち方
@export_group("機体")
## 自機・通常敵・ボス・ドローンの素材基準に対する表示倍率。敵の判定にも適用。
@export var character_scale: float = 1.0
## 基本の最高速度
## レベル・特性・強化で伸びる前の最高速度。描ける線の長さとカメラの引きにも効く。
## 単位：単位/秒
@export var base_max_speed: float
## 基本の最大 HP
## レベル・強化で増える前の最大 HP。
## 単位：HP
@export var base_hp: float
## 機体の当たり判定の半径
## 機体の当たり判定の大きさ。見た目の大きさとは別。
## 単位：単位（距離）
@export var ship_radius: float
## 被弾後の無敵時間
## ダメージを受けたあと、次のダメージを受けない時間。
## 単位：世界秒
@export var invuln_time: float
## 基本の回収範囲
## ドロップを吸い寄せ始める距離。特性・強化で広がる。
## 単位：単位（距離）
@export var pickup_radius: float
## レベルごとの最高速度の伸び
## レベルが1上がるごとに、最高速度をこの割合だけ伸ばす。0.02 なら 2%。
## 単位：割合
@export var level_speed_growth: float
## レベルごとの攻撃力の伸び
## レベルが1上がるごとに、攻撃力をこの割合だけ伸ばす。
## 単位：割合
@export var level_atk_growth: float
## レベルごとの最大 HP の増加
## レベルが1上がるごとに、最大 HP に足す量。
## 単位：HP
@export var level_hp_growth: float
## レベルアップの回復
## レベルが上がったとき、最大 HP のこの割合だけ回復する。
## 単位：割合（0〜1）
@export var level_heal: float
## 向きを変える速さ
## マウス・スティックの方向へ、機体の進む向きを回す速さ。
## 単位：ラジアン/秒
@export var steer_rate: float
## 加速の強さ
## 巡航の速さに達するまでの加速。
## 単位：単位/秒²
@export var steer_accel: float
## 巡航の速さ
## マウスで動かすとき、最高速度のこの割合まで自分で加速する。
## 単位：割合（最高速度に対して）
@export var steer_cruise: float
## スティックを倒し切ったときの巡航の速さ
## タッチのスティックを最大まで倒したとき、最高速度のこの割合まで加速する。少しだけ倒したときは「巡航の速さ」。
## 単位：割合（最高速度に対して）
@export var stick_cruise_max: float
## スティックの遊び
## タッチのスティックで、これより小さいずれは無視する。
## 単位：px（画面上）
@export var stick_dead_zone: float
## スティックの半径
## タッチのスティックで、この距離だけずらすと倒し切った扱いになる。
## 単位：px（画面上）
@export var stick_radius: float
## マウスの遊び
## カーソルが機体からこの距離以内なら、向きを変えない。
## 単位：単位（距離）
@export var mouse_dead_zone: float
## 普段の減速
## 巡航の速さを超えた分が落ちていく強さ。
## 単位：毎秒の減衰率
@export var cruise_drag: float
## 減速の下限
## 普段の減速では、最高速度のこの割合より遅くならない。
## 単位：割合（最高速度に対して）
@export var cruise_floor: float
## 最高速度を超えた分の減り方
## 最高速度を超えている分が、毎秒どれだけ減っていくか。
## 単位：毎秒の減衰率
@export var overcap_decay: float
## 突進の強さ
## なぞりの速さ ＝ 最高速度 × この値 × 使ったゲージの量 ＋ 同じ向きの今の速さ × 速さの引き継ぎ。
## 単位：倍
@export var launch_ratio: float
## 速さの引き継ぎ
## なぞりを始めたとき、同じ向きに動いていた速さのうち、この割合を突進の速さに足す。
## 単位：割合（0〜1）
@export var carry: float
## 発射後の減速しない時間
## なぞりを始めてからこの時間は減速しない。
## 単位：実秒
@export var boost_duration: float
## 発射後に残す速さ
## 減速しない時間が終わったあと、速さをこの割合まで落とす（0.3 秒ごとにこの割合を掛ける）。
## 単位：割合（0〜1）
@export var energy_cut: float
## 向きを保つ速さ
## これより遅いときは、機体の向きを最後に操作した向きのままにする。
## 単位：単位/秒
@export var pivot_speed: float

## ゲージの溜まり方、線の描き方、なぞりの速さと攻撃
@export_group("ゲージと描画")
## ゲージの充填時間
## ゲージが空から満タンになるまでの時間（容量1のとき）。特性・強化で短くなる。
## 単位：実秒
@export var dash_charge_time: float
## 描き始められるゲージ
## ゲージがこの割合以上溜まっていれば、線を描き始められる。
## 単位：割合（0〜1）
@export var draw_min_charge: float
## 描ける長さ
## 満タン・容量1・基本の最高速度のときに描ける線の長さ。ゲージの量・容量・最高速度に比例して変わる。
## 単位：単位（距離）
@export var draw_length: float
## 描画中の世界の速さ
## 線を描いている間、世界をこの倍率で遅くする。0 で止まる、1 で通常どおり。
## 単位：倍（0〜1）
@export var draw_time_scale: float
## なぞり中の遅さの基準
## なぞり中の世界の速さ ＝ この値 ÷ 突進の速さ。大きいほど、なぞり中の世界が速く動く。
## 単位：単位/秒
@export var draw_run_slow_ref: float
## なぞり中の世界の速さの下限
## なぞり中、世界をこれより遅くしない。
## 単位：倍（0〜1）
@export var draw_run_scale_min: float
## なぞる時間
## 描いた線全体を機体がなぞり終えるまでの時間。線の長さによらず同じ。
## 単位：実秒
@export var draw_run_time: float
## 線の点の間隔
## 線を描くとき、この距離ごとに点を記録する。小さいほど線がなめらかになる。
## 単位：単位（距離）
@export var draw_step: float
## なぞりの波動の幅
## なぞった線の左右この距離の帯にいる敵に、装甲を無視する波動が当たる。
## 単位：単位（距離）
@export var wave_radius: float
## なぞりの波動の威力
## 波動のダメージ ＝ 攻撃力 × この値。
## 単位：倍
@export var wave_damage: float

## 攻撃力・装甲・クリティカル・弾かれ・ヒットストップ、敵の狙い方
@export_group("戦闘")
## 基本の攻撃力
## レベル・特性・強化で伸びる前の攻撃力。体当たりはこれが敵の装甲以上なら貫通する。
## 単位：攻撃力
@export var base_attack: float
## 攻撃力の全体倍率
## すべての攻撃力に掛ける倍率。全体の難しさの調整用。
## 単位：倍
@export var atk_scale: float
## 基本のクリティカル率
## 攻撃がクリティカルになる確率。特性で上がる。
## 単位：割合（0〜1）
@export var base_crit_chance: float
## クリティカルの威力
## クリティカルのダメージの倍率。
## 単位：倍
@export var crit_mult: float
## 高速の接触になる速さ
## 最高速度のこの割合以上で敵に触れると、体当たりの攻撃になる（なぞり中と勢いの間は常に攻撃）。
## 単位：割合（最高速度に対して）
@export var ram_speed_ratio: float
## クリティカルの装甲の判定
## クリティカルの体当たりでは、敵の装甲にこの値を掛けて貫通できるかを判定する。小さいほど抜けやすい。
## 単位：倍
@export var crit_armor: float
## 弾かれたときに残す速さ
## 装甲に弾かれて跳ね返るとき、速さをこの割合だけ残す。
## 単位：割合（0〜1）
@export var bounce_keep: float
## 弾かれたときの最低の速さ
## 弾かれて跳ね返る速さは、これより遅くならない。
## 単位：単位/秒
@export var bounce_min_speed: float
## 同じ敵に当たらない時間
## 一度触れた敵には、この時間だけ続けて当たらない。
## 単位：世界秒
@export var contact_cooldown: float
## 撃破のヒットストップ
## 敵を一撃で倒したとき、世界を止める時間。
## 単位：実秒
@export var kill_hitstop: float
## ヒットストップの上限
## 1回の突進で止まる時間の合計は、これを超えない。
## 単位：実秒
@export var kill_hitstop_cap: float
## ヒットストップの上限の戻り
## 突進していない間、使った上限が毎秒この量だけ戻る。
## 単位：実秒/実秒
@export var kill_hitstop_regen: float
## 大型の敵のヒットストップ
## 大型の敵を倒したとき、ヒットストップにこの倍率を掛ける。
## 単位：倍
@export var hitstop_big_mult: float
## クリティカルのヒットストップ
## クリティカルで倒したとき、ヒットストップにこの倍率を掛ける。
## 単位：倍
@export var hitstop_crit_mult: float
## 敵の狙いの遅れ
## 敵は機体の実際の位置ではなく、この時間だけ遅れて追いかける位置を狙う。射撃・誘導・追跡・突進に使う。
## 単位：秒
@export var enemy_aim_lag: float
## 敵の狙いの速さの上限
## 敵が狙う位置は、これより速く動かない。機体が速く動くほど、敵の狙いが外れやすい。
## 単位：単位/秒
@export var enemy_aim_speed: float

## 敵全体の強さ・数、動き方、出現の決まり
@export_group("敵")
## 敵の HP 倍率
## すべての敵（ボスを含む）の HP に掛ける。
## 単位：倍
@export var enemy_hp_mult: float
## 敵の装甲倍率
## すべての敵（ボスを含む）の装甲に掛ける。
## 単位：倍
@export var enemy_armor_mult: float
## 敵の密度倍率
## 時間帯ごとの敵の数と補充の速さに掛ける。
## 単位：倍
@export var density_mult: float
## 追跡の広がり
## 敵が機体から離れて動き回る範囲の広さ。480 で画面いっぱい、小さいほど機体の近くに集まる。
## 単位：単位（距離）
@export var enemy_pursuit_spread: float
## 接近と移動の周期
## 敵は、この周期で「機体へ接近」と「画面内を動き回る」を繰り返す。
## 単位：世界秒
@export var enemy_approach_cycle: float
## 接近する時間
## 周期のうち、機体へ向かって接近する時間。
## 単位：世界秒
@export var enemy_approach_time: float
## 接近と移動の切り替えの時間
## 接近と動き回るのを切り替えるとき、進路をなめらかに変える時間。
## 単位：世界秒
@export var enemy_approach_blend: float
## 動き回る先の回る速さ
## 動き回っている敵の移動先が、時間とともに回る速さ。
## 単位：ラジアン/世界秒
@export var enemy_roam_turn: float
## 分裂で増える上限
## 分裂で増える敵は、その時点の目標の数の (1 ＋ この値) 倍までにする。
## 単位：割合
@export var enemy_split_overflow: float
## 危険度による敵レベルの上乗せ
## 危険度が最大（1）の場所で出る敵に、レベルをこれだけ足す。
## 単位：レベル
@export var danger_level: float
## 出現位置の余白
## 敵を、画面の外側この距離のところに出す。
## 単位：単位（距離）
@export var spawn_margin: float
## 不足分を補う時間
## 敵が目標の数に足りないとき、およそこの時間で不足分を補充する。
## 単位：世界秒
@export var spawn_refill_time: float
## 遠くの敵を移す距離
## 画面の半分の大きさ × この値 ＋ 200 より離れた敵は、画面外の出現位置へ移す。
## 単位：倍
@export var spawn_recycle_scale: float
## タイタンの同時数の上限
## タイタンが同時に出ていられる数。
## 単位：体
@export var titan_max: int
## 当たり判定の格子の大きさ
## 当たり判定を探すための区切りの大きさ。性能の調整用で、遊びは変わらない。
## 単位：単位（距離）
@export var grid_cell: float
## 世界側の更新の間隔
## 敵・ボス・天体・格子・弾・出現・回収を、固定更新の何回に1回まとめて進めるか。入力・線・機体・武器は毎回進める。性能の調整用。
## 単位：回
@export var world_tick_div: int
## 敵の半径の最大値
## 当たり判定を探すときの余白。一番大きい敵の半径以上にする。
## 単位：単位（距離）
@export var max_enemy_radius: float
## 戦艦の同時数の上限
## 戦艦が同時に出ていられる数。
## 単位：体
@export var battleship_max: int

## 大型の敵を倒したときに飛ぶ、攻撃する破片
@export_group("大型の敵の破片")
## 破片が出る大きさ
## 半径がこれ以上の敵を倒すと、攻撃する破片が飛ぶ。
## 単位：単位（距離）
@export var hull_debris_min_radius: float
## 破片の最大数
## 1体から飛ぶ破片の数の上限（敵の大きさで増える）。
## 単位：個
@export var hull_debris_max_pieces: int
## 破片の寿命
## 破片が飛んでいる時間。
## 単位：世界秒
@export var hull_debris_life: float
## 破片の威力
## 破片のダメージ ＝ 攻撃力 × この値。
## 単位：倍
@export var hull_debris_damage: float
## 破片の速さ
## 普通に倒したときの破片の初速。
## 単位：単位/秒
@export var hull_debris_speed: float
## 強い攻撃での破片の速さ
## ソニックブーム・クリティカルランスで倒したときの破片の初速。
## 単位：単位/秒
@export var hull_debris_force_speed: float
## 破片の吹き飛ばし
## 破片が当たった敵を吹き飛ばす強さ。
## 単位：単位/秒
@export var hull_debris_knock: float
## 破片の広がり
## 攻撃の向きがあるとき、破片を飛ばす扇の角度。
## 単位：度
@export var hull_debris_spread: float

## 経験値・カプセル・修理キット・部品・出力コアの出方
@export_group("ドロップ")
## カプセルのドロップ率の係数
## 敵がカプセルを落とす確率 ＝ この値 × 敵の経験値 ^ ドロップ率の指数（上限あり）。
## 単位：割合
@export var drop_base: float
## ドロップ率の指数
## 強い敵ほどカプセルを落としやすくする度合い。
## 単位：指数
@export var drop_power_exp: float
## カプセルのドロップ率の上限
## 敵がカプセルを落とす確率は、これを超えない。
## 単位：割合（0〜1）
@export var drop_max: float
## カプセルの経験値
## 敵が落とすカプセルで得る経験値 ＝ 今のレベルに必要な経験値 × この値。
## 単位：割合
@export var capsule_xp_frac: float
## 漂流カプセルの経験値
## フィールドに漂うカプセルで得る経験値 ＝ 今のレベルに必要な経験値 × この値。
## 単位：割合
@export var drift_capsule_xp_frac: float
## 漂流カプセルの数
## フィールドに同時に漂っている漂流カプセルの最大数。
## 単位：個
@export var drift_capsule_count: int
## 漂流カプセルの補充の間隔
## この間隔ごとに、機体の近くへ漂流カプセルを1つ補充する。
## 単位：世界秒
@export var drift_capsule_interval: float
## 隕石の密度
## 隕石の配置の基準の数。隕石地帯・漂う岩・彗星の数がこれに合わせて決まる。
## 単位：個
@export var meteor_count: int
## 隕石の部品のドロップ率
## 隕石を壊したとき、部品（1〜3個）を落とす確率。
## 単位：割合（0〜1）
@export var meteor_coin_chance: float
## 隕石の修理キットのドロップ率
## 隕石を壊したとき、修理キットを落とす確率。
## 単位：割合（0〜1）
@export var meteor_heal_chance: float
## 修理キットの回復量
## 修理キットを拾ったとき、最大 HP のこの割合を回復する。
## 単位：割合（0〜1）
@export var meteor_heal_frac: float
## 隕石の回収ビーコンのドロップ率
## 隕石を壊したとき、回収ビーコン（フィールドの経験値をすべて回収）を落とす確率。
## 単位：割合（0〜1）
@export var meteor_magnet_chance: float
## 出力コアの効果
## 出力コアを1つ拾うごとに、最高速度をこの割合だけ伸ばす。
## 単位：割合
@export var core_boost: float
## ドロップの寿命
## 敵・隕石が落としたカプセル・修理キット・回収ビーコンが消えるまでの時間。
## 単位：世界秒
@export var pickup_life: float
## 経験値の結晶の最大数
## フィールドの経験値の結晶がこの数を超えたら、古いものをまとめる。性能の調整用。
## 単位：個
@export var gem_max: int

## レベルアップに必要な経験値、武器・特性の枠と上限、3択のカード
@export_group("成長")
## 必要経験値：基本
## レベル L から次へ必要な経験値 ＝ 基本 ＋ 伸び × L ＋ 曲線 × L²。
## 単位：経験値
@export var xp_base: float
## 必要経験値：伸び
## レベルが上がるごとに、必要な経験値に比例して足す量。
## 単位：経験値
@export var xp_growth: float
## 必要経験値：曲線
## レベルが高くなるほど、必要な経験値を急に増やす量。
## 単位：経験値
@export var xp_curve: float
## 武器の枠
## 同時に持てる武器の数。
## 単位：個
@export var weapon_slots: int
## 武器の最大レベル
## 武器を強化できる上限のレベル。
## 単位：Lv
@export var weapon_max_level: int
## 特性の枠
## 同時に持てる特性の種類の数。
## 単位：個
@export var trait_slots: int
## 特性の最大重ね数
## 同じ特性を重ねられる上限。
## 単位：回
@export var trait_max_stacks: int
## 最初の武器の候補の数
## ラン開始時に、全武器からランダムにこの数だけ出し、1つを選んでスタートする。
## 単位：個
@export var start_weapon_choices: int
## リロールの回数
## 1回のランで、3択のカードを引き直せる回数。機体の強化「演算予備」で増える。
## 単位：回
@export var reroll_count: int
## 持っているもののカードの出やすさ
## 3択で、持っている武器・特性の強化のカードを、新しいものよりこの倍率で出やすくする。
## 単位：倍
@export var owned_card_bias: float
## 回復のカードの回復量
## 3択の候補が足りないときに出る回復のカードで、最大 HP のこの割合を回復する。
## 単位：割合（0〜1）
@export var fallback_heal: float

## 画面に映る範囲と、速さによる引き
@export_group("カメラ")
## 止まっているときの映る範囲
## 止まっているとき、画面の短い辺に映る距離。大きいほど広く見える。
## 単位：単位（距離）
@export var base_view: float
## 引き始める最高速度
## 最高速度がこれを超えると、カメラが引いて広く映す。
## 単位：単位/秒
@export var zoom_ref_speed: float
## 引きの強さ
## 最高速度が上がったとき、どれだけ強く引くか。
## 単位：指数
@export var zoom_exp: float
## 最も引いたときの倍率
## カメラはこれより引かない（小さいほど広く映せる）。
## 単位：倍
@export var zoom_min: float
## 先を見せる量
## 進む向きへ、速さ × この値だけ先を画面の中心にする。
## 単位：秒
@export var look_ahead: float
