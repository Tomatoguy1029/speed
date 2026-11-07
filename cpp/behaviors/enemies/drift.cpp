#include "drift.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
void DriftBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &enemy=run.state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &drift=run.content->drifts[def.drift_definition-1];enemy.facing=enemy.facing+enemy.spin*dt;
    if (!drift.has_life) return;
    if (enemy.age>drift.life) {enemy.dead=true;run.state.dead_rows.push_back(row);}
}
}
