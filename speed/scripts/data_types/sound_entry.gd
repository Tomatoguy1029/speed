## 音の表の1欄。ファイルがあればそれを、なければ合成音を鳴らし、どちらもなければ鳴らさない。
## 値の正は共有の音づけ表で、取り込みのたびに上書きされる（設計書 13）。
@tool
class_name SoundEntry
extends Resource

## 鳴らす音。取り込んだ効果音は使う範囲で切り出し済み。
@export var stream: AudioStream
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
## 鳴らすたびに最小〜最大からピッチを選ぶ。同じなら固定。
@export_range(0.25, 4.0, 0.01) var pitch_min := 1.0
@export_range(0.25, 4.0, 0.01) var pitch_max := 1.0
## 同じ音を同時に鳴らす数。0は標準の数。
@export_range(0, 32) var max_voices := 0
## 止めるまで繰り返す。
@export var loop := false

@export_group("BGM")
## 曲の再生を始める位置（秒）。
@export var trim_start := 0.0
## 曲の終わりとして扱う位置（秒）。0はファイルの最後。
@export var trim_end := 0.0
## ループで戻る位置（秒）。
@export var loop_start := 0.0

@export_group("合成音")
## 素材がない間だけ鳴らす仮の音の波形（square・sine・saw・noise）。空なら鳴らさない。素材に差し替えたら使わない。
@export var synth_wave := ""
@export var synth_from_hz := 0.0
@export var synth_to_hz := 0.0
@export var synth_seconds := 0.0

func is_synth() -> bool:
	return stream == null and synth_wave != ""
