#include "run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;
namespace {
constexpr double rounding = 4.0 * std::numeric_limits<double>::epsilon();
bool greater(double a, double b) { return a > b && a - b > std::max(std::abs(a), std::abs(b)) * rounding; }
bool reached(double time, double deadline) { return time >= deadline || deadline - time <= std::max(std::abs(time), std::abs(deadline)) * rounding; }
bool number(const Variant &v, double &out) {
    if (v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT) return false;
    out = v; return std::isfinite(out);
}
}
bool SpeedRunCore::configure_attack_budget(const Dictionary &settings) {
    if (closed) return false;
    const Variant enabled = settings.get("enabled", false);
    if (enabled.get_type() != Variant::BOOL) return false;
    double budget = attack_budget.budget, jitter = attack_budget.jitter;
    if (settings.has("budget") && !number(settings["budget"], budget)) return false;
    if (settings.has("jitter") && !number(settings["jitter"], jitter)) return false;
    attack_budget.enabled = enabled; attack_budget.budget = budget; attack_budget.jitter = jitter;
    return true;
}
bool SpeedRunCore::set_attack_guard(bool active, double until) {
    if (closed || std::isnan(until)) return false;
    attack_budget.guard = active; attack_budget.guard_until = until; return true;
}
double SpeedRunCore::used_attack_cost() const {
    double total = 0;
    for (const auto &entry : attack_budget.groups) total += entry.value.cost;
    return total;
}
StringName SpeedRunCore::next_attack_owner() const {
    if (attack_budget.budget <= 0) return StringName();
    StringName winner; double best = -std::numeric_limits<double>::infinity();
    for (const auto &entry : attack_budget.waiting) {
        const auto &item = entry.value;
        if (greater(item.cost, attack_budget.budget)) continue;
        const double score = item.priority - item.since * 0.2;
        if (winner == StringName() || score > best) { winner = entry.key; best = score; }
    }
    return winner;
}
bool SpeedRunCore::request_attack(StringName owner, const PackedStringArray &categories, int64_t id, double duration, double priority, double cost) {
    if (!started || closed || !std::isfinite(duration) || !std::isfinite(priority)) return false;
    const auto found = rows_by_id.find(id);
    if (found == rows_by_id.end()) return false;
    if (!std::isfinite(cost) || cost < 0) cost = 1;
    if (cost == 0 || categories.is_empty()) return true;
    auto &budget = attack_budget;
    const size_t row = found->second;
    const double until = budget.now + std::max(0.05, duration);
    if (!std::isfinite(until)) return false;
    if (const auto *token = budget.owners.getptr(owner)) {
        auto &group = budget.groups[*token];
        if (const auto *member = group.members.getptr(id)) return !member->closed;
        if (!attack_formation_mode) return false;
        if (budget.enabled && (budget.budget <= 0 || greater(used_attack_cost(), budget.budget))) return false;
        group.members.insert(id, AttackBudget::Member{row, until, false, false});
        group.until = std::max(group.until, until);
        return true;
    }
    auto *waiting = budget.waiting.getptr(owner);
    if (!waiting) {
        AttackBudget::Waiting item;
        item.id = id; item.row = row; item.since = budget.now; item.categories = categories;
        budget.waiting.insert(owner, item); waiting = budget.waiting.getptr(owner);
    }
    waiting->priority = priority; waiting->cost = cost;
    if (budget.enabled) {
        const StringName next = next_attack_owner();
        if (next != StringName() && next != owner) return false;
    }
    const double used = used_attack_cost();
    if ((budget.guard && budget.now <= budget.guard_until) || (budget.enabled &&
            (budget.budget <= 0 || (cost > 0 && used >= budget.budget) || greater(used + cost, budget.budget)))) {
        waiting->has_ready = false; return false;
    }
    if (budget.enabled && budget.now > waiting->since + 0.001 && budget.jitter > 0) {
        if (!waiting->has_ready) { waiting->ready = budget.now + rng->randf() * budget.jitter; waiting->has_ready = true; }
        if (!reached(budget.now, waiting->ready)) return false;
    }
    AttackBudget::Group group;
    group.owner = owner; group.row = row; group.id = id; group.categories = categories;
    group.until = until; group.start = budget.now; group.cost = cost;
    group.pos = enemies[row].pos; group.type = definitions[enemies[row].definition].id;
    group.members.insert(id, AttackBudget::Member{row, until, false, false});
    const int64_t token = ++budget.serial;
    budget.groups.insert(token, group); budget.owners.insert(owner, token); budget.waiting.erase(owner);
    Dictionary event; event["owner"] = String(owner); event["row"] = int64_t(row); event["id"] = id;
    Array cats; for (int i = 0; i < categories.size(); ++i) cats.append(categories[i]);
    event["categories"] = cats; event["token"] = token; emit_event("attack_start", event);
    return true;
}
Dictionary SpeedRunCore::attack_budget_snapshot() const {
    Dictionary out; Array groups, waiting;
    for (const auto &entry : attack_budget.groups) {
        const auto &group = entry.value; Dictionary row; Array members;
        for (const auto &m : group.members) {
            Dictionary member; member["id"] = m.key; member["until"] = m.value.until;
            member["begun"] = m.value.begun; member["closed"] = m.value.closed; members.append(member);
        }
        row["token"] = entry.key; row["owner"] = String(group.owner); row["id"] = group.id;
        row["cost"] = group.cost; row["until"] = group.until; row["start"] = group.start;
        row["passive"] = group.passive; row["members"] = members; groups.append(row);
    }
    for (const auto &entry : attack_budget.waiting) {
        const auto &item = entry.value; Dictionary row;
        row["owner"] = String(entry.key); row["id"] = item.id; row["since"] = item.since;
        row["priority"] = item.priority; row["cost"] = item.cost;
        if (item.has_ready) row["ready"] = item.ready;
        waiting.append(row);
    }
    out["used"] = used_attack_cost(); out["serial"] = attack_budget.serial; out["now"] = attack_budget.now;
    out["groups"] = groups; out["waiting"] = waiting; return out;
}

