#include "run_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_attack_budget_mode", "enabled", "from_stage"), &SpeedRunCore::set_attack_budget_mode);
    ClassDB::bind_method(D_METHOD("advance_attack_budget", "at"), &SpeedRunCore::advance_attack_budget);
    ClassDB::bind_method(D_METHOD("cancel_attack_wait", "owner", "id"), &SpeedRunCore::cancel_attack_wait, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("cancel_attack", "owner", "id"), &SpeedRunCore::cancel_attack);
    ClassDB::bind_method(D_METHOD("owns_attack", "owner", "id"), &SpeedRunCore::owns_attack);
    ClassDB::bind_method(D_METHOD("attack_token", "owner"), &SpeedRunCore::attack_token);
    ClassDB::bind_method(D_METHOD("passive_attack", "owner", "id"), &SpeedRunCore::passive_attack);
    ClassDB::bind_method(D_METHOD("track_attack_external", "token", "key"), &SpeedRunCore::track_attack_external);
    ClassDB::bind_method(D_METHOD("release_attack_external", "token", "key"), &SpeedRunCore::release_attack_external);
    ClassDB::bind_method(D_METHOD("configure_attack_budget", "settings"), &SpeedRunCore::configure_attack_budget);
    ClassDB::bind_method(D_METHOD("set_attack_guard", "active", "until"), &SpeedRunCore::set_attack_guard);
    ClassDB::bind_method(D_METHOD("request_attack", "owner", "categories", "id", "duration", "priority", "cost"), &SpeedRunCore::request_attack);
    ClassDB::bind_method(D_METHOD("attack_budget_snapshot"), &SpeedRunCore::attack_budget_snapshot);
    ClassDB::bind_method(D_METHOD("configure_clips", "data"), &SpeedRunCore::configure_clips);
    ClassDB::bind_method(D_METHOD("step_clips"), &SpeedRunCore::step_clips);
    ClassDB::bind_method(D_METHOD("clips_snapshot"), &SpeedRunCore::clips_snapshot);
    ClassDB::bind_method(D_METHOD("configure_formations", "data", "base_view"), &SpeedRunCore::configure_formations);
    ClassDB::bind_method(D_METHOD("spawn_formation", "index", "layout", "entry", "types", "value", "priority", "managed"), &SpeedRunCore::spawn_formation);
    ClassDB::bind_method(D_METHOD("set_attack_formation_mode", "enabled"), &SpeedRunCore::set_attack_formation_mode);
    ClassDB::bind_method(D_METHOD("enemy_attack_snapshot"), &SpeedRunCore::enemy_attack_snapshot);
    ClassDB::bind_method(D_METHOD("set_population_mode", "enabled", "bonus", "blocked"), &SpeedRunCore::set_population_mode);
    ClassDB::bind_method(D_METHOD("configure_refill", "config"), &SpeedRunCore::configure_refill);
    ClassDB::bind_method(D_METHOD("step_population", "world_dt", "bonus"), &SpeedRunCore::step_population);
    ClassDB::bind_method(D_METHOD("refill_snapshot"), &SpeedRunCore::refill_snapshot);
    ClassDB::bind_method(D_METHOD("configure_population", "config"), &SpeedRunCore::configure_population);
    ClassDB::bind_method(D_METHOD("survey_population", "target"), &SpeedRunCore::survey_population);
    ClassDB::bind_method(D_METHOD("population_spawn_point", "extra"), &SpeedRunCore::population_spawn_point);
    ClassDB::bind_method(D_METHOD("population_snapshot"), &SpeedRunCore::population_snapshot);
    ClassDB::bind_method(D_METHOD("configure_enemy_order", "order"), &SpeedRunCore::configure_enemy_order);
    ClassDB::bind_method(D_METHOD("enemy_order_snapshot"), &SpeedRunCore::enemy_order_snapshot);
    ClassDB::bind_method(D_METHOD("configure_spawn_timeline", "data"), &SpeedRunCore::configure_spawn_timeline);
    ClassDB::bind_method(D_METHOD("spawn_target", "at", "bonus"), &SpeedRunCore::spawn_target);
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
    ClassDB::bind_method(D_METHOD("spawn_enemy", "type", "position", "options"), &SpeedRunCore::spawn_enemy, DEFVAL(Dictionary()));
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
    for (const auto &rows : behavior_rows) for (size_t row : rows) {
        auto &enemy = enemies[row];
        if (enemy.dead) continue;
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
                enemy.vel += (toward / distance * enemy.speed - enemy.vel) * std::min(1.0, def.accel * bdt);
                const double difference = double((ship_pos - enemy.pos).angle()) - enemy.facing;
                const double wrapped = difference - (2.0 * Math_PI) * std::floor((difference + Math_PI) / (2.0 * Math_PI));
                enemy.facing += std::clamp(wrapped, -def.turn * bdt, def.turn * bdt);
            } else {
                const Vector2 toward = ship_pos - enemy.pos;
                const double distance = toward.length();
                enemy.vel = Vector2();
                if (distance > 0.001) {
                    const Vector2 unit = toward / distance;
                    enemy.vel = unit * enemy.speed;
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
    behavior_rows.clear(); behavior_kinds.clear();
    dead_rows.clear();
    rows_by_id.clear();
    definitions.clear(); formations.clear(); clips.clear(); clips_ready = false;
    spawn_timeline = speed::SpawnTimeline();
    population = Population();
    attack_budget = AttackBudget();
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
        if (row.has("attack")) {
            if (row["attack"].get_type() != Variant::DICTIONARY) return false;
            const Dictionary source = row["attack"];
            const char *keys[] = {"value", "priority", "weight"};
            double *values[] = {&def.attack_value, &def.attack_priority, &def.attack_weight};
            for (int k = 0; k < 3; ++k) {
                const Variant value = source.get(keys[k], Variant());
                if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
                *values[k] = value;
            }
            if (source.get("managed", Variant()).get_type() != Variant::BOOL) return false;
            def.attack_managed = source["managed"];
            const Variant telegraph = source.get("telegraph", 0.0);
            if ((telegraph.get_type() != Variant::FLOAT && telegraph.get_type() != Variant::INT) || !std::isfinite(double(telegraph))) return false;
            def.attack_telegraph = telegraph;
        }
        if (row.has("spawn")) {
            if (row["spawn"].get_type() != Variant::DICTIONARY) return false;
            const Dictionary source = row["spawn"];
            const Variant rank = source.get("rank", Variant());
            if ((rank.get_type() != Variant::INT && rank.get_type() != Variant::FLOAT) || !std::isfinite(double(rank)) || double(rank) < 0 || double(rank) > INT32_MAX || std::floor(double(rank)) != double(rank)) return false;
            if (source.get("size_var", Variant()).get_type() != Variant::BOOL) return false;
            def.rank = int64_t(rank); def.size_var = source["size_var"]; def.spawn_ready = true;
        }
        if (row.has("scaling")) {
            if (row["scaling"].get_type() != Variant::DICTIONARY) return false;
            const Dictionary source = row["scaling"];
            const char *keys[] = {"radius", "hp", "armor", "hp_mult", "armor_mult", "character", "visual", "collision"};
            double *values[] = {&def.scaling.radius, &def.scaling.hp, &def.scaling.armor, &def.scaling.hp_mult, &def.scaling.armor_mult, &def.scaling.character, &def.scaling.visual, &def.scaling.collision};
            for (int k = 0; k < 8; ++k) {
                const Variant value = source.get(keys[k], Variant());
                if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value)) || double(value) < 0) return false;
                *values[k] = value;
            }
            if (def.scaling.radius <= 0 || source.get("fixed_sprite", Variant()).get_type() != Variant::BOOL) return false;
            def.scaling.fixed_sprite = source["fixed_sprite"]; def.scaling.ready = true;
        }
        parsed.push_back(def);
    }
    definitions = std::move(parsed); formations.clear(); clips.clear(); clips_ready = false;
    population = Population();
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

