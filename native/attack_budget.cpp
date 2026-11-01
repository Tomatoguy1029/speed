#include "run_core.h"
#include "../cpp/systems/attack_budget.h"
#include "../cpp/systems/population_system.h"
#include <cmath>
using namespace godot;
namespace {
std::string name(const String &value) {return value.utf8().get_data();}
std::string name(const StringName &value) {return String(value).utf8().get_data();}
bool number(const Variant &value,double &out) {
    if (value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) return false;
    out=value;return std::isfinite(out);
}
}
bool SpeedRunCore::configure_attack_budget(const Dictionary &settings) {
    if (runtime.state.closed || settings.get("enabled",false).get_type()!=Variant::BOOL) return false;
    auto &state=runtime.state.world.attack_budget;double budget=state.budget,jitter=state.jitter;
    if ((settings.has("budget") && !number(settings["budget"],budget)) || (settings.has("jitter") && !number(settings["jitter"],jitter))) return false;
    return speed::AttackBudgetSystem::configure(runtime.state,{bool(settings.get("enabled",false)),budget,jitter});
}
bool SpeedRunCore::set_attack_guard(bool active,double until) {
    return speed::AttackBudgetSystem::set_guard(runtime.state,active,until);
}
double SpeedRunCore::used_attack_cost() const {return speed::AttackBudgetSystem::used_cost(runtime.state);}
bool SpeedRunCore::request_attack(StringName owner,const PackedStringArray &categories,int64_t id,double duration,double priority,double cost) {
    const auto found=runtime.state.rows_by_id.find(id);if (found==runtime.state.rows_by_id.end()) return false;
    speed::BudgetRequest request;request.owner=name(owner);request.source=runtime.state.enemy_handles.at(uint32_t(found->second));
    request.duration=duration;request.priority=priority;request.cost=cost;
    for (int64_t i=0;i<categories.size();++i) {
        speed::AttackCategory category;if (!speed::parse_symbol(categories[i].utf8().get_data(),category)) return false;
        request.categories.push_back(category);
    }
    return speed::AttackBudgetSystem(runtime).request(request);
}
int64_t SpeedRunCore::attack_token(StringName owner) const {return speed::AttackBudgetSystem::token(runtime.state,name(owner));}
bool SpeedRunCore::owns_attack(StringName owner,int64_t id) const {return speed::AttackBudgetSystem::owns(runtime.state,name(owner),id);}
void SpeedRunCore::cancel_attack_wait(StringName owner,int64_t id) {speed::AttackBudgetSystem(runtime).cancel_wait(name(owner),id);}
void SpeedRunCore::cancel_attack(StringName owner,int64_t id) {speed::AttackBudgetSystem(runtime).cancel(name(owner),id);}
void SpeedRunCore::track_attack_external(int64_t token,const String &key) {speed::AttackBudgetSystem(runtime).external(token,name(key),true);}
void SpeedRunCore::release_attack_external(int64_t token,const String &key) {speed::AttackBudgetSystem(runtime).external(token,name(key),false);}
int64_t SpeedRunCore::passive_attack(StringName owner,int64_t id) {
    const auto found=runtime.state.rows_by_id.find(id);if (found==runtime.state.rows_by_id.end()) return 0;
    return speed::AttackBudgetSystem(runtime).passive(name(owner),runtime.state.enemy_handles.at(uint32_t(found->second)));
}
bool SpeedRunCore::advance_attack_budget(double at) {return speed::AttackBudgetSystem(runtime).advance(at);}
bool SpeedRunCore::attack_guard_active() const {return speed::AttackBudgetSystem::guard_active(runtime.state);}
void SpeedRunCore::sync_attack_budget() {speed::PopulationSystem::sync_attack_budget(runtime);}
bool SpeedRunCore::set_attack_budget_mode(bool enabled,bool from_stage) {
    if (runtime.state.closed || (enabled && !runtime.state.frame_ready) || (from_stage && runtime.content->budget_phases.empty() && (!runtime.state.spawn_timeline_ready || runtime.state.spawn_timeline.phases.empty()))) return false;
    speed::AttackBudgetSystem::set_mode(runtime.state,enabled,from_stage);
    if (enabled) sync_attack_budget();return true;
}
Dictionary SpeedRunCore::attack_budget_snapshot() const {
    const auto &budget=runtime.state.world.attack_budget;Dictionary out;Array groups,waiting;
    for (const auto &entry:budget.groups) {
        const auto &group=entry.value;Dictionary row;Array members;
        for (const auto &m:group.members) {
            Dictionary member;member["id"]=m.key;member["until"]=m.value.until;member["begun"]=m.value.begun;member["closed"]=m.value.closed;members.append(member);
        }
        row["token"]=entry.key;row["owner"]=String::utf8(group.owner.c_str());row["id"]=group.id;row["cost"]=group.cost;
        row["until"]=group.until;row["start"]=group.start;row["passive"]=group.passive;row["members"]=members;groups.append(row);
    }
    for (const auto &entry:budget.waiting) {
        const auto &item=entry.value;Dictionary row;row["owner"]=String::utf8(entry.key.c_str());row["id"]=item.id;
        row["since"]=item.since;row["priority"]=item.priority;row["cost"]=item.cost;if (item.has_ready) row["ready"]=item.ready;waiting.append(row);
    }
    out["used"]=used_attack_cost();out["serial"]=budget.serial;out["now"]=budget.now;out["groups"]=groups;out["waiting"]=waiting;return out;
}
