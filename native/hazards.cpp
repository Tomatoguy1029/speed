#include "run_core.h"
#include "../cpp/systems/attacks/wave.h"
#include "../cpp/systems/attack_system.h"
#include "../cpp/systems/combat_resolver.h"
#include "../cpp/output/event_builder.h"
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
    BiteZone zone; zone.pos = at; zone.shape=speed::CircleHazard{float(radius)}; zone.delay = delay; zone.damage = damage; zone.color = color;
    if (!std::isfinite(std::get<speed::CircleHazard>(zone.shape).radius) || !std::isfinite(zone.delay)) return -1;
    speed::AttackSpec spec;spec.owner.budget.value=token;
    spec.policies=speed::EndPolicy::NaturalLifetime|speed::EndPolicy::ClearWithBonus;spec.cause=speed::Cause::Blast;
    if (!runtime.content->contacts.empty()) speed::AttackSystem::configure_contact(*runtime.content,2,spec);
    const auto handle=speed::AttackSystem::emit_hazard(runtime.state,zone,spec);
    const auto *record=speed::AttackSystem::get(runtime.state,handle);return record?record->row:-1;
}

void SpeedRunCore::end_bite_visual(bool hit, Vector2 at) {
    if (!(hit ? runtime.state.bite_zone_config.hit : runtime.state.bite_zone_config.fade)) return;
    Dictionary event; if (runtime.state.bite_zone_config.visual_key) event["visual_key"]=runtime.state.bite_zone_config.visual_key;else event["scene"] = runtime.state.bite_zone_config.scene; event["phase"] = hit ? "Hit" : "Fade"; event["pos"] = at;
    emit_event("attack_visual_end", event);
}

bool SpeedRunCore::step_hazards(double dt) {
    return speed::AttackSystem::step_hazards(runtime,dt);
}

Array SpeedRunCore::hazards_snapshot() const {
    Array out;
    for (size_t i = 0; i < runtime.state.hazards.size(); ++i) {
        const auto &zone = runtime.state.hazards[i]; if (!zone.alive) continue;
        Dictionary row; row["row"] = int64_t(i); row["pos"] = zone.pos; row["radius"] = std::holds_alternative<speed::CircleHazard>(zone.shape)?std::get<speed::CircleHazard>(zone.shape).radius:0.0;
        row["time"] = zone.time; row["delay"] = zone.delay; row["active"] = zone.duration;
        if (const auto *beam=std::get_if<speed::BeamHazard>(&zone.shape)) {
            row["kind"]=0;row["angle"]=beam->angle;row["length"]=beam->length;row["half_width"]=beam->half_width;row["arc"]=beam->arc;
            const auto *record=speed::AttackSystem::get(runtime.state,zone.attack);row["owner_id"]=record?record->spec.owner.source_id:0;
        }
        if (const auto *wall=std::get_if<speed::WallHazard>(&zone.shape)) {
            row["kind"]=3;row["angle"]=wall->angle;row["length"]=wall->length;row["half_width"]=wall->half_width;
            row["style"]=wall->style;row["blocking"]=wall->blocking;
            const auto *record=speed::AttackSystem::get(runtime.state,zone.attack);row["owner_id"]=record?record->spec.owner.source_id:0;
        }
        if (const auto *wave=std::get_if<speed::WaveHazard>(&zone.shape)) {
            row["kind"]=2;row["angle"]=wave->angle;row["length"]=wave->radius;row["half_width"]=wave->half_width;row["arc"]=wave->arc;
            row["radius"]=speed::WaveSystem::radius(zone);row["start_radius"]=wave->start_radius;row["speed"]=wave->speed;
            row["gap_angle"]=wave->gap;row["gap_arc"]=wave->gap_arc;row["style"]=wave->style;row["enemy_damage"]=wave->enemy_damage;
            PackedInt64Array hits;for (auto id:wave->enemy_hits) hits.push_back(id);row["enemy_hits"]=hits;
            const auto *attack=speed::AttackSystem::get(runtime.state,zone.attack);row["attached"]=attack && attack->spec.owner.attached;
        }
        row["damage"] = zone.damage; row["color"] = zone.color; row["hit"] = zone.hit; const auto *record=speed::AttackSystem::get(runtime.state,zone.attack);row["token"]=record?record->spec.owner.budget.value:0; out.append(row);
    }
    return out;
}
