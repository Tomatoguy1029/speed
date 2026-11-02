## 通常入口を切り替えるまで、編集値だけのResourceを既存Runnerへ対応させる。
## C++の状態や技実行へは渡さない。
extends RefCounted
const RUNNERS := {
	"res://scripts/data_types/boss_techniques/monoceros/charge.gd":"res://scripts/bosses/monoceros/techniques/charge.gd",
	"res://scripts/data_types/boss_techniques/monoceros/kick.gd":"res://scripts/bosses/monoceros/techniques/kick.gd",
}
static func make(move: BossTechnique) -> RefCounted:
	if move==null: return null
	var path: String = move.get_script().resource_path
	if RUNNERS.has(path): return load(RUNNERS[path]).new().make_runner()
	return move.make_runner()
