#include "image_pose_system.h"
#include "image_pose.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>

namespace speed {
namespace {
std::string mode(const BossBodyState &body,const TechniqueState *t,const std::string &technique) {
    if (t && t->combo_waiting && t->stage<TechniqueStage::Finished) return "combo_gap";
    if (body.mode==BossMode::Entrance) return "entrance";
    if (body.mode==BossMode::Phase) return "phase";
    if (body.mode==BossMode::Final) return "final";
    if (body.mode>=BossMode::Defeated) return "defeated";
    if (body.centaurus.leaping) return "leap";
    if (t && t->stage==TechniqueStage::Active) {
        if (technique=="sail_run") return "sail";
        if (technique=="rain" || technique=="shower_chase" || technique=="shower_wall" || technique=="shower_path") return "rain";
        if (technique=="rear_attack" || technique=="stomp") return "strike";
    }
    if (!t) return "idle";
    if (t->stage==TechniqueStage::Windup) return "windup";
    if (t->stage==TechniqueStage::Active) return "shooting";
    if (t->stage==TechniqueStage::Recovery) return "recovery";
    return "idle";
}
}
bool CentaurusImagePoseSystem::refresh(RunRuntime &run,BossBodyState &body) {
    const auto &content=*run.content;
    if (!run.state.enemy_handles.contains(body.actor) || !body.definition || body.definition>content.boss_bodies.size()) return false;
    const auto &definition=content.boss_bodies[body.definition-1];
    if (!definition.boss || definition.boss>content.bosses.size() || content.bosses[definition.boss-1].kind!=1) return false;
    const auto &enemy=run.state.enemies[body.actor.slot];
    const TechniqueState *t=nullptr;
    for (const auto &candidate:run.state.bosses->techniques) if (same_handle(candidate.actor,body.actor) && candidate.stage<TechniqueStage::Finished) {t=&candidate;break;}
    std::string technique;
    uint32_t released=0;
    int64_t id=0;
    double interval=0.4,pose_time=-1;
    if (t && t->definition && t->definition<=content.boss_techniques.size()) {
        const auto &p=content.boss_techniques[t->definition-1];
        technique=p.external_id;id=t->id;
        if (p.kind==8 || p.kind==13) {
            if (const auto *v=std::get_if<CentaurusVolleyState>(&t->detail)) released=v->released;
            if (p.kind==8) for (const auto &v:content.centaurus_volleys) if (v.technique==p.id) {interval=v.interval;break;}
            if (p.kind==13) for (const auto &v:content.centaurus_fans) if (v.technique==p.id) {interval=v.interval;break;}
        } else if (p.kind==11) {
            if (const auto *v=std::get_if<CentaurusPowerState>(&t->detail)) released=v->released;
        } else if (p.kind==15) {
            if (const auto *v=std::get_if<CentaurusSailState>(&t->detail)) released=v->fired;
            for (const auto &v:content.centaurus_sails) if (v.technique==p.id) {interval=v.interval;break;}
        } else if (p.kind==12) pose_time=t->stage==TechniqueStage::Active?std::max(0.0,body.clock-t->started_at-p.warn):0.0;
    }
    double leap=0;
    if (body.centaurus.leaping) {
        const auto found=std::find_if(content.centaurus_bodies.begin(),content.centaurus_bodies.end(),[&](const auto &v){return v.body==body.definition;});
        if (found==content.centaurus_bodies.end()) return false;
        const double progress=std::clamp(body.centaurus.leap_elapsed/std::max(0.001,found->leap_time),0.0,1.0);
        leap=std::sin(godot::Math::PI*progress);
    }
    const auto smooth=[](double a,double b,double value){const double k=std::clamp((value-a)/(b-a),0.0,1.0);return k*k*(3-2*k);};
    double scale_mul=1;godot::Vector2 lift;
    if (technique=="stomp" && t) {
        if (t->stage==TechniqueStage::Windup) {const double w=smooth(0,.5,enemy.charge);scale_mul=1+.07*w;lift=godot::Vector2::from_angle(enemy.facing)*(-enemy.radius*.1*w);}
        else {
            const double a=body.clock-t->started_at-content.boss_techniques[t->definition-1].warn;
            if (a>=0 && a<.35) {const double f=a<.05?smooth(0,.05,a):1-smooth(.05,.35,a);scale_mul=a<.05?1.07+(.96-1.07)*a/.05:.96+.04*smooth(.05,.35,a);lift=godot::Vector2::from_angle(enemy.facing)*(enemy.radius*.08*f);}
        }
    } else if (technique=="rain" && t) {
        double last=-1;
        for (const auto &rule:content.centaurus_rains) if (rule.technique==t->definition)
            for (uint32_t v=0;v<rule.traces;++v) for (uint32_t i=0;i<4;++i) {
                const double at=t->started_at+.08+v*(content.boss_techniques[t->definition-1].warn-.16)/std::max(1u,rule.traces)+i*.035;
                if (at<=body.clock) last=std::max(last,at);
            }
        if (last>=0) lift=godot::Vector2::from_angle(enemy.facing)*(-enemy.radius*.05*(1-smooth(0,.12,body.clock-last)));
    }
    const double scale=enemy.radius/135.0*(1.0+0.12*leap)*scale_mul;
    const godot::Transform2D root(enemy.facing-godot::Math::PI*0.5,godot::Vector2(scale,scale),0.0,enemy.pos+godot::Vector2(0,-65.0*leap)+lift);
    auto clock=body.centaurus.image_pose;
    const double dt=clock.last_body_clock<0?0:std::max(0.0,body.clock-clock.last_body_clock);
    if (!CentaurusImagePoseEvaluator::step(content.centaurus_image_pose,clock,id,technique,mode(body,t,technique),enemy.charge,dt,pose_time,released,interval,root,body.image_parts)) return false;
    clock.last_body_clock=body.clock;body.centaurus.image_pose=clock;
    if (body.mode>=BossMode::Defeated) for (auto &part:body.image_parts) part.visible=false;
    return true;
}
}
