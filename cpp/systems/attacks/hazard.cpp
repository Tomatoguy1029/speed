#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include "beam.h"
#include <cmath>
namespace speed {
bool AttackSystem::step_hazards(RunRuntime &run,double dt) {
    auto &state=run.state;
    if (!state.started || state.closed || !state.ship_ready || !std::isfinite(dt) || dt<0) return false;
    if (dt==0) return true;
    const int64_t cutoff=state.attacks.next_id;
    for (size_t row=0;row<state.hazards.size();++row) {
        auto &hazard=state.hazards[row];
        if (!hazard.alive) continue;const auto handle=hazard.attack;const auto *record=get(state,handle);if (!record || record->id>=cutoff) continue;
        const double time=double(hazard.time)+dt;hazard.time=time;
        const auto owner=record->spec.owner.live_source;
        const bool owner_ended=record->spec.owner.attached && (!state.enemy_handles.contains(owner) || state.enemies[owner.slot].dead || state.enemy_handles.contains(state.enemies[owner.slot].pump_owner));
        if (time>=double(hazard.delay)+double(hazard.duration) || owner_ended) {end(state,handle,owner_ended?AttackEndReason::ParticipantEnd:AttackEndReason::Lifetime);continue;}
        if (time>=hazard.delay && !hazard_act(state,handle,dt)) return true;
        if (time<hazard.delay || hazard.hit) continue;
        if (!hazard_before_touch(state,handle)) return true;
        const auto *circle=std::get_if<CircleHazard>(&hazard.shape);
        const ContactShape shape=circle?ContactShape(PointCircle{hazard.pos,circle->radius}):BeamSystem::geometry(hazard);
        if (circle) hazard.hit=true;
        const auto *contact=get(state,handle);if (!contact) continue;const auto &policy=contact->spec.contact;
        const auto previous=contact->ship_previous_ready?contact->ship_previous:state.ship.pos;
        if (!CollisionQuery::touches(shape,{previous,state.ship.pos,state.ship_config.ship_radius},{policy.add_ship_radius,policy.ship_sweep})) continue;
        hazard.hit=true;
        if (circle && state.bite_zone_config.hit) {
            godot::Dictionary event;if (state.bite_zone_config.visual_key) event["visual_key"]=state.bite_zone_config.visual_key;else event["scene"]=state.bite_zone_config.scene;
            event["phase"]="Hit";event["pos"]=state.ship.pos;EventBuilder::flush_combat(run);FrameBuilder::append(run,"attack_visual_end",event);
        }
        CombatResolver::attack_ship_damage(run,handle,shape,hazard.damage,0);EventBuilder::flush_combat(run);
        if (state.phase!=godot::RunState::Phase::Play) return true;
    }
    return true;
}
}
