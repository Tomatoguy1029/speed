#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
void HydraTechnique::tornado(RunRuntime &r,TechniqueState &t,double) {
    auto *b=PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);auto &move=std::get<HydraTornadoState>(v.move);
    const auto &p=*std::find_if(r.content->hydra_tornadoes.begin(),r.content->hydra_tornadoes.end(),[&](const auto &p){return p.technique==t.definition;});
    auto &wind=*HydraNormalAttack::neck(*b,v.participants[0]);auto &debris=*HydraNormalAttack::neck(*b,v.participants[1]);
    if (!move.initialized) {
        move.initialized=true;move.direction=(r.state.ship_pos-wind.strike_pos).normalized();if (move.direction==godot::Vector2()) move.direction=godot::Vector2::from_angle(wind.angle);
        move.center=wind.strike_pos+move.direction*120;move.from=debris.strike_pos;wind.angle=move.direction.angle();debris.angle=(move.center-debris.strike_pos).angle();
        move.vortex=emit(r,t,wind.actor,{move.center,move.center+godot::Vector2(0.1,0)},p.width*0.8,0,p.charge,Cause::TornadoCharge);
        if (const auto *record=AttackSystem::get(r.state,move.vortex)) {r.state.hazards[record->row].damage=0;}
        for (int j=0;j<3;++j) {EnemySpawn spawn;spawn.position=debris.strike_pos;spawn.origin=SpawnOrigin::BossPart;const auto id=EnemySystem::spawn(r,p.enemy-1,spawn);if (id>0) {const auto actor=r.state.enemy_handles.at(r.state.rows_by_id.at(id));move.rubble.push_back(actor);r.state.enemies[actor.slot].radius=26+6*j;}}
        HydraNormalAttack::cue(r,*b,wind,"gather_started",t.definition);
    }
    if (!move.launched) {
        HydraShapeHazard *shape=nullptr;if (const auto *record=AttackSystem::get(r.state,move.vortex)) shape=std::get_if<HydraShapeHazard>(&r.state.hazards[record->row].shape);
        if (shape) {shape->fill=std::clamp((v.time-p.charge*5/12)/(p.charge*7/12),0.,1.);shape->feed.clear();}
        const auto side=(move.center-move.from).normalized().orthogonal();
        for (size_t j=0;j<move.rubble.size();++j) if (r.state.enemy_handles.contains(move.rubble[j])) {auto &e=r.state.enemies[move.rubble[j].slot];const double progress=std::clamp((v.time-p.charge*(0.25+j*0.12)/1.2)/(p.charge*0.65/1.2),0.,1.);e.pos=move.from.lerp(move.center,progress)+side*std::sin(progress*3.141592653589793)*(60+35*j);e.radius=(26+6*j)*(1-progress*0.7);if (shape) shape->feed.emplace_back(e.pos.x,e.pos.y,e.radius);}
    }
    if (v.time>=p.charge && !move.launched) {
        move.launched=true;AttackSystem::end(r.state,move.vortex,AttackEndReason::Lifetime);
        for (auto actor:move.rubble) if (r.state.enemy_handles.contains(actor)) EnemySystem::mark_dead(r,actor);
        const auto handle=emit(r,t,wind.actor,{move.center-move.direction*45,move.center+move.direction*45},p.width,0,p.life,Cause::Tornado,true);
        if (const auto *record=AttackSystem::get(r.state,handle)) std::get<HydraShapeHazard>(r.state.hazards[record->row].shape).velocity=move.direction*p.speed;
        HydraNormalAttack::cue(r,*b,wind,"attack_started",t.definition);
    }
}
}
