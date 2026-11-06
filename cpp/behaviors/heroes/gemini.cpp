#include "gemini.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include "../../systems/attack_system.h"
#include "../../systems/equipment.h"
#include "../weapons/endBlast.h"
#include "../weapons/mines.h"
#include "../weapons/bipolar.h"
#include "../weapons/afterimage.h"
#include "../weapons/dashRangeDrone.h"
#include "../weapons/massTow.h"
#include "../weapons/sonic.h"
#include "../weapons/interceptor.h"
#include <algorithm>
namespace speed {
namespace {
const GeminiDefinition *definition(const RunRuntime &r) {
    const auto &s=r.state;if (s.heroes.active<=0) return nullptr;
    for (const auto &d:r.content->gemini) if (d.hero==s.heroes.power) return &d;return nullptr;
}
}
// 影の機体は、描いた経路を「突進を始めた機体の位置を通り、それまでの機体の向きに平行な線」で左右反転した経路を同時に走る。
void GeminiBehavior::launch(RunRuntime &r,godot::Vector2 origin,godot::Vector2 axis) {
    auto &t=r.state.heroes.twin;const auto &path=r.state.draw.path;if (!definition(r) || path.size()<2 || axis.is_zero_approx()) return;
    const auto u=axis.normalized();t.path.clear();
    for (int64_t i=0;i<path.size();++i) {const auto d=path[i]-origin;t.path.push_back(origin+u*d.dot(u)*2.0-d);}
    t.position=t.path.front();t.rate=r.state.draw.rate;t.segment=0;t.segment_position=0;t.inside.clear();t.tracing=true;
    t.afterimage_echo=0;t.sonic_active=true;t.sonic_hits.clear();t.sonic_last=t.position;t.sonic_distance=t.sonic_emission=0;
}
bool GeminiBehavior::active(const RunRuntime &r) {return definition(r)!=nullptr;}
namespace {
// 並走する影の中心は、機体の右横へ機体の絵の SIDE ドット（gemini_twins.gd の SIDE と同じ）。分裂を見せ終わるまでは撃たない
constexpr double SIDE=40.0,SPLIT_TIME=1.15;
// 分裂を見せ終えてから、影の粒が集まってドローンなど外に付ける武器を形づくるまでの秒（gemini_twins.gd の ASSEMBLE_TIME と同じ）
constexpr double ASSEMBLE_TIME=0.6;
// 発動からの秒。効果が切れたあとも走っている影は、分裂も組み立ても済んだものとして扱う
double elapsed(const RunRuntime &r) {
    const auto &h=r.state.heroes;if (h.active<=0 || !h.power) return SPLIT_TIME+ASSEMBLE_TIME;
    return r.content->heroes[h.power-1].definition.duration-h.active;
}
}
// 影の外に付ける武器（エスコートウィングのドローン）が現れる進み（0〜1）。分裂し終えてから ASSEMBLE_TIME 秒で 1 になる
double GeminiBehavior::equipment_appear(const RunRuntime &r) {return std::clamp((elapsed(r)-SPLIT_TIME)/ASSEMBLE_TIME,0.0,1.0);}
// 突進していない間、影の位置を機体の右横へそろえる（武器の複製の起点）。
void GeminiBehavior::follow(RunRuntime &r) {
    auto &s=r.state;auto &t=s.heroes.twin;if (!definition(r) || t.tracing) return;
    const auto h=s.ship.heading.is_zero_approx()?godot::Vector2(1,0):s.ship.heading.normalized();
    t.position=s.ship.pos+godot::Vector2(-h.y,h.x)*SIDE*r.content->config.character_scale;
}
// 影も機体と同じように武器を使う：このフレームに武器が撃った弾（first_id 以降に生まれた弾）を、同じ向き・同じ性能で影の位置からも撃つ。
// 発射間隔などの状態は機体と共通。破片・船体・質量牽引の弾と、影が自分のドローンで撃つ迎撃ドローンの弾は複製しない
void GeminiBehavior::duplicate(RunRuntime &r,int64_t first_id) {
    auto &s=r.state;const auto *d=definition(r);if (!d || elapsed(r)<SPLIT_TIME) return;
    const auto offset=s.heroes.twin.position-s.ship.pos;if (!offset.is_finite() || offset.is_zero_approx()) return;
    std::vector<godot::RunState::Friendly> copies;std::vector<AttackSpec> specs;
    for (const auto &f:s.friends) {
        if (!f.alive || f.id<first_id || f.kind!=0 || f.visual==godot::StringName("weapon/massTow") || f.visual==godot::StringName("weapon/interceptor")) continue;
        const auto *record=AttackSystem::get(s,f.attack);if (!record) continue;
        auto copy=f;copy.pos+=offset;copy.hit_ids.clear();for (int64_t i=0;i<copy.trail.size();++i) copy.trail.set(i,copy.trail[i]+offset);
        copies.push_back(std::move(copy));specs.push_back(record->spec);
    }
    for (size_t i=0;i<copies.size();++i) AttackSystem::emit_friendly(r,std::move(copies[i]),specs[i]);
}
// 影がいる間（効いているか、走り出した影がまだ走っている間）の、影の位置・向き・速さ。
bool GeminiBehavior::motion(const RunRuntime &r,godot::Vector2 &pos,godot::Vector2 &heading,godot::Vector2 &velocity) {
    const auto &s=r.state;const auto &t=s.heroes.twin;if (!definition(r) && !t.tracing) return false;
    pos=t.position;heading=s.ship.heading;velocity=s.ship.vel;
    if (t.tracing && t.path.size()>=2) {const size_t seg=std::min(t.segment,t.path.size()-2);heading=(t.path[seg+1]-t.path[seg]).normalized();velocity=heading*t.rate;}
    return true;
}
namespace {
// 機体の武器を影として呼ぶ間だけ、機体の位置・向き・速さと、なぞりの経路・進み・状態を影のものへ差し替え、終わったら戻す
struct AsTwin {
    RunRuntime &r;godot::Vector2 pos,heading,velocity;godot::PackedVector2Array path;int64_t segment;double seg_pos;bool tracing;
    explicit AsTwin(RunRuntime &run):r(run) {
        auto &s=r.state;const auto &t=s.heroes.twin;pos=s.ship.pos;heading=s.ship.heading;velocity=s.ship.vel;path=s.draw.path;segment=s.draw.segment;seg_pos=s.draw.seg_pos;tracing=s.draw.tracing;
        GeminiBehavior::motion(r,s.ship.pos,s.ship.heading,s.ship.vel);
        if (t.path.size()>=2) {godot::PackedVector2Array twin_path;for (auto p:t.path) twin_path.push_back(p);s.draw.path=twin_path;s.draw.segment=int64_t(std::min(t.segment,t.path.size()-2));s.draw.seg_pos=t.segment_position;}
        s.draw.tracing=t.tracing;
    }
    ~AsTwin() {auto &s=r.state;s.ship.pos=pos;s.ship.heading=heading;s.ship.vel=velocity;s.draw.path=path;s.draw.segment=segment;s.draw.seg_pos=seg_pos;s.draw.tracing=tracing;}
};
// 影のエスコートウィング：設定は機体のものを写し、編隊・展開・命中の状態だけ影のものを使って f を呼ぶ
template<class F> void with_twin_escort(RunRuntime &r,F f) {
    auto &l=*r.state.loadout;if (!l.escort.ready) return;
    auto twin=l.escort;const auto &kept=l.twin_escort;twin.active=kept.active;twin.dash_id=kept.dash_id;twin.distance=kept.distance;twin.drones=kept.drones;twin.normals=kept.normals;twin.hits=kept.hits;
    std::swap(l.escort,twin);{AsTwin scope(r);f();}l.twin_escort=std::move(l.escort);l.escort=std::move(twin);
}
// 影の迎撃ドローン：設定は機体のものを写し、ドローン・時計・狙い直しの待ちだけ影のものを使って f を呼ぶ
template<class F> void with_twin_interceptor(RunRuntime &r,F f) {
    auto &l=*r.state.loadout;if (!l.interceptor.ready) return;
    auto twin=l.interceptor;const auto &kept=l.twin_interceptor;twin.clock=kept.clock;twin.drones=kept.drones;twin.target_after=kept.target_after;
    std::swap(l.interceptor,twin);{AsTwin scope(r);f();}l.twin_interceptor=std::move(l.interceptor);l.interceptor=std::move(twin);
}
// 影のミラージュ：残像の一覧は機体と共通で、影が走らせている残像の番号だけ入れ替えて f を呼ぶ
template<class F> void with_twin_echo(RunRuntime &r,F f) {
    auto &w=r.state.loadout->afterimage;auto &t=r.state.heroes.twin;if (!w.ready) return;
    const auto current=w.current;w.current=t.afterimage_echo;{AsTwin scope(r);f();}t.afterimage_echo=w.current;w.current=current;
}
bool owns(const RunRuntime &r,const char *id) {
    for (const auto &owned:r.state.loadout->weapons) if (r.content->equipment[owned.definition-1].external_id==id) return true;return false;
}
}
// 影が持つ、機体の突進に付いていく武器を毎フレーム進める（ソニックブームの発射、エスコートウィングの待機と追従）。
// 影がいなくなったら、影のエスコートウィングを消し、影が牽いていた敵は機体へ渡す
void GeminiBehavior::weapons(RunRuntime &r,double dt) {
    auto &s=r.state;auto &t=s.heroes.twin;auto &l=*s.loadout;godot::Vector2 pos,heading,velocity;
    if (!motion(r,pos,heading,velocity)) {
        l.twin_escort={};l.twin_interceptor={};
        for (auto &c:l.mass_tow.cargo) if (c.twin) {c.twin=false;c.relative=c.pos-s.ship.pos;}
        return;
    }
    if (owns(r,"W08") && l.sonic.ready) {
        auto &w=l.sonic;std::swap(w.last,t.sonic_last);std::swap(w.emission,t.sonic_emission);std::swap(w.distance,t.sonic_distance);std::swap(w.pulse,t.sonic_pulse);std::swap(w.speed,t.sonic_speed);std::swap(w.active,t.sonic_active);std::swap(w.hits,t.sonic_hits);
        SonicBehavior::emit(r,dt,pos,heading,velocity.length(),t.tracing,true);
        std::swap(w.last,t.sonic_last);std::swap(w.emission,t.sonic_emission);std::swap(w.distance,t.sonic_distance);std::swap(w.pulse,t.sonic_pulse);std::swap(w.speed,t.sonic_speed);std::swap(w.active,t.sonic_active);std::swap(w.hits,t.sonic_hits);
    }
    // 影のドローンは、分裂し終えて影の粒が集まりはじめてから現れる
    if (elapsed(r)<SPLIT_TIME) {l.twin_escort={};l.twin_interceptor={};return;}
    if (s.phase==godot::RunState::Phase::Play && owns(r,"W26")) with_twin_escort(r,[&]{DashRangeDroneBehavior::step(r,dt);});
    // 影の迎撃ドローンは、影のまわりを回って影の近くの敵を自分で狙う。組み立ての間（equipment_appear<1）は撃たない
    if (s.phase==godot::RunState::Phase::Play && owns(r,"W25")) with_twin_interceptor(r,[&]{const bool drawing=s.draw.drawing;if (equipment_appear(r)<1) s.draw.drawing=true;InterceptorBehavior::step(r,dt);s.draw.drawing=drawing;});
}
void GeminiBehavior::end(RunRuntime &r) {auto &t=r.state.heroes.twin;t.tracing=false;t.path.clear();t.inside.clear();t.segment=0;t.segment_position=t.rate=0;}
namespace {
void sweep(RunRuntime &r,godot::Vector2 from,godot::Vector2 to) {
    auto &s=r.state;auto &t=s.heroes.twin;
    // 影の経路にも、機体の突進に付いていく武器（ミラージュの残像、エスコートウィング）を走らせる
    if (owns(r,"W27")) with_twin_echo(r,[&]{if (!s.loadout->afterimage.current) AfterimageBehavior::launch(r);AfterimageBehavior::trail(r,from,to);});
    if (s.phase!=godot::RunState::Phase::Play) return;
    if (owns(r,"W26") && elapsed(r)>=SPLIT_TIME) with_twin_escort(r,[&]{DashRangeDroneBehavior::trail(r,from,to);});
    if (s.phase!=godot::RunState::Phase::Play) return;const double radius=s.trace_radius,padding=radius+std::max(s.combat_config.max_enemy_radius,s.grid.max_radius),power=CombatResolver::attack_power(r)*(definition(r)?definition(r)->power:1.0);const godot::Vector2 pad(padding,padding),direction=(to-from).normalized();
    for (auto row:CollisionQuery::enemy_rows(s,from.min(to)-pad,from.max(to)+pad)) {
        const auto &e=s.enemies[row];if (e.dead || s.field.rock_handles.contains(e.rock)) continue;const auto target=CombatResolver::damage_target(r,s.enemy_handles.at(row));if (!s.enemy_handles.contains(target)) continue;
        const auto id=s.enemy_handles.entity_id(target);if (t.inside.count(id) || CollisionQuery::segment_circle_t(from,to,e.pos,e.radius+radius)<0) continue;t.inside.insert(id);
        DamageRequest request;request.struck=s.enemy_handles.at(row);request.amount=power;request.cause=Cause::Ram;request.direction=direction;request.impact=to;request.has_impact=true;
        if (e.stone>0) CombatResolver::kill_enemy(r,request);
        // 影は装甲に弾かれずに貫く
        else if (CombatResolver::gate(r,request.struck,request)==GateResult::Allow) {request.impact=e.pos;CombatResolver::damage_enemy(r,request);
            // 影の体当たりにも、機体の体当たりと同じく接触で働く武器（接触波・閃光斬・電撃）が反応する
            if (s.phase==godot::RunState::Phase::Play && s.enemy_handles.contains(request.struck)) EquipmentSystem::contact(r,request.struck,request.impact);}
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
}
}
namespace {
// 影が走り終えたところで、機体の突進の終わりと同じ武器（終点の爆発・機雷・双極ビーム）を影の位置から使う。
// それぞれの武器は機体の位置・向き・経路を読むので、その間だけ影のものへ差し替えて戻す
void finish(RunRuntime &r) {
    auto &s=r.state;auto &t=s.heroes.twin;if (t.path.size()<2) return;
    const auto ship_pos=s.ship.pos,heading=s.ship.heading;const auto path=s.draw.path;const auto segment=s.draw.segment;
    s.ship.pos=t.position;s.ship.heading=(t.path.back()-t.path[t.path.size()-2]).normalized();
    godot::PackedVector2Array twin_path;for (auto p:t.path) twin_path.push_back(p);s.draw.path=twin_path;s.draw.segment=int64_t(t.path.size())-2;
    for (const auto &owned:s.loadout->weapons) {
        if (s.phase!=godot::RunState::Phase::Play) break;
        const auto &id=r.content->equipment[owned.definition-1].external_id;
        if (id=="W29") EndBlastBehavior::end(r);
        else if (id=="W07") MinesBehavior::end(r);
        else if (id=="W22") {auto &w=s.loadout->bipolar;const auto origin=w.origin;const bool active=w.active;w.origin=t.path.front();w.active=true;BipolarBehavior::end(r);w.origin=origin;w.active=active;}
    }
    s.ship.pos=ship_pos;s.ship.heading=heading;s.draw.path=path;s.draw.segment=segment;
    if (owns(r,"W27")) with_twin_echo(r,[&]{AfterimageBehavior::end(r);});
    if (owns(r,"W26")) with_twin_escort(r,[&]{DashRangeDroneBehavior::end(r);});
    for (auto &c:s.loadout->mass_tow.cargo) if (c.twin) c.ready=true;
}
}
void GeminiBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &t=s.heroes.twin;if (!t.tracing || s.phase!=godot::RunState::Phase::Play) return;double distance=t.rate*dt;
    while (distance>1e-9 && t.segment<t.path.size()-1) {
        const auto a=t.path[t.segment],b=t.path[t.segment+1];const double length=a.distance_to(b),move=std::min(distance,length-t.segment_position);const auto from=t.position;
        t.segment_position+=move;distance-=move;t.position=a+(b-a)/std::max(length,1e-6)*t.segment_position;sweep(r,from,t.position);
        if (s.phase!=godot::RunState::Phase::Play) return;
        if (t.segment_position>=length-1e-9) {++t.segment;t.segment_position=0;}
    }
    if (t.segment>=t.path.size()-1) {finish(r);if (s.phase!=godot::RunState::Phase::Play) return;end(r);}
}
}