int64_t SpeedRunCore::attack_token(StringName owner) const {
    const auto *token = attack_budget.owners.getptr(owner); return token ? *token : 0;
}
bool SpeedRunCore::owns_attack(StringName owner, int64_t id) const {
    const auto *group = attack_budget.groups.getptr(attack_token(owner));
    if (!group) return false;
    const auto *member = group->members.getptr(id); return member && !member->closed;
}
void SpeedRunCore::cancel_attack_wait(StringName owner, int64_t id) {
    auto *waiting = attack_budget.waiting.getptr(owner);
    if (waiting && (id < 0 || waiting->id == id)) attack_budget.waiting.erase(owner);
}
void SpeedRunCore::cancel_attack(StringName owner, int64_t id) {
    cancel_attack_wait(owner, id);
    auto *group = attack_budget.groups.getptr(attack_token(owner));
    if (!group) return;
    if (auto *member = group->members.getptr(id)) { member->closed = true; member->until = attack_budget.now; }
    group->until = attack_budget.now;
    for (const auto &entry : group->members) group->until = std::max(group->until, entry.value.until);
}
void SpeedRunCore::track_attack_external(int64_t token, const String &key) {
    if (auto *group = attack_budget.groups.getptr(token)) group->external.insert(key.utf8().get_data());
}
void SpeedRunCore::release_attack_external(int64_t token, const String &key) {
    if (auto *group = attack_budget.groups.getptr(token)) group->external.erase(key.utf8().get_data());
}
int64_t SpeedRunCore::passive_attack(StringName owner, int64_t id) {
    if (!started || closed || attack_formation_mode) return 0;
    const auto found = rows_by_id.find(id); if (found == rows_by_id.end()) return 0;
    auto &budget = attack_budget;
    const int64_t token = ++budget.serial;
    AttackBudget::Group group;
    group.owner = String(owner) + ":passive:" + String::num_int64(token);
    group.id = id; group.row = found->second; group.until = budget.now; group.start = budget.now; group.passive = true;
    group.pos = enemies[group.row].pos; group.type = definitions[enemies[group.row].definition].id;
    group.categories.append("zone"); budget.groups.insert(token, group); return token;
}
bool SpeedRunCore::advance_attack_budget(double at) {
    if (!started || closed || !std::isfinite(at) || at < attack_budget.now) return false;
    auto &budget = attack_budget; budget.now = at;
    std::vector<int64_t> expired;
    for (auto &entry : budget.groups) {
        auto &group = entry.value;
        if (!group.members.is_empty()) {
            group.until = at;
            for (auto &m : group.members) {
                auto &member = m.value;
                if (!member.closed) {
                    const auto found = rows_by_id.find(m.key);
                    const bool same = found != rows_by_id.end() && found->second == member.row && !enemies[member.row].dead;
                    // 現在対応している追跡・盾には、予告中や突進中の行動状態がない。
                    // それらを持つ敵は行動の移行時に、この寿命更新にも接続する。
                    if (!same || member.begun || enemies[member.row].fire_t > definitions[enemies[member.row].definition].attack_telegraph || reached(at, member.until)) {
                        member.closed = true; member.until = at;
                    }
                }
                group.until = std::max(group.until, member.until);
            }
        }
        if (reached(at, group.until)) expired.push_back(entry.key);
    }
    if (!expired.empty()) {
        std::unordered_set<int64_t> live;
        for (const auto &shot : hostiles) if (shot.alive) live.insert(shot.attack_token);
        for (int64_t token : expired) {
            auto &group = budget.groups[token];
            if (live.count(token) || !group.external.empty()) continue;
            Dictionary event; event["token"] = token; event["owner"] = String(group.owner); emit_event("attack_end", event);
            if (attack_token(group.owner) == token) budget.owners.erase(group.owner);
            budget.groups.erase(token);
        }
    }
    std::vector<StringName> cancelled;
    for (const auto &entry : budget.waiting) {
        const auto found = rows_by_id.find(entry.value.id);
        if (found == rows_by_id.end() || found->second != entry.value.row || enemies[entry.value.row].dead) cancelled.push_back(entry.key);
    }
    for (const auto &owner : cancelled) budget.waiting.erase(owner);
    return true;
}

bool SpeedRunCore::attack_guard_active() const {
    return attack_budget.guard && attack_budget.now <= attack_budget.guard_until;
}
void SpeedRunCore::sync_attack_budget() {
    if (!attack_budget.stage_budget) return;
    size_t phase = 0;
    for (size_t i = 1; i < spawn_timeline.phases.size(); ++i) {
        if (spawn_timeline.phases[i].start > time) break;
        phase = i;
    }
    attack_formation_mode = true; attack_budget.enabled = true;
    attack_budget.budget = std::max(int64_t(0), spawn_timeline.phases[phase].budget);
    attack_budget.jitter = 0;
}
bool SpeedRunCore::set_attack_budget_mode(bool enabled, bool from_stage) {
    if (closed || (enabled && !frame_ready) || (from_stage && (!spawn_timeline_ready || spawn_timeline.phases.empty()))) return false;
    attack_budget.frame_enabled = enabled; attack_budget.stage_budget = from_stage;
    if (enabled) sync_attack_budget();
    return true;
}
