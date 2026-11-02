#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <array>
#include <vector>
#include <unordered_set>
namespace speed {
// 星座、目印二枠、力をランと一緒に値で保持する。
struct HeroState {
    struct Twin {
        std::vector<godot::Vector2> first,path;
        godot::Vector2 position;
        std::unordered_set<int64_t> inside;
        double rate=0,segment_position=0;
        size_t segment=0;
        bool tracing=false;
    } twin;
    uint32_t hero=0,power=0;
    godot::Vector2 center,previous;
    std::vector<godot::Vector2> stars,landmarks;
    std::vector<uint8_t> lit;
    std::array<double,2> landmark_times{};
    std::array<EnemyHandle,2> carriers{};
    std::array<int64_t,2> carrier_ids{};
    std::array<bool,2> done{};
    double boss_stun=0;
    double cooldown=0,active=0,next=-1;
    int64_t last_dash=-1,last_star=-1;
    bool guarded=false,seen=false,announced=false;
};
}
