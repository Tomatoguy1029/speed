#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_forward(const Dictionary &parameters, int64_t level, double character_scale) {
    if (started || closed || level < 1 || !std::isfinite(character_scale) || character_scale <= 0) return false;
    ForwardWeapon parsed;
    const char *keys[] = {"interval_by_level", "damage_by_level", "pierce_by_level"};
    double interval = 0, damage = 0, pierce = 0;
    double *targets[] = {&interval, &damage, &pierce};
    for (int i = 0; i < 3; ++i) {
        if (!parameters.has(keys[i]) || parameters[keys[i]].get_type() != Variant::ARRAY) return false;
        const Array entries = parameters[keys[i]];
        if (entries.is_empty()) return false;
        for (int j = 0; j < entries.size(); ++j) {
            const Variant entry = entries[j];
            if ((entry.get_type() != Variant::FLOAT && entry.get_type() != Variant::INT) || !std::isfinite(double(entry)) || double(entry) < 0) return false;
        }
        *targets[i] = double(entries[std::min(level - 1, entries.size() - 1)]);
    }
    if (interval <= 0 || pierce > INT32_MAX) return false;
    const char *scalars[] = {"life", "spread_step", "knock"};
    double *fields[] = {&parsed.life, &parsed.spread, &parsed.knock};
    for (int i = 0; i < 3; ++i) {
        if (!parameters.has(scalars[i])) return false;
        const Variant value = parameters[scalars[i]];
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(float(double(value))) || double(value) < 0) return false;
        *fields[i] = double(value);
    }
    parsed.interval = interval; parsed.damage = damage; parsed.pierce = int64_t(pierce);
    parsed.character_scale = character_scale; parsed.ready = true;
    forward = parsed;
    return true;
}

void SpeedRunCore::step_forward(double world_dt) {
    if (!forward.ready) return;
    forward.recoil = std::max(0.0, forward.recoil - world_dt);
    if (draw.drawing || draw.tracing) return;
    forward.elapsed += world_dt;
    if (forward.elapsed < forward.interval) return;
    forward.elapsed = std::fmod(forward.elapsed, forward.interval);
    // 弾数が整数でも、元の共通弾数処理は乱数を一回進める。
    rng->randf();
    const double angle = ship.heading.angle();
    const Vector2 origin = ship.pos + ship.heading * 16.0 * 1.82 * forward.character_scale;
    Friendly shot;
    shot.pos = origin; shot.vel = Vector2::from_angle(angle) * 1300.0;
    shot.damage = combat_config.base_attack * combat_config.attack_mult * combat_config.atk_scale * forward.damage;
    shot.life = forward.life; shot.pierce_left = forward.pierce; shot.knock = forward.knock;
    shot.color = Color::html("ffe46b"); shot.weapon_id = "W01"; shot.visual = "weapon/forward";
    add_friend(std::move(shot));
    forward.recoil = 0.12;
    Dictionary event; event["id"] = StringName("W01"); event["pos"] = origin; event["angle"] = angle; event["visual_key"] = "weapon/forward";
    emit_event("weapon_fire", event);
}

Dictionary SpeedRunCore::forward_snapshot() const {
    Dictionary out; out["elapsed"] = forward.elapsed; out["recoil"] = forward.recoil; return out;
}
