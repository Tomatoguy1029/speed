#include "friend_shot.h"
#include "../attack_system.h"
#include <cmath>
namespace speed {
AttackHandle FriendShotSystem::emit(RunRuntime &run,godot::RunState::Friendly shot) {
    if (!run.state.started || run.state.closed || !run.state.combat_ready || shot.kind!=int64_t(FriendKind::Shot) ||
        !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.damage) || shot.damage<0 || shot.pierce_left<0) return {};
    for (double value:{shot.radius,shot.life,shot.knock}) if (!std::isfinite(value) || value<0) return {};
    AttackSpec spec;spec.cause=Cause::Shot;spec.policies=policy(EndPolicy::NaturalLifetime);
    if (shot.weapon_id==godot::StringName("W01")) spec.weapon=1;
    if (!run.content->friend_shots.empty()) {
        shot.definition=1;
        if (!AttackSystem::configure_contact(*run.content,run.content->friend_shots.front().contact,spec)) return {};
    } else if (run.api_configured) return {};
    return AttackSystem::emit_friendly(run.state,std::move(shot),spec);
}
}
