#include "flame_aim.h"
#include "flames.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include "../../systems/field.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
void CanisFlameAim::begin(RunRuntime &r,TechniqueState &t,CanisFlameAimState &v) {v={};t.stage=TechniqueStage::Windup;t.locked=false;r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"telegraph");}
bool CanisFlameAim::advance(RunRuntime &r,TechniqueState &t,CanisFlameAimState &v,const CanisFlameAimSettings &p,double dt) {
    if (v.done) return true;
    if (!v.fired) {
        if (!t.locked) {const double lead=p.remaining_lead?std::max(0.0,p.warn-v.age):p.lead;if (r.content->boss_techniques[t.definition-1].track_during_warn) {t.aim=r.state.ship_pos+r.state.ship.vel*lead;CanisTechnique::face(r,t,t.aim,p.turn,dt);}if (v.age>=p.warn-p.lock) CanisTechnique::lock_aim(r,t,true);}
        v.age+=dt;if (v.age<p.warn) return false;t.locked=true;t.direction=godot::Vector2::from_angle(r.state.enemies[t.actor.slot].facing);if (auto *b=PhaseController::find(r,t.actor)) CanisFlames::begin(r,*b,p.flame,{},0,t.definition);v.fired=true;v.age=0;t.stage=TechniqueStage::Active;CanisTechnique::cue(r,t,"sirius");return false;
    }
    v.age+=dt;v.done=v.age>=r.content->canis_flames[p.flame-1].duration;return v.done;
}
double CanisFlameAim::progress(const CanisFlameAimState &v,double warn) {return v.fired?0:std::clamp(v.age/std::max(warn,0.001),0.0,1.0);}
bool CanisFlameAim::validate(const CanisFlameAimState &v) {return std::isfinite(v.age) && v.age>=0 && (!v.done || v.fired);}
godot::Dictionary CanisFlameAim::snapshot(const RunRuntime &r,const TechniqueState &t,const CanisFlameAimState &v,const CanisFlameAimSettings &p) {const auto &flame=r.content->canis_flames[p.flame-1];godot::Dictionary out;out["fired"]=v.fired;out["aim_done"]=v.done;out["aim_age"]=v.age;out["windup_progress"]=progress(v,p.warn);out["beam_width"]=flame.width;out["warning_length"]=flame.length;double length=flame.length;if (r.state.enemy_handles.contains(t.actor)) {const auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*0.84;if (const auto hit=FieldSystem::first_body_hit(r,from,from+godot::Vector2::from_angle(e.facing)*length,0)) length*=hit->t;}out["beam_length"]=length;return out;}
}
