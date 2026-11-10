#include "route_constraints.h"
#include "collision_query.h"
#include "combat_resolver.h"
#include "attack_system.h"
#include "../runtime/run_runtime.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
RouteContext RouteConstraints::context(const RunRuntime &run) {
    const auto &s=run.state;const auto &d=s.draw_config;const auto &ship=s.ship_config;RouteContext c;
    c.ship_radius=ship.ship_radius;c.field_radius=ship.field_radius;c.point_step=d.point_step;c.zoom=s.control.camera_zoom;c.ship_position=s.ship.pos;c.fuel=s.draw.fuel;c.fuel_max=d.fuel_capacity*d.capacity;c.fuel_capacity=d.fuel_capacity;c.boost_min_cost=d.boost_min_cost;c.boost_min_q=d.boost_min_q;
    c.draw_length=d.length;c.boost_cost_ratio=d.boost_cost_ratio;c.max_speed=ship.max_speed;c.base_speed=ship.base_max_speed;c.length_mult=d.length_mult;c.confirm_delay=d.confirm_delay;c.run_time=d.run_time;c.hitstop_cap=s.combat_config.kill_hitstop_cap;
    c.time_scale=d.time_scale;c.scale_min=d.scale_min;c.pending_world=s.control.world_dt_accum;c.attack=CombatResolver::attack_power(run);
    c.window_attack=s.combat_config.base_attack*s.combat_config.atk_scale*std::min(1.0,s.combat_config.attack_mult)*std::min(1.0,s.loadout->effects.burst_power);
    c.body_speed=s.field.body_speed_max;c.comet_time=s.field.ready?s.field.comet_t:std::numeric_limits<double>::infinity();c.rock_count=s.field.rocks.size();c.well_count=s.field.wells.size();
    c.tick=s.control.tick;c.equipment_count=s.loadout->weapons.size()+s.loadout->traits.size();c.auto_spawn=s.population.frame_enabled && !s.population.blocked;
    for (const auto &body:s.field.bodies) c.bodies.push_back({body.position,body.radius});
    for (const auto &e:s.enemies) if (e.alive && !e.dead) {
        const auto &def=run.content->definitions[e.definition];const bool simple=def.kind==EnemyDefinition::Kind::Chase || def.kind==EnemyDefinition::Kind::Drift;
        c.enemies.push_back({e.id,e.pos,e.vel,e.radius,e.hp,e.armor,e.speed,uint32_t(def.gate),e.is_boss,simple,def.death_chain_definition!=0,def.split_definition!=0,def.drift_definition && run.content->drifts[def.drift_definition-1].has_life});
    }
    for (uint32_t i=0;i<s.hostiles.size();++i) {const auto &p=s.hostiles[i];if (p.alive) c.bullets.push_back({p.pos,p.vel,p.radius,p.turn>0 || p.kind==1,int64_t(i)});}
    for (uint32_t i=0;i<s.hazards.size();++i) {
        const auto &h=s.hazards[i];
        // 旧ボスの内部波は経路制約の対象外。時間幅の判定はボス自体を未対応とする。
        if (!h.alive || (std::holds_alternative<MonocerosWaveHazard>(h.shape) || std::holds_alternative<CanisFlameHazard>(h.shape) || std::holds_alternative<CanisHoundLungeHazard>(h.shape) || std::holds_alternative<HydraShapeHazard>(h.shape))) continue;const auto *record=AttackSystem::get(s,h.attack);RouteContext::Hazard out;out.position=h.pos;out.id=i;out.attached=record && record->spec.owner.attached;
        std::visit([&](const auto &shape) {
            using T=std::decay_t<decltype(shape)>;
            if constexpr (std::is_same_v<T,CircleHazard>) out.radius=shape.radius;
            else if constexpr (std::is_same_v<T,WaveHazard>) out.radius=shape.radius+shape.half_width;
            else if constexpr (std::is_same_v<T,MonocerosWaveHazard> || std::is_same_v<T,CanisFlameHazard> || std::is_same_v<T,CanisHoundLungeHazard> || std::is_same_v<T,HydraShapeHazard>) {}
            else {out.circle=false;out.end=h.pos+godot::Vector2::from_angle(shape.angle)*shape.length;out.radius=shape.half_width;
                if constexpr (std::is_same_v<T,BeamHazard>) out.radius+=std::abs(std::tan(shape.arc))*shape.length;
            }
        },h.shape);c.hazards.push_back(out);
    }
    return c;
}
double RouteConstraints::distance(godot::Vector2 p,const std::vector<godot::Vector2> &path) {
    double squared=std::numeric_limits<double>::infinity();for (size_t n=1;n<path.size();++n) squared=std::min(squared,CollisionQuery::point_segment_squared(p,path[n-1],path[n]));return std::sqrt(squared);
}
RouteResult RouteConstraints::validate(const RouteContext &c,const std::vector<godot::Vector2> &path,const RouteOptions &o) {
    RouteResult r;r.radius=c.ship_radius+std::max(0.0,o.margin)+c.point_step+2.5/std::max(c.zoom,0.01);
    r.budget=c.draw_length*(c.fuel/c.fuel_capacity)*(c.max_speed/c.base_speed)*c.length_mult/c.boost_cost_ratio;
    r.horizon=(std::max(0.0,o.window)+std::max(o.draw_seconds,c.confirm_delay)+c.run_time+c.hitstop_cap)*std::max(1.0,std::max(c.time_scale,c.scale_min))+c.pending_world;
    if (path.size()<2) return r;
    for (size_t n=1;n<path.size();++n) r.length+=path[n-1].distance_to(path[n]);
    const auto end=path.back();const double exit=std::max(0.0,o.exit_clearance);
    const auto near=[&](godot::Vector2 p) {return std::min(distance(p,path),double(p.distance_to(end))-exit);};
    const auto block=[&](RouteReason reason,godot::Vector2 at,int64_t id=0){r.blockers.push_back({reason,at,id});};
    const auto unknown=[&](RouteReason reason,int64_t id=0){r.unsupported.push_back({reason,{},id});};
    if (c.fuel<c.boost_min_cost) block(RouteReason::LowFuel,path.front());
    const double connection=c.ship_position.distance_to(path.front());
    if (connection>=r.budget) block(RouteReason::LinkTooFar,path.front());
    r.budget=std::max(0.0,r.budget-connection);
    if (end.length()+r.radius+exit>=c.field_radius) block(RouteReason::FieldEdge,end);
    if (r.length>r.budget+0.01) block(RouteReason::OverBudget,end);
    for (auto point:path) if (point.length()+r.radius>=c.field_radius) block(RouteReason::FieldEdge,point);
    for (const auto &body:c.bodies) if (near(body.position)<=body.radius+r.radius+c.body_speed*(o.window>0?r.horizon:0)) block(RouteReason::Body,body.position);
    for (const auto &e:c.enemies) {
        if (o.window>0 && (e.boss || !e.simple || e.speed>0 || e.velocity.length()>0.01 || e.chain || e.split || e.life || e.gate!=0)) unknown(RouteReason::MovingEnemy,e.id);
        if (near(e.position)>e.radius+r.radius || e.gate==1 || e.gate==3) continue;
        const double attack=o.window>0?c.window_attack:c.attack;
        if (e.gate!=0) block(RouteReason::Gate,e.position,e.id);
        else if (attack<e.armor || attack<e.hp) block(RouteReason::Strong,e.position,e.id);
        else r.fodder.push_back(e.id);
    }
    if (o.window>0) {
        if (c.body_speed>0 || c.rock_count) unknown(RouteReason::MovingTerrain);
        for (auto tick:o.future_ticks) if (tick>c.tick && double(tick)<=double(c.tick)+std::ceil(r.horizon*c.history_hz)) unknown(RouteReason::FutureCommands);
        if (c.equipment_count || c.hero || c.well_count) unknown(RouteReason::Equipment);
        if (c.comet_time<=r.horizon || c.gravity_time<=r.horizon) unknown(RouteReason::FutureTerrain);
        if (c.auto_spawn) unknown(RouteReason::AutoSpawn);if (o.scheduled) unknown(RouteReason::Scheduled);
    }
    const auto sweep=[&](godot::Vector2 from,godot::Vector2 to,double width) {
        if (CollisionQuery::point_segment_squared(end,from,to)<=std::pow(width+exit,2)) return true;
        for (size_t n=1;n<path.size();++n) if (CollisionQuery::sweep_segment(from,to,path[n-1],path[n],width)) return true;return false;
    };
    for (const auto &p:c.bullets) {
        bool hit=near(p.position)<p.radius+r.radius;
        if (o.window>0) {if (p.homing) unknown(RouteReason::HomingBullet,p.id);else hit=hit || sweep(p.position,p.position+p.velocity*r.horizon,p.radius+r.radius);}
        if (hit) block(RouteReason::Bullet,p.position);
    }
    for (const auto &h:c.hazards) {
        if (o.window>0 && h.attached) unknown(RouteReason::AttachedHazard,h.id);
        if (h.circle?near(h.position)<=h.radius+r.radius:sweep(h.position,h.end,h.radius+r.radius)) block(RouteReason::Hazard,h.position);
    }
    r.status=o.window>0?(r.blockers.empty() && r.unsupported.empty()?RouteStatus::Window:RouteStatus::Unsupported):(r.blockers.empty()?RouteStatus::Static:RouteStatus::Unfound);
    r.valid=r.blockers.empty() && (o.window<=0 || r.status==RouteStatus::Window);return r;
}
}
