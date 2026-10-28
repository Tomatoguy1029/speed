## BossAIと実験場が共用する技パラメータの表示・入力範囲。
extends RefCounted

const PARAM_LABELS := {"radius_factor":"螺旋の半径倍率","body_ratio":"螺旋の胴体幅（画面短辺比）","head_scale":"頭の拡大倍率","coil_turns":"胴体の巻き数","first_lap":"1周目の時間（秒）","second_lap":"2周目の時間（秒）","pause":"巻き終わりの停止（秒）","shrink_time":"収縮と離脱（秒）","clone_stars":"複製1体の星数（仮）","warn": "予告（秒）", "active": "実行時間（秒）", "recover": "技後の待ち（秒）", "hold": "攻撃後の停止（秒）", "return_speed": "正面へ戻る速さ（度/秒）", "cd": "再使用待ち（秒）", "damage": "ダメージ", "distance": "移動距離", "reach": "届く長さ", "arc": "薙ぐ角度（度）", "normal_charge": "予備動作（秒）", "normal_hold": "攻撃後の停止（秒）", "attack_cd": "技後の待ち（秒）", "normal_lunge": "踏み込み時間（秒）", "warning_time": "予告（秒）", "performance_time": "実行時間（秒）", "tech_recovery": "技後の全体待ち（秒）", "cooldown": "再使用待ち（秒）", "sweep_time": "薙ぎ時間（秒）", "sweep_reach": "薙ぎの長さ", "sweep_arc": "薙ぎの角度（度）", "aim_tracking": "標的位置を追う時間（秒）", "count": "矢の数", "interval": "矢の間隔（秒）", "speed": "矢の速さ", "radius": "矢の半径", "travel": "矢の射程", "alert": "発射前の警告（秒）", "traces": "トレースの回数", "forward": "前方への距離", "circle_radius": "円の半径", "trace_length": "トレースの長さ", "trace_speed": "トレースの速さ", "trace_bend": "曲がり具合（度）", "trace_gap": "トレースの間隔（秒）", "drop_delay": "円が通ってから矢を落とし始めるまで（秒）", "fall": "矢が降りる時間（秒）", "fade": "矢が不透明になる時間（秒）", "drop_height": "矢が降りる高さ", "arrow_gap": "矢を落とす間隔（距離）", "arrows_per_step": "一度に落とす矢の数", "linger": "刺さった矢が残る時間（秒）", "back_offset": "背中から範囲の中心までの距離", "range_radius": "攻撃範囲の半径", "lock": "狙いを固定する時間（秒）", "overshoot": "着地点の先までの距離", "lunge_speed": "猟犬が飛び出す速さ", "lunge_time": "猟犬が飛び出す時間（秒）", "min_hounds": "号令に要る猟犬の数", "alone_hounds": "群れが少ないとみなす猟犬の数", "cd_alone": "群れが少ないときの再使用待ち（秒）", "beam_length": "光の長さ", "beam_width": "光の太さ", "beam_time": "光を出す時間（秒）", "ring_count": "囲みの猟犬の数", "ring_radius": "囲みの始めの半径", "ring_close": "囲みの終わりの半径", "gather_time": "囲みに並ぶ時間（秒）", "close_time": "囲みを狭める時間（秒）", "gaps": "薄い所の数", "gap_slots": "薄い所で抜く猟犬の数", "summon_max": "呼び足す猟犬の上限", "spawn_out": "呼んだ猟犬が出る輪の外の距離", "catch_up": "囲みへ走る速さの倍率"}
const SPIRAL_KEYS := ["radius_factor", "aspect_ratio", "pitch_ratio", "coil_time", "head_offset", "pause", "exit_duration", "spiral_length"]
const SPIRAL_LABELS := {"radius_factor":"外周半径（画面長辺の倍率）","aspect_ratio":"外周の長辺／短辺半径比","pitch_ratio":"隣の周回へ縮む割合","coil_time":"渦を2周巻く時間（秒）","pause":"巻き終わりの逃走時間（秒）","head_offset":"巻き終わりの頭の高さ（距離）","exit_duration":"全身退場の目安時間（秒）","spiral_length":"渦専用の最小体長（距離）"}
const SPIRAL_SHORT_LABELS := {"radius_factor":"外周半径の倍率","aspect_ratio":"外周の縦横比","pitch_ratio":"周回の間隔","coil_time":"2周の時間（秒）","pause":"逃走時間（秒）","head_offset":"頭の高さ","exit_duration":"退場時間（秒）","spiral_length":"最小体長"}
const SPIRAL_TIPS := {"radius_factor":"カメラを引いた後の画面長辺の半分に掛ける値。0.5〜1.5。小さくしても胴幅4本分の半径を確保します。","aspect_ratio":"1.0で円。1.0より大きいと画面の長辺方向が長い楕円になります。0.85〜1.5。","pitch_ratio":"1周ごとに半径を減らす外周半径の割合。大きいほど周回間の隙間が広がります。胴幅の1.5倍の中心線間隔を下回らないよう補正し、最大0.44。","coil_time":"頭が渦を2周する合計時間。小さいほど速くなります。1周目に40%、2周目に60%を配分し、実行時間内に逃走と突進を残すよう補正します。","pause":"巻き終わりに操作を戻して逃げられる時間。0.8秒以上を確保し、技の実行時間内に収めます。","head_offset":"巻き終わりの頭の中心を機体より何距離上に置くか。頭と機体の半径に60の余白を加えた距離以上を確保します。","exit_duration":"現在の胴体全体が画面外へ抜ける目安時間。0.6〜3秒。実際は全身が見えなくなるまで退場を続けます。この間は操作できます。","spiral_length":"渦専用の体長の下限。外周と2周の経路に必要な長さまで自動で伸ばし、通常技の体長は変えません。"}
const SPIRAL_BOUNDS := {"radius_factor":Vector2(0.5,1.5),"aspect_ratio":Vector2(0.85,1.5),"pitch_ratio":Vector2(0.15,0.44),"coil_time":Vector2(0.5,3.0),"pause":Vector2(0.8,3.0),"head_offset":Vector2(200.0,1000.0),"exit_duration":Vector2(0.6,3.0),"spiral_length":Vector2(0.0,20000.0)}

