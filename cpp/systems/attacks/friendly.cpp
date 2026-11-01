#include "../attack_system.h"
#include "../collision_query.h"
#include "../combat_resolver.h"
#include "../field.h"
#include "../../runtime/run_runtime.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include "reflected.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
using namespace godot;
bool AttackSystem::step_friendly(RunRuntime &runtime,double world_dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.combat_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    struct Hit { double time; size_t row; };
    struct Earlier { bool operator()(const Hit &a, const Hit &b) const { return a.time < b.time; } };
    std::vector<Hit> hits;
    // 命中で末尾へ増えた弾は同じ更新で進め、既に通った空き行は次回に進める。
    for (size_t i = 0; i < runtime.state.friends.size(); ++i) {
        auto &shot = runtime.state.friends[i];
        if (!shot.alive) continue;
        const auto processing_handle=shot.attack;
        const Vector2 from = shot.pos, vel = shot.vel, destination = from + vel * world_dt;
        auto body_hit=speed::FieldSystem::first_body_hit(runtime,from,destination,shot.radius);
        const Vector2 to=body_hit?body_hit->point:destination;
        Vector2 position = destination;
        double life = double(shot.life) - world_dt;
        auto end_reason=speed::AttackEndReason::Lifetime;
        shot.age = double(shot.age) + world_dt;
        shot.angle = double(shot.angle) + double(shot.spin) * world_dt;
        if (shot.kind == 1 && shot.visual != StringName("weapon/knockback")) {
            shot.trail.append(destination);
            if (shot.trail.size() > runtime.state.projectile_config.trail_points) shot.trail.remove_at(0);
        }
        const double padding = double(shot.radius) + std::max(runtime.state.combat_config.max_enemy_radius, runtime.state.grid.max_radius);
        const Vector2 pad(padding, padding);
        hits.clear();
        for (size_t row : CollisionQuery::enemy_rows(runtime.state,from.min(to) - pad, from.max(to) + pad)) {
            const auto &enemy = runtime.state.enemies[row];
            const auto target=CombatResolver::damage_target(runtime,runtime.state.enemy_handles.at(uint32_t(row)));
            if (!runtime.state.enemy_handles.contains(target) || shot.hit_ids.count(runtime.state.enemy_handles.entity_id(target))) continue;
            const double t = speed::CollisionQuery::segment_circle_t(from, to, enemy.pos, double(shot.radius) + enemy.radius);
            if (t >= 0) hits.push_back({t, row});
        }
        SortArray<Hit, Earlier>().sort(hits.data(), hits.size());
        const double speed = vel.length();
        for (const auto &hit : hits) {
            const auto &enemy = runtime.state.enemies[hit.row];
            const auto struck=runtime.state.enemy_handles.at(uint32_t(hit.row));
            const auto target=CombatResolver::damage_target(runtime,struck);
            if (life<=0 || enemy.dead || !runtime.state.enemy_handles.contains(target) || shot.hit_ids.count(runtime.state.enemy_handles.entity_id(target))) continue;
            const Vector2 impact = from.lerp(to, hit.time);
            DamageRequest request;request.struck=struck;request.amount=shot.damage;request.direction=speed>0?vel/speed:Vector2();request.knock=shot.knock;
            request.impact=impact;request.has_impact=true;request.no_crit=shot.no_crit;
            if (const auto *record=get(runtime.state,processing_handle)) {request.cause=record->spec.cause;request.weapon_id=record->spec.weapon;}else break;
            if (shot.kind==int64_t(FriendKind::Shot) && !CombatResolver::allows_hit(runtime,struck,request)) {
                speed::ReflectedSystem::reflect(runtime,runtime.state.enemy_handles.at(uint32_t(hit.row)),impact,vel,shot.radius);
                position = impact;life = 0;body_hit.reset();end_reason=speed::AttackEndReason::Hit;break;
            }
            shot.hit_ids.insert(runtime.state.enemy_handles.entity_id(target));
            CombatResolver::damage_enemy(runtime,request);EventBuilder::flush_combat(runtime);
            if (!speed::AttackSystem::get(runtime.state,processing_handle)) break;
            Dictionary event; event["pos"] = impact; event["dir"] = vel.normalized();
            event["visual_key"] = String(shot.visual); event["kind"] = shot.kind;
            FrameBuilder::append(runtime,"shot_hit",event);
            if (runtime.state.phase != godot::RunState::Phase::Play) { shot.pos=position;shot.life=life;return true; }
            if (!shot.pierce) { if (shot.pierce_left > 0) --shot.pierce_left; else {life=0;end_reason=speed::AttackEndReason::Hit;} }
        }
        if (!speed::AttackSystem::get(runtime.state,processing_handle)) continue;
        if (body_hit) {
            position=body_hit->point;life=0;end_reason=speed::AttackEndReason::Hit;
            Dictionary event;event["pos"]=position;event["radius"]=22.0;event["color"]=Color::html("ffd19a");event["life"]=0.18;FrameBuilder::append(runtime,"ring",event);
        }
        shot.pos = position; shot.life = life;
        if (life <= 0) {
            if (shot.kind == 1) {
                if (shot.visual != StringName("weapon/knockback") && shot.trail.size() > 1) {
                    Dictionary ended; ended["points"] = shot.trail; ended["color"] = shot.color;
                    FrameBuilder::append(runtime,"debris_trail",ended);
                }
            }
            speed::AttackSystem::end(runtime.state,processing_handle,end_reason);
        }
    }
    return true;
}

}
