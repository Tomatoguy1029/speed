#include "knockback.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/friend_debris.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include <algorithm>
#include <cmath>
namespace speed {
void KnockbackBehavior::defeated(RunRuntime &run,const DeathContext &death) {
    auto &k=run.state.loadout->knockback;const auto &p=*run.state.loadout;
    const auto depth=death.request.shatter_depth;
    if (!k.ready || death.hull_used || !death.one_shot || depth<0 || uint32_t(depth)>k.chain_limit) return;
    if (run.state.control.rng.randf()>=k.chance*std::pow(0.5,depth)) return;
    DebrisScatterParams scatter;scatter.source=death.target;scatter.direction=death.request.direction;scatter.shatter_depth=depth+1;
    scatter.speed=k.speed*(1+k.projectile_increment*double(p.post_projectile_speed_stacks));
    scatter.damage=k.base_attack>0?k.base_damage*CombatResolver::attack_power(run)/k.base_attack*EquipmentSystem::weapon_damage_factor(run,k.definition):0;
    scatter.knock=k.base_knock*(1+k.knockback_increment*double(p.post_knockback_stacks));
    scatter.radius_mult=p.effects.area*(1+k.area_increment*double(p.post_area_stacks));
    scatter.life_mult=k.base_life>0?k.life/k.base_life*(1+k.duration_increment*double(p.post_duration_stacks)):0;
    EventBuilder::flush_combat(run);
    if (FriendDebrisSystem::scatter(run,scatter)) k.visuals.push_back({death.corpse.pos,++k.serial,false,run.state.world_time});
}
void KnockbackBehavior::step(RunRuntime &run,double) {
    auto &k=run.state.loadout->knockback;
    k.visuals.erase(std::remove_if(k.visuals.begin(),k.visuals.end(),[&](const auto &v){return run.state.world_time-v.born_world_time>=(v.hit?0.3:0.8);}),k.visuals.end());
}
void KnockbackBehavior::hit(RunRuntime &run,godot::Vector2 position) {auto &k=run.state.loadout->knockback;if (k.ready) k.visuals.push_back({position,++k.serial,true,run.state.world_time});}
}
