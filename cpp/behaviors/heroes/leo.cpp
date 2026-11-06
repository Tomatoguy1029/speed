#include "leo.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <vector>
namespace speed {
namespace {
double segment_distance(godot::Vector2 p,godot::Vector2 a,godot::Vector2 b) {
    const auto ab=b-a;const double length=ab.length_squared();
    const double t=length>0?std::clamp(double((p-a).dot(ab))/length,0.0,1.0):0.0;
    return p.distance_to(a+ab*t);
}
}
const LeoDefinition *LeoBehavior::active(const RunRuntime &run) {
    const auto &h=run.state.heroes;if (!h.power || h.active<=0) return nullptr;
    for (const auto &d:run.content->leo) if (d.hero==h.power) return &d;
    return nullptr;
}
// 獅子の体は、機体の向きにそった前 front・後ろ back の線分に半径 radius をつけた形。
// 敵には装甲や特殊な倒し方に関係なく、特性を除いた攻撃力 × power を与え、同じ敵には hit_interval 世界秒ごとに当たる。
// 障害物は砕け、敵の弾は消える
void LeoBehavior::contact(RunRuntime &run,godot::Vector2 from,godot::Vector2 to) {
    const auto *d=active(run);if (!d) return;
    auto &s=run.state;
    godot::Vector2 forward=s.ship.heading;if (forward.is_zero_approx()) forward=(to-from);
    forward=forward.is_zero_approx()?godot::Vector2(1,0):forward.normalized();
    const auto head=to+forward*d->front,tail=to-forward*d->back;
    const double attack=s.combat_config.base_attack*s.combat_config.atk_scale*d->power;
    std::vector<EnemyHandle> rocks,struck;
    for (size_t row=0;row<s.enemies.size();++row) {
        const auto &e=s.enemies[row];if (!e.alive || e.dead) continue;
        if (segment_distance(e.pos,tail,head)>e.radius+d->radius) continue;
        const auto handle=s.enemy_handles.at(uint32_t(row));
        if (s.field.rock_handles.contains(e.rock)) rocks.push_back(handle);
        else struck.push_back(handle);
    }
    for (const auto target:rocks) {
        if (!s.enemy_handles.contains(target) || s.enemies[target.slot].dead) continue;
        DamageRequest request;request.struck=target;request.cause=Cause::Ram;request.direction=forward;CombatResolver::kill_enemy(run,request);
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
    for (const auto target:struck) {
        if (!s.enemy_handles.contains(target) || s.enemies[target.slot].dead) continue;
        const auto owner=CombatResolver::damage_target(run,target);if (!s.enemy_handles.contains(owner)) continue;
        auto &health=s.enemies[owner.slot];if (health.hit_cd>0) continue;
        health.hit_cd=d->hit_interval;
        const auto &e=s.enemies[target.slot];
        DamageRequest request;request.struck=target;request.cause=Cause::Ram;request.no_crit=true;request.amount=attack;
        request.direction=forward;request.impact=e.pos;request.has_impact=true;
        CombatResolver::damage_enemy(run,request);
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
    for (auto &shot:s.hostiles) if (shot.alive && shot.life>0 && segment_distance(shot.pos,tail,head)<=shot.radius+d->radius) shot.life=0;
}
}
