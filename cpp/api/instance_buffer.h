#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {
// 表示の値だけから、InstanceBatchと同じ順序・丸めの12要素バッファを作る。
class SpeedInstanceBuffer : public RefCounted {
    GDCLASS(SpeedInstanceBuffer, RefCounted)
    PackedFloat32Array buffer_;
    int count_ = 0;
    void reserve(int count);
protected:
    static void _bind_methods();
public:
    void begin(PackedFloat32Array buffer);
    void frame(PackedFloat32Array transforms, PackedColorArray colors);
    void enemy_part(Dictionary row, Vector2 pivot, double angle_offset, int jaw_sign, int ruler_side, bool articulate);
    int get_count() const { return count_; }
    PackedFloat32Array take_buffer();
};
}
