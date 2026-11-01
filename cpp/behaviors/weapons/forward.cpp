#include "forward.h"
#include "../../systems/timing.h"
namespace speed {
bool ForwardBehavior::advance(godot::RunState::ForwardWeapon &state,double dt,bool busy) {
    state.recoil=remaining_time(state.recoil,dt);
    if (busy) return false;
    state.fire.advance(dt);
    if (!state.fire.due()) return false;
    state.fire.fired(state.interval);state.fire.skip_missed(state.interval);return true;
}
void ForwardBehavior::set_interval(godot::RunState::ForwardWeapon &state,double interval) {
    state.fire.remaining+=interval-state.interval;state.interval=interval;
}
}
