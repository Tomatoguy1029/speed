#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;

void SpeedRunCore::update_pushed(Enemy &enemy, double dt) {
    if (enemy.shove_time > 0) {
        enemy.shove_from = enemy.pos; enemy.shoved = true;
        enemy.shove_time -= dt; enemy.vel = enemy.shove_vel;
        enemy.shove_vel *= std::exp(-dt * 0.8);
    } else {
        enemy.knock_t -= dt; enemy.vel *= std::exp(-dt * 2.0);
    }
    enemy.pos += enemy.vel * dt;
}

// 比較・実験場からの操作口。通常の更新では所有している個体へ直接適用する。
bool SpeedRunCore::set_enemy_motion(int64_t id, const Dictionary &state) {
    if (!started || closed) return false;
    const auto found = rows_by_id.find(id); if (found == rows_by_id.end()) return false;
    const Array keys = state.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING && keys[i].get_type() != Variant::STRING_NAME) return false;
        const String key = keys[i]; const Variant value = state[keys[i]];
        if (key == "held" || key == "slash_hold") { if (value.get_type() != Variant::BOOL) return false; }
        else if (key == "stone" || key == "knock_t" || key == "shove_time") {
            if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
        } else if (key == "vel" || key == "shove_vel") {
            if (value.get_type() != Variant::VECTOR2 || !Vector2(value).is_finite()) return false;
        } else return false;
    }
    auto &enemy = enemies[found->second];
    if (state.has("held")) enemy.held = state["held"];
    if (state.has("slash_hold")) enemy.slash_hold = state["slash_hold"];
    if (state.has("stone")) enemy.stone = state["stone"];
    if (state.has("knock_t")) enemy.knock_t = state["knock_t"];
    if (state.has("shove_time")) enemy.shove_time = state["shove_time"];
    if (state.has("vel")) enemy.vel = state["vel"];
    if (state.has("shove_vel")) enemy.shove_vel = state["shove_vel"];
    return true;
}

Array SpeedRunCore::enemy_motion_snapshot() const {
    std::vector<const Enemy *> ordered;
    for (const auto &enemy : enemies) if (enemy.alive) ordered.push_back(&enemy);
    std::sort(ordered.begin(), ordered.end(), [](const auto *a, const auto *b) { return a->id < b->id; });
    Array out;
    for (const auto *e : ordered) {
        Dictionary row; row["id"] = e->id; row["stone"] = e->stone; row["knock_t"] = e->knock_t;
        row["shove_time"] = e->shove_time; row["shove_vel"] = e->shove_vel; row["shove_from"] = e->shove_from;
        row["held"] = int(e->held); row["slash_hold"] = int(e->slash_hold); row["shoved"] = int(e->shoved);
        row["age"] = e->age; row["fire_t"] = e->fire_t;
        row["mode"] = int(e->mode); row["timer"] = e->timer; row["charge"] = e->charge; out.append(row);
    }
    return out;
}
