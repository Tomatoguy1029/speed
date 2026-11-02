#include "run_core.h"
#include "../cpp/behaviors/weapons/forward.h"
#include "../cpp/systems/attacks/friend_shot.h"
#include "../cpp/systems/attack_system.h"
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_forward(const Dictionary &parameters, int64_t level, double character_scale) {
    if (runtime.state.started || runtime.state.closed || level < 1 || !std::isfinite(character_scale) || character_scale <= 0) return false;
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
    parsed.fire.remaining=interval;
    parsed.base_interval = parsed.interval = interval; parsed.damage = damage; parsed.pierce = int64_t(pierce);
    parsed.character_scale = character_scale; parsed.ready = true;
    runtime.state.forward = parsed; runtime.state.forward_parameters=parameters.duplicate(true);
    return true;
}

void SpeedRunCore::step_forward(double world_dt) {
    speed::ForwardBehavior::step(runtime,world_dt);
}

Dictionary SpeedRunCore::forward_snapshot() const {
    Dictionary out; out["elapsed"] = runtime.state.forward.interval-runtime.state.forward.fire.remaining; out["recoil"] = runtime.state.forward.recoil; return out;
}

Dictionary SpeedRunCore::scatter_snapshot() const {
    const auto &weapon=runtime.state.loadout.scatter;
    Dictionary out;out["elapsed"]=weapon.interval-weapon.fire.remaining;out["recoil"]=weapon.recoil;return out;
}

Dictionary SpeedRunCore::rear_snapshot() const {
    const auto &weapon=runtime.state.loadout.rear;
    Dictionary out;out["elapsed"]=weapon.interval-weapon.fire.remaining;out["recoil"]=weapon.recoil;
    out["ready"]=weapon.ready;out["mount"]=runtime.state.ship.pos+Vector2(weapon.mount_x,weapon.mount_y).rotated(runtime.state.ship.heading.angle()+Math::PI/2.0)*weapon.character_scale;out["aim"]=-runtime.state.ship.heading;return out;
}

bool SpeedRunCore::set_forward_level(int64_t level) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.forward.ready || level<1) return false;
    if (runtime.state.forward_parameters.is_empty()) {
        if (runtime.content->forward_levels.empty()) return false;
        const auto &next=runtime.content->forward_levels[std::min(size_t(level-1),runtime.content->forward_levels.size()-1)];
        speed::ForwardBehavior::set_interval(runtime.state.forward,next.interval);runtime.state.forward.damage=next.damage;
        runtime.state.forward.pierce=next.pierce;runtime.state.forward.life=next.life;runtime.state.forward.spread=next.spread;
        runtime.state.forward.knock=next.knock;return true;
    }
    const Array intervals=runtime.state.forward_parameters["interval_by_level"], damages=runtime.state.forward_parameters["damage_by_level"], pierces=runtime.state.forward_parameters["pierce_by_level"];
    speed::ForwardBehavior::set_interval(runtime.state.forward,intervals[std::min(level-1,intervals.size()-1)]); runtime.state.forward.damage=damages[std::min(level-1,damages.size()-1)]; runtime.state.forward.pierce=int64_t(pierces[std::min(level-1,pierces.size()-1)]); return true;
}
