#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <vector>
#include <cstdint>
namespace speed {
struct EncounterPatternData {
    struct Region {uint32_t enemy=0,min_count=1,max_count=1;godot::Vector2 position;double angle=0,jitter=0;bool fodder=false,elite=false;};
    uint32_t attempts=8,min_fodder=0;
    double margin=20,window=0,draw_seconds=0.5,exit_clearance=0,rotation=3.141592653589793,scale_min=0.8,scale_max=1,min_spacing=0;
    std::vector<godot::Vector2> route;
    std::vector<Region> regions;
};
}
