#include "picaro_wall.h"
#include "picaro.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/light_arrow.h"
#include "../../systems/attacks/zone.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const DracoPicaroWallDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_picaro_walls.begin(),r.content->draco_picaro_walls.end(),[&](const auto &p){return p.technique==t.definition;});}
godot::Vector2 target(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];return TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos);}
}
void DracoPicaroWall::begin(RunRuntime &r,TechniqueState &t) {
    auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoPicaroWallState{};const auto &p=rule(r,t);auto *b=PhaseController::find(r,t.actor);b->draco->picaro_attacking=true;
    const auto origin=r.state.enemies[t.actor.slot].pos,aim=target(r,t);auto forward=(aim-origin).normalized();if (forward.is_zero_approx()) forward={1,0};
    std::vector<uint32_t> choices;for (const auto &q:r.content->draco_picaro_wall_candidates) if (q.technique==t.definition) choices.push_back(q.enemy);
    for (uint32_t j=0;j<p.count;++j) DracoPicaro::spawn(r,*b,choices[j%choices.size()],origin.lerp(aim,0.45)+forward.orthogonal()*(double(j)-double(p.count-1)*0.5)*180);
}
void DracoPicaroWall::active(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoPicaroWallState>(v.move);const auto &p=rule(r,t);const auto &e=r.state.enemies[t.actor.slot];auto *b=PhaseController::find(r,t.actor);const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    if (s.shots<p.arrows && v.stage_time>=s.shots*p.interval) {
        const auto from=e.pos+godot::Vector2::from_angle(e.facing)*100*b->draco->head_scale;LightArrowParams arrow;arrow.position=from;arrow.angle=-1.5707963267948966;arrow.speed=900;arrow.radius=12;arrow.travel=std::max(1000.0,double(r.state.view_half.y)*2.5);arrow.cosmic=true;arrow.owner=t.actor;arrow.technique=ticket;LightArrowSystem::emit(r,arrow);
        const double top=r.state.view_center.y-r.state.view_half.y,leave=std::max(0.0,double(from.y)-top+80)/900;s.impacts.push_back({{},std::max(p.flight,leave+0.15),p.impact_warn,0,false});++s.shots;
    }
    for (auto &impact:s.impacts) {impact.age+=dt;if (!impact.locked && impact.age>=impact.wait) {impact.position=target(r,t);impact.locked=true;}
        if (impact.locked && impact.age>=impact.wait+impact.warn) {ZoneParams zone;zone.position=impact.position;zone.radius=p.radius;zone.damage=r.content->boss_techniques[t.definition-1].damage*r.state.combat_config.atk_scale;zone.style=ZoneStyle::Plain;zone.color=godot::Color::html("b7a3ff");zone.owner=t.actor;zone.technique=ticket;ZoneSystem::emit(r,zone);b->draco->impacts.push_back({impact.position,b->clock,p.radius,t.definition});if (b->draco->impacts.size()>32) b->draco->impacts.erase(b->draco->impacts.begin());}
    }
    s.impacts.erase(std::remove_if(s.impacts.begin(),s.impacts.end(),[](const auto &i){return i.locked && i.age>=i.wait+i.warn;}),s.impacts.end());
}
void DracoPicaroWall::end(RunRuntime &r,TechniqueState &t,bool cancelled) {std::get<DracoPicaroWallState>(t.detail.get<DracoTechniqueState>().move).impacts.clear();if (auto *b=PhaseController::find(r,t.actor)) DracoPicaro::pause(r,*b,cancelled);}
bool DracoPicaroWall::validate(const DracoPicaroWallState &s) {for (const auto &i:s.impacts) if (!i.position.is_finite() || !std::isfinite(i.age) || i.age<0 || !std::isfinite(i.wait) || i.wait<0 || !std::isfinite(i.warn) || i.warn<=0) return false;return true;}
godot::Dictionary DracoPicaroWall::snapshot(const TechniqueState &t) {const auto &s=std::get<DracoPicaroWallState>(t.detail.get<DracoTechniqueState>().move);godot::Dictionary out;out["shots"]=s.shots;godot::Array impacts;for (const auto &i:s.impacts) {godot::Dictionary q;q["position"]=i.position;q["age"]=i.age;q["wait"]=i.wait;q["warn"]=i.warn;q["locked"]=i.locked;impacts.push_back(q);}out["arrow_impacts"]=impacts;return out;}
}
