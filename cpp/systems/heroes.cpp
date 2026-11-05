#include "../behaviors/heroes/hercules.h"
#include "../behaviors/heroes/leo.h"
#include "../behaviors/heroes/perseus.h"
#include "heroes.h"
#include "enemy_system.h"
#include "field.h"
#include "population_system.h"
#include "collision_query.h"
#include "../output/frame_builder.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
using godot::Vector2;using godot::Dictionary;using godot::String;using godot::StringName;
namespace {
constexpr double TAU=6.28318530717958647692;
Vector2 direction(double a) {return Vector2(std::cos(a),std::sin(a));}
StringName name(const RunRuntime &run,uint32_t id) {return id?StringName(String::utf8(run.content->heroes[id-1].definition.external_id.c_str())):StringName();}
void emit(RunRuntime &run,const char *type,Dictionary data={}) {FrameBuilder::append(run,type,data);}
bool valid_carrier(const RunRuntime &run,size_t slot) {const auto &h=run.state.heroes;return run.state.enemy_handles.contains(h.carriers[slot]) && run.state.enemy_handles.entity_id(h.carriers[slot])==h.carrier_ids[slot];}
void clear_carriers(RunRuntime &run) {
    auto &h=run.state.heroes;
    for (size_t i=0;i<2;++i) {if (valid_carrier(run,i)) run.state.enemies[h.carriers[i].slot].landmark=false;h.carriers[i]={};h.carrier_ids[i]=0;}
}
uint32_t random_hero(RunRuntime &run,uint32_t except=0) {
    std::vector<uint32_t> choices;for (const auto &hero:run.content->heroes) if (hero.definition.id!=except) choices.push_back(hero.definition.id);
    return choices.empty()?0:choices[*run.state.control.rng.randi_range(0,choices.size()-1)];
}
bool eligible(const EnemyDefinition &d) {return d.rank>=2 && d.rank<=5;}
bool spaced(const RunRuntime &run,Vector2 pos) {
    const auto &h=run.state.heroes;const double distance=run.content->hero_config.spacing;
    if (pos.distance_to(h.center)<distance) return false;
    for (auto previous:h.landmarks) if (pos.distance_to(previous)<distance) return false;
    for (size_t i=0;i<2;++i) if (valid_carrier(run,i)) {const auto &e=run.state.enemies[h.carriers[i].slot];if (!e.dead && pos.distance_to(e.pos)<distance) return false;}
    return true;
}
int64_t pick_carrier(RunRuntime &run) {
    std::vector<size_t> nearby,picks;auto &s=run.state;const double reach=s.view_half.length()*1.3;
    for (size_t i=0;i<s.enemies.size();++i) {const auto &e=s.enemies[i];if (!e.alive || e.dead || e.landmark || e.is_boss || e.parent.generation || !eligible(run.content->definitions[e.definition]) || e.pos.distance_squared_to(s.ship.pos)>reach*reach) continue;nearby.push_back(i);if (spaced(run,e.pos)) picks.push_back(i);}
    if (picks.empty()) picks=std::move(nearby);
    return picks.empty()?-1:int64_t(picks[*s.control.rng.randi_range(0,picks.size()-1)]);
}
int64_t spawn_carrier(RunRuntime &run) {
    auto &s=run.state;std::vector<StringName> types;
    const auto append=[&](StringName type) {if (std::find(types.begin(),types.end(),type)==types.end()) types.push_back(type);};
    for (const auto &clip:s.clips) {
        if (clip.start>s.time || clip.end<=clip.start || clip.maximum<=0) continue;
        for (auto fi:clip.formations) {const auto &f=s.formations[fi];if (std::none_of(f.entries.begin(),f.entries.end(),[](const auto &e){return e.weight>0;})) continue;
            for (const auto &layout:f.layouts) if (layout.weight>0) for (const auto &placement:layout.placements) for (const auto &marker:placement) if (clip.types.is_empty() || clip.types.has(String(marker.type))) append(marker.type);
        }
    }
    const auto &timeline=s.spawn_timeline;
    if (!timeline.phases.empty()) {
        if (!timeline.curves.empty()) {for (const auto &curve:timeline.curves) if (PopulationSystem::sample_curve(curve,s.time)>0) append(curve.type);}
        else {size_t phase=0;for (size_t i=1;i<timeline.phases.size();++i) {if (timeline.phases[i].start>s.time) break;phase=i;}for (const auto &[type,weight]:timeline.phases[phase].mix) if (weight>0) append(type);}
    }
    std::vector<size_t> definitions;
    for (auto type:types) {const auto &defs=run.content->definitions;for (size_t i=0;i<defs.size();++i) if (defs[i].id==type && eligible(defs[i])) {definitions.push_back(i);break;}}
    if (definitions.empty()) return -1;
    const auto definition=definitions[*s.control.rng.randi_range(0,definitions.size()-1)];const auto &d=run.content->definitions[definition];
    const double margin=d.radius+s.ship_config.ship_radius+160,distance=std::max(margin,double(std::min(s.view_half.x,s.view_half.y))*0.85),angle=s.control.rng.randf()*TAU;
    auto pos=FieldSystem::push_out(run,s.ship.pos+direction(angle)*distance,d.radius+16);
    for (int i=0;i<24;++i) {auto candidate=FieldSystem::push_out(run,s.ship.pos+direction(angle+TAU*i/24.0)*distance,d.radius+16);if (candidate.length()+d.radius<s.ship_config.field_radius && FieldSystem::body_gap(run,candidate,d.radius)>=0) {pos=candidate;break;}}
    EnemySpawn spawn;spawn.position=pos;spawn.has_facing=true;spawn.facing=(s.ship.pos-pos).angle();spawn.origin=SpawnOrigin::HeroLandmark;
    const int64_t id=EnemySystem::spawn(run,definition,spawn);const auto found=s.rows_by_id.find(id);return found==s.rows_by_id.end()?-1:int64_t(found->second);
}
void guards(RunRuntime &run) {
    auto &s=run.state;auto &h=s.heroes;h.guarded=true;std::vector<size_t> defs;
    for (const auto &phase:s.spawn_timeline.phases) for (const auto &mix:phase.mix) {
        const auto &type=mix.first;
        for (size_t i=0;i<run.content->definitions.size();++i) {
            const auto &d=run.content->definitions[i];
            if (d.id==type && std::any_of(s.spawn_timeline.types.begin(),s.spawn_timeline.types.end(),[&](const auto &t){return t.id==type && t.maximum>0;}) && d.scaling.radius<50 && std::find(defs.begin(),defs.end(),i)==defs.end()) defs.push_back(i);
        }
    }
    if (defs.empty()) return;
    for (uint32_t i=0;i<run.content->hero_config.guards;++i) {const auto def=defs[*s.control.rng.randi_range(0,defs.size()-1)];EnemySpawn spawn;spawn.position=h.center+direction(TAU*i/run.content->hero_config.guards)*420;spawn.facing=(s.ship.pos-spawn.position).angle();spawn.has_facing=true;spawn.origin=SpawnOrigin::Summon;EnemySystem::spawn(run,def,spawn);}
}
void free_hero(RunRuntime &run) {
    auto &h=run.state.heroes;clear_carriers(run);h.power=h.hero;h.cooldown=h.active=0;Dictionary data;data["id"]=name(run,h.hero);data["pos"]=h.center;emit(run,"hero_freed",data);if (run.state.lifecycle.endless) h.next=run.content->hero_config.next_time;
}
}
void HeroesSystem::initialize(RunRuntime &run) {
    run.state.heroes={};run.state.heroes.previous=run.state.ship.pos;
    if (run.state.lifecycle.endless) {place(run,random_hero(run));return;}
    for (const auto &hero:run.content->heroes) if (hero.definition.stage==uint32_t(String(run.state.control.stage_id).to_int())) place(run,hero.definition.id);
}
void HeroesSystem::place(RunRuntime &run,uint32_t id) {
    auto &s=run.state;auto &h=s.heroes;clear_carriers(run);h.hero=id;if (!id) return;
    const auto &cfg=run.content->hero_config;auto &rng=s.control.rng;const double distance=std::max(2500.0,cfg.glow_range),radius=s.ship_config.field_radius;
    h.center=direction(s.ship.pos.angle()+TAU/2)*(radius-600);
    for (int i=0;i<16;++i) {const double angle=rng.randf()*TAU,length=rng.randf_range(radius*0.72,radius-600);auto candidate=direction(angle)*length;if (candidate.distance_to(s.ship.pos)<=distance) continue;h.center=candidate;if (FieldSystem::body_gap(run,h.center,0)>600) break;}
    const double rotation=rng.randf()*TAU;h.stars.clear();for (auto star:run.content->heroes[id-1].stars) h.stars.push_back(h.center+star.rotated(rotation)*cfg.scale);
    h.lit.assign(run.content->heroes[id-1].links.size(),0);h.guarded=h.seen=h.announced=false;h.last_star=-1;h.landmarks.clear();h.done.fill(false);
    const double origin=s.lifecycle.endless?s.time:0;
    const std::pair<double,double> windows[]={{cfg.first_min,cfg.first_max},{cfg.second_min,cfg.second_max}};
    for (size_t i=0;i<2;++i) {const auto first=int64_t(std::ceil(windows[i].first)),last=std::max(first,int64_t(std::ceil(windows[i].second))-1);h.landmark_times[i]=origin+*rng.randi_range(first,last);}
}
double HeroesSystem::trace_width(const RunRuntime &run) {return LeoBehavior::trace_width(run);}
bool HeroesSystem::captive(const RunRuntime &run) {const auto &h=run.state.heroes;return h.hero && std::find(h.lit.begin(),h.lit.end(),0)!=h.lit.end();}
void HeroesSystem::step(RunRuntime &run,double real_dt,double world_dt) {
    auto &s=run.state;auto &h=s.heroes;const auto &cfg=run.content->hero_config;
    h.cooldown=std::max(0.0,h.cooldown-real_dt);
    if (h.active>0) {h.active=std::max(0.0,h.active-real_dt);if (h.active<=0) {Dictionary data;data["id"]=name(run,h.power);emit(run,"hero_power_end",data);}}
    if (h.next>=0) {h.next-=real_dt;if (h.next<0) place(run,random_hero(run,h.power));}
    HerculesBehavior::step(run,real_dt);
    const auto from=h.previous;h.previous=s.ship.pos;if (!captive(run)) return;
    if (!h.guarded && s.ship.pos.distance_squared_to(h.center)<cfg.guard_range*cfg.guard_range) guards(run);
    if (s.ship.pos.distance_squared_to(h.center)<cfg.glow_range*cfg.glow_range) h.seen=true;
    if (!s.control.lab_mode && s.control.bonus_remaining<=0 && h.landmarks.size()<2) for (size_t i=0;i<2;++i) {
        if (h.done[i] || s.time<h.landmark_times[i] || (valid_carrier(run,i) && !s.enemies[h.carriers[i].slot].dead)) continue;
        auto row=pick_carrier(run);if (row<0) row=spawn_carrier(run);if (row<0) continue;
        s.enemies[row].landmark=true;h.carriers[i]=s.enemy_handles.at(row);h.carrier_ids[i]=s.enemies[row].id;
    }
    if (!h.announced && (h.seen || h.landmarks.size()>=2)) {h.announced=true;Dictionary data;data["id"]=name(run,h.hero);emit(run,"hero_discovered",data);}
    if (s.draw.tracing) pass_stars(run,from,s.ship.pos,s.draw.dash_id);
}
void HeroesSystem::pass_stars(RunRuntime &run,Vector2 from,Vector2 to,int64_t dash) {
    auto &h=run.state.heroes;if (!captive(run)) return;if (dash!=h.last_dash) {h.last_dash=dash;h.last_star=-1;}
    std::vector<std::pair<double,size_t>> hits;const double reach=run.content->hero_config.star_radius+run.state.ship_config.ship_radius;
    for (size_t i=0;i<h.stars.size();++i) {const double t=CollisionQuery::segment_circle_t(from,to,h.stars[i],reach);if (t>=0) hits.emplace_back(t,i);}
    std::stable_sort(hits.begin(),hits.end(),[](const auto &a,const auto &b){return a.first<b.first;});
    const auto &links=run.content->heroes[h.hero-1].links;
    for (const auto &[t,k]:hits) {if (int64_t(k)==h.last_star) continue;if (h.last_star>=0) for (size_t i=0;i<links.size();++i) {const auto [a,b]=links[i];if (!h.lit[i] && ((a==h.last_star && b==k)||(b==h.last_star && a==k))) {h.lit[i]=1;Dictionary data;data["from"]=h.stars[h.last_star];data["to"]=h.stars[k];emit(run,"hero_link",data);if (!captive(run)) free_hero(run);break;}}h.last_star=k;}
}
void HeroesSystem::recovered(RunRuntime &run,EnemyHandle enemy) {
    auto &h=run.state.heroes;
    if (!run.state.enemies[enemy.slot].landmark) return;
    h.landmarks.push_back(run.state.enemies[enemy.slot].pos);Dictionary data;data["pos"]=run.state.enemies[enemy.slot].pos;emit(run,"landmark",data);
    for (size_t i=0;i<2;++i) if (same_handle(h.carriers[i],enemy) && valid_carrier(run,i)) h.done[i]=true;
}
void HeroesSystem::select_power(RunRuntime &run,uint32_t id) {run.state.heroes.power=id;run.state.heroes.active=0;}
void HeroesSystem::activate(RunRuntime &run) {
    auto &h=run.state.heroes;if (!h.power || h.cooldown>0) return;const auto &d=run.content->heroes[h.power-1].definition;h.cooldown=d.cooldown;h.active=d.duration;Dictionary data;data["id"]=name(run,h.power);data["pos"]=run.state.ship.pos;emit(run,"hero_power",data);
    if (d.external_id=="perseus") PerseusBehavior::activate(run,d.duration);
}
Dictionary HeroesSystem::snapshot(const RunRuntime &run) {
    const auto &h=run.state.heroes;Dictionary out;out["trace_width"]=trace_width(run);out["trace_radius"]=run.state.trace_radius*trace_width(run);out["boss_stun"]=h.boss_stun;out["id"]=name(run,h.hero);out["power"]=name(run,h.power);out["field_radius"]=run.state.ship_config.field_radius;out["center"]=h.center;out["previous"]=h.previous;out["cooldown"]=h.cooldown;out["active"]=h.active;out["next"]=h.next;out["seen"]=h.seen;out["announced"]=h.announced;out["guarded"]=h.guarded;out["captive"]=captive(run);out["revealed"]=h.hero && (h.seen || h.landmarks.size()>=2 || !captive(run));out["guidance"]=run.state.lifecycle.endless || !run.state.world.boss_spawned;
    Dictionary fire;godot::PackedFloat64Array falls,burns;for (const auto &v:h.hercules.falls) {falls.push_back(v.position.x);falls.push_back(v.position.y);falls.push_back(v.remaining);}for (const auto &v:h.hercules.burns) {burns.push_back(v.position.x);burns.push_back(v.position.y);burns.push_back(v.remaining);}fire["falls"]=falls;fire["burns"]=burns;fire["fire_time"]=h.hercules.fire_time;fire["burn_tick"]=h.hercules.burn_tick;out["hercules"]=fire;
    Dictionary twin;godot::PackedVector2Array first,path;for (auto p:h.twin.first) first.push_back(p);for (auto p:h.twin.path) path.push_back(p);
    twin["first"]=first;twin["path"]=path;twin["position"]=h.twin.position;twin["tracing"]=h.twin.tracing;twin["rate"]=h.twin.rate;twin["segment"]=int64_t(h.twin.segment);twin["segment_position"]=h.twin.segment_position;out["twin"]=twin;
    godot::PackedVector2Array stars,landmarks;godot::PackedByteArray lit,done;godot::PackedInt32Array links;godot::PackedInt64Array ids;godot::PackedFloat64Array times;
    for (auto p:h.stars) stars.push_back(p);for (auto p:h.landmarks) landmarks.push_back(p);for (auto v:h.lit) lit.push_back(v);
    if (h.hero) for (auto [a,b]:run.content->heroes[h.hero-1].links) {links.push_back(a);links.push_back(b);}
    for (size_t i=0;i<2;++i) {ids.push_back(h.carrier_ids[i]);times.push_back(h.landmark_times[i]);done.push_back(h.done[i]);}
    out["stars"]=stars;out["links"]=links;out["lit"]=lit;out["landmarks"]=landmarks;out["carriers"]=ids;out["times"]=times;out["done"]=done;return out;
}
bool HeroesSystem::validate(const godot::RunState &s,const ContentBundle &c) {
    const auto &h=s.heroes;if (h.hero>c.heroes.size() || h.power>c.heroes.size() || !h.center.is_finite() || !h.previous.is_finite() || !std::isfinite(h.cooldown) || !std::isfinite(h.active) || !std::isfinite(h.next) || !std::isfinite(h.boss_stun) || h.boss_stun<0 || h.cooldown<0 || h.active<0 || h.landmarks.size()>2) return false;
    if (h.hero && (h.stars.size()!=c.heroes[h.hero-1].stars.size() || h.lit.size()!=c.heroes[h.hero-1].links.size())) return false;
    if (!std::isfinite(h.hercules.fire_time) || !std::isfinite(h.hercules.burn_tick)) return false;
    for (const auto *items:{&h.hercules.falls,&h.hercules.burns}) for (const auto &v:*items) if (!v.position.is_finite() || !std::isfinite(v.remaining) || v.remaining<0) return false;
    const auto &t=h.twin;if (!t.position.is_finite() || !std::isfinite(t.rate) || t.rate<0 || !std::isfinite(t.segment_position) || t.segment_position<0 || (t.tracing && (t.path.size()<2 || t.segment>=t.path.size()-1))) return false;
    for (auto p:t.first) if (!p.is_finite()) return false;for (auto p:t.path) if (!p.is_finite()) return false;for (auto id:t.inside) if (id<=0) return false;
    for (auto p:h.stars) if (!p.is_finite()) return false;for (auto p:h.landmarks) if (!p.is_finite()) return false;for (auto v:h.lit) if (v>1) return false;
    for (size_t i=0;i<2;++i) if (!std::isfinite(h.landmark_times[i]) || h.carrier_ids[i]<0 || (s.enemy_handles.contains(h.carriers[i]) && s.enemy_handles.entity_id(h.carriers[i])!=h.carrier_ids[i])) return false;return true;
}
}
