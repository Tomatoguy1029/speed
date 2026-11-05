#include "image_pose.h"
#include "../../content/content_bundle.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>

namespace speed {
namespace {
using godot::Transform2D;
using godot::Vector2;
const CentaurusImageClip *find_clip(const CentaurusImagePoseData &d,const std::string &name) {
    for (const auto &clip:d.clips) if (clip.name==name) return &clip;
    return nullptr;
}
std::vector<const CentaurusImageKey *> clip_keys(const CentaurusImagePoseData &d,const std::string &name) {
    std::vector<const CentaurusImageKey *> result;
    const auto *clip=find_clip(d,name);
    if (clip) for (const auto &key:d.keys) if (key.clip==clip->id) result.push_back(&key);
    if (result.empty()) for (const auto &key:d.keys) if (key.clip==0) {result.push_back(&key);break;}
    return result;
}
const CentaurusImagePose *pose_for(const CentaurusImagePoseData &d,uint32_t key,uint32_t node) {
    for (const auto &pose:d.poses) if (pose.key==key && pose.node==node) return &pose;
    return nullptr;
}
double mix(double a,double b,double t) {return a+(b-a)*t;}
struct Pose {
    Vector2 position,scale,pivot_origin;
    double rotation=0,skew=0;
    bool visible=true,has_pivot_origin=false;
    int64_t bow=-1;
};
Pose value(const CentaurusImageNode &node,const CentaurusImagePose *p) {
    if (!p) return {Vector2(node.x,node.y),Vector2(node.scale_x,node.scale_y),Vector2(),node.rotation,node.skew,node.visible,false,-1};
    return {Vector2(p->x,p->y),Vector2(p->scale_x,p->scale_y),Vector2(p->pivot_x,p->pivot_y),p->rotation,p->skew,p->visible,p->pivot_origin,p->bow};
}
void interpolate(Pose &a,const CentaurusImagePose &b,double t) {
    a.position=a.position.lerp(Vector2(b.x,b.y),t);
    a.scale=a.scale.lerp(Vector2(b.scale_x,b.scale_y),t);
    a.rotation=godot::Math::lerp_angle(a.rotation,b.rotation,t);
    a.skew=godot::Math::lerp_angle(a.skew,b.skew,t);
    if (a.has_pivot_origin && b.pivot_origin) a.pivot_origin=a.pivot_origin.lerp(Vector2(b.pivot_x,b.pivot_y),t);
}
}

double CentaurusImagePoseEvaluator::duration(const CentaurusImagePoseData &d,const std::string &clip) {
    const auto *selected=find_clip(d,clip);
    if (!selected) return 0.0;
    double seconds=0;
    for (const auto &key:d.keys) if (key.clip==selected->id) seconds+=key.duration;
    return seconds;
}
bool CentaurusImagePoseEvaluator::evaluate(const CentaurusImagePoseData &d,const std::string &clip,double time,
                                            const Transform2D &root,std::vector<BossImagePart> &out) {
    out.clear();
    const auto keys=clip_keys(d,clip);
    if (keys.empty() || !std::isfinite(time)) return false;
    double left=std::max(0.0,time);
    size_t index=0;
    while (index+1<keys.size() && left>=keys[index]->duration) left-=keys[index++]->duration;
    const auto *current=keys[index];
    const auto *next=index+1<keys.size()?keys[index+1]:nullptr;
    const double fraction=next && current->interpolate?std::clamp(left/current->duration,0.0,1.0):0.0;
    std::vector<Transform2D> transforms(d.nodes.size()+1);
    std::vector<bool> visible(d.nodes.size()+1,true);
    std::vector<int64_t> bows(d.nodes.size()+1,-1);
    transforms[0]=root;
    for (const auto &node:d.nodes) {
        if (!node.id || node.id>=transforms.size() || node.parent>=node.id) {out.clear();return false;}
        const auto *p=pose_for(d,current->id,node.id);
        Pose pose=value(node,p);
        const auto *following=next?pose_for(d,next->id,node.id):nullptr;
        // sample() は現在と次の両方にある部位だけを補間する。
        if (p && following && next && current->interpolate) interpolate(pose,*following,fraction);
        Transform2D local(pose.rotation,pose.scale,pose.skew,pose.position);
        if (node.pivot && pose.has_pivot_origin)
            local.set_origin(pose.pivot_origin-local.basis_xform(Vector2(node.pivot_x,node.pivot_y)));
        transforms[node.id]=transforms[node.parent]*local;
        visible[node.id]=visible[node.parent] && pose.visible;
        bows[node.id]=pose.bow;
    }
    for (const auto &sprite:d.sprites) {
        if (!sprite.node || sprite.node>=transforms.size() || !sprite.mask) {out.clear();return false;}
        uint32_t x=sprite.region_x,y=sprite.region_y,w=sprite.region_w,h=sprite.region_h;
        Vector2 position(sprite.x,sprite.y);
        if (sprite.bow) {
            if (d.bows.empty()) {out.clear();return false;}
            const int64_t variant=bows[sprite.node]>=0?bows[sprite.node]:0;
            const auto i=std::clamp<int64_t>(variant,0,int64_t(d.bows.size())-1);
            const auto &bow=d.bows[size_t(i)];x=bow.region_x;y=bow.region_y;w=bow.region_w;h=bow.region_h;
            position=Vector2(5.0-bow.grip_x,34.0-bow.grip_y);
        }
        if (!w || !h) {out.clear();return false;}
        const Vector2 size(w,h);
        Vector2 origin(sprite.offset_x,sprite.offset_y);
        if (sprite.centered) origin-=size*0.5;
        const Vector2 sign(sprite.flip_h?-1.0:1.0,sprite.flip_v?-1.0:1.0);
        if (sprite.flip_h) origin.x+=w;
        if (sprite.flip_v) origin.y+=h;
        const Transform2D local(sprite.rotation,Vector2(sprite.scale_x,sprite.scale_y),sprite.skew,position);
        const Transform2D pixel(Vector2(sign.x,0),Vector2(0,sign.y),origin);
        BossImagePart part;
        part.part=sprite.id;part.mask=sprite.mask;part.region=godot::Rect2i(x,y,w,h);
        part.pixel_to_world=transforms[sprite.node]*local*pixel;
        part.visible=visible[sprite.node] && sprite.visible;
        out.push_back(part);
    }
    return !out.empty();
}

bool CentaurusImagePoseEvaluator::step(const CentaurusImagePoseData &d,CentaurusImagePoseClock &clock,
                                        int64_t technique_id,const std::string &technique,const std::string &mode,
                                        double progress,double delta,double pose_time,uint32_t released,double interval,
                                        const Transform2D &root,std::vector<BossImagePart> &out) {
    if (clock.technique_id!=technique_id || clock.technique!=technique) {
        clock.technique_id=technique_id;clock.technique=technique;clock.released=0;
    }
    if (released>clock.released) {
        clock.shot_interval=std::max(0.05,interval);clock.elapsed=0;clock.released=released;
    }
    std::string clip="idle";
    if (technique=="volley" || technique=="power_shot") {
        if (mode=="windup") clip="shot_windup";else if (mode=="shooting") clip="shot_release";else if (mode=="recovery") clip="shot_recovery";
    } else if (technique=="rain") {
        if (mode=="windup") clip="rain_windup";else if (mode=="rain") clip="rain";else if (mode=="recovery") clip="rain_recovery";
    } else if (technique=="shower_chase" || technique=="shower_wall" || technique=="shower_path") {
        if (mode=="windup") clip="shower_windup";else if (mode=="rain") clip="shower";else if (mode=="recovery") clip="shower_recovery";
    } else if (technique=="fan_volley") {
        if (mode=="windup") clip="fan_windup";else if (mode=="shooting") clip="fan_release";else if (mode=="recovery") clip="fan_recovery";
    } else if (technique=="sail_run") {
        if (mode=="windup") clip="sail_windup";else if (mode=="sail") clip="sail_run";else if (mode=="recovery") clip="sail_recovery";
    } else if (technique=="stomp") {
        if (mode=="windup") clip="stomp_windup";else if (mode=="strike") clip="stomp";else if (mode=="recovery") clip="stomp_recovery";
    }
    if (mode=="leap") clip="leap";else if (mode=="retreat") clip="run";
    if (clock.clip!=clip) {clock.clip=clip;clock.elapsed=0;}
    clock.elapsed+=std::max(0.0,delta);
    const double length=duration(d,clip);
    double at=clock.elapsed;
    if (mode=="windup") at=std::clamp(progress,0.0,1.0)*length;
    else if (clip=="shot_release" || clip=="fan_release" || clip=="sail_run") at=clock.elapsed/clock.shot_interval*length;
    else if ((clip=="idle" || clip=="rain" || clip=="shower" || clip=="run") && length>0) at=std::fmod(clock.elapsed,length);
    if (clip=="stomp" && pose_time>=0) at=pose_time;
    return evaluate(d,clip,at,root,out);
}

}
