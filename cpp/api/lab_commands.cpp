#include "run_core.h"
#include "../systems/equipment.h"
#include "../behaviors/weapons/barrier.h"
#include "../behaviors/weapons/interceptor.h"
#include "../behaviors/weapons/forward.h"
#include "../behaviors/traits/critBeam.h"
#include "../behaviors/traits/fullBurst.h"
#include "../behaviors/traits/killSonic.h"
#include "../behaviors/traits/rampage.h"
#include "../systems/heroes.h"
#include "../runtime/dev_commands.h"
#include "../runtime/dev_scenario.h"
#include "../runtime/checkpoint.h"
#include "../systems/population_system.h"
#include "../systems/progression.h"
#include "../systems/enemy_system.h"
#include "../systems/field.h"
#include "../systems/attack_budget.h"
#include "../systems/combat_resolver.h"
#include "../systems/attack_system.h"
#include "../output/frame_builder.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/hydra/body.h"
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
    if (command=="dev_set_scenario" && kind=="timeline") {
        speed::TimelineScenario timeline;
        if (s.phase!=Phase::Paused || !speed::decode_timeline_scenario(p,timeline)) return reply(false);
        speed::apply_timeline_scenario(runtime,timeline);return reply(true);
    }
    if (command=="dev_set_scenario" && (kind=="lab" || kind=="intro")) {
        if (!keys(p,{"lab_mode","auto_spawn","auto_boss","invincible","position","gauge","time","level","empty","enemy_ai","terrain","rocks"})) return reply(false);
        for (const char *key:{"lab_mode","auto_spawn","auto_boss","invincible","empty","enemy_ai","terrain","rocks"}) if (p.has(key) && p[key].get_type()!=Variant::BOOL) return reply(false);
        Vector2 at=s.ship.pos;if (p.has("position") && !point(p,"position",at)) return reply(false);
        double gauge,time,level;if (!scalar(p,"gauge",s.draw.gauge,gauge) || gauge<0 || !scalar(p,"time",s.time,time) || time<0 || !scalar(p,"level",s.loadout.level,level) || level<1 || level>1000) return reply(false);
        c.lab_mode=p.get("lab_mode",true);c.lab_enemy_ai=p.get("enemy_ai",true);s.population.frame_enabled=p.get("auto_spawn",false);s.world.boss_spawned=!bool(p.get("auto_boss",false));s.invincible=p.get("invincible",true);
        s.ship.pos=s.ship_pos=at;s.ship.vel=Vector2();s.view_center=s.enemy_aim=at;c.camera_center=at;c.camera_ready=false;s.draw.gauge=gauge;s.time=time;s.loadout.level=int64_t(level);speed::EquipmentSystem::refresh_effects(runtime);
        if (bool(p.get("empty",false))) {s.field.bodies.clear();s.field.rocks.clear();s.field.rock_handles={};s.field.wells.clear();s.field.warp_gone=-1;}
        if (!bool(p.get("terrain",true))) s.field.bodies.clear();
        if (!bool(p.get("rocks",true))) {s.field.rocks.clear();s.field.rock_handles={};}
        return reply(true);
    }
    if (command=="dev_set_scenario" && (kind=="formation" || kind=="phase_set")) {
        if (!keys(p,{"replacement","expected_revision","layout","entry"}) || p.get("replacement",Variant()).get_type()!=Variant::PACKED_BYTE_ARRAY || p.get("expected_revision",Variant()).get_type()!=Variant::INT || (kind=="phase_set" && p.size()!=2) || (kind=="formation" && (p.size()!=4 || p["layout"].get_type()!=Variant::INT || p["entry"].get_type()!=Variant::INT))) return reply(false);
        Ref<SpeedRunCore> candidate;candidate.instantiate();candidate->runtime=runtime;candidate->runtime.state=speed::clone_state(s);
        Dictionary replacement;replacement["definition_id"]="config";replacement["replacement"]=p["replacement"];replacement["expected_revision"]=p["expected_revision"];
        const Dictionary edited=speed::DevCommands::replace_definition(candidate->runtime,replacement);if (!bool(edited["ok"])) return edited;
        auto &target=candidate->runtime.state;Variant value;
        if (kind=="formation") {
            if (candidate->runtime.content->formations.empty()) return reply(false);
            const auto &f=candidate->runtime.content->formations.back();const int64_t layout=p["layout"],entry=p["entry"];
            if (layout<0 || uint64_t(layout)>=f.layouts.size() || entry<0 || uint64_t(entry)>=f.entries.size()) return reply(false);
            target.formations=candidate->runtime.content->formations;target.formation_base_view=candidate->runtime.content->formation_base_view;target.motion_ready=true;
            const auto ids=candidate->spawn_formation(target.formations.size()-1,layout,entry,PackedStringArray(),-1.0,Variant(),Variant());
            if (ids.size()!=int64_t(f.layouts[layout].types.size())) return reply(false);value=ids;
            Dictionary event;event["pos"]=target.ship_pos;event["enemy_type"]="formation";speed::FrameBuilder::append(candidate->runtime,"lab_spawn",event);
        } else {
            const bool enabled=target.population.frame_enabled;
            if (!target.population.ready) speed::PopulationSystem::prepare(candidate->runtime);
            target.population.frame_enabled=enabled;target.spawn_timeline=candidate->runtime.content->population_timeline;target.spawn_timeline_ready=true;
        }
        runtime=std::move(candidate->runtime);return reply(true,value);
    }
    if (command!="dev_edit") return reply(false);
    if (kind=="delete" || kind=="clear") {
        if ((kind=="clear" && !p.is_empty()) || (kind=="delete" && (p.size()!=1 || p.get("entity_id",Variant()).get_type()!=Variant::INT))) return reply(false);
        const auto erase=[&](int64_t id) {
            const auto found=s.rows_by_id.find(id);if (found==s.rows_by_id.end()) return false;
            const auto actor=s.enemy_handles.at(found->second);const auto enemy=s.enemies[found->second];
            speed::PhaseController::cancel(runtime,actor);
            speed::EnemySystem::mark_dead(runtime,actor);
            if (kind=="delete" && s.enemy_handles.contains(enemy.parent)) {
                speed::DeathContext death;death.target=actor;death.corpse={enemy.id,uint32_t(enemy.definition+1),enemy.pos,enemy.vel,enemy.radius,enemy.facing,enemy.max_hp,enemy.xp,enemy.elite,enemy.is_boss};
                speed::HydraBody::part_defeated(runtime,death);
            }
            return remove_enemy(id);
        };
        if (kind=="delete") {const bool removed=erase(p["entity_id"]);if (removed) rebuild_enemy_grid(s.frame_grid_cell);return reply(removed);}
        std::vector<int64_t> ids;for (const auto &enemy:s.enemies) if (enemy.alive) ids.push_back(enemy.id);
        for (const auto id:ids) if (s.rows_by_id.count(id)) erase(id);
        s.pending_enemies.clear();
        speed::AttackSystem::clear_hostile(s,speed::AttackEndReason::BossClear);rebuild_enemy_grid(s.frame_grid_cell);return reply(true);
    }
    if (kind=="spawn") {
        Vector2 at;double facing,spacing;const Variant count=p.get("count",Variant());
        if (!keys(p,{"definition_id","position","facing","elite","count","spacing"}) || p.get("definition_id",Variant()).get_type()!=Variant::STRING || !point(p,"position",at) || p.get("elite",Variant()).get_type()!=Variant::BOOL || count.get_type()!=Variant::INT || int64_t(count)<1 || int64_t(count)>10000 || !scalar(p,"facing",0,facing) || !scalar(p,"spacing",60,spacing) || spacing<0) return reply(false);
        size_t definition=0;while (definition<runtime.content->definitions.size() && runtime.content->definitions[definition].id!=StringName(p["definition_id"])) ++definition;
        if (definition==runtime.content->definitions.size()) return reply(false);
        int64_t id=-1;
        for (int64_t k=0;k<int64_t(count);++k) {
            speed::EnemySpawn options;options.position=at+Vector2::from_angle(k*2.399963)*std::sqrt(double(k))*spacing;options.facing=facing;options.has_facing=true;options.elite=p["elite"];options.origin=speed::SpawnOrigin::DevPlacement;
            id=speed::DevCommands::place_lab_actor(runtime,definition,options);if (id<=0) return reply(false);
        }
        rebuild_enemy_grid(s.frame_grid_cell);Dictionary event;event["pos"]=at;event["enemy_type"]=runtime.content->definitions[definition].id;speed::FrameBuilder::append(runtime,"lab_spawn",event);return reply(true,id);
    }
    if (kind=="debug_action") return development_debug_command(p);
    if (kind=="debug_content" && s.control.resume_phase!=int32_t(Phase::Finishing) && s.control.resume_phase!=int32_t(Phase::Ended)) return speed::DevCommands::replace_definition(runtime,p,true);
    if (kind=="equipment_preview" || kind=="equipment_seed") {
        if (!c.lab_mode || s.phase!=RunState::Phase::Play || p.get("id",Variant()).get_type()!=Variant::STRING) return reply(false);
        const String id=p["id"];const speed::LoadoutDefinition *definition=nullptr;
        for (const auto &d:runtime.content->equipment) if (String::utf8(d.external_id.c_str())==id) definition=&d;
        if (!definition) return reply(false);const auto &owned=definition->kind==0?s.loadout.weapons:s.loadout.traits;
        if (std::none_of(owned.begin(),owned.end(),[&](const auto &v){return v.definition==definition->id;})) return reply(false);
        const auto matches=[&](const auto &levels){return std::any_of(levels.begin(),levels.end(),[&](const auto &v){return v.equipment==definition->id;});};
        const auto weapon_matches=[&](const auto &levels){return std::any_of(levels.begin(),levels.end(),[&](const auto &v){return v.weapon==definition->id;});};
        const bool kill_sonic=matches(runtime.content->kill_sonic_levels),rampage=matches(runtime.content->rampage_levels),duplicator=matches(runtime.content->duplicator_levels);
        if (kind=="equipment_seed") {
            if (p.size()!=1 || (!kill_sonic && !rampage) || !s.draw.tracing) return reply(false);
            speed::DeathContext death;death.corpse.pos=s.ship.pos+s.ship.heading*100.0;death.request.cause=speed::Cause::Shot;
            for (int i=0;i<(kill_sonic?10:150);++i) {if (kill_sonic) speed::KillSonicBehavior::kill(runtime,death);else speed::RampageBehavior::kill(runtime,death);}return reply(true);
        }
        Vector2 heading;if (p.size()!=3 || !point(p,"heading",heading) || heading.length_squared()<0.0001 || p.get("targets",Variant()).get_type()!=Variant::PACKED_INT64_ARRAY) return reply(false);
        const PackedInt64Array ids=p["targets"];std::vector<speed::EnemyHandle> targets;
        for (const auto entity:ids) {const auto row=s.rows_by_id.find(entity);if (row==s.rows_by_id.end() || s.enemies[row->second].dead) return reply(false);targets.push_back(s.enemy_handles.at(row->second));}
        if (targets.empty()) return reply(false);heading=heading.normalized();s.ship.heading=heading;s.draw.gauge=s.draw_config.capacity;
        if (weapon_matches(runtime.content->flash_slash_levels) || duplicator) for (auto target:targets) s.enemies[target.slot].hp=s.enemies[target.slot].max_hp=100.0;
        if (weapon_matches(runtime.content->knockback_levels)) {s.loadout.knockback.chance=1;speed::DamageRequest hit;hit.struck=targets.front();hit.amount=100;hit.cause=speed::Cause::Shot;hit.direction=heading;speed::CombatResolver::damage_enemy(runtime,hit);}
        if (weapon_matches(runtime.content->interceptor_levels)) speed::InterceptorBehavior::step(runtime,1.0);
        if (duplicator) {s.loadout.duplicator.chance=1;if (s.forward.ready) speed::ForwardBehavior::step(runtime,0.5);}
        if (weapon_matches(runtime.content->barrier_levels)) {speed::ShipDamageRequest hit;hit.amount=1;hit.has_impact=true;hit.impact=s.ship.pos+heading*100;speed::BarrierBehavior::block(runtime,hit,1);}
        if (matches(runtime.content->crit_beam_levels)) {speed::DamageRequest hit;hit.has_impact=true;hit.impact=s.ship.pos;speed::DamageResult result;speed::CritBeamBehavior::critical(runtime,hit,result);}
        if (matches(runtime.content->full_charge_levels)) {s.draw.gauge=0.99;speed::FullBurstBehavior::step(runtime);s.draw.gauge=s.draw_config.capacity;speed::FullBurstBehavior::step(runtime);}
        return reply(true);
    }
    if (kind=="meta") {
        if (p.size()!=2 || p.get("levels",Variant()).get_type()!=Variant::PACKED_INT32_ARRAY || p.get("profile",Variant()).get_type()!=Variant::DICTIONARY) return reply(false);
        const PackedInt32Array levels=p["levels"];if (levels.size()!=8) return reply(false);for (auto level:levels) if (level<0 || level>100) return reply(false);
        speed::RunRuntime next;next.content=runtime.content;next.state=speed::clone_state(s);
        const Dictionary applied=speed::DevCommands::set_profile(next,p["profile"]);if (!bool(applied["ok"])) return applied;
        next.state.loadout.meta_levels.assign(levels.ptr(),levels.ptr()+levels.size());runtime.state=std::move(next.state);return reply(true);
    }
    if (kind=="camera") {
        Vector2 center,size;double zoom,bars;
        if (p.size()!=4 || !point(p,"center",center) || !point(p,"size",size) || size.x<=0 || size.y<=0 || !scalar(p,"zoom",1,zoom) || zoom<=0 || !scalar(p,"bars",0,bars) || bars<0 || bars>1) return reply(false);
        c.camera_center=s.view_center=center;c.camera_zoom=zoom;c.logical_size=size;s.view_half=size/(2.0*zoom);c.camera_ready=true;c.cinematic_bars=bars;return reply(true);
    }
    if (kind=="finish_input" && p.is_empty()) {
        s.hitstop=0;c.world_scale=1;s.draw.drawing=s.draw.tracing=false;s.draw.path.clear();s.draw.points.clear();s.ship.vel=Vector2();s.ship.glide=false;s.ship.boost_t=s.ship.fade_t=0;c.world_real_accum=c.world_dt_accum=0;c.world_steps=0;return reply(true);
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
        Vector2 at;double gauge;if (!keys(p,{"position","velocity","gauge","capacity"}) || !point(p,"position",at) || !scalar(p,"gauge",s.draw.gauge,gauge) || gauge<0) return reply(false);
        Vector2 velocity;if (p.has("velocity") && !point(p,"velocity",velocity)) return reply(false);
        double capacity;if (!scalar(p,"capacity",s.draw_config.capacity,capacity) || capacity<=0 || (p.has("capacity") && !c.lab_mode)) return reply(false);
        s.ship.pos=s.ship_pos=at;s.ship.vel=velocity;s.draw.gauge=gauge;s.draw_config.capacity=capacity;return reply(true);
    }
    if (kind=="time" || kind=="level") {
        double value;if (p.size()!=1 || !scalar(p,"value",0,value) || value<(kind=="level"?1:0) || (kind=="level" && value>1000)) return reply(false);
        if (kind=="time") s.time=value;else {s.loadout.level=int64_t(value);speed::EquipmentSystem::refresh_effects(runtime);}return reply(true);
    }
    if (kind=="move") {
        Vector2 at;double angle;
        if (!keys(p,{"entity_id","position","angle"}) || p.get("entity_id",Variant()).get_type()!=Variant::INT || !point(p,"position",at)) return reply(false);
        const auto row=s.rows_by_id.find(int64_t(p["entity_id"]));if (row==s.rows_by_id.end() || !scalar(p,"angle",s.enemies[row->second].facing,angle)) return reply(false);
        const auto origin=s.enemies[row->second].pos;const auto delta=at-origin;const double rotation=angle-s.enemies[row->second].facing;
        auto family=s.enemies[row->second].parts;family.insert(family.begin(),s.enemy_handles.at(row->second));
        for (const auto child:family) if (s.enemy_handles.contains(child)) {
            auto &enemy=s.enemies[child.slot];const auto previous=enemy.pos;enemy.pos=origin+(enemy.pos-origin).rotated(rotation)+delta;enemy.facing+=rotation;enemy.body_gap=-1;
            if (s.field.rock_handles.contains(enemy.rock)) {auto &rock=s.field.rocks[enemy.rock.slot];rock.position+=enemy.pos-previous;}
            for (auto &hazard:s.hazards) if (hazard.alive) {
                const auto *record=speed::AttackSystem::get(s,hazard.attack);
                if (!record || !record->spec.owner.attached || !speed::same_handle(record->spec.owner.live_source,child)) continue;
                hazard.pos=origin+(hazard.pos-origin).rotated(rotation)+delta;
                if (auto *beam=std::get_if<speed::BeamHazard>(&hazard.shape)) beam->angle+=rotation;
                if (auto *wall=std::get_if<speed::WallHazard>(&hazard.shape)) wall->angle+=rotation;
                if (auto *wave=std::get_if<speed::WaveHazard>(&hazard.shape)) wave->angle+=rotation;
            }
        }
        rebuild_enemy_grid(s.frame_grid_cell);speed::AttackSystem::sync_observation_positions(s);return reply(true);
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
            for (const auto &body:runtime.content->boss_bodies) if (body.enemy==e.definition+1) e.boss=true;
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
    Array groups=director["groups"];size_t gi=0;for (const auto &entry:budget.groups) {Dictionary row=groups[gi++];Array categories;for (auto category:entry.value.categories) categories.push_back(speed::symbol_name(category));row["categories"]=categories;row["pos"]=entry.value.pos;row["type"]=entry.value.definition?runtime.content->definitions[entry.value.definition-1].source_id():StringName();}value["director"]=director;
    Array enemies;
    for (const auto &e:s.enemies) if (e.alive) {
        Dictionary row;row["id"]=e.id;row["type"]=runtime.content->definitions[e.definition].source_id();row["pos"]=e.pos;row["vel"]=e.vel;row["hp"]=e.hp;row["max_hp"]=e.max_hp;row["armor"]=e.armor;row["speed"]=e.speed;row["r"]=e.radius;row["facing"]=e.facing;row["dead"]=e.dead;row["elite"]=e.elite;row["gate"]=int(runtime.content->definitions[e.definition].gate);row["is_boss"]=e.is_boss;row["meteor_index"]=s.field.rock_handles.contains(e.rock)?int64_t(e.rock.slot):-1;row["mode"]=int(e.mode);row["charge"]=e.charge;row["parent"]=s.enemy_handles.contains(e.parent)?s.enemy_handles.entity_id(e.parent):-1;enemies.push_back(row);
    }
    value["draw_time_scale"]=s.draw_config.time_scale;value["max_hp"]=s.ship_config.max_hp;value["xp_profile_factor"]=s.loadout.xp_profile_factor;value["hero"]=speed::HeroesSystem::snapshot(runtime);PackedInt32Array meta;for (auto level:s.loadout.meta_levels) meta.push_back(level);value["meta_levels"]=meta;
    PackedStringArray definitions;for (const auto &d:runtime.content->definitions) definitions.push_back(d.id);value["definition_ids"]=definitions;
    godot::Array final_modules;for (const auto &id:s.control.final_modules) final_modules.push_back(godot::String(id.c_str()));value["final_modules"]=final_modules;value["draco_finish_done"]=s.control.draco_finish_done;value["lab_mode"]=s.control.lab_mode;value["cinematic_bars"]=s.control.cinematic_bars;value["camera_zoom"]=s.control.camera_zoom;value["view_half"]=s.view_half;value["view_center"]=s.view_center;value["capacity"]=s.draw_config.capacity;value["max_speed"]=s.ship_config.max_speed;value["length_mult"]=s.draw_config.length_mult;value["enemies"]=enemies;Array bodies;for (const auto &b:s.field.bodies) {Dictionary row;row["pos"]=b.position;row["r"]=b.radius;bodies.push_back(row);}value["bodies"]=bodies;value["hazards"]=hazards_snapshot();value["hostiles"]=hostiles_snapshot();return reply(true,value);
}
