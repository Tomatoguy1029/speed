#include "sonic.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/collision_query.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
void SonicBehavior::refresh(RunRuntime &r) {auto &w=r.state.loadout->sonic;w.wave_speed=w.base_speed*1.82*r.content->config.character_scale*r.state.loadout->effects.area*(1+w.area_increment*double(r.state.loadout->post_area_stacks));w.life=w.base_life*(1+w.duration_increment*double(r.state.loadout->post_duration_stacks));}
void SonicBehavior::launch(RunRuntime &r) {auto &w=r.state.loadout->sonic;if (!w.ready) return;w.active=true;w.hits.clear();w.last=r.state.ship.pos;w.distance=w.emission=0;}
// 1機ぶんの発射：pos・forward・vel から衝撃波の輪を出し、輪の重なった敵を押し出して遅れて当てる（輪・押し出し・見た目の一覧は共通）。
// moving は突進か滑空で動いている間。ふたご座の影は、自分の位置と発射の状態を入れ替えてこれを呼ぶ
void SonicBehavior::emit(RunRuntime &r,double dt,godot::Vector2 pos,godot::Vector2 forward,double velocity_length,bool moving,bool twin) {
    auto &s=r.state;auto &w=s.loadout->sonic;if (!w.ready || dt<=0) return;
    const double scale=1.82*r.content->config.character_scale;const auto side=godot::Vector2(forward.y,-forward.x);const double move=w.last.distance_to(pos);
    w.pulse=std::max(0.0,w.pulse-dt);w.speed=move/dt;moving=w.active && moving;
    if (moving && w.speed<=w.min_speed*scale) w.emission=0;
    else if (moving) {
        w.distance+=move;if (w.distance>=w.pulse_distance*scale) {w.distance=std::fmod(w.distance,w.pulse_distance*scale);w.pulse=w.pulse_time;EventBuilder::audio(r,"weapon.sonic_boom.ring",pos);}
        w.emission+=move;const double spacing=w.emit_spacing*scale;const auto nose=forward*w.nose*scale;
        while (w.emission>=spacing) {w.emission-=spacing;const double back=w.emission/std::max(move,0.001);w.frames.push_back({w.last.lerp(pos,1-back)+nose,back*dt,twin});}
    } else if (w.active) w.active=false;
    w.last=pos;
    if (w.pulse>0) {
        const double reach=w.wave_speed*w.life+velocity_length*w.life;const godot::Vector2 pad(reach+s.grid.max_radius,reach+s.grid.max_radius);bool damage_ready=false;double damage=0;
        for (auto row:CollisionQuery::enemy_rows(s,pos-pad,pos+pad)) {
            const auto &e=s.enemies[row];if (e.dead || w.hits.count(e.id)) continue;const auto relative=e.pos-pos;if (relative.dot(forward)>=0) continue;
            unsigned overlap=0;const double width=4*scale+e.radius;
            for (const auto &f:w.frames) {const double radius=w.wave_speed*f.age;if (radius<=2*scale) continue;const double inner=radius-width,outer=radius+width,dist=e.pos.distance_squared_to(f.pos);if (outer>0 && dist<outer*outer && (inner<0 || dist>inner*inner) && ++overlap>=3) break;}
            if (overlap<3) continue;w.hits.insert(e.id);
            if (!damage_ready) {damage=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage;damage_ready=true;}
            const double projection=relative.dot(side),sign=projection<0?-1.0:1.0;const auto velocity=(side*sign*w.side_speed-forward*w.back_speed)*scale;
            w.pending.push_back({s.enemy_handles.at(uint32_t(row)),e.id,w.damage_delay,0,damage,velocity,false});
            w.visuals.push_back({w.next_visual++,e.id,e.pos,velocity.normalized(),s.world_time,false,false});godot::Dictionary event;event["pos"]=e.pos;event["dir"]=velocity.normalized();event["row"]=int64_t(row);event["id"]=e.id;FrameBuilder::append(r,"sonic_push",event);
        }
    }
}
void SonicBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &w=s.loadout->sonic;if (!w.ready || dt<=0) return;
    for (auto &f:w.frames) f.age+=dt;w.frames.erase(std::remove_if(w.frames.begin(),w.frames.end(),[&](const auto &f){return f.age>=w.life;}),w.frames.end());
    w.visuals.erase(std::remove_if(w.visuals.begin(),w.visuals.end(),[&](const auto &v){return s.world_time-v.born>=(v.impact?0.26:0.07);}),w.visuals.end());
    emit(r,dt,s.ship.pos,s.ship.heading,s.ship.vel.length(),s.draw.tracing || s.ship.glide);
    const double decay=std::pow(w.decay,dt);
    for (auto &h:w.pending) {
        if (!s.enemy_handles.contains(h.target) || s.enemies[h.target.slot].dead) continue;h.age+=dt;auto &e=s.enemies[h.target.slot];const auto &d=r.content->definitions[e.definition];
        const double scale_knock=e.is_boss || (s.enemy_handles.contains(e.parent) && s.enemies[e.parent.slot].is_boss)?0:d.knockback;
        if (scale_knock>0) {e.pos+=h.velocity*dt*scale_knock;h.velocity*=decay;}
        if (!h.hit && h.age>=h.delay) {h.hit=true;DamageRequest request;request.struck=h.target;request.amount=h.damage;request.cause=Cause::Sonic;request.knock=0;CombatResolver::damage_enemy(r,request);
            EventBuilder::flush_combat(r);const auto &after=s.enemies[h.target.slot];const auto direction=h.velocity.normalized();w.visuals.push_back({w.next_visual++,h.id,after.pos,direction,s.world_time,true,after.dead});godot::Dictionary event;event["pos"]=after.pos;event["dir"]=direction;event["dead"]=after.dead;FrameBuilder::append(r,"sonic_impact",event);}
    }
    w.pending.erase(std::remove_if(w.pending.begin(),w.pending.end(),[&](const auto &h){return h.age>=0.7 || !s.enemy_handles.contains(h.target) || s.enemies[h.target.slot].dead;}),w.pending.end());EventBuilder::flush_combat(r);
}
}
