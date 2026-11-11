#pragma once
#include <cstdint>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace godot {
// PixelPainter と同じ順序・格子・MultiMesh形式で、画素の多い武器演出をまとめて作る。
class SpeedWeaponGeometry : public RefCounted {
    GDCLASS(SpeedWeaponGeometry, RefCounted)
    PackedFloat32Array buffer_;
    float *data_ = nullptr;
    int count_ = 0;
    double px_ = 1;
    void fill(double x, double y, Color color, int w = 1, int h = 1);
    void dot(Vector2 p, Color color, int size = 1);
    void disk(Vector2 p, double r, Color color);
    void ring(Vector2 p, double r, Color color);
    void thick_ring(Vector2 p, double r, int width, Color color);
    void line(Vector2 a, Vector2 b, Color color);
    void dither_dot(Vector2 origin, Vector2 at, Color color, double alpha);
    void dither_line(Vector2 origin, Vector2 a, Vector2 b, Color color, double alpha);
protected:
    static void _bind_methods();
public:
    void begin(PackedFloat32Array buffer, int count, double pixel);
    PackedFloat32Array take_buffer();
    int get_count() const { return count_; }
    void mass_tow_heat(Vector2 cell, int count, double clock);
    void mass_tow_chains(Array cargo, Vector2 ship_pos, Vector2 heading, int count, double clock);
    void mass_tow_hulls(Array shots);
    void knockback(Array breaks, Array hits, double clock);
    void end_blast_arc(Vector2 origin, PackedVector2Array path, double strength);
};
}
