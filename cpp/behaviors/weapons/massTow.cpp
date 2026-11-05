#include "massTow.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attacks/friend_hull.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/equipment.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
bool MassTowBehavior::capture(RunRuntime &r,const DeathContext &death) {
    auto &s=r.state;auto &w=s.loadout->mass_tow;const auto &e=death.corpse;
    if (!w.ready || !s.draw.tracing || e.is_boss || r.content->definitions[e.definition-1].kind==EnemyDefinition::Kind::Meteor || s.ship.pos.distance_squared_to(e.pos)>std::pow(w.capture_radius*(1+w.area_increment*double(s.loadout->post_area_stacks))+e.radius,2)) return false;
    w.cargo.push_back({e.pos,e.pos-s.ship.pos,e.radius,e.facing,e.definition,e.id,false});
    godot::Dictionary event;event["id"]=e.id;event["pos"]=e.pos;event["to"]=s.ship.pos-s.ship.heading*70;FrameBuilder::append(r,"anchor_capture",event);return true;
}
void MassTowBehavior::end(RunRuntime &r) {auto &w=r.state.loadout->mass_tow;if (!w.ready) return;for (auto &c:w.cargo) c.ready=true;w.fire.remaining=w.hold;}
void MassTowBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &w=s.loadout->mass_tow;if (!w.ready || dt<=0 || w.cargo.empty()) return;
    const auto u=s.ship.vel.length()>1?s.ship.vel.normalized():s.ship.heading;const size_t count=std::min(size_t(w.visible),w.cargo.size());
    const auto center=-u*(70+w.clump_spacing*std::sqrt(double(count))*0.6);const double follow=1-std::exp(-w.follow*dt);
    for (size_t j=0;j<w.cargo.size();++j) {auto &c=w.cargo[j];c.angle+=dt*(j%2?-0.6:0.6);auto target=center;
        if (j<count) target+=godot::Vector2::from_angle(j*2.39996323)*w.clump_spacing*0.6*std::sqrt(double(j))+godot::Vector2(std::sin(s.time*2+j),std::cos(s.time*1.7+j*1.3))*5;
        c.relative+=(target-c.relative)*follow;c.pos=s.ship.pos+c.relative;
    }
    w.fire.advance(dt);const double floor=std::min(w.interval,std::max(w.minimum_interval,w.interval*w.minimum_ratio));const double interval=std::max(floor,w.interval*(1-w.interval_increment*double(s.loadout->post_weapon_interval_stacks)));
    while (w.fire.due() && !w.cargo.empty() && w.cargo.front().ready) {
        const auto c=w.cargo.front();w.cargo.erase(w.cargo.begin());const auto direction=s.ship.heading;
        FriendHullParams p;p.position=c.pos;p.velocity=direction*w.shot_speed*(1+w.projectile_increment*double(s.loadout->post_projectile_speed_stacks));p.radius=c.radius*s.loadout->effects.area;p.damage=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage*std::max(1.0,c.radius/w.size_ref);p.life=w.life*(1+w.duration_increment*double(s.loadout->post_duration_stacks));p.knock=w.knock*(1+w.knockback_increment*double(s.loadout->post_knockback_stacks));p.source_definition=c.definition;p.source_id=c.source_id;p.angle=direction.angle();FriendHullSystem::emit(r,p);
        godot::Dictionary event;event["pos"]=c.pos;event["dir"]=direction;event["radius"]=c.radius;FrameBuilder::append(r,"anchor_fire",event);w.fire.fired(interval);
    }
    if (w.cargo.empty() || !w.cargo.front().ready) w.fire.remaining=0;
}
void MassTowBehavior::render(const RunRuntime &r,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &w=r.state.loadout->mass_tow;if (!w.ready) return;
    for (size_t i=0;i<std::min(size_t(w.visible),w.cargo.size());++i) {const auto &c=w.cargo[i];if (!view.grow(c.radius*2).has_point(c.pos)) continue;const auto look=std::find_if(r.content->hull_looks.begin(),r.content->hull_looks.end(),[&](const auto &l){return l.enemy==c.definition;});if (look==r.content->hull_looks.end()) continue;
        Dictionary row;row["kind"]=int32_t(RenderShapeKind::FriendHull);row["owner_id"]=c.source_id;row["layer"]=14;row["order"]=int32_t(1000000+i);PackedVector2Array points;points.push_back(c.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(c.radius*look->scale);PackedColorArray colors;colors.push_back(Color(1,1,1,1));row["points"]=points;row["offsets"]=offsets;row["widths"]=widths;row["colors"]=colors;row["angle"]=look->angle+(look->fixed_angle?0:c.angle);row["saw"]=false;row["visual_id"]=int64_t(r.content->definitions[c.definition-1].visual_id);row["hull_points"]=PackedVector2Array();out.push_back(row);
    }
}
}
