#include "lance.h"
#include "strike_shape.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const BossDefinition &boss(const RunRuntime &r,const TechniqueState &t) {return r.content->bosses[rule(r,t).boss-1];}
double length(const RunRuntime &r,const TechniqueState &t) {const auto &b=boss(r,t);return r.state.enemies[t.actor.slot].radius*(rule(r,t).phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio);}
void enter(MonocerosLanceState &v,MonocerosLanceState::Stage stage) {v.stage=stage;v.elapsed=0;}
void move(RunRuntime &r,TechniqueState &t,godot::Vector2 step,double dt) {auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos;e.pos+=step;e.vel=step/dt;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {godot::Dictionary p;p["pos"]=r.state.enemies[t.actor.slot].pos+(std::string(name)=="sonic_boom"?t.direction*rule(r,t).boom_ahead:godot::Vector2());p["direction"]=t.direction;p["horn"]=MonocerosLance::horn(r,t);p["head_length"]=rule(r,t).head_length;FrameBuilder::append(r,name,p);}
}
bool MonocerosLance::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;TechniqueState t;t.actor=actor;t.definition=definition;return r.state.enemies[actor.slot].pos.distance_to(r.state.ship_pos)<=rule(r,t).distance+length(r,t)+rule(r,t).head_length;}
void MonocerosLance::begin(RunRuntime &r,TechniqueState &t) {auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=r.state.ship_pos;t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;t.detail=MonocerosLanceState{};}
godot::PackedVector2Array MonocerosLance::horn(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];const auto u=godot::Vector2::from_angle(e.facing);godot::PackedVector2Array out;out.push_back(e.pos+u*e.radius*0.65);out.push_back(e.pos+u*(length(r,t)+rule(r,t).head_length*std::get<MonocerosLanceState>(t.detail).form));return out;}
void MonocerosLance::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);auto &v=std::get<MonocerosLanceState>(t.detail);using Stage=MonocerosLanceState::Stage;
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    const auto prior=horn(r,t);v.elapsed+=dt;
    switch (v.stage) {
    case Stage::Gather: {
        if (!t.locked) {if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) {e.facing+=std::clamp(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing),-p.aim_turn*dt,p.aim_turn*dt);t.aim=r.state.ship_pos;}if (v.elapsed>=p.warn-p.lock_time) t.locked=true;}
        t.direction=godot::Vector2::from_angle(e.facing);move(r,t,-t.direction*p.back_speed*dt,dt);const double k=std::clamp(v.elapsed/std::max(p.warn,0.001),0.0,1.0);v.form=1.0-(1.0-k)*(1.0-k);v.glow=v.form;
        if (v.elapsed>=p.warn) {
            const double distance=std::max(b.near_clearance,std::min(double(e.pos.distance_to(t.aim)),p.distance));
            if (FieldSystem::first_body_hit(r,e.pos,e.pos+t.direction*distance,e.radius)) {t.stage=TechniqueStage::Failed;t.reposition=b.reposition_time;const auto side=(t.aim-e.pos).normalized().orthogonal();t.reposition_direction=FieldSystem::body_gap(r,e.pos+side*220.0,e.radius)>=FieldSystem::body_gap(r,e.pos-side*220.0,e.radius)?side:-side;e.vel={};return;}
            t.stage=TechniqueStage::Active;t.hit=false;v.form=1;enter(v,Stage::Run);cue(r,t,"lance_launch");
        }break;
    }
    case Stage::Run: {
        v.form=1;const auto from=e.pos,step=t.direction*std::min(p.speed*dt,std::max(0.0,p.distance-v.traveled));const auto hit=FieldSystem::first_body_hit(r,from,from+step,e.radius);e.pos=hit?from.lerp(from+step,hit->t):from+step;e.vel=step/dt;MonocerosStrike::damage(r,t,prior,horn(r,t),p.width);
        if (hit) {v.speed=p.speed;enter(v,Stage::Stop);break;}
        v.traveled+=step.length();v.boom_time+=dt;while (v.boom_time>=std::max(p.boom_interval,0.001)) {v.boom_time-=std::max(p.boom_interval,0.001);cue(r,t,"sonic_boom");}
        if (v.traveled>=p.distance) {v.speed=p.speed;enter(v,Stage::Stop);}break;
    }
    case Stage::Stop:
        v.speed*=std::exp(-p.stop_decay*dt);move(r,t,t.direction*v.speed*dt,dt);
        if (!v.shattered && v.elapsed>=p.shatter_time) {cue(r,t,"lance_shatter");v.shattered=true;v.form=0;v.glow=0;}
        if (v.elapsed>=p.stop_time) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;e.vel={};}break;
    }
}
bool MonocerosLance::validate(const TechniqueState &t) {if (!std::holds_alternative<MonocerosLanceState>(t.detail)) return false;const auto &v=std::get<MonocerosLanceState>(t.detail);for (double x:{v.elapsed,v.form,v.glow,v.traveled,v.boom_time,v.speed}) if (!std::isfinite(x) || x<0) return false;return v.stage<=MonocerosLanceState::Stage::Stop && v.form<=1 && v.glow<=1;}
}
