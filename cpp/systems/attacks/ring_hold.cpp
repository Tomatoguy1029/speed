#include "ring_hold.h"
#include "bullet.h"
#include "../attack_system.h"
#include "../../content/content_bundle.h"
#include <cmath>
namespace speed {
std::vector<AttackHandle> RingHoldSystem::emit(RunRuntime &run,const RingHoldParams &p) {
    std::vector<AttackHandle> result;
    if (!run.state.started || run.state.closed || !run.state.enemy_handles.contains(p.source) || run.content->ring_holds.empty() ||
        uint64_t(p.count)>=uint64_t(INT64_MAX-run.state.attacks.next_id)) return result;
    for (double v:{p.radius,p.wait,p.speed}) if (!std::isfinite(float(v)) || v<0) return result;
    if (!std::isfinite(p.damage) || p.damage<0) return result;
    const auto &d=run.content->ring_holds.front();const double life=d.life+p.wait;if (!std::isfinite(float(life))) return result;
    const auto center=run.state.enemies[p.source.slot].pos;
    for (uint32_t k=0;k<p.count;++k) {
        const auto u=godot::Vector2::from_angle(godot::Math::TAU*double(k)/p.count);
        BulletSpawn bullet;bullet.source=p.source;bullet.definition=d.projectile;bullet.position=center+u*p.radius;bullet.velocity=u*p.speed;
        bullet.speed=p.speed;bullet.radius=d.projectile_radius;bullet.life=life;bullet.wait=p.wait;bullet.damage=p.damage;bullet.budget=p.budget;
        const auto handle=BulletSystem::emit(run,bullet);
        if (!AttackSystem::get(run.state,handle)) {for (auto old:result) AttackSystem::end(run.state,old,AttackEndReason::Lifetime);return {};}
        result.push_back(handle);
    }return result;
}
}
