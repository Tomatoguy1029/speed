#include "run_core.h"
#include "../../native/geometry.h"
#include "../systems/enemy_system.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure_bite_zone", "data"), &SpeedRunCore::configure_bite_zone);
    ClassDB::bind_method(D_METHOD("fire_bite_zone", "at", "radius", "delay", "damage", "color", "token"), &SpeedRunCore::fire_bite_zone, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("step_hazards", "dt"), &SpeedRunCore::step_hazards);
    ClassDB::bind_method(D_METHOD("hazards_snapshot"), &SpeedRunCore::hazards_snapshot);
    ClassDB::bind_method(D_METHOD("set_enemy_motion", "id", "state"), &SpeedRunCore::set_enemy_motion);
    ClassDB::bind_method(D_METHOD("enemy_motion_snapshot"), &SpeedRunCore::enemy_motion_snapshot);
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
    ClassDB::bind_method(D_METHOD("follow_hound", "id", "goal", "until", "scale"), &SpeedRunCore::follow_hound);
    ClassDB::bind_method(D_METHOD("avoid_strong", "dt"), &SpeedRunCore::avoid_strong);
    ClassDB::bind_method(D_METHOD("apply_external_progression", "stats", "hp", "waiting", "random_state"), &SpeedRunCore::apply_external_progression);
    ClassDB::bind_method(D_METHOD("set_forward_level", "level"), &SpeedRunCore::set_forward_level);
    ClassDB::bind_method(D_METHOD("progression_revision"), &SpeedRunCore::progression_revision);
    ClassDB::bind_method(D_METHOD("random_state"), &SpeedRunCore::random_state);
    ClassDB::bind_method(D_METHOD("configure_progression", "data"), &SpeedRunCore::configure_progression);
    ClassDB::bind_method(D_METHOD("grant_equipment", "kind", "id", "levels"), &SpeedRunCore::grant_equipment, DEFVAL(1));
    ClassDB::bind_method(D_METHOD("add_xp", "amount"), &SpeedRunCore::add_xp);
    ClassDB::bind_method(D_METHOD("open_cards", "initial"), &SpeedRunCore::open_cards, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("reroll_cards"), &SpeedRunCore::reroll_cards);
    ClassDB::bind_method(D_METHOD("choose_card", "index", "revision"), &SpeedRunCore::choose_card);
    ClassDB::bind_method(D_METHOD("resources_ready", "revision", "id", "status"), &SpeedRunCore::resources_ready);
    ClassDB::bind_method(D_METHOD("drain_resource_requests"), &SpeedRunCore::drain_resource_requests);
    ClassDB::bind_method(D_METHOD("progression_snapshot"), &SpeedRunCore::progression_snapshot);
    ClassDB::bind_method(D_METHOD("hound_snapshot"), &SpeedRunCore::hound_snapshot);
    ClassDB::bind_method(D_METHOD("remove_enemy", "id"), &SpeedRunCore::remove_enemy);
    ClassDB::bind_method(D_METHOD("enemies_snapshot"), &SpeedRunCore::enemies_snapshot);
    ClassDB::bind_method(D_METHOD("rebuild_enemy_grid", "cell_size"), &SpeedRunCore::rebuild_enemy_grid);
    ClassDB::bind_method(D_METHOD("query_enemy_ids", "lo", "hi"), &SpeedRunCore::query_enemy_ids);
    ClassDB::bind_method(D_METHOD("enemy_buffer", "type", "scale", "angle_offset"), &SpeedRunCore::enemy_buffer);
    ClassDB::bind_method(D_METHOD("close"), &SpeedRunCore::close);
    ClassDB::bind_method(D_METHOD("checkpoint"), &SpeedRunCore::checkpoint);
    ClassDB::bind_method(D_METHOD("update_enemy_definition", "id", "data"), &SpeedRunCore::update_enemy_definition);
    ClassDB::bind_method(D_METHOD("enemy_handle", "id"), &SpeedRunCore::enemy_handle);
    ClassDB::bind_method(D_METHOD("valid_enemy_handle", "handle"), &SpeedRunCore::valid_enemy_handle);
    ClassDB::bind_method(D_METHOD("inspect"), &SpeedRunCore::inspect);
}

