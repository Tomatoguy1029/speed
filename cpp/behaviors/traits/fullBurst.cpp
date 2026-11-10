#include "fullBurst.h"
#include "../../runtime/run_runtime.h"
#include "../../state/loadout_state.h"
#include <algorithm>
namespace speed {
double FullBurstBehavior::rate(const RunRuntime &run) {
    if (!run.state.draw_ready) return 1.0;
    return 1.0+run.state.loadout->effects.full_gauge_rate*run.state.draw.fuel/run.state.draw_config.fuel_capacity;
}
double FullBurstBehavior::strength(const RunRuntime &run) {
    return run.state.loadout->full_burst_owned?std::min(1.0,run.state.draw.fuel/run.state.draw_config.fuel_capacity):0.0;
}
void FullBurstBehavior::step(RunRuntime &run) {
    run.state.loadout->full_burst_active=run.state.loadout->full_burst_owned && run.state.draw.fuel>=run.state.draw_config.fuel_capacity;
}
}
