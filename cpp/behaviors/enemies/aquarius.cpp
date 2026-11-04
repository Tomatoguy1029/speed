#include "aquarius.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/flood.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
double smooth(double a,double b,double value) {const double k=std::clamp((value-a)/(b-a),0.0,1.0);return k*k*(3.0-2.0*k);}
}
double AquariusBehavior::visual_time(const RunRuntime &r,uint32_t row) {
    const auto &e=r.state.enemies[row];const auto &p=r.content->aquarius[r.content->definitions[e.definition].aquarius_definition-1];
    if (e.mode==EnemyMode::Recover) return p.telegraph+p.beam_time+std::max(0.0,p.rest-e.timer);
    if (e.mode!=EnemyMode::Windup) return -1;
    const auto found=r.state.attacks.by_source.find(e.id);
    if (found!=r.state.attacks.by_source.end()) for (auto handle:found->second) {
        const auto *record=AttackSystem::get(r.state,handle);if (!record || record->pool!=AttackPool::Hazard) continue;
        const auto &hazard=r.state.hazards[record->row];const auto *beam=std::get_if<BeamHazard>(&hazard.shape);
        if (hazard.alive && beam && beam->style==uint32_t(BeamStyle::Flood)) return hazard.time;
    }
    return std::max(0.0,p.telegraph+p.beam_time-e.timer);
}
AquariusPose AquariusBehavior::visual_pose(const RunRuntime &r,uint32_t row,godot::Vector2 pos,double facing,double time) {
    const auto &e=r.state.enemies[row];const auto &p=r.content->aquarius[r.content->definitions[e.definition].aquarius_definition-1];
    double rotation=0;godot::Vector2 shake;
    if (time<p.telegraph) rotation=-0.18*smooth(0,p.telegraph*0.6,time);
    else if (time<p.telegraph+p.beam_time) {
        const double age=time-p.telegraph;
        rotation=-0.18+std::sin(age*2.4)*0.09*smooth(0,0.3,age)+std::sin(age*41)*0.012;
        shake={float(std::sin(age*53)*1.6),float(std::cos(age*47)*1.6)};
    } else rotation=(-0.18+std::sin(p.beam_time*2.4)*0.09)*(1-smooth(0,0.5,time-p.telegraph-p.beam_time));
    const double tilt=time<p.telegraph?smooth(0,p.telegraph*0.6,time):
        (time<p.telegraph+p.beam_time?1.0:1.0-smooth(0,0.5,time-p.telegraph-p.beam_time));
    return {pos+shake,facing+rotation-godot::Math::PI*0.5*tilt};
}
godot::Vector2 AquariusBehavior::claw_tip(const RunRuntime &r,uint32_t row,const AquariusPose &pose) {
    const auto &e=r.state.enemies[row];const auto &d=r.content->definitions[e.definition];
    const double scale=2.0*e.radius*d.sprite_scale/90.0;
    return pose.position+godot::Vector2(-12.0*scale,33.0*scale).rotated(d.sprite_angle+pose.facing);
}
void AquariusBehavior::after_move(RunRuntime &r,EnemyHandle owner,double dt) {
    auto &s=r.state;if (!s.enemy_handles.contains(owner)) return;const auto &e=s.enemies[owner.slot];if (e.dead) return;
    const auto found=s.attacks.by_source.find(e.id);if (found==s.attacks.by_source.end()) return;
    for (auto handle:found->second) {
        const auto *record=AttackSystem::get(s,handle);if (!record || record->pool!=AttackPool::Hazard) continue;
        const auto &hazard=s.hazards[record->row];const auto *beam=std::get_if<BeamHazard>(&hazard.shape);
        if (!hazard.alive || !beam || beam->style!=uint32_t(BeamStyle::Flood)) continue;
        const auto pose=visual_pose(r,owner.slot,e.pos,e.facing,double(hazard.time)+dt);
        BeamSystem::move(r,handle,claw_tip(r,owner.slot,pose),beam->angle);
    }
}
void AquariusBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->aquarius[d.aquarius_definition-1];
    const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Beam},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    if (e.mode==EnemyMode::Windup) {
        if (e.timer>p.beam_time) {e.vel*=std::max(0.0,1.0-2.5*dt);EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),2.0,dt,tracking);}else e.vel*=std::max(0.0,1.0-8.0*dt);
        const double before=e.timer;e.timer-=dt;
        if (before>p.beam_time && e.timer<=p.beam_time) {godot::Dictionary ev;ev["id"]=e.id;FrameBuilder::append(r,"enemy_laser_fire",ev);}
        e.charge=std::clamp(1.0-(e.timer-p.beam_time)/p.telegraph,0.0,1.0);
        if (e.timer<=0) {e.charge=0;e.mode=EnemyMode::Recover;e.timer=p.rest;}return;
    }
    if (e.mode==EnemyMode::Recover) {e.vel*=std::max(0.0,1.0-8.0*dt);e.timer-=dt;if (e.timer<=0) e.mode=EnemyMode::Move;return;}
    const auto to=s.ship_pos-e.pos;const double dist=to.length();const auto goal=s.ship_pos-to/std::max(dist,1.0)*p.approach;
    EnemyMotion::steer(e,goal,e.speed*std::clamp((dist-p.approach)/200.0,0.0,1.0),p.accel,dt,tracking);EnemyMotion::turn(e,to.angle(),d.turn,dt,tracking);e.fire_t-=dt;
    if (e.fire_t>0 || dist>p.approach*1.25) return;e.fire_t=d.fire_interval;
    const double angle=tracking.angle(e.facing,to.angle());const auto color=d.color.lightened(0.25);godot::Dictionary ev;
    const auto source=claw_tip(r,row,visual_pose(r,row,e.pos,e.facing,0.0));
    ev["pos"]=source;ev["angle"]=angle;ev["count"]=p.beams;ev["length"]=p.beam_length;ev["width"]=p.half_width*p.fx_size*2;ev["spread"]=p.spread;ev["delay"]=p.telegraph;ev["active"]=p.beam_time;ev["color"]=color;ev["row"]=row;ev["id"]=e.id;FrameBuilder::append(r,"aquarius_aim",ev);
    std::vector<AttackHandle> volley;
    for (uint32_t k=0;k<p.beams;++k) {BeamParams beam;beam.position=source;beam.angle=angle+k*godot::Math::TAU/p.beams;beam.length=p.beam_length;beam.half_width=p.half_width*p.fx_size;beam.arc=p.spread;beam.delay=p.telegraph;beam.active=p.beam_time;beam.damage=p.damage;beam.color=color;beam.owner=self;if (e.attack_managed) beam.budget.value=budget.token(owner);const auto h=FloodSystem::emit(r,beam);if (const auto *record=AttackSystem::get(s,h)) {auto &visual=std::get<BeamHazard>(s.hazards[record->row].shape);visual.flood_index=k;visual.flood_reference=true;volley.push_back(h);}}
    if (!volley.empty()) {const int64_t group=AttackSystem::get(s,volley.front())->id;for (auto h:volley) if (const auto *record=AttackSystem::get(s,h)) std::get<BeamHazard>(s.hazards[record->row].shape).flood_group=group;}
    e.mode=EnemyMode::Windup;e.timer=p.telegraph+p.beam_time;godot::Dictionary charge;charge["id"]=e.id;charge["row"]=row;FrameBuilder::append(r,"enemy_laser_charge",charge);
}
}
