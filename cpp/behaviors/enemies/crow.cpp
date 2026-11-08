#include "crow.h"
#include "../../output/event_builder.h"
#include "../../systems/enemy_system.h"
#include "../../systems/pickup_system.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
void CrowBehavior::spawned(RunRuntime &r,EnemyHandle h,bool member) {
    if (member) return;auto &s=r.state;const auto leader=s.enemies[h.slot];const auto &p=r.content->crows[r.content->definitions[leader.definition].crow_definition-1];
    const double x=s.control.rng.randf_range(-p.aim_spread,p.aim_spread)*s.view_half.x;const double y=s.control.rng.randf_range(-p.aim_spread,p.aim_spread)*s.view_half.y;
    const auto target=s.view_center+godot::Vector2(x,y);
    if (target.distance_to(leader.pos)>std::min(s.view_half.x,s.view_half.y)*0.25) s.enemies[h.slot].facing=(target-leader.pos).angle();
    s.enemies[h.slot].mode=EnemyMode::Dash;EventBuilder::audio(r,"elite.crow.pass",leader.pos);const double facing=s.enemies[h.slot].facing;const auto u=godot::Vector2::from_angle(facing);const godot::Vector2 side(-u.y,u.x);
    const godot::Vector2 formation[]={godot::Vector2(-1,-1.1),godot::Vector2(-1.1,1),godot::Vector2(-2.1,0.2)};
    for (int64_t k=0;k<std::min<int64_t>(int64_t(p.flock)-1,3);++k) {
        EnemySpawn options;options.origin=leader.origin;options.picaro_owner=leader.picaro_owner;options.position=leader.pos+(u*formation[k].x+side*formation[k].y)*p.flock_gap;options.facing=facing;options.has_facing=true;options.elite=leader.elite;options.flock_member=true;
        options.group=leader.attack_group;options.value=leader.attack_value;options.priority=leader.attack_priority;options.has_value=options.has_priority=true;
        const auto id=EnemySystem::spawn_base(r,leader.definition,options);if (id>0) s.enemies[s.rows_by_id.at(id)].mode=EnemyMode::Dash;
    }
}
void CrowBehavior::step(RunRuntime &r,uint32_t row) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &p=r.content->crows[r.content->definitions[e.definition].crow_definition-1];
    e.vel=godot::Vector2::from_angle(e.facing)*e.speed;const auto rel=e.pos-s.view_center;
    if ((std::abs(rel.x)>s.view_half.x+p.exit_margin || std::abs(rel.y)>s.view_half.y+p.exit_margin) && rel.dot(e.vel)>0) {PickupSystem::lose(r,e.id,CargoLoss::Retreat);EnemySystem::mark_dead(r,s.enemy_handles.at(row));}
}
void CrowBehavior::gather(RunRuntime &r,double dt) {
    auto &s=r.state;const auto kind=std::find(s.behavior_kinds.begin(),s.behavior_kinds.end(),EnemyDefinition::Kind::Crow);if (kind==s.behavior_kinds.end()) return;
    for (auto row:s.behavior_rows[size_t(kind-s.behavior_kinds.begin())]) {
        const auto &e=s.enemies[row];if (e.dead) continue;const auto &p=r.content->crows[r.content->definitions[e.definition].crow_definition-1];
        const double reach=std::max(p.gather_width,p.gather_behind)+e.radius,step=p.gather_speed*dt;const auto u=godot::Vector2::from_angle(e.facing),feet=e.pos-u*e.radius*0.62;
        for (size_t crystal:s.pickups.query_gems(godot::Rect2(e.pos-godot::Vector2(reach,reach),godot::Vector2(reach*2,reach*2)))) {
            auto &gem=s.pickups.gems[crystal];if (!gem.alive || gem.pulled || gem.wait>0) continue;
            const auto rel=gem.pos-e.pos;if (rel.length_squared()>=reach*reach) continue;const double along=rel.dot(u);
            if (along>e.radius*0.3 || along<-p.gather_behind || std::abs(rel.cross(u))>p.gather_width) continue;
            const auto delta=feet-gem.pos;const double distance=delta.length();
            if (distance<=step+4) {PickupSystem::carry(r,s.enemy_handles.at(uint32_t(row)),crystal);EventBuilder::audio(r,"elite.crow.pick",e.pos);}
            else s.pickups.move_gem(crystal,gem.pos+delta/distance*step);
        }
    }
}
CrowCargo CrowBehavior::cargo(const RunRuntime &r,EnemyHandle h) {
    CrowCargo out;const auto id=r.state.enemy_handles.entity_id(h);if (id<=0) return out;
    for (const auto &c:r.state.pickups.cargo) if (c.enemy_id==id && same_handle(c.owner,h)) {out.count=uint32_t(c.crystals.size());for (const auto &gem:c.crystals) out.amount+=gem.value;break;}return out;
}
}
