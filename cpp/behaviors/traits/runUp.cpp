#include "runUp.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attacks/zone.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include <algorithm>
#include <cmath>
namespace speed {
void RunUpBehavior::step(RunRuntime &run,double dt) {auto &r=run.state.loadout->run_up;for (auto &hit:r.hits) hit.age+=dt;r.hits.erase(std::remove_if(r.hits.begin(),r.hits.end(),[](const auto &h){return h.age>=0.4;}),r.hits.end());}
void RunUpBehavior::launch(RunRuntime &run) {auto &r=run.state.loadout->run_up;r.first=true;r.strength=0;}
double RunUpBehavior::multiplier(RunRuntime &run,double extra) {
    auto &r=run.state.loadout->run_up;if (!r.ready || !r.first || !run.state.draw.tracing) return 1;
    const double x=std::clamp((run.state.loadout->boost_distance+extra)/r.distance,0.0,1.0);
    r.strength=(std::exp(3*x)-1)/(std::exp(3.0)-1);return 1+(r.multiplier-1)*r.strength;
}
void RunUpBehavior::contact(RunRuntime &run,godot::Vector2 pos,godot::Vector2 direction,double applied) {
    auto &r=run.state.loadout->run_up;if (!r.ready || !r.first || !run.state.draw.tracing) return;
    r.first=false;r.hits.push_back({pos,direction,0,r.next_visual++});const double radius=r.radius*r.strength*run.state.loadout->effects.area;
    if (radius>0) ZoneSystem::explode(run,pos,radius,applied*r.area_damage,Cause::RunUp,0,0.2);
    godot::Dictionary event;event["pos"]=pos;event["dir"]=direction;event["strength"]=r.strength;FrameBuilder::append(run,"run_up_hit",event);
}
}
