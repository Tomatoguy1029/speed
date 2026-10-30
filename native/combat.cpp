#include "run_core.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_combat(const Dictionary &config, const Dictionary &stats) {
    if (started || closed) return false;
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
    combat_config = c; combat_ready = true;
    return true;
}

void SpeedRunCore::emit_event(StringName type, Dictionary data) { data["type"] = type; events.append(data); }
Array SpeedRunCore::drain_events() { Array out = events; events = Array(); return out; }
Dictionary SpeedRunCore::combat_snapshot() const {
    Dictionary out; out["hitstop"] = hitstop; out["dash_stop"] = dash_stop; out["kills"] = kills; return out;
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

void SpeedRunCore::damage_enemy(size_t row, double amount, StringName cause, bool crit, Vector2 direction, double knock) {
    auto &enemy = enemies[row];
    if (enemy.dead || amount <= 0) return;
    const auto &def = definitions[enemy.definition];
    bool fresh = enemy.hp >= def.hp - 1e-6;
    if (draw.tracing) {
        if (enemy.dash_seen != draw.dash_id) { enemy.dash_seen = draw.dash_id; enemy.dash_fresh = fresh; }
        fresh = enemy.dash_fresh;
    }
    const double before = enemy.hp;
    enemy.hp -= amount;
    if (cause == StringName("ram") && before > std::max(0.0, enemy.hp)) {
        double seconds = 0;
        if (fresh && enemy.hp <= 0) seconds = combat_config.kill_hitstop * (def.radius > 25 ? combat_config.hitstop_big_mult : 1.0) * (crit ? combat_config.hitstop_crit_mult : 1.0);
        if (crit) seconds = std::max(seconds, enemy.hp <= 0 ? 0.05 : 0.035);
        if (def.hitstop_multiplier > 0) {
            const double stop = std::min(seconds * def.hitstop_multiplier, std::max(0.0, combat_config.kill_hitstop_cap - dash_stop));
            hitstop = std::max(hitstop, stop); dash_stop += stop;
        }
    }
    enemy.flash = 0.12;
    Dictionary hit;
    hit["pos"] = enemy.pos; hit["crit"] = crit; hit["dmg"] = amount; hit["cause"] = cause; hit["id"] = enemy.id;
    emit_event("hit", hit);
    if (crit) {
        Dictionary text;
        text["pos"] = enemy.pos + Vector2(0, -def.radius - 10.0); text["text"] = "CRIT";
        text["color"] = Color::html("ffe46b"); text["size"] = 16;
        emit_event("text", text);
    }
    if (enemy.hp <= 0) {
        enemy.dead = true; dead_rows.push_back(row); ++kills;
        Dictionary killed;
        killed["pos"] = enemy.pos; killed["r"] = def.radius; killed["crit"] = crit;
        killed["id"] = enemy.id; killed["t"] = time; killed["world_t"] = world_time;
        killed["enemy_type"] = def.id; killed["meteor_index"] = -1; killed["facing"] = enemy.facing;
        killed["elite"] = false; killed["cause"] = cause; killed["dir"] = direction; killed["color"] = def.color;
        emit_event("kill", killed);
        drop_enemy_pickups(enemy);
    } else if (def.knockback > 0) {
        const double mass = std::max(1.0, def.radius / 20.0);
        enemy.vel += direction * knock * def.knockback / mass;
    }
}

bool SpeedRunCore::collide_ship(Vector2 from, double radius) {
    if (!started || closed || !ship_ready || !combat_ready || !from.is_finite() || !std::isfinite(radius) || radius < 0) return false;
    const auto &c = combat_config;
    const Vector2 to = ship.pos;
    const double padding = radius + std::max(c.max_enemy_radius, grid.max_radius);
    const Vector2 pad(padding, padding);
    struct Hit { double time; size_t row; };
    struct Earlier { bool operator()(const Hit &a, const Hit &b) const { return a.time < b.time; } };
    std::vector<Hit> hits;
    for (size_t row : query_enemy_rows(from.min(to) - pad, from.max(to) + pad)) {
        const auto &enemy = enemies[row];
        if (draw.tracing ? draw.inside.count(enemy.id) > 0 : enemy.hit_cd > 0) continue;
        const double t = segment_circle(from, to, enemy.pos, definitions[enemy.definition].radius + radius);
        if (t >= 0) hits.push_back({t, row});
    }
    SortArray<Hit, Earlier>().sort(hits.data(), hits.size());
    for (const auto &hit : hits) {
        auto &enemy = enemies[hit.row];
        if (enemy.dead || (draw.tracing ? draw.inside.count(enemy.id) > 0 : enemy.hit_cd > 0)) continue;
        const auto &def = definitions[enemy.definition];
        const Vector2 position = from.lerp(to, hit.time);
        const double speed = ship.vel.length();
        const Vector2 direction = speed > 0 ? ship.vel / speed : Vector2();
        const double attack = c.base_attack * c.attack_mult * c.atk_scale;
        const bool fast = draw.tracing || ship.glide || speed >= ship_config.max_speed * c.ram_speed_ratio;
        const bool crit = rng->randf() < c.crit_chance;
        if (!fast) {
            enemy.hit_cd = c.contact_cooldown;
            damage_enemy(hit.row, attack * c.touch_damage, "touch", false, direction);
            continue;
        }
        if (attack >= def.armor * (crit ? c.crit_armor : 1.0)) {
            damage_enemy(hit.row, attack * (crit ? c.crit_mult : 1.0), "ram", crit, direction);
            if (crit) {
                Dictionary impact; impact["pos"] = position; impact["enemy_pos"] = enemy.pos; impact["r"] = def.radius;
                emit_event("weak_impact", impact);
            }
            enemy.hit_cd = c.contact_cooldown;
            if (draw.tracing) {
                draw.inside[enemy.id] = hit.row;
                const int64_t passes = ++draw.passes[enemy.id];
                if (passes > 1) {
                    Dictionary text; text["pos"] = enemy.pos + Vector2(def.radius, -def.radius - 16.0);
                    text["text"] = String::utf8("×") + String::num_int64(passes);
                    text["color"] = crit ? Color::html("ffe46b") : Color(1, 1, 1, 1);
                    text["size"] = 22 + 4 * std::min(int64_t(5), passes); emit_event("text", text);
                }
            }
            if (!ship.glide && !draw.tracing) {
                const double loss = enemy.dead ? (0.004 + def.radius * 0.0006) : (0.1 + def.radius * 0.002);
                ship.vel *= 1.0 - std::min(0.6, loss);
            }
            continue;
        }
        ship.glide = false;
        Vector2 normal = position - enemy.pos;
        normal = normal.length_squared() > 0 ? normal.normalized() : -direction;
        Dictionary impact; impact["pos"] = position; impact["normal"] = normal; impact["enemy_pos"] = enemy.pos; impact["r"] = def.radius;
        emit_event("block_impact", impact);
        ship.pos = enemy.pos + normal * (def.radius + ship_config.ship_radius + 1.0);
        const double vn = ship.vel.dot(normal);
        if (vn < 0) ship.vel -= normal * 2.0 * vn;
        ship.vel *= c.bounce_keep;
        if (ship.vel.length() < c.bounce_min_speed) ship.vel = normal * c.bounce_min_speed;
        ship.boost_t = 0;
        damage_enemy(hit.row, attack * 0.25, "bump", crit, -normal);
        enemy.hit_cd = 0.25;
        Dictionary bounce; bounce["pos"] = ship.pos; emit_event("bounce", bounce);
        ship_pos = ship.pos;
        return true;
    }
    ship_pos = ship.pos;
    return false;
}
