## 通常入口を切り替えるまで、編集値だけのResourceを既存Runnerへ対応させる。
## C++の状態や技実行へは渡さない。
extends RefCounted
const RUNNERS := {
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