bool SpeedRunCore::start(int64_t seed, int64_t first_id, int64_t first_gem_seq) {
    if (runtime.state.started || runtime.state.closed || first_id <= 0 || first_gem_seq < 0) return false;
    if (runtime.state.lifecycle_ready && !runtime.state.frame_ready) return false;
    if (runtime.state.forward.ready && !runtime.state.combat_ready) return false;
    if ((runtime.state.draw_ready && !runtime.state.ship_ready) || (runtime.state.combat_ready && (!runtime.state.ship_ready || !runtime.state.pickups_ready))) return false;
    if (runtime.state.frame_ready && (!runtime.state.ship_ready || !runtime.state.draw_ready || !runtime.state.combat_ready || !runtime.state.pickups_ready)) return false;
    for (const auto &def : runtime.content->definitions) if ((def.kind == speed::EnemyDefinition::Kind::Biter || def.kind == speed::EnemyDefinition::Kind::Hound) && (!runtime.state.ship_ready || !runtime.state.bite_zone_config.ready)) return false;
    runtime.state.next_id = first_id;
    runtime.state.next_gem_seq = first_gem_seq;
    runtime.state.rng.instantiate();
    runtime.state.rng->set_seed(seed);
    runtime.state.started = true;
    return true;
}

bool SpeedRunCore::step(double delta) {
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(delta) || delta <= 0.0 || !std::isfinite(runtime.state.time + delta)) return false;
    if (!runtime.state.rows_by_id.empty() && !runtime.state.motion_ready) return false;
    runtime.state.time += delta;
    runtime.state.world_time += delta;
    advance_enemies(delta);
    return true;
}

void SpeedRunCore::advance_enemies(double delta) {
    capture_avoidance();
    ++runtime.state.ticks;
    if (runtime.state.aim_ready && !runtime.state.draw.tracing) {
        const Vector2 toward = runtime.state.ship_pos - runtime.state.enemy_aim;
        const double distance = toward.length();
        if (distance >= 1e-6) {
            const double step = std::min(distance * (1.0 - std::exp(-delta / runtime.state.enemy_aim_lag)), runtime.state.enemy_aim_speed * delta);
            runtime.state.enemy_aim += toward / distance * step;
        }
    }
    const Vector2 limit = runtime.state.view_half * 1.25 + Vector2(300, 300);
    for (size_t group = 0; group < runtime.state.behavior_rows.size(); ++group) {
      const auto &rows = runtime.state.behavior_rows[group];
      if (runtime.state.behavior_kinds[group] == speed::EnemyDefinition::Kind::Hound) prepare_hounds(rows);
      for (size_t row : rows) {
        auto &enemy = runtime.state.enemies[row];
        if (enemy.dead || enemy.held) continue;
        if (enemy.stone > 0) { enemy.stone -= delta; enemy.vel = Vector2(); continue; }
        if (enemy.hit_cd > 0) enemy.hit_cd -= delta;
        if (enemy.flash > 0) enemy.flash -= delta;
        enemy.age += delta;
        const auto &def = runtime.content->definitions[enemy.definition];
        if (def.kind == speed::EnemyDefinition::Kind::Shield && enemy.slash_hold) { enemy.vel = Vector2(); continue; }
        if (enemy.shove_time > 0 || enemy.knock_t > 0) { update_pushed(enemy, delta); continue; }
        const Vector2 relative = enemy.pos - runtime.state.view_center;
        const bool far = std::abs(relative.x) > limit.x || std::abs(relative.y) > limit.y;
        if (def.kind == speed::EnemyDefinition::Kind::Biter || def.kind == speed::EnemyDefinition::Kind::Hound) { advance_biter(row, delta, far); continue; }
        if (!far || (enemy.id + runtime.state.ticks) % 3 == 0) {
            if (def.kind == speed::EnemyDefinition::Kind::Shield) {
                const double bdt = far ? delta * 3.0 : delta;
                enemy.fire_t = std::max(0.0, enemy.fire_t - bdt);
                const Vector2 toward = runtime.state.enemy_aim - enemy.pos;
                double distance = toward.length();
                if (distance < 0.001) distance = 1;
                enemy.vel += (toward / distance * enemy.speed - enemy.vel) * std::min(1.0, def.accel * bdt);
                const double difference = double((runtime.state.ship_pos - enemy.pos).angle()) - enemy.facing;
                const double wrapped = speed::angle_difference(difference);
                enemy.facing += std::clamp(wrapped, -def.turn * bdt, def.turn * bdt);
            } else {
                speed::EnemySystem::aim_chase(enemy, runtime.state.ship_pos);
            }
        }
        enemy.pos += enemy.vel * delta;
      }
    }
}

