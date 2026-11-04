#include "sweep.h"
#include "strike_shape.h"
#include "../flow/phase_controller.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const BossDefinition &boss(const RunRuntime &r,const TechniqueState &t) {return r.content->bosses[rule(r,t).boss-1];}
double length(const RunRuntime &r,const TechniqueState &t) {const auto &b=boss(r,t);return r.state.enemies[t.actor.slot].radius*(rule(r,t).phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio);}
void enter(MonocerosSweepState &v,MonocerosSweepState::Stage stage) {v.stage=stage;v.elapsed=0;}
void move(RunRuntime &r,TechniqueState &t,godot::Vector2 step,double dt) {auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos;e.pos+=step;e.vel=step/dt;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);}
}
bool MonocerosSweep::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;
    TechniqueState t;t.actor=actor;t.definition=definition;const auto &p=rule(r,t);
    const double accelerated=std::min(p.approach_max,std::max(0.0,p.approach_speed_max-p.approach_speed_start)/std::max(p.approach_accel,0.001));
    const double reach=p.approach_speed_start*accelerated+0.5*p.approach_accel*accelerated*accelerated+p.approach_speed_max*std::max(0.0,p.approach_max-accelerated)+length(r,t);
    return r.state.enemies[actor.slot].pos.distance_to(r.state.ship_pos)<=reach;
}
void MonocerosSweep::begin(RunRuntime &r,TechniqueState &t) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=r.state.ship_pos;t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;
    MonocerosSweepState v;v.angle=e.facing;v.speed=rule(r,t).approach_speed_start;if (const auto *body=PhaseController::find(r,t.actor)) v.side=body->sweep_side;t.detail=v;
}
godot::PackedVector2Array MonocerosSweep::horn(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];const auto direction=godot::Vector2::from_angle(std::get<MonocerosSweepState>(t.detail).angle);godot::PackedVector2Array out;out.push_back(e.pos+direction*e.radius*0.65);out.push_back(e.pos+direction*length(r,t));return out;}
void MonocerosSweep::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);auto &v=std::get<MonocerosSweepState>(t.detail);using Stage=MonocerosSweepState::Stage;
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    auto prior=horn(r,t);const double before=v.elapsed;v.elapsed+=dt;
    switch (v.stage) {
    case Stage::Approach: {
        v.speed=std::min(p.approach_speed_max,v.speed+p.approach_accel*dt);
        if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing),-p.approach_turn*dt,p.approach_turn*dt);
        t.direction=godot::Vector2::from_angle(e.facing);move(r,t,t.direction*v.speed*dt,dt);
        const double k=std::clamp(v.elapsed/std::max(p.twist_time,0.001),0.0,1.0);v.angle=e.facing-v.side*p.twist*(1.0-(1.0-k)*(1.0-k));v.glow=k;
        if ((e.pos.distance_to(r.state.ship_pos)<p.stop_range && v.elapsed>p.approach_min) || v.elapsed>p.approach_max) {v.base=e.facing;t.locked=true;enter(v,Stage::Stop);}break;
    }
    case Stage::Stop: {
        const double k=std::clamp(v.elapsed/std::max(p.stop_time,0.001),0.0,1.0);v.speed=std::max(0.0,v.speed-p.stop_decel*dt);move(r,t,godot::Vector2::from_angle(v.base)*v.speed*dt,dt);e.facing=v.base;
        v.angle=v.base-v.side*(p.twist+(p.windup_twist-p.twist)*(1.0-(1.0-k)*(1.0-k)));
        if (v.elapsed>=p.stop_time) {t.stage=TechniqueStage::Active;t.hit=false;e.vel={};enter(v,Stage::Swing);}break;
    }
    case Stage::Swing: {
        const int steps=std::max(1,int(std::ceil(dt/0.008)));
        for (int j=0;j<steps;++j) {const double k=std::clamp((before+dt*double(j+1)/steps)/std::max(p.active,0.001),0.0,1.0);v.angle=v.base+v.side*(-p.windup_twist+p.arc*k*k*(1.6-0.6*k));const auto next=horn(r,t);MonocerosStrike::damage(r,t,prior,next,boss(r,t).horn_width);prior=next;}
        if (v.elapsed>=p.active) enter(v,Stage::Hold);break;
    }
    case Stage::Hold:if (v.elapsed>=p.hold) enter(v,Stage::Return);break;
    case Stage::Return: {
        const double k=std::clamp(v.elapsed/std::max(p.return_time,0.001),0.0,1.0);const double from=v.base+v.side*(-p.windup_twist+p.arc);v.angle=from+(v.base-from)*k*k*(3.0-2.0*k);
        if (v.elapsed>=p.return_time) {if (auto *body=PhaseController::find(r,t.actor)) body->sweep_side=-v.side;t.stage=TechniqueStage::Recovery;t.remaining=p.recover;e.vel={};}break;
    }
    }
}
bool MonocerosSweep::validate(const TechniqueState &t) {
    if (!std::holds_alternative<MonocerosSweepState>(t.detail)) return false;const auto &v=std::get<MonocerosSweepState>(t.detail);
    return v.stage<=MonocerosSweepState::Stage::Return && std::isfinite(v.elapsed) && v.elapsed>=0 && std::isfinite(v.angle) && std::isfinite(v.base) && std::isfinite(v.glow) && v.glow>=0 && v.glow<=1 && std::isfinite(v.speed) && v.speed>=0 && (v.side==1 || v.side==-1);
}
}
