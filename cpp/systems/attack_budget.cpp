#include "attack_budget.h"
#include "../runtime/run_runtime.h"
#include "../output/event_builder.h"
#include "../output/recording_builder.h"
#include "timing.h"
#include "enemy_system.h"
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
std::string AttackBudgetSystem::owner(const godot::RunState &state,int64_t entity,int64_t formation) {
    return state.world.attack_formation_mode && formation>0?"formation:"+std::to_string(formation):std::to_string(entity);
}
bool AttackBudgetSystem::configure(godot::RunState &state,BudgetSettings settings) {
    if (state.closed || !std::isfinite(settings.budget) || !std::isfinite(settings.jitter)) return false;
    auto &budget=state.world.attack_budget;budget.enabled=settings.enabled;budget.budget=settings.budget;budget.jitter=settings.jitter;return true;
}
bool AttackBudgetSystem::set_guard(godot::RunState &state,bool active,double until) {
    if (state.closed || std::isnan(until)) return false;
    state.world.attack_budget.guard=active;state.world.attack_budget.guard_until=until;return true;
}
void AttackBudgetSystem::set_mode(godot::RunState &state,bool enabled,bool from_stage) {
    state.world.attack_budget.frame_enabled=enabled;state.world.attack_budget.stage_budget=from_stage;
}
bool AttackBudgetSystem::set_formation_mode(godot::RunState &state,bool enabled) {
    if (state.closed) return false;state.world.attack_formation_mode=enabled;return true;
}
void AttackBudgetSystem::apply_stage_budget(godot::RunState &state,double capacity) {
    state.world.attack_formation_mode=true;
    auto &budget=state.world.attack_budget;budget.enabled=true;budget.budget=capacity;budget.jitter=0;
}
void AttackBudgetSystem::reset_residuals(godot::RunState &state) {
    for (auto &entry:state.world.attack_budget.groups) entry.value.residuals=0;
}
bool AttackBudgetSystem::retain(godot::RunState &state,BudgetToken token) {
    if (!token.value) return true;
    auto *group=state.world.attack_budget.groups.getptr(token.value);
    if (!group || group->residuals==UINT32_MAX) return false;
    ++group->residuals;return true;
}
void AttackBudgetSystem::release(godot::RunState &state,BudgetToken token) {
    if (auto *group=state.world.attack_budget.groups.getptr(token.value)) if (group->residuals) --group->residuals;
    // 枠の失効判定と通知は、今と同じdirectorの世界更新位置で行う。
}
uint32_t AttackBudgetSystem::retained(const godot::RunState &state,BudgetToken token) {
    const auto *group=state.world.attack_budget.groups.getptr(token.value);return group?group->residuals:0;
}

