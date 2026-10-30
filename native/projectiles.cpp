#include "run_core.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

size_t SpeedRunCore::add_friend(Friendly shot) {
    ++live_friends;
    if (shot.kind == 1) ++live_debris;
    size_t row;
    if (free_friends.empty()) { row = friends.size(); friends.push_back(std::move(shot)); }
    else { row = free_friends.back(); free_friends.pop_back(); friends[row] = std::move(shot); }
    return row;
}

bool SpeedRunCore::fire_shot(Vector2 from, double angle, double damage, const Dictionary &options) {
    if (!started || closed || !combat_ready || !from.is_finite() || !std::isfinite(angle) || !std::isfinite(damage) || damage < 0) return false;
    const Array keys = options.keys();
    for (int i = 0; i < keys.size(); ++i) {
        const String key = keys[i];
        if (key != "speed" && key != "r" && key != "life" && key != "pierce_left" && key != "knock" && key != "color" && key != "cause" && key != "weapon_id" && key != "visual_key") return false;
    }
    double speed = 1300, radius = 5, life = 0.9, knock = 250;
    const char *names[] = {"speed", "r", "life", "knock"};
    double *values[] = {&speed, &radius, &life, &knock};
    for (int i = 0; i < 4; ++i) if (options.has(names[i])) {
        const Variant v = options[names[i]];
        if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) return false;
        *values[i] = double(v);
        if (!std::isfinite(float(*values[i])) || *values[i] < 0) return false;
    }
    Friendly shot;
    if (options.has("pierce_left")) {
        const Variant v = options["pierce_left"];
        if (v.get_type() != Variant::INT || int64_t(v) < 0 || int64_t(v) > INT32_MAX) return false;
        shot.pierce_left = int64_t(v);
    }
    for (const char *key : {"cause", "weapon_id", "visual_key"}) if (options.has(key)) {
        const Variant::Type type = options[key].get_type();
        if (type != Variant::STRING && type != Variant::STRING_NAME) return false;
    }
    if (options.has("color") && options["color"].get_type() != Variant::COLOR) return false;
    shot.pos = from; shot.vel = Vector2::from_angle(angle) * speed;
    shot.radius = radius; shot.damage = damage; shot.life = life; shot.knock = knock;
    shot.color = options.get("color", Color::html("ffe46b"));
    for (float channel : {shot.color.r, shot.color.g, shot.color.b, shot.color.a}) if (!std::isfinite(channel)) return false;
    shot.cause = options.get("cause", StringName("shot"));
    if (shot.cause != StringName("shot")) return false;
    shot.weapon_id = options.get("weapon_id", StringName());
    shot.visual = options.get("visual_key", StringName());
    add_friend(std::move(shot));
    return true;
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

