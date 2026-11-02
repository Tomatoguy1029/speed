#include "run_core.h"
#include "../systems/equipment.h"
#include "../systems/progression.h"
#include "../systems/enemy_system.h"
#include "../systems/field.h"
#include "../systems/attack_budget.h"
#include "../systems/combat_resolver.h"
#include <cmath>
#include <algorithm>
using namespace godot;
namespace {
Dictionary reply(bool ok,Variant value=Variant()) {Dictionary r;r["ok"]=ok;r["code"]=ok?0:1;r["field"]=ok?"":"scenario";r["message"]=ok?String():String::utf8("実験の命令の種類・入力・対象を確認してください");r["value"]=value;return r;}
bool keys(const Dictionary &d,std::initializer_list<const char *> names) {for (auto key:d.keys()) {bool found=false;for (auto name:names) if (String(key)==name) found=true;if (!found) return false;}return true;}
bool scalar(const Dictionary &d,const char *key,double fallback,double &value) {const Variant v=d.get(key,fallback);if (v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) return false;value=v;return std::isfinite(value);}
bool point(const Dictionary &d,const char *key,Vector2 &out) {const Variant v=d.get(key,Variant());if (v.get_type()!=Variant::VECTOR2) return false;out=v;return out.is_finite();}
}
Dictionary SpeedRunCore::development_lab_command(const String &command,const Dictionary &envelope) {
    if (!runtime.api_development || envelope.size()!=2 || envelope.get("kind",Variant()).get_type()!=Variant::STRING) return reply(false);
    const String kind=envelope["kind"];const char *body=command=="dev_set_scenario"?"params":"payload";
    if (envelope.get(body,Variant()).get_type()!=Variant::DICTIONARY) return reply(false);
    const Dictionary p=envelope[body];auto &s=runtime.state;auto &c=s.control;
    if (command=="dev_set_scenario" && (kind=="lab" || kind=="intro")) {
        if (!keys(p,{"lab_mode","auto_spawn","auto_boss","invincible","position","gauge","time","level","empty"})) return reply(false);
        for (const char *key:{"lab_mode","auto_spawn","auto_boss","invincible","empty"}) if (p.has(key) && p[key].get_type()!=Variant::BOOL) return reply(false);
        Vector2 at=s.ship.pos;if (p.has("position") && !point(p,"position",at)) return reply(false);
        double gauge,time,level;if (!scalar(p,"gauge",s.draw.gauge,gauge) || gauge<0 || !scalar(p,"time",s.time,time) || time<0 || !scalar(p,"level",s.loadout.level,level) || level<1 || level>1000) return reply(false);
        c.lab_mode=p.get("lab_mode",true);s.population.frame_enabled=p.get("auto_spawn",false);s.world.boss_spawned=!bool(p.get("auto_boss",false));s.invincible=p.get("invincible",true);
        s.ship.pos=s.ship_pos=at;s.ship.vel=Vector2();s.view_center=s.enemy_aim=at;c.camera_center=at;c.camera_ready=false;s.draw.gauge=gauge;s.time=time;s.loadout.level=int64_t(level);speed::EquipmentSystem::refresh_effects(runtime);
        if (bool(p.get("empty",false))) {s.field.bodies.clear();s.field.rocks.clear();s.field.wells.clear();s.field.warp_gone=-1;}
        return reply(true);
    }
    if (command!="dev_edit") return reply(false);
    if (kind=="camera") {
        Vector2 center,size;double zoom,bars;
        if (p.size()!=4 || !point(p,"center",center) || !point(p,"size",size) || size.x<=0 || size.y<=0 || !scalar(p,"zoom",1,zoom) || zoom<=0 || !scalar(p,"bars",0,bars) || bars<0 || bars>1) return reply(false);
        c.camera_center=s.view_center=center;c.camera_zoom=zoom;c.logical_size=size;s.view_half=size/(2.0*zoom);c.camera_ready=true;c.cinematic_bars=bars;return reply(true);
    }
    if (kind=="finish_input" && p.is_empty()) {
        s.hitstop=0;c.world_scale=1;s.draw.drawing=s.draw.tracing=false;s.ship.vel=Vector2();c.world_real_accum=c.world_dt_accum=0;c.world_steps=0;return reply(true);
    }
    if (kind=="enemy_motion") {
        if (p.size()!=2 || p.get("entity_id",Variant()).get_type()!=Variant::INT) return reply(false);
        double speed;if (!scalar(p,"speed",0,speed) || speed<0) return reply(false);
        const auto row=s.rows_by_id.find(int64_t(p["entity_id"]));if (row==s.rows_by_id.end()) return reply(false);s.enemies[row->second].speed=speed;return reply(true);
    }
    if (kind=="planet") {
        Vector2 at;double radius;if (p.size()!=2 || !point(p,"position",at) || !scalar(p,"radius",0,radius) || radius<10 || runtime.content->field_bodies.empty()) return reply(false);
        speed::FieldBody body;body.position=at;body.radius=radius;s.field.bodies.push_back(body);
        for (auto &e:s.enemies) e.body_gap=-1;for (auto &shot:s.hostiles) shot.gap=0;return reply(true);
    }
    if (kind=="director") {
        if (!keys(p,{"enabled","budget","jitter"}) || (p.has("enabled") && p["enabled"].get_type()!=Variant::BOOL)) return reply(false);
        double budget,jitter;if (!scalar(p,"budget",s.world.attack_budget.budget,budget) || !scalar(p,"jitter",s.world.attack_budget.jitter,jitter)) return reply(false);
        return reply(speed::AttackBudgetSystem::configure(s,{bool(p.get("enabled",false)),budget,jitter}));
    }
    if (kind=="guard") {
        double until;if (p.size()!=1 || !scalar(p,"until",0,until)) return reply(false);
        return reply(speed::AttackBudgetSystem::set_guard(s,true,until));
    }
    if (kind=="individual") {
        if (!keys(p,{"entity_id","elite","size"}) || p.get("entity_id",Variant()).get_type()!=Variant::INT || (p.has("elite") && p["elite"].get_type()!=Variant::BOOL)) return reply(false);
        const auto found=s.rows_by_id.find(int64_t(p["entity_id"]));if (found==s.rows_by_id.end()) return reply(false);
        auto next=s.enemies[found->second];const auto &d=runtime.content->definitions[next.definition];const auto &scale=d.scaling;
        double size;if (!scale.ready || !scalar(p,"size",scale.radius,size) || size<0.1) return reply(false);
        const bool elite=p.get("elite",next.elite);const double z=size/scale.radius,ratio=next.hp/std::max(0.001,next.max_hp);
        next.radius=(scale.fixed_sprite?scale.radius:size*(elite?1.25:1.0))*scale.character*scale.visual*scale.collision;
        next.max_hp=scale.hp*z*z*scale.hp_mult*(elite?3.0:1.0);next.hp=next.max_hp*ratio;next.armor=scale.armor*z*scale.armor_mult*(elite?1.3:1.0);next.xp=d.xp*z*(elite?4.0:1.0);next.elite=elite;
        for (double value:{next.radius,next.hp,next.max_hp,next.armor,next.xp}) if (!std::isfinite(value)) return reply(false);
        s.enemies[found->second]=next;return reply(true);
    }
    if (kind=="draw") {
        if (!keys(p,{"action","position"}) || p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
        const String action=p["action"];Vector2 at;
        if (action=="commit" && p.size()==1) {commit_draw();return reply(true);}
        if (p.size()!=2 || !point(p,"position",at)) return reply(false);
        if (action=="start") {begin_draw(true,at,int64_t(std::llround(s.sim_time*1000)));return reply(s.draw.drawing);}
        if (action=="extend" && s.draw.drawing) {extend_draw(at,c.camera_zoom);return reply(true);}
        return reply(false);
    }
    if (kind=="invincible" && p.size()==1 && p.get("value",Variant()).get_type()==Variant::BOOL) {s.invincible=p["value"];return reply(true);}
    if (kind=="pin") {
        Vector2 at;if (p.size()!=2 || p.get("value",Variant()).get_type()!=Variant::BOOL || !point(p,"position",at)) return reply(false);
        c.lab_pinned=p["value"];c.lab_pin=at;if (c.lab_pinned) {s.ship.pos=s.ship_pos=at;s.ship.vel=Vector2();}return reply(true);
    }
    if (kind=="ship") {
        Vector2 at;double gauge;if (!keys(p,{"position","velocity","gauge"}) || !point(p,"position",at) || !scalar(p,"gauge",s.draw.gauge,gauge) || gauge<0) return reply(false);
        Vector2 velocity;if (p.has("velocity") && !point(p,"velocity",velocity)) return reply(false);
        s.ship.pos=s.ship_pos=at;s.ship.vel=velocity;s.draw.gauge=gauge;return reply(true);
    }
    if (kind=="time" || kind=="level") {
        double value;if (p.size()!=1 || !scalar(p,"value",0,value) || value<(kind=="level"?1:0) || (kind=="level" && value>1000)) return reply(false);
        if (kind=="time") s.time=value;else {s.loadout.level=int64_t(value);speed::EquipmentSystem::refresh_effects(runtime);}return reply(true);
    }
    if (kind=="move") {
        Vector2 at;double angle;
        if (!keys(p,{"entity_id","position","angle"}) || p.get("entity_id",Variant()).get_type()!=Variant::INT || !point(p,"position",at)) return reply(false);
        const auto row=s.rows_by_id.find(int64_t(p["entity_id"]));if (row==s.rows_by_id.end() || !scalar(p,"angle",s.enemies[row->second].facing,angle)) return reply(false);
        const auto handle=s.enemy_handles.at(row->second);if (!speed::EnemySystem::relocate(runtime,handle,at)) return reply(false);s.enemies[row->second].facing=angle;return reply(true);
    }
    if (kind=="schedule") {
        if (p.size()!=1 || p.get("entries",Variant()).get_type()!=Variant::ARRAY) return reply(false);
        std::vector<speed::RunControlState::LabSchedule> entries;
        const Array source=p["entries"];if (source.size()>4096) return reply(false);
        for (const Variant value:source) {
            if (value.get_type()!=Variant::DICTIONARY) return reply(false);const Dictionary row=value;
            if (!keys(row,{"type","position","start","end","interval","count","probability","radius","spacing","angle","enabled","elite"}) || row.get("type",Variant()).get_type()!=Variant::STRING) return reply(false);
            speed::RunControlState::LabSchedule e;bool found=false;
            for (uint32_t n=0;n<runtime.content->definitions.size();++n) if (runtime.content->definitions[n].id==StringName(row["type"])) {e.definition=n;found=true;break;}
            if (!found || !point(row,"position",e.position)) return reply(false);
            double start,end,interval,count;if (!scalar(row,"start",0,start) || !scalar(row,"end",600,end) || !scalar(row,"interval",1,interval) || !scalar(row,"count",1,count) || start<0 || end<start || interval<=0 || count<1 || count>10000 || end>1e9) return reply(false);
            if (!scalar(row,"probability",1,e.probability) || !scalar(row,"radius",0,e.radius) || !scalar(row,"spacing",60,e.spacing) || !scalar(row,"angle",0,e.facing) || e.probability<0 || e.probability>1 || e.radius<0 || e.spacing<0) return reply(false);
            for (const char *key:{"enabled","elite"}) if (row.has(key) && row[key].get_type()!=Variant::BOOL) return reply(false);
            e.start=std::llround(start*120);e.end=std::llround(end*120);e.interval=std::max<int64_t>(1,std::llround(interval*120));e.count=int64_t(count);e.enabled=row.get("enabled",true);e.elite=row.get("elite",false);entries.push_back(e);
        }
        c.lab_schedule=std::move(entries);return reply(true);
    }
    return reply(false);
}
Dictionary SpeedRunCore::lab_state_run() const {
    if (runtime.busy || !runtime.api_configured || !runtime.api_development || !runtime.state.started || runtime.state.closed) return reply(false);
    const auto &s=runtime.state;Dictionary value;value["ship"]=ship_snapshot();value["draw"]=draw_snapshot();value["clock"]=inspect();value["loadout"]=speed::ProgressionSystem::ui(runtime);value["invincible"]=s.invincible;value["pinned"]=s.control.lab_pinned;value["pin"]=s.control.lab_pin;value["attack_power"]=speed::CombatResolver::attack_power(runtime);Dictionary director=attack_budget_snapshot();const auto &budget=s.world.attack_budget;
    Dictionary settings;settings["enabled"]=budget.enabled;settings["budget"]=budget.budget;settings["jitter"]=budget.jitter;director["settings"]=settings;director["enabled"]=budget.enabled;director["guard_active"]=speed::AttackBudgetSystem::guard_active(s);
    Array groups=director["groups"];size_t gi=0;for (const auto &entry:budget.groups) {Dictionary row=groups[gi++];Array categories;for (auto category:entry.value.categories) categories.push_back(speed::symbol_name(category));row["categories"]=categories;row["pos"]=entry.value.pos;row["type"]=entry.value.definition?runtime.content->definitions[entry.value.definition-1].id:StringName();}value["director"]=director;
    Array enemies;
    for (const auto &e:s.enemies) if (e.alive) {
        Dictionary row;row["id"]=e.id;row["type"]=runtime.content->definitions[e.definition].id;row["pos"]=e.pos;row["vel"]=e.vel;row["hp"]=e.hp;row["max_hp"]=e.max_hp;row["armor"]=e.armor;row["speed"]=e.speed;row["r"]=e.radius;row["facing"]=e.facing;row["dead"]=e.dead;row["elite"]=e.elite;row["gate"]=int(runtime.content->definitions[e.definition].gate);row["is_boss"]=e.is_boss;row["mode"]=int(e.mode);row["charge"]=e.charge;row["parent"]=s.enemy_handles.contains(e.parent)?s.enemy_handles.entity_id(e.parent):-1;enemies.push_back(row);
    }
    value["lab_mode"]=s.control.lab_mode;value["cinematic_bars"]=s.control.cinematic_bars;value["camera_zoom"]=s.control.camera_zoom;value["view_half"]=s.view_half;value["view_center"]=s.view_center;value["capacity"]=s.draw_config.capacity;value["max_speed"]=s.ship_config.max_speed;value["length_mult"]=s.draw_config.length_mult;value["enemies"]=enemies;Array bodies;for (const auto &b:s.field.bodies) {Dictionary row;row["pos"]=b.position;row["r"]=b.radius;bodies.push_back(row);}value["bodies"]=bodies;value["hazards"]=hazards_snapshot();value["hostiles"]=hostiles_snapshot();return reply(true,value);
}
