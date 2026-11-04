#include "reference_fx.h"
#include "../flow/phase_controller.h"
#include "stomp.h"
#include "../../runtime/run_runtime.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
godot::Vector2 mouth(const RunRuntime &r,const BossBodyState &b) {
    const auto &e=r.state.enemies[b.actor.slot];
    for (const auto &p:r.content->centaurus_bodies) if (p.body==b.definition) return e.pos+godot::Vector2::from_angle(e.facing)*e.radius*p.bow_reach;
    return e.pos;
}
std::vector<godot::Vector2> feet(const RunRuntime &r,const BossBodyState &b) {
    const auto &data=r.content->centaurus_image_pose;
    std::vector<godot::Vector2> out;
    const char *names[]={"FrontLeftLeg","FrontRightLeg","RearLeftLeg","RearRightLeg"};
    for (int i=0;i<4;++i) for (const auto &node:data.nodes) if (node.path==names[i]) {
        for (const auto &sprite:data.sprites) if (sprite.node==node.id) {
            const auto part=std::find_if(b.image_parts.begin(),b.image_parts.end(),[&](const auto &p){return p.part==sprite.id;});
            if (part==b.image_parts.end()) continue;
            const godot::Vector2 size(part->region.size),sign(sprite.flip_h?-1.0:1.0,sprite.flip_v?-1.0:1.0);
            godot::Vector2 origin(sprite.offset_x,sprite.offset_y);if (sprite.centered) origin-=size*.5;
            if (sprite.flip_h) origin.x+=size.x;if (sprite.flip_v) origin.y+=size.y;
            const godot::Transform2D local(sprite.rotation,godot::Vector2(sprite.scale_x,sprite.scale_y),sprite.skew,godot::Vector2(sprite.x,sprite.y));
            const godot::Transform2D pixel(godot::Vector2(sign.x,0),godot::Vector2(0,sign.y),origin);
            out.push_back((part->pixel_to_world*(local*pixel).affine_inverse()).xform(godot::Vector2(i%2?7.5:11.5,52)));
            break;
        }
    }
    return out;
}
}
void CentaurusReferenceFx::released(RunRuntime &r,const TechniqueState &t,godot::Vector2 position,double angle) {
    if (auto *b=PhaseController::find(r,t.actor)) b->centaurus.reference_fx.releases.push_back({position,angle,b->clock});
}
void CentaurusReferenceFx::update(RunRuntime &r,BossBodyState &b) {
    auto &fx=b.centaurus.reference_fx;const auto &e=r.state.enemies[b.actor.slot];const auto &p=r.content->centaurus_fx;
    if (fx.leaping && !b.centaurus.leaping) {auto points=feet(r,b);if (points.size()==4) fx.landings.push_back({e.pos,std::move(points),b.clock,e.radius});}
    fx.leaping=b.centaurus.leaping;
    for (const auto &t:r.state.bosses.techniques) {
        if (!same_handle(t.actor,b.actor) || t.stage>=TechniqueStage::Finished) continue;
        const auto &technique=r.content->boss_techniques[t.definition-1];
        if (technique.kind==12 && t.stage!=TechniqueStage::Windup && fx.stomp_id!=t.id) {
            const auto data=CentaurusStomp::snapshot(r,t);
            fx.stomps.push_back({data["center"],e.facing,data["half_angle"],data["range_radius"],t.started_at+technique.warn});fx.stomp_id=t.id;
        }
        if (technique.kind!=10 || t.stage!=TechniqueStage::Windup) continue;
        const auto rule=std::find_if(r.content->centaurus_rains.begin(),r.content->centaurus_rains.end(),[&](const auto &v){return v.technique==t.definition;});
        if (rule==r.content->centaurus_rains.end()) continue;
        if (fx.rain_id!=t.id) {fx.rain_id=t.id;fx.up_emitted.assign(rule->traces*4,0);}
        double radius=12,length=0;
        for (const auto &fan:r.content->centaurus_fans) if (r.content->boss_techniques[fan.technique-1].boss==technique.boss) {radius=fan.radius;length=fan.length;break;}
        for (uint32_t v=0;v<rule->traces;++v) for (uint32_t i=0;i<4;++i) {
            const uint32_t index=v*4+i;const double at=t.started_at+.08+v*(technique.warn-.16)/std::max(1u,rule->traces)+i*.035;
            if (index>=fx.up_emitted.size() || fx.up_emitted[index] || b.clock<at) continue;
            const double value=std::sin((v*7+i)*127.1+311.7)*43758.5453;
            fx.ups.push_back({mouth(r,b),-3.141592653589793*.5+((value-std::floor(value))-.5)*.3,at,radius,length});fx.up_emitted[index]=1;
        }
    }
    const auto prune=[&](auto &items,double life){items.erase(std::remove_if(items.begin(),items.end(),[&](const auto &v){return b.clock-v.started>life;}),items.end());};
    prune(fx.releases,p.release_life);prune(fx.landings,p.landing_life);prune(fx.stomps,p.stomp_life);prune(fx.ups,.5);
}
godot::Dictionary CentaurusReferenceFx::snapshot(const BossBodyState &b) {
    godot::Dictionary out;godot::Array releases,landings,stomps,ups;const auto &fx=b.centaurus.reference_fx;
    for (const auto &v:fx.releases) {godot::Dictionary d;d["position"]=v.position;d["angle"]=v.angle;d["started"]=v.started;releases.push_back(d);}
    for (const auto &v:fx.landings) {godot::Dictionary d;godot::PackedVector2Array points;for (auto p:v.feet) points.push_back(p);d["position"]=v.position;d["feet"]=points;d["started"]=v.started;d["radius"]=v.radius;landings.push_back(d);}
    for (const auto &v:fx.stomps) {godot::Dictionary d;d["position"]=v.position;d["angle"]=v.angle;d["half"]=v.half;d["radius"]=v.radius;d["started"]=v.started;stomps.push_back(d);}
    for (const auto &v:fx.ups) {godot::Dictionary d;d["position"]=v.position;d["angle"]=v.angle;d["started"]=v.started;d["radius"]=v.radius;d["length"]=v.length;ups.push_back(d);}
    out["releases"]=releases;out["landings"]=landings;out["stomps"]=stomps;out["ups"]=ups;return out;
}
}
