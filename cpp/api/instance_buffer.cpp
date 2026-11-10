#include "instance_buffer.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {
namespace {
double smooth(double from, double to, double value) {
    const double t = std::clamp((value - from) / (to - from), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
double jaw_angle(int mode, double charge, double timer, double rest) {
    if (mode == 1) return -8.0 * smooth(0.0, 1.0, charge);
    if (mode != 3) return 0.0;
    constexpr double snap = 0.034, closed = 0.051, back = 0.12;
    const double age = std::max(0.0, rest - timer);
    if (age < snap) return -8.0 + 20.0 * smooth(0.0, snap, age);
    if (age < snap + closed) return 12.0;
    return 12.0 * (1.0 - smooth(snap + closed, snap + closed + back, age));
}
void write_transform(float *out, const float *t, Color color) {
    out[0] = t[0]; out[1] = t[2]; out[2] = 0; out[3] = t[4];
    out[4] = t[1]; out[5] = t[3]; out[6] = 0; out[7] = t[5];
    out[8] = color.r; out[9] = color.g; out[10] = color.b; out[11] = color.a;
}
}
void SpeedInstanceBuffer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("begin", "buffer"), &SpeedInstanceBuffer::begin);
    ClassDB::bind_method(D_METHOD("frame", "transforms", "colors"), &SpeedInstanceBuffer::frame);
    ClassDB::bind_method(D_METHOD("enemy_part", "row", "pivot", "angle_offset", "jaw_sign", "ruler_side", "articulate"), &SpeedInstanceBuffer::enemy_part);
    ClassDB::bind_method(D_METHOD("get_count"), &SpeedInstanceBuffer::get_count);
    ClassDB::bind_method(D_METHOD("take_buffer"), &SpeedInstanceBuffer::take_buffer);
}
void SpeedInstanceBuffer::begin(PackedFloat32Array buffer) { buffer_ = buffer; count_ = 0; }
void SpeedInstanceBuffer::reserve(int count) {
    const int need = count * 12;
    if (buffer_.size() < need) buffer_.resize(std::max(need, int(buffer_.size()) * 2));
}
PackedFloat32Array SpeedInstanceBuffer::take_buffer() {
    PackedFloat32Array result = buffer_;
    buffer_ = PackedFloat32Array();
    return result;
}
void SpeedInstanceBuffer::frame(PackedFloat32Array transforms, PackedColorArray colors) {
    const int count = colors.size();
    ERR_FAIL_COND(transforms.size() != int64_t(count) * 6);
    reserve(count);
    if (count == 0) return;
    const float *t = transforms.ptr(); const Color *c = colors.ptr();
    float *out = buffer_.ptrw();
    for (int i = 0; i < count; ++i) write_transform(out + i * 12, t + i * 6, c[i]);
    count_ = count;
}
void SpeedInstanceBuffer::enemy_part(Dictionary row, Vector2 pivot, double offset, int jaw_sign, int ruler_side, bool articulate) {
    const PackedFloat32Array transforms = row["transforms"], deformation = row.get("deformations", PackedFloat32Array());
    const PackedColorArray colors = row["colors"];
    const PackedInt32Array sides = row.get("ruler_sides", PackedInt32Array());
    const Dictionary biter = row.get("biter", Dictionary());
    const PackedInt32Array modes = biter.get("modes", PackedInt32Array());
    const PackedFloat32Array charges = biter.get("charges", PackedFloat32Array()), timers = biter.get("timers", PackedFloat32Array()), rests = biter.get("rests", PackedFloat32Array());
    const int count = colors.size();
    ERR_FAIL_COND(transforms.size() != int64_t(count) * 6 || (!deformation.is_empty() && deformation.size() != int64_t(count) * 5));
    ERR_FAIL_COND(ruler_side != 0 && sides.size() != count);
    ERR_FAIL_COND(articulate && (modes.size() != count || charges.size() != count || timers.size() != count || rests.size() != count));
    reserve(count);
    if (count == 0) return;
    float *out = buffer_.ptrw(); const float *t = transforms.ptr(), *d = deformation.ptr();
    const Color *color = colors.ptr();
    for (int i = 0; i < count; ++i) {
        if (ruler_side != 0 && sides[i] != 0 && sides[i] != ruler_side) continue;
        double radius = Vector2(t[i * 6], t[i * 6 + 1]).length();
        double angle = std::atan2(double(t[i * 6 + 1]), double(t[i * 6]));
        if (d) { radius = d[i * 5]; angle = d[i * 5 + 1]; }
        double jaw = articulate ? Math::deg_to_rad(jaw_angle(modes[i], charges[i], timers[i], rests[i])) : 0.0;
        double turn = (jaw_sign == 1 ? jaw : jaw_sign == -1 ? -jaw : 0.0) + offset;
        const Vector2 part_pivot = pivot * (radius / 17.0);
        const Vector2 center = Vector2(t[i * 6 + 4], t[i * 6 + 5]) + (part_pivot - part_pivot.rotated(turn)).rotated(angle);
        const double c = std::cos(angle + turn) * radius, s = std::sin(angle + turn) * radius;
        float pose[6] = {float(c), float(s), float(-s), float(c), center.x, center.y};
        if (d) {
            const Vector2 radial(d[i * 5 + 2], d[i * 5 + 3]);
            if (!(double(radial.length_squared()) < 0.0001)) {
                const Vector2 normal = radial.normalized(), side = normal.orthogonal();
                for (int column = 0; column < 2; ++column) {
                    const Vector2 basis(pose[column * 2], pose[column * 2 + 1]);
                    const Vector2 stretched = normal * basis.dot(normal) * (1.0 - 0.5 * double(d[i * 5 + 4])) + side * basis.dot(side) * (1.0 + 0.6 * double(d[i * 5 + 4]));
                    pose[column * 2] = stretched.x; pose[column * 2 + 1] = stretched.y;
                }
            }
        }
        write_transform(out + count_ * 12, pose, color[i]);
        ++count_;
    }
}
}
