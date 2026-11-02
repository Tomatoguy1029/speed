#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include "beam.h"
#include "wave.h"
#include "wall.h"
#include "zone.h"
#include <cmath>
namespace speed {
bool AttackSystem::step_hazards(RunRuntime &run,double dt) {
    auto &state=run.state;
    if (!state.started || state.closed || !state.ship_ready || !std::isfinite(dt) || dt<0) return false;
    if (dt==0) return true;
    const int64_t cutoff=state.attacks.next_id;
    for (size_t row=0;row<state.hazards.size();++row) {
        auto &hazard=state.hazards[row];
        if (!hazard.alive || (std::holds_alternative<MonocerosWaveHazard>(hazard.shape) || std::holds_alternative<CanisFlameHazard>(hazard.shape) || std::holds_alternative<CanisHoundLungeHazard>(hazard.shape))) continue;const auto handle=hazard.attack;const auto *record=get(state,handle);if (!record || record->id>=cutoff) continue;
        const double time=double(hazard.time)+dt;hazard.time=time;
        const auto owner=record->spec.owner.live_source;
        const bool owner_ended=record->spec.owner.attached && (!state.enemy_handles.contains(owner) || state.enemies[owner.slot].dead || state.enemy_handles.contains(state.enemies[owner.slot].pump_owner));
        if (time>=double(hazard.delay)+double(hazard.duration) || owner_ended) {end(state,handle,owner_ended?AttackEndReason::ParticipantEnd:AttackEndReason::Lifetime);EventBuilder::flush_combat(run);continue;}
        if (time>=hazard.delay && std::holds_alternative<WaveHazard>(hazard.shape)) {
            if (owner.generation && std::get<WaveHazard>(hazard.shape).style==uint32_t(WaveStyle::Pulser)) {
                auto &spec=state.attacks.records[handle.slot].spec;spec.owner.live_source={};spec.owner.attached=false;
                spec.policies&=~policy(EndPolicy::CancelWithParticipant);
            }
            if (!WaveSystem::act(run,handle,dt)) return true;
            EventBuilder::flush_combat(run);
        }
        if (auto *shape=std::get_if<HydraShapeHazard>(&state.hazards[row].shape)) {shape->before=shape->last_points.empty()?shape->points:shape->last_points;if (time>=state.hazards[row].delay) for (auto &point:shape->points) point+=shape->velocity*dt;shape->last_points=shape->points;if (!shape->points.empty()) state.hazards[row].pos=shape->points.front();}
        if (!get(state,handle)) continue;
        if (time>=state.hazards[row].delay && !hazard_act(state,handle,dt)) return true;
        const auto &pending=state.hazards[row];
        if (time<pending.delay || pending.hit) continue;
        if (!hazard_before_touch(state,handle)) return true;
        if (pending.zone_definition && !ZoneSystem::activate(run,handle)) {EventBuilder::flush_combat(run);return true;}
        if (!get(state,handle)) continue;
        auto &current=state.hazards[row];
        const auto *circle=std::get_if<CircleHazard>(&current.shape);
        const ContactShape shape=std::holds_alternative<HydraShapeHazard>(current.shape)?ContactShape(Polyline{std::get<HydraShapeHazard>(current.shape).points,std::get<HydraShapeHazard>(current.shape).before,std::get<HydraShapeHazard>(current.shape).width*0.5}):circle?ContactShape(PointCircle{current.pos,circle->radius}):std::holds_alternative<WaveHazard>(current.shape)?WaveSystem::geometry(current):std::holds_alternative<WallHazard>(current.shape)?WallSystem::geometry(current):BeamSystem::geometry(current);
        if (circle) current.hit=true;
        const auto *contact=get(state,handle);if (!contact) continue;const auto &policy=contact->spec.contact;
        const auto previous=contact->ship_previous_ready?contact->ship_previous:state.ship.pos;
        if (!CollisionQuery::touches(shape,{previous,state.ship.pos,state.ship_config.ship_radius},{policy.add_ship_radius,policy.ship_sweep})) continue;
        if (!std::holds_alternative<WallHazard>(current.shape)) current.hit=true;
        if (circle && circle->kind!=CircleHazardKind::Blast && state.bite_zone_config.hit) {
            godot::Dictionary event;if (state.bite_zone_config.visual_key) event["visual_key"]=state.bite_zone_config.visual_key;else event["scene"]=state.bite_zone_config.scene;
            event["phase"]="Hit";event["pos"]=state.ship.pos;EventBuilder::flush_combat(run);FrameBuilder::append(run,"attack_visual_end",event);
        }
        if (current.zone_definition) ZoneSystem::end_visual(run,current.zone_definition,true,state.ship.pos);
        CombatResolver::attack_ship_damage(run,handle,shape,current.damage,0);EventBuilder::flush_combat(run);
        if (state.phase!=godot::RunState::Phase::Play) return true;
    }
    return true;
}
}
