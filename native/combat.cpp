#include "run_core.h"
#include "geometry.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/math.hpp>
using namespace godot;

bool SpeedRunCore::configure_combat(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
    CombatConfig c{};
    const char *keys[] = {"base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius", "attack_mult", "crit_chance", "crit_mult"};
    double *fields[] = {&c.base_attack, &c.atk_scale, &c.ram_speed_ratio, &c.crit_armor, &c.touch_damage, &c.contact_cooldown, &c.bounce_keep, &c.bounce_min_speed, &c.kill_hitstop, &c.kill_hitstop_cap, &c.kill_hitstop_regen, &c.hitstop_big_mult, &c.hitstop_crit_mult, &c.max_enemy_radius, &c.attack_mult, &c.crit_chance, &c.crit_mult};
    for (int i = 0; i < 17; ++i) {
        const Dictionary &source = i < 14 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *fields[i] = double(value);
        if (!std::isfinite(*fields[i]) || *fields[i] < 0) return false;
    }
    runtime.state.combat_config = c; runtime.state.combat_ready = true;
    return true;
}

void SpeedRunCore::emit_event(StringName type, Dictionary data) { data["type"] = type; runtime.state.events.append(data); }
Array SpeedRunCore::drain_events() { Array out = runtime.state.events; runtime.state.events = Array(); return out; }
Dictionary SpeedRunCore::combat_snapshot() const {
    Dictionary out; out["hitstop"] = runtime.state.hitstop; out["dash_stop"] = runtime.state.dash_stop; out["kills"] = runtime.state.kills; return out;
}

static double segment_circle(Vector2 from, Vector2 to, Vector2 center, double radius) {
    const Vector2 f = from - center;
    const double cc = double(f.length_squared()) - radius * radius;
    if (cc <= 0) return 0;
    const Vector2 d = to - from;
    const double a = d.length_squared();
    if (a == 0) return -1;
    const double b = 2.0 * f.dot(d), disc = b * b - 4.0 * a * cc;
    if (disc < 0) return -1;
    const double t = (-b - std::sqrt(disc)) / (2.0 * a);
    return t >= 0 && t <= 1 ? t : -1;
}

static double angle_difference(double target, double current) {
    const double difference = target - current;
    return speed::angle_difference(difference);
}

bool SpeedRunCore::blocks_front(size_t row, Vector2 hit, Vector2 direction) const {
    const auto &enemy = runtime.state.enemies[row];
    const auto &def = runtime.content->definitions[enemy.definition];
    if (def.kind != speed::EnemyDefinition::Kind::Shield || enemy.stone > 0) return false;
    Vector2 toward = hit - enemy.pos;
    if (toward.length_squared() < 0.01) toward = -direction;
    return toward.length_squared() > 0 && std::abs(angle_difference(toward.angle(), enemy.facing)) <= def.front_arc;
}

void SpeedRunCore::damage_enemy(size_t row, double amount, StringName cause, bool crit, Vector2 direction, double knock, const Vector2 *impact) {
    auto &enemy = runtime.state.enemies[row];
    if (enemy.dead || amount <= 0 || runtime.state.phase != Phase::Play || runtime.state.controls_locked || runtime.state.encounter_protected) return;
    const auto &def = runtime.content->definitions[enemy.definition];
    if (cause != StringName("ram") && cause != StringName("bump") && blocks_front(row, impact ? *impact : enemy.pos, direction)) return;
    bool fresh = enemy.hp >= enemy.max_hp - 1e-6;
    if (runtime.state.draw.tracing) {
        if (enemy.dash_seen != runtime.state.draw.dash_id) { enemy.dash_seen = runtime.state.draw.dash_id; enemy.dash_fresh = fresh; }
        fresh = enemy.dash_fresh;
    }
    const double before = enemy.hp;
    enemy.hp -= amount;
    if (runtime.state.hitstop_enabled && cause == StringName("ram") && before > std::max(0.0, enemy.hp)) {
        double seconds = 0;
        if (fresh && enemy.hp <= 0) seconds = runtime.state.combat_config.kill_hitstop * (enemy.radius > 25 ? runtime.state.combat_config.hitstop_big_mult : 1.0) * (crit ? runtime.state.combat_config.hitstop_crit_mult : 1.0);
        if (crit) seconds = std::max(seconds, enemy.hp <= 0 ? 0.05 : 0.035);
        if (def.hitstop_multiplier > 0) {
            const double stop = std::min(seconds * def.hitstop_multiplier, std::max(0.0, runtime.state.combat_config.kill_hitstop_cap - runtime.state.dash_stop));
            runtime.state.hitstop = std::max(runtime.state.hitstop, stop); runtime.state.dash_stop += stop;
        }
    }
    enemy.flash = 0.12;
    Dictionary hit;
    hit["pos"] = enemy.pos; hit["crit"] = crit; hit["dmg"] = amount; hit["cause"] = cause; hit["id"] = enemy.id;
    emit_event("hit", hit);
    if (crit) {
        Dictionary text;
        text["pos"] = enemy.pos + Vector2(0, -enemy.radius - 10.0); text["text"] = "CRIT";
        text["color"] = Color::html("ffe46b"); text["size"] = 16;
        emit_event("text", text);
    }
    if (enemy.hp <= 0) {
        kill_enemy(row, crit, cause, direction);
    } else if (def.knockback > 0) {
        const double mass = std::max(1.0, enemy.radius / 20.0);
        enemy.vel += direction * knock * def.knockback / mass;
    }
}

