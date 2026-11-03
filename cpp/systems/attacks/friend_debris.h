#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct DebrisBurstParams {godot::Vector2 position;int64_t count=0,source_id=-1,armor_count=-1;double speed=0,damage=0;godot::Color color;};
struct DebrisScatterParams {EnemyHandle source;godot::Vector2 direction;double speed=0,damage=0,knock=-1,radius_mult=1,life_mult=1;int32_t shatter_depth=1;};
struct DebrisFlingParams {EnemyHandle source;godot::Vector2 velocity;double damage=0,radius_mult=1,knock_mult=1,life_mult=1;};
class FriendDebrisSystem {
public:
    static AttackHandle emit(RunRuntime &,godot::RunState::Friendly,int64_t source_id=-1);
    static bool burst(RunRuntime &,const DebrisBurstParams &);
    static bool scatter(RunRuntime &,const DebrisScatterParams &);
    static bool fling(RunRuntime &,const DebrisFlingParams &);
    static void advance(const RunRuntime &,godot::RunState::Friendly &,godot::Vector2);
    static void finish(RunRuntime &,const godot::RunState::Friendly &);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &,double alpha=1.0);
    static void development_death(RunRuntime &,const DeathContext &);
};
}
