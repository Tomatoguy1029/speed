#include "run_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "data"), &SpeedRunCore::configure);
    ClassDB::bind_method(D_METHOD("configure_ship", "config", "stats"), &SpeedRunCore::configure_ship);
    ClassDB::bind_method(D_METHOD("step_ship", "real_dt", "world_dt", "input"), &SpeedRunCore::step_ship);
    ClassDB::bind_method(D_METHOD("ship_snapshot"), &SpeedRunCore::ship_snapshot);
    ClassDB::bind_method(D_METHOD("start", "seed", "first_id"), &SpeedRunCore::start, DEFVAL(1));
    ClassDB::bind_method(D_METHOD("step", "delta"), &SpeedRunCore::step);
    ClassDB::bind_method(D_METHOD("set_motion_context", "ship", "center", "half"), &SpeedRunCore::set_motion_context);
    ClassDB::bind_method(D_METHOD("spawn_enemy", "type", "position"), &SpeedRunCore::spawn_enemy);
    ClassDB::bind_method(D_METHOD("remove_enemy", "id"), &SpeedRunCore::remove_enemy);
    ClassDB::bind_method(D_METHOD("enemies_snapshot"), &SpeedRunCore::enemies_snapshot);
    ClassDB::bind_method(D_METHOD("enemy_buffer", "type", "scale", "angle_offset"), &SpeedRunCore::enemy_buffer);
    ClassDB::bind_method(D_METHOD("close"), &SpeedRunCore::close);
    ClassDB::bind_method(D_METHOD("inspect"), &SpeedRunCore::inspect);
}

bool SpeedRunCore::start(int64_t seed, int64_t first_id) {
    if (started || closed || first_id <= 0) return false;
    next_id = first_id;
    rng.instantiate();
    rng->set_seed(seed);
    started = true;
    return true;
}

bool SpeedRunCore::step(double delta) {
    if (!started || closed || !std::isfinite(delta) || delta <= 0.0 || !std::isfinite(time + delta)) return false;
    if (!rows_by_id.empty() && !motion_ready) return false;
    time += delta;
    ++ticks;
    const Vector2 limit = view_half * 1.25 + Vector2(300, 300);
    for (auto &enemy : enemies) {
        if (!enemy.alive) continue;
        enemy.age += delta;
        const Vector2 relative = enemy.pos - view_center;
        const bool far = std::abs(relative.x) > limit.x || std::abs(relative.y) > limit.y;
        if (!far || (enemy.id + ticks) % 3 == 0) {
            const Vector2 toward = ship_pos - enemy.pos;
            const double distance = toward.length();
            enemy.vel = Vector2();
            if (distance > 0.001) {
                const Vector2 unit = toward / distance;
                enemy.vel = unit * definitions[enemy.definition].speed;
                enemy.facing = unit.angle();
            }
        }
        enemy.pos += enemy.vel * delta;
    }
    return true;
}

void SpeedRunCore::close() {
    closed = true;
    rng.unref();
    enemies.clear();
    enemies.shrink_to_fit();
    free_rows.clear();
    rows_by_id.clear();
    definitions.clear();
}

Dictionary SpeedRunCore::inspect() const {
    Dictionary out;
    out["active"] = started && !closed;
    out["closed"] = closed;
    out["time"] = time;
    out["ticks"] = ticks;
    out["rng_state"] = rng.is_valid() ? String::num_int64(rng->get_state()) : String();
    return out;
}

