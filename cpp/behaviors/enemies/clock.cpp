#include "clock.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attack_system.h"
#include "../../systems/attacks/wall.h"
namespace speed {
void ClockBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->clocks[d.clock_definition-1];const auto self=s.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    const bool allowed=!e.attack_managed || (budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) || budget.request({owner,{AttackCategory::Residue},self,p.warn+0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight});
    e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);if (!allowed) {e.charge=0;return;}
    auto &state=std::get<ClockState>(e.behavior_state);bool owns=true;
    for (auto hand:state.hands) {const auto *record=AttackSystem::get(s,hand);if (!record || !record->spec.owner.attached || !same_handle(record->spec.owner.live_source,self)) owns=false;}
    if (!owns) {
        for (size_t k=0;k<2;++k) {WallParams wall;wall.position=e.pos;wall.length=k==0?p.hand_long:p.hand_short;wall.half_width=p.hand_width*0.5;wall.delay=p.warn;wall.active=1e9;wall.damage=p.damage;wall.color=d.color;wall.owner=self;wall.attached=true;if (e.attack_managed) wall.budget.value=budget.token(owner);state.hands[k]=WallSystem::emit(r,wall);}
    }
    e.spin+=dt;WallSystem::move(r,state.hands[0],e.pos,e.spin*p.long_speed);WallSystem::move(r,state.hands[1],e.pos,e.spin*p.short_speed+godot::Math::PI);
}
}