void SpeedRunCore::close() {
    runtime.state.closed = true;
    runtime.state.rng.unref();
    runtime.workspace.avoidance_ids.clear(); runtime.workspace.avoidance_from.clear();
    runtime.state.progression = Progression();
    runtime.state.hound_packs.clear();
    runtime.state.enemies.clear(); runtime.state.enemy_handles = {};
    runtime.state.enemies.shrink_to_fit();
    runtime.state.free_rows.clear();
    runtime.state.behavior_rows.clear(); runtime.state.behavior_kinds.clear();
    runtime.state.dead_rows.clear();
    runtime.state.rows_by_id.clear();
    runtime.replace_definitions({}); runtime.state.formations.clear(); runtime.state.clips.clear(); runtime.state.clips_ready = false;
    runtime.state.spawn_timeline = speed::SpawnTimeline();
    runtime.state.population = Population();
    runtime.state.attack_budget = AttackBudget();
    runtime.state.draw = Draw();
    runtime.state.grid = EnemyGrid();
    runtime.state.events.clear();
    runtime.state.hostiles.clear(); runtime.state.free_hostiles.clear();
    runtime.state.bite_zones.clear(); runtime.state.free_bite_zones.clear(); runtime.state.bite_zone_config = BiteZoneConfig();
    runtime.state.friends.clear(); runtime.state.free_friends.clear(); runtime.state.live_friends = 0; runtime.state.live_debris = 0;
    runtime.state.gems.clear(); runtime.state.coins.clear(); runtime.state.free_gems.clear(); runtime.state.free_coins.clear(); runtime.state.gem_queue.clear(); runtime.state.collections.clear();
}

Dictionary SpeedRunCore::inspect() const {
    Dictionary out;
    out["active"] = runtime.state.started && !runtime.state.closed;
    out["phase"] = int(runtime.state.phase);
    out["sequence_t"] = runtime.state.sequence_t;
    out["closed"] = runtime.state.closed;
    out["time"] = runtime.state.time;
    out["world_time"] = runtime.state.world_time;
    out["sim_time"] = runtime.state.sim_time;
    out["ticks"] = runtime.state.ticks;
    out["rng_state"] = runtime.state.rng.is_valid() ? String::num_int64(runtime.state.rng->get_state()) : String();
    return out;
}