void SpeedRunCore::kill_enemy(size_t row, bool crit, StringName cause, Vector2 direction) {
    auto &enemy = runtime.state.enemies[row];
    if (enemy.dead || runtime.state.phase != Phase::Play) return;
    const auto &def = runtime.content->definitions[enemy.definition];
    enemy.dead = true; runtime.state.dead_rows.push_back(row); ++runtime.state.kills;
    remove_hound(row);
    Dictionary killed;
    killed["pos"] = enemy.pos; killed["r"] = enemy.radius; killed["crit"] = crit;
    killed["id"] = enemy.id; killed["t"] = runtime.state.time; killed["world_t"] = runtime.state.world_time;
    killed["enemy_type"] = def.id; killed["meteor_index"] = -1; killed["facing"] = enemy.facing;
    killed["elite"] = enemy.elite; killed["cause"] = cause; killed["dir"] = direction; killed["color"] = def.color;
    emit_event("kill", killed);
    passive_attack(String::num_int64(enemy.id), enemy.id);
    drop_enemy_pickups(enemy);
}

bool SpeedRunCore::collide_ship(Vector2 from, double radius) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.combat_ready || !from.is_finite() || !std::isfinite(radius) || radius < 0) return false;
    const auto &c = runtime.state.combat_config;
    const Vector2 to = runtime.state.ship.pos;
    const double padding = radius + std::max(c.max_enemy_radius, runtime.state.grid.max_radius);
    const Vector2 pad(padding, padding);
    struct Hit { double time; size_t row; };
    struct Earlier { bool operator()(const Hit &a, const Hit &b) const { return a.time < b.time; } };
    std::vector<Hit> hits;
    for (size_t row : query_enemy_rows(from.min(to) - pad, from.max(to) + pad)) {
        const auto &enemy = runtime.state.enemies[row];
        if (runtime.state.draw.tracing ? runtime.state.draw.inside.count(enemy.id) > 0 : (enemy.hit_cd > 0 && runtime.content->definitions[enemy.definition].kind != speed::EnemyDefinition::Kind::Shield)) continue;
        const double t = segment_circle(from, to, enemy.pos, enemy.radius + radius);
        if (t >= 0) hits.push_back({t, row});
    }
    SortArray<Hit, Earlier>().sort(hits.data(), hits.size());
    for (const auto &hit : hits) {
        auto &enemy = runtime.state.enemies[hit.row];
        if (enemy.dead || (runtime.state.draw.tracing && runtime.state.draw.inside.count(enemy.id) > 0)) continue;
        const auto &def = runtime.content->definitions[enemy.definition];
        const Vector2 position = from.lerp(to, hit.time);
        const double speed = runtime.state.ship.vel.length();
        const Vector2 direction = speed > 0 ? runtime.state.ship.vel / speed : Vector2();
        const double attack = c.base_attack * c.attack_mult * c.atk_scale;
        const bool fast = runtime.state.draw.tracing || runtime.state.ship.glide || speed >= runtime.state.ship_config.max_speed * c.ram_speed_ratio;
        const bool front = blocks_front(hit.row, position, direction);
        if (front && (!fast || (!runtime.state.draw.tracing && enemy.hit_cd > 0))) {
            Vector2 normal = position - enemy.pos;
            normal = normal.length_squared() > 0 ? normal.normalized() : -direction;
            runtime.state.ship.pos = enemy.pos + normal * (enemy.radius + radius + 1.0);
            const double vn = runtime.state.ship.vel.dot(normal);
            if (vn < 0) { runtime.state.ship.vel -= normal * 2.0 * vn; runtime.state.ship.vel *= c.bounce_keep; }
            if (enemy.hit_cd <= 0) {
                enemy.hit_cd = 0.25;
                Dictionary event; event["pos"] = position; event["normal"] = normal; event["enemy_pos"] = enemy.pos; event["r"] = enemy.radius;
                emit_event("block_impact", event);
            }
            runtime.state.ship_pos = runtime.state.ship.pos;
            return true;
        }
        if (!runtime.state.draw.tracing && enemy.hit_cd > 0) continue;
        const bool rear = std::abs(angle_difference((position - enemy.pos).angle(), enemy.facing + godot::Math::PI)) <= def.weak_arc;
        const bool crit = (def.weak_arc > 0 && rear) || runtime.state.rng->randf() < c.crit_chance;
        if (enemy.stone > 0) {
            enemy.hit_cd = c.contact_cooldown;
            if (runtime.state.draw.tracing) runtime.state.draw.inside[enemy.id] = hit.row;
            Dictionary event; event["pos"] = enemy.pos; event["normal"] = -direction;
            event["enemy_pos"] = enemy.pos; event["r"] = enemy.radius; emit_event("block_impact", event);
            kill_enemy(hit.row, false, fast ? StringName("ram") : StringName("touch"), direction);
            continue;
        }
        if (!fast) {
            enemy.hit_cd = c.contact_cooldown;
            damage_enemy(hit.row, attack * c.touch_damage, "touch", false, direction, 160.0, &position);
            continue;
        }
        if (!front && attack >= enemy.armor * (crit ? c.crit_armor : 1.0)) {
            double damage = attack * (crit ? c.crit_mult : 1.0);
            if (def.kind == speed::EnemyDefinition::Kind::Shield && rear) {
                runtime.state.ship.shield_t = def.shield_time; runtime.state.ship.shield_max = def.shield_time; runtime.state.ship.shield_flash = 0.2;
                Dictionary stolen; stolen["pos"] = enemy.pos; stolen["facing"] = enemy.facing; stolen["r"] = enemy.radius; stolen["arc"] = def.front_arc;
                emit_event("shield_stolen", stolen);
                damage = std::max(damage, enemy.hp);
            }
            damage_enemy(hit.row, damage, "ram", crit, direction);
            if (crit) {
                Dictionary impact; impact["pos"] = position; impact["enemy_pos"] = enemy.pos; impact["r"] = enemy.radius;
                emit_event("weak_impact", impact);
            }
            enemy.hit_cd = c.contact_cooldown;
            if (runtime.state.draw.tracing) {
                runtime.state.draw.inside[enemy.id] = hit.row;
                const int64_t passes = ++runtime.state.draw.passes[enemy.id];
                if (passes > 1) {
                    Dictionary text; text["pos"] = enemy.pos + Vector2(enemy.radius, -enemy.radius - 16.0);
                    text["text"] = String::utf8("×") + String::num_int64(passes);
                    text["color"] = crit ? Color::html("ffe46b") : Color(1, 1, 1, 1);
                    text["size"] = 22 + 4 * std::min(int64_t(5), passes); emit_event("text", text);
                }
            }
            if (!runtime.state.ship.glide && !runtime.state.draw.tracing) {
                const double loss = enemy.dead ? (0.004 + enemy.radius * 0.0006) : (0.1 + enemy.radius * 0.002);
                runtime.state.ship.vel *= 1.0 - std::min(0.6, loss);
            }
            continue;
        }
        runtime.state.ship.glide = false;
        Vector2 normal = position - enemy.pos;
        normal = normal.length_squared() > 0 ? normal.normalized() : -direction;
        Dictionary impact; impact["pos"] = position; impact["normal"] = normal; impact["enemy_pos"] = enemy.pos; impact["r"] = enemy.radius;
        emit_event("block_impact", impact);
        runtime.state.ship.pos = enemy.pos + normal * (enemy.radius + runtime.state.ship_config.ship_radius + 1.0);
        const double vn = runtime.state.ship.vel.dot(normal);
        if (vn < 0) runtime.state.ship.vel -= normal * 2.0 * vn;
        runtime.state.ship.vel *= c.bounce_keep;
        if (runtime.state.ship.vel.length() < c.bounce_min_speed) runtime.state.ship.vel = normal * c.bounce_min_speed;
        runtime.state.ship.boost_t = 0;
        if (!front) damage_enemy(hit.row, attack * 0.25, "bump", crit, -normal);
        enemy.hit_cd = 0.25;
        Dictionary bounce; bounce["pos"] = runtime.state.ship.pos; emit_event("bounce", bounce);
        runtime.state.ship_pos = runtime.state.ship.pos;
        return true;
    }
    runtime.state.ship_pos = runtime.state.ship.pos;
    return false;
}
