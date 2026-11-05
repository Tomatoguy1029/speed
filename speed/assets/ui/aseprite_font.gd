@tool
extends SystemFont

func _init() -> void:
	var japanese: Font
	var path := OS.get_system_font_path("Yu Gothic UI", 400, 100, false)
	if not path.is_empty():
		var data := FileAccess.get_file_as_bytes(path)
		var reader := StreamPeerBuffer.new()
		reader.big_endian = true
		reader.data_array = data
		if data.size() >= 12 and data.slice(0, 4).get_string_from_ascii() == "ttcf":
			reader.seek(8)
			for face in reader.get_u32():
				var candidate := FontFile.new()
				candidate.data = _collection_face(data, face)
				if candidate.get_font_name() == "Yu Gothic UI":
					japanese = candidate
					_configure(candidate)
					break
	if japanese == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Yu Gothic UI"])
		japanese = system
		_configure(system)
	fallbacks = [japanese]

func _validate_property(property: Dictionary) -> void:
	# OSから取得したフォントデータを保存用のResourceへ埋め込まない。
	if property.name == "fallbacks":
		property.usage &= ~PROPERTY_USAGE_STORAGE

## TTCの面指定が無視される環境でも同じ字形を使えるよう、選んだ面だけをメモリに展開する。
func _collection_face(data: PackedByteArray, face: int) -> PackedByteArray:
	var source := StreamPeerBuffer.new()
	source.big_endian = true
	source.data_array = data
	source.seek(12 + face * 4)
	var start := source.get_u32()
	source.seek(start + 4)
	var count := source.get_u16()
	var result := StreamPeerBuffer.new()
	result.big_endian = true
	result.put_data(data.slice(start, start + 12 + count * 16))
	for table in count:
		var record := 12 + table * 16
		source.seek(start + record + 8)
		var offset := source.get_u32()
		var length := source.get_u32()
		result.seek(result.get_size())
		while result.get_size() % 4 != 0:
			result.put_u8(0)
		var target := result.get_size()
		result.put_data(data.slice(offset, offset + length))
		result.seek(record + 8)
		result.put_u32(target)
	return result.data_array

func _configure(font: Font) -> void:
	font.set("antialiasing", TextServer.FONT_ANTIALIASING_NONE)
	font.set("hinting", TextServer.HINTING_NORMAL)
	font.set("subpixel_positioning", TextServer.SUBPIXEL_POSITIONING_DISABLED)
	font.set("disable_embedded_bitmaps", false)
	font.set("oversampling", 1.0)
