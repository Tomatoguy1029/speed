#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;

Ref<SpeedRunCore> SpeedRunCore::checkpoint() const {
    if (!runtime.state.started || runtime.state.closed) return Ref<SpeedRunCore>();
    Ref<SpeedRunCore> out; out.instantiate();
    // タイマー、時計の端数、格納行、空き行、命中集合、待機中の枠も含む値コピー。
    out->runtime.state = runtime.state;
    out->runtime.content = runtime.content;
    out->runtime.state.rng.instantiate(); out->runtime.state.rng->set_seed(runtime.state.rng->get_seed()); out->runtime.state.rng->set_state(runtime.state.rng->get_state());
    // Dictionary/Arrayは共有書込みなので、可変の保持値を明示的に分離する。
    out->runtime.state.events=runtime.state.events.duplicate(true); out->runtime.state.collections=runtime.state.collections.duplicate(true);
    out->runtime.state.progression.data=runtime.state.progression.data.duplicate(true); out->runtime.state.progression.stats=runtime.state.progression.stats.duplicate(true);
    out->runtime.state.progression.weapons=runtime.state.progression.weapons.duplicate(true); out->runtime.state.progression.traits=runtime.state.progression.traits.duplicate(true);
    out->runtime.state.progression.cards=runtime.state.progression.cards.duplicate(true); out->runtime.state.progression.resource_requests=runtime.state.progression.resource_requests.duplicate(true);
    out->runtime.state.forward_parameters=runtime.state.forward_parameters.duplicate(true);
    return out;
}
bool SpeedRunCore::update_enemy_definition(StringName id, const Dictionary &data) {
    if (!runtime.state.started || runtime.state.closed) return false;
    auto found=std::find_if(runtime.content->definitions.begin(),runtime.content->definitions.end(),[&](const auto &d){return d.id==id;});
    if (found==runtime.content->definitions.end()) return false;
    Ref<SpeedRunCore> parsed; parsed.instantiate();
    if (!parsed->configure(data) || parsed->runtime.content->definitions.size()!=1 || parsed->runtime.content->definitions[0].id!=id || parsed->runtime.content->definitions[0].kind!=found->kind) return false;
    const auto previous=*found, replacement=parsed->runtime.content->definitions[0];
    const size_t index=found-runtime.content->definitions.begin();
    const double old_hp=previous.scaling.ready?previous.scaling.hp:previous.hp;
    const double new_hp=replacement.scaling.ready?replacement.scaling.hp:replacement.hp;
    const double old_armor=previous.scaling.ready?previous.scaling.armor:previous.armor;
    const double new_armor=replacement.scaling.ready?replacement.scaling.armor:replacement.armor;
    for (auto &e:runtime.state.enemies) {
        if (!e.alive || e.dead || e.definition!=index) continue;
        const double scale=std::sqrt(e.max_hp/std::max(old_hp*(previous.scaling.ready?previous.scaling.hp_mult:1.0)*(e.elite?3.0:1.0),0.001));
        if (new_hp!=old_hp) {
            const double health=e.hp/std::max(e.max_hp,0.001);
            e.max_hp*=new_hp/std::max(old_hp,0.001); e.hp=e.max_hp*health;
        }
        if (new_armor!=old_armor) e.armor=old_armor>0?e.armor*new_armor/old_armor:new_armor*scale*(replacement.scaling.ready?replacement.scaling.armor_mult:1.0)*(e.elite?1.3:1.0);
        if (replacement.speed!=previous.speed) e.speed=previous.speed>0?e.speed*replacement.speed/previous.speed:replacement.speed;
        if (previous.fire_interval>0 && replacement.fire_interval!=previous.fire_interval) e.fire_t*=replacement.fire_interval/previous.fire_interval;
    }
    auto definitions = runtime.content->definitions;
    definitions[index] = replacement;
    runtime.replace_definitions(std::move(definitions)); return true;
}
