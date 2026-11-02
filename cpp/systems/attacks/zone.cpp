#include "zone.h"
#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
bool ZoneSystem::explode(RunRuntime &run,godot::Vector2 center,double radius,double damage,Cause cause,double knock,double life,const godot::Color &color,bool no_crit) {
    const double reach=radius+std::max(run.state.combat_config.max_enemy_radius,run.state.grid.max_radius);
    const auto rows=CollisionQuery::enemy_rows(run.state,center-godot::Vector2(reach,reach),center+godot::Vector2(reach,reach));
    std::vector<EnemyHandle> targets;targets.reserve(rows.size());
    for (auto row:rows) targets.push_back(run.state.enemy_handles.at(uint32_t(row)));
    for (auto target:targets) {
        if (!run.state.enemy_handles.contains(target)) continue;
        const auto &enemy=run.state.enemies[target.slot];if (!enemy.alive || enemy.dead) continue;
        const auto delta=enemy.pos-center;if (delta.length_squared()>(radius+enemy.radius)*(radius+enemy.radius)) continue;
        DamageRequest request;request.struck=target;request.amount=damage;request.cause=cause;request.knock=knock;request.no_crit=no_crit;
        request.direction=delta.length_squared()>0?delta.normalized():godot::Vector2();
        CombatResolver::damage_enemy(run,request);
        if (run.state.phase!=godot::RunState::Phase::Play) return false;
    }
    EventBuilder::flush_combat(run);godot::Dictionary event;event["pos"]=center;event["radius"]=radius;event["cause"]=symbol_name(cause);event["color"]=color;event["life"]=life;FrameBuilder::append(run,"explode",event);
    return true;
}
const char *ZoneSystem::scene(uint32_t style) {
    static const char *paths[]={"res://scenes/attacks/zone.tscn","res://scenes/attacks/zone_reticle.tscn","res://scenes/attacks/zone_lightning.tscn","res://scenes/attacks/zone_bite.tscn","res://scenes/attacks/zone_aquila.tscn","res://scenes/attacks/zone_phoenix.tscn","res://scenes/attacks/zone_bomber.tscn","res://scenes/attacks/zone_pump.tscn"};
    return style<uint32_t(ZoneStyle::Count)?paths[style]:"";
}
AttackHandle ZoneSystem::emit(RunRuntime &run,const ZoneParams &p) {
    if (p.style>=ZoneStyle::Count || !std::isfinite(p.enemy_damage) || p.enemy_damage<0) return {};
    const auto found=std::find_if(run.content->zones.begin(),run.content->zones.end(),[&](const auto &d){return d.style==uint32_t(p.style);});
    if (found==run.content->zones.end()) return {};
    BlastParams blast;blast.position=p.position;blast.color=p.color;blast.source=p.owner;blast.attached=p.attached;blast.budget=p.budget;
    blast.source_id=p.source_id;blast.source_definition=p.source_definition;blast.radius=p.radius;blast.damage=p.damage;blast.delay=p.delay;blast.duration=found->active;blast.contact=found->contact;
    const auto handle=BlastSystem::emit(run,blast);const auto *record=AttackSystem::get(run.state,handle);if (!record) return {};
    auto &hazard=run.state.hazards[record->row];hazard.zone_definition=found->id;hazard.enemy_damage=p.enemy_damage;return handle;
}
bool ZoneSystem::activate(RunRuntime &run,AttackHandle handle) {
    const auto *record=AttackSystem::get(run.state,handle);if (!record) return true;
    const auto hazard=run.state.hazards[record->row];run.state.hazards[record->row].hit=true;
    if (hazard.enemy_damage<=0) return true;
    const double radius=std::get<CircleHazard>(hazard.shape).radius;
    const double padding=std::max(run.state.combat_config.max_enemy_radius,run.state.grid.max_radius),reach=radius+padding;
    const auto rows=CollisionQuery::enemy_rows(run.state,hazard.pos-godot::Vector2(reach,reach),hazard.pos+godot::Vector2(reach,reach));
    std::vector<EnemyHandle> targets;targets.reserve(rows.size());
    for (auto row:rows) targets.push_back(run.state.enemy_handles.at(uint32_t(row)));
    for (auto target:targets) {
        if (!run.state.enemy_handles.contains(target)) continue;
        const auto &enemy=run.state.enemies[target.slot];if (!enemy.alive || enemy.dead) continue;
        const auto delta=enemy.pos-hazard.pos;if (delta.length_squared()>(radius+enemy.radius)*(radius+enemy.radius)) continue;
        DamageRequest request;request.struck=target;request.amount=hazard.enemy_damage;
        request.direction=delta.length_squared()>0?delta.normalized():godot::Vector2();request.cause=Cause::Chain;request.no_crit=true;request.knock=300;
        CombatResolver::damage_enemy(run,request);
        if (run.state.phase!=godot::RunState::Phase::Play) return false;
    }
    EventBuilder::flush_combat(run);godot::Dictionary event;event["pos"]=hazard.pos;event["radius"]=radius;event["cause"]="chain";event["color"]=hazard.color;event["life"]=0.3;FrameBuilder::append(run,"explode",event);
    return true;
}
void ZoneSystem::end_visual(RunRuntime &run,uint32_t id,bool hit,godot::Vector2 position) {
    if (!id || id>run.content->zones.size()) return;const auto &d=run.content->zones[id-1];if (!(hit?d.hit:d.fade)) return;
    godot::Dictionary event;event["scene"]=scene(d.style);event["phase"]=hit?"Hit":"Fade";event["pos"]=position;event["duration"]=hit?d.hit_duration:d.fade_duration;event["tint"]=godot::Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a);FrameBuilder::append(run,"attack_visual_end",event);
}
void ZoneSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &h=run.state.hazards[row];if (!h.alive || !h.zone_definition) return;
    const auto &d=run.content->zones[h.zone_definition-1];const double radius=std::get<CircleHazard>(h.shape).radius;
    if (!view.grow(radius*3).has_point(h.pos)) return;const auto *record=AttackSystem::get(run.state,h.attack);if (!record) return;
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Zone);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;points.push_back(h.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(radius);PackedColorArray colors;colors.push_back(h.color);
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["time"]=double(h.time);shape["delay"]=double(h.delay);shape["active"]=double(h.duration);shape["zone_style"]=d.style;
    shape["tint"]=Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a);shape["glow_opacity"]=d.glow_opacity;shape["ring_opacity"]=d.ring_opacity;shape["ring_width"]=d.ring_width;shape["arm_count"]=int32_t(d.arm_count);shape["lightning_reach"]=d.lightning_reach;shape["lightning_width"]=d.lightning_width;out.push_back(shape);
}
}
