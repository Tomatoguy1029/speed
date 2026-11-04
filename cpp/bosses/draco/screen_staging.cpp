#include "screen_staging.h"
#include "body.h"
#include "pose.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../flow/phase_controller.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
void DracoScreenStaging::side_entry(RunRuntime &r,TechniqueState &t,DracoSideEntryState &s) {auto &e=r.state.enemies[t.actor.slot];s.side=r.state.control.rng.randf()<0.5?-1:1;s.origin=e.pos;s.outside=r.state.view_center+godot::Vector2(s.side*(r.state.view_half.x+e.radius+100),0);s.inside=r.state.view_center+godot::Vector2(s.side*std::min(700.0,double(r.state.view_half.x)*0.72),0);s.angle=e.facing;s.facing=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.angle(e.facing,(DracoTechnique::predict(r,t.actor,0,0)-s.inside).angle());}
void DracoScreenStaging::advance_side(RunRuntime &r,TechniqueState &t,const DracoSideEntryState &s,double progress) {auto &e=r.state.enemies[t.actor.slot];e.pos=progress<0.4?s.origin.lerp(s.outside,DracoTechnique::smooth(progress/0.4)):s.outside.lerp(s.inside,DracoTechnique::smooth((progress-0.4)/0.6));e.facing=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.angle(e.facing,godot::Math::lerp_angle(s.angle,s.facing,DracoTechnique::smooth(progress/0.65)));}
bool DracoScreenStaging::validate_side(const DracoSideEntryState &s) {return s.origin.is_finite() && s.outside.is_finite() && s.inside.is_finite() && std::isfinite(s.angle) && std::isfinite(s.facing) && (s.side==-1 || s.side==1);}
void DracoScreenStaging::begin(RunRuntime &r,TechniqueState &t,DracoStagingState &s,bool enter,double height) {
    const auto &b=*PhaseController::find(r,t.actor);s.enter=enter;s.height=height;s.side=r.state.control.rng.randf()<0.5?-1:1;s.points=DracoPose::samples(DracoPose::points(r,b),DracoBody::rule(r,b).body_segments+1);s.trail=s.points;auto away=s.points.front()-r.state.ship_pos;if (away.length_squared()<1) away=godot::Vector2::from_angle(r.state.enemies[t.actor.slot].facing);s.exit_angle=(s.points[0]-s.points[1]).angle();s.away_angle=away.angle();
}
bool DracoScreenStaging::advance(RunRuntime &r,TechniqueState &t,DracoStagingState &s,double dt) {
    if (s.phase==2) return true;
    auto &v=std::get<DracoTechniqueState>(t.detail);v.stage_time=t.elapsed=0;auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];const auto &p=DracoBody::rule(r,b);
    const auto set_head=[&](godot::Vector2 head) {b.draco.trail=s.trail;b.draco.override_points.clear();e.pos=head;DracoPose::update(r,b);s.trail=b.draco.trail;s.points=b.draco.pose;e.facing=(s.points[0]-s.points[1]).angle();b.draco.override_points=s.points;};
    if (s.phase==1) {s.entry_time+=dt;const double f=DracoTechnique::smooth(s.entry_time/0.42);set_head(s.entry_from.lerp(s.entry_to,f));if (f<1) return false;s.phase=2;b.draco.trail=s.trail;b.draco.override_points.clear();return true;}
    s.exit_time+=dt;const double angle=s.exit_angle+std::remainder(s.away_angle-s.exit_angle,6.283185307179586)*DracoTechnique::smooth(s.exit_time/0.45);const double speed=std::max((p.body_length+r.state.view_half.length()*2+b.draco.width*2)/1.65,double(r.state.ship.vel.length())+1000);set_head(e.pos+godot::Vector2::from_angle(angle)*speed*dt);
    const godot::Rect2 view(r.state.view_center-r.state.view_half,r.state.view_half*2);
    for (size_t j=0;j<s.points.size();++j) {const double fraction=double(j)/std::max(size_t(1),s.points.size()-1);const double radius=j==0?e.radius:b.draco.width*0.5*(1-0.77*std::pow(std::clamp((fraction-0.55)/0.45,0.0,1.0),1.35));if (view.grow(radius).has_point(s.points[j])) return false;}
    e.pos=r.state.view_center+godot::Vector2(s.side*(r.state.view_half.x+e.radius+120),r.state.view_half.y*s.height);s.entry_from=e.pos;s.entry_to=r.state.view_center+godot::Vector2(s.side*std::min(700.0,double(r.state.view_half.x)*0.68),r.state.view_half.y*s.height);e.facing=s.side<0?0:3.141592653589793;s.trail.clear();for (uint32_t j=0;j<=p.body_segments;++j) s.trail.push_back(e.pos+godot::Vector2(s.side*p.body_length*double(j)/p.body_segments,0));s.points=s.trail;s.phase=s.enter?1:2;if (s.enter) b.draco.override_points=s.points;else {b.draco.trail=s.trail;b.draco.override_points.clear();}return !s.enter;
}
bool DracoScreenStaging::validate(const DracoStagingState &s) {if (s.phase>2 || (s.side!=-1 && s.side!=1) || !std::isfinite(s.height) || !std::isfinite(s.exit_angle) || !std::isfinite(s.away_angle) || !std::isfinite(s.exit_time) || s.exit_time<0 || !std::isfinite(s.entry_time) || s.entry_time<0 || !s.entry_from.is_finite() || !s.entry_to.is_finite() || s.points.size()<2 || s.trail.size()<2) return false;for (const auto *v:{&s.points,&s.trail}) for (auto p:*v) if (!p.is_finite()) return false;return true;}
}