bool SpeedRunCore::step_projectiles(double world_dt) {
    if (!started || closed || !combat_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    struct Hit { double time; size_t row; };
    struct Earlier { bool operator()(const Hit &a, const Hit &b) const { return a.time < b.time; } };
    std::vector<Hit> hits;
    // 命中で末尾へ増えた弾は同じ更新で進め、既に通った空き行は次回に進める。
    for (size_t i = 0; i < friends.size(); ++i) {
        auto &shot = friends[i];
        if (!shot.alive) continue;
        const Vector2 from = shot.pos, vel = shot.vel, to = from + vel * world_dt;
        Vector2 position = to;
        double life = double(shot.life) - world_dt;
        shot.age = double(shot.age) + world_dt;
        shot.angle = double(shot.angle) + double(shot.spin) * world_dt;
        if (shot.kind == 1 && shot.visual != StringName("weapon/knockback")) {
            shot.trail.append(to);
            if (shot.trail.size() > projectile_config.trail_points) shot.trail.remove_at(0);
        }
        const double padding = double(shot.radius) + std::max(combat_config.max_enemy_radius, grid.max_radius);
        const Vector2 pad(padding, padding);
        hits.clear();
        for (size_t row : query_enemy_rows(from.min(to) - pad, from.max(to) + pad)) {
            const auto &enemy = enemies[row];
            if (shot.hit_ids.count(enemy.id)) continue;
            const double t = segment_circle(from, to, enemy.pos, double(shot.radius) + definitions[enemy.definition].radius);
            if (t >= 0) hits.push_back({t, row});
        }
        SortArray<Hit, Earlier>().sort(hits.data(), hits.size());
        const double speed = vel.length();
        for (const auto &hit : hits) {
            const auto &enemy = enemies[hit.row];
            if (life <= 0 || enemy.dead || shot.hit_ids.count(enemy.id)) continue;
            const Vector2 impact = from.lerp(to, hit.time);
            if (shot.kind == 0 && blocks_front(hit.row, impact, vel)) {
                auto &target = enemies[hit.row];
                if (target.fire_t <= 0) {
                    const auto &def = definitions[target.definition];
                    Vector2 normal = (impact - target.pos).normalized();
                    if (normal.is_zero_approx()) normal = Vector2::from_angle(target.facing);
                    const Vector2 direction = (vel - normal * 2.0 * vel.dot(normal)).normalized();
                    Hostile reflected;
                    reflected.kind = 2; reflected.pos = impact + normal * 2.0;
                    reflected.vel = direction * def.reflect_speed; reflected.speed = def.reflect_speed;
                    reflected.radius = std::clamp(double(shot.radius), 5.0, 10.0);
                    reflected.life = def.reflect_life; reflected.damage = def.reflect_damage;
                    add_hostile(std::move(reflected));
                    target.fire_t = std::max(0.01, def.reflect_interval); target.flash = 0.1;
                    Dictionary reflected_event; reflected_event["pos"] = impact; reflected_event["normal"] = normal;
                    emit_event("shield_reflect", reflected_event);
                }
                position = impact; life = 0; break;
            }
            shot.hit_ids.insert(enemy.id);
            damage_enemy(hit.row, shot.damage, shot.cause, false, speed > 0 ? vel / speed : Vector2(), shot.knock, &impact);
            duplicate_friend(i, impact);
            Dictionary event; event["pos"] = impact; event["dir"] = vel.normalized();
            event["visual_key"] = String(shot.visual); event["kind"] = shot.kind;
            emit_event("shot_hit", event);
            if (!shot.pierce) { if (shot.pierce_left > 0) --shot.pierce_left; else life = 0; }
        }
        shot.pos = position; shot.life = life;
        if (life <= 0) {
            if (shot.kind == 1) {
                --live_debris;
                if (shot.visual != StringName("weapon/knockback") && shot.trail.size() > 1) {
                    Dictionary ended; ended["points"] = shot.trail; ended["color"] = shot.color;
                    emit_event("debris_trail", ended);
                }
            }
            shot.alive = false; --live_friends; free_friends.push_back(i);
        }
    }
    return true;
}

Array SpeedRunCore::projectiles_snapshot() const {
    Array out;
    for (size_t row = 0; row < friends.size(); ++row) {
        const auto &shot = friends[row];
        if (!shot.alive) continue;
        std::vector<int64_t> sorted(shot.hit_ids.begin(), shot.hit_ids.end());
        std::sort(sorted.begin(), sorted.end());
        Array ids; for (int64_t id : sorted) ids.append(id);
        Dictionary item;
        item["row"] = int64_t(row); item["kind"] = shot.kind; item["generation"] = shot.generation; item["pos"] = shot.pos; item["vel"] = shot.vel;
        item["radius"] = shot.radius; item["damage"] = shot.damage; item["life"] = shot.life; item["age"] = shot.age;
        item["pierce_left"] = shot.pierce_left; item["hit_ids"] = ids; item["angle"] = shot.angle; item["trail"] = shot.trail;
        out.append(item);
    }
    return out;
}
