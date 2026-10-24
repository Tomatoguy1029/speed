@tool
extends Resource
@export var maximum_stamina := 6.0
@export var partial_rest := 1.0
@export var empty_rest := 3.0
@export_storage var layout: Dictionary = {}
@export var sections: Array = [{"name": "通常", "request": "normal", "cap": 2.0, "weights": {"single": 60.0, "parallel": 25.0, "combo": 15.0}, "next": 0}]
