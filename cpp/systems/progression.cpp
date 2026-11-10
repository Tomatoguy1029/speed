#include "progression.h"
#include "equipment.h"
#include "fuel.h"
#include "../api/run_core.h"
#include "../behaviors/weapons/forward.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <climits>
using namespace godot;
namespace speed {
namespace {
const PostMaxDefinition *post_definition(const RunRuntime &r,const std::string &id) {
    for (const auto &d:r.content->post_max) if (d.external_id==id) return &d;return nullptr;
}
uint64_t count(const LoadoutState &s,const std::string &id) {
    // 選択と開発命令で同じ対応表を参照する。ここでは書き換えない。
    auto &mutable_state=const_cast<LoadoutState &>(s);const auto *p=ProgressionSystem::post_stacks(mutable_state,id);return p?*p:0;
}
double baseline(const RunRuntime &r,const std::string &id) {
    const auto &s=r.state;const auto &c=r.content->config;const auto &p=*s.loadout;
    if (id=="max_speed") return s.ship_config.max_speed/(1+ProgressionSystem::post_amount(r,id));
    if (id=="max_hp") return c.ship_config_max_hp+p.hp_profile_add;
    if (id=="crit_chance") return s.combat_config.crit_chance-ProgressionSystem::post_effect(r,id);
    if (id=="crit_mult") return c.combat_crit_mult;
    if (id=="pickup_radius") return s.pickup_config.coin_radius;
    if (id=="line_length") return s.draw_config.length*s.draw_config.length_mult/(1+ProgressionSystem::post_amount(r,id));
    if (id=="charge_time") return p.fuel_gain_profile_factor;
    if (id=="xp_gain") return s.pickup_config.xp_mult*p.xp_profile_factor;
    if (id=="acceleration") return c.ship_config_acceleration;
    if (id=="turn_rate") return c.ship_config_turn_rate;
    if (id=="invulnerability") return c.ship_config_invulnerability;
    if (id=="repair") return c.pickup_repair_fraction;
    if (id=="pickup_speed") return 1;
    return 0;
}
bool has_baseline(const std::string &id) {
    return id=="max_speed" || id=="max_hp" || id=="crit_chance" || id=="crit_mult" || id=="pickup_radius" || id=="line_length" || id=="charge_time" || id=="xp_gain" || id=="acceleration" || id=="turn_rate" || id=="invulnerability" || id=="repair" || id=="pickup_speed";
}
double current_value(const RunRuntime &r,const std::string &id,uint64_t extra) {
    const double effect=ProgressionSystem::post_effect(r,id,extra),base=baseline(r,id);
    if (id=="charge_time") return (base+effect)*100;
    if (id=="max_hp" || id=="crit_chance" || id=="crit_mult" || id=="invulnerability" || id=="repair") return (base+effect)*(id=="crit_chance" || id=="repair"?100:1);
    return base*(1+effect);
}
Dictionary post_info(const RunRuntime &r,uint32_t effect) {
    const auto &d=r.content->post_max[effect-1];const auto &id=d.external_id;
    const double a=ProgressionSystem::post_effect(r,id),b=ProgressionSystem::post_effect(r,id,1);
    Dictionary out;out["post_id"]=String::utf8(id.c_str());out["before"]=a;out["after"]=b;out["change"]=b-a;out["increment"]=d.increment;
    out["has_current"]=has_baseline(id);out["current_before"]=current_value(r,id,0);out["current_after"]=current_value(r,id,1);
    out["hp_before"]=r.state.ship.hp;out["hp_after"]=std::min(r.state.ship_config.max_hp,r.state.ship.hp+r.state.ship_config.max_hp*d.increment);
    const bool fixed=id=="max_hp" || id=="crit_mult" || id=="invulnerability";
    out["total_before"]=fixed?a:a*100;
    out["total_after"]=fixed?b:b*100;
    out["unit"]=id=="max_hp"?"HP":id=="crit_mult"?"×":id=="invulnerability"?"s":"%";
    Array intervals,targets;
    for (const auto &weapon:r.state.loadout->weapons) {
        for (const auto &target:r.content->post_max_targets) if (target.equipment==weapon.definition && target.effect==effect && (id=="area" || id=="followup")) targets.append("postmax.target."+String::utf8(r.content->equipment[weapon.definition-1].external_id.c_str())+"."+String::utf8(id.c_str()));
        if (id!="weapon_interval") continue;
        for (const auto &v:r.content->post_max_intervals) if (v.equipment==weapon.definition && v.level==weapon.level) {
            const double before=ProgressionSystem::post_reduced(r,id,v.base),after=ProgressionSystem::post_reduced(r,id,v.base,1);if (std::abs(before-after)<=0.000001) continue;
            Dictionary row;row["weapon"]=String::utf8(r.content->equipment[weapon.definition-1].external_id.c_str());row["parameter"]=String::utf8(v.parameter.c_str());row["before"]=before;row["after"]=after;row["reduction_before"]=(1-before/v.base)*100;row["reduction_after"]=(1-after/v.base)*100;intervals.append(row);
        }
    }
    out["intervals"]=intervals;out["targets"]=targets;return out;
}
}
uint64_t *ProgressionSystem::post_stacks(LoadoutState &p,const std::string &id) {
    if (id=="weapon_damage") return &p.post_weapon_damage_stacks;
    if (id=="weapon_interval") return &p.post_weapon_interval_stacks;
    if (id=="projectile_speed") return &p.post_projectile_speed_stacks;
    if (id=="duration") return &p.post_duration_stacks;
    if (id=="knockback") return &p.post_knockback_stacks;
    if (id=="crit_chance") return &p.post_crit_stacks;
    if (id=="crit_mult") return &p.post_crit_mult_stacks;
    if (id=="area") return &p.post_area_stacks;
    if (id=="followup") return &p.post_followup_stacks;
    if (id=="max_speed") return &p.post_max_speed_stacks;
    if (id=="acceleration") return &p.post_acceleration_stacks;
    if (id=="turn_rate") return &p.post_turn_rate_stacks;
    if (id=="line_length") return &p.post_line_length_stacks;
    if (id=="charge_time") return &p.post_charge_stacks;
    if (id=="max_hp") return &p.post_max_hp_stacks;
    if (id=="invulnerability") return &p.post_invulnerability_stacks;
    if (id=="repair") return &p.post_repair_stacks;
    if (id=="pickup_radius") return &p.post_xp_pickup_stacks;
    if (id=="pickup_speed") return &p.post_pickup_speed_stacks;
    if (id=="xp_gain") return &p.post_xp_gain_stacks;
    return nullptr;
}
double ProgressionSystem::post_amount(const RunRuntime &r,const std::string &id) {
    const auto *d=post_definition(r,id);return d?d->increment*double(count(*r.state.loadout,id)):0;
}
double ProgressionSystem::post_reduced(const RunRuntime &r,const std::string &id,double base,uint64_t extra) {
    const auto *d=post_definition(r,id);if (!d) return base;
    return std::max(std::min(base,std::max(d->minimum_time,base*d->minimum_ratio)),base*(1-d->increment*(double(count(*r.state.loadout,id))+double(extra))));
}
double ProgressionSystem::post_effect(const RunRuntime &r,const std::string &id,uint64_t extra) {
    const auto *d=post_definition(r,id);if (!d) return 0;
    const double amount=d->increment*(double(count(*r.state.loadout,id))+double(extra));
    if (id=="crit_chance") {const auto &crit=r.content->post_crit;const double cap=std::min(1.0,crit.trait_maximum);return std::min(std::max(0.0,cap-std::min(cap,r.content->config.combat_crit_chance+crit.trained_bonus)),amount);}
    if (id=="invulnerability" || id=="repair") return std::min(std::max(0.0,d->maximum-baseline(r,id)),amount);
    if (id=="weapon_interval") return std::min(1-d->minimum_ratio,amount);
    if (id=="charge_time") return std::min(std::max(0.0,r.state.draw_config.fuel_gain_max-std::max(0.0,r.state.loadout->fuel_gain_profile_factor-1.0)),amount);
    return amount;
}
bool ProgressionSystem::normal_complete(const RunRuntime &r) {
    const auto &p=*r.state.loadout;if (p.weapons.size()<r.content->progression.weapon_slots || p.traits.size()<r.content->progression.trait_slots) return false;
    for (const auto *list:{&p.weapons,&p.traits}) for (const auto &e:*list) if (e.level<r.content->equipment[e.definition-1].maximum_level) return false;return true;
}
bool ProgressionSystem::post_eligible(const RunRuntime &r,uint32_t effect) {
    if (!effect || effect>r.content->post_max.size()) return false;const auto &d=r.content->post_max[effect-1];const auto &id=d.external_id;
    if (d.increment<=0 || count(*r.state.loadout,id)>=UINT32_MAX-1) return false;
    if (id=="heal") return r.state.ship.hp<r.state.ship_config.max_hp;
    if (id=="weapon_interval" || id=="projectile_speed" || id=="duration" || id=="knockback" || id=="area" || id=="followup") {
        bool target=false;
        for (const auto &w:r.state.loadout->weapons) for (const auto &v:r.content->post_max_targets) if (v.equipment==w.definition && v.effect==effect) {
            if (id!="weapon_interval") target=true;
            else for (const auto &base:r.content->post_max_intervals) if (base.equipment==w.definition && base.level==w.level && post_reduced(r,id,base.base,1)<post_reduced(r,id,base.base)-0.000001) target=true;
        }
        if (!target) return false;
    }
    return std::abs(post_effect(r,id,1)-post_effect(r,id))>0.000001;
}

namespace {
const LoadoutDefinition *definition(const RunRuntime &run,uint32_t id) {
    for (const auto &d:run.content->equipment) if (d.id==id) return &d;
    return nullptr;
}
uint32_t level_of(const std::vector<EquipmentLevel> &owned,uint32_t id) {
    for (const auto &e:owned) if (e.definition==id) return e.level;
    return 0;
}
ResourceRequest *request_for(RunRuntime &run,int64_t candidate) {
    for (auto &r:run.resource_workspace.requests) if (r.offer_id==run.state.loadout->offer_id && (r.candidate_id==candidate || (run.state.loadout->comet_weapon && r.candidate_id==1))) return &r;
    return nullptr;
}
const ResourceRequest *request_for(const RunRuntime &run,int64_t candidate) {
    for (const auto &r:run.resource_workspace.requests) if (r.offer_id==run.state.loadout->offer_id && (r.candidate_id==candidate || (run.state.loadout->comet_weapon && r.candidate_id==1))) return &r;
    return nullptr;
}
CardCandidate *candidate_for(RunRuntime &run,int64_t id) {
    for (auto &c:run.state.loadout->candidates) if (c.id==id) return &c;
    return nullptr;
}
std::vector<CardCandidate> roll(RunRuntime &run,bool initial) {
    auto &state=*run.state.loadout;const auto &config=run.content->progression;
    struct Weighted {CardCandidate card;double weight;};std::vector<Weighted> pool;
    const bool enhanced=!initial && ProgressionSystem::normal_complete(run);
    if (enhanced) for (const auto &d:run.content->post_max) if (ProgressionSystem::post_eligible(run,d.id)) pool.push_back({{0,CardKind::PostMax,d.id,uint32_t(count(state,d.external_id)+1)},1.0});
    for (const auto &d:run.content->equipment) {
        const bool weapon=d.kind==0;const auto &owned=weapon?state.weapons:state.traits;
        if ((initial && !weapon) || (weapon && d.comet_only)) continue;
        const auto level=level_of(owned,d.id),slots=weapon?config.weapon_slots:config.trait_slots;
        if (!initial && (level>=d.maximum_level || (!level && owned.size()>=slots))) continue;
        pool.push_back({{0,weapon?CardKind::Weapon:CardKind::Trait,d.id,initial?1:level+1},level?config.owned_card_bias:1.0});
    }
    std::vector<CardCandidate> cards;const auto count=initial?config.start_weapon_choices:3;
    if (enhanced && !pool.empty()) {const auto index=run.state.control.rng.randi_range(0,pool.size()-1).value();auto card=pool[index].card;card.id=1;cards.push_back(card);pool.erase(pool.begin()+index);}
    while (cards.size()<count && !pool.empty()) {
        size_t index=0;
        if (initial) index=run.state.control.rng.randi_range(0,pool.size()-1).value();
        else {
            double total=0;for (const auto &p:pool) total+=p.weight;
            double choice=run.state.control.rng.randf()*total;
            while (index+1<pool.size() && choice>=pool[index].weight) choice-=pool[index++].weight;
        }
        auto card=pool[index].card;card.id=cards.size()+1;cards.push_back(card);pool.erase(pool.begin()+index);
    }
    return cards;
}
void issue(RunRuntime &run,const CardCandidate &card) {
    if (run.resource_workspace.next_id==INT64_MAX) return;
    ResourceRequest request;request.id=run.resource_workspace.next_id++;request.offer_id=run.state.loadout->offer_id;request.candidate_id=card.id;
    for (const auto &a:run.content->equipment_assets) if (card.kind!=CardKind::PostMax && a.equipment==(run.state.loadout->comet_weapon?run.state.loadout->comet_weapon:card.definition)) request.asset_keys.push_back(a.asset);
    if (card.kind==CardKind::PostMax) request.status=ResourceStatus::Ready;
    run.resource_workspace.requests.push_back(std::move(request));
}
void publish(RunRuntime &run,std::vector<CardCandidate> cards,bool initial) {
    auto &p=*run.state.loadout;
    p.candidates=std::move(cards);p.initial_offer=initial;p.offer_id=p.next_offer_id++;p.selected_id=0;
    ProgressionSystem::rebuild_requests(run);run.state.phase=RunState::Phase::LevelUp;run.state.hitstop=0;
    Dictionary event;event["offer_id"]=p.offer_id;event["initial"]=initial;event["count"]=int64_t(p.candidates.size());FrameBuilder::append(run,"offer",event);
}
bool grant(RunRuntime &run,const CardCandidate &card) {
    if (card.kind==CardKind::PostMax) {
        if (!ProgressionSystem::normal_complete(run) || !ProgressionSystem::post_eligible(run,card.definition)) return false;
        const auto &d=run.content->post_max[card.definition-1];
        if (d.external_id=="heal") run.state.ship.hp=std::min(run.state.ship_config.max_hp,run.state.ship.hp+run.state.ship_config.max_hp*d.increment);
        else {auto *stacks=ProgressionSystem::post_stacks(*run.state.loadout,d.external_id);if (!stacks) return false;++*stacks;EquipmentSystem::refresh_effects(run);}
        return true;
    }
    const auto *d=definition(run,card.definition);if (!d || card.level>d->maximum_level) return false;
    const auto &owned=d->kind==0?run.state.loadout->weapons:run.state.loadout->traits;
    return level_of(owned,card.definition)+1==card.level && EquipmentSystem::grant(run,card.definition);

}
Dictionary card_value(const RunRuntime &run,const CardCandidate &card) {
    Dictionary value;value["candidate_id"]=card.id;value["kind"]=symbol_name(card.kind);
    if (card.kind==CardKind::PostMax) {value["id"]=String::utf8(run.content->post_max[card.definition-1].external_id.c_str());value["level"]=int64_t(card.level);value["info"]=post_info(run,card.definition);value["request_id"]=0;return value;}
    const auto *d=definition(run,card.definition);value["id"]=String::utf8(d?d->external_id.c_str():"");value["level"]=card.level;
    if (run.state.loadout->comet_weapon) {const auto &target=run.content->equipment[run.state.loadout->comet_weapon-1];value["new"]=String::utf8(target.external_id.c_str());value["resource_kind"]="weapon";value["resource_id"]=value["new"];value["resource_level"]=target.maximum_level;if (card.kind==CardKind::Keep) value["id"]="keep";}
    if (run.state.loadout->initial_offer) value["start"]=true;
    const auto *r=request_for(run,card.id);value["request_id"]=r?r->id:0;return value;
}
void notify_grant(RunRuntime &run,const CardCandidate &card) {
    Dictionary event;event["kind"]=symbol_name(card.kind);event["id"]=String::utf8((card.kind==CardKind::PostMax?run.content->post_max[card.definition-1].external_id:definition(run,card.definition)->external_id).c_str());event["level"]=card.level;
    FrameBuilder::append(run,"loadout",event);
}
}
bool ProgressionSystem::development(SpeedRunCore &core,const String &kind,const Dictionary &data) {
    auto &r=core.runtime;auto &p=*r.state.loadout;
    if (kind=="comet_weapon") {
        if (data.size()!=1 || data.get("id",Variant()).get_type()!=Variant::STRING) return false;
        const String id=data["id"];for (const auto &d:r.content->equipment) if (d.comet_only && String::utf8(d.external_id.c_str())==id) {p.pending_comet_weapons.push_back(d.id);return true;}return false;
    }
    if (kind=="post_max") {
        if (data.size()!=1 || data.get("stacks",Variant()).get_type()!=Variant::DICTIONARY) return false;
        const Dictionary values=data["stacks"];auto next=p;
        for (const auto &d:r.content->post_max) if (auto *n=post_stacks(next,d.external_id)) *n=0;
        for (auto key:values.keys()) {
            if (key.get_type()!=Variant::STRING && key.get_type()!=Variant::STRING_NAME) return false;const String id=key;
            const auto *d=post_definition(r,id.utf8().get_data());if (!d || values[key].get_type()!=Variant::INT || int64_t(values[key])<0 || int64_t(values[key])>=UINT32_MAX) return false;
            auto *n=post_stacks(next,d->external_id);if (!n) return false;*n=uint64_t(int64_t(values[key]));
        }
        p=std::move(next);EquipmentSystem::refresh_effects(r);return true;
    }
    if (kind=="progression") {
        for (auto key:data.keys()) if (String(key)!="hp" && String(key)!="pending_levels") return false;
        if (data.has("hp") && ((data["hp"].get_type()!=Variant::FLOAT && data["hp"].get_type()!=Variant::INT) || !std::isfinite(double(data["hp"])) || double(data["hp"])<0 || double(data["hp"])>r.state.ship_config.max_hp)) return false;
        if (data.has("pending_levels") && (data["pending_levels"].get_type()!=Variant::INT || int64_t(data["pending_levels"])<0 || int64_t(data["pending_levels"])>10000)) return false;
        if (data.has("hp")) r.state.ship.hp=data["hp"];
        if (data.has("pending_levels")) p.pending_levels=data["pending_levels"];
        return true;
    }
    if (kind=="post_max_offer") {
        if (data.size()!=1 || data.get("ids",Variant()).get_type()!=Variant::PACKED_STRING_ARRAY || !normal_complete(r) || r.state.phase!=RunState::Phase::Play || p.next_offer_id==INT64_MAX) return false;
        const PackedStringArray ids=data["ids"];if (ids.is_empty() || ids.size()>3) return false;std::vector<CardCandidate> cards;
        for (const auto &id:ids) {const auto *d=post_definition(r,id.utf8().get_data());if (!d || !post_eligible(r,d->id)) return false;cards.push_back({int64_t(cards.size()+1),CardKind::PostMax,d->id,uint32_t(count(p,d->external_id)+1)});}
        if (!p.pending_levels) p.pending_levels=1;publish(r,std::move(cards),false);return true;
    }
    return false;
}
void ProgressionSystem::initialize(RunRuntime &run,bool initial) {
    auto &p=*run.state.loadout;const auto meta_levels=p.meta_levels;const double hp_add=p.hp_profile_add,xp_factor=p.xp_profile_factor,reroll_add=p.reroll_profile_add;const double charge_factor=p.fuel_gain_profile_factor,speed_factor=p.speed_profile_factor,attack_factor=p.attack_profile_factor,pickup_factor=p.pickup_profile_factor,length_factor=p.length_profile_factor;p={};p.fuel_gain_profile_factor=charge_factor;p.speed_profile_factor=speed_factor;p.attack_profile_factor=attack_factor;p.pickup_profile_factor=pickup_factor;p.length_profile_factor=length_factor;p.meta_levels=meta_levels;p.hp_profile_add=hp_add;p.xp_profile_factor=xp_factor;p.reroll_profile_add=reroll_add;p.ready=true;p.rerolls=run.content->progression.reroll_count+int64_t(std::llround(reroll_add));
    if (!initial) p.weapons.push_back({1,1});else run.state.forward.ready=false;
    EquipmentSystem::refresh_effects(run);
    FuelSystem::set(run,FuelSystem::maximum(run.state),true);
    run.resource_workspace.requests.clear();
}
double ProgressionSystem::next_xp(const RunRuntime &run) {
    const auto &c=run.content->progression;const double level=run.state.loadout->level;
    return c.xp_base+c.xp_growth*level+c.xp_curve*level*level;
}
bool ProgressionSystem::add_experience(SpeedRunCore &core,double amount) {
    auto &run=core.runtime;auto &p=*run.state.loadout;
    if (!p.ready || !std::isfinite(amount) || amount<0 || !std::isfinite(p.xp+amount) || !std::isfinite(p.xp_gained+amount)) return false;
    p.xp+=amount;p.xp_gained+=amount;
    while (p.xp>=next_xp(run)) {
        if (p.level==INT64_MAX || p.pending_levels==INT64_MAX) return false;
        p.xp-=next_xp(run);++p.level;++p.pending_levels;
        run.state.ship.hp=std::min(run.state.ship_config.max_hp,run.state.ship.hp+run.state.ship_config.max_hp*run.content->progression.level_heal);
        Dictionary event;event["level"]=p.level;core.emit_event("levelup",event);
        Dictionary text;text["pos"]=run.state.ship.pos+Vector2(0,-34);text["text"]=String("Lv ")+String::num_int64(p.level);text["color"]=Color::html("6dffb0");text["size"]=18;core.emit_event("text",text);
    }
    return true;
}
bool ProgressionSystem::open(SpeedRunCore &core,bool initial) {
    auto &run=core.runtime;auto &p=*run.state.loadout;
    if (!p.ready || run.state.phase!=RunState::Phase::Play || run.state.draw.drawing || run.state.draw.tracing || p.offer_id || p.next_offer_id==INT64_MAX) return false;
    if (!initial) while (!p.pending_comet_weapons.empty()) {
        const auto id=p.pending_comet_weapons.front();p.pending_comet_weapons.erase(p.pending_comet_weapons.begin());
        if (level_of(p.weapons,id)) continue;
        p.comet_weapon=id;p.comet_direct=p.weapons.size()<run.content->progression.weapon_slots;
        std::vector<CardCandidate> cards;
        if (p.comet_direct) cards.push_back({1,CardKind::Weapon,id,run.content->equipment[id-1].maximum_level});
        else {for (const auto &owned:p.weapons) cards.push_back({int64_t(cards.size()+1),CardKind::Swap,owned.definition,owned.level});cards.push_back({int64_t(cards.size()+1),CardKind::Keep,0,1});}
        publish(run,std::move(cards),false);if (p.comet_direct) p.selected_id=1;return true;
    }
    if (!initial && !p.pending_levels) return false;
    auto cards=roll(run,initial);if (cards.empty()) {p.pending_levels=0;return false;}
    publish(run,std::move(cards),initial);return true;
}
bool ProgressionSystem::choose(RunRuntime &run,int64_t offer,int64_t candidate) {
    auto &p=*run.state.loadout;
    if (run.state.phase!=RunState::Phase::LevelUp || p.offer_id!=offer || !candidate_for(run,candidate)) return false;
    p.selected_id=candidate;return true;
}
bool ProgressionSystem::choose_swap(RunRuntime &run,int64_t offer,int64_t candidate,const String &replace) {
    const auto *card=candidate_for(run,candidate);if (!card || card->kind!=CardKind::Swap || !run.state.loadout->comet_weapon) return false;
    const auto *d=definition(run,card->definition);return d && String::utf8(d->external_id.c_str())==replace && choose(run,offer,candidate);
}
bool ProgressionSystem::cancel(RunRuntime &run,int64_t offer) {
    if (run.state.phase!=RunState::Phase::LevelUp || run.state.loadout->offer_id!=offer || !offer) return false;
    run.state.loadout->selected_id=0;return true;
}
bool ProgressionSystem::reroll(SpeedRunCore &core,int64_t offer) {
    auto &p=*core.runtime.state.loadout;
    if (core.runtime.state.phase!=RunState::Phase::LevelUp || p.offer_id!=offer || !offer || p.comet_weapon || p.rerolls<=0 || p.next_offer_id==INT64_MAX) return false;
    auto cards=roll(core.runtime,p.initial_offer);if (cards.empty()) return false;
    --p.rerolls;publish(core.runtime,std::move(cards),p.initial_offer);core.emit_event("reroll");return true;
}
bool ProgressionSystem::complete(RunRuntime &run,int64_t id,int status) {
    if (status!=1 && status!=-1 && status!=-2) return false;
    for (auto &r:run.resource_workspace.requests) if (r.id==id && r.offer_id==run.state.loadout->offer_id && r.status==ResourceStatus::Pending) {r.status=ResourceStatus(status);return true;}
    return false;
}
bool ProgressionSystem::retry(RunRuntime &run,int64_t id) {
    if (run.resource_workspace.next_id==INT64_MAX) return false;
    for (auto &r:run.resource_workspace.requests) if (r.id==id && r.offer_id==run.state.loadout->offer_id && r.status==ResourceStatus::Failed) {
        r.id=run.resource_workspace.next_id++;r.status=ResourceStatus::Pending;return true;
    }
    return false;
}
void ProgressionSystem::rebuild_requests(RunRuntime &run) {
    run.resource_workspace.requests.clear();
    for (const auto &card:run.state.loadout->candidates) {issue(run,card);if (run.state.loadout->comet_weapon) break;}
}
void ProgressionSystem::poll(SpeedRunCore &core) {
    auto &run=core.runtime;auto &p=*run.state.loadout;
    if (run.state.phase!=RunState::Phase::LevelUp || !p.selected_id) return;
    const auto *request=request_for(run,p.selected_id);const auto *selected=candidate_for(run,p.selected_id);
    if (!selected || (selected->kind!=CardKind::Keep && (!request || request->status!=ResourceStatus::Ready))) return;
    const auto card=*selected;const auto offer=p.offer_id;const bool initial=p.initial_offer;const Dictionary chosen_value=card_value(run,card);
    if (p.comet_weapon) {
        if (card.kind!=CardKind::Keep) {
            const auto id=p.comet_weapon;const auto &d=run.content->equipment[id-1];
            if (card.kind==CardKind::Swap) {if (!EquipmentSystem::remove_weapon(run,card.definition)) return;CardCandidate removed{0,CardKind::Weapon,card.definition,0};notify_grant(run,removed);}
            if (!EquipmentSystem::grant(run,id,d.maximum_level)) return;
            CardCandidate gained{0,CardKind::Weapon,id,d.maximum_level};notify_grant(run,gained);
            if (card.kind==CardKind::Swap) {Dictionary event;event["card"]=chosen_value;core.emit_event("upgrade",event);}
            else {Dictionary text;text["pos"]=run.state.ship.pos+Vector2(0,-60);text["text"]=String::utf8(d.external_id.c_str());text["color"]=Color::html("efcb70");text["size"]=24;core.emit_event("text",text);}
        }
        Dictionary choice;choice["offer_id"]=offer;choice["candidate_id"]=card.id;choice["kind"]=symbol_name(card.kind);choice["id"]=chosen_value["id"];choice["level"]=card.level;core.emit_event("choice",choice);
        p.comet_weapon=0;p.comet_direct=false;p.candidates.clear();p.selected_id=p.offer_id=0;run.resource_workspace.requests.clear();run.state.phase=RunState::Phase::Play;open(core);return;
    }
    if (!grant(run,card)) {if (card.kind==CardKind::PostMax) publish(run,roll(run,false),false);return;}
    Dictionary choice;choice["offer_id"]=offer;choice["candidate_id"]=card.id;choice["kind"]=symbol_name(card.kind);choice["id"]=String::utf8((card.kind==CardKind::PostMax?run.content->post_max[card.definition-1].external_id:definition(run,card.definition)->external_id).c_str());choice["level"]=card.level;
    core.emit_event("choice",choice);notify_grant(run,card);
    if (!initial) {
        Dictionary event;event["card"]=chosen_value;core.emit_event("upgrade",event);
        int bonus_count=0;
        if (card.kind==CardKind::Weapon || card.kind==CardKind::Trait) for (double chance:{run.content->progression.levelup_bonus_chance,run.content->progression.levelup_bonus_more,run.content->progression.levelup_bonus_last}) {
            if (run.state.control.rng.randf()>=chance) break;
            std::vector<CardCandidate> targets;
            for (const auto *owned:{&p.weapons,&p.traits}) for (const auto &e:*owned) {const auto *d=definition(run,e.definition);if (e.level<d->maximum_level) targets.push_back({0,d->kind==0?CardKind::Weapon:CardKind::Trait,e.definition,e.level+1});}
            if (targets.empty()) break;
            const auto bonus=targets[run.state.control.rng.randi_range(0,targets.size()-1).value()];
            if (grant(run,bonus)) {notify_grant(run,bonus);Dictionary b;b["kind"]=symbol_name(bonus.kind);b["id"]=String::utf8(definition(run,bonus.definition)->external_id.c_str());b["level"]=bonus.level;b["count"]=++bonus_count;core.emit_event("level_bonus",b);}
        }
        --p.pending_levels;
    }
    p.candidates.clear();p.selected_id=p.offer_id=0;p.initial_offer=false;run.resource_workspace.requests.clear();run.state.phase=RunState::Phase::Play;
    if (!initial) open(core);
}
Dictionary ProgressionSystem::ui(const RunRuntime &run) {
    const auto &p=*run.state.loadout;Dictionary out,cards;Array candidates,weapons,traits;
    for (const auto &c:p.candidates) candidates.append(card_value(run,c));
    cards["offer_id"]=p.offer_id;cards["candidates"]=candidates;cards["selected_id"]=p.selected_id;cards["preparing"]=false;cards["error_code"]=0;cards["initial"]=p.initial_offer;cards["swap_pick"]=p.comet_weapon?String::utf8(run.content->equipment[p.comet_weapon-1].external_id.c_str()):String();cards["comet_direct"]=p.comet_direct;
    if (const auto *r=request_for(run,p.selected_id)) {cards["preparing"]=r->status==ResourceStatus::Pending;cards["error_code"]=int(r->status)<0?int(r->status):0;cards["request_id"]=r->id;}
    for (auto pair:{std::pair{&p.weapons,&weapons},std::pair{&p.traits,&traits}}) for (const auto &e:*pair.first) {Dictionary v;v["id"]=String::utf8(definition(run,e.definition)->external_id.c_str());v["level"]=e.level;pair.second->append(v);}
    Dictionary post_counts;Array post_candidates;
    for (const auto &d:run.content->post_max) {const auto n=count(p,d.external_id);if (n) post_counts[String::utf8(d.external_id.c_str())]=int64_t(n);if (normal_complete(run) && post_eligible(run,d.id)) {CardCandidate c{0,CardKind::PostMax,d.id,uint32_t(n+1)};post_candidates.append(card_value(run,c));}}
    out["post_max_stacks"]=post_counts;out["post_max_candidates"]=post_candidates;out["normal_complete"]=normal_complete(run);out["pending_levels"]=p.pending_levels;
    out["cards"]=cards;out["weapon_levels"]=weapons;out["trait_levels"]=traits;out["xp"]=p.xp;out["next_xp"]=next_xp(run);out["level"]=p.level;out["rerolls_left"]=p.rerolls;return out;
}
Array ProgressionSystem::requests(const RunRuntime &run) {
    Array out;
    for (const auto &r:run.resource_workspace.requests) {Dictionary v;PackedInt32Array assets;for (auto key:r.asset_keys) assets.push_back(key);v["request_id"]=r.id;v["offer_id"]=r.offer_id;v["purpose"]="candidate";v["asset_keys"]=assets;out.append(v);}
    return out;
}
}
