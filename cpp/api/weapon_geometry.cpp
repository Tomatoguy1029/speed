#include "weapon_geometry.h"
#include <algorithm>
#include <cmath>
#include <unordered_set>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
namespace {
constexpr double TAU = 6.283185307179586;
constexpr int STRIDE = 12;
Color hex(uint32_t rgb, float alpha = 1) { return Color(((rgb >> 16) & 255) / 255.0f, ((rgb >> 8) & 255) / 255.0f, (rgb & 255) / 255.0f, alpha); }
double mix(double a, double b, double t) { return a + (b - a) * t; }
double hash(double x, double y, double z) { const double s = std::sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return s - std::floor(s); }
double noise(double x, double y, double z) {
    const double xi = std::floor(x), yi = std::floor(y), zi = std::floor(z);
    const auto smooth = [](double f) { return f * f * (3 - 2 * f); };
    const double u = smooth(x - xi), v = smooth(y - yi), w = smooth(z - zi);
    const double a = mix(mix(hash(xi, yi, zi), hash(xi + 1, yi, zi), u), mix(hash(xi, yi + 1, zi), hash(xi + 1, yi + 1, zi), u), v);
    const double b = mix(mix(hash(xi, yi, zi + 1), hash(xi + 1, yi, zi + 1), u), mix(hash(xi, yi + 1, zi + 1), hash(xi + 1, yi + 1, zi + 1), u), v);
    return mix(a, b, w);
}
}
void SpeedWeaponGeometry::_bind_methods() {
    ClassDB::bind_method(D_METHOD("begin", "buffer", "count", "pixel"), &SpeedWeaponGeometry::begin);
    ClassDB::bind_method(D_METHOD("take_buffer"), &SpeedWeaponGeometry::take_buffer);
    ClassDB::bind_method(D_METHOD("get_count"), &SpeedWeaponGeometry::get_count);
    ClassDB::bind_method(D_METHOD("mass_tow_heat", "cell", "count", "clock"), &SpeedWeaponGeometry::mass_tow_heat);
    ClassDB::bind_method(D_METHOD("mass_tow_chains", "cargo", "ship_pos", "heading", "count", "clock"), &SpeedWeaponGeometry::mass_tow_chains);
    ClassDB::bind_method(D_METHOD("mass_tow_hulls", "shots"), &SpeedWeaponGeometry::mass_tow_hulls);
    ClassDB::bind_method(D_METHOD("knockback", "breaks", "hits", "clock"), &SpeedWeaponGeometry::knockback);
    ClassDB::bind_method(D_METHOD("end_blast_arc", "origin", "path", "strength"), &SpeedWeaponGeometry::end_blast_arc);
}
void SpeedWeaponGeometry::begin(PackedFloat32Array buffer, int count, double pixel) { buffer_ = buffer; count_ = count; px_ = pixel; data_ = nullptr; }
PackedFloat32Array SpeedWeaponGeometry::take_buffer() { PackedFloat32Array result = buffer_; buffer_ = PackedFloat32Array(); data_ = nullptr; return result; }
void SpeedWeaponGeometry::fill(double x, double y, Color color, int w, int h) {
    if (color.a <= 0) return;
    const int need = (count_ + 1) * STRIDE;
    if (buffer_.size() < need) { buffer_.resize(std::max(need, int(buffer_.size()) * 2)); data_ = nullptr; }
    if (!data_) data_ = buffer_.ptrw();
    float *q = data_ + count_ * STRIDE;
    q[0] = w * px_ * 0.5; q[1] = 0; q[2] = 0; q[3] = (std::round(x) + w * 0.5) * px_;
    q[4] = 0; q[5] = h * px_ * 0.5; q[6] = 0; q[7] = (std::round(y) + h * 0.5) * px_;
    q[8] = color.r; q[9] = color.g; q[10] = color.b; q[11] = color.a; ++count_;
}
void SpeedWeaponGeometry::dot(Vector2 p, Color color, int size) { const Vector2 c = p / px_; fill(c.x, c.y, color, size, size); }
void SpeedWeaponGeometry::disk(Vector2 p, double r, Color color) {
    if (r <= 0) return;
    const Vector2 c = p / px_; const int big = int(std::ceil(r));
    for (int y = -big; y <= big; ++y) { const int w = int(std::floor(std::sqrt(std::max(0.0, r * r - y * y)))); fill(double(c.x) - w, double(c.y) + y, color, w * 2 + 1, 1); }
}
void SpeedWeaponGeometry::ring(Vector2 p, double r, Color color) {
    if (r <= 0) return;
    const Vector2 c = p / px_; const int n = int(std::ceil(r * 8));
    std::unordered_set<uint64_t> seen;
    for (int i = 0; i < n; ++i) {
        const double a = double(i) / n * TAU;
        const int x = int(std::round(c.x + std::cos(a) * r)), y = int(std::round(c.y + std::sin(a) * r));
        const uint64_t key = (uint64_t(uint32_t(x)) << 32) | uint32_t(y);
        if (seen.insert(key).second) fill(x, y, color);
    }
}
void SpeedWeaponGeometry::thick_ring(Vector2 p, double r, int width, Color color) {
    if (r <= 0) return;
    const Vector2 c = p / px_; const int n = std::max(16, int(std::ceil(r * 7)));
    for (int i = 0; i < n; ++i) { const double a = double(i) / n * TAU; for (int k = 0; k < width; ++k) fill(c.x + std::cos(a) * (r - k), c.y + std::sin(a) * (r - k), color); }
}
void SpeedWeaponGeometry::line(Vector2 a, Vector2 b, Color color) {
    const Vector2 ca = a / px_, cb = b / px_;
    // GDScript の Vector2成分を取り出した後の演算は倍精度。
    const double dx = double(cb.x) - ca.x, dy = double(cb.y) - ca.y;
    const int n = std::max(1, int(std::ceil(std::max(std::abs(dx), std::abs(dy)))));
    for (int i = 0; i <= n; ++i) { const double k = double(i) / n; fill(ca.x + dx * k, ca.y + dy * k, color); }
}
void SpeedWeaponGeometry::mass_tow_heat(Vector2 c, int count, double clock) {
    const double radius = 4 + 3 * std::sqrt(double(count)); const int big = int(std::ceil(radius)), flicker = int(clock * 10);
    const Color inner = hex(0xffbe65, 0.55f), outer = hex(0xc86a1e, 0.4f);
    for (int y = -big; y <= big; ++y) for (int x = -big; x <= big; ++x) {
        const double d = std::sqrt(double(x * x + y * y)) / radius;
        if (d > 1) continue;
        const double nz = noise((double(c.x) + x) * 0.25, (double(c.y) + y) * 0.25, clock * 3);
        if (d + 0.35 * (nz - 0.5) > 0.85 || (((x + y + flicker) & 1) && d > 0.45)) continue;
        fill(double(c.x) + x, double(c.y) + y, d < 0.45 ? inner : outer);
    }
}
void SpeedWeaponGeometry::mass_tow_chains(Array cargo, Vector2 ship_pos, Vector2 heading, int count, double clock) {
    if (cargo.is_empty()) return;
    const Dictionary first = cargo[0];
    const Color link = bool(first["ready"]) ? hex(0xfff2c0) : hex(0xffbe65);
    Color faded = link; faded.a = 0.35f;
    for (int j = 0; j < count; ++j) {
        const Dictionary item = cargo[j]; const Vector2 hull = item["pos"];
        Vector2 near = ship_pos - heading * 12.0 * px_; double near_r = 0;
        for (int i = 0; i < j; ++i) {
            const Dictionary other_item = cargo[i]; const Vector2 other = other_item["pos"];
            if (other.distance_squared_to(hull) < near.distance_squared_to(hull)) { near = other; near_r = double(other_item["r"]) * 0.7; }
        }
        const Vector2 dir = (hull - near).normalized();
        const Vector2 a = near + dir * near_r, b = hull - dir * double(item["r"]) * 0.7;
        const double cells = double(a.distance_to(b)) / px_;
        if (cells < 1) continue;
        line(a, b, faded);
        double shift = std::fmod(clock * 12 + j * 1.7, 4.0); if (shift < 0) shift += 4;
        for (double k = shift; k < cells; k += 4) dot(b.lerp(a, k / cells), link, 2);
    }
}
void SpeedWeaponGeometry::mass_tow_hulls(Array shots) {
    for (int i = 0; i < shots.size(); ++i) {
        const Dictionary shot = shots[i]; const Vector2 pos = shot["pos"]; const double cells = double(shot["r"]) / px_, hot = shot["age"];
        const Color heat = hot < 0.08 ? Color(1, 1, 1, 0.85f) : hot < 0.18 ? hex(0xffd27a, 0.75f) : hex(0xff9a3c, 0.55f);
        const Vector2 c = (pos / px_).round(); const int big = int(std::ceil(cells));
        for (int y = -big; y <= big; ++y) for (int x = -big; x <= big; ++x) {
            if (x * x + y * y > cells * cells || (hot >= 0.18 && ((int(c.x) + x + int(c.y) + y) & 1))) continue;
            fill(double(c.x) + x, double(c.y) + y, heat);
        }
        ring(pos, cells + (hot < 0.18 ? 1 : 0), hot < 0.18 ? Color(1, 1, 1) : hex(0xffd27a));
    }
}
void SpeedWeaponGeometry::knockback(Array breaks, Array hits, double clock) {
    for (int i = 0; i < breaks.size(); ++i) {
        const Dictionary b = breaks[i]; const double age = b["age"]; const Vector2 pos = b["pos"];
        if (age < 0.05) disk(pos, 10, Color(1, 1, 1));
        else if (age < 0.22) { const double q = (age - 0.05) / 0.17; thick_ring(pos, 8 + 26 * q, q < 0.5 ? 2 : 1, q < 0.5 ? Color(1, 1, 1) : hex(0xe8dcff)); }
        if (age < 0.8) {
            const double k = age / 0.8; const int phase = int(clock * 30); const Array glitter = b["glitter"];
            for (int j = 0; j < glitter.size(); ++j) {
                const Dictionary g = glitter[j]; const double v = g["v"], a = g["a"];
                if ((int(v) + phase) % 4 == 0 && k > 0.5) continue;
                const double d = v * (1 - std::pow(1 - k, 2.0));
                dot(pos + Vector2::from_angle(a) * d * px_, k < 0.4 ? Color(1, 1, 1) : hex(0xfff2c8));
            }
        }
    }
    for (int i = 0; i < hits.size(); ++i) {
        const Dictionary h = hits[i]; const double q = double(h["age"]) / 0.3, turn = h["turn"]; const Vector2 pos = h["pos"];
        if (q >= 1) continue;
        if (q < 0.25) disk(pos, 4, Color(1, 1, 1));
        for (int j = 0; j < 6; ++j) dot(pos + Vector2::from_angle(j / 6.0 * TAU + turn) * (3 + 10 * q) * px_, q < 0.5 ? hex(0xfff6d8) : hex(0xc9b4ff));
    }
}
void SpeedWeaponGeometry::dither_dot(Vector2 origin, Vector2 at, Color color, double alpha) {
    if (alpha <= 0) return;
    const double x = std::floor(double(origin.x) + at.x), y = std::floor(double(origin.y) + at.y);
    constexpr int bayer[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
    if (alpha < 1 && alpha <= (bayer[(int(y) & 3) * 4 + (int(x) & 3)] + 0.5) / 16.0) return;
    fill(x, y, color);
}
void SpeedWeaponGeometry::dither_line(Vector2 origin, Vector2 a, Vector2 b, Color color, double alpha) {
    const double dx = double(b.x) - a.x, dy = double(b.y) - a.y;
    const int n = std::max(1, int(std::ceil(std::max(std::abs(dx), std::abs(dy)))));
    for (int i = 0; i <= n; ++i) dither_dot(origin, a.lerp(b, double(i) / n), color, alpha);
}
void SpeedWeaponGeometry::end_blast_arc(Vector2 origin, PackedVector2Array path, double strength) {
    if (strength <= 0.05) return;
    for (int i = 1; i < path.size(); ++i) {
        dither_line(origin, path[i - 1] + Vector2(1, 0), path[i] + Vector2(1, 0), hex(0xb070ff), strength * 0.8);
        dither_line(origin, path[i - 1], path[i], i < path.size() * 0.6 ? Color(1, 1, 1) : hex(0xe6d2ff), std::min(1.0, strength * 1.4));
    }
}

}
