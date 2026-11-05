#include "barrier.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/equipment.h"
#include "../../systems/collision_query.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
bool BarrierBehavior::block(RunRuntime &run,const ShipDamageRequest &request,double amount) {
    auto &state=run.state;auto &barrier=state.loadout->barrier;
    if (!barrier.ready || barrier.restore>0 || amount<=0) return false;
    if (barrier.durability<0) barrier.durability=barrier.maximum;
    barrier.durability-=amount;const bool broken=barrier.durability<=0;
    const auto &post=run.content->barrier_post;
    if (broken) {
        const double floor=std::min(barrier.revive,std::max(post.minimum_interval,barrier.revive*post.minimum_ratio));
        barrier.restore=std::max(floor,barrier.revive*(1-post.interval_increment*double(state.loadout->post_weapon_interval_stacks)));
    }
    BarrierWaveState wave;wave.pos=state.ship.pos;wave.radius=barrier.radius*state.loadout->effects.area;
    wave.damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,barrier.definition)*barrier.damage;
    const auto hit=request.has_impact?request.impact:state.ship.pos+state.ship.heading*barrier.shell_radius*1.82*run.content->config.character_scale;
    wave.angle=(hit-state.ship.pos).angle();wave.broken=broken;barrier.waves.push_back(std::move(wave));
    godot::Dictionary event;event["pos"]=state.ship.pos;event["hit"]=hit;event["angle"]=(hit-state.ship.pos).angle();event["radius"]=barrier.waves.back().radius;event["broken"]=broken;
    FrameBuilder::append(run,"barrier_hit",event);return true;
}
double BarrierBehavior::segment(const RunRuntime &run,godot::Vector2 from,godot::Vector2 to,double radius,const ShipDamageRequest &request) {
    const auto &state=run.state;const auto &barrier=state.loadout->barrier;
    if (!barrier.ready || barrier.restore>0 || request.amount<=0 || request.cause==Cause::Debug || request.cause==Cause::FinalStrike || state.phase!=godot::RunState::Phase::Play || state.boss_dead || state.controls_locked || state.encounter_protected || state.ship.shield_t>0 || state.ship.invuln>0 || state.invincible) return -1;
    return CollisionQuery::segment_circle_t(from,to,state.ship.pos,barrier.shell_radius*1.82*run.content->config.character_scale+radius);
}
void BarrierBehavior::step(RunRuntime &run,double dt) {
    auto &state=run.state;auto &barrier=state.loadout->barrier;
    if (!barrier.ready || dt<=0 || state.phase!=godot::RunState::Phase::Play || state.controls_locked) return;
    barrier.restore_visual_age=std::min(1.0,barrier.restore_visual_age+dt);
    if (barrier.restore>0) {
        barrier.restore=remaining_time(barrier.restore,dt);
        if (barrier.restore<=0) {barrier.durability=barrier.maximum;barrier.restore_visual_age=0;godot::Dictionary event;event["pos"]=state.ship.pos;FrameBuilder::append(run,"barrier_restore",event);}
    }
    const double cell=std::sqrt(3.0)*4.0*1.82*run.content->config.character_scale;
    const double knock=barrier.knock*(1+run.content->barrier_post.knockback_increment*double(state.loadout->post_knockback_stacks));
    for (auto &wave:barrier.waves) {
        wave.age+=dt;if (wave.age<0.21) continue;
        const double reach=std::min(wave.radius,(4+std::floor((wave.age-0.21)/0.05))*cell);
        const godot::Vector2 pad(reach+state.grid.max_radius,reach+state.grid.max_radius);
        for (size_t row:CollisionQuery::enemy_rows(state,wave.pos-pad,wave.pos+pad)) {
            const auto &enemy=state.enemies[row];
            if (enemy.dead || wave.hits.count(enemy.id) || enemy.pos.distance_to(wave.pos)>reach+enemy.radius) continue;
            wave.hits.insert(enemy.id);
            DamageRequest request;request.struck=state.enemy_handles.at(uint32_t(row));request.amount=wave.damage;request.cause=Cause::Barrier;
            request.direction=(enemy.pos-wave.pos).normalized();request.knock=knock;
            CombatResolver::damage_enemy(run,request);
        }
    }
    barrier.waves.erase(std::remove_if(barrier.waves.begin(),barrier.waves.end(),[&](const auto &wave){return wave.age>=0.26+std::ceil(wave.radius/cell-4.0)*0.05;}),barrier.waves.end());
    EventBuilder::flush_combat(run);
}
}
