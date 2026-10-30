#include "run_core.h"
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_projectiles(const Dictionary &config, const Dictionary &split) {
    if (started || closed) return false;
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
    c.ready = true; projectile_config = c;
    return true;
}

bool SpeedRunCore::burst_debris(Vector2 position, int64_t count, double speed, double damage, Color color, int64_t source_id) {
    if (!started || closed || !combat_ready || !projectile_config.ready || !position.is_finite() || count < 0 || count > INT32_MAX ||
            !std::isfinite(float(speed)) || speed < 0 || !std::isfinite(damage) || damage < 0) return false;
    for (float channel : {color.r, color.g, color.b, color.a}) if (!std::isfinite(channel)) return false;
    constexpr double tau = 6.283185307179586476925286766559;
    for (int64_t k = 0; k < count; ++k) {
        const Vector2 unit = Vector2::from_angle(tau * k / double(count) + double(rng->randf()) * 0.4);
        Friendly shot;
        shot.kind = 1; shot.cause = "hullDebris"; shot.pos = position + unit * 10.0;
        shot.vel = unit * speed * (0.8 + 0.3 * double(rng->randf()));
        shot.radius = 12; shot.damage = damage; shot.life = projectile_config.debris_life;
        shot.pierce = true; shot.no_crit = true; shot.color = color; shot.knock = projectile_config.debris_knock;
        shot.angle = double(rng->randf()) * tau; shot.spin = k % 2 == 0 ? 10 : -10;
        if (source_id != -1) shot.hit_ids.insert(source_id);
        add_friend(std::move(shot));
    }
    Dictionary event; event["pos"] = position; event["count"] = count; emit_event("hull_scatter", event);
    return true;
}

void SpeedRunCore::duplicate_friend(size_t source, Vector2 impact) {
    const auto &c = projectile_config;
    const auto &parent = friends[source];
    if (!c.split || parent.generation >= c.generations || int64_t(live_friends) + 2 > c.maximum) return;
    if (rng->randf() >= c.chance) return;
    Array directions;
    constexpr double radians = 3.1415926535897932384626433832795 / 180.0;
    for (double side : {-1.0, 1.0}) {
        const double angle = double(rng->randf_range(c.angle_min, c.angle_max)) * radians * side;
        directions.append(parent.vel.rotated(angle) * rng->randf_range(0.9, 1.1));
    }
    for (int i = 0; i < directions.size(); ++i) {
        if (parent.kind == 1 && live_debris >= 200) break;
        Friendly child = parent;
        child.pos = impact; child.vel = directions[i]; child.damage *= c.damage;
        child.angle = child.vel.angle(); child.generation = parent.generation + 1;
        // 新しい破片の航跡だけは空で始める。命中IDと進んだ時間は引き継ぐ。
        child.trail = PackedVector2Array();
        add_friend(std::move(child));
    }
    Dictionary event; event["pos"] = impact; event["directions"] = directions; emit_event("duplicate", event);
}
