#include "ruler.h"
#include "pursuit.h"
#include "../../systems/enemy_system.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/wall.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
godot::Vector2 RulerBehavior::beam_origin(const RunRuntime &r,uint32_t row) {
    const auto &e=r.state.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->rulers[d.ruler_definition-1];
    const auto direction=godot::Vector2::from_angle(e.facing),normal=godot::Vector2(-direction.y,direction.x);
    const double scale=2.0*e.radius*d.sprite_scale/58.0,side=std::get<RulerState>(e.behavior_state).side;
    return e.pos+direction*(27.5*scale+p.fx_muzzle)+normal*(side*10.5*scale);
}
void RulerBehavior::after_tick(RunRuntime &r) {
    // AI can be skipped while pushed, held or offscreen. Keep the live wall on
    // its emitter after movement and field collision, independent of AI ticks.
    const auto &s=r.state;
    for (size_t group=0;group<s.behavior_kinds.size();++group) {
        if (s.behavior_kinds[group]!=EnemyDefinition::Kind::Ruler) continue;
        for (auto row:s.behavior_rows[group]) {
            const auto &e=s.enemies[row];if (!e.alive || e.dead) continue;
            const auto &v=std::get<RulerState>(e.behavior_state);
            const auto *beam=AttackSystem::get(s,v.beam);
            if (beam && same_handle(beam->spec.owner.live_source,s.enemy_handles.at(row)))
                WallSystem::move(r,v.beam,beam_origin(r,row),e.facing);
        }
    }
}
void RulerBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<RulerState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->rulers[d.ruler_definition-1];const auto self=s.enemy_handles.at(row);
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Beam},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    if (!v.side) {
        EnemyMotion::keep_distance(r,row,p.keep,p.accel,dt);if (e.age<p.split_delay) return;
        const auto rel=s.ship_pos-e.pos;godot::Vector2 direction=std::abs(rel.x)>std::abs(rel.y)?godot::Vector2((rel.x>0)-(rel.x<0),0):godot::Vector2(0,(rel.y>0)-(rel.y<0));
        if (direction==godot::Vector2()) direction={0,1};if (tracking.locked()) direction=godot::Vector2::from_angle(e.facing);
        EnemySpawn spawn;spawn.origin=SpawnOrigin::Split;spawn.picaro_owner=e.picaro_owner;spawn.position=e.pos;spawn.facing=direction.angle();spawn.has_facing=true;spawn.elite=e.elite;spawn.group=e.attack_group;spawn.value=e.attack_value;spawn.has_value=true;spawn.priority=e.attack_priority;spawn.has_priority=true;
        const auto child_id=EnemySystem::spawn_base(r,e.definition,spawn);v.side=1;e.facing=direction.angle();e.mode=EnemyMode::Dash;e.timer=p.deploy_time;e.vel=godot::Vector2(-direction.y,direction.x)*p.deploy_speed*0.6;
        if (child_id>0) {auto &child=s.enemies[s.rows_by_id.at(child_id)];std::get<RulerState>(child.behavior_state).side=-1;child.facing=direction.angle();child.mode=EnemyMode::Dash;child.timer=p.deploy_time;child.vel=-e.vel;}
        godot::Dictionary event;event["pos"]=spawn.position;event["angle"]=direction.angle();event["color"]=d.color;FrameBuilder::append(r,"ruler_split",event);return;
    }
    const auto direction=godot::Vector2::from_angle(e.facing);e.timer-=dt;
    if (e.mode==EnemyMode::Dash) {
        const auto normal=godot::Vector2(-direction.y,direction.x);EnemyMotion::steer(e,s.ship_pos+normal*(double(v.side)*p.half_gap)-direction*p.emit_back,p.deploy_speed,6,dt,tracking);
        if (e.timer<=0) {e.mode=EnemyMode::Windup;e.timer=p.warn;godot::Dictionary event;event["id"]=e.id;event["row"]=int64_t(row);FrameBuilder::append(r,"enemy_laser_charge",event);}return;
    }
    e.vel*=std::max(0.0,1-8*dt);
    if (e.mode==EnemyMode::Windup) {
        e.charge=1-std::max(0.0,e.timer)/p.warn;if (e.timer>0) return;
        WallParams wall;wall.position=beam_origin(r,row);wall.angle=e.facing;wall.length=p.beam_len;wall.half_width=p.beam_width*0.5;wall.active=p.beam_time;wall.damage=p.damage;wall.color=d.color;wall.style=WallStyle::Ray;wall.blocking=true;wall.attached=true;wall.owner=self;if (e.attack_managed) wall.budget.value=budget.token(owner);
        v.beam=WallSystem::emit(r,wall);godot::Dictionary event;event["id"]=e.id;FrameBuilder::append(r,"enemy_laser_fire",event);e.charge=0;e.mode=EnemyMode::Recover;e.timer=p.beam_time;return;
    }
    if (e.mode==EnemyMode::Recover) {
        if (e.timer<=0) {AttackSystem::end(s,v.beam,AttackEndReason::TechniqueEnd);v.beam={};e.mode=EnemyMode::Dash;e.timer=p.deploy_time;}
    }
}
}
