#include "intro.h"
#include "body.h"
#include "pose.h"
#include "cinematic.h"
#include "../../systems/field.h"
#include "../../state/boss_states.h"
#include "state.h"
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
namespace {
// 登場の尺と動きは、承認済みの試作の値をそのまま使う。時刻は裂け目が開く1.2秒前を0とする。
constexpr double PI=3.141592653589793,TEAR=1.2,EYES=3.1,APPROACH=4.7,PEEK_AT=7.1,BURST=8.6,SETTLE=12.2,RETURN=13.0,TOTAL=14.0;
constexpr double PEEK=125,RECOIL=95,ARRIVE=3.35,BURST_TIME=3.6,BURST_EASE=2.4,PATH_STEP=8,CHEST=110;
double smooth(double a,double b,double x) {x=std::clamp((x-a)/(b-a),0.0,1.0);return x*x*(3-2*x);}
double out_cubic(double k) {return 1-std::pow(1-std::clamp(k,0.0,1.0),3);}
double mix(double a,double b,double k) {return a+(b-a)*k;}
// ゆっくり動き出し、長く減速して止まる。
double glide(double k) {return 1-std::pow(1-smooth(0,1,k),1.6);}
godot::Vector2 safe_position(const RunRuntime &r,const BossBodyState &b,godot::Vector2 ship) {
    const auto &p=DracoBody::rule(r,b);const double margin=p.head_radius*b.draco->head_scale+40,limit=std::max(margin,r.state.ship_config.field_radius-margin);const auto desired=ship+godot::Vector2(0,-430);auto candidate=desired.limit_length(limit);
    for (int j=0;j<4;++j) candidate=FieldSystem::push_out(r,candidate,margin).limit_length(limit);
    const auto clear=[&](godot::Vector2 at){return at.length()<=limit+0.1 && FieldSystem::body_gap(r,at,margin)>=-0.1;};
    if (clear(candidate)) return candidate;auto best=candidate;double best_score=std::numeric_limits<double>::infinity();
    for (double distance:{430.0,650.0,900.0}) for (int j=0;j<24;++j) {auto point=(ship+godot::Vector2::from_angle(-1.5707963267948966+j*6.283185307179586/24)*distance).limit_length(limit);if (!clear(point)) continue;const double score=point.distance_squared_to(desired)+std::max(0.0,double(point.y-ship.y))*1000;if (score<best_score) {best=point;best_score=score;}}
    return best;
}
// 頭が裂け目から出て対面の位置へ着くまでの道。対面の位置の430下を原点に置く。
void bake_path(DracoIntroState &v,godot::Vector2 base) {
    static const double way[][2]={{0,-1130},{0,-800},{0,-470},{190,-300},{520,-290},{760,-500},{740,-780},{470,-900},{150,-800},{0,-430},{0,-150}};
    const int count=int(sizeof(way)/sizeof(way[0]));std::vector<godot::Vector2> dense;
    for (int i=1;i<count-2;++i) for (int j=0;j<40;++j) {const double t=double(j)/40;const auto q=[&](int k){const double a=way[i-1][k],b=way[i][k],c=way[i+1][k],d=way[i+2][k];return 0.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t);};dense.push_back(base+godot::Vector2(q(0),q(1)));}
    dense.push_back(base+godot::Vector2(way[count-2][0],way[count-2][1]));
    double total=0;for (size_t j=1;j<dense.size();++j) total+=dense[j-1].distance_to(dense[j]);
    const int steps=std::max(1,int(std::ceil(total/PATH_STEP)));v.path_step=total/steps;v.path.clear();size_t at=0;double traversed=0;
    for (int j=0;j<=steps;++j) {const double target=std::min(total,v.path_step*j);while (at+2<dense.size() && target>traversed+dense[at].distance_to(dense[at+1])) {traversed+=dense[at].distance_to(dense[at+1]);++at;}const double span=dense[at].distance_to(dense[at+1]);v.path.push_back(dense[at].lerp(dense[at+1],span>0.0001?std::clamp((target-traversed)/span,0.0,1.0):0.0));}
}
double path_length(const DracoIntroState &v) {return v.path_step*double(v.path.size()-1);}
// 負の位置は裂け目の奥。当たり判定の列は、道の入口から真上へまっすぐ伸ばしておく。
godot::Vector2 path_at(const DracoIntroState &v,double s) {
    if (s<=0) return v.path.front()+godot::Vector2(0,s);const double f=std::min(s/v.path_step,double(v.path.size()-1));const size_t i=std::min(size_t(f),v.path.size()-2);return v.path[i].lerp(v.path[i+1],f-double(i));
}
double head_position(double t,double length) {
    if (t<EYES) return -1000;
    if (t<APPROACH) return mix(-1000,-850,smooth(0,APPROACH-EYES,t-EYES));
    if (t<BURST) return mix(-850,PEEK,glide(std::clamp((t-APPROACH)/ARRIVE,0.0,1.0)))-(PEEK-RECOIL)*smooth(BURST-PEEK_AT-0.45,BURST-PEEK_AT,t-PEEK_AT);
    return mix(RECOIL,length,1-std::pow(1-std::clamp((t-BURST)/BURST_TIME,0.0,1.0),BURST_EASE));
}
double head_facing(const DracoIntroState &v,double s) {
    const double blend=smooth(PEEK,PEEK+260,s);if (blend<=0) return PI*0.5;const double free=(path_at(v,s)-path_at(v,s-60)).angle();return PI*0.5+std::remainder(free-PI*0.5,PI*2)*blend;
}
void place(RunRuntime &r,BossBodyState &b,double s) {
    auto &v=b.draco->intro;const auto &p=DracoBody::rule(r,b);auto &points=b.draco->override_points;points.resize(p.body_segments+1);
    for (uint32_t j=0;j<=p.body_segments;++j) points[j]=path_at(v,s-p.body_length*double(j)/p.body_segments);
    auto &e=r.state.enemies[b.actor.slot];e.pos=path_at(v,std::max(0.0,s));e.facing=head_facing(v,s);e.vel={};
}
void apply(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco->intro;const auto &p=DracoBody::rule(r,b);const double quiet=p.entrance_quiet,t=v.time-quiet+TEAR,length=path_length(v);
    v.head_s=head_position(t,length);
    const double close_at=BURST+BURST_TIME*(1-std::pow(1-std::clamp((p.body_length+80-RECOIL)/(length-RECOIL),0.0,1.0),1/BURST_EASE)),closing=smooth(0,1,(t-close_at)/0.55);
    v.rift=t<TEAR?0:out_cubic((t-TEAR)/0.22)*(1-closing);v.rift_open=v.rift*(1-closing*0.5);v.rift_wide=t<TEAR?0:120+60*smooth(-520,-60,v.head_s);
    const double lit=t-EYES;v.eyes=lit<0?0:smooth(0,0.18,lit)*(lit>0.42 && lit<0.5?0.15:1)*(1+0.12*std::sin(t*9))*(1-0.75*smooth(SETTLE,SETTLE+1,t));
    v.chest=smooth(-120,260,v.head_s-CHEST*b.draco->head_scale);v.chest_flare=v.chest*(1-smooth(RETURN,TOTAL,t));v.stage=t<TEAR?0:t<APPROACH?1:t<SETTLE?2:t<RETURN?3:4;
    place(r,b,v.head_s);
    // カメラ：通常の画面から対面の引きへ移り、裂け目へ寄って、飛び出しで一気に引く。倍率は高さ720の画面での値。
    const auto base=v.center+godot::Vector2(0,430);auto size=r.state.control.logical_size;if (size.x<=0 || size.y<=0) size={1280,720};const double scale=size.y/720.0;
    const double enter=smooth(0,std::max(0.01,std::min(1.5,quiet)),v.time),push=smooth(TEAR,EYES+0.5,t),creep=smooth(EYES,BURST,t),pull=out_cubic((t-BURST)/1.0),restore=smooth(RETURN,TOTAL,t);
    auto center=(base+godot::Vector2(0,-380)).lerp(base+godot::Vector2(0,-790),push)+godot::Vector2(0,creep*18);double zoom=mix(0.5,1.15,push)+creep*0.07;
    center=center.lerp(base+godot::Vector2(140,-440),pull);zoom=mix(zoom,0.47,pull);
    double shake=0;if (t>TEAR && t<TEAR+0.4) shake=7*(1-(t-TEAR)/0.4);if (t>BURST && t<BURST+0.6) shake=std::max(shake,12*(1-(t-BURST)/0.6));
    center+=godot::Vector2(std::sin(t*83),std::cos(t*71))*(shake/zoom);
    DracoCinematic::frame(r,v.camera.lerp(center,enter).lerp(v.camera,restore),mix(mix(v.zoom,zoom*scale,enter),v.zoom,restore));r.state.control.cinematic_bars=1-restore;DracoBody::update(r,b);
}
}
void DracoIntro::begin(RunRuntime &r,BossBodyState &b) {
    if (b.draco->intro.active) end(r,b,true);auto &s=r.state;auto &e=s.enemies[b.actor.slot];auto &v=b.draco->intro;DracoCinematic::capture(r,v.saved);v.origin=e.pos;v.facing=e.facing;v.guard=e.guard;v.mode=b.mode;v.ship=s.ship_pos;v.camera=s.view_center;v.zoom=std::max(0.1,s.control.camera_zoom);v.center=safe_position(r,b,v.ship);v.rift_center=v.center+godot::Vector2(0,-370);v.active=true;v.time=0;v.stage=0;v.rift=v.rift_open=v.rift_wide=v.eyes=v.chest=v.chest_flare=0;DracoPose::reset(r,b);v.trail=b.draco->trail;bake_path(v,v.center+godot::Vector2(0,430));b.mode=BossMode::Entrance;e.guard=1;s.controls_locked=s.encounter_protected=true;s.control.cinematic_bars=1;s.control.cinematic_camera=s.control.cinematic_hide_enemies=true;s.ship.heading={0,-1};s.ship.vel={};s.draw.drawing=s.draw.tracing=false;
    for (uint32_t row=0;row<s.enemies.size();++row) {auto &member=s.enemies[row];if (member.alive && !member.dead && !member.is_boss) {v.held.push_back({s.enemy_handles.at(row),member.held});member.held=true;}}
    apply(r,b);
}
bool DracoIntro::tick(RunRuntime &r,BossBodyState &b,double dt) {
    auto &v=b.draco->intro;if (!v.active) return false;v.time+=dt;apply(r,b);if (v.time-DracoBody::rule(r,b).entrance_quiet+TEAR>=TOTAL) end(r,b);return v.active;
}
void DracoIntro::end(RunRuntime &r,BossBodyState &b,bool interrupted) {
    auto &v=b.draco->intro;if (!v.active) return;v.active=false;v.stage=0;for (const auto &member:v.held) if (r.state.enemy_handles.contains(member.actor)) r.state.enemies[member.actor.slot].held=member.held;v.held.clear();DracoCinematic::restore(r,v.saved);auto &d=*b.draco;
    if (r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];
        // 自然終了とスキップは、道を抜け切った対面の姿勢で戦闘へ渡す。中断は登場前の位置と姿勢へ戻す。
        if (interrupted) {d.override_points.clear();d.pose.clear();d.trail=v.trail;e.pos=v.origin;e.facing=v.facing;} else place(r,b,path_length(v));
        e.guard=v.guard;e.vel={};}
    DracoPose::reset(r,b);b.mode=interrupted?v.mode:BossMode::Idle;v.rift=v.rift_open=v.rift_wide=v.eyes=v.chest=v.chest_flare=v.head_s=0;v.path.clear();v.trail.clear();DracoBody::update(r,b);
}
bool DracoIntro::validate(const godot::RunState &,const BossBodyState &b) {
    const auto &v=b.draco->intro;for (double n:{v.time,v.rift,v.rift_open,v.rift_wide,v.eyes,v.chest,v.chest_flare,v.head_s,v.path_step,v.zoom,v.facing,v.guard,v.saved.bars,v.saved.zoom,v.saved.world_scale}) if (!std::isfinite(n)) return false;for (auto p:{v.origin,v.ship,v.camera,v.center,v.rift_center,v.saved.center,v.saved.half,v.saved.heading}) if (!p.is_finite()) return false;for (const auto *list:{&v.path,&v.trail}) for (auto p:*list) if (!p.is_finite()) return false;return v.time>=0 && v.zoom>0 && v.stage<=4 && (!v.active || (v.saved.saved && b.mode==BossMode::Entrance && v.path.size()>=2 && v.path_step>0));
}
void DracoIntro::snapshot(const BossBodyState &b,godot::Dictionary &p) {
    const auto &v=b.draco->intro;godot::Dictionary q;q["active"]=v.active;q["time"]=v.time;q["stage"]=int(v.stage);q["rift"]=v.rift;q["rift_open"]=v.rift_open;q["rift_wide"]=v.rift_wide;q["eyes"]=v.eyes;q["chest_glow"]=v.chest;q["chest_flare"]=v.chest_flare;q["head_s"]=v.head_s;q["center"]=v.center;q["rift_center"]=v.rift_center;
    if (v.active) {const auto base=v.center+godot::Vector2(0,430);q["rift_from"]=base+godot::Vector2(-440,-745);q["rift_to"]=base+godot::Vector2(440,-855);godot::PackedVector2Array path;for (auto point:v.path) path.push_back(point);q["path"]=path;q["path_step"]=v.path_step;}
    p["intro"]=q;
}
}
