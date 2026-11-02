#include "fullBurst.h"
#include "../../runtime/run_runtime.h"
#include "../../output/frame_builder.h"
namespace speed {
void FullBurstBehavior::step(RunRuntime &run) {
    auto &loadout=run.state.loadout;
    if (!loadout.full_burst_owned) return;
    const bool ready=run.state.draw.gauge>=1.0;
    if (ready && !loadout.full_burst_active) {godot::Dictionary event;event["pos"]=run.state.ship.pos;FrameBuilder::append(run,"full_burst_ready",event);}
    loadout.full_burst_active=ready;
}
}
