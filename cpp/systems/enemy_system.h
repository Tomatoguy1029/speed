#pragma once
#include "../state/run_state.h"
namespace speed {
class RunRuntime;
struct EnemySpawn {
    godot::Vector2 position,velocity;
    double facing=0,size=0,knock=0,value=1,priority=0;
    int64_t group=0,hound_pack=-1;
    bool elite=false,has_value=false,has_priority=false,has_managed=false,managed=false;
    RockHandle rock;
};
class EnemySystem {
public:
    static int64_t spawn_base(RunRuntime &,size_t definition,const EnemySpawn &);
    static bool relocate(RunRuntime &,EnemyHandle,godot::Vector2);
    static bool attack_active(const godot::RunState &,EnemyHandle);
    static bool attack_due(const RunRuntime &,EnemyHandle,double dt);
    static EnemyHandle insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy);
    static bool retire(godot::RunState &state,EnemyHandle enemy,RetireReason reason);
    static void leave_hound(godot::RunState &state,size_t row);
    static void release(godot::RunState &state, uint32_t slot);
};
}
