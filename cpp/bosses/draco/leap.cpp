#include "leap.h"
#include "screen_staging.h"
#include "body.h"
#include "pose.h"
#include "tail_motion.h"
#include "../flow/phase_controller.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void lock(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoLeapState>(v.move);const auto &b=*PhaseController::find(r,t.actor);const auto &p=r.content->boss_techniques[t.definition-1];const auto &d=*std::find_if(r.content->draco_leaps.begin(),r.content->draco_leaps.end(),[&](const auto &d){return d.technique==t.definition;});t.aim=DracoTechnique::predict(r,t.actor,std::max(0.0,p.warn-v.stage_time)+p.active,d.lead_cap);t.direction=(t.aim-s.origin).normalized();if (t.direction.is_zero_approx()) t.direction={1,0};s.takeoff=s.origin-t.direction*190;s.destination=t.aim-t.direction*105*b.draco->head_scale;v.warning={s.takeoff+t.direction*105*b.draco->head_scale,t.aim};v.warning_width=p.width;}
}
void DracoLeap::begin(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoLeapState{};auto &s=std::get<DracoLeapState>(v.move);DracoScreenStaging::begin(r,t,s.staging,true,-0.3);s.staging.side=r.state.ship_pos.x>r.state.view_center.x?-1:1;s.staging.distance=1000;t.locked=false;}
void DracoLeap::windup(RunRuntime &r,TechniqueState &t,double dt) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoLeapState>(v.move);if (!DracoScreenStaging::advance(r,t,s.staging,dt)) return;auto &e=r.state.enemies[t.actor.slot];auto &b=*PhaseController::find(r,t.actor);const double warn=r.content->boss_techniques[t.definition-1].warn,setup=std::min(0.2,warn*0.3);if (!s.positioned) {s.origin=e.pos;s.positioned=true;s.base=DracoTechnique::neutral(r,b,e.pos,e.facing);}if (!t.locked) {lock(r,t);t.locked=v.stage_time>=setup;}
    // ためで頭を後ろへ引きながら、胴をばねのようにS字へ縮めて止まる。
    const double k=DracoTailMotion::soft(std::clamp(v.stage_time/(warn*0.85),0.0,1.0));const auto head=s.origin.lerp(s.takeoff,k);const auto &p=DracoBody::rule(r,b);b.draco->override_points=DracoTailMotion::wave(s.base,t.direction.angle(),head,p.body_length,0,[k](double u) {return k*1.05*std::sin(u*6.283185307179586*1.15)*(1-0.45*u);});e.pos=head;e.facing=t.direction.angle();}
void DracoLeap::active(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoLeapState>(v.move);auto &b=*PhaseController::find(r,t.actor);if (!b.draco->override_points.empty()) {b.draco->trail=b.draco->override_points;b.draco->override_points.clear();}v.warning.clear();const auto before=DracoTechnique::mouth(r,b);r.state.enemies[t.actor.slot].pos=s.takeoff.lerp(s.destination,DracoTechnique::burst(v.stage_time/r.content->boss_techniques[t.definition-1].active));const auto after=DracoTechnique::mouth(r,b);DracoTechnique::hit_segment(r,t,before,after,r.content->boss_techniques[t.definition-1].width,Cause::Leap);v.attack={before,after};}
void DracoLeap::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &v=t.detail.get<DracoTechniqueState>();v.warning.clear();v.attack.clear();if (r.state.enemy_handles.contains(t.actor)) std::get<DracoLeapState>(v.move).landed=r.state.enemies[t.actor.slot].pos;if (cancelled) if (auto *b=PhaseController::find(r,t.actor)) DracoPose::reset(r,*b);}
void DracoLeap::recover(RunRuntime &r,TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoLeapState>(v.move);r.state.enemies[t.actor.slot].pos=s.landed+t.direction*30*DracoTechnique::smooth(v.stage_time/std::max(0.001,r.content->boss_techniques[t.definition-1].recover));}
bool DracoLeap::validate(const DracoLeapState &s) {for (auto p:s.base) if (!p.is_finite()) return false;return s.origin.is_finite() && s.destination.is_finite() && s.takeoff.is_finite() && s.landed.is_finite() && DracoScreenStaging::validate(s.staging);}
godot::Dictionary DracoLeap::snapshot(const TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoLeapState>(v.move);godot::Dictionary out;godot::PackedVector2Array markers;if (!v.warning.empty()) markers.push_back(t.aim);out["telegraph_points"]=markers;out["telegraph_radius"]=v.warning_width;out["staging_ready"]=s.staging.phase==2;out["staging_phase"]=s.staging.phase;out["exit_time"]=s.staging.exit_time;out["entry_time"]=s.staging.entry_time;out["staging_side"]=s.staging.side;out["origin"]=s.origin;out["destination"]=s.destination;out["takeoff"]=s.takeoff;return out;}
}
