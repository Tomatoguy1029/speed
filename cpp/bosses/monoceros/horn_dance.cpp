#include "horn_dance.h"
#include "charge.h"
#include "../flow/phase_controller.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const BossDefinition &boss(const RunRuntime &r,const TechniqueState &t) {return r.content->bosses[rule(r,t).boss-1];}
void enter(MonocerosDanceState &v,MonocerosDanceState::Stage stage) {v.stage=stage;v.elapsed=0;}
void move(RunRuntime &r,TechniqueState &t,godot::Vector2 velocity,double dt) {auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos;e.pos+=velocity*dt;e.vel=velocity;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);}
void end(TechniqueState &t) {auto &v=std::get<MonocerosDanceState>(t.detail);v.speed=v.run_speed;enter(v,MonocerosDanceState::Stage::End);}
void launch(RunRuntime &r,TechniqueState &t,double speed,bool circle) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);auto &v=std::get<MonocerosDanceState>(t.detail);
    const double distance=std::max(b.near_clearance,double(e.pos.distance_to(t.aim)));const auto direction=godot::Vector2::from_angle(e.facing);
    if (FieldSystem::first_body_hit(r,e.pos,e.pos+direction*distance,e.radius)) {t.stage=TechniqueStage::Failed;t.reposition=b.reposition_time;const auto side=(t.aim-e.pos).normalized().orthogonal();t.reposition_direction=FieldSystem::body_gap(r,e.pos+side*220.0,e.radius)>=FieldSystem::body_gap(r,e.pos-side*220.0,e.radius)?side:-side;e.vel={};return;}
    if (circle) e.facing=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.angle(e.facing,(r.state.ship_pos-e.pos).angle());
    t.direction=godot::Vector2::from_angle(e.facing);v.travel=std::max(p.min_run,double(e.pos.distance_to(r.state.ship_pos))+p.overshoot);v.traveled=0;v.run_speed=speed;t.hit=false;v.angle=e.facing;v.glow=1;t.stage=TechniqueStage::Active;enter(v,MonocerosDanceState::Stage::Run);
}
}
bool MonocerosDance::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void MonocerosDance::begin(RunRuntime &r,TechniqueState &t) {if (auto *body=PhaseController::find(r,t.actor)) body->monoceros_burns.clear();auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*boss(r,t).lock_lead);t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;MonocerosDanceState v;v.angle=e.facing;t.detail=v;}
godot::PackedVector2Array MonocerosDance::horn(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];const auto &b=boss(r,t);const auto u=godot::Vector2::from_angle(std::get<MonocerosDanceState>(t.detail).angle);godot::PackedVector2Array out;out.push_back(e.pos+u*e.radius*0.65);out.push_back(e.pos+u*e.radius*(rule(r,t).phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio));return out;}
void MonocerosDance::step(RunRuntime &r,TechniqueState &t,double dt) {
    if (t.stage!=TechniqueStage::Windup && t.stage!=TechniqueStage::Active) {MonocerosCharge::step(r,t,dt);return;}
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);auto &v=std::get<MonocerosDanceState>(t.detail);using Stage=MonocerosDanceState::Stage;const auto prior=horn(r,t);v.elapsed+=dt;const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    switch (v.stage) {
    case Stage::Aim:if (!t.locked) {e.facing=tracking.angle(e.facing,e.facing+std::clamp(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing),-p.aim_turn*dt,p.aim_turn*dt));t.aim=tracking.target(e.pos,e.facing,r.state.ship_pos);if (v.elapsed>=p.warn-p.aim_lock) t.locked=true;}v.angle=e.facing;v.glow=std::clamp(v.elapsed/std::max(p.warn,0.001),0.0,1.0);if (v.elapsed>=p.warn) launch(r,t,p.speed,false);break;
    case Stage::Run: {v.glow=1;const auto step=t.direction*std::min(v.run_speed*dt,std::max(0.0,v.travel-v.traveled));if (!MonocerosCharge::advance(r,t,dt,prior,step,false)) {if (t.stage!=TechniqueStage::Stuck) end(t);return;}v.traveled+=step.length();if (v.traveled>=v.travel) {if (++v.completed>=p.passes) end(t);else {v.heading=e.facing;v.speed=v.run_speed;enter(v,Stage::Circle);}}break;}
    case Stage::Circle: {v.heading-=p.circle_turn*dt;const double target_speed=v.elapsed>p.circle_late_time?p.circle_speed_late:p.circle_speed;v.speed+=std::clamp(target_speed-v.speed,-p.circle_decel*dt,p.circle_accel*dt);move(r,t,godot::Vector2::from_angle(v.heading)*v.speed,dt);e.facing=v.heading;const auto target=r.state.ship_pos-e.pos;const double off=angle_difference(target.angle()-v.heading);if (!tracking.locked()) v.angle=v.heading+std::clamp(off,-p.head_lead,p.head_lead);v.glow=std::max(0.0,1.0-std::abs(off)/std::max(p.glow_angle,0.001));if (std::abs(off)<p.align_angle && target.length()>p.align_min_distance && v.elapsed>p.align_min_time) {t.aim=tracking.target(e.pos,e.facing,r.state.ship_pos);launch(r,t,std::max(p.speed,v.speed),true);}else if (v.elapsed>p.circle_max_time) end(t);break;}
    case Stage::End:v.speed*=std::exp(-p.end_decay*dt);move(r,t,t.direction*v.speed,dt);v.angle=e.facing;v.glow=0.6*std::min(1.0,v.elapsed/0.3);if (v.elapsed>=p.end_time) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;e.vel={};}break;
    }
    if (v.stage==Stage::Run || v.stage==Stage::Circle) if (auto *body=PhaseController::find(r,t.actor)) if (body->monoceros_burns.empty() || body->monoceros_burns.back().position.distance_to(e.pos)>14.0) body->monoceros_burns.push_back({e.pos,body->clock});
}
bool MonocerosDance::validate(const TechniqueState &t) {if (!std::holds_alternative<MonocerosDanceState>(t.detail)) return false;const auto &v=std::get<MonocerosDanceState>(t.detail);for (double x:{v.elapsed,v.glow,v.run_speed,v.travel,v.traveled,v.speed}) if (!std::isfinite(x) || x<0) return false;return v.stage<=MonocerosDanceState::Stage::End && v.glow<=1 && std::isfinite(v.angle) && std::isfinite(v.heading);}
}
