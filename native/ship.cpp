#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>

using namespace godot;

bool SpeedRunCore::configure_ship(const Dictionary &config, const Dictionary &stats) {
    if (started || closed) return false;
    ShipConfig c{};
    const char *keys[] = {"start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time", "max_hp", "max_speed", "turn_rate", "acceleration", "glide_duration_mult", "invulnerability"};
    double *fields[] = {&c.start_radius, &c.base_max_speed, &c.stick_dead_zone, &c.mouse_dead_zone, &c.steer_cruise, &c.glide_hold, &c.glide_fade, &c.cruise_floor, &c.energy_cut, &c.cruise_drag, &c.overcap_decay, &c.field_radius, &c.boundary_push, &c.ship_radius, &c.crash_restitution, &c.ship_hurt_time, &c.max_hp, &c.max_speed, &c.turn_rate, &c.acceleration, &c.glide_duration_mult, &c.invulnerability};
    for (int i = 0; i < 22; ++i) {
        const Dictionary &source = i < 16 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *fields[i] = double(value);
        if (!std::isfinite(*fields[i]) || *fields[i] < 0) return false;
    }
    if (c.base_max_speed <= 0 || c.max_speed <= 0 || c.max_hp <= 0 || c.field_radius <= 0) return false;
    ship_config = c;
    ship = Ship();
    ship.pos = Vector2(-c.start_radius, 0);
    ship.vel = Vector2(0, -c.base_max_speed * 0.3);
    ship.hp = c.max_hp;
    ship_pos = ship.pos;
    ship_ready = true;
    return true;
}

void SpeedRunCore::steer_ship(double want, double dt) {
    const auto &c = ship_config;
    const double sp = ship.vel.length();
    if (sp > 1) {
        const double difference = want - double(ship.vel.angle());
        const double wrapped = difference - (2.0 * Math_PI) * std::floor((difference + Math_PI) / (2.0 * Math_PI));
        const double turn = std::clamp(wrapped, -c.turn_rate * dt, c.turn_rate * dt);
        ship.vel = ship.vel.rotated(turn);
    }
    const double cruise = c.max_speed * c.steer_cruise;
    if (sp < cruise) ship.vel += Vector2::from_angle(want) * std::min(c.acceleration * dt, cruise - sp);
    if (ship.vel.is_zero_approx()) ship.heading = Vector2::from_angle(want);
}

void SpeedRunCore::move_ship(double dt, Vector2 accel) {
    const auto &c = ship_config;
    if (ship.glide) {
        ship.glide_t += dt;
        const double cruise = c.max_speed * c.steer_cruise;
        double sp = ship.glide_speed;
        const double hold = c.glide_hold * c.glide_duration_mult;
        const double fade = c.glide_fade * c.glide_duration_mult;
        if (ship.glide_t > hold) {
            const double k = (ship.glide_t - hold) / std::max(0.001, fade);
            if (k >= 1) { ship.glide = false; sp = cruise; }
            else sp = Math::lerp(ship.glide_speed, cruise, k);
        }
        if (!ship.vel.is_zero_approx()) ship.vel = ship.vel.normalized() * sp;
        ship.boost_t = std::max(0.0, ship.boost_t - dt);
        ship.fade_t = 0;
        ship.pos += ship.vel * dt;
        return;
    }
    ship.vel += accel * dt;
    const double sp = ship.vel.length();
    if (sp > 0) {
        double target = sp;
        if (ship.boost_t > 0) {
            ship.boost_t -= dt;
            if (ship.boost_t <= 0) ship.fade_t = 0.3;
        } else {
            if (ship.fade_t > 0) {
                ship.fade_t -= dt;
                if (target > c.max_speed * c.cruise_floor) target *= std::pow(c.energy_cut, dt / 0.3);
            }
            const double floor = c.max_speed * c.cruise_floor;
            if (target > floor) target = floor + (target - floor) * std::exp(-c.cruise_drag * dt);
        }
        if (target > c.max_speed) target = c.max_speed + (target - c.max_speed) * std::exp(-c.overcap_decay * dt);
        ship.vel *= target / sp;
    }
    ship.pos += ship.vel * dt;
    if (!ship.vel.is_zero_approx()) ship.heading = ship.vel.normalized();
}

bool SpeedRunCore::step_ship(double real_dt, double world_dt, const Dictionary &input) {
    if (!started || closed || !ship_ready || !std::isfinite(real_dt) || !std::isfinite(world_dt) || real_dt < 0 || world_dt < 0) return false;
    for (const char *key : {"touch", "has_cursor", "stick_active"}) if (input.has(key) && input[key].get_type() != Variant::BOOL) return false;
    for (const char *key : {"cursor", "stick"}) if (input.has(key) && (input[key].get_type() != Variant::VECTOR2 || !Vector2(input[key]).is_finite())) return false;
    if (ship.hurt > 0) ship.hurt -= real_dt;
    if (ship.invuln > 0) ship.invuln -= world_dt;
    ship.shield_flash = std::max(0.0, ship.shield_flash - world_dt);
    ship.shield_t = std::max(0.0, ship.shield_t - world_dt);
    if (world_dt <= 0) return true;
    const auto &c = ship_config;
    if (bool(input.get("touch", false))) {
        const Vector2 stick = input.get("stick", Vector2());
        if (bool(input.get("stick_active", false)) && stick.length() >= c.stick_dead_zone) steer_ship(stick.angle(), world_dt);
    } else if (bool(input.get("has_cursor", false))) {
        const Vector2 d = Vector2(input.get("cursor", Vector2())) - ship.pos;
        if (d.length_squared() >= c.mouse_dead_zone * c.mouse_dead_zone) steer_ship(d.angle(), world_dt);
    }
    const double r = ship.pos.length();
    const Vector2 accel = r <= c.field_radius ? Vector2() : -ship.pos / r * (c.boundary_push + (r - c.field_radius) * 4.0);
    move_ship(world_dt, accel);
    // 地形のない比較場面の外周。天体・固定囲いは地形の移行単位で接続する。
    const double radius = ship.pos.length(), wall = c.field_radius + 500.0;
    if (radius > wall) {
        ship.glide = false;
        const Vector2 n = ship.pos / radius;
        ship.pos = n * wall;
        const double vn = ship.vel.dot(n);
        if (vn > 0) ship.vel -= n * 2.0 * vn;
    }
    if (!ship.vel.is_zero_approx()) ship.heading = ship.vel.normalized();
    ship.peak_speed = std::max(ship.peak_speed, double(ship.vel.length()));
    ship_pos = ship.pos;
    return true;
}

Dictionary SpeedRunCore::ship_snapshot() const {
    Dictionary out;
    if (!ship_ready || closed) return out;
    out["ship_pos"] = ship.pos; out["ship_vel"] = ship.vel; out["ship_heading"] = ship.heading;
    out["ship_hp"] = ship.hp; out["ship_hurt"] = ship.hurt; out["ship_invuln"] = ship.invuln;
    out["ship_shield_flash"] = ship.shield_flash; out["ship_shield_t"] = ship.shield_t;
    out["ship_boost_t"] = ship.boost_t; out["ship_fade_t"] = ship.fade_t;
    out["glide"] = ship.glide; out["glide_t"] = ship.glide_t; out["glide_speed"] = ship.glide_speed;
    out["peak_speed"] = ship.peak_speed;
    return out;
}
