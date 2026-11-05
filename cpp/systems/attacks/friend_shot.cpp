#include "friend_shot.h"
#include "../../behaviors/traits/duplicator.h"
#include "../attack_system.h"
#include "../../content/content_bundle.h"
#include <cmath>
namespace speed {
AttackHandle FriendShotSystem::emit(RunRuntime &run,godot::RunState::Friendly shot) {
    FriendlyBirthScope scope(run);
    if (!run.state.started || run.state.closed || !run.state.combat_ready || shot.kind!=int64_t(FriendKind::Shot) ||
        !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.damage) || shot.damage<0 || shot.pierce_left<0) return {};
    for (double value:{shot.radius,shot.life,shot.knock}) if (!std::isfinite(value) || value<0) return {};
    AttackSpec spec;spec.cause=Cause::Shot;spec.policies=policy(EndPolicy::NaturalLifetime);
    for (const auto &weapon:run.content->equipment) if (weapon.kind==0 && shot.weapon_id==godot::StringName(weapon.external_id.c_str())) {spec.weapon=weapon.id;break;}
    if (!run.content->friend_shots.empty()) {
        shot.definition=1;
        if (!AttackSystem::configure_contact(*run.content,run.content->friend_shots.front().contact,spec)) return {};
    } else if (run.api_configured) return {};
    return AttackSystem::emit_friendly(run,std::move(shot),spec);
}
}
