#pragma once
#include "../../state/run_state.h"
namespace speed {
class RunRuntime;
class ForwardBehavior {
public:
    static void step(RunRuntime &,double dt);
    static bool advance(godot::RunState::ForwardWeapon &state,double dt,bool busy);
    static void set_interval(godot::RunState::ForwardWeapon &state,double interval);
};
}