const ARC_KEYS := ["offset_x", "offset_y", "radius", "angle_degrees", "spread_degrees", "count"]
const ARC_LABELS := {"offset_x":"位置 X", "offset_y":"位置 Y", "radius":"半径", "angle_degrees":"中心角度", "spread_degrees":"広がり", "count":"弾数"}
const REQUIRED := {"spiral": ["warn", "active", "recover", "damage", "reach", "width", "radius_factor", "aspect_ratio", "pitch_ratio", "coil_time", "pause", "head_offset", "exit_duration", "spiral_length", "shrink_time"]}
const MORE_LABELS := {
	"wind_time": "風の継続時間", "wind_length": "風の長さ", "wind_width": "風の幅", "wind_force": "風の押し出す力",
	"blade_interval": "刃を出す間隔", "blade_size": "刃の大きさ", "blade_width": "刃の幅", "blade_life": "刃が残る時間", "blade_speed": "刃の速さ", "blade_spread": "刃の広がり角度（度）",
	"rubble_spread": "瓦礫の広がり角度（度）", "rubble_small_radius": "小さい瓦礫の半径",
	"bolt_length": "光弾の長さ", "bolt_width": "光弾の幅", "bolt_life": "光弾が残る時間", "bolt_speed": "光弾の速さ",
	"thunder_radius": "雷の範囲", "thunder_flash": "雷光の時間", "target_lock_fraction": "狙いを固定する割合", "thunder_lead": "雷の先読み距離",
	"tornado_charge": "竜巻の予備動作", "tornado_life": "竜巻が残る時間", "tornado_speed": "竜巻の速さ", "tornado_width": "竜巻の幅",
	"shatter_arc": "破片の広がり角度（度）", "shatter_deploy": "破片を広げる時間", "shatter_time": "破片が残る時間",
	"pincer_close_angle": "挟み込みの終点角度（度）", "pincer_delay": "挟み込みまでの遅れ", "pincer_open_angle": "挟み込みの開始角度（度）", "pincer_time": "挟み込みの時間",
	"north_flight": "北の首の飛行時間", "north_lock_time": "北の首の固定時間", "sequence_charge": "連続攻撃の予備動作", "sequence_gap": "連続攻撃の間隔",
	"curve_delay": "曲線攻撃までの遅れ", "curve_lag": "曲線攻撃の軌跡差（度）", "curve_time": "曲線攻撃の時間", "curve_turn": "曲線攻撃の回転速度（度/秒）",
	"swarm_flight": "群れの飛行時間", "swarm_gap": "群れの間隔", "swarm_reach": "群れの到達距離", "grid_time": "格子攻撃の時間",
	"active": "攻撃の継続時間", "damage": "ダメージ", "reach": "到達距離", "recover": "攻撃後の待ち", "shrink_time": "縮む時間", "width": "攻撃の幅",
	"inhale_time": "吸い込み時間", "pull_range": "引き寄せる範囲", "pull_speed": "引き寄せる速さ", "picaro_pull_speed": "複製体の引き寄せ速度", "mouth_radius": "口元の半径", "bite_damage": "噛みつきのダメージ", "beam_warn": "ビームの予告",
	"comets_per_star": "星ごとの彗星数", "comet_cap": "彗星の同時上限", "comet_speed": "彗星の速さ", "clone_hp": "複製体のHP", "arrows": "矢の数", "flight": "飛行時間", "impact_warn": "着弾の予告",
	"scratch_time": "ひっかきの時間", "scratch_width": "ひっかきの幅", "lead_cap": "標的の先読み上限", "rocks": "岩の数", "rock_hp": "岩のHP", "rock_radius": "岩の半径", "rock_distance": "岩までの距離", "rock_spacing": "岩の間隔", "half_angle": "左右の広がり角度（度）", "sweep": "薙ぐ角度（度）", "spread": "扇の角度（度）", "retract": "引き戻す時間"
}

