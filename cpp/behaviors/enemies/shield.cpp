#include "shield.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/motion_math.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include <godot_cpp/core/math.hpp>
#include <cmath>
namespace speed {
void ShieldBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    enemy.fire_t=remaining_time(enemy.fire_t,dt);
    EnemyMotion::steer(enemy,state.enemy_aim,enemy.speed,def.accel,dt,tracking);
    EnemyMotion::turn(enemy,(state.ship_pos-enemy.pos).angle(),def.turn,dt,tracking);
}
bool ShieldBehavior::blocks_front(const RunRuntime &run,EnemyHandle handle,godot::Vector2 impact,godot::Vector2 direction) {
    if (!run.state.enemy_handles.contains(handle)) return false;
    const auto &enemy=run.state.enemies[handle.slot];if (enemy.stone>0) return false;
    auto toward=impact-enemy.pos;if (toward.length_squared()<0.01) toward=-direction;
    return toward.length_squared()>0 && std::abs(angle_difference(double(toward.angle())-enemy.facing))<=run.content->definitions[enemy.definition].front_arc;
}
bool ShieldBehavior::rear_open(const RunRuntime &run,EnemyHandle handle,godot::Vector2 impact) {
    if (!run.state.enemy_handles.contains(handle)) return false;const auto &enemy=run.state.enemies[handle.slot];
    return std::abs(angle_difference(double((impact-enemy.pos).angle())-enemy.facing-godot::Math::PI))<=run.content->definitions[enemy.definition].weak_arc;
}
void ShieldBehavior::steal(RunRuntime &run,EnemyHandle handle) {
    if (!run.state.enemy_handles.contains(handle)) return;
    const auto &enemy=run.state.enemies[handle.slot];const auto &definition=run.content->definitions[enemy.definition];auto &ship=run.state.ship;
    ship.shield_t=ship.shield_max=definition.shield_time;ship.shield_flash=0.2;ship.shield_source_definition=uint32_t(enemy.definition+1);
    godot::Dictionary event;event["pos"]=enemy.pos;event["facing"]=enemy.facing;event["r"]=enemy.radius;event["arc"]=definition.front_arc;event["enemy_type"]=definition.id;
    EventBuilder::flush_combat(run);FrameBuilder::append(run,"shield_stolen",event);
}
}
