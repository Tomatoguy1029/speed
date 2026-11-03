#include "strike_shape.h"
#include "../../systems/combat_resolver.h"
namespace speed {
void MonocerosStrike::damage(RunRuntime &r,TechniqueState &t,const godot::PackedVector2Array &before,const godot::PackedVector2Array &points,double width) {
    if (t.hit || t.stage!=TechniqueStage::Active) return;
    const SweptSegment shape{before[0],before[1],points[0],points[1],width*0.5};
    if (!r.state.observations.check(t.observation_id,CollisionQuery::touches(shape,{t.previous_ship,r.state.ship_pos,r.state.ship_config.ship_radius},{true,true}))) return;
    ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=r.content->boss_techniques[t.definition-1].damage;request.scale=DamageScale::AtkScale;request.cause=Cause::Horn;
    request.source=r.state.enemies[t.actor.slot].definition+1;request.technique=t.definition;
    CombatResolver::ship_damage(r,request);t.hit=true;
}
}
