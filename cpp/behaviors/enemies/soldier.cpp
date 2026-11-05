#include "soldier.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/group_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/bolt.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
bool SoldierBehavior::configure(RunRuntime &r,EnemyHandle h,EnemyHandle king,uint32_t slot,const SoldierFormation &f,bool moving) {
    auto &s=r.state;if (!s.enemy_handles.contains(h) || !s.enemy_handles.contains(king) || same_handle(h,king) || s.enemies[h.slot].dead || s.enemies[king.slot].dead || !std::holds_alternative<SoldierState>(s.enemies[h.slot].behavior_state) || !f.anchor.is_finite() || f.tier<1 || f.tier>3 || slot>=(f.tier==1?3u:f.tier==2?5u:7u)) return false;
    for (double v:{f.spacing,f.row_near,f.row_far,f.fan_radius,f.fan_step}) if (!std::isfinite(v) || v<0 || !std::isfinite(float(v))) return false;
    auto &e=s.enemies[h.slot];e.behavior_state=SoldierState{king,s.enemies[king.slot].id,slot,f};e.mode=moving?EnemyMode::Dash:EnemyMode::Move;e.charge=0;
    GroupSystem::join(s,h,s.enemies[king.slot].id);auto &group=s.groups.groups[s.enemies[king.slot].id];group.kind=Group::Kind::Cepheus;group.leader=king;group.formation=f;return true;
}
void SoldierBehavior::start_mutiny(RunRuntime &r,EnemyHandle h,double seconds) {
    auto &s=r.state;if (!s.enemy_handles.contains(h) || s.enemies[h.slot].dead || !std::isfinite(seconds) || seconds<0 || !std::holds_alternative<SoldierState>(s.enemies[h.slot].behavior_state)) return;
    auto &e=s.enemies[h.slot];e.mode=EnemyMode::Recover;e.timer=seconds;e.fire_t=s.control.rng.randf()*r.content->soldiers[r.content->definitions[e.definition].soldier_definition-1].mutiny_shot;
}
AttackHandle SoldierBehavior::fire(RunRuntime &r,EnemyHandle h,BudgetToken token) {
    auto &s=r.state;if (!s.enemy_handles.contains(h)) return {};const auto &e=s.enemies[h.slot];
    if (e.dead || e.mode!=EnemyMode::Move || !std::holds_alternative<SoldierState>(e.behavior_state)) return {};
    const auto &p=r.content->soldiers[r.content->definitions[e.definition].soldier_definition-1];BoltParams shot;shot.position=e.pos+godot::Vector2::from_angle(e.facing)*e.radius;shot.angle=e.facing;shot.speed=p.bolt_speed;shot.damage=p.damage;shot.budget=token;const auto handle=BoltSystem::emit(r,shot);if (const auto *record=AttackSystem::get(s,handle)) s.hostiles[record->row].bolt.reference_soldier=true;return handle;
}
void SoldierBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->soldiers[d.soldier_definition-1];const auto self=s.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (!e.group_id && e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Aimed},self,0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    const auto state=std::get<SoldierState>(e.behavior_state);
    if (e.mode==EnemyMode::Recover) {
        e.vel*=std::max(0.0,1.0-8.0*dt);e.timer-=dt;e.fire_t-=dt;EnemyHandle foe;double nearest=INFINITY;
        const auto &rows=s.behavior_rows[e.behavior_group];for (auto other:rows) {const auto &candidate=s.enemies[other];if (other==row || candidate.dead) continue;const double distance=e.pos.distance_squared_to(candidate.pos);if (distance<nearest) {nearest=distance;foe=s.enemy_handles.at(uint32_t(other));}}
        if (s.enemy_handles.contains(foe)) {
            const auto target=s.enemies[foe.slot];EnemyMotion::turn(e,(target.pos-e.pos).angle(),d.turn,dt,tracking);
            if (e.fire_t<=0) {
                e.fire_t=p.mutiny_shot;godot::Dictionary event;event["from"]=e.pos;event["to"]=target.pos;event["width"]=4.0;event["life"]=0.12;event["color"]=d.color.lightened(0.3);FrameBuilder::append(r,"beam",event);
                DamageRequest request;request.struck=foe;request.amount=target.max_hp*0.35;request.cause=Cause::Collapse;request.no_crit=true;CombatResolver::damage_enemy(r,request);
            }
        }
        if (s.enemy_handles.contains(self) && !s.enemies[row].dead && s.enemies[row].timer<=0) {DamageRequest request;request.struck=self;request.cause=Cause::Collapse;CombatResolver::kill_enemy(r,request);}return;
    }
    if (!s.enemy_handles.contains(state.king) || s.enemies[state.king.slot].dead) {start_mutiny(r,self,0.4);return;}
    const auto *group=s.groups.groups.getptr(state.king_id);const auto &f=group && group->kind==Group::Kind::Cepheus?group->formation:state.formation;double angle=s.enemies[state.king.slot].facing;const auto u=godot::Vector2::from_angle(angle),n=godot::Vector2(-u.y,u.x);godot::Vector2 goal;
    if (f.tier==1) goal=f.anchor+u*f.row_near+n*(double(state.slot)-1.0)*f.spacing;
    else if (f.tier==2) {angle+=(double(state.slot)-2.0)*f.fan_step;goal=f.anchor+godot::Vector2::from_angle(angle)*f.fan_radius;}
    else if (state.slot<4) goal=f.anchor+u*f.row_far+n*(double(state.slot)-1.5)*f.spacing;
    else goal=f.anchor+u*f.row_near+n*(double(state.slot)-5.0)*f.spacing;
    if (e.mode==EnemyMode::Dash) {EnemyMotion::steer(e,goal,e.speed,p.accel,dt,tracking);EnemyMotion::turn(e,(goal-e.pos).angle(),d.turn,dt,tracking);if (e.pos.distance_to(goal)<8.0) {e.pos=goal;e.vel={};e.facing=tracking.angle(e.facing,angle);e.mode=EnemyMode::Move;}return;}
    e.vel={};e.pos=goal;EnemyMotion::turn(e,angle,d.turn,dt,tracking);
}
}
