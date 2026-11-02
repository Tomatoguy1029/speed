#include "run_core.h"
#include "../cpp/behaviors/weapons/barrier.h"
#include "../cpp/systems/field.h"
#include "../cpp/systems/attack_system.h"
#include "../cpp/systems/attacks/missile.h"
#include "../cpp/systems/attacks/wall.h"
#include "../cpp/systems/attacks/slash.h"
#include "../cpp/systems/attacks/light_arrow.h"
#include "geometry.h"
#include "../cpp/systems/combat_resolver.h"
#include "../cpp/output/event_builder.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

size_t SpeedRunCore::add_hostile(Hostile shot,speed::AttackSpec spec) {
    if (!spec.contact_definition && !runtime.content->contacts.empty()) speed::AttackSystem::configure_contact(*runtime.content,1,spec);
    if (!spec.policies) spec.policies=speed::EndPolicy::NaturalLifetime|speed::EndPolicy::ClearWithBonus;
    if (spec.cause==speed::Cause::None) spec.cause=shot.kind==1?speed::Cause::Missile:shot.kind==2?speed::Cause::Reflected:speed::Cause::Bullet;
    const auto handle=speed::AttackSystem::emit_hostile(runtime.state,std::move(shot),spec);
    const auto *record=speed::AttackSystem::get(runtime.state,handle);return record?record->row:SIZE_MAX;
}

int64_t SpeedRunCore::spawn_hostile(const Dictionary &fields) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !fields.has("kind") || fields["kind"].get_type() != Variant::INT) return -1;
    const Array keys_in = fields.keys();
    for (int i = 0; i < keys_in.size(); ++i) {
        const String key = keys_in[i];
        if (key != "kind" && key != "pos" && key != "vel" && key != "speed" && key != "r" && key != "life" && key != "dmg" && key != "slow" && key != "turn" && key != "stone" && key != "wait" && key != "attack_token") return -1;
    }
    Hostile shot;speed::AttackSpec spec;
    if (fields.has("attack_token")) {
        if (fields["attack_token"].get_type() != Variant::INT || int64_t(fields["attack_token"]) < 0) return -1;
        spec.owner.budget.value = fields["attack_token"];
    }
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
    const auto row=add_hostile(std::move(shot),spec);return row==SIZE_MAX?-1:int64_t(row);
}

bool SpeedRunCore::damage_ship(double amount,double slow,StringName cause,StringName source) {
    speed::ShipDamageRequest request;request.amount=amount;request.slow=slow;
    if (!speed::parse_symbol(String(cause).utf8().get_data(),request.cause)) return false;
    for (size_t i=0;i<runtime.content->definitions.size();++i) if (runtime.content->definitions[i].id==source) {request.source=uint32_t(i+1);break;}
    const auto result=speed::CombatResolver::ship_damage(runtime,request);speed::EventBuilder::flush_combat(runtime);return result.accepted;
}


