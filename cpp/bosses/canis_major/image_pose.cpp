#include "image_pose.h"
#include "nova.h"
#include "pounce.h"
#include "roar.h"
#include "../../runtime/run_runtime.h"
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <algorithm>
#include <cmath>
#include <initializer_list>

namespace speed {
namespace {
using godot::Vector2;
using godot::Transform2D;
using Key=std::pair<double,double>;
double smooth(double a,double b,double t) {const double x=std::clamp((t-a)/(b-a),0.0,1.0);return x*x*(3-2*x);}
double curve(double t,std::initializer_list<Key> keys) {
    auto p=keys.begin();if (t<=p->first) return p->second;
    for (auto q=p+1;q!=keys.end();++q,++p) if (t<=q->first) return p->second+(q->second-p->second)*smooth(p->first,q->first,t);
    return (keys.end()-1)->second;
}
double front_travel(double t) {return curve(t,{{-.7,0},{-.18,-1},{-.06,-3},{.035,7},{.17,3},{.32,8},{.4,4},{.46,-5},{.54,-3},{.7,0}});}
double rear_travel(double t) {return curve(t,{{-.7,0},{-.18,2},{-.06,4},{.035,-7},{.15,-5},{.32,-2},{.42,2},{.49,5},{.57,2},{.7,0}});}
double front_angle(double t) {return curve(t,{{-.7,0},{-.16,.05},{-.06,.07},{.04,.01},{.17,.1},{.32,0},{.43,.025},{.53,.06},{.7,0}});}
double rear_angle(double t) {return curve(t,{{-.7,0},{-.18,.06},{-.06,.12},{.04,.02},{.19,.055},{.4,.06},{.5,.11},{.7,0}});}
const TechniqueState *active(const RunRuntime &r,EnemyHandle actor) {
    for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,actor) && t.stage<TechniqueStage::Finished) return &t;
    return nullptr;
}
const CanisPounceState *jump(const TechniqueState *t) {
    if (!t) return nullptr;
    if (const auto *p=std::get_if<CanisPounceState>(&t->detail)) return p;
    if (const auto *p=std::get_if<CanisBayState>(&t->detail)) return p->jumping?&p->jump:nullptr;
    if (const auto *p=std::get_if<CanisHuntPounceState>(&t->detail)) return p->jumping?&p->jump:nullptr;
    return nullptr;
}
void pounce(std::array<CanisImageNodePose,7> &nodes,double time) {
    for (int i=1;i<=4;++i) {
        const bool front=i>=3,right=i%2==0;
        const double t=time-(right?.018:0), side=right?1:-1;
        nodes[i].position.y+=front?front_travel(t):rear_travel(t);
        nodes[i].rotation=side*(front?front_angle(t):rear_angle(t));
        nodes[i].scale={1,1};
    }
    nodes[5].position=Vector2(0,curve(time,{{-.7,0},{-.18,-1},{-.06,-3},{.035,3},{.2,3},{.4,1},{.48,-3},{.67,0}}));
    nodes[5].rotation=0;nodes[5].scale={1,1};
    nodes[6].position.y+=curve(time,{{-.7,0},{-.17,-1},{-.055,-4},{.035,5},{.3,6},{.43,7},{.5,0},{.66,0}});
    nodes[6].rotation=0;nodes[6].scale={1,1};
    nodes[0].rotation=curve(time,{{-.7,0},{-.12,.025},{.09,-.03},{.38,-.015},{.53,.03},{.7,0}});
    nodes[0].scale={1,1};
}
}
void CanisImagePose::update(RunRuntime &r,BossBodyState &b) {
    if (!r.state.enemy_handles.contains(b.actor) || r.content->canis_image_parts.size()!=7) {b.image_parts.clear();return;}
    auto &c=b.canis.image_pose;const auto &e=r.state.enemies[b.actor.slot];const auto *t=active(r,b.actor);
    const double dt=c.clock>=0?std::max(0.0,b.clock-c.clock):0;
    if (c.clock>b.clock) {c.gait=c.walk_phase=0;c.landed_at=-1;}
    if (c.clock>=0 && dt>0) c.walk_phase+=c.previous_position.distance_to(e.pos)/std::max(double(e.radius)*.95,.001)*godot::Math::TAU;
    c.previous_position=e.pos;c.clock=b.clock;c.gait+=dt*(t && t->stage==TechniqueStage::Active?18:9);
    const double scale=e.radius/100.0;c.root_scale=Vector2(scale,scale);
    for (size_t i=0;i<c.nodes.size();++i) {const auto &row=r.content->canis_image_parts[i];c.nodes[i]={Vector2(row.x,row.y),Vector2(1,1),0};}
    c.nodes[0].rotation=std::sin(c.gait*.4)*.07;
    if (t && r.content->boss_techniques[t->definition-1].external_id=="howl" && t->stage==TechniqueStage::Windup)
        c.nodes[6].rotation=-.45*smooth(0,.65,e.charge);
    if (e.vel.length()>5) {
        const double offsets[]={0,.5,.25,.75};
        for (int i=0;i<4;++i) {
            auto &part=c.nodes[i+1];const double phase=std::fmod(c.walk_phase/godot::Math::TAU+offsets[i],1.0);
            const bool stance=phase<.72;const double stroke=stance?1-2*phase/.72:-1+2*smooth(.72,1,phase);
            const double lift=stance?0:std::sin((phase-.72)/.28*godot::Math::PI);
            part.position+=Vector2(lift*3*(i%2?1:-1),stroke*11);part.rotation=stroke*.26;part.scale=Vector2(1,1-lift*.18);
        }
        c.nodes[0].rotation+=std::sin(c.walk_phase)*.12;
        c.nodes[5].rotation=std::sin(c.walk_phase)*.05;
        c.nodes[5].position=Vector2(std::sin(c.walk_phase)*1.5,std::abs(std::sin(c.walk_phase))*2);
        c.nodes[6].rotation-=std::sin(c.walk_phase)*.07;
    }
    const auto *p=jump(t);const double land_age=c.landed_at>=0?b.clock-c.landed_at:-1;
    if (t && !p) {
        const auto *roar=CanisRoar::settings(*r.content,t->definition);
        const auto *hunt=std::get_if<CanisHuntState>(&t->detail);
        const auto *relay=std::get_if<CanisRelayState>(&t->detail);
        const bool aiming=(hunt && hunt->aiming) || (relay && relay->aiming);
        if (roar && roar->has_roar && roar->external_id!="O-nova" && !aiming) {
            const double age=b.canis.roar_last_technique==t->id?b.clock-b.canis.roar_started:-1;
            const double inhale=age>=0?0:std::clamp((t->stage==TechniqueStage::Windup?e.charge:0.0)*2.0,0.0,1.0);
            const double push=age>=0?smooth(0,.035,age)*(1-smooth(.09,.24,age)):0;
            c.nodes[6].rotation=-.045*inhale;c.nodes[6].position={0,float(42-inhale*9+push*13)};c.nodes[6].scale={float(1+push*.035),float(1+push*.09)};
            c.nodes[5].position={0,float(-inhale*4-push*3)};c.nodes[5].rotation=0;c.nodes[5].scale={float(1+inhale*.025-push*.02),float(1-inhale*.055+push*.04)};
        }
    }
    if (p && !p->done) {
        const auto motion=CanisPounce::motion_snapshot(r,*p);
        const double span=double(motion[p->jumping?"active_time":"warn_time"]);
        const double time=p->jumping?p->stage_time/std::max(span,.001)*.45:p->stage_time-span;
        pounce(c.nodes,time);
    } else if (land_age>=0 && land_age<.5) pounce(c.nodes,.45+land_age);
    if (t && t->stage==TechniqueStage::Active && r.content->boss_techniques[t->definition-1].external_id=="sirius_flame") {
        c.nodes[6].rotation+=std::sin(b.clock*23)*.018;
        c.nodes[6].position=Vector2(0,42+std::sin(b.clock*16)*1.2);
    }
    if (r.state.bosses.handles.contains(b.canis.nova)) {
        const auto head=CanisNova::image_head_pose(r,b);c.nodes[6].position={0,head.x};c.nodes[6].rotation=head.y;
    }
    const Transform2D root(e.facing-godot::Math::PI/2,c.root_scale,0,e.pos);
    b.image_parts.clear();
    for (size_t i=0;i<c.nodes.size();++i) {
        const auto &def=r.content->canis_image_parts[i];const auto &node=c.nodes[i];
        const Transform2D local(node.rotation,node.scale,0,node.position);
        const Transform2D sprite(0,Vector2(1,1),0,Vector2(def.sprite_x,def.sprite_y));
        const double sign=def.flip_h?-1:1;
        const Transform2D pixel(Vector2(sign,0),Vector2(0,1),Vector2(def.flip_h?def.width*.5:-double(def.width)*.5,-double(def.height)*.5));
        BossImagePart part;part.part=def.id;part.mask=def.mask;part.region=godot::Rect2i(0,0,def.width,def.height);
        part.pixel_to_world=root*local*sprite*pixel;part.visible=def.visible && b.mode<BossMode::Defeated;
        b.image_parts.push_back(part);
    }
}
godot::Vector2 CanisImagePose::mouth(const RunRuntime &r,const BossBodyState &b) {
    if (!r.state.enemy_handles.contains(b.actor)) return {};
    const auto &enemy=r.state.enemies[b.actor.slot];const auto &head=b.canis.image_pose.nodes[6];
    return enemy.pos+(head.position+(godot::Vector2(0,59)*head.scale).rotated(head.rotation)).rotated(enemy.facing-godot::Math::PI/2)*(enemy.radius/100.0);
}
godot::Array CanisImagePose::snapshot(const RunRuntime &,const BossBodyState &b) {
    godot::Array out;
    for (const auto &node:b.canis.image_pose.nodes) {godot::Dictionary row;row["position"]=node.position;row["rotation"]=node.rotation;row["scale"]=node.scale;out.push_back(row);}
    return out;
}
}
