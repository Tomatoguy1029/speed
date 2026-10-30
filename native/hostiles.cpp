#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

size_t SpeedRunCore::add_hostile(Hostile shot) {
    size_t row;
    if (free_hostiles.empty()) { row = hostiles.size(); hostiles.push_back(std::move(shot)); }
    else { row = free_hostiles.back(); free_hostiles.pop_back(); hostiles[row] = std::move(shot); }
    return row;
}

int64_t SpeedRunCore::spawn_hostile(const Dictionary &fields) {
    if (!started || closed || !ship_ready || !fields.has("kind") || fields["kind"].get_type() != Variant::INT) return -1;
    const Array keys_in = fields.keys();
    for (int i = 0; i < keys_in.size(); ++i) {
        const String key = keys_in[i];
        if (key != "kind" && key != "pos" && key != "vel" && key != "speed" && key != "r" && key != "life" && key != "dmg" && key != "slow" && key != "turn" && key != "stone" && key != "wait") return -1;
    }
    Hostile shot;
    shot.kind = fields["kind"];
    if (shot.kind < 0 || shot.kind > 2) return -1;
    for (const char *key : {"pos", "vel"}) if (!fields.has(key) || fields[key].get_type() != Variant::VECTOR2 || !Vector2(fields[key]).is_finite()) return -1;
    shot.pos = fields["pos"]; shot.vel = fields["vel"];
    const char *keys[] = {"speed", "r", "life", "slow", "turn", "stone", "wait"};
    float *values[] = {&shot.speed, &shot.radius, &shot.life, &shot.slow, &shot.turn, &shot.stone, &shot.wait};
    for (int i = 0; i < 7; ++i) {
        if (!fields.has(keys[i])) { if (i >= 5) continue; return -1; }
        const Variant value = fields[keys[i]];
        if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return -1;
        *values[i] = double(value);
        if (!std::isfinite(*values[i]) || *values[i] < 0) return -1;
    }
    if (!fields.has("dmg") || (fields["dmg"].get_type() != Variant::FLOAT && fields["dmg"].get_type() != Variant::INT)) return -1;
    shot.damage = fields["dmg"];
    if (!std::isfinite(shot.damage) || shot.damage < 0) return -1;
    return add_hostile(std::move(shot));
}

bool SpeedRunCore::damage_ship(double amount, double slow, StringName cause, StringName source) {
    if (phase != Phase::Play || controls_locked || encounter_protected) return false;
    if (ship.shield_t > 0) {
        if (ship.shield_flash <= 0) { Dictionary event; event["pos"] = ship.pos; emit_event("shield_block", event); }
        ship.shield_flash = 0.12;
        return false;
    }
    if (ship.invuln > 0 || invincible) return false;
    ship.hp -= amount;
    if (slow > 0) ship.glide = false;
    ship.vel *= 1.0 - std::min(0.9, slow);
    ship.invuln = ship_config.invulnerability;
    ship.hurt = ship_config.ship_hurt_time;
    Dictionary hit; hit["pos"] = ship.pos; hit["amount"] = amount; hit["cause"] = cause; hit["source"] = source;
    hit["t"] = time; hit["world_t"] = world_time; hit["hp_after"] = ship.hp; emit_event("hurt", hit);
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

bool SpeedRunCore::step_hostiles(double world_dt) {
    if (!started || closed || !ship_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    const Vector2 keep = view_half + Vector2(400, 400);
    for (size_t row = 0; row < hostiles.size(); ++row) {
        auto &shot = hostiles[row];
        if (!shot.alive) continue;
        const auto release = [&]() { shot.alive = false; free_hostiles.push_back(row); };
        double life = shot.life;
        if (life <= 0) { release(); continue; }
        const Vector2 from = shot.pos;
        if (shot.stone > 0) {
            shot.stone = double(shot.stone) - world_dt;
            const double reach = double(shot.radius) + ship_config.ship_radius;
            if (ship.pos.distance_squared_to(from) <= reach * reach) release();
            continue;
        }
        Vector2 vel = shot.vel;
        if (shot.wait > 0) { shot.wait = double(shot.wait) - world_dt; vel = Vector2(); }
        if (shot.kind == 1) {
            const double turn = double(shot.turn) * world_dt, current = vel.angle();
            const double difference = double(((aim_ready ? enemy_aim : ship_pos) - shot.pos).angle()) - current;
            const double wrapped = difference - (2.0 * Math_PI) * std::floor((difference + Math_PI) / (2.0 * Math_PI));
            const Vector2 steered = Vector2::from_angle(current + std::clamp(wrapped, -turn, turn)) * shot.speed;
            if (steered != vel) { vel = steered; shot.vel = vel; }
        }
        Vector2 to = from + vel * world_dt;
        life -= world_dt;
        const Vector2 relative = to - view_center;
        if (shot.kind != 1 && (std::abs(relative.x) > keep.x || std::abs(relative.y) > keep.y) && relative.dot(vel) > 0) life = 0;
        const double step = double(shot.speed) * world_dt;
        const double reach = double(shot.radius) + ship_config.ship_radius + step;
        if (ship.pos.distance_squared_to(to) <= reach * reach) {
            const double t = segment_circle(from, to, ship.pos, double(shot.radius) + ship_config.ship_radius);
            if (t >= 0) {
                static const StringName causes[] = {"bullet", "missile", "reflected"};
                damage_ship(shot.damage, shot.slow, causes[shot.kind]);
                life = 0; to = from + (to - from) * t;
            }
        }
        if (life <= 0) release();
        else {
            shot.pos = to; shot.life = life;
            // 地形を接続する前の代表経路には障害物がない。
            shot.gap = std::numeric_limits<float>::infinity();
        }
    }
    return true;
}

Array SpeedRunCore::hostiles_snapshot() const {
    Array out;
    for (size_t row = 0; row < hostiles.size(); ++row) {
        const auto &shot = hostiles[row];
        if (!shot.alive) continue;
        Dictionary item;
        item["row"] = int64_t(row); item["kind"] = shot.kind; item["pos"] = shot.pos; item["vel"] = shot.vel;
        item["life"] = shot.life; item["gap"] = shot.gap; item["stone"] = shot.stone; item["wait"] = shot.wait;
        out.append(item);
    }
    return out;
}
