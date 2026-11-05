#include "friend_debris.h"
#include "../attack_system.h"
#include "../motion_math.h"
#include "../../behaviors/traits/duplicator.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
FriendDebrisDefinition settings(const RunRuntime &run) {
    if (!run.content->friend_debris.empty()) return run.content->friend_debris.front();
    FriendDebrisDefinition d;d.life=run.state.projectile_config.debris_life;d.knock=run.state.projectile_config.debris_knock;d.trail_points=run.state.projectile_config.trail_points;d.maximum=200;d.character_scale=1;return d;
}
bool trails(const godot::RunState::Friendly &s) {return s.visual!=godot::StringName("weapon/knockback") && s.visual!=godot::StringName("enemy/pump_burst");}
}
AttackHandle FriendDebrisSystem::emit(RunRuntime &run,godot::RunState::Friendly shot,int64_t source_id) {
    if (!run.state.started || run.state.closed || !run.state.combat_ready || !run.state.projectile_config.ready || !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.damage) || shot.damage<0 || shot.shatter_depth<0) return {};
    for (double v:{shot.radius,shot.life,shot.knock}) if (!std::isfinite(v) || v<0) return {};
    if (!std::isfinite(shot.angle) || !std::isfinite(shot.spin)) return {};
    shot.kind=int64_t(FriendKind::Debris);shot.pierce=true;
    shot.debris.style=shot.visual==godot::StringName("weapon/knockback")?DebrisStyle::Stardust:shot.visual==godot::StringName("enemy/pump_burst")?DebrisStyle::Pump:DebrisStyle::Plain;
    AttackSpec spec;spec.policies=policy(EndPolicy::NaturalLifetime);spec.owner.source_id=std::max(int64_t(0),source_id);
    if (!parse_symbol(godot::String(shot.cause).utf8().get_data(),spec.cause)) return {};
    for (const auto &weapon:run.content->equipment) if (weapon.kind==0 && shot.weapon_id==godot::StringName(weapon.external_id.c_str())) {spec.weapon=weapon.id;break;}
    if (!run.content->friend_debris.empty()) {shot.debris.definition=1;if (!AttackSystem::configure_contact(*run.content,run.content->friend_debris.front().contact,spec)) return {};}
    else if (run.api_configured) return {};
    return AttackSystem::emit_friendly(run,std::move(shot),spec);
}
bool FriendDebrisSystem::burst(RunRuntime &run,const DebrisBurstParams &p) {
    if (!p.position.is_finite() || p.count<0 || p.count>INT32_MAX || !std::isfinite(float(p.speed)) || p.speed<0 || !std::isfinite(p.damage) || p.damage<0) return false;
    for (float v:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(v)) return false;
    if (!run.state.started || run.state.closed || !run.state.projectile_config.ready) return false;
    const auto d=settings(run);FriendlyBirthScope births(run);
    for (int64_t k=0;k<p.count;++k) {
        const auto u=godot::Vector2::from_angle(godot::Math::TAU*k/double(p.count)+run.state.control.rng.randf()*0.4);
        godot::RunState::Friendly s;s.cause="hullDebris";s.pos=p.position+u*10.0;s.vel=u*p.speed*(0.8+0.3*run.state.control.rng.randf());
        s.radius=12;s.life=d.life;s.damage=p.damage;s.knock=d.knock;s.no_crit=true;s.color=p.color;
        s.angle=run.state.control.rng.randf()*godot::Math::TAU;s.spin=k%2==0?10:-10;if (p.source_id!=-1) s.hit_ids.insert(p.source_id);
        if (p.armor_count>=0) {s.visual="enemy/pump_burst";s.type=k<p.armor_count?"pump":((k-p.armor_count)%3==0?"drifter":(k-p.armor_count)%3==1?"swarm":"splitling");}
        if (!AttackSystem::get(run.state,emit(run,std::move(s),p.source_id))) return false;
    }
    godot::Dictionary event;event["pos"]=p.position;event["count"]=p.count;FrameBuilder::append(run,"hull_scatter",event);return true;
}
bool FriendDebrisSystem::scatter(RunRuntime &run,const DebrisScatterParams &p) {
    auto &state=run.state;if (!state.enemy_handles.contains(p.source) || !p.direction.is_finite() || p.shatter_depth<0 || !std::isfinite(p.damage) || p.damage<0 || !std::isfinite(p.knock)) return false;
    for (double v:{p.speed,p.radius_mult,p.life_mult}) if (!std::isfinite(float(v)) || v<0) return false;
    auto &enemy=state.enemies[p.source.slot];const auto &definition=run.content->definitions[enemy.definition];if (enemy.is_boss || state.field.rock_handles.contains(enemy.rock)) return false;
    enemy.hull_scattered=true;const auto d=settings(run);const int64_t count=std::min(std::min(int64_t(16),std::max(int64_t(2),definition.rank*2)),int64_t(d.maximum)-int64_t(state.live_debris));if (count<=0) return false;
    const bool directed=p.direction.length()>0.01;const double base=directed?p.direction.angle():enemy.facing,spread=directed?d.spread:godot::Math::TAU;
    FriendlyBirthScope births(run);
    for (int64_t k=0;k<count;++k) {
        double angle=base+(directed?(count>1?double(k)/(count-1)-0.5:0.0):double(k)/count)*spread;angle+=(state.control.rng.randf()-0.5)*0.25;
        const auto u=godot::Vector2::from_angle(angle);const double speed=p.speed*(0.7+0.6*state.control.rng.randf());
        godot::RunState::Friendly s;s.cause="hullDebris";s.pos=enemy.pos+u*enemy.radius*0.3;s.vel=u*speed;s.radius=4.0*1.82*d.character_scale*p.radius_mult;
        s.life=d.life*p.life_mult;s.damage=p.damage;s.color=definition.color;s.no_crit=true;s.knock=p.knock<0?d.knock:p.knock;
        s.angle=state.control.rng.randf()*godot::Math::TAU;s.spin=k%2==0?10:-10;s.hit_ids.insert(enemy.id);s.visual="weapon/knockback";s.weapon_id="W03";s.shatter_depth=p.shatter_depth;
        if (!AttackSystem::get(state,emit(run,std::move(s),enemy.id))) return false;
    }
    godot::Dictionary event;event["pos"]=enemy.pos;event["count"]=count;if (run.api_configured) event["visual_key"]="weapon/knockback";FrameBuilder::append(run,"hull_scatter",event);return true;
}
bool FriendDebrisSystem::fling(RunRuntime &run,const DebrisFlingParams &p) {
    if (!run.state.enemy_handles.contains(p.source) || !p.velocity.is_finite() || !std::isfinite(p.damage) || p.damage<0) return false;
    for (double v:{p.radius_mult,p.knock_mult,p.life_mult}) if (!std::isfinite(float(v)) || v<0) return false;
    const auto &e=run.state.enemies[p.source.slot];godot::RunState::Friendly s;s.cause="corpse";s.pos=e.pos;s.vel=p.velocity;s.radius=std::max(10.0,e.radius*0.6)*p.radius_mult;
    s.damage=p.damage;s.life=0.9*p.life_mult;s.color=run.content->definitions[e.definition].color;s.no_crit=true;s.knock=250*p.knock_mult;
    s.angle=run.state.control.rng.randf()*godot::Math::TAU;s.spin=10;s.hit_ids.insert(e.id);s.visual="weapon/knockback";return AttackSystem::get(run.state,emit(run,std::move(s),e.id));
}
void FriendDebrisSystem::advance(const RunRuntime &run,godot::RunState::Friendly &s,godot::Vector2 destination) {
    if (!trails(s)) return;s.trail.push_back(destination);if (s.trail.size()>settings(run).trail_points) s.trail.remove_at(0);
}
void FriendDebrisSystem::finish(RunRuntime &run,const godot::RunState::Friendly &s) {
    if (!trails(s) || s.trail.size()<2) return;godot::Dictionary event;event["points"]=s.trail;event["color"]=s.color;
    if (run.api_configured) event["life"]=settings(run).trail_life;FrameBuilder::append(run,"debris_trail",event);
}
void FriendDebrisSystem::development_death(RunRuntime &run,const DeathContext &death) {
    if (!run.api_development) return;auto &sources=run.state.attacks.development_debris_sources;const auto found=sources.find(death.corpse.id);if (found==sources.end()) return;
    const auto fixture=found->second;sources.erase(found);DebrisBurstParams p;p.position=death.corpse.pos;p.source_id=death.corpse.id;p.count=fixture.count;p.speed=fixture.speed;p.damage=fixture.damage;p.color=run.content->definitions[death.corpse.definition-1].color;burst(run,p);
}
void FriendDebrisSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out,double alpha) {
    using namespace godot;const auto &s=run.state.friends[row];if (!s.alive || s.kind!=int64_t(FriendKind::Debris) || !view.grow(s.radius+150).has_point(s.pos)) return;
    const auto *record=AttackSystem::get(run.state,s.attack);if (!record) return;const auto d=settings(run);
    Vector2 position=s.pos;double angle=s.angle;const auto &previous=run.state.previous_poses;
    if (previous.ready && row<previous.friendly.size() && previous.friendly[row].id==s.id) {
        position=previous.friendly[row].position.lerp(s.pos,alpha);angle=previous.friendly[row].angle+angle_difference(double(s.angle)-previous.friendly[row].angle)*alpha;
    }
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::FriendDebris);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array p;p.push_back(position);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(s.radius);PackedColorArray colors;colors.push_back(Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a));
    shape["points"]=p;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["angle"]=angle;shape["age"]=double(s.age);shape["life"]=double(s.life);shape["clock"]=run.state.world_time;
    shape["velocity"]=s.vel;shape["trail"]=s.trail;shape["debris_style"]=int32_t(s.debris.style);shape["trail_width"]=d.trail_width;shape["pump_kind"]=s.type==StringName("pump")?-1:s.type==StringName("swarm")?1:s.type==StringName("splitling")?2:0;out.push_back(shape);
}
}
