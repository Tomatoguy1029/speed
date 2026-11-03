#include "corona.h"
#include "pursuit.h"
namespace speed {
void CoronaBehavior::step(RunRuntime &r,uint32_t row,double dt) {auto &e=r.state.enemies[row];const auto &d=r.content->definitions[e.definition];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};e.vel=PursuitBehavior::velocity(e,r.state.ship_pos,d.turn,dt,tracking);}
}
