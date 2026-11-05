#include "perseus.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attacks/bullet.h"
#include "../../systems/combat_resolver.h"
#include "../../content/content_bundle.h"
namespace speed {
namespace {
const PerseusDefinition *definition(const RunRuntime &run) {
    for (const auto &d:run.content->perseus) if (d.hero==run.state.heroes.power) return &d;
    return nullptr;
}
// 目が開ききった瞬間：画面の中の敵と弾を、砕けるまで石にして止める。ボスは止めるだけ
void petrify(RunRuntime &run,const PerseusDefinition &d) {
    auto &s=run.state;const godot::Rect2 view(s.view_center-s.view_half,s.view_half*2);const double hold=d.shatter_delay+0.5;
    for (auto &e:s.enemies) {
        if (!e.alive || e.dead || s.field.rock_handles.contains(e.rock) || !view.has_point(e.pos)) continue;
        if (e.is_boss) s.heroes.boss_stun=d.boss_stun;
        else e.stone=hold;
    }
    BulletSystem::petrify(s,view,hold);
}
// 石の敵を一斉に砕き、石の弾を消す。大物（星6以上）とボスは砕けずに、最大HPの割合のダメージを受ける
void shatter(RunRuntime &run,const PerseusDefinition &d) {
    auto &s=run.state;const godot::Rect2 view(s.view_center-s.view_half,s.view_half*2);
    std::vector<EnemyHandle> broken,struck;
    for (size_t row=0;row<s.enemies.size();++row) {
        auto &e=s.enemies[row];if (!e.alive || e.dead) continue;const auto handle=s.enemy_handles.at(uint32_t(row));
        if (e.is_boss) {if (view.has_point(e.pos)) struck.push_back(handle);continue;}
        if (e.stone<=0) continue;
        if (run.content->definitions[e.definition].rank>=6) {e.stone=0;struck.push_back(handle);}
        else broken.push_back(handle);
    }
    for (const auto target:broken) {
        if (!s.enemy_handles.contains(target) || s.enemies[target.slot].dead) continue;
        DamageRequest request;request.struck=target;request.cause=Cause::Touch;CombatResolver::kill_enemy(run,request);
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
    for (const auto target:struck) {
        if (!s.enemy_handles.contains(target) || s.enemies[target.slot].dead) continue;
        const auto owner=CombatResolver::damage_target(run,target);if (!s.enemy_handles.contains(owner)) continue;
        const auto &e=s.enemies[owner.slot];
        DamageRequest request;request.struck=target;request.cause=Cause::Ram;request.no_crit=true;
        request.amount=e.max_hp*(e.is_boss?d.boss_damage_ratio:d.big_damage_ratio);request.impact=e.pos;request.has_impact=true;
        CombatResolver::damage_enemy(run,request);
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
    for (auto &shot:s.hostiles) if (shot.alive && shot.stone>0) shot.life=0;
}
}
void PerseusBehavior::activate(RunRuntime &run) {
    const auto *d=definition(run);if (d && d->open_delay<=0) petrify(run,*d);
}
// before・after は効いている時間の残り（実秒）。発動からの経過で、石化と砕ける時刻を越えたときに1回ずつ行う
void PerseusBehavior::step(RunRuntime &run,double before,double after) {
    const auto &h=run.state.heroes;if (!h.power || before<=0) return;
    const auto &hero=run.content->heroes[h.power-1].definition;if (hero.external_id!="perseus") return;
    const auto *d=definition(run);if (!d) return;
    const double from=hero.duration-before,to=hero.duration-after,broken=d->open_delay+d->shatter_delay;
    if (d->open_delay>0 && from<d->open_delay && to>=d->open_delay) petrify(run,*d);
    if (from<broken && to>=broken) shatter(run,*d);
}
}
