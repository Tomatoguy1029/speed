#include "run_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure_lifecycle", "config"), &SpeedRunCore::configure_lifecycle);
    ClassDB::bind_method(D_METHOD("set_run_guards", "guards"), &SpeedRunCore::set_run_guards);
    ClassDB::bind_method(D_METHOD("set_paused", "paused"), &SpeedRunCore::set_paused);
    ClassDB::bind_method(D_METHOD("friendly_buffer", "visual", "pixel", "scale", "clock"), &SpeedRunCore::friendly_buffer);
    ClassDB::bind_method(D_METHOD("configure_forward", "parameters", "level", "character_scale"), &SpeedRunCore::configure_forward);
    ClassDB::bind_method(D_METHOD("forward_snapshot"), &SpeedRunCore::forward_snapshot);
    ClassDB::bind_method(D_METHOD("spawn_hostile", "fields"), &SpeedRunCore::spawn_hostile);
    ClassDB::bind_method(D_METHOD("step_hostiles", "world_dt"), &SpeedRunCore::step_hostiles);
    ClassDB::bind_method(D_METHOD("hostiles_snapshot"), &SpeedRunCore::hostiles_snapshot);
    ClassDB::bind_method(D_METHOD("configure_projectiles", "config", "split"), &SpeedRunCore::configure_projectiles, DEFVAL(Dictionary()));
    ClassDB::bind_method(D_METHOD("burst_debris", "position", "count", "speed", "damage", "color", "source_id"), &SpeedRunCore::burst_debris);
    ClassDB::bind_method(D_METHOD("fire_shot", "from", "angle", "damage", "options"), &SpeedRunCore::fire_shot, DEFVAL(Dictionary()));
    ClassDB::bind_method(D_METHOD("step_projectiles", "world_dt"), &SpeedRunCore::step_projectiles);
    ClassDB::bind_method(D_METHOD("projectiles_snapshot"), &SpeedRunCore::projectiles_snapshot);
    ClassDB::bind_method(D_METHOD("configure_frame", "config"), &SpeedRunCore::configure_frame);
    ClassDB::bind_method(D_METHOD("step_frame", "real_dt", "input", "center", "half", "camera_zoom"), &SpeedRunCore::step_frame);
    ClassDB::bind_method(D_METHOD("configure", "data"), &SpeedRunCore::configure);
    ClassDB::bind_method(D_METHOD("configure_pickups", "config", "stats"), &SpeedRunCore::configure_pickups);
    ClassDB::bind_method(D_METHOD("pickups_snapshot"), &SpeedRunCore::pickups_snapshot);
    ClassDB::bind_method(D_METHOD("pickup_buffer", "kind", "size", "color", "view"), &SpeedRunCore::pickup_buffer);
    ClassDB::bind_method(D_METHOD("step_pickups", "world_dt"), &SpeedRunCore::step_pickups);
    ClassDB::bind_method(D_METHOD("drain_collections"), &SpeedRunCore::drain_collections);
    ClassDB::bind_method(D_METHOD("configure_combat", "config", "stats"), &SpeedRunCore::configure_combat);
    ClassDB::bind_method(D_METHOD("collide_ship", "from", "radius"), &SpeedRunCore::collide_ship);
    ClassDB::bind_method(D_METHOD("combat_snapshot"), &SpeedRunCore::combat_snapshot);
    ClassDB::bind_method(D_METHOD("drain_events"), &SpeedRunCore::drain_events);
    ClassDB::bind_method(D_METHOD("configure_ship", "config", "stats"), &SpeedRunCore::configure_ship);
    ClassDB::bind_method(D_METHOD("step_ship", "real_dt", "world_dt", "input"), &SpeedRunCore::step_ship);
    ClassDB::bind_method(D_METHOD("ship_snapshot"), &SpeedRunCore::ship_snapshot);
    ClassDB::bind_method(D_METHOD("configure_draw", "config", "stats"), &SpeedRunCore::configure_draw);
    ClassDB::bind_method(D_METHOD("handle_draw", "input", "clock_msec", "camera_zoom"), &SpeedRunCore::handle_draw);
    ClassDB::bind_method(D_METHOD("step_draw", "real_dt"), &SpeedRunCore::step_draw);
    ClassDB::bind_method(D_METHOD("world_scale"), &SpeedRunCore::world_scale);
    ClassDB::bind_method(D_METHOD("draw_snapshot"), &SpeedRunCore::draw_snapshot);
    ClassDB::bind_method(D_METHOD("start", "seed", "first_id", "first_gem_seq"), &SpeedRunCore::start, DEFVAL(1), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("step", "delta"), &SpeedRunCore::step);
    ClassDB::bind_method(D_METHOD("set_motion_context", "ship", "center", "half"), &SpeedRunCore::set_motion_context);
    ClassDB::bind_method(D_METHOD("spawn_enemy", "type", "position"), &SpeedRunCore::spawn_enemy);
    ClassDB::bind_method(D_METHOD("remove_enemy", "id"), &SpeedRunCore::remove_enemy);
    ClassDB::bind_method(D_METHOD("enemies_snapshot"), &SpeedRunCore::enemies_snapshot);
    ClassDB::bind_method(D_METHOD("rebuild_enemy_grid", "cell_size"), &SpeedRunCore::rebuild_enemy_grid);
    ClassDB::bind_method(D_METHOD("query_enemy_ids", "lo", "hi"), &SpeedRunCore::query_enemy_ids);
    ClassDB::bind_method(D_METHOD("enemy_buffer", "type", "scale", "angle_offset"), &SpeedRunCore::enemy_buffer);
    ClassDB::bind_method(D_METHOD("close"), &SpeedRunCore::close);
    ClassDB::bind_method(D_METHOD("inspect"), &SpeedRunCore::inspect);
}

