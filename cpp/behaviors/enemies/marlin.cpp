#include "marlin.h"
#include "../../systems/attack_budget.h"
#include "../../systems/enemy_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/field.h"
#include "../../systems/motion_math.h"
#include "../../systems/enemy_motion.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
namespace {
bool admit(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];if (!e.attack_managed) return true;
    const auto &d=r.content->definitions[e.definition];const auto &p=r.content->marlins[d.marlin_definition-1];
    AttackBudgetSystem budget(r);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);const auto h=s.enemy_handles.at(row);
    if (budget.owns(owner,e.id) && EnemySystem::attack_active(s,h)) return true;
    if (!EnemySystem::attack_due(r,h,dt)) return true;
    if (budget.request({owner,{AttackCategory::Dash,AttackCategory::Aimed},h,p.warn+p.dash_time+0.1,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) return true;
    e.charge=0;return false;
}
}
void MarlinBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->marlins[d.marlin_definition-1];
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.mode!=EnemyMode::Move) admit(r,row,dt);
    switch (e.mode) {
    case EnemyMode::Move:
        e.fire_t=std::max(p.warn,e.fire_t-dt);
        if (e.fire_t<=p.warn && admit(r,row,dt)) {
            auto &state=std::get<MarlinState>(e.behavior_state);state.anchor=tracking.target(e.pos,e.facing,s.ship_pos);
            e.facing=tracking.angle(e.facing,(state.anchor-e.pos).angle());e.vel={};e.mode=EnemyMode::Windup;e.timer=std::max(0.0,e.fire_t);e.charge=0.01;
        } else {
            const auto relative=e.pos-s.enemy_aim;const auto outward=relative.length_squared()>0.001?relative.normalized():godot::Vector2(1,0);
            const auto target=s.enemy_aim+outward*p.keep+outward.orthogonal()*200.0*(e.id%2?1.0:-1.0);const auto course=target-e.pos;
            if (course.length_squared()>0.001 && !tracking.locked()) e.facing+=std::clamp(angle_difference(double(course.angle())-e.facing),-d.turn*dt,d.turn*dt);
            const double speed=e.vel.length(),change=e.speed*p.accel*dt;const double next=speed+std::clamp(e.speed-speed,-change,change);
            e.vel=godot::Vector2::from_angle(e.facing)*next;
        }break;
    case EnemyMode::Windup:
        e.vel={};e.timer-=dt;e.charge=std::clamp(1.0-e.timer/std::max(p.warn,0.001),0.01,1.0);
        if (e.timer<=0) {e.mode=EnemyMode::Dash;e.timer=p.dash_time;e.fire_t=d.fire_interval;e.charge=0;}break;
    case EnemyMode::Dash:
        if (e.timer<=0) {e.vel={};e.mode=EnemyMode::Recover;e.timer=p.recover;}break;
    case EnemyMode::Recover:
        e.vel*=std::max(0.0,1.0-8.0*dt);e.timer-=dt;
        if (e.timer<=0) {e.vel={};e.mode=EnemyMode::Move;}break;
    }
}
void MarlinBehavior::before_move(RunRuntime &r,EnemyHandle self,double dt) {
    auto &s=r.state;if (!s.enemy_handles.contains(self) || s.enemies[self.slot].mode!=EnemyMode::Dash || dt<=0) return;
    const auto e=s.enemies[self.slot];const auto &p=r.content->marlins[r.content->definitions[e.definition].marlin_definition-1];
    const double travel=std::min(dt,std::max(0.0,e.timer));if (travel<=0) {s.enemies[self.slot].vel={};return;}
    const auto from=e.pos,direction=godot::Vector2::from_angle(e.facing);auto to=from+direction*p.dash_speed*travel;
    if (const auto hit=FieldSystem::first_body_hit(r,from,to,e.radius)) to=from.lerp(to,hit->t);
    std::vector<EnemyHandle> targets;targets.reserve(s.enemies.size());for (uint32_t j=0;j<s.enemies.size();++j) targets.push_back(s.enemy_handles.at(j));
    for (auto target:targets) {
        if (!s.enemy_handles.contains(target) || same_handle(target,self)) continue;const auto victim=s.enemies[target.slot];
        if (!victim.alive || victim.dead || victim.is_boss || victim.guard>0 || (s.enemy_handles.contains(victim.parent) && s.enemies[victim.parent.slot].is_boss)) continue;
        const double t=CollisionQuery::segment_circle_t(from,to,victim.pos,e.radius+victim.radius);if (t<0) continue;
        DamageRequest request;request.struck=target;request.amount=victim.hp;request.cause=Cause::Marlin;request.direction=direction;request.impact=from.lerp(to,t);request.has_impact=true;
        if (CombatResolver::allows_hit(r,target,request)) CombatResolver::kill_enemy(r,request);
        if (!s.enemy_handles.contains(self) || s.enemies[self.slot].dead || s.phase!=godot::RunState::Phase::Play) return;
    }
    if (!s.enemy_handles.contains(self)) return;
    s.enemies[self.slot].vel=(to-from)/dt;s.enemies[self.slot].timer=std::max(0.0,s.enemies[self.slot].timer-dt);
}
void MarlinBehavior::after_tick(RunRuntime &r,const std::vector<EnemyHandle> &handles) {
    auto &s=r.state;
    for (auto h:handles) if (s.enemy_handles.contains(h)) {
        auto &e=s.enemies[h.slot];const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
        if (!e.dead && e.mode==EnemyMode::Move && e.shove_time<=0 && e.knock_t<=0 && e.vel.length_squared()>0.001 && !tracking.locked()) e.facing=e.vel.angle();
    }
}
}
