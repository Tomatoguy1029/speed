#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <array>
#include <vector>
#include <unordered_set>
#include <unordered_map>
namespace speed {
// 星座、目印二枠、力をランと一緒に値で保持する。
struct HeroState {
    struct FirePosition {godot::Vector2 position;double remaining=0;};
    struct Hercules {std::vector<FirePosition> falls,burns;double fire_time=0,burn_tick=0;} hercules;
    struct Twin {
        std::vector<godot::Vector2> path;
        godot::Vector2 position;
        std::unordered_map<int64_t,size_t> inside;
        double rate=0,segment_position=0;
        size_t segment=0;
        bool tracing=false;
        // 影が使う機体の武器のうち、影ごとに持つ小さな値（ソニックブームの発射の状態、走らせているミラージュの残像の番号）
        godot::Vector2 sonic_last;
        double sonic_emission=0,sonic_distance=0,sonic_pulse=0,sonic_speed=0;
        bool sonic_active=false;
        std::unordered_set<int64_t> sonic_hits;
        uint64_t afterimage_echo=0;
        // 助走（T32）は突進の最初の命中だけを強めるので、影の最初の命中も影ごとに数える
        bool run_up_first=false;
        // 機体の処理を影として呼んでいる間だけ true（影は被弾しないので、その間の機体への被弾を受けない）。保存しない
        bool acting=false;
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
