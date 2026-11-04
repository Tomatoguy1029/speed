#include "return_charge.h"
#include "charge.h"
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
void enter(MonocerosReturnState &v,MonocerosReturnState::Stage stage) {v.stage=stage;v.elapsed=0;}
void finish(RunRuntime &r,TechniqueState &t) {t.stage=TechniqueStage::Recovery;t.remaining=rule(r,t).recover;r.state.enemies[t.actor.slot].vel={};}
void launch(RunRuntime &r,TechniqueState &t) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);auto &v=std::get<MonocerosReturnState>(t.detail);
    const double distance=std::max(b.near_clearance,std::min(double(e.pos.distance_to(t.aim)),p.distance));
    if (FieldSystem::first_body_hit(r,e.pos,e.pos+t.direction*distance,e.radius)) {t.stage=TechniqueStage::Failed;t.reposition=b.reposition_time;const auto side=(t.aim-e.pos).normalized().orthogonal();t.reposition_direction=FieldSystem::body_gap(r,e.pos+side*220.0,e.radius)>=FieldSystem::body_gap(r,e.pos-side*220.0,e.radius)?side:-side;e.vel={};return;}
    t.direction=godot::Vector2::from_angle(e.facing);v.travel=std::min(p.distance,double(e.pos.distance_to(r.state.ship_pos))+p.overshoot);v.traveled=0;v.angle=e.facing;v.glow=1;t.hit=false;t.stage=TechniqueStage::Active;enter(v,MonocerosReturnState::Stage::Run);
}
}
bool MonocerosReturn::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;TechniqueState t;t.actor=actor;t.definition=definition;const auto &b=boss(r,t);return r.state.enemies[actor.slot].pos.distance_to(r.state.ship_pos)<=rule(r,t).distance+r.state.enemies[actor.slot].radius*(rule(r,t).phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio);}
void MonocerosReturn::begin(RunRuntime &r,TechniqueState &t) {MonocerosCharge::begin(r,t);MonocerosReturnState v;v.angle=r.state.enemies[t.actor.slot].facing;t.detail=v;}
godot::PackedVector2Array MonocerosReturn::horn(const RunRuntime &r,const TechniqueState &t,bool warning) {const auto &e=r.state.enemies[t.actor.slot];const auto &b=boss(r,t);const auto u=godot::Vector2::from_angle(std::get<MonocerosReturnState>(t.detail).angle);godot::PackedVector2Array out;out.push_back(e.pos+u*e.radius*0.65);out.push_back(e.pos+u*e.radius*(rule(r,t).phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio)+(warning?t.direction*rule(r,t).distance:godot::Vector2()));return out;}
void MonocerosReturn::step(RunRuntime &r,TechniqueState &t,double dt) {
    if (t.stage!=TechniqueStage::Windup && t.stage!=TechniqueStage::Active) {MonocerosCharge::step(r,t,dt);return;}
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);auto &v=std::get<MonocerosReturnState>(t.detail);using Stage=MonocerosReturnState::Stage;const auto prior=horn(r,t);v.elapsed+=dt;
    const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    switch (v.stage) {
    case Stage::Aim:
        MonocerosCharge::step(r,t,dt);if (!t.locked && v.elapsed>=p.warn-b.lock_lead) MonocerosCharge::command(r,t,TechniqueCommand::LockAim);v.angle=e.facing;v.glow=std::clamp(v.elapsed/std::max(p.warn,0.001),0.0,1.0);if (v.elapsed>=p.warn) launch(r,t);break;
    case Stage::Run: {
        v.glow=1;const auto step=t.direction*std::min(p.distance/std::max(p.active,0.001)*dt,std::max(0.0,v.travel-v.traveled));if (!MonocerosCharge::advance(r,t,dt,prior,step)) return;v.traveled+=step.length();
        if (v.traveled>=v.travel) {if (++v.completed>=p.passes) finish(r,t);else {t.locked=false;enter(v,Stage::Brake);}}break;
    }
    case Stage::Brake: {
        v.glow=0;const double k=std::clamp(v.elapsed/std::max(p.brake_time,0.001),0.0,1.0),speed=p.distance/std::max(p.active,0.001)*p.brake_speed_ratio*(1.0-k);const auto from=e.pos;e.pos+=t.direction*speed*dt;e.vel=t.direction*speed;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);v.angle=e.facing;
        if (v.elapsed>=p.brake_time) {v.from_angle=e.facing;v.turn_delta=angle_difference((r.state.ship_pos-e.pos).angle()-v.from_angle);enter(v,Stage::Turn);}break;
    }
    case Stage::Turn: {
        const double target=(r.state.ship_pos-e.pos).angle();double delta=angle_difference(target-v.from_angle);if (std::abs(delta-v.turn_delta)>godot::Math::PI) delta+=(v.turn_delta-delta>0?1:-1)*godot::Math::TAU;v.turn_delta=delta;
        if (!t.locked) {const double q=std::clamp(v.elapsed/std::max(p.turn_time-p.turn_lock,0.001),0.0,1.0);e.facing=tracking.angle(e.facing,v.from_angle+delta*q*q*(3.0-2.0*q));if (!tracking.locked()) v.angle=e.facing+std::clamp(angle_difference(target-e.facing),-p.head_lead,p.head_lead)*std::sin(godot::Math::PI*q);t.aim=tracking.target(e.pos,e.facing,r.state.ship_pos);t.direction=godot::Vector2::from_angle(e.facing);if (v.elapsed>=p.turn_time-p.turn_lock) t.locked=true;}
        if (t.locked) v.angle=e.facing;if (v.elapsed>=p.turn_time) launch(r,t);break;
    }
    }
}
bool MonocerosReturn::validate(const TechniqueState &t) {if (!std::holds_alternative<MonocerosReturnState>(t.detail)) return false;const auto &v=std::get<MonocerosReturnState>(t.detail);for (double x:{v.elapsed,v.glow,v.travel,v.traveled}) if (!std::isfinite(x) || x<0) return false;return v.stage<=MonocerosReturnState::Stage::Turn && v.glow<=1 && std::isfinite(v.angle) && std::isfinite(v.from_angle) && std::isfinite(v.turn_delta);}
}
