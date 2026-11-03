#include "aquarius.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/flood.h"
#include "../../output/frame_builder.h"
#include <algorithm>
namespace speed {
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
    ev["pos"]=e.pos;ev["angle"]=angle;ev["count"]=p.beams;ev["length"]=p.beam_length;ev["width"]=p.half_width*2;ev["spread"]=p.spread;ev["delay"]=p.telegraph;ev["active"]=p.beam_time;ev["color"]=color;ev["row"]=row;ev["id"]=e.id;FrameBuilder::append(r,"aquarius_aim",ev);
    std::vector<AttackHandle> volley;
    for (uint32_t k=0;k<p.beams;++k) {BeamParams beam;beam.position=e.pos;beam.angle=angle+k*godot::Math::TAU/p.beams;beam.length=p.beam_length;beam.half_width=p.half_width;beam.arc=p.spread;beam.delay=p.telegraph;beam.active=p.beam_time;beam.damage=p.damage;beam.color=color;beam.owner=self;if (e.attack_managed) beam.budget.value=budget.token(owner);const auto h=FloodSystem::emit(r,beam);if (AttackSystem::get(s,h)) volley.push_back(h);}
    if (!volley.empty()) {const int64_t group=AttackSystem::get(s,volley.front())->id;for (auto h:volley) if (const auto *record=AttackSystem::get(s,h)) std::get<BeamHazard>(s.hazards[record->row].shape).flood_group=group;}
    e.mode=EnemyMode::Windup;e.timer=p.telegraph+p.beam_time;godot::Dictionary charge;charge["id"]=e.id;charge["row"]=row;FrameBuilder::append(r,"enemy_laser_charge",charge);
}
}
