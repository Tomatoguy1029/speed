#include "roar.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>

namespace speed {
namespace {
const CanisRoarDefinition *settings(const ContentBundle &content,uint32_t technique) {
    const auto found=std::find_if(content.canis_roars.begin(),content.canis_roars.end(),[&](const auto &x){return x.technique==technique;});
    return found==content.canis_roars.end()?nullptr:&*found;
}
double warning(const ContentBundle &content,const TechniqueState &t) {
    const auto &technique=content.boss_techniques[t.definition-1];
    if (technique.external_id=="hunt") {
        const auto it=std::find_if(content.canis_hunts.begin(),content.canis_hunts.end(),[&](const auto &x){return x.technique==t.definition;});
        if (it!=content.canis_hunts.end()) return content.boss_techniques[it->stream-1].warn;
    }
    if (technique.external_id=="hunt_pounce") {
        const auto it=std::find_if(content.canis_hunt_pounces.begin(),content.canis_hunt_pounces.end(),[&](const auto &x){return x.technique==t.definition;});
        if (it!=content.canis_hunt_pounces.end()) return content.boss_techniques[it->stream-1].warn;
    }
    return technique.warn;
}
}
void CanisRoar::update(RunRuntime &r,BossBodyState &body) {
    for (const auto &t:r.state.bosses.techniques) {
        if (!same_handle(t.actor,body.actor) || t.stage>=TechniqueStage::Finished || body.canis.roar_last_technique==t.id) continue;
        const auto *p=settings(*r.content,t.definition);if (!p || !p->has_roar) continue;
        const auto &id=r.content->boss_techniques[t.definition-1].external_id;
        const double warn=warning(*r.content,t);
        const double cue=id=="nova"?.4:warn-std::min(warn*.65,id=="howl"?.55:.32);
        if (body.clock-t.started_at<cue) continue;
        body.canis.roar_last_technique=t.id;
        body.canis.roar_definition=p->id;
        body.canis.roar_started=t.started_at+cue;
        ++body.canis.roar_serial;
        break;
    }
}
godot::Dictionary CanisRoar::snapshot(const RunRuntime &r,const BossBodyState &body) {
    godot::Dictionary out;
    if (!body.canis.roar_definition || body.canis.roar_definition>r.content->canis_roars.size() || !r.state.enemy_handles.contains(body.actor)) return out;
    const auto &p=r.content->canis_roars[body.canis.roar_definition-1];
    const double age=(body.clock-body.canis.roar_started)/p.timing;
    constexpr double lives[]={0,.24,.36,.52};
    if (!p.level || p.level>3 || age<0 || age>=lives[p.level]*p.roar_time) return out;
    const auto &enemy=r.state.enemies[body.actor.slot];const auto &head=body.canis.image_pose.nodes[6];
    const auto mouth=enemy.pos+(head.position+godot::Vector2(0,59).rotated(head.rotation)).rotated(enemy.facing-godot::Math::PI/2)*(enemy.radius/100.0);
    out["id"]=godot::String::utf8(p.external_id.c_str());out["age"]=age;out["seed"]=1+9*(body.canis.roar_serial-1);out["mouth"]=mouth;out["radius"]=enemy.radius;
    return out;
}
bool CanisRoar::validate(const BossBodyState &body,const ContentBundle &content) {
    const auto &c=body.canis;
    return c.roar_last_technique>=0 && c.roar_serial>=0 && std::isfinite(c.roar_started) && c.roar_started>=-1 && c.roar_definition<=content.canis_roars.size();
}
}
