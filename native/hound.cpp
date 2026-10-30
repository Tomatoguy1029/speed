#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;

void SpeedRunCore::spawn_hounds(size_t row, const Dictionary &options) {
    auto &enemy = enemies[row];
    const auto &def = definitions[enemy.definition];
    enemy.pack = options.get("hound_pack", enemy.id); enemy.in_pack = true;
    hound_packs[enemy.pack].push_back(row);
    if (!options.has("vel")) {
        enemy.vel = (ship_pos - enemy.pos).normalized() * enemy.speed;
        enemy.facing = enemy.vel.angle();
    }
    if (options.has("hound_pack")) return;
    // 子の追加で格納配列が伸びるため、親の値は先に取り出す。
    const Enemy parent = enemy;
    const Vector2 direction = Vector2::from_angle(parent.facing), side = direction.orthogonal();
    const double gap = std::max(0.0, def.pack.gap);
    for (int64_t k = 1; k < def.pack.count; ++k) {
        const Vector2 at = parent.pos - direction * gap * double((k + 1) / 2) + side * gap * (k % 2 ? 0.5 : -0.5);
        Dictionary child = options.duplicate(); child["hound_pack"] = parent.pack; child["facing"] = parent.facing;
        child["attack_group"] = parent.attack_group; child["attack_value"] = parent.attack_value; child["attack_priority"] = parent.attack_priority;
        spawn_enemy(def.id, at, child);
    }
}
bool SpeedRunCore::running_hound(size_t row) const {
    const auto &e = enemies[row];
    return e.alive && !e.dead && !e.held && e.stone <= 0 && e.shove_time <= 0 && e.knock_t <= 0 && e.mode != EnemyMode::Windup;
}
Vector2 SpeedRunCore::hound_velocity(size_t row) const {
    const auto &e = enemies[row]; const auto &pack = definitions[e.definition].pack;
    const auto *members = hound_packs.getptr(e.pack);
    const double gap = std::max(1.0, pack.gap), reach = std::max(1.0, pack.reach);
    Vector2 separation, center, velocity;
    int count = 0;
    const bool following = e.follow_ready && e.follow_until >= world_time;
    for (size_t other : *members) {
        if (other == row || !running_hound(other)) continue;
        const auto &neighbor = enemies[other];
        const Vector2 offset = e.pos - neighbor.pos;
        const double distance = offset.length();
        if (!following && distance > reach) continue;
        center += neighbor.pos; velocity += neighbor.vel; ++count;
        if (distance > 0.001 && distance < gap) separation += offset / distance * (1.0 - distance / gap);
    }
    if (following) {
        const Vector2 to = e.follow_goal - e.pos;
        const double top = e.speed * e.follow_scale;
        Vector2 desired = to.length_squared() > 1.0 ? to.normalized() * std::min(top, double(to.length()) / 0.25) : Vector2();
        desired += separation * e.speed * pack.separation;
        return desired.limit_length(top);
    }
    const Vector2 chase = (ship_pos - e.pos).normalized() * e.speed;
    if (count == 0) return chase;
    Vector2 desired = chase.lerp(velocity / count, std::clamp(pack.alignment, 0.0, 1.0));
    desired += (center / count - e.pos) / reach * e.speed * pack.cohesion;
    desired += separation * e.speed * pack.separation;
    return desired.limit_length(e.speed);
}
void SpeedRunCore::prepare_hounds(const std::vector<size_t> &rows) {
    for (size_t row : rows) {
        auto &e = enemies[row]; e.pursuit_ready = running_hound(row);
        if (e.pursuit_ready) e.pursuit = hound_velocity(row);
    }
}
void SpeedRunCore::remove_hound(size_t row) {
    auto &e = enemies[row]; if (!e.in_pack) return;
    auto &members = hound_packs[e.pack];
    members.erase(std::remove(members.begin(), members.end(), row), members.end());
    if (members.empty()) hound_packs.erase(e.pack);
    e.in_pack = false; e.pursuit_ready = false; e.follow_ready = false;
}
bool SpeedRunCore::follow_hound(int64_t id, Vector2 goal, double until, double scale) {
    if (!started || closed || !goal.is_finite() || !std::isfinite(until) || !std::isfinite(scale) || scale < 0) return false;
    const auto found = rows_by_id.find(id); if (found == rows_by_id.end()) return false;
    auto &e = enemies[found->second]; if (!e.in_pack || e.dead) return false;
    e.follow_ready = true; e.follow_goal = goal; e.follow_until = until; e.follow_scale = scale;
    return true;
}
Dictionary SpeedRunCore::hound_snapshot() const {
    Array packs, follows;
    for (const auto &entry : hound_packs) {
        Dictionary pack; Array members;
        for (size_t row : entry.value) members.append(enemies[row].id);
        pack["id"] = entry.key; pack["members"] = members; packs.append(pack);
    }
    std::vector<const Enemy *> ordered;
    for (const auto &e : enemies) if (e.alive && e.follow_ready) ordered.push_back(&e);
    std::sort(ordered.begin(), ordered.end(), [](const auto *a, const auto *b) { return a->id < b->id; });
    for (const auto *e : ordered) {
        Dictionary follow; follow["id"] = e->id; follow["goal"] = e->follow_goal;
        follow["until"] = e->follow_until; follow["scale"] = e->follow_scale; follows.append(follow);
    }
    Dictionary out; out["packs"] = packs; out["follows"] = follows; return out;
}