// 入力全体を検証してから差し替え、不正な途中結果を残さない。
bool SpeedRunCore::configure(const Dictionary &data) {
    if (runtime.state.started || runtime.state.closed || !data.has("version") ||
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
                !row.has("behavior") || row["behavior"].get_type() != Variant::STRING || (String(row["behavior"]) != "chase" && String(row["behavior"]) != "shield" && String(row["behavior"]) != "biter" && String(row["behavior"]) != "hound")) return false;
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
        if (String(row["behavior"]) == "biter" || String(row["behavior"]) == "hound") {
            if (row.get("bite", Variant()).get_type() != Variant::DICTIONARY) return false;
            const Dictionary bite = row["bite"]; def.kind = speed::EnemyDefinition::Kind::Biter;
            const char *keys[] = {"turn", "bite_reach", "bite_telegraph", "bite_rest", "bite_radius", "bullet_dmg"};
            double *values[] = {&def.turn, &def.bite.reach, &def.bite.telegraph, &def.bite.rest, &def.bite.radius, &def.bite.damage};
            for (int k = 0; k < 6; ++k) {
                const Variant value = bite.get(keys[k], Variant());
                if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value)) || double(value) < 0) return false;
                *values[k] = value;
            }
            if (def.bite.telegraph <= 0) return false;
        }
        if (String(row["behavior"]) == "hound") {
            if (row.get("pack", Variant()).get_type() != Variant::DICTIONARY) return false;
            const Dictionary pack = row["pack"]; def.kind = speed::EnemyDefinition::Kind::Hound;
            if (pack.get("count", Variant()).get_type() != Variant::INT || int64_t(pack["count"]) < 1) return false;
            def.pack.count = pack["count"];
            const char *keys[] = {"gap", "reach", "alignment", "cohesion", "separation", "accel"};
            double *values[] = {&def.pack.gap, &def.pack.reach, &def.pack.alignment, &def.pack.cohesion, &def.pack.separation, &def.accel};
            for (int k = 0; k < 6; ++k) {
                const Variant value = pack.get(keys[k], Variant());
                if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
                *values[k] = value;
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
    runtime.replace_definitions(std::move(parsed)); runtime.state.formations.clear(); runtime.state.clips.clear(); runtime.state.clips_ready = false;
    runtime.state.population = Population();
    runtime.state.enemy_aim_lag = aim_lag; runtime.state.enemy_aim_speed = aim_speed; runtime.state.aim_ready = aim_lag > 0;
    return true;
}

bool SpeedRunCore::set_motion_context(Vector2 ship, Vector2 center, Vector2 half) {
    if (!runtime.state.started || runtime.state.closed || !ship.is_finite() || !center.is_finite() || !half.is_finite() || half.x <= 0 || half.y <= 0) return false;
    if (!runtime.state.motion_ready) runtime.state.enemy_aim = ship;
    runtime.state.ship_pos = ship; runtime.state.view_center = center; runtime.state.view_half = half;
    runtime.state.motion_ready = true;
    return true;
}

bool SpeedRunCore::configure_enemy_order(const PackedStringArray &order) {
    if (runtime.state.started || runtime.state.closed) return false;
    std::vector<speed::EnemyDefinition::Kind> kinds;
    for (int64_t i = 0; i < order.size(); ++i) {
        if (order[i] != "chase" && order[i] != "shield" && order[i] != "biter" && order[i] != "hound") return false;
        const auto kind = order[i] == "chase" ? speed::EnemyDefinition::Kind::Chase : order[i] == "shield" ? speed::EnemyDefinition::Kind::Shield : order[i] == "biter" ? speed::EnemyDefinition::Kind::Biter : speed::EnemyDefinition::Kind::Hound;
        if (std::find(kinds.begin(), kinds.end(), kind) != kinds.end()) return false;
        kinds.push_back(kind);
    }
    runtime.state.behavior_kinds = std::move(kinds);
    runtime.state.behavior_rows.clear(); runtime.state.behavior_rows.resize(runtime.state.behavior_kinds.size());
    return true;
}

PackedInt64Array SpeedRunCore::enemy_order_snapshot() const {
    PackedInt64Array out;
    if (runtime.state.closed) return out;
    for (const auto &rows : runtime.state.behavior_rows) for (size_t row : rows) out.push_back(runtime.state.enemies[row].id);
    return out;
}

int64_t SpeedRunCore::spawn_enemy(StringName type, Vector2 position, const Dictionary &options) {
    if (!runtime.state.started || runtime.state.closed || !position.is_finite() || runtime.state.next_id == INT64_MAX) return -1;
    size_t definition = 0;
    while (definition < runtime.content->definitions.size() && runtime.content->definitions[definition].id != type) ++definition;
    if (definition == runtime.content->definitions.size()) return -1;
    Enemy enemy;
    const Array keys = options.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING && keys[i].get_type() != Variant::STRING_NAME) return -1;
        const String key = keys[i];
        if (key != "elite" && key != "size" && key != "facing" && key != "vel" && key != "attack_group" && key != "attack_value" && key != "attack_priority" && key != "attack_managed" && key != "knock" && key != "hound_pack") return -1;
    }
    if (options.has("elite") && options["elite"].get_type() != Variant::BOOL) return -1;
    if (options.has("hound_pack") && options["hound_pack"].get_type() != Variant::INT) return -1;
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
    if (options.has("knock")) {
        const Variant value = options["knock"];
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return -1;
        enemy.knock_t = value;
    }
    enemy.definition = definition;
    enemy.pos = position;
    const auto &def = runtime.content->definitions[definition];
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
    enemy.attack_managed = !runtime.state.attack_formation_mode ? def.attack_weight > 0 :
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
    while (!runtime.state.free_rows.empty() && !runtime.state.enemy_handles.reusable(runtime.state.free_rows.back())) runtime.state.free_rows.pop_back();
    if (runtime.state.free_rows.empty() && runtime.state.enemies.size() >= UINT32_MAX) return -1;
    size_t row = runtime.state.enemies.size();
    if (runtime.state.free_rows.empty()) runtime.state.enemies.emplace_back();
    else { row = runtime.state.free_rows.back(); runtime.state.free_rows.pop_back(); }
    const auto found = std::find(runtime.state.behavior_kinds.begin(), runtime.state.behavior_kinds.end(), def.kind);
    enemy.behavior_group = size_t(found - runtime.state.behavior_kinds.begin());
    if (found == runtime.state.behavior_kinds.end()) { runtime.state.behavior_kinds.push_back(def.kind); runtime.state.behavior_rows.emplace_back(); }
    auto &active_rows = runtime.state.behavior_rows[enemy.behavior_group];
    enemy.behavior_slot = active_rows.size(); active_rows.push_back(row);
    enemy.id = runtime.state.next_id++;
    enemy.fire_t = runtime.content->definitions[definition].fire_interval * (0.5 + runtime.state.rng->randf() * 0.5);
    enemy.alive = true;
    speed::EnemySystem::insert(runtime.state, uint32_t(row), enemy);
    runtime.state.rows_by_id[enemy.id] = row;
    if (def.kind == speed::EnemyDefinition::Kind::Hound) spawn_hounds(row, options);
    if (def.rank >= 3) { Dictionary event; event["id"] = enemy.id; event["enemy_type"] = def.id; emit_event("strong_spawn", event); }
    return enemy.id;
}

