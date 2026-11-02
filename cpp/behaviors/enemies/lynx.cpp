#include "lynx.h"
#include "gunner.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/slash.h"
namespace speed {
void LynxBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->lynxes[d.lynx_definition-1];const auto handle=s.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,handle)) && EnemySystem::attack_due(r,handle,dt)) {
        if (!budget.request({owner,{AttackCategory::Aimed},handle,p.warn+0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    const auto delta=e.pos-s.enemy_aim;const auto u=delta/std::max(1.0,double(delta.length()));const auto room=s.view_half-godot::Vector2(1,1)*(e.radius+40.0);
    const auto goal=(s.enemy_aim+u*p.keep).clamp(s.view_center-room,s.view_center+room);
    EnemyMotion::steer(e,goal,e.speed,p.accel,dt,tracking);EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),d.turn,dt,tracking);
    if (!GunnerTiming::advance(e.fire_t,e.charge,dt,p.warn,d.fire_interval)) return;
    auto &state=std::get<LynxState>(e.behavior_state);const double side=state.buds%2==0?1:-1;state.buds=state.buds==INT32_MAX?INT32_MIN:state.buds+1;
    const double angle=tracking.angle(e.facing,(s.ship_pos-e.pos).angle());SlashParams shot;shot.position=e.pos+godot::Vector2::from_angle(angle)*e.radius;shot.angle=angle;shot.speed=p.slash_speed;shot.size=p.slash_size;shot.range=p.slash_range;shot.damage=p.damage;shot.side=side;
    if (e.attack_managed) shot.budget.value=budget.token(owner);SlashSystem::emit(r,shot);
}
}
