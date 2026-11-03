#include "fullCharge.h"
#include "../../runtime/run_runtime.h"
#include <algorithm>
#include <cmath>
namespace speed {
double FullChargeBehavior::multiplier(const RunRuntime &run,double distance) {
    const double x=std::clamp(distance/run.state.draw_config.length,0.0,1.0);
    return 1.0+(run.state.loadout.full_charge_maximum-1.0)*(std::exp(3.0*x)-1.0)/(std::exp(3.0)-1.0);
}
void FullChargeBehavior::launch(RunRuntime &run) {
    auto &loadout=run.state.loadout;loadout.boost_distance=0;
    if (loadout.full_charge_maximum>1) {loadout.effects.ignore_armor=false;loadout.effects.burst_power=1;}
}
void FullChargeBehavior::prepare(RunRuntime &run,double extra) {
    auto &loadout=run.state.loadout;
    if (loadout.full_charge_maximum>1) loadout.effects.burst_power=run.state.draw.tracing?multiplier(run,loadout.boost_distance+extra):1.0;
}
void FullChargeBehavior::trail(RunRuntime &run,godot::Vector2 from,godot::Vector2 to) {
    auto &loadout=run.state.loadout;loadout.boost_distance+=from.distance_to(to);
    if (loadout.full_charge_maximum>1 && run.state.phase==godot::RunState::Phase::Play) loadout.effects.burst_power=multiplier(run,loadout.boost_distance);
}
void FullChargeBehavior::end(RunRuntime &run) {
    run.state.loadout.effects.burst_power=1;run.state.loadout.effects.ignore_armor=false;
}
}
