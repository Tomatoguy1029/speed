#include "cycle.h"
#include "body.h"
#include "pose.h"
#include "picaro.h"
#include "cinematic.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const DracoCycleDefinition *rule(const RunRuntime &r,const BossBodyState &b) {const auto boss=r.content->boss_bodies[b.definition-1].boss;const auto it=std::find_if(r.content->draco_cycles.begin(),r.content->draco_cycles.end(),[&](const auto &p){return p.boss==boss;});return it==r.content->draco_cycles.end()?nullptr:&*it;}
double smooth(double x,double duration) {x=std::clamp(x/duration,0.0,1.0);return x*x*(3-2*x);}
void finish(RunRuntime &r,BossBodyState &b) {auto &v=b.draco.cycle;const bool first=v.first;DracoCinematic::restore(r,v.saved);v.stage=DracoCycleStage::None;v.first=false;v.time=0;v.next_cycle=10;DracoPose::reset(r,b);b.mode=BossMode::Idle;r.state.enemies[b.actor.slot].guard=0;if (first) r.state.encounter_protected=false;b.draco.picaro_attacking=false;}
bool alive(const RunRuntime &r,const DracoPicaroMember &m) {return r.state.enemy_handles.contains(m.actor) && !r.state.enemies[m.actor.slot].dead;}
}
bool DracoCycle::begin_initial(RunRuntime &r,BossBodyState &b) {
    if (!rule(r,b)) return false;if (b.draco.cycle.stage!=DracoCycleStage::None) cancel(r,b);auto &v=b.draco.cycle;auto &s=r.state;auto &e=s.enemies[b.actor.slot];DracoCinematic::capture(r,v.saved);v.first=true;v.stage=DracoCycleStage::Roar;v.time=0;v.generated=0;v.home=v.from=e.pos;v.zoom=std::max(0.1,s.control.camera_zoom);DracoPose::reset(r,b);s.control.cinematic_camera=true;s.controls_locked=true;s.control.cinematic_bars=1;s.encounter_protected=true;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};e.guard=1;return true;
}
bool DracoCycle::begin_deep(RunRuntime &r,BossBodyState &b) {
    if (!rule(r,b) || b.draco.cycle.stage!=DracoCycleStage::None) return false;auto &v=b.draco.cycle;v.first=false;v.stage=DracoCycleStage::Collect;v.time=0;v.generated=0;v.home=v.from=r.state.enemies[b.actor.slot].pos;DracoPose::reset(r,b);r.state.enemies[b.actor.slot].guard=1;b.draco.picaro_attacking=true;return true;
}
bool DracoCycle::tick(RunRuntime &r,BossBodyState &b,double dt) {
    const auto *p=rule(r,b);if (!p) return false;auto &v=b.draco.cycle;auto &e=r.state.enemies[b.actor.slot];
    if (v.stage==DracoCycleStage::None) {bool enabled=!r.state.control.lab_mode;for (const auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) enabled=f.selection_enabled;if (enabled && b.phase>=2 && b.mode==BossMode::Idle) {v.next_cycle-=dt;if (v.next_cycle<=0) begin_deep(r,b);}return v.stage!=DracoCycleStage::None;}
    v.time+=dt;e.vel={};if (v.first) DracoCinematic::frame(r,r.state.ship_pos.lerp(e.pos,0.55),v.zoom*0.8);
    switch (v.stage) {
    case DracoCycleStage::Roar:if (v.time>=1) {v.stage=DracoCycleStage::Collect;v.time=0;}break;
    case DracoCycleStage::Collect: {const double depth=smooth(v.time,1.25);e.pos=v.from+godot::Vector2(std::sin(v.time*0.6)*180,-320)*depth;DracoPose::depth(r,b,1-0.72*depth,1-0.7*depth);e.guard=1;const bool any=std::any_of(b.draco.picaro.begin(),b.draco.picaro.end(),[&](const auto &m){return alive(r,m);});if (v.time>=(v.first?2:p->collect_time) || (!v.first && !any && v.time>1.25)) {DracoPicaro::pause(r,b,false);v.stage=DracoCycleStage::WaitBeams;v.time=0;}break;}
    case DracoCycleStage::WaitBeams: {bool busy=false;for (const auto &m:b.draco.picaro) if (alive(r,m)) for (const auto &h:r.state.hazards) if (h.alive) {const auto *attack=AttackSystem::get(r.state,h.attack);if (attack && same_handle(attack->spec.owner.live_source,m.actor)) busy=true;}if (!busy) {v.return_from=e.pos;v.return_depth=b.draco.depth;v.return_alpha=b.draco.alpha;v.return_angle=e.facing;if (!v.first) v.home=r.state.ship_pos+godot::Vector2(500,-150);v.stage=DracoCycleStage::Return;v.time=0;}break;}
    case DracoCycleStage::Return: {const double progress=smooth(v.time,1.2);e.pos=v.return_from.lerp(v.home,progress);const double facing=v.return_angle+angle_difference((r.state.ship_pos-v.home).angle()-v.return_angle)*progress;e.facing=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.angle(e.facing,facing);DracoPose::depth(r,b,v.return_depth+(1-v.return_depth)*progress,v.return_alpha+(1-v.return_alpha)*progress);if (v.time>=1.2) {DracoPose::reset(r,b);e.guard=v.first?1:0;v.stage=DracoCycleStage::Generate;v.time=0;v.generated=0;}break;}
    case DracoCycleStage::Generate:if (v.time>=0.6+v.generated*0.8 && v.generated<p->count) {std::vector<const DracoCycleCandidate *> choices;for (const auto &c:r.content->draco_cycle_candidates) if (c.cycle==p->id) choices.push_back(&c);const auto &chosen=*choices[*r.state.control.rng.randi_range(0,choices.size()-1)];if (!chosen.excluded) DracoPicaro::spawn(r,b,chosen.enemy,v.home+godot::Vector2(150,(double(v.generated)-1)*180));++v.generated;}if (v.time>0.6+p->count*0.8+1) finish(r,b);break;
    case DracoCycleStage::None:break;
    }
    DracoBody::update(r,b);return v.stage!=DracoCycleStage::None;
}
void DracoCycle::cancel(RunRuntime &r,BossBodyState &b) {auto &v=b.draco.cycle;if (v.stage==DracoCycleStage::None && !v.saved.saved) return;const bool first=v.first;DracoCinematic::restore(r,v.saved);if (first) r.state.encounter_protected=false;v.stage=DracoCycleStage::None;v.first=false;v.time=0;v.next_cycle=10;DracoPose::reset(r,b);if (r.state.enemy_handles.contains(b.actor)) {r.state.enemies[b.actor.slot].guard=0;if (b.mode==BossMode::Phase) b.mode=BossMode::Idle;DracoBody::update(r,b);}b.draco.picaro_attacking=false;}
bool DracoCycle::validate(const BossBodyState &b) {const auto &v=b.draco.cycle;for (double x:{v.time,v.next_cycle,v.zoom,v.return_depth,v.return_alpha,v.return_angle,v.saved.zoom,v.saved.bars,v.saved.world_scale}) if (!std::isfinite(x)) return false;for (auto p:{v.home,v.from,v.return_from,v.saved.center,v.saved.half,v.saved.heading}) if (!p.is_finite()) return false;return v.stage<=DracoCycleStage::Generate && v.time>=0 && v.zoom>0 && v.return_depth>=0.1 && v.return_depth<=1 && v.return_alpha>=0 && v.return_alpha<=1 && (!v.first || v.saved.saved);}
void DracoCycle::snapshot(const BossBodyState &b,godot::Dictionary &out) {const auto &v=b.draco.cycle;godot::Dictionary p;p["stage"]=int(v.stage);p["first"]=v.first;p["time"]=v.time;p["next_cycle"]=v.next_cycle;p["home"]=v.home;p["generated"]=v.generated;out["cycle"]=p;}
}
