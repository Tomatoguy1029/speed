#pragma once
#include "fire_field.h"
#include <cstdint>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>

namespace speed {
struct CanisFireDeposit {
    godot::Vector2 position;
    double updated=0;
    uint32_t seed=0;
    std::vector<godot::Vector2> pixels;
};
struct CanisFireHistory {
    godot::Vector2 origin;
    double angle=0,started=0,cell=0;
    std::unordered_set<uint64_t> footprint;
    std::unordered_map<uint64_t,size_t> deposit_cells;
    std::vector<CanisFireDeposit> deposits;
    // 同じ論理画素のworld上の位置を記録し、45 world単位の元の粒へまとめる。
    void stamp(const std::vector<CanisFirePixel> &,godot::Vector2 view_origin,double world_scale,double clock);
};
}
