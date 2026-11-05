#include "tail_slam.h"
#include "body.h"
#include "pose.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/zone.h"
#include "../../systems/attacks/wave.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const DracoTailSlamDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_tail_slams.begin(),r.content->draco_tail_slams.end(),[&](const auto &d){return d.technique==t.definition;});}
std::vector<godot::Vector2> pose(const RunRuntime &r,const TechniqueState &t,godot::Vector2 tip) {
    const auto &s=std::get<DracoTailSlamState>(t.detail.get<DracoTechniqueState>().move);const auto &b=*PhaseController::find(r,t.actor);const auto &p=DracoBody::rule(r,b);const auto backward=-godot::Vector2::from_angle(r.state.enemies[t.actor.slot].facing),side=backward.orthogonal();const auto c1=s.origin+backward*p.body_length*0.7,c2=tip+backward*220+side*p.body_length*0.35;std::vector<godot::Vector2> points;
    for (uint32_t j=0;j<=p.body_segments;++j) {const double f=double(j)/p.body_segments;points.push_back(s.origin*(1-f)*(1-f)*(1-f)+c1*3*(1-f)*(1-f)*f+c2*3*(1-f)*f*f+tip*f*f*f);}return DracoTechnique::fit(points,s.base,true);
}
void target(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoTailSlamState>(v.move);const auto &p=r.content->boss_techniques[t.definition-1];const auto &d=rule(r,t);s.target=DracoTechnique::predict(r,t.actor,std::max(0.0,p.warn-v.stage_time)+p.active*0.65,d.lead_cap);const auto delta=s.target-s.origin;if (delta.length()>p.reach) s.target=s.origin+delta.normalized()*p.reach;s.lifted=pose(r,t,s.target+godot::Vector2(0,-180));std::vector<godot::Vector2> ring;for (int j=0;j<49;++j) ring.push_back(s.target+godot::Vector2::from_angle(j*6.283185307179586/48)*d.radius);v.warning_paths={std::move(ring)};v.warning_width=3;}
}
void DracoTailSlam::begin(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoTailSlamState{};auto &s=std::get<DracoTailSlamState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &e=r.state.enemies[t.actor.slot];s.origin=e.pos;s.base=DracoTechnique::neutral(r,b,e.pos,e.facing);target(r,t);}
void DracoTailSlam::windup(RunRuntime &r,TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoTailSlamState>(v.move);const double warn=r.content->boss_techniques[t.definition-1].warn;if (!t.locked) {target(r,t);t.locked=v.stage_time>=std::min(0.25,warn*0.35);}DracoTechnique::blend(r,*PhaseController::find(r,t.actor),s.base,s.lifted,v.stage_time/std::max(0.001,warn));}
void DracoTailSlam::active(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoTailSlamState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &p=r.content->boss_techniques[t.definition-1];const auto &d=rule(r,t);v.warning_paths.clear();const double drop=DracoTechnique::smooth(v.stage_time/(p.active*0.65));b.draco->override_points=pose(r,t,(s.target+godot::Vector2(0,-180)).lerp(s.target,drop));if (s.fired || drop<1) return;s.fired=true;const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    ZoneParams zone;zone.position=s.target;zone.radius=d.radius;zone.damage=p.damage*r.state.combat_config.atk_scale;zone.owner=t.actor;zone.technique=ticket;ZoneSystem::emit(r,zone);
    WaveParams wave;wave.position=s.target;wave.arc=3.141592653589793;wave.radius=d.radius*1.6;wave.speed=330;wave.width=18;wave.damage=p.damage*0.5*r.state.combat_config.atk_scale;wave.owner=t.actor;wave.technique=ticket;WaveSystem::emit(r,wave);
    b.draco->impacts.push_back({s.target,b.clock,d.radius,t.definition});if (b.draco->impacts.size()>32) b.draco->impacts.erase(b.draco->impacts.begin());
}
void DracoTailSlam::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &v=t.detail.get<DracoTechniqueState>();v.warning_paths.clear();v.attack.clear();auto *b=PhaseController::find(r,t.actor);if (!b) return;std::get<DracoTailSlamState>(v.move).last=b->draco->override_points;if (cancelled) DracoPose::reset(r,*b);}
void DracoTailSlam::recover(RunRuntime &r,TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoTailSlamState>(v.move);if (s.last.empty()) return;auto &b=*PhaseController::find(r,t.actor);DracoTechnique::blend(r,b,s.last,DracoTechnique::neutral(r,b,s.origin,r.state.enemies[t.actor.slot].facing),v.stage_time/std::max(0.001,r.content->boss_techniques[t.definition-1].recover));}
bool DracoTailSlam::validate(const DracoTailSlamState &s) {if (!s.origin.is_finite() || !s.target.is_finite() || s.base.size()<2 || s.lifted.size()!=s.base.size()) return false;for (const auto *v:{&s.base,&s.lifted,&s.last}) for (auto p:*v) if (!p.is_finite()) return false;return true;}
godot::Dictionary DracoTailSlam::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoTailSlamState>(v.move);godot::Dictionary out;godot::PackedVector2Array markers;if (!v.warning_paths.empty()) markers.push_back(s.target);out["telegraph_points"]=markers;out["telegraph_radius"]=rule(r,t).radius;out["target"]=s.target;out["fired"]=s.fired;return out;}
}
