#include "dev_scenario.h"
#include "run_runtime.h"
#include "../systems/population_system.h"
#include <cmath>
namespace speed {
bool decode_timeline_scenario(const godot::Dictionary &params,TimelineScenario &out) {
    if (params.size()!=1 || !params.has("time")) return false;
    const godot::Variant value=params["time"];
    if (value.get_type()!=godot::Variant::FLOAT && value.get_type()!=godot::Variant::INT) return false;
    const double time=value;
    if (!std::isfinite(time) || time<0) return false;
    out.time=time;return true;
}
void apply_timeline_scenario(RunRuntime &run,const TimelineScenario &scenario) {
    run.state.time=scenario.time;
    run.state.population.frame_enabled=true;
    PopulationSystem::sync_attack_budget(run);
}
}
