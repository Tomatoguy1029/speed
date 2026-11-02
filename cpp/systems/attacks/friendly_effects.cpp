#include "../../api/run_core.h"
#include "friend_debris.h"
#include "../../behaviors/traits/duplicator.h"
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_projectiles(const Dictionary &config, const Dictionary &split) {
    if (runtime.state.started || runtime.state.closed) return false;
    ProjectileConfig c;
    const char *base[] = {"hull_debris_life", "hull_debris_knock"};
    double *fields[] = {&c.debris_life, &c.debris_knock};
    for (int i = 0; i < 2; ++i) {
        if (!config.has(base[i])) return false;
        const Variant value = config[base[i]];
        if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return false;
        *fields[i] = double(value);
        if (!std::isfinite(float(*fields[i])) || *fields[i] < 0) return false;
    }
    if (!config.has("corpse_trail_points") || config["corpse_trail_points"].get_type() != Variant::INT) return false;
    c.trail_points = config["corpse_trail_points"];
    if (c.trail_points < 0) return false;
    if (!split.is_empty()) {
        const char *keys[] = {"chance", "damage", "angle_min", "angle_max"};
        double *values[] = {&c.chance, &c.damage, &c.angle_min, &c.angle_max};
        for (int i = 0; i < 4; ++i) {
            if (!split.has(keys[i])) return false;
            const Variant value = split[keys[i]];
            if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return false;
            *values[i] = double(value);
            if (!std::isfinite(float(*values[i])) || *values[i] < 0) return false;
        }
        if (c.chance > 1 || c.angle_min > c.angle_max) return false;
        for (const char *key : {"generations", "max"}) if (!split.has(key) || split[key].get_type() != Variant::INT) return false;
        c.generations = split["generations"]; c.maximum = split["max"];
        if (c.generations < 0 || c.generations > 255 || c.maximum < 0) return false;
        c.split = true;
    }
    c.ready = true; runtime.state.projectile_config = c;
    return true;
}

bool SpeedRunCore::burst_debris(Vector2 position,int64_t count,double speed,double damage,Color color,int64_t source_id) {
    speed::DebrisBurstParams p;p.position=position;p.count=count;p.speed=speed;p.damage=damage;p.color=color;p.source_id=source_id;
    return speed::FriendDebrisSystem::burst(runtime,p);
}
