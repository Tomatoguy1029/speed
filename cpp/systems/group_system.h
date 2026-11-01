#pragma once
#include "../state/run_state.h"
namespace speed {
class GroupSystem {
public:
    static void join(godot::RunState &,EnemyHandle,int64_t group);
    static void leave(godot::RunState &,EnemyHandle);
    static HoundOrder *order(godot::RunState &,EnemyHandle);
    static const HoundOrder *order(const godot::RunState &,EnemyHandle);
    static bool follow(godot::RunState &,EnemyHandle,godot::Vector2,double until,double scale);
    static bool steer(godot::RunState &,EnemyHandle,godot::Vector2,godot::Vector2,double until,const HoundSteering &);
    static bool quiet(godot::RunState &,EnemyHandle,double until,bool has_velocity,godot::Vector2);
    static bool mark(godot::RunState &,EnemyHandle,double until);
    static bool release_order(godot::RunState &,EnemyHandle);
    static bool warning(const godot::RunState &,EnemyHandle);
    static bool validate(const godot::RunState &);
};
}
