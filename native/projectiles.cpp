#include "run_core.h"
#include "../cpp/systems/field.h"
#include "../cpp/systems/attacks/friend_shot.h"
#include "../cpp/systems/attacks/reflected.h"
#include "../cpp/systems/combat_resolver.h"
#include "../cpp/systems/attack_system.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/math.hpp>
using namespace godot;

size_t SpeedRunCore::add_friend(Friendly shot) {
    speed::AttackSpec spec;spec.policies=speed::policy(speed::EndPolicy::NaturalLifetime);
    if (shot.weapon_id==StringName("W01")) spec.weapon=1;
    if (!speed::parse_symbol(String(shot.cause).utf8().get_data(),spec.cause)) return SIZE_MAX;
    const auto handle=speed::AttackSystem::emit_friendly(runtime.state,std::move(shot),spec);
    const auto *record=speed::AttackSystem::get(runtime.state,handle);return record?record->row:SIZE_MAX;
}

bool SpeedRunCore::fire_shot(Vector2 from, double angle, double damage, const Dictionary &options) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.combat_ready || !from.is_finite() || !std::isfinite(angle) || !std::isfinite(damage) || damage < 0) return false;
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
    const auto handle=speed::FriendShotSystem::emit(runtime,std::move(shot));
    return speed::AttackSystem::get(runtime.state,handle)!=nullptr;
}


bool SpeedRunCore::step_projectiles(double world_dt) {
    return speed::AttackSystem::step_friendly(runtime,world_dt);
}

Array SpeedRunCore::projectiles_snapshot() const {
    Array out;
    for (size_t row = 0; row < runtime.state.friends.size(); ++row) {
        const auto &shot = runtime.state.friends[row];
        if (!shot.alive) continue;
        std::vector<int64_t> sorted(shot.hit_ids.begin(), shot.hit_ids.end());
        std::sort(sorted.begin(), sorted.end());
        Array ids; for (int64_t id : sorted) ids.append(id);
        Dictionary item;
        item["row"] = int64_t(row); item["kind"] = shot.kind; item["generation"] = shot.generation; item["pos"] = shot.pos; item["vel"] = shot.vel;
        item["radius"] = shot.radius; item["damage"] = shot.damage; item["life"] = shot.life; item["age"] = shot.age; item["knock"]=shot.knock;
        item["cause"]=shot.cause;item["type"]=shot.type;item["pierce"]=shot.pierce;item["pierce_left"] = shot.pierce_left; item["hit_ids"] = ids; item["angle"] = shot.angle; item["trail"] = shot.trail;
        out.append(item);
    }
    return out;
}

PackedFloat32Array SpeedRunCore::friendly_buffer(StringName visual, double pixel, double scale, double clock) const {
    PackedFloat32Array buffer;
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(pixel) || pixel <= 0 || !std::isfinite(scale) || scale <= 0 || !std::isfinite(clock)) return buffer;
    int64_t count = 0;
    for (const auto &shot : runtime.state.friends) if (shot.alive && shot.visual == visual) ++count;
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    for (const auto &shot : runtime.state.friends) {
        if (!shot.alive || shot.visual != visual) continue;
        const Vector2 position = (shot.pos / pixel).round() * pixel;
        const double size = 18.0 * pixel * scale;
        const double angle = Math::fposmod(double(shot.vel.angle()), 2.0 * godot::Math::PI) / (2.0 * godot::Math::PI);
        out[index++] = size; out[index++] = 0; out[index++] = 0; out[index++] = position.x;
        out[index++] = 0; out[index++] = size; out[index++] = 0; out[index++] = position.y;
        out[index++] = angle; out[index++] = visual == StringName("weapon/scatter") && shot.life < 0.09 ? 1 : 0;
        out[index++] = clock; out[index++] = 1;
    }
    return buffer;
}
