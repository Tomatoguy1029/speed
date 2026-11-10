#include "interceptor.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/collision_query.h"
#include "../../systems/motion_math.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/friend_shot.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
void InterceptorBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &w=s.loadout->interceptor;if (!w.ready || dt<=0) return;w.clock+=dt;
    for (auto i=w.target_after.begin();i!=w.target_after.end();) {if (i->second<=w.clock) i=w.target_after.erase(i);else ++i;}
    const auto interval=[&](double base){const double floor=std::min(base,std::max(w.minimum_interval,base*w.minimum_ratio));return std::max(floor,base*(1-w.interval_increment*double(s.loadout->post_weapon_interval_stacks)));};
    while (w.drones.size()<w.count) {InterceptorDrone d;d.pos=s.ship.pos;d.next=w.clock+w.drones.size()*interval(w.interval)/w.count;w.drones.push_back(d);}
    bool candidates_ready=false;std::vector<size_t> candidates;
    const auto nearest=[&](godot::Vector2 from) {
        if (!candidates_ready) {const godot::Vector2 pad(w.range,w.range);candidates=CollisionQuery::enemy_rows(s,s.ship.pos-pad,s.ship.pos+pad);candidates_ready=true;}
        EnemyHandle best;double score=std::numeric_limits<double>::infinity();
        for (auto row:candidates) {const auto &e=s.enemies[row];if (e.dead || r.content->definitions[e.definition].kind==EnemyDefinition::Kind::Meteor || w.target_after.count(e.id) || e.pos.distance_squared_to(s.ship.pos)>w.range*w.range) continue;const double value=e.pos.distance_squared_to(from)+((e.is_boss || s.enemy_handles.contains(e.parent))?w.range*w.range:0);if (value<score) {score=value;best=s.enemy_handles.at(uint32_t(row));}}
        return best;
    };
    for (size_t i=0;i<w.drones.size();++i) {auto &d=w.drones[i];const double angle=w.clock*w.orbit_speed+i*6.283185307179586/w.drones.size();d.pos=s.ship.pos+godot::Vector2::from_angle(angle)*w.orbit-godot::Vector2::from_angle(d.angle)*d.kick;d.kick=std::max(0.0,d.kick-dt*12*1.82*r.content->config.character_scale);d.flash=std::max(0.0,d.flash-dt);
        const auto aim=d.left && s.enemy_handles.contains(d.target)?d.target:nearest(d.pos);if (s.enemy_handles.contains(aim)) d.angle+=angle_difference((s.enemies[aim.slot].pos-d.pos).angle()-d.angle)*std::min(dt*14,1.0);
        if (s.draw.drawing || s.draw.tracing || w.clock<d.next) continue;
        EnemyHandle target;if (!d.left) {target=aim;if (!s.enemy_handles.contains(target)) continue;d.left=w.burst;}else if (s.enemy_handles.contains(d.target) && !s.enemies[d.target.slot].dead) target=d.target;else target=nearest(d.pos);
        if (s.enemy_handles.contains(target)) {const auto &e=s.enemies[target.slot];d.target=target;d.target_id=e.id;d.angle=(e.pos-d.pos).angle();w.target_after[e.id]=w.clock+w.target_interval;d.kick=1.5*1.82*r.content->config.character_scale;d.flash=0.06;const auto direction=godot::Vector2::from_angle(d.angle);const auto origin=d.pos+direction*15*r.content->config.character_scale;const auto count=EquipmentSystem::shot_count(r,1);const double damage=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage;
            for (int64_t j=0;j<count;++j) {godot::RunState::Friendly shot;shot.pos=origin;shot.vel=godot::Vector2::from_angle(d.angle+(j-(count-1)/2.0)*0.08)*(w.shot_speed*(1+w.projectile_increment*double(s.loadout->post_projectile_speed_stacks)));shot.damage=damage;shot.radius=w.shot_radius*s.loadout->effects.area;shot.life=w.life*(1+w.duration_increment*double(s.loadout->post_duration_stacks));shot.color=godot::Color::hex(w.color);shot.cause="interceptor";shot.weapon_id="W25";shot.visual="weapon/interceptor";shot.callback.kind=FriendHitKind::Interceptor;FriendShotSystem::emit(r,std::move(shot));}
        }
        --d.left;const double rate=s.draw.gauge<1?1:1+s.loadout->effects.full_gauge_rate*s.draw.gauge;d.next=w.clock+interval(d.left?w.burst_interval:w.interval)/rate;
    }
}
}
