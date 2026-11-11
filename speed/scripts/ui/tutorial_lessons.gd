## 操作練習の説明パネルの一覧。初回の練習とポーズ中の操作ガイドが同じ内容を表示する。
## 動く絵は実際のランを録画したコマを格子状に並べた画像で、strip は手順表示を光らせる時刻（秒）。
extends RefCounted

const CLIP_SIZE := Vector2i(320, 180)
const CLIP_COLUMNS := 8
const CLIP_FPS := 10.0

const LESSONS := [
	{"key": "move", "frames": 64},
	{"key": "boost", "frames": 41, "strip": [[0.0, 0.6, 0], [0.6, 2.6, 1], [2.6, 3.1, 2]]},
	{"key": "gauge", "frames": 64},
	{"key": "xp", "frames": 63},
	{"key": "cards", "frames": 42},
]

## 練習の最後に出す区切り。動く絵を持たない。
const END := {"key": "end", "frames": 1}

static func clip_path(key: String) -> String:
	return "res://assets/ui/tutorial/%s.png" % key