bool SpeedRunCore::remove_enemy(int64_t id) {
    if (!runtime.state.started || runtime.state.closed) return false;
    auto found = runtime.state.rows_by_id.find(id);
    if (found == runtime.state.rows_by_id.end()) return false;
    remove_hound(found->second);
    auto &enemy = runtime.state.enemies[found->second];
    auto &active_rows = runtime.state.behavior_rows[enemy.behavior_group];
    const size_t last = active_rows.back();
    active_rows[enemy.behavior_slot] = last;
    runtime.state.enemies[last].behavior_slot = enemy.behavior_slot;
    active_rows.pop_back();
    enemy.alive = false;
    speed::EnemySystem::release(runtime.state, uint32_t(found->second));
    if (runtime.state.enemy_handles.reusable(found->second)) runtime.state.free_rows.push_back(found->second);
    runtime.state.rows_by_id.erase(found);
    return true;
}

Array SpeedRunCore::enemies_snapshot() const {
    Array out;
    for (const auto &enemy : runtime.state.enemies) {
        if (!enemy.alive) continue;
        const auto &def = runtime.content->definitions[enemy.definition];
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
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(scale) || scale <= 0 || !std::isfinite(angle_offset)) return buffer;
    int64_t count = 0;
    for (const auto &enemy : runtime.state.enemies) if (enemy.alive && !enemy.dead && runtime.content->definitions[enemy.definition].id == type) ++count;
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    for (const auto &enemy : runtime.state.enemies) {
        if (!enemy.alive || enemy.dead || runtime.content->definitions[enemy.definition].id != type) continue;
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
    if (runtime.state.started || runtime.state.closed) return false;
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
    runtime.state.world_div = int64_t(values[0]); runtime.state.frame_grid_cell = values[1]; runtime.state.trace_radius = values[2]; runtime.state.frame_ready = true;
    return true;
}

bool SpeedRunCore::set_run_guards(const Dictionary &guards) {
    if (!runtime.state.started || runtime.state.closed) return false;
    const Array keys = guards.keys();
    for (int i = 0; i < keys.size(); ++i) {
        const String key = keys[i];
        if (key != "controls_locked" && key != "encounter_protected" && key != "steering_locked" && key != "invincible" && key != "hitstop_enabled") return false;
        if (guards[keys[i]].get_type() != Variant::BOOL) return false;
    }
    runtime.state.controls_locked = guards.get("controls_locked", runtime.state.controls_locked);
    runtime.state.encounter_protected = guards.get("encounter_protected", runtime.state.encounter_protected);
    runtime.state.steering_locked = guards.get("steering_locked", runtime.state.steering_locked);
    runtime.state.invincible = guards.get("invincible", runtime.state.invincible);
    runtime.state.hitstop_enabled = guards.get("hitstop_enabled", runtime.state.hitstop_enabled);
    if (!runtime.state.hitstop_enabled) runtime.state.hitstop = 0;
    return true;
}

bool SpeedRunCore::set_paused(bool paused) {
    if (!runtime.state.started || runtime.state.closed || (runtime.state.phase != Phase::Play && runtime.state.phase != Phase::Paused)) return false;
    runtime.state.phase = paused ? Phase::Paused : Phase::Play;
    if (paused) runtime.state.hitstop = 0;
    return true;
}

bool SpeedRunCore::step_frame(double real_dt, const Dictionary &input, Vector2 center, Vector2 half, double camera_zoom) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.frame_ready || !std::isfinite(real_dt) || real_dt <= 0 ||
            !center.is_finite() || !half.is_finite() || half.x <= 0 || half.y <= 0 || !std::isfinite(camera_zoom) || camera_zoom <= 0) return false;
    for (const char *key : {"touch", "has_cursor", "stick_active", "press", "alt_press", "pen_release"}) if (input.has(key) && input[key].get_type() != Variant::BOOL) return false;
    for (const char *key : {"cursor", "stick", "pen"}) if (input.has(key) && (input[key].get_type() != Variant::VECTOR2 || !Vector2(input[key]).is_finite())) return false;
    if (runtime.state.phase == Phase::Dying) { step_death(real_dt); return true; }
    if (runtime.state.phase != Phase::Play) return true;
    if (runtime.state.controls_locked || runtime.state.encounter_protected) runtime.state.hitstop = 0;
    const Dictionary intent = runtime.state.controls_locked || runtime.state.steering_locked ? Dictionary() : input;
    if (runtime.state.controls_locked) runtime.state.ship.vel = Vector2();
    runtime.state.sim_time += real_dt;
    if (!runtime.state.motion_ready) runtime.state.enemy_aim = runtime.state.ship_pos;
    runtime.state.view_center = center; runtime.state.view_half = half; runtime.state.motion_ready = true;
    handle_draw(intent, int64_t(std::round(runtime.state.sim_time * 1000.0)), camera_zoom);
    if (runtime.state.hitstop > 0) { runtime.state.hitstop = std::max(0.0, runtime.state.hitstop - real_dt); return true; }
    if (!runtime.state.draw.tracing && runtime.state.dash_stop > 0) runtime.state.dash_stop = std::max(0.0, runtime.state.dash_stop - real_dt * runtime.state.combat_config.kill_hitstop_regen);
    step_draw(real_dt);
    if (check_run_end()) return true;
    const double world_dt = real_dt * world_scale();
    runtime.state.time += real_dt; runtime.state.world_time += world_dt;
    runtime.state.world_accum += world_dt; ++runtime.state.world_steps;
    const bool world_step = runtime.state.world_steps >= runtime.state.world_div;
    const double accumulated = runtime.state.world_accum;
    if (world_step) {
        runtime.state.world_accum = 0; runtime.state.world_steps = 0;
        if (runtime.state.attack_budget.frame_enabled) {
            sync_attack_budget();
            if (!advance_attack_budget(runtime.state.world_time)) return false;
        }
        advance_enemies(accumulated);
        avoid_strong(accumulated);
        if (check_run_end()) return true;
        rebuild_enemy_grid(runtime.state.frame_grid_cell);
    }
    step_ship(real_dt, world_dt, intent);
    if (world_dt > 0 && !runtime.state.controls_locked) step_forward(world_dt);
    if (world_step && accumulated > 0) {
        step_projectiles(accumulated);
        step_hostiles(accumulated);
        step_hazards(accumulated);
    }
    if (check_run_end()) return true;
    for (size_t row : runtime.state.dead_rows) if (runtime.state.enemies[row].alive && runtime.state.enemies[row].dead) remove_enemy(runtime.state.enemies[row].id);
    runtime.state.dead_rows.clear();
    if (world_step) {
        if (runtime.state.population.frame_enabled && !runtime.state.population.blocked && !attack_guard_active() && !step_population(accumulated, runtime.state.population.bonus)) return false;
        step_pickups(accumulated);

    }
    if (runtime.state.progression.ready) open_cards(false);
    return true;
}

