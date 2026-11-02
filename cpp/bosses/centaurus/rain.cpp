#include "rain.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/motion_math.h"
#include "../../systems/tracking_policy.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusRainDefinition &rule(const ContentBundle &c,const TechniqueState &t) {return *std::find_if(c.centaurus_rains.begin(),c.centaurus_rains.end(),[&](const auto &v){return v.technique==t.definition;});}
godot::Vector2 point(const CentaurusRainDefinition &p,const CentaurusRainTrace &trace,double distance) {
    if (std::abs(p.trace_bend)<0.001) return trace.start+trace.direction*distance;
    const double radius=p.trace_length/p.trace_bend;const auto center=trace.start+trace.direction.orthogonal()*double(trace.turn)*radius;
    return center+(trace.start-center).rotated(-trace.turn*distance/radius);
}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {
    const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);
}
}
bool CentaurusRain::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusRain::begin(RunRuntime &r,TechniqueState &t) {t.detail=CentaurusRainState{};t.aim=r.state.enemy_aim;t.previous_ship=r.state.ship_pos;r.state.enemies[t.actor.slot].vel={};cue(r,t,"telegraph");}
void CentaurusRain::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    if (command!=TechniqueCommand::BeginRain || t.stage!=TechniqueStage::Windup) return;
    auto &v=std::get<CentaurusRainState>(t.detail);v.left=rule(*r.content,t).traces;v.next_at=PhaseController::find(r,t.actor)->clock;t.stage=TechniqueStage::Active;cue(r,t,"rain_started");
}
void CentaurusRain::step(RunRuntime &r,TechniqueState &t,double dt) {
    const auto &p=rule(*r.content,t);const auto &base=r.content->boss_techniques[t.definition-1];auto &v=std::get<CentaurusRainState>(t.detail);auto &e=r.state.enemies[t.actor.slot];auto *body=PhaseController::find(r,t.actor);const double now=body->clock;
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    if (t.stage==TechniqueStage::Windup) {e.vel={};const auto aim=base.track_during_warn?r.state.enemy_aim:t.aim;const auto &boss=r.content->bosses[base.boss-1];if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference((aim-e.pos).angle()-e.facing),-boss.turn*dt,boss.turn*dt);return;}
    CentaurusBody::position_tick(r,*body,dt);
    const double speed=std::max(1.0,p.trace_speed),length=p.trace_length,gap=std::max(1.0,p.arrow_gap);
    if (v.left && now>=v.next_at) {
        const auto ship=r.state.ship_pos;const auto heading=r.state.ship.vel.length()>60?r.state.ship.vel.normalized():(ship-r.state.enemies[t.actor.slot].pos).normalized();
        CentaurusRainTrace trace;trace.start=ship+heading*p.forward;trace.direction=(ship-trace.start).normalized();trace.turn=v.traces.size()%2==0?1:-1;trace.started=now;
        double reach=p.forward;if (std::abs(p.trace_bend)>=0.001) {const double radius=length/std::abs(p.trace_bend);reach=2*radius*std::asin(std::min(1.0,reach/(2*radius)));}
        const auto probe=point(p,trace,reach);trace.direction=trace.direction.rotated(angle_difference((ship-trace.start).angle()-(probe-trace.start).angle()));
        v.traces.push_back(trace);--v.left;v.next_at=now+length/speed+p.trace_gap;cue(r,t,"rain_trace");
    }
    bool all_landed=true;
    for (auto &trace:v.traces) {
        const double run=now-trace.started,head=std::clamp(run*speed,0.0,length);
        while (trace.next_drop<=head) {v.expire_at=std::max(v.expire_at,trace.started+trace.next_drop/speed+p.drop_delay+p.fall+p.linger+0.15);trace.next_drop+=gap;}
        const double land=std::clamp((run-p.drop_delay-p.fall)*speed,0.0,length);
        if (!trace.hit && land>trace.landed && CollisionQuery::touches(SegmentCircle{point(p,trace,trace.landed),point(p,trace,land),p.circle_radius},{r.state.ship_pos,r.state.ship_pos,r.state.ship_config.ship_radius},{true,false})) {
            trace.hit=true;ShipDamageRequest request;request.amount=base.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::Rain;request.source=r.state.enemies[t.actor.slot].definition+1;request.technique=t.definition;CombatResolver::ship_damage(r,request);
        }
        trace.landed=land;if (land<length) all_landed=false;
    }
    if (!v.left && all_landed && now>v.expire_at) {v.traces.clear();t.stage=TechniqueStage::Recovery;t.remaining=base.recover;cue(r,t,"recovery_started");}
}
bool CentaurusRain::validate(const TechniqueState &t,const ContentBundle &c) {
    const auto *v=std::get_if<CentaurusRainState>(&t.detail);if (!v) return false;const auto &p=rule(c,t);
    if (v->left>p.traces || v->traces.size()>p.traces || !std::isfinite(v->next_at) || !std::isfinite(v->expire_at) || v->next_at<0 || v->expire_at<0) return false;
    for (const auto &trace:v->traces) if (!trace.start.is_finite() || !trace.direction.is_finite() || !std::isfinite(trace.started) || !std::isfinite(trace.next_drop) || !std::isfinite(trace.landed) || trace.started<0 || trace.next_drop<0 || trace.landed<0 || trace.landed>p.trace_length || (trace.turn!=1 && trace.turn!=-1)) return false;
    return true;
}
godot::Dictionary CentaurusRain::snapshot(const RunRuntime &r,const TechniqueState &t) {
    const auto &p=rule(*r.content,t);const auto &v=std::get<CentaurusRainState>(t.detail);godot::Dictionary out;godot::Array traces;
    for (const auto &trace:v.traces) {godot::Dictionary row;row["start"]=trace.start;row["direction"]=trace.direction;row["turn"]=trace.turn;row["started"]=trace.started;row["landed"]=trace.landed;row["next_drop"]=trace.next_drop;row["hit"]=trace.hit;traces.push_back(row);}
    out["traces"]=traces;out["left"]=v.left;out["next_at"]=v.next_at;out["expire_at"]=v.expire_at;
    out["trace_length"]=p.trace_length;out["trace_speed"]=std::max(1.0,p.trace_speed);out["trace_bend"]=p.trace_bend;out["circle_radius"]=p.circle_radius;out["drop_delay"]=p.drop_delay;out["fall"]=p.fall;out["linger"]=p.linger;out["drop_height"]=p.drop_height;out["fade"]=p.fade;out["arrow_gap"]=std::max(1.0,p.arrow_gap);out["arrows_per_step"]=p.arrows_per_step;
    const auto &d=r.content->light_arrows[p.projectile-1];out["arrow_radius"]=p.arrow_radius*d.flight_scale;out["arrow_length"]=p.arrow_length*d.flight_scale;out["effect_tint"]=godot::Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a);out["arrow_color"]=godot::Color(d.arrow_r,d.arrow_g,d.arrow_b,d.arrow_a);out["shot_length_scale"]=d.shot_length_scale;out["shot_width_scale"]=d.shot_width_scale;out["core_width"]=d.core_width;
    return out;
}
}
