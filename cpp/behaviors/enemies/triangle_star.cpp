#include "triangle_star.h"
#include "part.h"
namespace speed {
void TriangleStarBehavior::step(RunRuntime &run,uint32_t row) {PartBehavior::step(run,row);}
bool TriangleStarBehavior::passes(const RunRuntime &run,EnemyHandle target) {
    const auto &s=run.state;if (!s.enemy_handles.contains(target)) return false;const auto parent=s.enemies[target.slot].parent;
    return s.enemy_handles.contains(parent) && s.enemies[parent.slot].mode==EnemyMode::Dash;
}
}
