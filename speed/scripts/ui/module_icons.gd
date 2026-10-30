## 装備枠と図鑑が共通で使うアイコン。新しい絵が届くまでは既存の枠を使う。
extends RefCounted
const TEXTURE := preload("res://assets/ui/combat/icons.png")
const IDS := ["W01","W02","W03","W04","W05","W25","W07","W08","W17","W21","W22","W23","T01","T03","T04","T05","T06","T07","T08","T09","T10","T11","T12","T13","T14"]
const ALIASES := {"W29":"T01","W28":"T06","T32":"T04","T33":"T11","T34":"T14","T35":"W02","T36":"W01","T37":"W25"}
static func texture_for(definition: Resource) -> Texture2D:
	if definition.icon_texture != null: return definition.icon_texture
	var id := String(definition.id)
	var index := IDS.find(ALIASES.get(id,id))
	if index < 0: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE
	atlas.region = Rect2(index*47,0,47,47)
	return atlas
