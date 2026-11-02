#include "equipment.h"
#include "../behaviors/weapons/forward.h"
#include <algorithm>
namespace speed {
void EquipmentSystem::refresh_effects(RunRuntime &run) {
    auto &effects=run.state.loadout.effects;
    effects.area=effects.shot_amount=1;effects.full_gauge_rate=0;double charge_bonus=0,capacity_bonus=0,crit_bonus=0;
    for (const auto &owned:run.state.loadout.traits) {
        for (const auto &level:run.content->numeric_traits) if (level.equipment==owned.definition && level.level==owned.level) {
            effects.area+=level.area_bonus;effects.shot_amount+=level.shot_bonus;effects.full_gauge_rate+=level.full_gauge_rate;charge_bonus+=level.charge_bonus;capacity_bonus+=level.capacity_bonus;crit_bonus+=level.crit_bonus;
        }
    }
    run.state.draw_config.capacity=1.0+capacity_bonus;
    const auto &p=run.state.loadout;const auto &post=run.content->post_charge;
    const double base=run.content->config.draw_config_charge_time*p.charge_profile_factor/(1.0+charge_bonus);
    const double floor=std::min(base,std::max(post.minimum_time,base*post.minimum_ratio));
    run.state.draw_config.charge_time=std::max(floor,base*(1.0-post.increment*double(p.post_charge_stacks)));
    const auto &crit=run.content->post_crit;const double crit_base=run.content->config.combat_crit_chance;
    const double cap=std::min(1.0,crit.trait_maximum),trained=std::min(cap,crit_base+crit.trained_bonus);
    const double reserve=std::max(0.0,cap-trained);
    run.state.combat_config.crit_chance=std::min(crit.trait_maximum,crit_base+crit_bonus)+std::min(reserve,crit.increment*double(p.post_crit_stacks));
}
bool EquipmentSystem::grant(RunRuntime &run,uint32_t id,uint32_t levels) {
    if (!levels || !id || id>run.content->equipment.size()) return false;
    const auto &d=run.content->equipment[id-1];
    auto &owned=d.kind==0?run.state.loadout.weapons:run.state.loadout.traits;
    auto current=std::find_if(owned.begin(),owned.end(),[&](const auto &v){return v.definition==id;});
    const uint32_t old=current==owned.end()?0:current->level;
    if (old>=d.maximum_level || (!old && owned.size()>=(d.kind==0?run.content->progression.weapon_slots:run.content->progression.trait_slots))) return false;
    const uint32_t next=old+std::min(levels,d.maximum_level-old);
    if (d.kind==0) {
        if (d.external_id!="W01") return false;
        const auto &level=run.content->forward_levels[next-1];auto &forward=run.state.forward;
        if (forward.ready) ForwardBehavior::set_interval(forward,level.interval);
        else {forward={};forward.base_interval=forward.interval=forward.fire.remaining=level.interval;}
        forward.damage=level.damage;forward.pierce=level.pierce;forward.life=level.life;forward.spread=level.spread;forward.knock=level.knock;
        forward.character_scale=run.content->config.character_scale;forward.ready=true;
    } else if (std::none_of(run.content->numeric_traits.begin(),run.content->numeric_traits.end(),[&](const auto &v){return v.equipment==id && v.level==next;})) return false;
    if (current==owned.end()) owned.push_back({id,next});else current->level=next;
    refresh_effects(run);
    if (std::find(run.state.lifecycle.obtained.begin(),run.state.lifecycle.obtained.end(),id)==run.state.lifecycle.obtained.end()) run.state.lifecycle.obtained.push_back(id);
    return true;
}
bool EquipmentSystem::remove_trait(RunRuntime &run,uint32_t id) {
    auto &owned=run.state.loadout.traits;const auto found=std::find_if(owned.begin(),owned.end(),[&](const auto &item){return item.definition==id;});
    if (found==owned.end()) return false;
    owned.erase(found);refresh_effects(run);return true;
}
bool EquipmentSystem::remove_weapon(RunRuntime &run,uint32_t id) {
    auto &owned=run.state.loadout.weapons;
    auto current=std::find_if(owned.begin(),owned.end(),[&](const auto &v){return v.definition==id;});
    if (current==owned.end() || !id || id>run.content->equipment.size() || run.content->equipment[id-1].external_id!="W01") return false;
    // 発射済みの自然寿命の弾は、装備の解除後も残す。
    run.state.forward={};owned.erase(current);refresh_effects(run);return true;
}
}
