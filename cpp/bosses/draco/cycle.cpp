#include "cycle.h"
#include "body.h"
#include "pose.h"
#include "picaro.h"
#include "cinematic.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
// 奥への往復の道と尺。承認済みの試作の値をそのまま使う。座標は機体を原点、上が負。
constexpr double PI=3.141592653589793,NEAR=650,FAR=1150,RADIUS=560,RATE=1.0744145734345427,SPEED=1000*RATE,FAR_SPEED=760*RATE;
constexpr double SHOT_FIRST=1.0,SHOT_STEP=0.9,FLY=0.38,FOLLOW=300;
const godot::Vector2 LOOP(-840,-1300),VIEW(-150,-420);
struct Way {godot::Vector2 p;double z;};
const DracoCycleDefinition *rule(const RunRuntime &r,const BossBodyState &b) {const auto boss=r.content->boss_bodies[b.definition-1].boss;const auto it=std::find_if(r.content->draco_cycles.begin(),r.content->draco_cycles.end(),[&](const auto &p){return p.boss==boss;});return it==r.content->draco_cycles.end()?nullptr:&*it;}
double smooth(double x) {x=std::clamp(x,0.0,1.0);return x*x*(3-2*x);}
godot::Vector2 flip(godot::Vector2 p,double mirror) {return {float(p.x*mirror),p.y};}
godot::Vector2 loop_point(double degrees,double mirror) {const double a=degrees*PI/180;return flip(LOOP+godot::Vector2(std::cos(a),-std::sin(a))*RADIUS,mirror);}
// c[from]〜c[to] を通るなめらかな道を足す。前後の点は向きを決めるために使う。
void spline(const std::vector<Way> &c,size_t from,size_t to,std::vector<godot::Vector2> &points,std::vector<double> &depths) {
    for (size_t i=from;i<to;++i) for (int j=0;j<40;++j) {
        const double t=double(j)/40;const auto q=[&](double a,double b,double c2,double d){return 0.5*(2*b+(-a+c2)*t+(2*a-5*b+4*c2-d)*t*t+(-a+3*b-3*c2+d)*t*t*t);};
        points.push_back({float(q(c[i-1].p.x,c[i].p.x,c[i+1].p.x,c[i+2].p.x)),float(q(c[i-1].p.y,c[i].p.y,c[i+1].p.y,c[i+2].p.y))});depths.push_back(std::max(0.0,q(c[i-1].z,c[i].z,c[i+1].z,c[i+2].z)));
    }
    points.push_back(c[to].p);depths.push_back(c[to].z);
}
void measure(const std::vector<godot::Vector2> &points,std::vector<double> &arc) {arc.assign(points.size(),0);for (size_t j=1;j<points.size();++j) arc[j]=arc[j-1]+points[j-1].distance_to(points[j]);}
Way along(const std::vector<godot::Vector2> &points,const std::vector<double> &depths,const std::vector<double> &arc,double s) {
    if (s<=0) {const auto back=(points[0]-points[1]).normalized();return {points[0]+back*-s,depths[0]};}
    if (s>=arc.back()) return {points.back(),depths.back()};
    const size_t j=size_t(std::upper_bound(arc.begin(),arc.end(),s)-arc.begin());const double span=arc[j]-arc[j-1],k=span>0.0001?(s-arc[j-1])/span:0;
    return {points[j-1].lerp(points[j],k),depths[j-1]+(depths[j]-depths[j-1])*k};
}
// 道の上の点。zone は 0＝奥へ向かう道、1＝奥の周回、2＝帰りの道。
Way path_at(const DracoCycleState &v,double s,int &zone) {
    if (v.exit_s>=0 && s>v.exit_s) {zone=2;return along(v.back,v.back_z,v.back_arc,s-v.exit_s);}
    if (s>=v.loop_start) {zone=1;const double a=PI/2+(s-v.loop_start)/RADIUS;return {flip(LOOP+godot::Vector2(std::cos(a),-std::sin(a))*RADIUS,v.mirror),FAR};}
    zone=0;return along(v.out,v.out_z,v.out_arc,s);
}
// 周回の出口（帰りの道の入口）のうち、s 以降で最初のもの。
double next_exit(const DracoCycleState &v,double s) {const double first=v.loop_start+RADIUS*PI*1.75,lap=RADIUS*PI*2;return first+lap*std::max(0.0,std::ceil((s-first)/lap));}
double end_s(const DracoCycleState &v) {return v.exit_s+v.back_arc.back();}
// 道の原点。試作の画面と同じく、画面の中心から見た位置に置く。
godot::Vector2 origin(const RunRuntime &r,double mirror) {return r.state.view_center-flip(VIEW,mirror);}
// 手前の部位はフィールドに留まり、奥の部位は画面に対して留まる。奥ほど画面の中心へ寄って小さくなる。
void place(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco->cycle;auto &d=*b.draco;auto &e=r.state.enemies[b.actor.slot];const auto &p=DracoBody::rule(r,b);
    const auto center=r.state.view_center,screen=origin(r,v.mirror);
    d.override_points.resize(p.body_segments+1);d.scales.resize(p.body_segments+1);
    for (uint32_t j=0;j<=p.body_segments;++j) {
        int zone=0;const auto at=path_at(v,v.s-p.body_length*double(j)/p.body_segments,zone);const double follow=zone==1?1.0:smooth(at.z/FOLLOW),near=1/(1+at.z/NEAR);
        const auto world=at.p+(zone==2?v.landing:v.anchor).lerp(screen,follow);d.override_points[j]=center+(world-center)*near;d.scales[j]=near;
    }
    int zone=0;const auto head=path_at(v,v.s,zone),neck=path_at(v,v.s-70,zone);const double free=(head.p-neck.p).angle();
    e.pos=d.override_points[0];e.vel={};
    double facing=v.face+angle_difference(free-v.face)*smooth(v.time/0.4);
    if (v.stage==DracoCycleStage::Return && v.stop_time>=0) facing=free+angle_difference((r.state.ship_pos-e.pos).angle()-free)*smooth((v.stop_time-(v.stop_duration-1.6))/1.5);
    if (v.stage!=DracoCycleStage::Collect || v.time>=0.4) v.face=facing;
    e.facing=facing;
}
// 今の体の形を道の始まりにして、頭の先へ、向きを変えて奥の周回へ入る道を継ぐ。
void launch(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco->cycle;const auto &e=r.state.enemies[b.actor.slot];DracoPose::reset(r,b);const auto pose=DracoPose::points(r,b);
    v.mirror=e.pos.x>=r.state.view_center.x?1:-1;v.anchor=origin(r,v.mirror);v.out.clear();v.out_z.clear();v.back.clear();v.back_z.clear();v.back_arc.clear();v.spots.clear();
    for (size_t j=pose.size();j-->1;) {v.out.push_back(pose[j]-v.anchor);v.out_z.push_back(0);}
    const auto head=pose.front()-v.anchor,behind=pose[std::min(pose.size()-1,pose.size()/6)]-v.anchor,entry=loop_point(0,v.mirror);
    auto forward=(head-behind).normalized();if (forward.is_zero_approx()) forward=godot::Vector2::from_angle(e.facing);
    const auto turn=forward.rotated((forward.cross(entry-head)>=0?1:-1)*PI/6)*253;
    std::vector<Way> c{{behind,0},{head,0},{head+turn,0}};
    const auto dive=flip({140,-500},v.mirror),funnel=flip({-80,-760},v.mirror);
    if ((dive-c.back().p).length()>200 && (dive-c.back().p).dot(funnel-c.back().p)>0) c.push_back({dive,0});
    c.push_back({funnel,200});c.push_back({flip({-240,-1040},v.mirror),600});const size_t far=c.size();
    c.push_back({entry,950});for (double a:{45.0,90.0,135.0}) c.push_back({loop_point(a,v.mirror),FAR});
    const size_t before=v.out.size();spline(c,1,far,v.out,v.out_z);const size_t at_far=v.out.size()-1;spline(c,far,far+2,v.out,v.out_z);
    measure(v.out,v.out_arc);v.s=v.out_arc[before];v.far_s=v.out_arc[at_far];v.loop_start=v.out_arc.back();
    v.exit_s=v.rise_time=v.stop_time=-1;v.speed=v.far_time=v.settle=0;v.leaving=v.first;v.landed=false;v.face=e.facing;v.landing=v.anchor;
}
// 周回から回りながら浮かび上がり、機体へ顔を向けて止まる道。
void bake_return(DracoCycleState &v) {
    std::vector<Way> c;for (double a:{360.0,405.0}) c.push_back({loop_point(a,v.mirror),FAR});
    c.push_back({loop_point(450,v.mirror),560});c.push_back({loop_point(495,v.mirror),60});c.push_back({loop_point(540,v.mirror),0});c.push_back({loop_point(585,v.mirror),0});
    for (auto p:{godot::Vector2(-960,-640),godot::Vector2(-660,-420),godot::Vector2(-520,-300)}) c.push_back({flip(p,v.mirror),0});
    v.back.clear();v.back_z.clear();spline(c,1,c.size()-2,v.back,v.back_z);measure(v.back,v.back_arc);
}
// 浮かび上がる先は機体を追い、頭が手前へ出たところで決める。止まる位置はフィールドの中に収める。
void aim_landing(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco->cycle;if (v.landed) return;const auto &p=DracoBody::rule(r,b);
    const double margin=p.head_radius*b.draco->head_scale+40,limit=std::max(margin,r.state.ship_config.field_radius-margin);
    v.landing=origin(r,v.mirror);const auto stop=v.landing+v.back.back();v.landing+=stop.limit_length(limit)-stop;v.home=v.landing+v.back.back();
    int zone=0;if (v.exit_s>=0 && path_at(v,v.s,zone).z<=FOLLOW && zone==2) v.landed=true;
}
bool advance(RunRuntime &r,BossBodyState &b,double dt) {
    auto &v=b.draco->cycle;const bool returning=v.stage==DracoCycleStage::Return;
    if (returning && v.stop_time<0 && end_s(v)-v.s<=0.95*v.speed) {v.stop_time=0;v.stop_distance=end_s(v)-v.s;v.stop_duration=2*v.stop_distance/std::max(1.0,v.speed);}
    if (v.stop_time>=0) {
        v.stop_time+=dt;const double u=std::min(1.0,v.stop_time/v.stop_duration);v.s=end_s(v)-v.stop_distance*(1-2*(u-u*u*u+u*u*u*u/2));
        v.settle=smooth((v.stop_time-(v.stop_duration-0.6))/0.8);return u>=1;
    }
    const double target=returning || v.s<v.far_s?SPEED:FAR_SPEED,rate=!returning && v.speed<target?SPEED/0.7:(SPEED-FAR_SPEED)/0.5;
    v.speed+=std::clamp(target-v.speed,-rate*dt,rate*dt);v.s+=v.speed*dt;
    if (v.s>=v.far_s) v.far_time+=dt;if (v.exit_s>=0 && v.s>v.exit_s) v.rise_time=std::max(0.0,v.rise_time)+dt;
    return false;
}
godot::Vector2 mouth(const RunRuntime &r,const BossBodyState &b) {const auto &e=r.state.enemies[b.actor.slot];return e.pos+godot::Vector2::from_angle(e.facing)*120*b.draco->head_scale;}
// 顔の前、口の先の扇形に並ぶ生成位置。
void aim_spots(RunRuntime &r,BossBodyState &b,uint32_t count) {
    auto &v=b.draco->cycle;const auto &e=r.state.enemies[b.actor.slot];const auto from=mouth(r,b);v.spots.clear();const double step=count>1?std::min(0.62,1.9/(count-1)):0;
    // 試作では口から機体まで約620。機体が近いときは同じ割合で口へ寄せ、機体に重ねない。
    const double reach=std::min(1.0,double(from.distance_to(r.state.ship_pos))/620);
    for (uint32_t j=0;j<count;++j) {const double offset=double(j)-double(count-1)/2;v.spots.push_back(from+godot::Vector2::from_angle(e.facing+offset*step)*(285-40*std::min(1.0,std::abs(offset)))*reach);}
}
double generate_time(uint32_t count) {return SHOT_FIRST+SHOT_STEP*(std::max(1u,count)-1)+FLY+1.0;}
void finish(RunRuntime &r,BossBodyState &b) {auto &v=b.draco->cycle;const bool first=v.first;DracoCinematic::restore(r,v.saved);v.stage=DracoCycleStage::None;v.first=false;v.time=0;v.next_cycle=10;v.swim=v.settle=0;DracoPose::reset(r,b);b.mode=BossMode::Idle;r.state.enemies[b.actor.slot].guard=0;if (first) r.state.encounter_protected=false;b.draco->picaro_attacking=false;}
bool alive(const RunRuntime &r,const DracoPicaroMember &m) {return r.state.enemy_handles.contains(m.actor) && !r.state.enemies[m.actor.slot].dead;}
}
bool DracoCycle::background(const godot::RunState &s,EnemyHandle actor) {
    if (!s.enemy_handles.contains(actor) || !s.enemies[actor.slot].is_boss) return false;
    const auto parent=s.enemies[actor.slot].damage_target;
    if (s.enemy_handles.contains(parent)) actor=parent;
    for (const auto &b:s.bosses->bodies) if (same_handle(b.actor,actor)) {
        const auto stage=b.draco->cycle.stage;
        return stage==DracoCycleStage::Collect || stage==DracoCycleStage::WaitBeams || stage==DracoCycleStage::Return;
    }
    return false;
}
bool DracoCycle::begin_initial(RunRuntime &r,BossBodyState &b) {
    if (!rule(r,b)) return false;if (b.draco->cycle.stage!=DracoCycleStage::None) cancel(r,b);auto &v=b.draco->cycle;auto &s=r.state;auto &e=s.enemies[b.actor.slot];DracoCinematic::capture(r,v.saved);v.first=true;v.stage=DracoCycleStage::Roar;v.time=0;v.generated=0;v.swim=0;v.home=e.pos;v.zoom=std::max(0.1,s.control.camera_zoom);launch(r,b);s.control.cinematic_camera=true;s.controls_locked=true;s.control.cinematic_bars=1;s.encounter_protected=true;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};e.guard=1;return true;
}
bool DracoCycle::begin_deep(RunRuntime &r,BossBodyState &b) {
    // 通常攻撃が姿勢を更新している間は、奥への移動を始めない。
    if (std::any_of(r.state.bosses->techniques.begin(),r.state.bosses->techniques.end(),[&](const auto &t){return same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished;})) return false;
    if (!rule(r,b) || b.draco->cycle.stage!=DracoCycleStage::None) return false;auto &v=b.draco->cycle;v.first=false;v.stage=DracoCycleStage::Collect;v.time=0;v.generated=0;v.swim=0;v.home=r.state.enemies[b.actor.slot].pos;launch(r,b);r.state.enemies[b.actor.slot].guard=1;b.draco->picaro_attacking=true;return true;
}
bool DracoCycle::tick(RunRuntime &r,BossBodyState &b,double dt) {
    const auto *p=rule(r,b);if (!p) return false;auto &v=b.draco->cycle;auto &e=r.state.enemies[b.actor.slot];
    if (v.stage==DracoCycleStage::None) {bool enabled=!r.state.control.lab_mode;for (const auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) enabled=f.selection_enabled;if (enabled && b.phase>=2 && b.mode==BossMode::Idle) {v.next_cycle-=dt;if (v.next_cycle<=0) begin_deep(r,b);}return v.stage!=DracoCycleStage::None;}
    v.time+=dt;e.vel={};if (v.first) DracoCinematic::frame(r,r.state.ship_pos.lerp(e.pos,0.55),v.zoom*0.8);
    const double before=v.s;
    switch (v.stage) {
    case DracoCycleStage::Roar:v.swim=smooth(v.time/0.5);if (v.time>=1) {v.stage=DracoCycleStage::Collect;v.time=0;v.face=e.facing;}break;
    case DracoCycleStage::Collect: {
        v.swim=std::max(v.swim,smooth(v.time/0.5));advance(r,b,dt);e.guard=1;
        const bool any=std::any_of(b.draco->picaro.begin(),b.draco->picaro.end(),[&](const auto &m){return alive(r,m);});
        if (v.s>=v.far_s && (v.first || v.time>=p->collect_time || !any)) v.leaving=true;
        // 出口の手前でピカロの新しい攻撃を止め、続いている攻撃が終わるのを待つ。
        if (v.leaving && next_exit(v,v.s)-v.s<=FAR_SPEED) {DracoPicaro::pause(r,b,false);v.stage=DracoCycleStage::WaitBeams;}
        break;}
    case DracoCycleStage::WaitBeams: {
        advance(r,b,dt);const double exit=next_exit(v,before);
        bool busy=false;for (const auto &m:b.draco->picaro) if (alive(r,m)) for (const auto &h:r.state.hazards) if (h.alive) {const auto *attack=AttackSystem::get(r.state,h.attack);if (attack && same_handle(attack->spec.owner.live_source,m.actor)) busy=true;}
        if (v.s>=exit && !busy) {v.exit_s=exit;bake_return(v);v.stage=DracoCycleStage::Return;v.time=0;}
        break;}
    case DracoCycleStage::Return:
        if (advance(r,b,dt)) {aim_landing(r,b);v.landed=true;place(r,b);DracoPose::reset(r,b);e.guard=v.first?1:0;v.stage=DracoCycleStage::Generate;v.time=0;v.generated=0;v.settle=smooth(0.75);aim_spots(r,b,p->count);}
        break;
    case DracoCycleStage::Generate:
        v.settle=smooth((0.6+v.time)/0.8);v.swim=1-smooth((v.time-(generate_time(p->count)-0.6))/0.6);
        if (v.generated<p->count && v.time>=SHOT_FIRST+SHOT_STEP*v.generated+FLY) {std::vector<const DracoCycleCandidate *> choices;for (const auto &c:r.content->draco_cycle_candidates) if (c.cycle==p->id) choices.push_back(&c);const auto &chosen=*choices[*r.state.control.rng.randi_range(0,choices.size()-1)];if (!chosen.excluded) DracoPicaro::spawn(r,b,chosen.enemy,v.spots[v.generated]);++v.generated;}
        if (v.time>generate_time(p->count)) finish(r,b);
        break;
    case DracoCycleStage::None:break;
    }
    if (v.stage>=DracoCycleStage::Roar && v.stage<=DracoCycleStage::Return) {if (v.stage==DracoCycleStage::Return) aim_landing(r,b);place(r,b);}
    DracoBody::update(r,b);return v.stage!=DracoCycleStage::None;
}
void DracoCycle::cancel(RunRuntime &r,BossBodyState &b) {auto &v=b.draco->cycle;if (v.stage==DracoCycleStage::None && !v.saved.saved) return;const bool first=v.first;DracoCinematic::restore(r,v.saved);if (first) r.state.encounter_protected=false;v.stage=DracoCycleStage::None;v.first=false;v.time=0;v.next_cycle=10;v.swim=v.settle=0;DracoPose::reset(r,b);if (r.state.enemy_handles.contains(b.actor)) {r.state.enemies[b.actor.slot].guard=0;if (b.mode==BossMode::Phase) b.mode=BossMode::Idle;DracoBody::update(r,b);}b.draco->picaro_attacking=false;}
bool DracoCycle::validate(const BossBodyState &b) {
    const auto &v=b.draco->cycle;
    for (double x:{v.time,v.next_cycle,v.zoom,v.s,v.speed,v.far_s,v.loop_start,v.exit_s,v.mirror,v.face,v.far_time,v.rise_time,v.stop_time,v.stop_distance,v.stop_duration,v.settle,v.swim,v.saved.zoom,v.saved.bars,v.saved.world_scale}) if (!std::isfinite(x)) return false;
    for (auto p:{v.home,v.anchor,v.landing,v.saved.center,v.saved.half,v.saved.heading}) if (!p.is_finite()) return false;
    for (const auto *points:{&v.out,&v.back,&v.spots}) for (auto point:*points) if (!point.is_finite()) return false;
    for (const auto *values:{&v.out_z,&v.out_arc,&v.back_z,&v.back_arc}) for (double x:*values) if (!std::isfinite(x) || x<0) return false;
    if (v.out.size()!=v.out_z.size() || v.out.size()!=v.out_arc.size() || v.back.size()!=v.back_z.size() || v.back.size()!=v.back_arc.size()) return false;
    const bool moving=v.stage>=DracoCycleStage::Roar && v.stage<=DracoCycleStage::Return;
    if (moving && (v.out.size()<2 || v.loop_start<=0 || (v.exit_s>=0)!=(v.stage==DracoCycleStage::Return) || (v.exit_s>=0 && v.back.size()<2))) return false;
    return v.stage<=DracoCycleStage::Generate && v.time>=0 && v.zoom>0 && std::abs(std::abs(v.mirror)-1)<0.001 && (!v.first || v.saved.saved);
}
void DracoCycle::snapshot(const BossBodyState &b,godot::Dictionary &out) {
    const auto &v=b.draco->cycle;godot::Dictionary p;p["stage"]=int(v.stage);p["first"]=v.first;p["time"]=v.time;p["next_cycle"]=v.next_cycle;p["home"]=v.home;p["generated"]=v.generated;
    // 表示が使う値：奥にいる時間、浮かび上がり始めてからの時間、体のうねりと落ち着き、吐き出す時刻と行き先。
    p["far"]=v.far_time;p["rise"]=v.rise_time;p["swim"]=v.swim;p["settle"]=v.settle;p["shot_first"]=SHOT_FIRST;p["shot_step"]=SHOT_STEP;p["fly"]=FLY;
    godot::PackedVector2Array spots;if (v.stage==DracoCycleStage::Generate) for (auto spot:v.spots) spots.push_back(spot);p["spots"]=spots;out["cycle"]=p;
}
}
