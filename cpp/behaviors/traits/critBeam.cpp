#include "critBeam.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/light_lances.h"
namespace speed {
void CritBeamBehavior::critical(RunRuntime &run,const DamageRequest &request,const DamageResult &result) {
    auto &c=run.state.loadout.crit_beam;
    if (!c.ready || run.state.time<c.next_time || run.state.phase!=godot::RunState::Phase::Play) return;
    c.next_time=run.state.time+c.cooldown;
    const auto velocity=run.state.ship.vel;
    const auto direction=velocity.length()>1?velocity.normalized():run.state.ship.heading;
    auto position=request.impact;
    if (!request.has_impact) position=run.state.enemy_handles.contains(result.target)?run.state.enemies[result.target.slot].pos:run.state.ship.pos;
    LightLanceParams p;p.position=position;p.direction=direction;p.length=c.length;p.width=c.width*run.state.loadout.effects.area;p.damage=CombatResolver::attack_power(run)*c.damage;p.knock=c.knock;
    LightLancesSystem::fire(run,p);
}
}
