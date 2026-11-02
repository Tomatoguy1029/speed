## 通常入口を切り替えるまで、編集値だけのResourceを既存Runnerへ対応させる。
## C++の状態や技実行へは渡さない。
extends RefCounted
const RUNNERS := {
	"res://scripts/data_types/boss_techniques/draco/meteor.gd":"res://scripts/bosses/draco/techniques/meteor.gd",
	"res://scripts/data_types/boss_techniques/draco/star_fan.gd":"res://scripts/bosses/draco/techniques/star_fan.gd",
	"res://scripts/data_types/boss_techniques/draco/tail_sweep.gd":"res://scripts/bosses/draco/techniques/tail_sweep.gd",
	"res://scripts/data_types/boss_techniques/hydra/grid.gd":"res://scripts/bosses/hydra/techniques/grid.gd",
	"res://scripts/data_types/boss_techniques/hydra/curve.gd":"res://scripts/bosses/hydra/techniques/curve.gd",
	"res://scripts/data_types/boss_techniques/draco/tail_slam.gd":"res://scripts/bosses/draco/techniques/tail_slam.gd",
	"res://scripts/data_types/boss_techniques/draco/leap.gd":"res://scripts/bosses/draco/techniques/leap.gd",
	"res://scripts/data_types/boss_techniques/draco/charge.gd":"res://scripts/bosses/draco/techniques/charge.gd",
	"res://scripts/data_types/boss_techniques/draco/breath.gd":"res://scripts/bosses/draco/techniques/breath.gd",
	"res://scripts/data_types/boss_techniques/draco/bite.gd":"res://scripts/bosses/draco/techniques/bite.gd",
	"res://scripts/data_types/boss_techniques/centaurus/combo_shower_shot.gd":"res://scripts/bosses/centaurus/techniques/combo_shower_shot.gd",
	"res://scripts/data_types/boss_techniques/centaurus/combo_rain_volley.gd":"res://scripts/bosses/centaurus/techniques/combo_rain_volley.gd",
	"res://scripts/data_types/boss_techniques/hydra/wind_blades.gd":"res://scripts/bosses/hydra/techniques/wind_blades.gd",
	"res://scripts/data_types/boss_techniques/hydra/beam_fixed.gd":"res://scripts/bosses/hydra/techniques/beam_fixed.gd",
	"res://scripts/data_types/boss_techniques/hydra/beam_bolt.gd":"res://scripts/bosses/hydra/techniques/beam_bolt.gd",
	"res://scripts/data_types/boss_techniques/hydra/bite_sweep.gd":"res://scripts/bosses/hydra/techniques/bite_sweep.gd",
	"res://scripts/data_types/boss_techniques/hydra/bite_thrust.gd":"res://scripts/bosses/hydra/techniques/bite_thrust.gd",
	"res://scripts/data_types/boss_techniques/centaurus/sail_run.gd":"res://scripts/bosses/centaurus/techniques/sail_run.gd",
	"res://scripts/data_types/boss_techniques/centaurus/arrow_shower.gd":"res://scripts/bosses/centaurus/techniques/arrow_shower.gd",
	"res://scripts/data_types/boss_techniques/canis_major/sirius_flame.gd":"res://scripts/bosses/canis_major/techniques/sirius_flame.gd",
	"res://scripts/data_types/boss_techniques/canis_major/relay.gd":"res://scripts/bosses/canis_major/techniques/relay.gd",
	"res://scripts/data_types/boss_techniques/canis_major/nova.gd":"res://scripts/bosses/canis_major/techniques/nova.gd",
	"res://scripts/data_types/boss_techniques/canis_major/hunt_pounce.gd":"res://scripts/bosses/canis_major/techniques/hunt_pounce.gd",
	"res://scripts/data_types/boss_techniques/canis_major/hunt.gd":"res://scripts/bosses/canis_major/techniques/hunt.gd",
	"res://scripts/data_types/boss_techniques/canis_major/stream.gd":"res://scripts/bosses/canis_major/techniques/stream.gd",
	"res://scripts/data_types/boss_techniques/canis_major/blaze.gd":"res://scripts/bosses/canis_major/techniques/blaze.gd",
	"res://scripts/data_types/boss_techniques/canis_major/bay.gd":"res://scripts/bosses/canis_major/techniques/bay.gd",
	"res://scripts/data_types/boss_techniques/canis_major/sirius.gd":"res://scripts/bosses/canis_major/techniques/sirius.gd",
	"res://scripts/data_types/boss_techniques/canis_major/pounce.gd":"res://scripts/bosses/canis_major/techniques/pounce.gd",
	"res://scripts/data_types/boss_techniques/canis_major/howl.gd":"res://scripts/bosses/canis_major/techniques/howl.gd",
	"res://scripts/data_types/boss_techniques/canis_major/command.gd":"res://scripts/bosses/canis_major/techniques/command.gd",
	"res://scripts/data_types/boss_techniques/centaurus/fan_volley.gd":"res://scripts/bosses/centaurus/techniques/fan_volley.gd",
	"res://scripts/data_types/boss_techniques/centaurus/stomp.gd":"res://scripts/bosses/centaurus/techniques/stomp.gd",
	"res://scripts/data_types/boss_techniques/centaurus/power_shot.gd":"res://scripts/bosses/centaurus/techniques/power_shot.gd",
	"res://scripts/data_types/boss_techniques/centaurus/rain.gd":"res://scripts/bosses/centaurus/techniques/rain.gd",
	"res://scripts/data_types/boss_techniques/centaurus/rear_attack.gd":"res://scripts/bosses/centaurus/techniques/rear_attack.gd",
	"res://scripts/data_types/boss_techniques/centaurus/volley.gd":"res://scripts/bosses/centaurus/techniques/volley.gd",
	"res://scripts/data_types/boss_techniques/monoceros/sword_flash.gd":"res://scripts/bosses/monoceros/techniques/sword_flash.gd",
	"res://scripts/data_types/boss_techniques/monoceros/horn_dance.gd":"res://scripts/bosses/monoceros/techniques/horn_dance.gd",
	"res://scripts/data_types/boss_techniques/monoceros/horn_wave.gd":"res://scripts/bosses/monoceros/techniques/horn_wave.gd",
	"res://scripts/data_types/boss_techniques/monoceros/return_charge.gd":"res://scripts/bosses/monoceros/techniques/return_charge.gd",
	"res://scripts/data_types/boss_techniques/monoceros/lance.gd":"res://scripts/bosses/monoceros/techniques/lance.gd",
	"res://scripts/data_types/boss_techniques/monoceros/sweep.gd":"res://scripts/bosses/monoceros/techniques/sweep.gd",
	"res://scripts/data_types/boss_techniques/monoceros/charge.gd":"res://scripts/bosses/monoceros/techniques/charge.gd",
	"res://scripts/data_types/boss_techniques/monoceros/kick.gd":"res://scripts/bosses/monoceros/techniques/kick.gd",
}
static func definition(move: BossTechnique) -> BossTechnique:
	if move==null: return null
	var path: String = move.get_script().resource_path
	if not RUNNERS.has(path): return move
	var legacy: BossTechnique = load(RUNNERS[path]).new()
	legacy.assign_values(move.values())
	return legacy

static func make(move: BossTechnique) -> RefCounted:
	var legacy := definition(move)
	return legacy.make_runner() if legacy!=null else null
