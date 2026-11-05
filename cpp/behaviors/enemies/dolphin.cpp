#include "dolphin.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/motion_math.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/wave.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
void DolphinBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->dolphins[d.dolphin_definition-1];
    const auto handle=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.mode!=EnemyMode::Recover && e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,handle)) && EnemySystem::attack_due(r,handle,dt)) {
        if (!budget.request({owner,{AttackCategory::Wave},handle,p.warn+0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    switch (e.mode) {
    case EnemyMode::Windup: {
        e.vel={};const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
        if (!tracking.locked()) e.facing+=std::clamp(angle_difference(double((s.ship_pos-e.pos).angle())-e.facing),-p.aim_turn*dt,p.aim_turn*dt);
        e.timer-=dt;e.charge=1.0-std::max(0.0,e.timer)/p.warn;
        if (e.timer<=0) {
            WaveParams wave;wave.position=e.pos+godot::Vector2::from_angle(e.facing)*e.radius;wave.angle=e.facing;wave.arc=p.arc;wave.radius=p.radius;wave.speed=p.speed;wave.width=p.width;wave.damage=p.damage;
            wave.color=godot::Color(1.0,0.3,0.25);wave.style=WaveStyle::Ripple;wave.enemy_damage=p.enemy_damage;
            if (e.attack_managed) wave.budget.value=budget.token(owner);WaveSystem::emit(r,wave);
            // dolphin_reference.gdの後続3波が口元を出てから、さらに0.5秒止まる。
            e.charge=0;e.mode=EnemyMode::Recover;e.timer=3.0*p.width*1.6/std::max(p.speed,1.0)+0.5;
        }break;
    }
    case EnemyMode::Recover:
        e.vel={};e.timer-=dt;if (e.timer<=0) {e.mode=EnemyMode::Move;e.fire_t=d.fire_interval;}break;
    default:
        EnemyMotion::keep_distance(r,row,p.keep,p.accel,dt);e.fire_t-=dt;if (e.fire_t<=0) {e.mode=EnemyMode::Windup;e.timer=p.warn;e.vel={};}break;
    }
}
}
