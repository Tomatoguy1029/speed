#include "rampage.h"
#include "../../output/event_builder.h"
#include "../../runtime/run_runtime.h"
#include "../../state/loadout_state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void refresh(RunRuntime &run) {
    const auto &rampage=run.state.loadout->rampage;
    run.state.loadout->effects.damage_multiplier=1+rampage.bonus*rampage.strength;
}
}
void RampageBehavior::launch(RunRuntime &run) {
    auto &rampage=run.state.loadout->rampage;
    if (!rampage.ready) return;
    rampage.kills=0;rampage.strength=0;refresh(run);
}
void RampageBehavior::kill(RunRuntime &run,const DeathContext &) {
    auto &rampage=run.state.loadout->rampage;
    if (!rampage.ready || !run.state.draw.tracing) return;
    if (rampage.kills<UINT64_MAX) ++rampage.kills;
    rampage.pop=1;
}
void RampageBehavior::end(RunRuntime &run) {
    auto &rampage=run.state.loadout->rampage;
    if (!rampage.ready) return;
    rampage.strength=std::min(1.0,double(rampage.kills)/rampage.target_kills);refresh(run);
    if (rampage.kills>0) EventBuilder::audio(run,"trait.momentum.buff",run.state.ship.pos);
}
void RampageBehavior::step(RunRuntime &run,double dt) {
    auto &rampage=run.state.loadout->rampage;
    if (!rampage.ready || dt<=0) return;
    if (!run.state.draw.tracing) rampage.strength*=std::pow(0.5,dt/rampage.half_life);
    rampage.pop=std::max(0.0,rampage.pop-dt*5.0);refresh(run);
}
}
