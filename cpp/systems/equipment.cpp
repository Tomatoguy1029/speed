#include "equipment.h"
#include "../behaviors/weapons/forward.h"
#include <algorithm>
namespace speed {
void EquipmentSystem::refresh_effects(RunRuntime &run) {
    auto &effects=run.state.loadout.effects;
    effects.area=effects.shot_amount=1;effects.full_gauge_rate=0;
    for (const auto &owned:run.state.loadout.traits) {
        for (const auto &level:run.content->numeric_traits) if (level.equipment==owned.definition && level.level==owned.level) {
            effects.area+=level.area_bonus;effects.shot_amount+=level.shot_bonus;effects.full_gauge_rate+=level.full_gauge_rate;
        }
    }
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
bool EquipmentSystem::remove_weapon(RunRuntime &run,uint32_t id) {
    auto &owned=run.state.loadout.weapons;
    auto current=std::find_if(owned.begin(),owned.end(),[&](const auto &v){return v.definition==id;});
    if (current==owned.end() || !id || id>run.content->equipment.size() || run.content->equipment[id-1].external_id!="W01") return false;
    // 発射済みの自然寿命の弾は、装備の解除後も残す。
    run.state.forward={};owned.erase(current);refresh_effects(run);return true;
}
}