## 技はラジアン（回転はラジアン/秒）で持ち、画面では度（度/秒）で表示・入力する値。
const ANGLE_KEYS := ["arc", "sweep_arc", "trace_bend", "blade_spread", "rubble_spread", "shatter_arc", "pincer_close_angle", "pincer_open_angle", "curve_lag", "curve_turn", "return_speed", "half_angle", "sweep", "spread"]

static func is_angle(key: String) -> bool:
	return key.trim_suffix("_p2") in ANGLE_KEYS

## 保存値を画面の値（度）へ。
static func to_display(key: String, value: float) -> float:
	return rad_to_deg(value) if is_angle(key) else value

## 画面の値（度）を保存値へ。
static func from_display(key: String, value: float) -> float:
	return deg_to_rad(value) if is_angle(key) else value

static func editable_keys(move: Resource) -> Array[String]:
	var keys: Array[String] = []
	if move == null or not move.get("parameters") is Dictionary: return keys
	for key in move.parameters:
		if key in ["cost", "major_cost"] or (move.technique == &"spiral" and key == "warn"): continue
		if move.parameters[key] is int or move.parameters[key] is float: keys.append(String(key))
	return keys

static func label_for(move: Resource, key: String, compact := false) -> String:
	var base := key.trim_suffix("_p2")
	var docs: Array = BossDef.PARAMS_DOCS.get(base, [])
	var fallback: String = String(docs[0]) if not docs.is_empty() else base
	var ordinary: String = PARAM_LABELS.get(base, MORE_LABELS.get(base, fallback))
	var label: String = SPIRAL_SHORT_LABELS.get(base, ordinary) if compact and move.technique == &"spiral" else SPIRAL_LABELS.get(base, ordinary) if move.technique == &"spiral" else ordinary
	return label + ("（第2形態）" if base != key else "")

static func tip_for(move: Resource, key: String) -> String:
	var base := key.trim_suffix("_p2")
	if move.technique == &"spiral" and SPIRAL_TIPS.has(base): return SPIRAL_TIPS[base]
	var docs: Array = BossDef.PARAMS_DOCS.get(base, [])
	return String(docs[1]) if docs.size() > 1 else "選択中の技の値です。変更は次に技を再生すると反映します。"

static func bounds_for(move: Resource, key: String) -> Vector2:
	var base := key.trim_suffix("_p2")
	return SPIRAL_BOUNDS.get(base, Vector2(0.0, 100000.0)) if move.technique == &"spiral" else Vector2(0.0, 100000.0)

static func arc_bounds(key: String) -> Vector2:
	return Vector2(-10000.0, 100000.0) if key in ["offset_x", "offset_y", "angle_degrees"] else Vector2(1.0, 100000.0)
