#include "pulser.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attack_system.h"
#include "../../systems/attacks/wave.h"
#include <algorithm>
namespace speed {
double PulserBehavior::ring_radius(const RunRuntime &r,uint32_t row) {
    const auto &e=r.state.enemies[row];const auto &d=r.content->definitions[e.definition];
    return std::min(r.content->pulsers[d.pulser_definition-1].radius,e.radius/d.scaling.collision*1.12);
}
void PulserBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->pulsers[d.pulser_definition-1];
    const auto handle=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,handle)) && EnemySystem::attack_due(r,handle,dt)) {
        if (!budget.request({owner,{AttackCategory::Wave},handle,p.warn+0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;EnemyMotion::keep_distance(r,row,p.keep,p.accel,dt);return;}
    }
    if (e.mode==EnemyMode::Move) EnemyMotion::keep_distance(r,row,p.keep,p.accel,dt);else e.vel*=std::max(0.0,1.0-8.0*dt);
    if (e.mode==EnemyMode::Move) {
        e.fire_t-=dt;if (e.fire_t<=0) {const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};e.facing=tracking.angle(e.facing,(s.enemy_aim-e.pos).angle());e.mode=EnemyMode::Windup;e.timer=p.warn;}return;
    }
    if (e.mode!=EnemyMode::Windup) return;
    e.timer-=dt;if (e.timer>0 || e.dead || e.held || s.enemy_handles.contains(e.pump_owner)) return;
    WaveParams wave;wave.position=e.pos;wave.angle=e.facing;wave.arc=p.arc;wave.radius=p.radius;wave.speed=p.speed;wave.width=p.width;wave.damage=p.damage;
    wave.color=godot::Color::html("ff0c24");wave.start_radius=ring_radius(r,row);wave.style=WaveStyle::Pulser;wave.owner=handle;if (e.attack_managed) wave.budget.value=budget.token(owner);
    const auto attack=WaveSystem::emit(r,wave);if (const auto *record=AttackSystem::get(s,attack)) s.hazards[record->row].time=-dt-e.timer;
    e.mode=EnemyMode::Move;e.fire_t=d.fire_interval;
}
}