bool SpeedRunCore::configure_enemy_order(const PackedStringArray &order) {
    if (started || closed) return false;
    std::vector<speed::EnemyDefinition::Kind> kinds;
    for (int64_t i = 0; i < order.size(); ++i) {
        if (order[i] != "chase" && order[i] != "shield") return false;
        const auto kind = order[i] == "chase" ? speed::EnemyDefinition::Kind::Chase : speed::EnemyDefinition::Kind::Shield;
        if (std::find(kinds.begin(), kinds.end(), kind) != kinds.end()) return false;
        kinds.push_back(kind);
    }
    behavior_kinds = std::move(kinds);
    behavior_rows.clear(); behavior_rows.resize(behavior_kinds.size());
    return true;
}

PackedInt64Array SpeedRunCore::enemy_order_snapshot() const {
    PackedInt64Array out;
    if (closed) return out;
    for (const auto &rows : behavior_rows) for (size_t row : rows) out.push_back(enemies[row].id);
    return out;
}

int64_t SpeedRunCore::spawn_enemy(StringName type, Vector2 position, const Dictionary &options) {
    if (!started || closed || !position.is_finite() || next_id == INT64_MAX) return -1;
    size_t definition = 0;
    while (definition < definitions.size() && definitions[definition].id != type) ++definition;
    if (definition == definitions.size()) return -1;
    Enemy enemy;
    const Array keys = options.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING && keys[i].get_type() != Variant::STRING_NAME) return -1;
        const String key = keys[i];
        if (key != "elite" && key != "size" && key != "facing" && key != "vel" && key != "attack_group" && key != "attack_value" && key != "attack_priority" && key != "attack_managed") return -1;
    }
    if (options.has("elite") && options["elite"].get_type() != Variant::BOOL) return -1;
    enemy.elite = options.get("elite", false);
    if (options.has("facing")) {
        const Variant facing = options["facing"];
        if ((facing.get_type() != Variant::FLOAT && facing.get_type() != Variant::INT) || !std::isfinite(double(facing))) return -1;
        enemy.facing = facing;
    }
    if (options.has("vel")) {
        if (options["vel"].get_type() != Variant::VECTOR2 || !Vector2(options["vel"]).is_finite()) return -1;
        enemy.vel = options["vel"];
    }
    enemy.definition = definition;
    enemy.pos = position;
    const auto &def = definitions[definition];
    if (options.has("attack_group")) {
        const Variant group = options["attack_group"];
        if (group.get_type() != Variant::INT || int64_t(group) < 0) return -1;
        enemy.attack_group = group;
    }
    for (const char *key : {"attack_value", "attack_priority"}) if (options.has(key)) {
        const Variant value = options[key];
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return -1;
    }
    if (options.has("attack_managed") && options["attack_managed"].get_type() != Variant::BOOL) return -1;
    enemy.attack_priority = options.get("attack_priority", def.attack_priority);
    enemy.attack_value = enemy.attack_group > 0 ? double(options.get("attack_value", 1.0)) : def.attack_value;
    enemy.attack_managed = !attack_formation_mode ? def.attack_weight > 0 :
        (enemy.attack_group > 0 ? bool(options.get("attack_managed", enemy.attack_value > 0)) : def.attack_managed);
    enemy.hp = enemy.max_hp = def.hp;
    enemy.radius = def.radius; enemy.armor = def.armor; enemy.xp = def.xp; enemy.speed = def.speed;
    if ((options.has("size") || enemy.elite) && !def.scaling.ready) return -1;
    if (def.scaling.ready) {
        const auto &s = def.scaling;
        double size = s.radius;
        if (options.has("size")) {
            const Variant value = options["size"];
            if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value)) || double(value) <= 0) return -1;
            size = value;
        }
        const double z = size / s.radius;
        double radius = size * (enemy.elite ? 1.25 : 1.0);
        if (s.fixed_sprite) radius = s.radius;
        radius *= s.character;
        enemy.radius = radius * s.visual * s.collision;
        enemy.hp = enemy.max_hp = s.hp * z * z * s.hp_mult * (enemy.elite ? 3.0 : 1.0);
        enemy.armor = s.armor * z * s.armor_mult * (enemy.elite ? 1.3 : 1.0);
        enemy.xp = def.xp * z * (enemy.elite ? 4.0 : 1.0);
        for (double value : {enemy.radius, enemy.hp, enemy.armor, enemy.xp}) if (!std::isfinite(value)) return -1;
    }
    size_t row = enemies.size();
    if (free_rows.empty()) enemies.emplace_back();
    else { row = free_rows.back(); free_rows.pop_back(); }
    const auto found = std::find(behavior_kinds.begin(), behavior_kinds.end(), def.kind);
    enemy.behavior_group = size_t(found - behavior_kinds.begin());
    if (found == behavior_kinds.end()) { behavior_kinds.push_back(def.kind); behavior_rows.emplace_back(); }
    auto &active_rows = behavior_rows[enemy.behavior_group];
    enemy.behavior_slot = active_rows.size(); active_rows.push_back(row);
    enemy.id = next_id++;
    enemy.fire_t = definitions[definition].fire_interval * (0.5 + rng->randf() * 0.5);
    enemy.alive = true;
    enemies[row] = enemy;
    rows_by_id[enemy.id] = row;
    if (def.rank >= 3) { Dictionary event; event["id"] = enemy.id; event["enemy_type"] = def.id; emit_event("strong_spawn", event); }
    return enemy.id;
}

