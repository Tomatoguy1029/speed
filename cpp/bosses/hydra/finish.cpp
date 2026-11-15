#include "../../output/event_builder.h"
#include "finish.h"
#include "body.h"
#include "normal_attack.h"
#include "regrow.h"
#include "../flow/technique_runner.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
namespace speed {
void HydraFinish::begin(RunRuntime &r,BossBodyState &b) {
    for (uint32_t i=0;i<r.state.bosses->techniques.size();++i) if (HydraNormalAttack::body(r,r.state.bosses->techniques[i].actor)==&b) TechniqueRunner::cancel(r,r.state.bosses->handles.at(i));b.hydra->growth_left=b.hydra->separation_left=0;b.hydra->final_beams.clear();godot::Dictionary cue;cue["id"]=r.state.enemy_handles.entity_id(b.actor);cue["cue"]="final_strike_started";cue["technique"]="";cue["neck"]=-1;cue["position"]=r.state.enemies[b.actor.slot].pos;cue["duration"]=0;cue["damage"]=0;cue["next_count"]=0;cue["target"]="hydra";FrameBuilder::append(r,"hydra_cue",cue);
}
void HydraFinish::tick(RunRuntime &r,BossBodyState &b,double dt) {
    auto &s=r.state;auto &body=s.enemies[b.actor.slot];const auto &p=r.content->boss_bodies[b.definition-1];const auto &h=HydraBody::rule(r,b);b.hydra->attack_field_advance=true;b.final_elapsed=std::max(0.0,s.time-b.final_started);const double k=std::clamp(b.final_elapsed/b.final_charge,0.,1.),widen=std::clamp((b.final_elapsed-(b.final_charge-p.final_widen_time))/p.final_widen_time,0.,1.);b.final_width=p.final_warn_width+(p.final_beam_width-p.final_warn_width)*widen*widen;const double reach=godot::Vector2(h.arena_x,h.arena_y).length()*1.5;body.guard=1;const TrackingPolicy tracking{s.draw.tracing,body.held,s.enemy_handles.contains(body.pump_owner)};
    const auto head=[&](HydraNeckState &n) {if (!HydraRegrow::alive(r,n)) return;auto &part=s.enemies[n.actor.slot];part.guard=1;if (b.hydra->separated) {n.velocity={};if (!tracking.locked()) n.angle+=angle_difference((s.ship_pos-n.free_pos).angle()-n.angle)*std::min(1.,dt*6);}else {HydraNormalAttack::aim(r,b,n,(s.ship_pos-HydraBody::neck_base(r,b,n)).angle(),dt);n.length+=std::clamp(h.neck_rest-n.length,-h.neck_rest*dt,h.neck_rest*dt);}n.glow=k;part.pos=HydraBody::head_position(r,b,n);part.facing=n.angle;const auto direction=tracking.locked()?godot::Vector2::from_angle(n.angle):(s.ship_pos-part.pos).normalized();const std::vector<godot::Vector2> points{part.pos,part.pos+direction*reach};auto it=b.hydra->final_beams.find(n.id);
        if (it==b.hydra->final_beams.end()) {HazardState hazard;hazard.pos=part.pos;hazard.damage=0;hazard.delay=std::max(0.,b.final_charge-p.final_widen_time-b.final_elapsed);hazard.duration=b.final_charge+10;hazard.shape=HydraShapeHazard{points,b.final_width};auto &shape=std::get<HydraShapeHazard>(hazard.shape);shape.delay=hazard.delay;shape.life=hazard.duration;AttackSpec spec;spec.observation_id=b.final_observation_id;spec.owner.live_source=n.actor;spec.owner.attached=true;spec.boss=s.bosses->body_handles.at(uint32_t(&b-s.bosses->bodies.data()));spec.cause=Cause::Beam;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBoss;spec.policies|=policy(EndPolicy::CancelWithParticipant);b.hydra->final_beams[n.id]=AttackSystem::emit_hazard(s,hazard,spec);it=b.hydra->final_beams.find(n.id);}
        if (const auto *a=AttackSystem::get(s,it->second)) {auto &hazard=s.hazards[a->row];auto &shape=std::get<HydraShapeHazard>(hazard.shape);shape.points=points;shape.width=b.final_width;hazard.pos=part.pos;}
    };
    for (auto &n:b.hydra->necks) head(n);if (b.hydra->separated) head(b.hydra->bearer);if (!b.final_landed && b.final_elapsed>=b.final_charge) {b.final_landed=true;EventBuilder::audio(r,"scene.time_up.strike",r.state.enemies[b.actor.slot].pos);TechniqueRunner::observe_scripted(r,b,"final_strike","final_strike_replay",ObservationEvent::Execute);s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest damage;damage.observation_id=b.final_observation_id;damage.amount=s.ship.hp+1;damage.cause=Cause::FinalStrike;damage.source=body.definition+1;CombatResolver::ship_damage(r,damage);TechniqueRunner::finish_scripted(r,b);}
}
}