bool SpeedRunCore::start(int64_t seed, int64_t first_id, int64_t first_gem_seq) {
    if (started || closed || first_id <= 0 || first_gem_seq < 0) return false;
    if (lifecycle_ready && !frame_ready) return false;
    if (forward.ready && !combat_ready) return false;
    if ((draw_ready && !ship_ready) || (combat_ready && (!ship_ready || !pickups_ready))) return false;
    if (frame_ready && (!ship_ready || !draw_ready || !combat_ready || !pickups_ready)) return false;
    next_id = first_id;
    next_gem_seq = first_gem_seq;
    rng.instantiate();
    rng->set_seed(seed);
    started = true;
    return true;
}

bool SpeedRunCore::step(double delta) {
    if (!started || closed || !std::isfinite(delta) || delta <= 0.0 || !std::isfinite(time + delta)) return false;
    if (!rows_by_id.empty() && !motion_ready) return false;
    time += delta;
    world_time += delta;
    advance_enemies(delta);
    return true;
}

void SpeedRunCore::advance_enemies(double delta) {
    ++ticks;
    if (aim_ready && !draw.tracing) {
        const Vector2 toward = ship_pos - enemy_aim;
        const double distance = toward.length();
        if (distance >= 1e-6) {
            const double step = std::min(distance * (1.0 - std::exp(-delta / enemy_aim_lag)), enemy_aim_speed * delta);
            enemy_aim += toward / distance * step;
        }
    }
    const Vector2 limit = view_half * 1.25 + Vector2(300, 300);
    for (auto &enemy : enemies) {
        if (!enemy.alive || enemy.dead) continue;
        if (enemy.hit_cd > 0) enemy.hit_cd -= delta;
        if (enemy.flash > 0) enemy.flash -= delta;
        enemy.age += delta;
        const Vector2 relative = enemy.pos - view_center;
        const bool far = std::abs(relative.x) > limit.x || std::abs(relative.y) > limit.y;
        if (!far || (enemy.id + ticks) % 3 == 0) {
            const auto &def = definitions[enemy.definition];
            if (def.kind == speed::EnemyDefinition::Kind::Shield) {
                const double bdt = far ? delta * 3.0 : delta;
                enemy.fire_t = std::max(0.0, enemy.fire_t - bdt);
                const Vector2 toward = enemy_aim - enemy.pos;
                double distance = toward.length();
                if (distance < 0.001) distance = 1;
                enemy.vel += (toward / distance * def.speed - enemy.vel) * std::min(1.0, def.accel * bdt);
                const double difference = double((ship_pos - enemy.pos).angle()) - enemy.facing;
                const double wrapped = difference - (2.0 * Math_PI) * std::floor((difference + Math_PI) / (2.0 * Math_PI));
                enemy.facing += std::clamp(wrapped, -def.turn * bdt, def.turn * bdt);
            } else {
                const Vector2 toward = ship_pos - enemy.pos;
                const double distance = toward.length();
                enemy.vel = Vector2();
                if (distance > 0.001) {
                    const Vector2 unit = toward / distance;
                    enemy.vel = unit * def.speed;
                    enemy.facing = unit.angle();
                }
            }
        }
        enemy.pos += enemy.vel * delta;
    }
}

void SpeedRunCore::close() {
    closed = true;
    rng.unref();
    enemies.clear();
    enemies.shrink_to_fit();
    free_rows.clear();
    dead_rows.clear();
    rows_by_id.clear();
    definitions.clear();
    draw = Draw();
    grid = EnemyGrid();
    events.clear();
    hostiles.clear(); free_hostiles.clear();
    friends.clear(); free_friends.clear(); live_friends = 0; live_debris = 0;
    gems.clear(); coins.clear(); free_gems.clear(); free_coins.clear(); gem_queue.clear(); collections.clear();
}

