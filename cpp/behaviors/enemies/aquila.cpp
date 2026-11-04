#include "aquila.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/field.h"
#include "../../systems/attacks/zone.h"
#include <algorithm>
namespace speed {
void AquilaBehavior::cruise(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->aquilas[d.aquila_definition-1];const auto radial=e.pos-s.enemy_aim;
    const auto outward=radial.length_squared()>0.001?radial.normalized():godot::Vector2(1,0);const double side=e.id%2?1.0:-1.0;
    const auto target=s.enemy_aim+outward*p.keep+outward.orthogonal()*200.0*side,course=target-e.pos;const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (course.length_squared()>0.001) EnemyMotion::turn(e,course.angle(),d.turn,dt,tracking);
    e.vel=godot::Vector2::from_angle(e.facing)*e.speed;
}
void AquilaBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<AquilaState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->aquilas[d.aquila_definition-1];
    const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Dash,AttackCategory::Zone},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {cruise(r,row,dt);return;}
    }
    switch (e.mode) {
    case EnemyMode::Move:
        e.fire_t=std::max(0.0,e.fire_t-dt);if (e.fire_t<=0) {e.mode=EnemyMode::Windup;e.timer=p.aim_time+p.lock_time;e.vel={};return;}cruise(r,row,dt);break;
    case EnemyMode::Windup:
        e.vel={};if (e.timer>p.lock_time) {EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),2.8,dt,tracking);e.charge=0;}
        e.timer-=dt;
        if (e.timer<=p.lock_time && e.charge==0) {
            const auto to_ship=s.ship_pos-e.pos;e.facing=tracking.angle(e.facing,to_ship.angle());const double gap=e.radius+r.content->config.ship_config_ship_radius+12.0;
            const double advance=std::min(p.dash_speed*p.dash_time,std::max(0.0,double(to_ship.length())-gap));const auto end=e.pos+godot::Vector2::from_angle(e.facing)*advance;
            const auto hit=FieldSystem::first_body_hit(r,e.pos,end,e.radius);v.anchor=hit?e.pos.lerp(end,hit->t):end;e.charge=0.01;
        }
        if (e.timer<=0) {e.mode=EnemyMode::Dash;e.timer=p.dash_time;v.bud_t=0;e.charge=0;}else e.charge=std::max(e.charge,1.0-e.timer/p.lock_time);break;
    case EnemyMode::Dash:break;
    default:
        e.vel={};e.timer-=dt;if (e.timer<=0) {e.mode=EnemyMode::Move;e.fire_t=d.fire_interval;}break;
    }
}
void AquilaBehavior::before_move(RunRuntime &r,EnemyHandle self,double dt) {
    auto &s=r.state;if (!s.enemy_handles.contains(self) || s.enemies[self.slot].mode!=EnemyMode::Dash || dt<=0) return;
    auto &e=s.enemies[self.slot];auto &v=std::get<AquilaState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->aquilas[d.aquila_definition-1];
    const auto dir=godot::Vector2::from_angle(e.facing);const double remaining=std::max(0.0,double((v.anchor-e.pos).dot(dir))),travel=std::min(remaining,p.dash_speed*std::min(dt,e.timer));e.vel=dir*(travel/dt);
    const double elapsed=travel/p.dash_speed;double next=v.bud_t;
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);
    const auto drop=[&](godot::Vector2 at) {ZoneParams zone;zone.position=at;zone.radius=p.blast_radius;zone.delay=p.blast_delay;zone.damage=p.damage;zone.style=ZoneStyle::Aquila;zone.color=godot::Color::html("e1f7ff");zone.owner=self;if (e.attack_managed) zone.budget.value=AttackBudgetSystem::token(s,owner);ZoneSystem::emit(r,zone);};
    while (next<=elapsed+0.00001) {drop(e.pos+dir*p.dash_speed*next);next+=p.drop_step;}
    v.bud_t=next-elapsed;e.timer-=dt;
    if (e.timer<=0 || remaining<=travel+0.001) {if (p.drop_step-v.bud_t>p.drop_step*0.25) drop(e.pos+dir*travel);e.mode=EnemyMode::Recover;e.timer=p.recover;}
}
}
