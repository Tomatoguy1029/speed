## 制作時に合成した音は、元の波形と同じデータを読み込む。
extends Node
const EXPECTED := {
	"block": {
		"hash": "bffdb464e57077af9d6cd023acd05f347580df13686e5c97adb6d96ceb76d676",
		"rate": 22050,
		"size": 3528
	},
	"boom": {
		"hash": "d9cf7b2f07eeec614744e9ec60fd9b5624b578c20f53fb33a4e2c58b9968b084",
		"rate": 22050,
		"size": 22050
	},
	"dash": {
		"hash": "3c2e4040ce6537d4739fd922a0ce27bfc5dbf6e06700f7c0f72c94fa463c6980",
		"rate": 22050,
		"size": 7938
	},
	"hit": {
		"hash": "5da78562aab917b6d0ecb27af43212180bfff246039a670f2a5c7c1a82766863",
		"rate": 22050,
		"size": 2646
	},
	"hurt": {
		"hash": "1d171757b9878cb04682c56f5838c397181789006eda8df4dc5eae1f397d7bf3",
		"rate": 22050,
		"size": 8820
	},
	"kill": {
		"hash": "640320e43cb28091db1574b84368f4115f494faf0e7ffac54d7dd6edf509b8c6",
		"rate": 22050,
		"size": 5292
	},
	"levelup": {
		"hash": "aa946cb1e3e3066b57f5ea4f40e342bd3de01442590680c9b4261519907ef093",
		"rate": 22050,
		"size": 11024
	},
	"pickup": {
		"hash": "3c61ef68b0cba6c26664ddc54d02ebc33ff7f540246ccad76f5c0b78cc151ee4",
		"rate": 22050,
		"size": 2204
	},
	"shoot": {
		"hash": "723723f560cfde53fc2f5a985c38ac94b173795f1db474d27d191ede479903e0",
		"rate": 22050,
		"size": 1764
	},
	"ui": {
		"hash": "9ced8e099c4f59ee2cf817e8d5a0d4623120e8dc806fd4a88336b185feace455",
		"rate": 22050,
		"size": 1764
	}
}
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(not AudioManager.has_method("_build_sounds"), "起動時の音声合成を持たない")
	for name in EXPECTED:
		var wav: AudioStreamWAV = AudioManager._sounds[StringName(name)]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(wav.data)
		check(hash.finish().hex_encode() == EXPECTED[name].hash, "波形を維持する: " + name)
		check(wav.mix_rate == EXPECTED[name].rate and wav.data.size() == EXPECTED[name].size, "長さとサンプル周波数を維持する: " + name)
	print("[baked_audio] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