bool SpeedRunCore::remove_enemy(int64_t id) {
    if (!started || closed) return false;
    auto found = rows_by_id.find(id);
    if (found == rows_by_id.end()) return false;
    auto &enemy = enemies[found->second];
    auto &active_rows = behavior_rows[enemy.behavior_group];
    const size_t last = active_rows.back();
    active_rows[enemy.behavior_slot] = last;
    enemies[last].behavior_slot = enemy.behavior_slot;
    active_rows.pop_back();
    enemy.alive = false;
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
        row["hp"] = enemy.hp; row["armor"] = enemy.armor;
        row["radius"] = enemy.radius; row["facing"] = enemy.facing; row["dead"] = enemy.dead ? 1 : 0;
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
        const double radius = enemy.radius * scale;
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
        if (attack_budget.frame_enabled) {
            sync_attack_budget();
            if (!advance_attack_budget(world_time)) return false;
        }
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
    if (world_step) {
        if (population.frame_enabled && !population.blocked && !attack_guard_active() && !step_population(accumulated, population.bonus)) return false;
        step_pickups(accumulated);
    }
    return true;
}

bool SpeedRunCore::set_attack_formation_mode(bool enabled) {
    if (closed) return false;
    attack_formation_mode = enabled;
    return true;
}

Array SpeedRunCore::enemy_attack_snapshot() const {
    Array out;
    if (closed) return out;
    std::vector<const Enemy *> ordered;
    for (const auto &enemy : enemies) if (enemy.alive) ordered.push_back(&enemy);
    std::sort(ordered.begin(), ordered.end(), [](const auto *a, const auto *b) { return a->id < b->id; });
    for (const auto *enemy : ordered) {
        Dictionary row;
        row["id"] = enemy->id; row["group"] = enemy->attack_group;
        row["value"] = enemy->attack_value; row["priority"] = enemy->attack_priority;
        row["managed"] = enemy->attack_managed; out.append(row);
    }
    return out;
}