bool SpeedRunCore::set_attack_formation_mode(bool enabled) {
    if (runtime.state.closed) return false;
    runtime.state.attack_formation_mode = enabled;
    return true;
}

Array SpeedRunCore::enemy_attack_snapshot() const {
    Array out;
    if (runtime.state.closed) return out;
    std::vector<const Enemy *> ordered;
    for (const auto &enemy : runtime.state.enemies) if (enemy.alive) ordered.push_back(&enemy);
    std::sort(ordered.begin(), ordered.end(), [](const auto *a, const auto *b) { return a->id < b->id; });
    for (const auto *enemy : ordered) {
        Dictionary row;
        row["id"] = enemy->id; row["group"] = enemy->attack_group;
        row["value"] = enemy->attack_value; row["priority"] = enemy->attack_priority;
        row["managed"] = enemy->attack_managed; out.append(row);
    }
    return out;
}

PackedInt64Array SpeedRunCore::enemy_handle(int64_t id) const {
    PackedInt64Array out;
    auto found = runtime.state.rows_by_id.find(id);
    if (found == runtime.state.rows_by_id.end()) return out;
    const auto handle = runtime.state.enemy_handles.at(uint32_t(found->second));
    out.push_back(handle.slot); out.push_back(handle.generation);
    return out;
}
bool SpeedRunCore::valid_enemy_handle(PackedInt64Array value) const {
    if (runtime.state.closed || value.size() != 2 || value[0] < 0 || value[0] >= UINT32_MAX || value[1] <= 0 || value[1] > UINT32_MAX) return false;
    return runtime.state.enemy_handles.contains({uint32_t(value[0]), uint32_t(value[1])});
}
