#include "arrow_shower.h"
#include "../flow/phase_controller.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusShowerDefinition &rule(const ContentBundle &c,const TechniqueState &t) {return *std::find_if(c.centaurus_showers.begin(),c.centaurus_showers.end(),[&](const auto &v){return v.technique==t.definition;});}
void cue(RunRuntime &r,const TechniqueState &t,const char *name,const godot::Vector2 *at=nullptr) {const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=at?*at:e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);}
}
bool CentaurusShower::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && PhaseController::find(r,actor) && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && (std::find_if(r.content->centaurus_showers.begin(),r.content->centaurus_showers.end(),[&](const auto &v){return v.technique==definition;})->pattern!=2 || PhaseController::find(r,actor)->phase>=2);}
void CentaurusShower::begin(RunRuntime &r,TechniqueState &t) {t.detail=CentaurusShowerState{};t.started_at=PhaseController::find(r,t.actor)->clock;r.state.enemies[t.actor.slot].vel={};cue(r,t,"telegraph");}
void CentaurusShower::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=r.content->boss_techniques[t.definition-1];
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};const auto target=t.stage==TechniqueStage::Windup?r.state.ship_pos:r.state.enemy_aim;const auto &d=r.content->bosses[p.boss-1];
    if (!tracking.locked()) e.facing+=std::clamp(angle_difference((target-e.pos).angle()-e.facing),-d.turn*dt,d.turn*dt);
    auto *body=PhaseController::find(r,t.actor);const double now=body->clock,base=t.started_at+p.warn;if (now<base) return;
    const auto &v=rule(*r.content,t);auto &s=std::get<CentaurusShowerState>(t.detail);
    if (!s.launched) {
        s.launched=true;t.stage=TechniqueStage::Active;cue(r,t,"shower_launched");
        if (v.pattern==2) {
            const auto direction=r.state.ship.vel.length()>=1.0?r.state.ship.vel.normalized():r.state.ship.heading;const auto center=r.state.ship_pos+direction*v.ahead;
            for (uint32_t j=0;j<v.count;++j) {const double offset=(double(j)-double(v.count-1)*0.5)*body->centaurus.path_side;s.marks.push_back({center+direction.orthogonal()*offset*v.spacing,base+j*v.step});}
            body->centaurus.path_side*=-1;
        } else if (v.pattern==1) {
            const auto toward=tracking.target(e.pos,e.facing,r.state.ship_pos)-e.pos;const auto direction=toward.length_squared()>0?toward.normalized():godot::Vector2::from_angle(e.facing);const auto center=e.pos+direction*std::clamp(double(toward.length())*v.wall_ratio,v.wall_min,v.wall_max);
            for (uint32_t j=0;j<v.count;++j) {const double offset=double(j)-double(v.count-1)*0.5;s.marks.push_back({center+direction.orthogonal()*offset*v.spacing,base+std::abs(offset)*v.step});}
        }
    }
    if (v.pattern==0) while (s.placed<v.count && now>=base+s.placed*v.interval) {s.marks.push_back({r.state.ship_pos+r.state.ship.vel*v.lead,base+s.placed*v.interval});++s.placed;}
    bool finished=v.pattern!=0 || s.placed>=v.count;
    for (auto &mark:s.marks) {
        const double age=now-mark.at;if (age<0) {finished=false;continue;}
        if (!mark.shown) {mark.shown=true;cue(r,t,"shower_mark",&mark.center);}
        if (age<v.mark_time+v.rain_time) finished=false;
        if (age<v.mark_time || mark.landed) continue;
        mark.landed=true;cue(r,t,"shower_landed",&mark.center);const double reach=v.radius+r.state.ship_config.ship_radius;
        if (r.state.observations.check(t.observation_id,r.state.ship_pos.distance_squared_to(mark.center)<=reach*reach)) {ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=p.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::ArrowShower;request.source=e.definition+1;request.technique=t.definition;CombatResolver::ship_damage(r,request);}
    }
    if (finished) {s.marks.clear();t.stage=TechniqueStage::Recovery;t.remaining=p.recover;cue(r,t,"recovery_started");}
}
bool CentaurusShower::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=std::get_if<CentaurusShowerState>(&t.detail);if (!v) return false;const auto &p=rule(c,t);if (v->placed>p.count || v->marks.size()>p.count) return false;for (const auto &mark:v->marks) if (!mark.center.is_finite() || !std::isfinite(mark.at) || mark.at<0 || (mark.landed && !mark.shown)) return false;return true;}
godot::Dictionary CentaurusShower::snapshot(const RunRuntime &r,const TechniqueState &t) {
    const auto &p=rule(*r.content,t);const auto &v=std::get<CentaurusShowerState>(t.detail);godot::Dictionary out;godot::Array marks;
    for (const auto &mark:v.marks) {godot::Dictionary row;row["center"]=mark.center;row["at"]=mark.at;row["shown"]=mark.shown;row["landed"]=mark.landed;marks.push_back(row);}
    out["marks"]=marks;out["placed"]=v.placed;out["launched"]=v.launched;out["pattern"]=p.pattern;out["mark_time"]=p.mark_time;out["rain_time"]=p.rain_time;out["linger"]=p.linger;out["radius"]=p.radius;out["technique"]=godot::String(r.content->boss_techniques[t.definition-1].external_id.c_str());out["arrow_count"]=PhaseController::find(r,t.actor)->phase==1?2:3;
    const auto &d=r.content->light_arrows[p.projectile-1];out["arrow_radius"]=p.arrow_radius*d.flight_scale;out["arrow_length"]=p.arrow_length*d.flight_scale;out["effect_tint"]=godot::Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a);out["arrow_color"]=godot::Color(d.arrow_r,d.arrow_g,d.arrow_b,d.arrow_a);out["shot_length_scale"]=d.shot_length_scale;out["shot_width_scale"]=d.shot_width_scale;out["core_width"]=d.core_width;return out;
}
}