namespace {
using Budget=AttackBudgetState;
constexpr double rounding=4.0*std::numeric_limits<double>::epsilon();
bool greater(double a,double b) {return a>b && a-b>std::max(std::abs(a),std::abs(b))*rounding;}
}
double AttackBudgetSystem::used_cost() const {return used_cost(run.state);}
double AttackBudgetSystem::used_cost(const godot::RunState &state) {
    double total=0;for (const auto &entry:state.world.attack_budget.groups) total+=entry.value.cost;return total;
}
std::string AttackBudgetSystem::next_owner() const {
    const auto &budget=run.state.world.attack_budget;if (budget.budget<=0) return {};
    std::string winner;double best=-std::numeric_limits<double>::infinity();
    for (const auto &entry:budget.waiting) {
        const auto &item=entry.value;if (greater(item.cost,budget.budget)) continue;
        const double score=item.priority-item.since*0.2;
        if (winner.empty() || score>best) {winner=entry.key;best=score;}
    }return winner;
}
bool AttackBudgetSystem::request(const BudgetRequest &request) {
    auto &state=run.state;auto &budget=state.world.attack_budget;
    if (!state.started || state.closed || !std::isfinite(request.duration) || !std::isfinite(request.priority) || !state.enemy_handles.contains(request.source)) return false;
    const int64_t id=state.enemy_handles.entity_id(request.source);const auto &owner=request.owner;
    const double cost=std::isfinite(request.cost) && request.cost>=0?request.cost:1;
    if (cost==0 || request.categories.empty()) return true;
    const double until=budget.now+std::max(0.05,request.duration);if (!std::isfinite(until)) return false;
    if (const auto *token=budget.owners.getptr(owner)) {
        auto &group=budget.groups[*token];
        if (auto *member=group.members.getptr(id)) {
            if (!member->closed) return true;
            // 既存の枠に残る同じ敵の斬撃を保ちながら、次の攻撃を始める。
            if (!request.reuse_residual || !group.residuals || guard_active() ||
                (budget.enabled && (budget.budget<=0 || greater(used_cost(),budget.budget)))) return false;
            member->actor=request.source;member->until=until;member->begun=false;member->closed=false;
            group.until=std::max(group.until,until);return true;
        }
        if (!state.world.attack_formation_mode) return false;
        if (budget.enabled && (budget.budget<=0 || greater(used_cost(),budget.budget))) return false;
        group.members.insert(id,{request.source,until,false,false});group.until=std::max(group.until,until);return true;
    }
    auto *waiting=budget.waiting.getptr(owner);
    if (!waiting) {
        Budget::Waiting item;item.id=id;item.actor=request.source;item.since=budget.now;item.categories=request.categories;
        budget.waiting.insert(owner,item);waiting=budget.waiting.getptr(owner);
    }
    waiting->priority=request.priority;waiting->cost=cost;
    if (budget.enabled) {const auto next=next_owner();if (!next.empty() && next!=owner) return false;}
    const double used=used_cost();
    if (guard_active() || (budget.enabled && (budget.budget<=0 || (cost>0 && used>=budget.budget) || greater(used+cost,budget.budget)))) {waiting->has_ready=false;return false;}
    if (budget.enabled && budget.now>waiting->since+0.001 && budget.jitter>0) {
        if (!waiting->has_ready) {waiting->ready=budget.now+state.control.rng.randf()*budget.jitter;waiting->has_ready=true;}
        if (!expired(budget.now,waiting->ready)) return false;
    }
    if (budget.serial==INT64_MAX) return false;
    const auto &enemy=state.enemies[request.source.slot];Budget::Group group;
    group.owner=owner;group.actor=request.source;group.id=id;group.categories=request.categories;group.until=until;group.start=budget.now;group.cost=cost;
    group.pos=enemy.pos;group.definition=uint32_t(enemy.definition+1);group.members.insert(id,{request.source,until,false,false});
    const int64_t token=++budget.serial;
    budget.groups.insert(token,group);budget.owners.insert(owner,token);budget.waiting.erase(owner);
    EventBuilder::budget_started(run,owner,id,request.source.slot,request.categories,token);return true;
}
int64_t AttackBudgetSystem::token(const std::string &owner) const {return token(run.state,owner);}
int64_t AttackBudgetSystem::token(const godot::RunState &state,const std::string &owner) {const auto *value=state.world.attack_budget.owners.getptr(owner);return value?*value:0;}
bool AttackBudgetSystem::owns(const std::string &owner,int64_t id) const {return owns(run.state,owner,id);}
bool AttackBudgetSystem::owns(const godot::RunState &state,const std::string &owner,int64_t id) {
    const auto *group=state.world.attack_budget.groups.getptr(token(state,owner));if (!group) return false;
    const auto *member=group->members.getptr(id);return member && !member->closed;
}
void AttackBudgetSystem::cancel_wait(const std::string &owner,int64_t id) {
    auto &budget=run.state.world.attack_budget;const auto *waiting=budget.waiting.getptr(owner);
    if (waiting && (id<0 || waiting->id==id)) budget.waiting.erase(owner);
}
void AttackBudgetSystem::cancel(const std::string &owner,int64_t id) {
    cancel_wait(owner,id);auto &budget=run.state.world.attack_budget;
    auto *group=budget.groups.getptr(token(owner));if (!group) return;
    if (auto *member=group->members.getptr(id)) {member->closed=true;member->until=budget.now;}
    group->until=budget.now;for (const auto &entry:group->members) group->until=std::max(group->until,entry.value.until);
}
void AttackBudgetSystem::external(int64_t value,const std::string &key,bool retain) {
    auto *group=run.state.world.attack_budget.groups.getptr(value);if (!group) return;
    if (retain) group->external.insert(key);else group->external.erase(key);
}
int64_t AttackBudgetSystem::passive(const std::string &owner,EnemyHandle source) {
    auto &state=run.state;auto &budget=state.world.attack_budget;
    if (!state.started || state.closed || state.world.attack_formation_mode || !state.enemy_handles.contains(source) || budget.serial==INT64_MAX) return 0;
    const int64_t token=++budget.serial;Budget::Group group;
    group.owner=owner+":passive:"+std::to_string(token);group.id=state.enemy_handles.entity_id(source);group.actor=source;
    group.until=group.start=budget.now;group.passive=true;
    group.pos=state.enemies[source.slot].pos;group.definition=uint32_t(state.enemies[source.slot].definition+1);group.categories.push_back(AttackCategory::Zone);
    budget.groups.insert(token,group);RecordingBuilder::budget(run);return token;
}
bool AttackBudgetSystem::advance(double at) {
    auto &state=run.state;auto &budget=state.world.attack_budget;
    if (!state.started || state.closed || !std::isfinite(at) || at<budget.now) return false;
    budget.now=at;std::vector<int64_t> ended;
    for (auto &entry:budget.groups) {
        auto &group=entry.value;
        if (!group.members.is_empty()) {
            group.until=at;
            for (auto &m:group.members) {
                auto &member=m.value;
                if (!member.closed) {
                    const bool same=state.enemy_handles.contains(member.actor) && state.enemy_handles.entity_id(member.actor)==m.key && !state.enemies[member.actor.slot].dead;
                    const bool active=same && owns(group.owner,m.key) && EnemySystem::attack_active(state,member.actor);
                    if (active) {member.begun=true;member.until=at+0.05;}
                    else if (!same || member.begun || !EnemySystem::attack_due(run,member.actor,0) || expired(at,member.until)) {member.closed=true;member.until=at;}
                }
                group.until=std::max(group.until,member.until);
            }
        }
        if (expired(at,group.until)) ended.push_back(entry.key);
    }
    for (const auto value:ended) {
        auto &group=budget.groups[value];if (group.residuals || !group.external.empty()) continue;
        EventBuilder::budget_ended(run,group.owner,value);
        if (token(group.owner)==value) budget.owners.erase(group.owner);
        budget.groups.erase(value);
    }
    std::vector<std::string> cancelled;
    for (const auto &entry:budget.waiting) {
        const auto &item=entry.value;
        if (!state.enemy_handles.contains(item.actor) || state.enemy_handles.entity_id(item.actor)!=item.id) {cancelled.push_back(entry.key);continue;}
        const auto &enemy=state.enemies[item.actor.slot];
        if (enemy.dead || enemy.stone>0 || enemy.knock_t>0 || enemy.shove_time>0) cancelled.push_back(entry.key);
    }
    for (const auto &owner:cancelled) budget.waiting.erase(owner);
    return true;
}
bool AttackBudgetSystem::guard_active() const {return guard_active(run.state);}
bool AttackBudgetSystem::guard_active(const godot::RunState &state) {const auto &budget=state.world.attack_budget;return budget.guard && budget.now<=budget.guard_until;}
}
