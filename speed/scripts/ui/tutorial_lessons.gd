## 操作練習の説明パネルの一覧。初回の練習とポーズ中の操作ガイドが同じ内容を表示する。
## 動く絵は実際のランを録画したコマを格子状に並べた画像で、strip は手順表示を光らせる時刻（秒）。
extends RefCounted

const CLIP_SIZE := Vector2i(320, 200)
const CLIP_COLUMNS := 8
const CLIP_FPS := 12.0

const LESSONS := [
	{"key": "move", "frames": 48},
	{"key": "boost", "frames": 60, "strip": [[0.6, 1.4, 0], [1.4, 3.2, 1], [3.2, 3.9, 2]]},
	{"key": "gauge", "frames": 60},
	{"key": "xp", "frames": 60},
	{"key": "cards", "frames": 48},
]

static func clip_path(key: String) -> String:
	return "res://assets/ui/tutorial/%s.png" % key
