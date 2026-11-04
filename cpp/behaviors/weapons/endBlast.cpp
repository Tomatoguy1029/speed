#include "endBlast.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/zone.h"
#include "../../state/loadout_state.h"
#include <algorithm>
#include <godot_cpp/core/math.hpp>
namespace speed {
namespace {
void blast(RunRuntime &run,const EndBlastPending &b) {
    auto &weapon=run.state.loadout->end_blast;
    if (ZoneSystem::explode(run,b.pos,b.radius,b.damage,Cause::EndBlast,weapon.knock,0.6)) weapon.visuals.push_back({b.pos,b.radius,0,weapon.next_visual++});
}
}
void EndBlastBehavior::end(RunRuntime &run) {
    auto &weapon=run.state.loadout->end_blast;if (!weapon.ready) return;
    const auto center=run.state.ship.pos;
    const double radius=weapon.radius*run.state.loadout->effects.area;
    const double damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,weapon.definition)*weapon.damage;
    blast(run,{center,radius,damage,0});
    const double offset=run.state.control.rng.randf()*godot::Math::TAU;
    for (uint32_t i=0;i<weapon.secondary;++i) {
        const double angle=double(i)*godot::Math::TAU/weapon.secondary+offset;
        weapon.pending.push_back({center+godot::Vector2::from_angle(angle)*radius*run.state.control.rng.randf_range(0.9,1.1),radius*weapon.secondary_radius,damage*weapon.secondary_damage,weapon.secondary_delay+i*weapon.secondary_step});
    }
}
void EndBlastBehavior::step(RunRuntime &run,double dt) {
    auto &weapon=run.state.loadout->end_blast;if (!weapon.ready || dt<=0) return;
    for (auto &visual:weapon.visuals) visual.age+=dt;
    weapon.visuals.erase(std::remove_if(weapon.visuals.begin(),weapon.visuals.end(),[](const auto &v){return v.age>=0.95;}),weapon.visuals.end());
    for (auto &pending:weapon.pending) {pending.delay-=dt;if (pending.delay<=0) blast(run,pending);}
    weapon.pending.erase(std::remove_if(weapon.pending.begin(),weapon.pending.end(),[](const auto &v){return v.delay<=0;}),weapon.pending.end());
}
}
