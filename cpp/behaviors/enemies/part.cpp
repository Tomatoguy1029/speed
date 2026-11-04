#include "part.h"
namespace speed {
void PartBehavior::step(RunRuntime &run,uint32_t row) {
    auto &state=run.state;auto &enemy=state.enemies[row];
    if (!state.enemy_handles.contains(enemy.parent) || state.enemies[enemy.parent.slot].dead) {enemy.dead=true;state.dead_rows.push_back(row);}
    enemy.vel=godot::Vector2();
}
}
