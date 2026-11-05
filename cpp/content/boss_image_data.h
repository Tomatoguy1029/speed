#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/rect2i.hpp>
#include <godot_cpp/variant/transform2d.hpp>
namespace speed {
struct BossImageMask {
    uint32_t id=0,width=0,height=0;
    std::vector<uint8_t> bits;
};
struct BossImagePart {
    uint32_t part=0,mask=0;
    godot::Rect2i region;
    godot::Transform2D pixel_to_world;
    bool visible=true;
};
}
