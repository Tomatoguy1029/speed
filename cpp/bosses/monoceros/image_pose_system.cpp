#include "image_pose_system.h"
#include "sweep_visual.h"
#include "../flow/technique_runner.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

namespace speed {
namespace {
using godot::Transform2D;using godot::Vector2;
struct Node {
    uint32_t parent=0;std::string path;Vector2 position,scale;double rotation=0,skew=0;bool visible=true;
    Transform2D world;
};
size_t find(const std::vector<Node> &nodes,const std::string &path) {
    for (size_t i=1;i<nodes.size();++i) if (nodes[i].path==path) return i;
    return 0;
}
void transforms(std::vector<Node> &nodes,const Transform2D &root) {
    nodes[0].world=root;
    for (size_t i=1;i<nodes.size();++i) {
        auto &n=nodes[i];n.world=nodes[n.parent].world*Transform2D(n.rotation,n.scale,n.skew,n.position);
    }
}
double follow(double value,double target,double dt,double seconds) {return godot::Math::lerp_angle(value,target,1.0-std::exp(-dt/std::max(seconds,0.001)));}
double limit(double center,double value,double degrees) {const double max=degrees*godot::Math::PI/180.0;return center+std::clamp(godot::Math::angle_difference(center,value),-max,max);}
size_t gait_frame(const MonocerosImagePoseData &data,double time) {
    double cycle=0;for (const auto &f:data.gait) cycle+=f.duration;
    if (cycle<=0) return 0;
    double left=std::fmod(time,cycle);
    for (size_t i=0;i<data.gait.size();++i) {if (left<data.gait[i].duration) return i;left-=data.gait[i].duration;}
    return 0;
}
}
bool MonocerosImagePoseSystem::refresh(RunRuntime &run,BossBodyState &body) {
    const auto &c=*run.content;const auto &data=c.monoceros_image_pose;
    body.monoceros->burns.erase(std::remove_if(body.monoceros->burns.begin(),body.monoceros->burns.end(),[&](const auto &v){return body.clock-v.started>2.5;}),body.monoceros->burns.end());
    body.monoceros->shatters.erase(std::remove_if(body.monoceros->shatters.begin(),body.monoceros->shatters.end(),[&](const auto &v){return body.clock-v.started>v.lifetime;}),body.monoceros->shatters.end());
    body.monoceros->breaths.erase(std::remove_if(body.monoceros->breaths.begin(),body.monoceros->breaths.end(),[&](const auto &v){return body.clock-v.started>v.lifetime;}),body.monoceros->breaths.end());
    if (!run.state.enemy_handles.contains(body.actor) || !body.definition || body.definition>c.boss_bodies.size()) return false;
    const auto &body_def=c.boss_bodies[body.definition-1];
    if (!body_def.boss || body_def.boss>c.bosses.size() || c.bosses[body_def.boss-1].kind!=0 || data.nodes.empty() || data.sprites.empty() || data.gait.empty() || data.horns.empty()) return false;
    const auto &enemy=run.state.enemies[body.actor.slot];
    const TechniqueState *t=nullptr;
    for (const auto &candidate:run.state.bosses->techniques) if (same_handle(candidate.actor,body.actor) && candidate.stage<TechniqueStage::Finished) {t=&candidate;break;}
    const BossTechniqueDefinition *attack=t && t->definition && t->definition<=c.boss_techniques.size()?&c.boss_techniques[t->definition-1]:nullptr;
    const std::string move=attack?attack->external_id:"";
    const MonocerosImageTuning *tuning=nullptr;
    for (const auto &v:data.tuning) if (v.move==move) {tuning=&v;break;}
    if (!tuning) for (const auto &v:data.tuning) if (v.move.empty()) {tuning=&v;break;}
    if (!tuning) return false;
    auto pose=body.monoceros->pose;
    if (!pose.initialized || pose.last_body_clock>body.clock) {
        pose.initialized=true;pose.body=pose.neck=pose.head=pose.tail=pose.flame=enemy.facing;pose.gait=0;pose.last_body_clock=body.clock;
    }
    const double dt=std::max(0.0,body.clock-pose.last_body_clock);pose.last_body_clock=body.clock;
    const bool live=body.mode==BossMode::Idle;
    const bool windup=live && t && t->stage==TechniqueStage::Windup;
    const bool active=live && t && t->stage==TechniqueStage::Active;
    const bool stuck=live && t && t->stage==TechniqueStage::Stuck;
    const bool attacking=active || stuck || (windup && t->locked);
    const bool sweeping=(move=="sweep" || move=="lance" || move=="return_charge" || move=="horn_wave" || move=="horn_dance" || move=="sword_flash") && (windup || active);
    const auto *wave_pose=t?t->detail.get_if<MonocerosHornWaveState>():nullptr;
    double wave_pull_scale=1.0;
    if (wave_pose && attack) {
        using Stage=MonocerosHornWaveState::Stage;
        if (wave_pose->stage==Stage::Windup || wave_pose->stage==Stage::Recharge) wave_pull_scale=0.5;
        else if (wave_pose->stage==Stage::Swing) {
            const double q=std::clamp(wave_pose->elapsed/std::max(attack->swing_time,0.001),0.0,1.0);
            wave_pull_scale=0.5+0.5*godot::Math::smoothstep(0.0,0.25,q);
        }
    }
    pose.body=limit(enemy.facing,follow(pose.body,enemy.facing,dt,tuning->body_follow*(attacking?0.3:1.0)),tuning->body_lag);
    godot::PackedVector2Array horn_line;
    if (t) horn_line=TechniqueRunner::shape(run,*t);
    if (attacking || sweeping) {
        pose.neck=move!="kick" && horn_line.size()>=2?(Vector2(horn_line[1])-Vector2(horn_line[0])).angle():enemy.facing;
        if (wave_pose) pose.neck=enemy.facing+godot::Math::angle_difference(enemy.facing,pose.neck)*wave_pull_scale;
        pose.head=pose.neck;
    } else {
        pose.neck=limit(pose.body,follow(pose.neck,enemy.facing,dt,tuning->neck_follow),tuning->head_turn*0.55);
        pose.head=limit(pose.body,follow(pose.head,enemy.facing,dt,tuning->head_follow),tuning->head_turn);
        pose.head=limit(pose.neck,pose.head,tuning->head_turn*0.55);
    }
    pose.tail=limit(pose.body,follow(pose.tail,pose.body,dt,tuning->tail_follow),tuning->tail_turn);
    pose.flame=limit(pose.tail,follow(pose.flame,pose.tail,dt,tuning->flame_follow),tuning->tail_turn*1.5);
    const auto &feedback=c.boss_image_feedback;
    const double strength=feedback.duration>0?std::clamp((body.hit_feedback_until-run.state.sim_time)/feedback.duration,0.0,1.0):0.0;
    const int64_t actor=run.state.enemy_handles.entity_id(body.actor);
    const double phase=run.state.sim_time*feedback.phase_rate+double(actor%feedback.seed_modulo)*feedback.seed_rate;
    pose.feedback_white=feedback.max_white*strength;
    pose.feedback_angle=std::sin(phase*feedback.angle_rate)*feedback.max_angle*strength;
    pose.feedback_offset=Vector2(std::sin(phase),std::cos(phase*feedback.y_rate))*feedback.max_offset*strength*feedback.offset_scale;
    std::vector<Node> nodes(data.nodes.size()+1);
    for (const auto &v:data.nodes) {
        if (!v.id || v.id>=nodes.size() || v.parent>=v.id) return false;
        auto &n=nodes[v.id];n.parent=v.parent;n.path=v.path;n.position=Vector2(v.x+v.offset_x,v.y+v.offset_y);n.scale=Vector2(v.scale_x,v.scale_y);n.rotation=v.rotation;n.skew=v.skew;n.visible=v.visible;
    }
    const auto parts=find(nodes,"Parts"),head=find(nodes,"Parts/Head"),lower=find(nodes,"Parts/Head/Lower"),tail=find(nodes,"Parts/TailBooster"),torso=find(nodes,"Parts/Body"),horn=find(nodes,"Parts/Head/Lower/Horn");
    if (!parts || !head || !lower || !tail || !torso || !horn) return false;
    const double k=enemy.radius/96.0;
    nodes[parts].scale=Vector2(k,k);
    nodes[parts].rotation=-godot::Math::PI*0.5+godot::Math::angle_difference(enemy.facing,pose.body)+pose.feedback_angle;
    nodes[parts].position=-Vector2(0,-37).rotated(nodes[parts].rotation)*k+pose.feedback_offset;
    nodes[head].rotation=godot::Math::angle_difference(pose.body,pose.neck);
    nodes[lower].rotation=godot::Math::angle_difference(pose.neck,pose.head);
    nodes[tail].rotation=godot::Math::angle_difference(pose.body,pose.tail);
    nodes[tail].position+=Vector2(0,26)-Vector2(0,26).rotated(nodes[tail].rotation);
    double cycle=0;for (const auto &f:data.gait) cycle+=f.duration;
    if (cycle<=0 || data.gait.size()<=3) return false;
    const bool moving=enemy.vel.length_squared()>25 && !(windup || stuck || body.mode==BossMode::Phase || body.mode==BossMode::Final || body.mode>=BossMode::Defeated);
    pose.gait=moving?std::fmod(pose.gait+dt,cycle):0;
    const size_t first=moving?gait_frame(data,pose.gait):3,opposite=moving?gait_frame(data,pose.gait+cycle*0.5):3;
    const char *feet[]={"FrontLeftLeg","FrontRightLeg","RearLeftLeg","RearRightLeg"};
    for (size_t i=0;i<4;++i) {
        const std::string base=std::string("Parts/")+feet[i]+"/Foot";
        const auto foot=find(nodes,base),sprite=find(nodes,base+"/Sprite");if (!foot || !sprite) return false;
        nodes[foot].position=Vector2(i%2==0?-5:4,40);
        const auto &frame=data.gait[(i==0 || i==3)?first:opposite];
        const auto &source=data.nodes[sprite-1];nodes[sprite].position=Vector2(-std::floor(double(frame.base_w)*0.5),-6)+Vector2(source.offset_x,source.offset_y);
    }
    const Transform2D body_world(enemy.facing,enemy.pos);
    transforms(nodes,body_world);
    const bool aimed=move=="charge" || move=="return_charge" || move=="horn_dance";
    bool first_sequence=true,run_stage=false;double elapsed=0;
    if (t && attack) {
        if (attack->kind==0) {run_stage=active;elapsed=std::max(0.0,t->elapsed-attack->warn);}
        if (const auto *v=t->detail.get_if<MonocerosReturnState>()) {first_sequence=v->stage==MonocerosReturnState::Stage::Aim;run_stage=active && v->stage==MonocerosReturnState::Stage::Run;elapsed=v->elapsed;}
        if (const auto *v=t->detail.get_if<MonocerosDanceState>()) {first_sequence=v->stage==MonocerosDanceState::Stage::Aim;run_stage=active && v->stage==MonocerosDanceState::Stage::Run;elapsed=v->elapsed;}
    }
    const double progress=t && attack?std::clamp(t->elapsed/std::max(0.001,attack->warn),0.0,1.0):0;
    const double prepare=aimed && windup && first_sequence?godot::Math::smoothstep(0.0,0.62,progress):0;
    const double release=aimed && run_stage?1.0-godot::Math::smoothstep(0.035,0.14,elapsed):0;
    nodes[head].position+=Vector2(0,-prepare*5+release*3);nodes[torso].position+=Vector2(0,-prepare*2+release*2);
    for (size_t i=0;i<2;++i) {const auto foot=find(nodes,std::string("Parts/")+feet[i]+"/Foot");nodes[foot].position+=Vector2(0,-prepare*7+release*3);}
    // monoWavePose の頭・胴の溜め、震え、突き出しを画像境界と表示で共有する。
    if (move=="horn_wave" && t && attack) if (const auto *v=t->detail.get_if<MonocerosHornWaveState>()) {
        using Stage=MonocerosHornWaveState::Stage;double pull=0,thrust=0,shake=0;
        if (v->stage==Stage::Windup || v->stage==Stage::Recharge) {
            const double duration=v->stage==Stage::Windup?attack->warn:attack->recharge;
            pull=godot::Math::smoothstep(0.0,duration*0.7,v->elapsed)*wave_pull_scale;
            shake=godot::Math::smoothstep(duration*0.7,duration,v->elapsed)*std::sin((t->elapsed+0.4)*70.0)*1.6;
        } else if (v->stage==Stage::Swing) {
            const double q=std::clamp(v->elapsed/std::max(attack->swing_time,0.001),0.0,1.0);
            thrust=std::sin(godot::Math::PI*std::min(1.0,q*1.3));pull=(1.0-godot::Math::smoothstep(0.0,0.25,q))*wave_pull_scale;
        }
        nodes[head].position+=Vector2(shake,-pull*16+thrust*15);
        nodes[torso].position+=Vector2(shake*0.5,-pull*8+thrust*8);
        nodes[torso].scale=Vector2(1+pull*0.05,1-pull*0.07+thrust*0.05);
    }
    // 承認済みmonoKickPose：後脚を回転・伸縮せず、付け根から足を移動する。
    if (move=="kick" && t && attack && int(t->stage)<=2) {
        const double recovery_total=attack->hold+(attack->return_speed>0?godot::Math::PI/attack->return_speed:0)+attack->recover;
        const double active_time=std::max(0.0,t->elapsed-attack->warn);
        const double recovery_time=std::max(0.0,recovery_total-t->remaining);
        const double fold=windup?godot::Math::smoothstep(0.05,attack->warn*0.55,t->elapsed):0;
        const double kick=active?godot::Math::smoothstep(0.0,attack->active*0.25,active_time):
            t->stage==TechniqueStage::Recovery?1.0-godot::Math::smoothstep(attack->hold,attack->hold+0.45,recovery_time):0.0;
        for (size_t i=2;i<4;++i) {
            const std::string base=std::string("Parts/")+feet[i];const auto leg=find(nodes,base),foot=find(nodes,base+"/Foot");
            if (!leg || !foot) return false;
            const auto &rest=data.nodes[foot-1];const double side=i==2?-1.0:1.0;
            nodes[leg].rotation=0;nodes[leg].scale=Vector2(1,1);
            nodes[foot].rotation=0;
            nodes[foot].position=Vector2(rest.x+side*(kick*7-fold*3),rest.y+fold*14-kick*125);
        }
        nodes[head].position+=Vector2(0,fold*4-kick*3);
        nodes[torso].position=Vector2(0,-37+fold*6+kick*5);
    }
    transforms(nodes,body_world);
    const double phase_progress=body.phase>=2?(body.mode==BossMode::Phase?1.0-body.phase_remaining/std::max(0.001,body_def.phase_time):1.0):0.0;
    size_t horn_frame=0;
    if (body.phase>=2) {
        double duration=0;for (size_t i=1;i<data.horns.size();++i) duration+=data.horns[i].duration;
        double time=phase_progress*duration;
        for (size_t i=1;i<data.horns.size();++i) {horn_frame=i;if (time<data.horns[i].duration) break;time-=data.horns[i].duration;}
    }
    const Vector2 origin=body_world.affine_inverse().xform(nodes[horn].world.get_origin());
    const Vector2 axis=body_world.affine_inverse().basis_xform(nodes[horn].world.basis_xform(Vector2(0,1))).normalized();
    const auto &boss=c.bosses[body_def.boss-1];
    const double length=enemy.radius*(boss.horn_length_ratio+(boss.horn_length_ratio_p2-boss.horn_length_ratio)*phase_progress);
    nodes[horn].scale.y=std::max(1.0,length-double(origin.dot(axis)))/(k*data.horns[horn_frame].core_length);
    transforms(nodes,body_world);
    MonocerosSweepVisualSystem::step(run,body,t,nodes[head].world.get_origin(),nodes[horn].world.xform(Vector2(0,data.horns[horn_frame].core_length)));
    pose.nodes.clear();body.image_parts.clear();
    for (size_t i=1;i<nodes.size();++i) pose.nodes.push_back({uint32_t(i),nodes[i].world,nodes[i].visible});
    for (const auto &sprite:data.sprites) {
        if (!sprite.node || sprite.node>=nodes.size() || !sprite.hframes || !sprite.vframes) return false;
        uint32_t mask=sprite.mask,x=sprite.region_x,y=sprite.region_y,w=sprite.region_w/sprite.hframes,h=sprite.region_h/sprite.vframes;
        if (sprite.gait_slot>=0 && sprite.gait_slot<4) {
            const size_t f=(sprite.gait_slot==0 || sprite.gait_slot==3)?first:opposite;const auto &g=data.gait[f];
            mask=sprite.gait_armor?g.armor_mask:g.base_mask;x=sprite.gait_armor?g.armor_x:g.base_x;y=sprite.gait_armor?g.armor_y:g.base_y;w=sprite.gait_armor?g.armor_w:g.base_w;h=sprite.gait_armor?g.armor_h:g.base_h;
        } else {const uint32_t frame=sprite.horn?uint32_t(horn_frame):sprite.frame;x+=(frame%sprite.hframes)*w;y+=(frame/sprite.hframes)*h;}
        if (!mask || !w || !h) return false;
        Vector2 origin(sprite.offset_x,sprite.offset_y);if (sprite.centered) origin-=Vector2(w,h)*0.5;
        const double sx=sprite.flip_h?-1:1,sy=sprite.flip_v?-1:1;if (sprite.flip_h) origin.x+=w;if (sprite.flip_v) origin.y+=h;
        BossImagePart part;part.part=sprite.id;part.mask=mask;part.region=godot::Rect2i(x,y,w,h);
        part.pixel_to_world=nodes[sprite.node].world*Transform2D(Vector2(sx,0),Vector2(0,sy),origin);
        part.visible=body.mode<BossMode::Defeated;for (uint32_t n=sprite.node;n;n=nodes[n].parent) part.visible=part.visible && nodes[n].visible;
        body.image_parts.push_back(part);
    }
    body.monoceros->pose=std::move(pose);
    return true;
}
}
