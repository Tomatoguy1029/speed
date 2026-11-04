#include "inhale.h"
#include "body.h"
#include "pose.h"
#include "picaro.h"
#include "screen_staging.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/beam.h"
#include "../../systems/attacks/bolt.h"
#include "../../systems/attack_system.h"
#include "../../systems/enemy_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const DracoInhaleDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_inhales.begin(),r.content->draco_inhales.end(),[&](const auto &p){return p.technique==t.definition;});}
void stretch(RunRuntime &r,TechniqueState &t) {auto &b=*PhaseController::find(r,t.actor);const auto &e=r.state.enemies[t.actor.slot];b.draco.override_points=DracoTechnique::neutral(r,b,e.pos,e.facing);}
void extend(RunRuntime &r,const TechniqueState &t) {const auto &s=std::get<DracoInhaleState>(std::get<DracoTechniqueState>(t.detail).move);const auto *a=AttackSystem::get(r.state,s.beam);if (!a || a->pool!=AttackPool::Hazard || !same_handle(a->spec.owner.live_source,t.actor)) return;auto &h=r.state.hazards[a->row];const double duration=rule(r,t).beam_extend,length=r.content->boss_techniques[t.definition-1].reach*(duration>0?std::clamp(double(h.time-h.delay)/duration,0.0,1.0):1);std::get<BeamHazard>(h.shape).length=length;}
}
void DracoInhale::begin(RunRuntime &r,TechniqueState &t) {auto &v=std::get<DracoTechniqueState>(t.detail);v.move=DracoInhaleState{};auto &s=std::get<DracoInhaleState>(v.move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];DracoPicaro::pause(r,b,true);s.direction=(DracoTechnique::predict(r,t.actor,0,DracoBody::rule(r,b).aim_lead_cap)-e.pos).normalized();if (s.direction.is_zero_approx()) s.direction=godot::Vector2::from_angle(e.facing);t.direction=s.direction;e.facing=s.direction.angle();DracoScreenStaging::side_entry(r,t,s.staging);}
void DracoInhale::windup(RunRuntime &r,TechniqueState &t) {auto &v=std::get<DracoTechniqueState>(t.detail);auto &s=std::get<DracoInhaleState>(v.move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];const double progress=std::clamp(v.stage_time/r.content->boss_techniques[t.definition-1].warn,0.0,1.0);DracoScreenStaging::advance_side(r,t,s.staging,progress);
    if (progress>=0.4) {const auto target=DracoTechnique::predict(r,t.actor,0,DracoBody::rule(r,b).aim_lead_cap);e.facing=godot::Math::lerp_angle(e.facing,double((target-e.pos).angle()),DracoTechnique::smooth((progress-0.4)/0.4));const auto straight=DracoTechnique::neutral(r,b,e.pos,e.facing);
        // Sourceはoverride中のbody_poseを保持するため、固定のtrailから取る。
        auto from=b.draco.trail.empty()?straight:DracoPose::samples(b.draco.trail,uint32_t(straight.size()));const auto head=e.pos,origin=from.front();
        // 加減算をoffsetへまとめると、折返しの補正が変わる。
        for (auto &p:from) p=p+head-origin;DracoTechnique::blend(r,b,from,straight,DracoTechnique::smooth((progress-0.4)/0.6));}
    t.direction=godot::Vector2::from_angle(e.facing);
}
void DracoInhale::active(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=std::get<DracoTechniqueState>(t.detail);auto &s=std::get<DracoInhaleState>(v.move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &common=r.content->boss_techniques[t.definition-1];auto mouth=DracoTechnique::mouth(r,b);stretch(r,t);const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    if (v.stage_time<p.inhale_time) {
        if (!s.caught) {e.facing=tracking.angle(e.facing,godot::Math::rotate_toward(e.facing,double((r.state.ship_pos-e.pos).angle()),1.2*dt));t.direction=godot::Vector2::from_angle(e.facing);}
        const auto toward=mouth-r.state.ship_pos;if (toward.length()<p.pull_range && !s.caught) {r.state.ship_pos+=toward.normalized()*std::min(double(toward.length()),p.pull_speed*dt);r.state.ship.pos=r.state.ship_pos;
            if (DracoTechnique::observe_contact(r,t,toward.length()<p.mouth_radius+r.state.ship_config.ship_radius)) {s.caught=true;ShipDamageRequest hit;hit.observation_id=t.observation_id;hit.amount=p.bite_damage;hit.scale=DamageScale::AtkScale;hit.cause=Cause::InhaleBite;hit.source=e.definition+1;hit.technique=t.definition;CombatResolver::ship_damage(r,hit);r.state.ship_pos=r.state.ship.pos=mouth+t.direction*(b.draco.head_scale*100);r.state.ship.vel=t.direction*1000;r.state.ship.invuln=std::max(r.state.ship.invuln,1.2);r.state.steering_locked=true;s.release_at=b.clock+0.8;}
        }
        for (const auto &m:b.draco.picaro) {if (!r.state.enemy_handles.contains(m.actor) || r.state.enemies[m.actor.slot].dead) continue;auto &copy=r.state.enemies[m.actor.slot];const auto delta=mouth-copy.pos;copy.pos+=delta.normalized()*std::min(double(delta.length()),p.picaro_pull_speed*dt);if (delta.length()<b.draco.head_scale*80) {s.stars+=m.stars;EnemySystem::mark_dead(r,m.actor);}}
        if (s.caught && b.clock>=s.release_at) r.state.steering_locked=false;return;
    }
    if (r.state.steering_locked) {if (b.clock<s.release_at) {v.stage_time=t.elapsed=p.inhale_time;return;}r.state.steering_locked=false;}
    if (s.spent) {extend(r,t);return;}s.spent=true;s.direction=(DracoTechnique::predict(r,t.actor,0,DracoBody::rule(r,b).aim_lead_cap)-e.pos).normalized();if (s.direction.is_zero_approx()) s.direction=t.direction;t.direction=s.direction;e.facing=s.direction.angle();mouth=DracoTechnique::mouth(r,b);const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    BeamParams beam;beam.position=mouth;beam.angle=t.direction.angle();beam.length=common.reach;beam.half_width=common.width*0.5;beam.delay=p.beam_warn;beam.active=p.beam_time;beam.damage=common.damage*r.state.combat_config.atk_scale;beam.color=godot::Color::html("d4bbff");beam.style=BeamStyle::Draco;beam.owner=t.actor;beam.technique=ticket;beam.definition=p.beam_definition;s.beam=BeamSystem::emit(r,beam);extend(r,t);
    if (!s.stars && r.state.control.lab_mode) s.stars=b.draco.lab_inhale_stars;
    uint32_t remaining=uint32_t(std::min(uint64_t(p.comet_cap),uint64_t(s.stars)*p.comets_per_star));std::vector<const DracoInhaleArc *> arcs;for (const auto &a:r.content->draco_inhale_arcs) if (a.technique==t.definition) arcs.push_back(&a);
    for (size_t index=0;index<arcs.size();++index) {const auto &arc=*arcs[index];const uint32_t quota=std::min(arc.count,uint32_t(std::ceil(double(remaining)/(arcs.size()-index))));for (uint32_t j=0;j<quota;++j) {const double angle=t.direction.angle()+(arc.angle_degrees-arc.spread_degrees+2*arc.spread_degrees*double(j)/std::max(1u,quota-1))*3.141592653589793/180;BoltParams bolt;bolt.position=mouth+godot::Vector2(arc.offset_x,arc.offset_y).rotated(t.direction.angle())+godot::Vector2::from_angle(angle)*arc.radius;bolt.angle=angle;bolt.speed=p.comet_speed;bolt.damage=common.damage*0.6*r.state.combat_config.atk_scale;bolt.owner=t.actor;bolt.technique=ticket;bolt.definition=p.projectile;BoltSystem::emit(r,bolt);}remaining-=quota;}s.stars=0;
}
void DracoInhale::recover(RunRuntime &r,TechniqueState &t) {stretch(r,t);}
void DracoInhale::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &s=std::get<DracoInhaleState>(std::get<DracoTechniqueState>(t.detail).move);const auto *a=AttackSystem::get(r.state,s.beam);if (a && same_handle(a->spec.owner.live_source,t.actor)) AttackSystem::end(r.state,s.beam,cancelled?AttackEndReason::TechniqueCancel:AttackEndReason::TechniqueEnd);r.state.steering_locked=false;s.stars=0;}
bool DracoInhale::validate(const DracoInhaleState &s) {return s.direction.is_finite() && std::isfinite(s.release_at) && s.release_at>=0 && DracoScreenStaging::validate_side(s.staging);}
godot::Dictionary DracoInhale::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &s=std::get<DracoInhaleState>(std::get<DracoTechniqueState>(t.detail).move);godot::Dictionary out;out["staging_side"]=s.staging.side;out["spent"]=s.spent;out["caught"]=s.caught;out["release_at"]=s.release_at;out["inhale_stars"]=s.stars;out["beam_direction"]=s.direction;out["steering_locked"]=r.state.steering_locked;out["mouth_open"]=t.stage==TechniqueStage::Active?1.35:t.stage==TechniqueStage::Windup?0.8:0;const auto *a=AttackSystem::get(r.state,s.beam);out["beam_alive"]=a!=nullptr;out["beam_length"]=a?double(std::get<BeamHazard>(r.state.hazards[a->row].shape).length):0;return out;}
}
