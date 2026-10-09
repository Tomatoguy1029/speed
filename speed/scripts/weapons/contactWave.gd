## W04 接触波動：高速で敵に触れるたび、触れた位置から周りへ波動（一覧 docs/game/catalog/weapons.md）。
extends WeaponBehavior

func on_contact(_e: Enemy, hit: Vector2, _dir: Vector2) -> void:
	build.combat.explode(hit, float(p("radius")) * radius_k(), atk() * float(p("damage")) * dmg_k(),
		{"cause": &"contactWave", "color": Color("#9fe8ff"), "knock": p("knock"), "life": 0.3})