Dictionary SpeedRunCore::inspect() const {
    Dictionary out;
    out["active"] = started && !closed;
    out["phase"] = int(phase);
    out["sequence_t"] = sequence_t;
    out["closed"] = closed;
    out["time"] = time;
    out["world_time"] = world_time;
    out["sim_time"] = sim_time;
    out["ticks"] = ticks;
    out["rng_state"] = rng.is_valid() ? String::num_int64(rng->get_state()) : String();
    return out;
}

// 入力全体を検証してから差し替え、不正な途中結果を残さない。
bool SpeedRunCore::configure(const Dictionary &data) {
    if (started || closed || !data.has("version") ||
            (data["version"].get_type() != Variant::INT && data["version"].get_type() != Variant::FLOAT) || double(data["version"]) != 2.0 ||
            !data.has("enemies") || data["enemies"].get_type() != Variant::ARRAY) return false;
    double aim_lag = 0, aim_speed = 0;
    if (data.has("motion")) {
        if (data["motion"].get_type() != Variant::DICTIONARY) return false;
        const Dictionary motion = data["motion"];
        for (const char *key : {"aim_lag", "aim_speed"}) {
            if (!motion.has(key) || (motion[key].get_type() != Variant::FLOAT && motion[key].get_type() != Variant::INT)) return false;
            if (!std::isfinite(double(motion[key])) || double(motion[key]) <= 0) return false;
        }
        aim_lag = motion["aim_lag"]; aim_speed = motion["aim_speed"];
    }
    const Array rows = data["enemies"];
    std::vector<speed::EnemyDefinition> parsed;
    for (int64_t i = 0; i < rows.size(); ++i) {
        if (rows[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = rows[i];
        if (!row.has("id") || row["id"].get_type() != Variant::STRING || String(row["id"]).is_empty() ||
                !row.has("behavior") || row["behavior"].get_type() != Variant::STRING || (String(row["behavior"]) != "chase" && String(row["behavior"]) != "shield")) return false;
        speed::EnemyDefinition def;
        def.id = String(row["id"]);
        if (String(row["behavior"]) == "shield") {
            if (aim_lag <= 0 || !row.has("shield") || row["shield"].get_type() != Variant::DICTIONARY) return false;
            def.kind = speed::EnemyDefinition::Kind::Shield;
            const Dictionary shield = row["shield"];
            const char *keys[] = {"accel", "turn", "weak_arc", "front_arc", "reflect_speed", "reflect_life", "reflect_dmg", "reflect_interval", "shield_time"};
            double *values[] = {&def.accel, &def.turn, &def.weak_arc, &def.front_arc, &def.reflect_speed, &def.reflect_life, &def.reflect_damage, &def.reflect_interval, &def.shield_time};
            for (int k = 0; k < 9; ++k) {
                if (!shield.has(keys[k])) return false;
                const Variant value = shield[keys[k]];
                if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return false;
                *values[k] = double(value);
                if (!std::isfinite(*values[k]) || *values[k] < 0) return false;
            }
        }
        for (const auto &previous : parsed) if (previous.id == def.id) return false;
        const char *keys[] = {"hp", "armor", "radius", "speed", "fire_interval", "xp", "knockback", "hitstop_multiplier"};
        double *values[] = {&def.hp, &def.armor, &def.radius, &def.speed, &def.fire_interval, &def.xp, &def.knockback, &def.hitstop_multiplier};
        for (int k = 0; k < 8; ++k) {
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
    enemy_aim_lag = aim_lag; enemy_aim_speed = aim_speed; aim_ready = aim_lag > 0;
    return true;
}

bool SpeedRunCore::set_motion_context(Vector2 ship, Vector2 center, Vector2 half) {
    if (!started || closed || !ship.is_finite() || !center.is_finite() || !half.is_finite() || half.x <= 0 || half.y <= 0) return false;
    if (!motion_ready) enemy_aim = ship;
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
        row["radius"] = def.radius; row["facing"] = enemy.facing; row["dead"] = enemy.dead ? 1 : 0;
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
    for (const auto &enemy : enemies) if (enemy.alive && !enemy.dead && definitions[enemy.definition].id == type) ++count;
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    for (const auto &enemy : enemies) {
        if (!enemy.alive || enemy.dead || definitions[enemy.definition].id != type) continue;
        const double radius = definitions[enemy.definition].radius * scale;
        const double angle = enemy.facing + angle_offset;
        const double c = std::cos(angle) * radius, s = std::sin(angle) * radius;
        out[index++] = c; out[index++] = -s; out[index++] = 0; out[index++] = enemy.pos.x;
        out[index++] = s; out[index++] = c; out[index++] = 0; out[index++] = enemy.pos.y;
        out[index++] = enemy.flash > 0 ? 1 : 0; out[index++] = 0; out[index++] = 0; out[index++] = 1;
    }
    return buffer;
}


bool SpeedRunCore::configure_frame(const Dictionary &config) {
    if (started || closed) return false;
    double values[3];
    const char *keys[] = {"world_tick_div", "grid_cell", "trace_radius"};
    for (int i = 0; i < 3; ++i) {
        if (!config.has(keys[i])) return false;
        const Variant value = config[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        values[i] = double(value);
        if (!std::isfinite(values[i]) || values[i] <= 0) return false;
    }
    if (std::floor(values[0]) != values[0] || values[0] > INT32_MAX) return false;
    world_div = int64_t(values[0]); frame_grid_cell = values[1]; trace_radius = values[2]; frame_ready = true;
    return true;
}

bool SpeedRunCore::set_run_guards(const Dictionary &guards) {
    if (!started || closed) return false;
    const Array keys = guards.keys();
    for (int i = 0; i < keys.size(); ++i) {
        const String key = keys[i];
        if (key != "controls_locked" && key != "encounter_protected" && key != "steering_locked" && key != "invincible" && key != "hitstop_enabled") return false;
        if (guards[keys[i]].get_type() != Variant::BOOL) return false;
    }
    controls_locked = guards.get("controls_locked", controls_locked);
    encounter_protected = guards.get("encounter_protected", encounter_protected);
    steering_locked = guards.get("steering_locked", steering_locked);
    invincible = guards.get("invincible", invincible);
    hitstop_enabled = guards.get("hitstop_enabled", hitstop_enabled);
    if (!hitstop_enabled) hitstop = 0;
    return true;
}

bool SpeedRunCore::set_paused(bool paused) {
    if (!started || closed || (phase != Phase::Play && phase != Phase::Paused)) return false;
    phase = paused ? Phase::Paused : Phase::Play;
    if (paused) hitstop = 0;
    return true;
}

bool SpeedRunCore::step_frame(double real_dt, const Dictionary &input, Vector2 center, Vector2 half, double camera_zoom) {
    if (!started || closed || !frame_ready || !std::isfinite(real_dt) || real_dt <= 0 ||
            !center.is_finite() || !half.is_finite() || half.x <= 0 || half.y <= 0 || !std::isfinite(camera_zoom) || camera_zoom <= 0) return false;
    for (const char *key : {"touch", "has_cursor", "stick_active", "press", "alt_press", "pen_release"}) if (input.has(key) && input[key].get_type() != Variant::BOOL) return false;
    for (const char *key : {"cursor", "stick", "pen"}) if (input.has(key) && (input[key].get_type() != Variant::VECTOR2 || !Vector2(input[key]).is_finite())) return false;
    if (phase == Phase::Dying) { step_death(real_dt); return true; }
    if (phase != Phase::Play) return true;
    if (controls_locked || encounter_protected) hitstop = 0;
    const Dictionary intent = controls_locked || steering_locked ? Dictionary() : input;
    if (controls_locked) ship.vel = Vector2();
    sim_time += real_dt;
    if (!motion_ready) enemy_aim = ship_pos;
    view_center = center; view_half = half; motion_ready = true;
    handle_draw(intent, int64_t(std::round(sim_time * 1000.0)), camera_zoom);
    if (hitstop > 0) { hitstop = std::max(0.0, hitstop - real_dt); return true; }
    if (!draw.tracing && dash_stop > 0) dash_stop = std::max(0.0, dash_stop - real_dt * combat_config.kill_hitstop_regen);
    step_draw(real_dt);
    if (check_run_end()) return true;
    const double world_dt = real_dt * world_scale();
    time += real_dt; world_time += world_dt;
    world_accum += world_dt; ++world_steps;
    const bool world_step = world_steps >= world_div;
    const double accumulated = world_accum;
    if (world_step) {
        world_accum = 0; world_steps = 0;
        advance_enemies(accumulated);
        if (check_run_end()) return true;
        rebuild_enemy_grid(frame_grid_cell);
    }
    step_ship(real_dt, world_dt, intent);
    if (world_dt > 0 && !controls_locked) step_forward(world_dt);
    if (world_step && accumulated > 0) {
        step_projectiles(accumulated);
        step_hostiles(accumulated);
    }
    if (check_run_end()) return true;
    for (size_t row : dead_rows) if (enemies[row].alive && enemies[row].dead) remove_enemy(enemies[row].id);
    dead_rows.clear();
    if (world_step) step_pickups(accumulated);
    return true;
}
