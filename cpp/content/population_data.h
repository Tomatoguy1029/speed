#pragma once
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <vector>
#include <cstdint>
namespace speed {
// 配置シーンから生成する不変値。表示サイズと機体の向きは出現時に適用する。
struct PopulationFormation {
    struct Marker { godot::StringName type; godot::Vector2 offset; double rotation=0; };
    struct Entry { double weight=0; godot::Vector2 pos; };
    struct Layout { double weight=0,value=-1; int32_t managed=-1; std::vector<godot::StringName> types; std::vector<std::vector<Marker>> placements; };
    std::vector<Entry> entries;
    std::vector<Layout> layouts;
};
struct PopulationClipData {
    double start=0,end=0,interval=0,priority=0;
    int64_t maximum=0;
    godot::PackedStringArray types;
    std::vector<size_t> formations;
};
}