// 入力全体を検証してから差し替え、不正な途中結果を残さない。
bool SpeedRunCore::configure(const Dictionary &data) {
    if (started || closed || !data.has("version") ||
            (data["version"].get_type() != Variant::INT && data["version"].get_type() != Variant::FLOAT) || double(data["version"]) != 1.0 ||
            !data.has("enemies") || data["enemies"].get_type() != Variant::ARRAY) return false;
    const Array rows = data["enemies"];
    std::vector<speed::EnemyDefinition> parsed;
    for (int64_t i = 0; i < rows.size(); ++i) {
        if (rows[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = rows[i];
        if (!row.has("id") || row["id"].get_type() != Variant::STRING || String(row["id"]).is_empty() ||
                !row.has("behavior") || row["behavior"].get_type() != Variant::STRING || String(row["behavior"]) != "chase") return false;
        speed::EnemyDefinition def;
        def.id = String(row["id"]);
        for (const auto &previous : parsed) if (previous.id == def.id) return false;
        const char *keys[] = {"hp", "armor", "radius", "speed", "fire_interval"};
        double *values[] = {&def.hp, &def.armor, &def.radius, &def.speed, &def.fire_interval};
        for (int k = 0; k < 5; ++k) {
            if (!row.has(keys[k])) return false;
            const Variant value = row[keys[k]];
            if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return false;
            *values[k] = double(value);
            if (!std::isfinite(*values[k]) || *values[k] < 0.0) return false;
        }
        if (def.hp <= 0.0 || def.radius <= 0.0 || !row.has("color") || row["color"].get_type() != Variant::ARRAY) return false;
        const Array color = row["color"];
        if (color.size() != 4) return false;
        for (int k = 0; k < 4; ++k) {
            const Variant value = color[k];
            if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
            def.color[k] = double(value);
        }
        parsed.push_back(def);
    }
    definitions = std::move(parsed);
    return true;
}

bool SpeedRunCore::set_motion_context(Vector2 ship, Vector2 center, Vector2 half) {
    if (!started || closed || !ship.is_finite() || !center.is_finite() || !half.is_finite() || half.x <= 0 || half.y <= 0) return false;
    ship_pos = ship; view_center = center; view_half = half;
    motion_ready = true;
    return true;
}

int64_t SpeedRunCore::spawn_enemy(StringName type, Vector2 position) {
    if (!started || closed || !position.is_finite() || next_id == INT64_MAX) return -1;
    size_t definition = 0;
    while (definition < definitions.size() && definitions[definition].id != type) ++definition;
    if (definition == definitions.size()) return -1;
    size_t row = enemies.size();
    if (free_rows.empty()) enemies.emplace_back();
    else { row = free_rows.back(); free_rows.pop_back(); }
    Enemy enemy;
    enemy.id = next_id++;
    enemy.definition = definition;
    enemy.pos = position;
    enemy.hp = definitions[definition].hp;
    enemy.fire_t = definitions[definition].fire_interval * (0.5 + rng->randf() * 0.5);
    enemy.alive = true;
    enemies[row] = enemy;
    rows_by_id[enemy.id] = row;
    return enemy.id;
}

bool SpeedRunCore::remove_enemy(int64_t id) {
    if (!started || closed) return false;
    auto found = rows_by_id.find(id);
    if (found == rows_by_id.end()) return false;
    enemies[found->second].alive = false;
    free_rows.push_back(found->second);
    rows_by_id.erase(found);
    return true;
}

Array SpeedRunCore::enemies_snapshot() const {
    Array out;
    for (const auto &enemy : enemies) {
        if (!enemy.alive) continue;
        const auto &def = definitions[enemy.definition];
        Dictionary row;
        row["id"] = enemy.id; row["type"] = String(def.id);
        row["pos"] = Array::make(enemy.pos.x, enemy.pos.y);
        row["vel"] = Array::make(enemy.vel.x, enemy.vel.y);
        row["hp"] = enemy.hp; row["armor"] = def.armor;
        row["radius"] = def.radius; row["facing"] = enemy.facing; row["dead"] = 0;
        out.append(row);
    }
    // 比較用コピーだけをID順へ並べる。実行中の格納位置は変えない。
    for (int i = 1; i < out.size(); ++i) {
        int j = i;
        while (j > 0 && int64_t(Dictionary(out[j - 1])["id"]) > int64_t(Dictionary(out[j])["id"])) {
            Variant previous = out[j - 1]; out[j - 1] = out[j]; out[j] = previous; --j;
        }
    }
    return out;
}

// 最新の所有状態から2D変換8値と表示色4値をまとめて渡す。
PackedFloat32Array SpeedRunCore::enemy_buffer(StringName type, double scale, double angle_offset) const {
    PackedFloat32Array buffer;
    if (!started || closed || !std::isfinite(scale) || scale <= 0 || !std::isfinite(angle_offset)) return buffer;
    int64_t count = 0;
    for (const auto &enemy : enemies) if (enemy.alive && definitions[enemy.definition].id == type) ++count;
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    for (const auto &enemy : enemies) {
        if (!enemy.alive || definitions[enemy.definition].id != type) continue;
        const double radius = definitions[enemy.definition].radius * scale;
        const double angle = enemy.facing + angle_offset;
        const double c = std::cos(angle) * radius, s = std::sin(angle) * radius;
        out[index++] = c; out[index++] = -s; out[index++] = 0; out[index++] = enemy.pos.x;
        out[index++] = s; out[index++] = c; out[index++] = 0; out[index++] = enemy.pos.y;
        out[index++] = 0; out[index++] = 0; out[index++] = 0; out[index++] = 1;
    }
    return buffer;
}
