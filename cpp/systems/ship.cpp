#include "../api/run_core.h"
#include "field.h"
#include "boss_contact_feedback.h"
#include "geometry.h"
#include "../behaviors/heroes/leo.h"
#include "../content/content_bundle.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>

using namespace godot;

bool SpeedRunCore::configure_ship(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
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
    runtime.state.ship_config = c;
    runtime.state.ship = Ship();
    runtime.state.ship.pos = Vector2(-c.start_radius, 0);
    runtime.state.ship.vel = Vector2(0, -c.base_max_speed * 0.3);
    runtime.state.ship.hp = c.max_hp;
    runtime.state.ship_pos = runtime.state.ship.pos;
    runtime.state.ship_ready = true;
    return true;
}

void SpeedRunCore::steer_ship(double want, double dt) {
    const auto &c = runtime.state.ship_config;
    // しし座の獅子は速く曲がり、一定の速さで駆ける（速さは move_ship が保つ）
    const auto *lion = speed::LeoBehavior::active(runtime);
    const double turn_rate = lion ? c.turn_rate * lion->turn_mult : c.turn_rate;
    const double sp = runtime.state.ship.vel.length();
    if (sp > 1) {
        const double difference = want - double(runtime.state.ship.vel.angle());
        const double wrapped = speed::angle_difference(difference);
        const double turn = std::clamp(wrapped, -turn_rate * dt, turn_rate * dt);
        runtime.state.ship.vel = runtime.state.ship.vel.rotated(turn);
    }
    if (lion) {
        if (runtime.state.ship.vel.is_zero_approx()) runtime.state.ship.vel = Vector2::from_angle(want) * lion->speed;
        return;
    }
    const double cruise = c.max_speed * c.steer_cruise;
    if (sp < cruise) runtime.state.ship.vel += Vector2::from_angle(want) * std::min(c.acceleration * dt, cruise - sp);
    if (runtime.state.ship.vel.is_zero_approx()) runtime.state.ship.heading = Vector2::from_angle(want);
}

void SpeedRunCore::move_ship(double dt, Vector2 accel) {
    const auto &c = runtime.state.ship_config;
    // しし座の獅子：勢いや減速はかけず、場の境界の押し戻しだけ受けて、いつも定義の速さで駆ける
    if (const auto *lion = speed::LeoBehavior::active(runtime)) {
        auto &ship = runtime.state.ship;
        ship.glide = false; ship.boost_t = 0; ship.fade_t = 0;
        Vector2 vel = ship.vel + accel * dt;
        if (vel.is_zero_approx()) vel = ship.heading.is_zero_approx() ? Vector2(1, 0) : ship.heading;
        ship.vel = vel.normalized() * lion->speed;
        ship.pos += ship.vel * dt;
        ship.heading = ship.vel.normalized();
        return;
    }
    if (runtime.state.ship.glide) {
        runtime.state.ship.glide_t += dt;
        const double cruise = c.max_speed * c.steer_cruise;
        double sp = runtime.state.ship.glide_speed;
        const double distance_ratio=std::clamp(runtime.state.draw.total/std::max(runtime.state.draw_config.length,1.0),0.0,1.0);
        const double duration_mult=distance_ratio*c.glide_duration_mult;
        const double hold = c.glide_hold * duration_mult;
        const double fade = c.glide_fade * duration_mult;
        if (runtime.state.ship.glide_t > hold) {
            const double k = (runtime.state.ship.glide_t - hold) / std::max(0.001, fade);
            if (k >= 1) { runtime.state.ship.glide = false; sp = cruise; }
            else sp = Math::lerp(runtime.state.ship.glide_speed, cruise, k);
        }
        if (!runtime.state.ship.vel.is_zero_approx()) runtime.state.ship.vel = runtime.state.ship.vel.normalized() * sp;
        runtime.state.ship.boost_t = std::max(0.0, runtime.state.ship.boost_t - dt);
        runtime.state.ship.fade_t = 0;
        runtime.state.ship.pos += runtime.state.ship.vel * dt;
        return;
    }
    runtime.state.ship.vel += accel * dt;
    const double sp = runtime.state.ship.vel.length();
    if (sp > 0) {
        double target = sp;
        if (runtime.state.ship.boost_t > 0) {
            runtime.state.ship.boost_t -= dt;
            if (runtime.state.ship.boost_t <= 0) runtime.state.ship.fade_t = 0.3;
        } else {
            if (runtime.state.ship.fade_t > 0) {
                runtime.state.ship.fade_t -= dt;
                if (target > c.max_speed * c.cruise_floor) target *= std::pow(c.energy_cut, dt / 0.3);
            }
            const double floor = c.max_speed * c.cruise_floor;
            if (target > floor) target = floor + (target - floor) * std::exp(-c.cruise_drag * dt);
        }
        if (target > c.max_speed) target = c.max_speed + (target - c.max_speed) * std::exp(-c.overcap_decay * dt);
        runtime.state.ship.vel *= target / sp;
    }
    runtime.state.ship.pos += runtime.state.ship.vel * dt;
    if (!runtime.state.ship.vel.is_zero_approx()) runtime.state.ship.heading = runtime.state.ship.vel.normalized();
}

