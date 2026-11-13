#include "cross.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/cross.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
void CrossBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->cross_enemies[d.cross_definition-1];
    const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Beam},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    if (e.mode==EnemyMode::Windup) {
        e.vel={};e.timer-=dt;e.charge=1.0-std::max(0.0,e.timer)/p.telegraph;
        if (e.timer<=0) {e.charge=0;godot::Dictionary ev;ev["id"]=e.id;FrameBuilder::append(r,"enemy_laser_fire",ev);e.mode=EnemyMode::Recover;e.timer=p.beam_time+p.rest;}return;
    }
    if (e.mode==EnemyMode::Recover) {e.vel={};e.timer-=dt;if (e.timer<=0) {e.mode=EnemyMode::Move;e.fire_t=d.fire_interval;}return;}
    const auto delta=s.ship_pos-e.pos;const auto sign=[](double v){return v<0?-1.0:1.0;};
    const auto goal=std::abs(delta.x)<std::abs(delta.y)?godot::Vector2(s.ship_pos.x,s.ship_pos.y-sign(delta.y)*p.stand_off):godot::Vector2(s.ship_pos.x-sign(delta.x)*p.stand_off,s.ship_pos.y);
    EnemyMotion::steer(e,goal,e.speed,p.accel,dt,tracking);e.facing+=dt*1.5;e.fire_t-=dt;
    if (std::min(std::abs(delta.x),std::abs(delta.y))>p.align_tol || e.fire_t>0 || delta.length()>p.beam_length*0.8) return;
    BeamParams beam;beam.position=e.pos;beam.angle=0;beam.length=p.beam_length;beam.half_width=p.half_width;beam.delay=p.telegraph;beam.active=p.beam_time;beam.damage=p.damage;beam.color=d.color.lightened(0.3);beam.owner=self;if (e.attack_managed) beam.budget.value=budget.token(owner);
    CrossSystem::emit(r,beam);e.vel={};e.mode=EnemyMode::Windup;e.timer=p.telegraph;e.facing=0;godot::Dictionary ev;ev["id"]=e.id;ev["row"]=row;ev["time"]=p.telegraph;FrameBuilder::append(r,"enemy_laser_charge",ev);
}
}
