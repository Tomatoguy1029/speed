#include "auriga.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/wall.h"
namespace speed {
void AurigaBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->aurigas[d.auriga_definition-1];
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    EnemyMotion::turn(e,(s.enemy_aim-e.pos).angle(),d.turn,dt,tracking);e.vel=godot::Vector2::from_angle(e.facing)*e.speed;e.fire_t-=dt;if (e.fire_t>0) return;
    const auto handle=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !budget.owns(owner,e.id) && EnemySystem::attack_due(r,handle,dt)) {
        if (!budget.request({owner,{AttackCategory::Residue},handle,0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) return;
    }
    e.fire_t=p.trail_step;const auto segment=e.vel*p.trail_step;const auto side=godot::Vector2::from_angle(e.facing+godot::Math::PI/2.0)*p.wheel_gap;
    for (double sign:{-1.0,1.0}) {WallParams wall;wall.position=e.pos-segment+side*sign;wall.angle=segment.angle();wall.length=segment.length();wall.half_width=p.trail_width*0.5;wall.active=p.trail_time;wall.damage=p.damage;wall.color=godot::Color::html("ff8a3c");if (e.attack_managed) wall.budget.value=budget.token(owner);WallSystem::emit(r,wall);}
}
}
