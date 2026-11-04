#include "triangle.h"
#include "pursuit.h"
#include "../../systems/enemy_system.h"
#include "../../systems/group_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/wall.h"
#include "../../systems/combat_resolver.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double tau=6.2831853071795864769;
godot::Vector2 vertex(const Enemy &e,const TriangleDefinition &p,uint32_t n) {return e.pos+godot::Vector2::from_angle(e.spin+tau*double(n%3)/3.0)*p.span;}
void end_travel(RunRuntime &r,EnemyHandle self) {
    auto &s=r.state;auto &e=s.enemies[self.slot];auto &v=std::get<TriangleState>(e.behavior_state);
    for (uint32_t k=0;k<3;++k) {const auto *record=AttackSystem::get(s,v.trails[k]);if (record && k<e.parts.size() && same_handle(record->spec.owner.live_source,e.parts[k])) AttackSystem::end(s,v.trails[k],AttackEndReason::TechniqueEnd);v.trails[k]={};}
}
}
void TriangleBehavior::spawned(RunRuntime &r,EnemyHandle self) {
    auto &s=r.state;auto &e=s.enemies[self.slot];const auto &p=r.content->triangles[r.content->definitions[e.definition].triangle_definition-1];e.spin=s.control.rng.randf()*tau;e.mode=EnemyMode::Move;e.timer=p.stop_time;
    GroupSystem::join(s,self,e.id);auto &group=s.groups.groups[e.id];group.kind=Group::Kind::Triangle;group.leader=self;group.target=e.pos;
    for (uint32_t k=0;k<3;++k) {const auto id=EnemySystem::spawn_part(r,self,p.star-1,vertex(s.enemies[self.slot],p,k));if (id>0) GroupSystem::join(s,s.enemy_handles.at(uint32_t(s.rows_by_id.at(id))),s.enemies[self.slot].id);}
}
void TriangleBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<TriangleState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->triangles[d.triangle_definition-1];const auto self=s.enemy_handles.at(row);
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Residue},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);e.timer-=dt;
    if (e.mode==EnemyMode::Move && e.timer<=0) {
        e.mode=EnemyMode::Dash;e.timer=p.move_time;v.trails={};
        for (uint32_t k=0;k<3 && k<e.parts.size();++k) {const auto part=e.parts[k];if (!s.enemy_handles.contains(part) || s.enemies[part.slot].dead) continue;
            const auto from=vertex(e,p,k+v.buds),to=vertex(e,p,k+v.buds+1);WallParams wall;wall.position=from;wall.angle=(to-from).angle();wall.half_width=p.trail_width*0.5;wall.active=p.move_time+0.2;wall.damage=p.trail_damage;wall.color=d.color;wall.style=WallStyle::Trail;wall.owner=part;wall.attached=true;if (e.attack_managed) wall.budget.value=budget.token(owner);v.trails[k]=WallSystem::emit(r,wall);
        }
    } else if (e.mode==EnemyMode::Dash && e.timer<=0) {end_travel(r,self);v.buds=(v.buds+1)%3;e.mode=EnemyMode::Move;e.timer=p.stop_time;}
}
void TriangleBehavior::after_tick(RunRuntime &r,const std::vector<EnemyHandle> &parents) {
    auto &s=r.state;
    for (auto self:parents) {
        if (!s.enemy_handles.contains(self) || s.enemies[self.slot].dead) continue;
        if (!EnemySystem::parts_alive(s,self)) {end_travel(r,self);DamageRequest death;death.struck=self;death.cause=Cause::Collapse;CombatResolver::kill_enemy(r,death);if (s.enemy_handles.contains(self) && !s.enemies[self.slot].dead) EnemySystem::mark_dead(r,self);continue;}
        auto &e=s.enemies[self.slot];auto &v=std::get<TriangleState>(e.behavior_state);const auto &p=r.content->triangles[r.content->definitions[e.definition].triangle_definition-1];const bool travel=e.mode==EnemyMode::Dash;const double u=travel?std::clamp(1-e.timer/p.move_time,0.0,1.0):0;
        if (auto *group=s.groups.groups.getptr(e.id)) group->target=e.pos;
        for (uint32_t k=0;k<3 && k<e.parts.size();++k) {const auto part=e.parts[k];if (!s.enemy_handles.contains(part) || s.enemies[part.slot].dead) continue;
            const auto from=vertex(e,p,k+v.buds),to=vertex(e,p,k+v.buds+1),at=from.lerp(to,u);auto &star=s.enemies[part.slot];star.pos=at;star.vel=e.vel;star.facing=(to-from).angle();
            const auto *record=AttackSystem::get(s,v.trails[k]);if (travel && record && same_handle(record->spec.owner.live_source,part)) WallSystem::move(r,v.trails[k],from,(to-from).angle(),from.distance_to(at));
        }
    }
}
}
