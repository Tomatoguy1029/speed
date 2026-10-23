## 制作時に展開した配置と、戦闘に必要な値だけを保存する。
## StageDefの数値と計算を共有し、編集用のシーン・名前・トラックは空にする。
## enemy_tuningは検証済みの敵別上書きを持ち、ラン専用のEnemyDefへ適用する。
class_name RuntimeStage
extends StageDef
@export var resources: StageResources
