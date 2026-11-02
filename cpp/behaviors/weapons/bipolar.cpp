#include "bipolar.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/collision_query.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/equipment.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include <algorithm>
namespace speed {
namespace {
void fire(RunRuntime &r,const BipolarPending &p) {
    auto &s=r.state;auto &w=s.loadout.bipolar;const auto direction=(p.to-p.from).normalized();
    const double width=w.width*s.loadout.effects.area*(1+w.area_increment*double(s.loadout.post_area_stacks));const godot::Vector2 pad(width/2,width/2);
    const double damage=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage;
    for (auto row:CollisionQuery::enemy_rows(s,p.from.min(p.to)-pad,p.from.max(p.to)+pad)) {
        const auto &e=s.enemies[row];if (e.dead || CollisionQuery::segment_circle_t(p.from,p.to,e.pos,e.radius+width/2)<0) continue;
        DamageRequest request;request.struck=s.enemy_handles.at(uint32_t(row));request.amount=damage;request.cause=Cause::Bipolar;request.direction=direction;request.knock=w.knock*(1+w.knockback_increment*double(s.loadout.post_knockback_stacks));request.weapon_id=w.definition;CombatResolver::damage_enemy(r,request);if (s.phase!=godot::RunState::Phase::Play) return;
    }
    EventBuilder::flush_combat(r);const double scale=w.radius_factor*s.loadout.effects.area;w.beams.push_back({p.from,p.to,p.id,0,scale});
    godot::Dictionary beam;beam["from"]=p.from;beam["to"]=p.to;beam["width"]=width;beam["color"]=godot::Color::hex(w.color);beam["life"]=w.life;beam["width_scale"]=scale;beam["visual_key"]="weapon/bipolar";FrameBuilder::append(r,"beam",beam);
    for (auto position:{p.from,p.to}) {godot::Dictionary ring;ring["pos"]=position;ring["radius"]=65.0;ring["color"]=godot::Color::hex(w.color);ring["life"]=w.life;ring["visual_key"]="weapon/bipolar";FrameBuilder::append(r,"ring",ring);}
}
}
void BipolarBehavior::launch(RunRuntime &r) {auto &w=r.state.loadout.bipolar;if (!w.ready) return;w.origin=r.state.ship.pos;w.active=true;w.started=r.state.world_time;}
void BipolarBehavior::end(RunRuntime &r) {auto &w=r.state.loadout.bipolar;if (!w.ready || !w.active) return;w.active=false;const auto to=r.state.ship.pos;if (w.origin.distance_to(to)<=w.min_length) return;w.pending.push_back({w.origin,to,w.next_id++,w.delay});godot::Dictionary e;e["from"]=w.origin;e["to"]=to;FrameBuilder::append(r,"bipolar_charge",e);}
void BipolarBehavior::step(RunRuntime &r,double dt) {auto &w=r.state.loadout.bipolar;if (!w.ready || dt<=0) return;for (auto &v:w.beams) v.age+=dt;w.beams.erase(std::remove_if(w.beams.begin(),w.beams.end(),[&](const auto &v){return v.age>=w.visual_life;}),w.beams.end());for (auto &p:w.pending) {p.delay-=dt;if (p.delay<=0) fire(r,p);}w.pending.erase(std::remove_if(w.pending.begin(),w.pending.end(),[](const auto &p){return p.delay<=0;}),w.pending.end());}
}
