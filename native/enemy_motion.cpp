#include "run_core.h"
#include "../cpp/systems/motion_math.h"
#include "../cpp/systems/enemy_system.h"
#include <algorithm>
#include <cmath>
using namespace godot;

void SpeedRunCore::update_pushed(Enemy &enemy, double dt) {
    if (enemy.shove_time > 0) {
        enemy.shove_from = enemy.pos; enemy.shoved = true;
        enemy.shove_time = speed::remaining_time(enemy.shove_time,dt); enemy.vel = enemy.shove_vel;
        enemy.shove_vel = speed::exponential_deceleration(enemy.shove_vel,0.8,dt);
    } else {
        enemy.knock_t = speed::remaining_time(enemy.knock_t,dt); enemy.vel = speed::exponential_deceleration(enemy.vel,2.0,dt);
    }
    enemy.pos += enemy.vel * dt;
}

// 比較・実験場からの操作口。通常の更新では所有している個体へ直接適用する。
bool SpeedRunCore::set_enemy_motion(int64_t id, const Dictionary &state) {
    if (!runtime.state.started || runtime.state.closed) return false;
    const auto found = runtime.state.rows_by_id.find(id); if (found == runtime.state.rows_by_id.end()) return false;
    const Array keys = state.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING && keys[i].get_type() != Variant::STRING_NAME) return false;
        const String key = keys[i]; const Variant value = state[keys[i]];
        if (key == "pump_owner") { if (value.get_type()!=Variant::INT || int64_t(value)<0 || (int64_t(value)>0 && !runtime.state.rows_by_id.count(int64_t(value)))) return false; }
        else if (key == "held" || key == "slash_hold") { if (value.get_type() != Variant::BOOL) return false; }
        else if (key == "stone" || key == "knock_t" || key == "shove_time" || key=="fire_t" || key=="charge" || key=="facing") {
            if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
        } else if (key == "vel" || key == "shove_vel") {
            if (value.get_type() != Variant::VECTOR2 || !Vector2(value).is_finite()) return false;
        } else return false;
    }
    auto &enemy = runtime.state.enemies[found->second];
    if (state.has("pump_owner")) {
        const int64_t owner=state["pump_owner"];
        enemy.pump_owner=owner>0?runtime.state.enemy_handles.at(uint32_t(runtime.state.rows_by_id.at(owner))):speed::EnemyHandle();
    }
    if (state.has("fire_t")) enemy.fire_t=double(state["fire_t"]);
    if (state.has("charge")) enemy.charge=double(state["charge"]);
    if (state.has("facing")) enemy.facing=double(state["facing"]);
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
    for (const auto &enemy : runtime.state.enemies) if (enemy.alive) ordered.push_back(&enemy);
    std::sort(ordered.begin(), ordered.end(), [](const auto *a, const auto *b) { return a->id < b->id; });
    Array out;
    for (const auto *e : ordered) {
        Dictionary row; row["id"] = e->id; row["stone"] = e->stone; row["knock_t"] = e->knock_t;
        row["shove_time"] = e->shove_time; row["shove_vel"] = e->shove_vel; row["shove_from"] = e->shove_from;
        row["turn_locked"]=runtime.state.draw.tracing && !e->held && !runtime.state.enemy_handles.contains(e->pump_owner);
        row["held"] = int(e->held); row["slash_hold"] = int(e->slash_hold); row["shoved"] = int(e->shoved);
        row["age"] = e->age; row["fire_t"] = e->fire_t;
        if (runtime.content->definitions[e->definition].kind==speed::EnemyDefinition::Kind::Drift) row["spin"]=e->spin;
        if (e->parent_id) {row["parent_id"]=e->parent_id;row["parent_alive"]=runtime.state.enemy_handles.contains(e->parent) && !runtime.state.enemies[e->parent.slot].dead;}
        if (!e->parts.empty()) row["parts_alive"]=int64_t(speed::EnemySystem::parts_alive(runtime.state,runtime.state.enemy_handles.at(uint32_t(runtime.state.rows_by_id.at(e->id)))));
        if (const auto *sniper=std::get_if<speed::SniperState>(&e->behavior_state)) {PackedFloat32Array rays;for (float value:sniper->rays) rays.push_back(value);row["sight_rays"]=rays;}
        if (const auto *marlin=std::get_if<speed::MarlinState>(&e->behavior_state)) row["anchor"]=marlin->anchor;
        row["mode"] = int(e->mode); row["timer"] = e->timer; row["charge"] = e->charge; out.append(row);
    }
    return out;
}
