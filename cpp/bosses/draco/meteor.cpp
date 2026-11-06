#include "meteor.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/enemy_system.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void retire(RunRuntime &r,RockHandle h) {if (!r.state.field.rock_handles.contains(h)) return;auto &rock=r.state.field.rocks[h.slot];rock.destroyed=true;if (r.state.enemy_handles.contains(rock.proxy)) EnemySystem::mark_dead(r,rock.proxy);}
}
void DracoMeteor::begin(RunRuntime &r,TechniqueState &t) {DracoBreath::begin(r,t);r.state.observations.execute(t.observation_id);}
void DracoMeteor::end(RunRuntime &r,TechniqueState &t,bool cancelled) {if (cancelled) DracoBreath::end(r,t,true);else t.detail.get<DracoTechniqueState>().warning_paths.clear();}
// 大きくて遅い弾。止まらずに飛び続け、体当たりでは止められない。
void DracoMeteor::launch(RunRuntime &r,TechniqueState &t,RockHandle h,godot::Vector2 direction) {
    if (!r.state.field.rock_handles.contains(h)) return;auto *b=PhaseController::find(r,t.actor);if (!b) return;auto &rock=r.state.field.rocks[h.slot];rock.size*=SCALE;auto &proxy=r.state.enemies[rock.proxy.slot];proxy.radius=rock.size;const auto &p=r.content->boss_techniques[t.definition-1];
    b->draco->meteors.push_back({h,direction,b->clock,LIFE});
    HazardState hazard;hazard.pos=rock.position;hazard.duration=LIFE;hazard.damage=p.damage;HydraShapeHazard shape;shape.points={rock.position,rock.position+godot::Vector2(0.1,0)};shape.life=LIFE;shape.width=rock.size*2;shape.follow=rock.proxy;hazard.shape=shape;
    AttackSpec spec;spec.owner.live_source=t.actor;spec.technique=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));spec.boss=r.state.bosses->body_handles.at(uint32_t(b-r.state.bosses->bodies.data()));spec.source_technique=t.definition;spec.cause=Cause::Rubble;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBoss;spec.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,true};const auto handle=AttackSystem::emit_hazard(r.state,hazard,spec);if (AttackSystem::get(r.state,handle)) r.state.attacks.records[handle.slot].ship_previous=t.previous_ship;
}
void DracoMeteor::tick(RunRuntime &r,BossBodyState &b,double dt) {auto &list=b.draco->meteors;for (auto i=list.begin();i!=list.end();) {const bool live=r.state.field.rock_handles.contains(i->rock) && !r.state.field.rocks[i->rock.slot].destroyed && r.state.enemy_handles.contains(r.state.field.rocks[i->rock.slot].proxy);i->life-=dt;if (!live || i->life<=0) {retire(r,i->rock);i=list.erase(i);continue;}auto &rock=r.state.field.rocks[i->rock.slot];rock.position+=i->direction*SPEED*dt;r.state.enemies[rock.proxy.slot].pos=rock.position;++i;}}
void DracoMeteor::clear_placed(RunRuntime &r,BossBodyState &b) {for (auto h:b.draco->placed_meteors) retire(r,h);b.draco->placed_meteors.clear();for (const auto &m:b.draco->meteors) retire(r,m.rock);b.draco->meteors.clear();}
bool DracoMeteor::validate(const godot::RunState &,const DracoBodyState &d) {for (const auto &m:d.meteors) if (!m.direction.is_finite() || !std::isfinite(m.born) || !std::isfinite(m.life)) return false;return true;}
void DracoMeteor::snapshot(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &out) {godot::Array rows;for (const auto &m:b.draco->meteors) {if (!r.state.field.rock_handles.contains(m.rock)) continue;const auto &rock=r.state.field.rocks[m.rock.slot];godot::Dictionary q;q["position"]=rock.position;q["radius"]=rock.size;q["angle"]=m.direction.angle();q["age"]=b.clock-m.born;q["seed"]=int64_t(m.rock.slot);rows.push_back(q);}out["meteors"]=rows;
    godot::Array shots;for (uint32_t row=0;row<r.state.hostiles.size();++row) {const auto &h=r.state.hostiles[row];if (!h.alive) continue;const auto *a=AttackSystem::get(r.state,h.attack);if (!a || !same_handle(a->spec.owner.live_source,b.actor) || !a->spec.source_technique) continue;const uint32_t kind=r.content->boss_techniques[a->spec.source_technique-1].kind;const int style=kind==108?0:kind==102?1:kind==106?2:-1;if (style<0) continue;godot::Dictionary q;q["id"]=int64_t(a->id);q["style"]=style;q["position"]=h.pos;q["angle"]=h.vel.angle();q["speed"]=h.speed;shots.push_back(q);}out["shots"]=shots;}
}
