#include "pump.h"
#include "pursuit.h"
#include "../../systems/collision_query.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/shell.h"
#include "../../systems/attacks/friend_debris.h"
#include "../../systems/attacks/zone.h"
#include "../../output/frame_builder.h"
#include <algorithm>
namespace speed {
namespace {
bool pulling(const RunRuntime &r,EnemyHandle h) {
    const auto &s=r.state;if (!s.enemy_handles.contains(h)) return false;const auto &e=s.enemies[h.slot];const auto &d=r.content->definitions[e.definition];
    return d.kind==EnemyDefinition::Kind::Pump && !e.dead && e.mode==EnemyMode::Move && std::get<PumpState>(e.behavior_state).contents.size()<r.content->pumps[d.pump_definition-1].store_max && e.stone<=0 && !e.held && e.knock_t<=0 && e.shove_time<=0;
}
bool owns(const RunRuntime &r,EnemyHandle h) {
    const auto &s=r.state;if (!s.enemy_handles.contains(h)) return false;const auto &e=s.enemies[h.slot];if (e.held || e.stone>0 || e.shove_time>0 || !pulling(r,e.pump_owner)) return false;
    const auto &owner=s.enemies[e.pump_owner.slot];const auto &p=r.content->pumps[r.content->definitions[owner.definition].pump_definition-1];return owner.pos.distance_squared_to(e.pos)<=p.pull_radius*p.pull_radius;
}
void suck(RunRuntime &r,EnemyHandle self,double dt) {
    auto &s=r.state;if (!pulling(r,self)) return;auto &e=s.enemies[self.slot];auto &v=std::get<PumpState>(e.behavior_state);const auto &p=r.content->pumps[r.content->definitions[e.definition].pump_definition-1];
    const auto mouth=e.pos+godot::Vector2::from_angle(e.facing)*p.mouth_radius*(e.elite?1.25:1.0)*0.85;const double bite=e.radius+p.swallow_reach;v.bud_t-=dt;
    const auto pad=godot::Vector2(p.pull_radius,p.pull_radius);const auto rows=CollisionQuery::enemy_rows(s,e.pos-pad,e.pos+pad);std::vector<EnemyHandle> targets;for (auto row:rows) targets.push_back(s.enemy_handles.at(uint32_t(row)));
    for (auto target:targets) {
        if (v.contents.size()>=p.store_max) break;if (!s.enemy_handles.contains(target) || same_handle(target,self)) continue;auto &item=s.enemies[target.slot];const auto &d=r.content->definitions[item.definition];
        if (item.dead || item.is_boss || s.field.rock_handles.contains(item.rock) || item.parent.generation || item.held || item.stone>0 || item.shove_time>0 || item.landmark || d.rank<1 || d.rank>2 || d.kind==EnemyDefinition::Kind::Pump || e.pos.distance_squared_to(item.pos)>p.pull_radius*p.pull_radius) continue;
        if (owns(r,target) && !same_handle(item.pump_owner,self)) continue;item.pump_owner=self;const auto delta=mouth-item.pos;const double distance=delta.length();
        if (distance<bite && v.bud_t<=0) {
            v.contents.push_back(uint32_t(item.definition+1));v.bud_t=p.swallow_interval;godot::Dictionary ev;ev["enemy_type"]=d.id;ev["pos"]=item.pos;ev["r"]=item.radius;ev["facing"]=item.facing;ev["color"]=d.color;ev["row"]=self.slot;ev["id"]=e.id;ev["visual_id"]=d.visual_id;ev["sprite_radius"]=item.radius*d.sprite_scale;ev["sprite_angle"]=item.facing+d.sprite_angle;FrameBuilder::append(r,"swallow",ev);EnemySystem::mark_dead(r,target);continue;
        }
        const double near=1.0-std::clamp(distance/std::max(p.pull_radius,0.001),0.0,1.0);item.knock_t=std::max(item.knock_t,dt*2.0);item.pos=item.pos.move_toward(mouth,p.pull*(0.3+0.7*near)*dt);item.vel={};
    }
}
}
void PumpBehavior::after_tick(RunRuntime &r) {for (uint32_t row=0;row<r.state.enemies.size();++row) {auto &e=r.state.enemies[row];if (e.alive && e.pump_owner.generation && (e.dead || !owns(r,r.state.enemy_handles.at(row)))) e.pump_owner={};}}
void PumpBehavior::gone(RunRuntime &r,EnemyHandle h,bool discard) {
    auto &s=r.state;if (!s.enemy_handles.contains(h)) return;auto &e=s.enemies[h.slot];e.pump_owner={};auto *v=std::get_if<PumpState>(&e.behavior_state);if (!v) return;if (discard) v->contents.clear();
    for (auto &item:s.enemies) if (item.alive && same_handle(item.pump_owner,h)) item.pump_owner={};
}
void PumpBehavior::death_marked(RunRuntime &r,const DeathContext &death) {gone(r,death.target,false);}
void PumpBehavior::died(RunRuntime &r,const DeathContext &death) {
    if (!r.state.enemy_handles.contains(death.target)) return;const auto e=r.state.enemies[death.target.slot];const auto *v=std::get_if<PumpState>(&e.behavior_state);if (!v) return;const auto &d=r.content->definitions[e.definition];const auto &p=r.content->pumps[d.pump_definition-1];const double full=double(v->contents.size())/p.store_max,damage=death.request.amount*p.release_damage;
    DebrisBurstParams debris;debris.position=e.pos;debris.count=int64_t(p.release_base)+int64_t(p.release_per*v->contents.size());debris.speed=p.release_speed;debris.damage=damage;debris.color=d.color.lightened(0.3);debris.source_id=e.id;debris.armor_count=p.release_base;FriendDebrisSystem::burst(r,debris);
    ZoneSystem::explode(r,e.pos,p.release_radius*(1.0+full),damage,Cause::PumpBurst,500.0+400.0*full,0.35,d.color.lightened(0.4),true);gone(r,death.target,true);
}
void PumpBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<PumpState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->pumps[d.pump_definition-1];const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {if (!budget.request({owner,{AttackCategory::Zone},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}}
    const double full=double(v.contents.size())/p.store_max,base=d.radius*(e.elite?1.25:1.0);e.radius+=(base*(1.0+p.grow*full)-e.radius)*std::min(1.0,6.0*dt);e.timer-=dt;
    switch (e.mode) {
    case EnemyMode::Move:
        EnemyMotion::steer(e,s.enemy_aim,e.speed,p.accel,dt,tracking);EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),d.turn,dt,tracking);suck(r,self,dt);if (v.contents.size()>=p.store_max) {e.mode=EnemyMode::Windup;e.timer=p.telegraph;}break;
    case EnemyMode::Windup:
        e.vel={};e.charge=1.0-std::max(0.0,e.timer)/p.telegraph;if (e.timer>p.lock_time) EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),d.turn*2.0,dt,tracking);
        if (e.timer<=0) {ShellParams shell;shell.source=self;shell.angle=e.facing;shell.speed=p.shell_speed;shell.radius=p.shell_radius;shell.range=p.shell_range;shell.burst=p.burst_radius;shell.damage=p.damage;shell.contents=v.contents;if (e.attack_managed) shell.budget.value=budget.token(owner);ShellSystem::emit(r,shell);v.contents.clear();e.charge=0;e.vel-=godot::Vector2::from_angle(e.facing)*p.shell_speed*0.3;e.mode=EnemyMode::Recover;e.timer=p.recover;}break;
    default:e.vel*=std::max(0.0,1.0-8.0*dt);if (e.timer<=0) e.mode=EnemyMode::Move;break;
    }
}
}
