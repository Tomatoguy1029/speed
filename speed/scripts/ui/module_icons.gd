## 武器16種・特性18種を図鑑順に並べた47pxの共通アイコン。
extends RefCounted

const TEXTURE := preload("res://assets/ui/combat/icons_ordered.png")
const IDS := [
	"W01", "W02", "W23", "W25", "W26", "W04", "W08", "W17",
	"W27", "W03", "W28", "W29", "W05", "W07", "W21", "W22",
	"T33", "T05", "T08", "T14", "T04", "T06", "T09", "T32", "T03",
	"T07", "T34", "T10", "T31", "T35", "T36", "T11", "T12", "T37",
]

## 原画ではミラージュが8枠目、アークフィールドが9枠目。図鑑順はIDSに保つ。
const SLOT_OVERRIDES := {"W17": 8, "W27": 7}

static func texture_for(definition: Resource) -> Texture2D:
	var index: int = SLOT_OVERRIDES.get(String(definition.id), IDS.find(String(definition.id)))
	if index < 0:
		return definition.icon_texture
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE
	atlas.region = Rect2(index * 47, 0, 47, 47)
	return atlas
