#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct MonocerosSweepPoint {godot::Vector2 center,tip;double progress=0,time=0;};
struct MonocerosSweepMote {godot::Vector2 position,velocity;double life=0,maximum=0;uint32_t color=0;};
struct MonocerosSweepVisual {
    int64_t technique_id=0;double started=0,last_clock=0,start_angle=0,last_angle=0,arc=0,duration=0;
    int32_t side=1;uint32_t random=2;bool finished=false;
    std::vector<MonocerosSweepPoint> points;std::vector<MonocerosSweepMote> motes;
};
}
