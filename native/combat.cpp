#include "run_core.h"
#include "../cpp/systems/attacks/wall.h"
#include "../cpp/behaviors/traits/fullCharge.h"
#include "../cpp/behaviors/traits/runUp.h"
#include "../cpp/behaviors/enemies/shield.h"
#include "../cpp/systems/field.h"
#include "geometry.h"
#include "../cpp/systems/combat_resolver.h"
#include "../cpp/output/event_builder.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/math.hpp>
using namespace godot;

bool SpeedRunCore::configure_combat(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
    CombatConfig c{};
    const char *keys[] = {"base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius", "attack_mult", "crit_chance", "crit_mult"};
    double *fields[] = {&c.base_attack, &c.atk_scale, &c.ram_speed_ratio, &c.crit_armor, &c.touch_damage, &c.contact_cooldown, &c.bounce_keep, &c.bounce_min_speed, &c.kill_hitstop, &c.kill_hitstop_cap, &c.kill_hitstop_regen, &c.hitstop_big_mult, &c.hitstop_crit_mult, &c.max_enemy_radius, &c.attack_mult, &c.crit_chance, &c.crit_mult};
    for (int i = 0; i < 17; ++i) {
        const Dictionary &source = i < 14 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *fields[i] = double(value);
        if (!std::isfinite(*fields[i]) || *fields[i] < 0) return false;
    }
    runtime.state.combat_config = c; runtime.state.combat_ready = true;
    return true;
}

void SpeedRunCore::emit_event(StringName type, Dictionary data) { speed::EventBuilder::flush_combat(runtime); speed::FrameBuilder::append(runtime,type,data); }
Array SpeedRunCore::drain_events() { speed::EventBuilder::flush_combat(runtime); if (runtime.api_configured) {
        Array out;for (int64_t i=0;i<runtime.frame_workspace.pending.size();++i) {
            const auto &event=runtime.frame_workspace.pending[i];auto row=event.payload.duplicate(true);
            row["type"]=StringName(speed::symbol_name(event.type));row["t"]=event.time;row["world_t"]=event.world_time;out.append(row);
        }return out;
    }
    Array out = runtime.state.events; runtime.state.events = Array(); return out; }
Dictionary SpeedRunCore::combat_snapshot() const {
    Dictionary out; out["hitstop"] = runtime.state.hitstop; out["dash_stop"] = runtime.state.dash_stop; out["kills"] = runtime.state.kills; return out;
}

static double segment_circle(Vector2 from, Vector2 to, Vector2 center, double radius) {
    const Vector2 f = from - center;
    const double cc = double(f.length_squared()) - radius * radius;
    if (cc <= 0) return 0;
    const Vector2 d = to - from;
    const double a = d.length_squared();
    if (a == 0) return -1;
    const double b = 2.0 * f.dot(d), disc = b * b - 4.0 * a * cc;
    if (disc < 0) return -1;
    const double t = (-b - std::sqrt(disc)) / (2.0 * a);
    return t >= 0 && t <= 1 ? t : -1;
}

static double angle_difference(double target, double current) {
    const double difference = target - current;
    return speed::angle_difference(difference);
}

bool SpeedRunCore::blocks_front(size_t row, Vector2 hit, Vector2 direction) const {
    const auto handle=runtime.state.enemy_handles.at(uint32_t(row));
    return runtime.content->definitions[runtime.state.enemies[row].definition].kind==speed::EnemyDefinition::Kind::Shield && speed::ShieldBehavior::blocks_front(runtime,handle,hit,direction);
}

void SpeedRunCore::damage_enemy(size_t row,double amount,StringName cause,bool crit,Vector2 direction,double knock,const Vector2 *impact) {
    speed::DamageRequest request;request.struck=runtime.state.enemy_handles.at(uint32_t(row));
    if (!speed::parse_symbol(String(cause).utf8().get_data(),request.cause)) return;
    request.amount=amount;request.crit=crit;request.direction=direction;request.knock=knock;
    request.has_impact=impact!=nullptr;if (impact) request.impact=*impact;
    speed::CombatResolver::damage_enemy(runtime,request);speed::EventBuilder::flush_combat(runtime);
}

void SpeedRunCore::kill_enemy(size_t row,bool crit,StringName cause,Vector2 direction) {
    speed::DamageRequest request;request.struck=runtime.state.enemy_handles.at(uint32_t(row));
    if (!speed::parse_symbol(String(cause).utf8().get_data(),request.cause)) return;
    request.crit=crit;request.direction=direction;
    speed::CombatResolver::kill_enemy(runtime,request);speed::EventBuilder::flush_combat(runtime);
}

