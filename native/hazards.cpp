#include "run_core.h"
#include "../cpp/systems/attack_system.h"
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_bite_zone(const Dictionary &data) {
    if (runtime.state.started || runtime.state.closed || data.get("version", Variant()).get_type() != Variant::INT || int64_t(data["version"]) != 1) return false;
    const Variant duration = data.get("duration", Variant());
    if ((duration.get_type() != Variant::FLOAT && duration.get_type() != Variant::INT) || !std::isfinite(double(duration)) || double(duration) <= 0) return false;
    BiteZoneConfig parsed; parsed.duration = double(duration);
    if (!std::isfinite(parsed.duration) || parsed.duration <= 0) return false;
    if (data.get("scene", Variant()).get_type() != Variant::STRING || String(data["scene"]).is_empty()) return false;
    for (const char *key : {"hit", "fade"}) if (data.get(key, Variant()).get_type() != Variant::BOOL) return false;
    parsed.scene = data["scene"]; parsed.hit = data["hit"]; parsed.fade = data["fade"]; parsed.ready = true;
    runtime.state.bite_zone_config = parsed; return true;
}

int64_t SpeedRunCore::fire_bite_zone(Vector2 at, double radius, double delay, double damage, Color color, int64_t token) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.bite_zone_config.ready || !at.is_finite() || token < 0) return -1;
    for (double value : {radius, delay, damage}) if (!std::isfinite(value) || value < 0) return -1;
    for (int k = 0; k < 4; ++k) if (!std::isfinite(color[k])) return -1;
    BiteZone zone; zone.pos = at; zone.radius = radius; zone.delay = delay; zone.damage = damage; zone.color = color;
    if (!std::isfinite(zone.radius) || !std::isfinite(zone.delay)) return -1;
    speed::AttackSpec spec;spec.owner.budget.value=token;
    spec.policies=speed::EndPolicy::NaturalLifetime|speed::EndPolicy::ClearWithBonus;spec.cause=speed::Cause::Blast;
    const auto handle=speed::AttackSystem::emit_hazard(runtime.state,zone,spec);
    const auto *record=speed::AttackSystem::get(runtime.state,handle);return record?record->row:-1;
}

void SpeedRunCore::end_bite_visual(bool hit, Vector2 at) {
    if (!(hit ? runtime.state.bite_zone_config.hit : runtime.state.bite_zone_config.fade)) return;
    Dictionary event; event["scene"] = runtime.state.bite_zone_config.scene; event["phase"] = hit ? "Hit" : "Fade"; event["pos"] = at;
    emit_event("attack_visual_end", event);
}

bool SpeedRunCore::step_hazards(double dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !std::isfinite(dt) || dt < 0) return false;
    const int64_t update_cutoff=runtime.state.attacks.next_id;
    for (size_t row = 0; row < runtime.state.bite_zones.size(); ++row) {
        auto &zone = runtime.state.bite_zones[row]; if (!zone.alive) continue;
        const auto processing_handle=zone.attack;const auto *record=speed::AttackSystem::get(runtime.state,processing_handle);
        if (!record || record->id>=update_cutoff) continue;
        // 元の配列への保存は単精度、同じ更新の分岐は保存前の倍精度で判断する。
        const double time = double(zone.time) + dt; zone.time = time;
        if (time >= double(zone.delay) + double(zone.duration)) {
            speed::AttackSystem::end(runtime.state,processing_handle,speed::AttackEndReason::Lifetime);continue;
        }
        if (time>=zone.delay && !speed::AttackSystem::hazard_act(runtime.state,processing_handle,dt)) return true;
        if (time < zone.delay || zone.hit) continue;
        if (!speed::AttackSystem::hazard_before_touch(runtime.state,processing_handle)) return true;
        // 円形判定は発動時の一回だけ。範囲外でも以後は表示だけ残す。
        zone.hit = true;
        const double reach = double(zone.radius) + runtime.state.ship_config.ship_radius;
        if (zone.pos.distance_squared_to(runtime.state.ship.pos) > reach * reach) continue;
        end_bite_visual(true, runtime.state.ship.pos);
        damage_ship(zone.damage, 0.0, "blast");
        if (runtime.state.phase != Phase::Play) return true;
    }
    return true;
}

Array SpeedRunCore::hazards_snapshot() const {
    Array out;
    for (size_t i = 0; i < runtime.state.bite_zones.size(); ++i) {
        const auto &zone = runtime.state.bite_zones[i]; if (!zone.alive) continue;
        Dictionary row; row["row"] = int64_t(i); row["pos"] = zone.pos; row["radius"] = zone.radius;
        row["time"] = zone.time; row["delay"] = zone.delay; row["active"] = zone.duration;
        row["damage"] = zone.damage; row["color"] = zone.color; row["hit"] = zone.hit; const auto *record=speed::AttackSystem::get(runtime.state,zone.attack);row["token"]=record?record->spec.owner.budget.value:0; out.append(row);
    }
    return out;
}
