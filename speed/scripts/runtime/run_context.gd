## 1つのランに属するものの置き場（設計書 4.4）。
##
## System・個別の処理は、ほかの System や状態をここから引く。グローバルな「今のラン」は引かない。
## 実験場は複数のランを同時に持つので、ランごとに別の RunContext を作る。
class_name RunContext
extends RefCounted

var state: RunState
var cfg: GameConfig
## ランを始めたときの指定（実験場の上書き・seed など）
var options: Dictionary = {}

var field: FieldSystem
var ship: ShipSystem
var draw: DrawSystem
var combat: CombatSystem
var enemies: EnemySystem
var spawn: SpawnSystem
var bosses: BossSystem
var projectiles: ProjectileSystem
var loadout: LoadoutSystem
var pickups: PickupSystem
var heroes: HeroSystem

var resources: ContentResourceScope

## 永続強化を反映した係数のスナップショット。
var profile: Dictionary = {}
## 開発版の処理時間の記録先。RunSimulation と同じもの
var perf := PerfLog.new()
