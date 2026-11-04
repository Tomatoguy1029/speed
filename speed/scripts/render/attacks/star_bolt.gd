## 星の形と芯はシーンのFlightで編集し、共通のMeshバッチで描く。
extends AttackVisual

## 制作済みのFlightメッシュを通常のC++ランでも使う。
static func setup_batch(batch: InstanceBatch, library: Resource, scene: String) -> void:
	batch._setup_mesh(library.get_meta("looks",{}).get(scene,{}).get("Flight"))
