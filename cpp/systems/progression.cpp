#include "progression.h"
#include "equipment.h"
#include "../api/run_core.h"
#include "../behaviors/weapons/forward.h"
#include <algorithm>
#include <cmath>
#include <climits>
using namespace godot;
namespace speed {
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
    for (auto &r:run.resource_workspace.requests) if (r.offer_id==run.state.loadout.offer_id && r.candidate_id==candidate) return &r;
    return nullptr;
}
const ResourceRequest *request_for(const RunRuntime &run,int64_t candidate) {
    for (const auto &r:run.resource_workspace.requests) if (r.offer_id==run.state.loadout.offer_id && r.candidate_id==candidate) return &r;
    return nullptr;
}
CardCandidate *candidate_for(RunRuntime &run,int64_t id) {
    for (auto &c:run.state.loadout.candidates) if (c.id==id) return &c;
    return nullptr;
}
std::vector<CardCandidate> roll(RunRuntime &run,bool initial) {
    auto &state=run.state.loadout;const auto &config=run.content->progression;
    struct Weighted {CardCandidate card;double weight;};std::vector<Weighted> pool;
    for (const auto &d:run.content->equipment) {
        const bool weapon=d.kind==0;const auto &owned=weapon?state.weapons:state.traits;
        if ((initial && !weapon) || (weapon && d.comet_only)) continue;
        const auto level=level_of(owned,d.id),slots=weapon?config.weapon_slots:config.trait_slots;
        if (!initial && (level>=d.maximum_level || (!level && owned.size()>=slots))) continue;
        pool.push_back({{0,weapon?CardKind::Weapon:CardKind::Trait,d.id,initial?1:level+1},level?config.owned_card_bias:1.0});
    }
    std::vector<CardCandidate> cards;const auto count=initial?config.start_weapon_choices:3;
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
    ResourceRequest request;request.id=run.resource_workspace.next_id++;request.offer_id=run.state.loadout.offer_id;request.candidate_id=card.id;
    for (const auto &a:run.content->equipment_assets) if (a.equipment==card.definition) request.asset_keys.push_back(a.asset);
    run.resource_workspace.requests.push_back(std::move(request));
}
void publish(RunRuntime &run,std::vector<CardCandidate> cards,bool initial) {
    auto &p=run.state.loadout;
    p.candidates=std::move(cards);p.initial_offer=initial;p.offer_id=p.next_offer_id++;p.selected_id=0;
    ProgressionSystem::rebuild_requests(run);run.state.phase=RunState::Phase::LevelUp;run.state.hitstop=0;
    Dictionary event;event["offer_id"]=p.offer_id;event["initial"]=initial;event["count"]=int64_t(p.candidates.size());FrameBuilder::append(run,"offer",event);
}
bool grant(RunRuntime &run,const CardCandidate &card) {
    const auto *d=definition(run,card.definition);if (!d || card.level>d->maximum_level) return false;
    const auto &owned=d->kind==0?run.state.loadout.weapons:run.state.loadout.traits;
    return level_of(owned,card.definition)+1==card.level && EquipmentSystem::grant(run,card.definition);

}
Dictionary card_value(const RunRuntime &run,const CardCandidate &card) {
    Dictionary value;value["candidate_id"]=card.id;value["kind"]=symbol_name(card.kind);
    const auto *d=definition(run,card.definition);value["id"]=String::utf8(d?d->external_id.c_str():"");value["level"]=card.level;
    if (run.state.loadout.initial_offer) value["start"]=true;
    const auto *r=request_for(run,card.id);value["request_id"]=r?r->id:0;return value;
}
void notify_grant(RunRuntime &run,const CardCandidate &card) {
    Dictionary event;event["kind"]=symbol_name(card.kind);event["id"]=String::utf8(definition(run,card.definition)->external_id.c_str());event["level"]=card.level;
    FrameBuilder::append(run,"loadout",event);
}
}
void ProgressionSystem::initialize(RunRuntime &run,bool initial) {
    auto &p=run.state.loadout;p={};p.ready=true;p.rerolls=run.content->progression.reroll_count;
    if (!initial) p.weapons.push_back({1,1});else run.state.forward.ready=false;
    run.resource_workspace.requests.clear();
}
double ProgressionSystem::next_xp(const RunRuntime &run) {
    const auto &c=run.content->progression;const double level=run.state.loadout.level;
    return c.xp_base+c.xp_growth*level+c.xp_curve*level*level;
}
bool ProgressionSystem::add_experience(SpeedRunCore &core,double amount) {
    auto &run=core.runtime;auto &p=run.state.loadout;
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
    auto &run=core.runtime;auto &p=run.state.loadout;
    if (!p.ready || run.state.phase!=RunState::Phase::Play || run.state.draw.drawing || run.state.draw.tracing || p.offer_id || (!initial && !p.pending_levels) || p.next_offer_id==INT64_MAX) return false;
    auto cards=roll(run,initial);if (cards.empty()) {p.pending_levels=0;return false;}
    publish(run,std::move(cards),initial);return true;
}
bool ProgressionSystem::choose(RunRuntime &run,int64_t offer,int64_t candidate) {
    auto &p=run.state.loadout;
    if (run.state.phase!=RunState::Phase::LevelUp || p.offer_id!=offer || !candidate_for(run,candidate)) return false;
    p.selected_id=candidate;return true;
}
bool ProgressionSystem::cancel(RunRuntime &run,int64_t offer) {
    if (run.state.phase!=RunState::Phase::LevelUp || run.state.loadout.offer_id!=offer || !offer) return false;
    run.state.loadout.selected_id=0;return true;
}
bool ProgressionSystem::reroll(SpeedRunCore &core,int64_t offer) {
    auto &p=core.runtime.state.loadout;
    if (core.runtime.state.phase!=RunState::Phase::LevelUp || p.offer_id!=offer || !offer || p.rerolls<=0 || p.next_offer_id==INT64_MAX) return false;
    auto cards=roll(core.runtime,p.initial_offer);if (cards.empty()) return false;
    --p.rerolls;publish(core.runtime,std::move(cards),p.initial_offer);core.emit_event("reroll");return true;
}
bool ProgressionSystem::complete(RunRuntime &run,int64_t id,int status) {
    if (status!=1 && status!=-1 && status!=-2) return false;
    for (auto &r:run.resource_workspace.requests) if (r.id==id && r.offer_id==run.state.loadout.offer_id && r.status==ResourceStatus::Pending) {r.status=ResourceStatus(status);return true;}
    return false;
}
bool ProgressionSystem::retry(RunRuntime &run,int64_t id) {
    if (run.resource_workspace.next_id==INT64_MAX) return false;
    for (auto &r:run.resource_workspace.requests) if (r.id==id && r.offer_id==run.state.loadout.offer_id && r.status==ResourceStatus::Failed) {
        r.id=run.resource_workspace.next_id++;r.status=ResourceStatus::Pending;return true;
    }
    return false;
}
void ProgressionSystem::rebuild_requests(RunRuntime &run) {
    run.resource_workspace.requests.clear();
    for (const auto &card:run.state.loadout.candidates) issue(run,card);
}
void ProgressionSystem::poll(SpeedRunCore &core) {
    auto &run=core.runtime;auto &p=run.state.loadout;
    if (run.state.phase!=RunState::Phase::LevelUp || !p.selected_id) return;
    const auto *request=request_for(run,p.selected_id);const auto *selected=candidate_for(run,p.selected_id);
    if (!request || request->status!=ResourceStatus::Ready || !selected) return;
    const auto card=*selected;const auto offer=p.offer_id;const bool initial=p.initial_offer;
    if (!grant(run,card)) return;
    Dictionary choice;choice["offer_id"]=offer;choice["candidate_id"]=card.id;choice["kind"]=symbol_name(card.kind);choice["id"]=String::utf8(definition(run,card.definition)->external_id.c_str());choice["level"]=card.level;
    core.emit_event("choice",choice);notify_grant(run,card);
    if (!initial) {
        Dictionary event;event["card"]=card_value(run,card);core.emit_event("upgrade",event);
        int bonus_count=0;
        for (double chance:{run.content->progression.levelup_bonus_chance,run.content->progression.levelup_bonus_more,run.content->progression.levelup_bonus_last}) {
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
    const auto &p=run.state.loadout;Dictionary out,cards;Array candidates,weapons,traits;
    for (const auto &c:p.candidates) candidates.append(card_value(run,c));
    cards["offer_id"]=p.offer_id;cards["candidates"]=candidates;cards["selected_id"]=p.selected_id;cards["preparing"]=false;cards["error_code"]=0;cards["initial"]=p.initial_offer;
    if (const auto *r=request_for(run,p.selected_id)) {cards["preparing"]=r->status==ResourceStatus::Pending;cards["error_code"]=int(r->status)<0?int(r->status):0;cards["request_id"]=r->id;}
    for (auto pair:{std::pair{&p.weapons,&weapons},std::pair{&p.traits,&traits}}) for (const auto &e:*pair.first) {Dictionary v;v["id"]=String::utf8(definition(run,e.definition)->external_id.c_str());v["level"]=e.level;pair.second->append(v);}
    out["cards"]=cards;out["weapon_levels"]=weapons;out["trait_levels"]=traits;out["xp"]=p.xp;out["next_xp"]=next_xp(run);out["level"]=p.level;out["rerolls_left"]=p.rerolls;return out;
}
Array ProgressionSystem::requests(const RunRuntime &run) {
    Array out;
    for (const auto &r:run.resource_workspace.requests) {Dictionary v;PackedInt32Array assets;for (auto key:r.asset_keys) assets.push_back(key);v["request_id"]=r.id;v["offer_id"]=r.offer_id;v["purpose"]="candidate";v["asset_keys"]=assets;out.append(v);}
    return out;
}
}
