#include "boss_contact.h"
#include "boss_contact_feedback.h"
#include "combat_resolver.h"
#include "collision_query.h"
#include "motion_math.h"
#include "../runtime/run_runtime.h"
#include "../bosses/monoceros/charge.h"
#include "../bosses/monoceros/kick.h"
#include "../bosses/monoceros/sweep.h"
#include "../bosses/monoceros/lance.h"
#include "../bosses/monoceros/return_charge.h"
#include "../bosses/monoceros/horn_dance.h"
#include "../bosses/centaurus/stomp.h"
#include "../output/event_builder.h"
#include "../state/boss_states.h"
#include "../content/content_bundle.h"
#include "../bosses/monoceros/state.h"
#include <algorithm>
namespace speed {
namespace {
ShipDamageResult hit(RunRuntime &r,EnemyHandle actor,uint32_t definition,int64_t observation,Cause cause) {
    ShipDamageRequest request;request.observation_id=observation;request.amount=r.content->boss_techniques[definition-1].damage;
    request.scale=DamageScale::AtkScale;request.cause=cause;request.source=r.state.enemies[actor.slot].definition+1;request.technique=definition;
    const auto result=CombatResolver::ship_damage(r,request);EventBuilder::flush_combat(r);return result;
}
bool alive(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    return r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && definition && definition<=r.content->boss_techniques.size();
}
bool mono_shape(const RunRuntime &r,const TechniqueState &t,ContactShape &shape) {
    const auto &p=r.content->boss_techniques[t.definition-1];if (t.stage!=TechniqueStage::Active) return false;
    godot::PackedVector2Array points;
    switch (p.kind) {
    case 0:points=MonocerosCharge::horn(r,t);break;
    case 1:points=MonocerosKick::horn(r,t);break;
    case 2:if (t.detail.get<MonocerosSweepState>().stage!=MonocerosSweepState::Stage::Swing) return false;points=MonocerosSweep::horn(r,t);break;
    case 3:if (t.detail.get<MonocerosLanceState>().stage!=MonocerosLanceState::Stage::Run) return false;points=MonocerosLance::horn(r,t);break;
    case 4:if (t.detail.get<MonocerosReturnState>().stage!=MonocerosReturnState::Stage::Run) return false;points=MonocerosReturn::horn(r,t);break;
    case 6:if (t.detail.get<MonocerosDanceState>().stage!=MonocerosDanceState::Stage::Run) return false;points=MonocerosDance::horn(r,t);break;
    default:return false;
    }
    if (points.size()<2) return false;
    const auto &b=r.content->bosses[p.boss-1];shape=SegmentCircle{points[0],points[1],(p.kind==3?p.width:b.horn_width)*0.5};return true;
}
bool centaurus_shape(const RunRuntime &r,const TechniqueState &t,ContactShape &shape,Cause &cause) {
    const auto &p=r.content->boss_techniques[t.definition-1];const auto &e=r.state.enemies[t.actor.slot];
    if (t.stage!=TechniqueStage::Active) return false;
    if (p.kind==12) {
        const auto data=CentaurusStomp::snapshot(r,t);
        shape=Fan{data["center"],double(data["range_radius"]),e.facing,double(data["half_angle"])};cause=Cause::Stomp;return true;
    }
    if (p.kind==9) {
        const auto found=std::find_if(r.content->centaurus_rears.begin(),r.content->centaurus_rears.end(),[&](const auto &v){return v.technique==t.definition;});
        if (found==r.content->centaurus_rears.end()) return false;
        shape=PointCircle{e.pos-godot::Vector2::from_angle(e.facing)*found->back_offset,found->radius};cause=Cause::RearAttack;return true;
    }
    return false;
}
}
void BossContactSystem::register_landing(RunRuntime &r,EnemyHandle actor,godot::Vector2 center,double radius,uint32_t technique,int64_t observation) {
    if (!alive(r,actor,technique) || radius<0) return;
    r.state.boss_landings.push_back({actor,center,radius,technique,observation,false});
    // なぞり中も着地の時点で判定する。通常移動時の後続判定と二重に当てない。
    auto &entry=r.state.boss_landings.back();
    if (CollisionQuery::touches(PointCircle{center,radius},{r.state.ship.pos,r.state.ship.pos,r.state.ship_config.ship_radius},{true,false})) {
        entry.attempted=true;hit(r,actor,technique,observation,Cause::Pounce);
    }
}
void BossContactSystem::clear_landings(RunRuntime &r) {r.state.boss_landings.clear();}
void BossContactSystem::normal_contact(RunRuntime &r,EnemyHandle actor,godot::Vector2 impact) {
    if (!r.state.enemy_handles.contains(actor)) return;
    ShipDamageRequest request;request.amount=r.state.control.boss_touch_damage;request.cause=Cause::Touch;
    request.source=r.state.enemies[actor.slot].definition+1;request.scale=DamageScale::None;
    CombatResolver::ship_damage(r,request);EventBuilder::flush_combat(r);

}
bool boss_contact_white(const RunRuntime &r) {
    const auto &s=r.state;
    if (s.ship.hurt<=0 || !s.lifecycle.has_damage || !s.lifecycle.last_damage.accepted) return false;
    // 既存の被弾記録を読むため、保持復帰でも白色化の種類を維持する。
    switch (s.lifecycle.last_request.cause) {
    case Cause::Touch:case Cause::Horn:case Cause::Stomp:case Cause::RearAttack:case Cause::Pounce:return true;
    default:return false;
    }
}
bool BossContactSystem::resolve(RunRuntime &r,godot::Vector2 from,godot::Vector2 to,double ship_radius) {
    const ShipMotion motion{from,to,ship_radius};
    for (auto &entry:r.state.boss_landings) {
        if (!alive(r,entry.actor,entry.technique) || !CollisionQuery::touches(PointCircle{entry.center,entry.radius},motion,{true,true})) continue;
        if (!entry.attempted) {entry.attempted=true;hit(r,entry.actor,entry.technique,entry.observation,Cause::Pounce);}
    }
    for (auto &t:r.state.bosses->techniques) {
        if (!alive(r,t.actor,t.definition)) continue;
        ContactShape shape;Cause cause=Cause::Horn;
        const bool active=mono_shape(r,t,shape) || centaurus_shape(r,t,shape,cause);
        if (!active || !CollisionQuery::touches(shape,motion,{true,true})) continue;
        if (!t.hit && r.state.observations.check(t.observation_id,true)) {
            const auto result=hit(r,t.actor,t.definition,t.observation_id,cause);
            if (cause!=Cause::Stomp || result.accepted) t.hit=true;
        }
    }
    return false;
}
}
