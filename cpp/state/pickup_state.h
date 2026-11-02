#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <array>
#include <vector>
#include <cstdint>
#include <cstddef>
#include <utility>
namespace speed {
enum class CrystalSource : uint8_t { Direct,Enemy,StrongGold };
struct CrystalOrigin {
    CrystalSource source=CrystalSource::Direct;
    uint32_t definition=0;
    int64_t enemy_id=-1;
    double run_time=0,world_time=0;
};
struct CrystalState {
    godot::Vector2 pos;
    double value=0;
    uint64_t order=0;
    bool alive=false,pulled=false;
    uint8_t kind=0;
    uint64_t id=0;
    CrystalOrigin origin;
    godot::Vector2 velocity;
    double wait=0;
};
struct CoinState {godot::Vector2 pos;bool alive=true,pulled=false;};
enum class CapsuleKind {Heal,Magnet,CometWeapon};
struct CapsuleState {godot::Vector2 pos;double age=0;CapsuleKind kind=CapsuleKind::Heal;uint32_t weapon=0;bool drop=true;};
struct CrystalTotal {uint64_t count=0;double base_xp=0;};
struct PickupState {
    std::vector<CrystalState> gems;
    std::vector<CoinState> coins;
    std::vector<CapsuleState> capsules;
    std::vector<size_t> free_gems,free_coins;
    std::vector<std::pair<size_t,uint64_t>> gem_queue;
    size_t gem_queue_head=0;
    uint64_t next_ground_order=0,gem_absorber_id=0;
    int64_t live_gems=0,gem_absorber=-1;
    double xp_dropped=0;
    uint64_t next_id=1,gold_rolls=0,gold_won=0;
    std::array<CrystalTotal,3> supplied{},collected{},lost{};
};
}
