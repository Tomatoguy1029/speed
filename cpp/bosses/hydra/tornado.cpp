#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <iterator>
#include <cmath>
namespace speed {
namespace {constexpr double ROCKS[5][3]={{0.42,15,0.86},{0.56,19,0.62},{0.68,12,0.42},{0.78,16,0.74},{0.87,10,0.54}};} // 打ち込む割合・大きさ・渦の中の半径の割合
void HydraTechnique::tornado(RunRuntime &r,TechniqueState &t,double) {
    auto *b=PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();auto &move=std::get<HydraTornadoState>(v.move);
    const auto &p=*std::find_if(r.content->hydra_tornadoes.begin(),r.content->hydra_tornadoes.end(),[&](const auto &p){return p.technique==t.definition;});
    auto &wind=*HydraNormalAttack::neck(*b,v.participants[0]);auto &debris=*HydraNormalAttack::neck(*b,v.participants[1]);
    if (!move.initialized) {
        move.initialized=true;move.direction=(r.state.ship_pos-wind.strike_pos).normalized();if (move.direction==godot::Vector2()) move.direction=godot::Vector2::from_angle(wind.angle);
        move.center=wind.strike_pos+move.direction*120;move.from=debris.strike_pos;wind.angle=move.direction.angle();debris.angle=(move.center-debris.strike_pos).angle();
        move.vortex=emit(r,t,wind.actor,{move.center,move.center+godot::Vector2(0.1,0)},p.width*0.8,0,p.charge,Cause::TornadoCharge);
        if (const auto *record=AttackSystem::get(r.state,move.vortex)) {r.state.hazards[record->row].damage=0;}
        HydraNormalAttack::cue(r,*b,wind,"gather_started",t.definition);
    }
    // 岩は瓦礫の首からまっすぐ渦へ打ち込まれ、捕まるとそのまま中を回り、終わりに外へ放り出される。
    if (!move.launched) if (const auto *record=AttackSystem::get(r.state,move.vortex)) {auto &shape=std::get<HydraShapeHazard>(r.state.hazards[record->row].shape);shape.fill=std::clamp((v.time-p.charge*5/12)/(p.charge*7/12),0.,1.);shape.feed.clear();}
    const double since=move.launched?v.time-move.launch_time:0,grow=move.launched?1:std::pow(std::clamp(v.time/p.charge,0.,1.),1.4),step=std::clamp(since/0.15,0.,1.);move.fade=std::clamp((p.life-since)/0.4,0.,1.);move.radius=p.width*0.5*(move.launched?0.8+0.2*step*step*(3-2*step):0.8*(0.1+0.9*grow));const auto now=move.center+move.direction*p.speed*since;move.from=debris.strike_pos+godot::Vector2::from_angle(debris.angle)*40;
    for (size_t j=0;j<std::size(ROCKS);++j) {
        const double start=ROCKS[j][0]*p.charge,size=ROCKS[j][1],share=ROCKS[j][2];if (v.time<start) continue;
        if (move.rocks.size()<=j) {HydraTornadoRock rock;rock.size=size;EnemySpawn spawn;spawn.position=move.from;spawn.origin=SpawnOrigin::BossPart;const auto id=EnemySystem::spawn(r,p.enemy-1,spawn);if (id>0) {rock.actor=r.state.enemy_handles.at(r.state.rows_by_id.at(id));r.state.enemies[rock.actor.slot].radius=size;move.rubble.push_back(rock.actor);}move.rocks.push_back(rock);}
        auto &rock=move.rocks[j];rock.duration=0.17;rock.progress=std::clamp((v.time-start)/rock.duration,0.,1.);rock.settle=std::max(0.,v.time-start-rock.duration);const double angle=(move.from-now).angle(),ring=move.radius*share;const auto entry=now+godot::Vector2::from_angle(angle)*ring;rock.spin=angle-6*rock.settle-5*(1-std::exp(-3*rock.settle));rock.orbit=ring*(1+(1-move.fade)*2.2);rock.aim=(entry-move.from).normalized();rock.flight=move.from.distance_to(entry);rock.world=rock.progress<1?move.from.lerp(entry,rock.progress):now+godot::Vector2::from_angle(rock.spin)*rock.orbit;if (r.state.enemy_handles.contains(rock.actor) && !r.state.enemies[rock.actor.slot].dead) r.state.enemies[rock.actor.slot].pos=rock.world;
    }
    if (v.time>=p.charge && !move.launched) {
        move.launched=true;AttackSystem::end(r.state,move.vortex,AttackEndReason::Lifetime);
        move.launch_time=v.time;
        const auto handle=emit(r,t,wind.actor,{move.center-move.direction*45,move.center+move.direction*45},p.width,0,p.life,Cause::Tornado,true);
        if (const auto *record=AttackSystem::get(r.state,handle)) std::get<HydraShapeHazard>(r.state.hazards[record->row].shape).velocity=move.direction*p.speed;
        HydraNormalAttack::cue(r,*b,wind,"attack_started",t.definition);
    }
}
}
