## 噛みつく雑魚だけの顎。固定の分割マップと共通塗装をバッチで再利用する。
extends EnemyVisual
const ASSETS_PATH := "res://data/visuals/biter_parts.tres"
const SOURCE_LOOK := "res://data/visuals/looks/biter.tres"
const ARMOR_SHADER := preload("res://shaders/biter_part_armor.gdshader")
const SPARK_SHADER := preload("res://shaders/biter_sparks.gdshader")
const SNAP := 0.034
const CLOSED_HOLD := 0.051
const RETURN_TIME := 0.12
const SPARK_TIME := 0.11
var _assets: Resource
var _parts: Array[Dictionary] = []
var _sparks: InstanceBatch
var _synced_frame := -1