bool SpeedRunCore::step_hostiles(double world_dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    if (!speed::AttackSystem::begin_hostile_update(runtime.state)) return false;
    struct UpdateEnd {RunState &state;~UpdateEnd(){speed::AttackSystem::finish_hostile_update(state);}} update_end{runtime.state};
    const Vector2 keep = runtime.state.view_half + Vector2(400, 400);
    for (size_t row = 0; row < runtime.state.hostiles.size(); ++row) {
        auto &shot = runtime.state.hostiles[row];
        if (!shot.alive) continue;
        const auto processing_handle=shot.attack;
        auto end_reason=speed::AttackEndReason::Lifetime;
        const auto release = [&]() { speed::AttackSystem::end(runtime.state,processing_handle,end_reason); };
        double life = shot.life;
        if (life <= 0) { release(); continue; }
        const Vector2 from = shot.pos;
        if (shot.stone > 0) {
            shot.stone = speed::remaining_time(shot.stone,world_dt);
            const double reach = double(shot.radius) + runtime.state.ship_config.ship_radius;
            if (runtime.state.ship.pos.distance_squared_to(from) <= reach * reach) {end_reason=speed::AttackEndReason::Hit;release();}
            continue;
        }
        Vector2 vel = shot.vel;
        if (shot.wait > 0) { shot.wait = speed::remaining_time(shot.wait,world_dt); vel = Vector2(); }
        if (shot.kind==int64_t(speed::HostileKind::Missile)) {
            const auto steered=speed::MissileSystem::steer(runtime,shot,vel,world_dt);
            if (steered!=vel) {vel=steered;shot.vel=vel;}
        }
        Vector2 to = from + vel * world_dt;
        life -= world_dt;
        const Vector2 relative = to - runtime.state.view_center;
        if (shot.kind!=int64_t(speed::HostileKind::Missile) && (std::abs(relative.x) > keep.x || std::abs(relative.y) > keep.y) && relative.dot(vel) > 0) life = 0;
        const auto *record=speed::AttackSystem::get(runtime.state,processing_handle);
        if (!record) continue;
        const double body_radius=record->spec.contact.add_ship_radius?runtime.state.ship_config.ship_radius:0;
        const double step = double(shot.speed) * world_dt;
        double gap=double(shot.gap)-runtime.state.field.body_speed_max*world_dt;
        std::optional<speed::BodyHit> body_hit;
        if (gap<=step) {gap=speed::FieldSystem::body_gap(runtime,from,shot.radius);if (gap<=step) body_hit=speed::FieldSystem::first_body_hit(runtime,from,to,shot.radius);}
        const auto wall=speed::WallSystem::block_hit(runtime,from,to,shot.radius);
        if (wall && (!body_hit || wall->t<body_hit->t)) body_hit=speed::BodyHit{UINT32_MAX,wall->t,wall->point};
        speed::ShipDamageRequest blocked;blocked.amount=shot.damage;blocked.slow=shot.slow;blocked.cause=record->spec.cause;
        blocked.source=record->spec.owner.source_definition;blocked.technique=record->spec.source_technique;blocked.scale=record->spec.contact.scale;
        const Vector2 barrier_end=body_hit?body_hit->point:to;
        const double barrier_t=speed::BarrierBehavior::segment(runtime,from,barrier_end,shot.radius,blocked);
        if (barrier_t>=0) {
            blocked.impact=from+(barrier_end-from)*barrier_t;blocked.has_impact=true;
            const auto defense=speed::CombatResolver::ship_damage(runtime,blocked);speed::EventBuilder::flush_combat(runtime);
            if (defense.reason==speed::CombatReason::Barrier) {
                shot.pos=blocked.impact;end_reason=speed::AttackEndReason::Barrier;release();continue;
            }
        }
        if (shot.kind==int64_t(speed::HostileKind::Slash)) {
            if (speed::SlashSystem::contact(runtime,processing_handle,to)) {end_reason=speed::AttackEndReason::Hit;life=0;body_hit.reset();}
        }
        const bool long_arrow=shot.arrow.definition && shot.arrow.length>0;
        if (long_arrow) {
            const auto t=speed::LightArrowSystem::contact(runtime,processing_handle,from,to,step,body_hit?std::optional<double>(body_hit->t):std::nullopt);
            if (t) {to=from.lerp(to,*t);end_reason=speed::AttackEndReason::Hit;life=0;body_hit.reset();}
        }
        const double ship_t=speed::CollisionQuery::segment_circle_t(from,to,runtime.state.ship.pos,double(shot.radius)+body_radius);
        const double reach = double(shot.radius) + body_radius + step;
        if (!long_arrow && shot.kind!=int64_t(speed::HostileKind::Slash) && (!body_hit || (ship_t>=0 && ship_t<body_hit->t)) && (record->spec.contact.ship_sweep || runtime.state.ship.pos.distance_squared_to(to) <= reach * reach)) {
            const auto contact=speed::CombatResolver::attack_ship_damage(runtime,processing_handle,speed::SegmentCircle{from,to,double(shot.radius)},shot.damage,shot.slow);
            speed::EventBuilder::flush_combat(runtime);
            if (contact.touching) {
                const double t=speed::CollisionQuery::segment_circle_t(from,to,runtime.state.ship.pos,double(shot.radius)+body_radius);
                end_reason=speed::AttackEndReason::Hit;life=0;if (t>=0) to=from+(to-from)*t;
                body_hit.reset();
            }
        }
        if (!speed::AttackSystem::get(runtime.state,processing_handle)) continue;
        if (body_hit) {to=body_hit->point;end_reason=speed::AttackEndReason::Hit;life=0;}
        if (life <= 0) {shot.pos=to;release();}
        else {
            shot.pos = to; shot.life = life;
            shot.gap = gap-step;
        }
    }
    return true;
}

Array SpeedRunCore::hostiles_snapshot() const {
    Array out;
    for (size_t row = 0; row < runtime.state.hostiles.size(); ++row) {
        const auto &shot = runtime.state.hostiles[row];
        if (!shot.alive) continue;
        Dictionary item;
        item["row"] = int64_t(row); item["kind"] = shot.kind; item["pos"] = shot.pos; item["vel"] = shot.vel;
        if (shot.star_bolt.definition) item["radius"]=shot.radius;
        if (shot.arrow.definition) item["length"]=shot.arrow.length;
        if (shot.slash.definition) {item["size"]=shot.radius;item["side"]=shot.slash.side;}
        item["life"] = shot.life; item["gap"] = shot.gap; item["stone"] = shot.stone; item["wait"] = shot.wait;
        out.append(item);
    }
    return out;
}
