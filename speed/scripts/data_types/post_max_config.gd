## 全武器MAX後の仮調整値。増分はそのランの基準値に対して加算する。
class_name PostMaxConfig
extends Resource

## カードID → 1回の増分。割合・秒・HP・ポイントはカードごとの単位。
@export var increments: Dictionary = {}
## 武器ID → 実際に増幅するパラメータ・専用の発射/接触経路。
## W03のcollision_radius・hull_lifeは船体/破片の専用経路を表す。表示専用の寿命・光跡は含めない。
@export var targets: Dictionary = {}
## 攻撃間隔・充填時間は基準のこの割合まで短縮する。
@export var minimum_time_ratio: float = 0.2
@export var minimum_interval: float = 0.05
@export var minimum_charge_time: float = 0.25
@export var maximum_invulnerability: float = 2.0
@export var maximum_repair_fraction: float = 1.0

func amount(id: StringName, stacks: Dictionary) -> float:
	return float(increments.get(String(id), 0.0)) * int(stacks.get(id, 0))

func factor(id: StringName, stacks: Dictionary) -> float:
	return 1.0 + amount(id, stacks)

func reduced(base: float, id: StringName, stacks: Dictionary, minimum: float) -> float:
	# 基準自体が下限より短い場合も、既存の特性・永続強化を弱めない。
	var floor_value := minf(base, maxf(minimum, base * minimum_time_ratio))
	return maxf(floor_value, base * (1.0 - amount(id, stacks)))

func target(weapon: StringName) -> Dictionary:
	return targets.get(String(weapon), {})
