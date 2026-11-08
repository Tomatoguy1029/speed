## 音の表（assets/audio/sound_table.tres）を制作工程で音声バンクへまとめる。
## 素材のない欄は合成音を作り、ループする欄は繰り返す設定にする。音なしの欄は音を入れない。
@tool
extends RefCounted
const SAMPLE_RATE := 22050
const TABLE := "res://assets/audio/sound_table.tres"
const SLOTS = preload("res://scripts/data_types/sound_slots.gd")

static func build(output: String) -> Error:
	var table := ResourceLoader.load(TABLE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as SoundTable
	if table == null:
		push_error("音の表を読み込めません: " + TABLE)
		return ERR_CANT_OPEN
	var bank := AudioBank.new()
	for row: Array in SLOTS.ROWS:
		var id := StringName(row[0])
		var music: bool = row[4] == "music"
		var entry := table.entry(id)
		if entry == null: entry = SoundEntry.new()
		bank.params[id] = {"volume_db": entry.volume_db, "pitch_min": entry.pitch_min, "pitch_max": maxf(entry.pitch_min, entry.pitch_max),
			"max_voices": entry.max_voices, "loop": entry.loop, "silent": entry.silent, "trim_start": entry.trim_start, "trim_end": entry.trim_end, "loop_start": entry.loop_start}
		var stream := _stream(entry, music)
		if stream == null: continue
		if music: bank.music[id] = stream
		else: bank.sounds[id] = stream
	return ResourceSaver.save(bank, output)

## 素材を繰り返しの設定つきで複製する。素材がなければ合成音。音なしの欄と、どちらもない欄は null。
static func _stream(entry: SoundEntry, music: bool) -> AudioStream:
	if entry.silent: return null
	if entry.stream == null:
		if entry.synth_wave == "" or entry.synth_seconds <= 0.0: return null
		return _looped(_tone(entry.synth_from_hz, entry.synth_to_hz, entry.synth_seconds, entry.synth_wave), entry.loop, 0.0)
	return _looped(entry.stream.duplicate(), entry.loop, entry.loop_start if music else 0.0)

static func _looped(stream: AudioStream, loop: bool, loop_start: float) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			wav.loop_begin = int(loop_start * wav.mix_rate)
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamMP3:
		stream.loop = loop
		stream.loop_offset = loop_start
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
		stream.loop_offset = loop_start
	return stream

static func _tone(f0: float, f1: float, length: float, wave: String) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * length)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + f1)
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase += f / SAMPLE_RATE
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				s = fmod(phase, 1.0) * 2.0 - 1.0
			"noise":
				s = rng.randf_range(-1.0, 1.0)
			_:
				s = sin(phase * TAU)
		var env := (1.0 - k) * minf(1.0, i / 40.0)
		bytes.encode_s16(i * 2, int(clampf(s * env * 0.35, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = bytes
	return wav
