#include "body.h"
#include "../flow/phase_controller.h"
namespace speed {
EnemyHandle MonocerosBody::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {
    if (!definition || definition>r.content->boss_bodies.size() || r.content->bosses[r.content->boss_bodies[definition-1].boss-1].kind!=0) return {};
    return PhaseController::spawn(r,definition,at,entrance);
}
}