bool SpeedRunCore::collide_ship(Vector2 from, double radius) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.combat_ready || !from.is_finite() || !std::isfinite(radius) || radius < 0) return false;
    if (speed::WallSystem::bounce_ship(runtime,from)) return true;
    const auto &c = runtime.state.combat_config;
    const Vector2 to = runtime.state.ship.pos;
    const double padding = radius + std::max(c.max_enemy_radius, runtime.state.grid.max_radius);
    const Vector2 pad(padding, padding);
    struct Hit { double time; size_t row; };
    struct Earlier { bool operator()(const Hit &a, const Hit &b) const { return a.time < b.time; } };
    std::vector<Hit> hits;
    for (size_t row : query_enemy_rows(from.min(to) - pad, from.max(to) + pad)) {
        const auto &enemy = runtime.state.enemies[row];
        if (runtime.state.draw.tracing ? runtime.state.draw.inside.count(enemy.id) > 0 : (enemy.hit_cd > 0 && !runtime.state.field.rock_handles.contains(enemy.rock) && runtime.content->definitions[enemy.definition].kind != speed::EnemyDefinition::Kind::Shield)) continue;
        const double t = segment_circle(from, to, enemy.pos, enemy.radius + radius);
        if (t >= 0) hits.push_back({t, row});
    }
    SortArray<Hit, Earlier>().sort(hits.data(), hits.size());
    for (const auto &hit : hits) {
        auto &enemy = runtime.state.enemies[hit.row];
        if (enemy.dead || (runtime.state.draw.tracing && runtime.state.draw.inside.count(enemy.id) > 0)) continue;
        const auto &def = runtime.content->definitions[enemy.definition];
        const Vector2 position = from.lerp(to, hit.time);
        const double speed = runtime.state.ship.vel.length();
        const Vector2 direction = speed > 0 ? runtime.state.ship.vel / speed : Vector2();
        if (runtime.state.draw.tracing) speed::FullChargeBehavior::prepare(runtime,from.distance_to(position));
        const double attack = speed::CombatResolver::attack_power(runtime)*speed::RunUpBehavior::multiplier(runtime,from.distance_to(position));
        const bool fast = runtime.state.draw.tracing || runtime.state.ship.glide || speed >= runtime.state.ship_config.max_speed * c.ram_speed_ratio;
        const bool front = blocks_front(hit.row, position, direction);
        if (front && (!fast || (!runtime.state.draw.tracing && enemy.hit_cd > 0))) {
            Vector2 normal = position - enemy.pos;
            normal = normal.length_squared() > 0 ? normal.normalized() : -direction;
            runtime.state.ship.pos = enemy.pos + normal * (enemy.radius + radius + 1.0);
            const double vn = runtime.state.ship.vel.dot(normal);
            if (vn < 0) { runtime.state.ship.vel -= normal * 2.0 * vn; runtime.state.ship.vel *= c.bounce_keep; }
            if (enemy.hit_cd <= 0) {
                enemy.hit_cd = 0.25;
                Dictionary event; event["pos"] = position; event["normal"] = normal; event["enemy_pos"] = enemy.pos; event["r"] = enemy.radius;
                emit_event("block_impact", event);
            }
            runtime.state.ship_pos = runtime.state.ship.pos;
            return true;
        }
        if (!runtime.state.draw.tracing && enemy.hit_cd > 0 && !runtime.state.field.rock_handles.contains(enemy.rock)) continue;
        const bool rear = def.kind==speed::EnemyDefinition::Kind::Shield?speed::ShieldBehavior::rear_open(runtime,runtime.state.enemy_handles.at(uint32_t(hit.row)),position):std::abs(angle_difference((position - enemy.pos).angle(), enemy.facing + godot::Math::PI)) <= def.weak_arc;
        const bool crit = (def.weak_arc > 0 && rear) || runtime.state.control.rng.randf() < c.crit_chance;
        if (enemy.stone > 0) {
            enemy.hit_cd = c.contact_cooldown;
            if (runtime.state.draw.tracing) runtime.state.draw.inside[enemy.id] = hit.row;
            Dictionary event; event["pos"] = enemy.pos; event["normal"] = -direction;
            event["enemy_pos"] = enemy.pos; event["r"] = enemy.radius; emit_event("block_impact", event);
            kill_enemy(hit.row, false, fast ? StringName("ram") : StringName("touch"), direction);
            continue;
        }
        if (speed::FieldSystem::contact_rock(*this,uint32_t(hit.row),direction,from,speed)) continue;
        if (!fast && runtime.state.field.rock_handles.contains(enemy.rock)) {
            Vector2 normal=position-enemy.pos;normal=normal.length_squared()>0?normal.normalized():-direction;
            runtime.state.ship.pos=enemy.pos+normal*(enemy.radius+radius+1.0);
            const double vn=runtime.state.ship.vel.dot(normal);
            if (vn<0) {runtime.state.ship.vel-=normal*2.0*vn;runtime.state.ship.vel*=c.bounce_keep;}
            if (enemy.hit_cd<=0) {
                enemy.hit_cd=0.25;Dictionary impact;impact["pos"]=position;impact["normal"]=normal;impact["enemy_pos"]=enemy.pos;impact["r"]=enemy.radius;emit_event("block_impact",impact);
                damage_enemy(hit.row,attack*0.25,"bump",false,-normal);
            }
            continue;
        }
        if (!fast) {
            enemy.hit_cd = c.contact_cooldown;
            damage_enemy(hit.row, attack * c.touch_damage, "touch", false, direction, 160.0, &position);
            continue;
        }
        speed::DamageRequest gate_request;gate_request.struck=runtime.state.enemy_handles.at(uint32_t(hit.row));gate_request.cause=speed::Cause::Ram;gate_request.direction=direction;gate_request.impact=position;gate_request.has_impact=true;
        const auto gate=speed::CombatResolver::gate(runtime,gate_request.struck,gate_request);
        if (gate==speed::GateResult::Pass) {enemy.hit_cd=c.contact_cooldown;if (runtime.state.draw.tracing) runtime.state.draw.inside[enemy.id]=hit.row;continue;}
        if (gate==speed::GateResult::Allow && (runtime.state.loadout.effects.ignore_armor || attack >= enemy.armor * (crit ? c.crit_armor : 1.0))) {
            double damage = attack * (crit ? c.crit_mult : 1.0);
            if (def.kind == speed::EnemyDefinition::Kind::Shield && rear) {
                speed::ShieldBehavior::steal(runtime,runtime.state.enemy_handles.at(uint32_t(hit.row)));
                damage = std::max(damage, enemy.hp);
            }
            speed::DamageRequest request;request.struck=runtime.state.enemy_handles.at(uint32_t(hit.row));request.amount=damage;request.cause=speed::Cause::Ram;request.crit=crit;request.direction=direction;request.impact=position;request.has_impact=true;
            const auto result=speed::CombatResolver::damage_enemy(runtime,request);speed::EventBuilder::flush_combat(runtime);
            enemy.hit_cd = c.contact_cooldown;
            if (runtime.state.draw.tracing) {
                runtime.state.draw.inside[enemy.id] = hit.row;
                const int64_t passes = ++runtime.state.draw.passes[enemy.id];
                if (passes > 1) {
                    Dictionary text; text["pos"] = enemy.pos + Vector2(enemy.radius, -enemy.radius - 16.0);
                    text["text"] = String::utf8("×") + String::num_int64(passes);
                    text["color"] = crit ? Color::html("ffe46b") : Color(1, 1, 1, 1);
                    text["size"] = 22 + 4 * std::min(int64_t(5), passes); emit_event("text", text);
                }
            }
            if (!runtime.state.ship.glide && !runtime.state.draw.tracing) {
                const double loss = enemy.dead ? (0.004 + enemy.radius * 0.0006) : (0.1 + enemy.radius * 0.002);
                runtime.state.ship.vel *= 1.0 - std::min(0.6, loss);
            }
            speed::RunUpBehavior::contact(runtime,position,direction,result.applied);
            continue;
        }
        runtime.state.ship.glide = false;
        Vector2 normal = position - enemy.pos;
        normal = normal.length_squared() > 0 ? normal.normalized() : -direction;
        Dictionary impact; impact["pos"] = position; impact["normal"] = normal; impact["enemy_pos"] = enemy.pos; impact["r"] = enemy.radius;
        emit_event("block_impact", impact);
        runtime.state.ship.pos = enemy.pos + normal * (enemy.radius + runtime.state.ship_config.ship_radius + 1.0);
        const double vn = runtime.state.ship.vel.dot(normal);
        if (vn < 0) runtime.state.ship.vel -= normal * 2.0 * vn;
        runtime.state.ship.vel *= c.bounce_keep;
        if (runtime.state.ship.vel.length() < c.bounce_min_speed) runtime.state.ship.vel = normal * c.bounce_min_speed;
        runtime.state.ship.boost_t = 0;
        if (gate==speed::GateResult::Allow) damage_enemy(hit.row, attack * 0.25, "bump", crit, -normal);
        enemy.hit_cd = 0.25;
        speed::RunUpBehavior::contact(runtime,position,direction,0);
        Dictionary bounce; bounce["pos"] = runtime.state.ship.pos; emit_event("bounce", bounce);
        runtime.state.ship_pos = runtime.state.ship.pos;
        return true;
    }
    runtime.state.ship_pos = runtime.state.ship.pos;
    return false;
}
