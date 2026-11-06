#include "tail_sweep.h"
#include "body.h"
#include "pose.h"
#include "tail_motion.h"
#include "../flow/phase_controller.h"
#include "../../systems/collision_query.h"
#include "../../systems/combat_resolver.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793;
const DracoTailSweepDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_tail_sweeps.begin(),r.content->draco_tail_sweeps.end(),[&](const auto &d){return d.technique==t.definition;});}
DracoTailTiming timing(const RunRuntime &r,const TechniqueState &t) {const auto &p=r.content->boss_techniques[t.definition-1];return {p.warn,p.active,p.recover};}
void place(RunRuntime &r,const TechniqueState &t,double clock,std::vector<godot::Vector2> *out=nullptr) {const auto &s=std::get<DracoTailSweepState>(t.detail.get<DracoTechniqueState>().move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];double facing=s.facing;auto points=DracoTailMotion::sweep(s.base,s.facing,s.origin,DracoBody::rule(r,b).body_length,timing(r,t),clock,&facing);e.pos=points.front();e.facing=facing;if (out) *out=points;b.draco->override_points=std::move(points);}
}
void DracoTailSweep::begin(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoTailSweepState{};auto &s=std::get<DracoTailSweepState>(v.move);const auto &e=r.state.enemies[t.actor.slot];s.origin=e.pos;s.facing=e.facing;{const auto &b=*PhaseController::find(r,t.actor);s.base=DracoPose::samples(DracoPose::points(r,b),DracoBody::rule(r,b).body_segments+1);}const double reach=r.content->boss_techniques[t.definition-1].reach,half=rule(r,t).half_angle;for (int j=0;j<25;++j) {const double f=j/24.0;s.area.push_back(s.origin+godot::Vector2::from_angle(s.facing+PI-half*f*f)*reach*f);}for (int j=1;j<49;++j) s.area.push_back(s.origin+godot::Vector2::from_angle(s.facing+PI-half+2*half*j/48.0)*reach);for (int j=23;j>0;--j) {const double f=j/24.0;s.area.push_back(s.origin+godot::Vector2::from_angle(s.facing+PI+half*f*f)*reach*f);}}
void DracoTailSweep::windup(RunRuntime &r,TechniqueState &t) {place(r,t,t.detail.get<DracoTechniqueState>().stage_time);}
void DracoTailSweep::active(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoTailSweepState>(v.move);s.area.clear();const auto &p=r.content->boss_techniques[t.definition-1];std::vector<godot::Vector2> points;place(r,t,p.warn+v.stage_time,&points);std::vector<float> fractions{0};float total=0;for (size_t j=1;j<points.size();++j) {total+=points[j-1].distance_to(points[j]);fractions.push_back(total);}if (total>0.001) for (auto &f:fractions) f/=total;
    for (size_t j=1;j+1<points.size();++j) {if (t.hit) break;const double f=(fractions[j]+fractions[j+1])*0.5,width=p.width*(1-0.77*std::pow(std::clamp((f-0.55)/0.45,0.0,1.0),1.35));v.attack_width=width;const ContactShape shape=s.prior.size()==points.size()?ContactShape(SweptSegment{s.prior[j],s.prior[j+1],points[j],points[j+1],width}):ContactShape(SegmentCircle{points[j],points[j+1],width});if (!DracoTechnique::observe_contact(r,t,CollisionQuery::touches(shape,{r.state.ship_pos,r.state.ship_pos,r.state.ship_config.ship_radius},{true,false}))) continue;ShipDamageRequest damage;damage.observation_id=t.observation_id;damage.amount=p.damage;damage.scale=DamageScale::AtkScale;damage.cause=Cause::TailSweep;damage.source=r.state.enemies[t.actor.slot].definition+1;damage.technique=t.definition;damage.hit_policy=HitPolicy::MarkIfAccepted;t.hit=CombatResolver::ship_damage(r,damage).accepted;}
    s.prior=std::move(points);v.attack.clear();
}
void DracoTailSweep::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoTailSweepState>(v.move);s.area.clear();v.attack.clear();auto *b=PhaseController::find(r,t.actor);if (b && cancelled) DracoPose::reset(r,*b);}
void DracoTailSweep::recover(RunRuntime &r,TechniqueState &t) {const auto &p=r.content->boss_techniques[t.definition-1];place(r,t,p.warn+p.active+t.detail.get<DracoTechniqueState>().stage_time);}
bool DracoTailSweep::validate(const DracoTailSweepState &s) {if (!s.origin.is_finite() || !std::isfinite(s.facing) || s.base.size()<2 || (!s.prior.empty() && s.prior.size()!=s.base.size())) return false;for (const auto *v:{&s.base,&s.prior,&s.area}) for (auto p:*v) if (!p.is_finite()) return false;return true;}
godot::Dictionary DracoTailSweep::snapshot(const TechniqueState &t) {const auto &s=std::get<DracoTailSweepState>(t.detail.get<DracoTechniqueState>().move);godot::Dictionary out;godot::PackedVector2Array area;for (auto p:s.area) area.push_back(p);out["telegraph_polygon"]=area;out["telegraph_center"]=s.origin;return out;}
}
