#include "perseus.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attacks/bullet.h"
namespace speed {
void PerseusBehavior::activate(RunRuntime &run,double duration) {
    auto &s=run.state;const godot::Rect2 view(s.view_center-s.view_half,s.view_half*2);
    for (auto &e:s.enemies) {
        if (!e.alive || e.dead || s.field.rock_handles.contains(e.rock) || !view.has_point(e.pos)) continue;
        if (e.is_boss) {for (const auto &definition:run.content->perseus) if (definition.hero==s.heroes.power) s.heroes.boss_stun=definition.boss_stun;}
        else e.stone=duration;
    }
    BulletSystem::petrify(s,view,duration);
}
}