bool SpeedRunCore::step_ship(double real_dt, double world_dt, const Dictionary &input) {
    speed::InputFrame frame;
    if (!speed::decode_input(input,frame,false)) return false;
    return step_ship_input(real_dt,world_dt,frame);
}

bool SpeedRunCore::step_ship_input(double real_dt, double world_dt, const speed::InputFrame &input) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !std::isfinite(real_dt) || !std::isfinite(world_dt) || real_dt < 0 || world_dt < 0) return false;
    if (runtime.state.ship.hurt > 0) runtime.state.ship.hurt=speed::remaining_time(runtime.state.ship.hurt,real_dt);
    if (runtime.state.ship.invuln > 0) runtime.state.ship.invuln=speed::remaining_time(runtime.state.ship.invuln,world_dt);
    runtime.state.ship.shield_flash = std::max(0.0, runtime.state.ship.shield_flash - world_dt);
    if (runtime.state.ship.shield_t > 0) {
        runtime.state.ship.shield_t = std::max(0.0, runtime.state.ship.shield_t - world_dt);
        if (runtime.state.ship.shield_t <= 0) { Dictionary event; event["pos"] = runtime.state.ship.pos; emit_event("shield_expired", event); }
    }
    if (runtime.state.draw.drawing || runtime.state.draw.tracing || world_dt <= 0) return true;
    const auto &c = runtime.state.ship_config;
    if (bool(input.touch)) {
        const Vector2 stick = input.stick;
        if (bool(input.stick_active) && stick.length() >= c.stick_dead_zone) steer_ship(stick.angle(), world_dt);
    } else if (bool(input.has_cursor)) {
        const Vector2 d = Vector2(input.cursor) - runtime.state.ship.pos;
        if (d.length_squared() >= c.mouse_dead_zone * c.mouse_dead_zone) steer_ship(d.angle(), world_dt);
    }
    const Vector2 accel=speed::FieldSystem::boundary_accel(runtime,runtime.state.ship.pos);
    const Vector2 from = runtime.state.ship.pos;
    move_ship(world_dt, accel);
    // しし座の獅子は弾かれず、獅子の体で当たる
    if (speed::LeoBehavior::active(runtime)) { if (runtime.state.combat_ready) speed::LeoBehavior::contact(runtime, from, runtime.state.ship.pos); }
    else if (runtime.state.combat_ready) collide_ship(from, c.ship_radius);
    if (runtime.state.phase!=Phase::Play) return true;
    speed::FieldSystem::collide_ship(runtime);
    if (!runtime.state.ship.vel.is_zero_approx()) runtime.state.ship.heading = runtime.state.ship.vel.normalized();
    runtime.state.ship.peak_speed = std::max(runtime.state.ship.peak_speed, double(runtime.state.ship.vel.length()));
    runtime.state.ship_pos = runtime.state.ship.pos;
    return true;
}

Dictionary SpeedRunCore::ship_snapshot() const {
    Dictionary out;
    if (!runtime.state.ship_ready || runtime.state.closed) return out;
    out["ship_pos"] = runtime.state.ship.pos; out["ship_vel"] = runtime.state.ship.vel; out["ship_heading"] = runtime.state.ship.heading;
    out["ship_contact_white"] = speed::boss_contact_white(runtime);
    out["ship_hp"] = runtime.state.ship.hp; out["ship_hurt"] = runtime.state.ship.hurt; out["ship_invuln"] = runtime.state.ship.invuln;
    out["ship_shield_flash"] = runtime.state.ship.shield_flash; out["ship_shield_t"] = runtime.state.ship.shield_t; out["ship_shield_max"] = runtime.state.ship.shield_max;
    out["ship_boost_t"] = runtime.state.ship.boost_t; out["ship_fade_t"] = runtime.state.ship.fade_t;
    out["glide"] = runtime.state.ship.glide; out["glide_t"] = runtime.state.ship.glide_t; out["glide_speed"] = runtime.state.ship.glide_speed;
    out["peak_speed"] = runtime.state.ship.peak_speed;
    return out;
}
