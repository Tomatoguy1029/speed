#include "technique_runner.h"
#include "../canis_major/command.h"
#include "../canis_major/howl.h"
#include "../monoceros/charge.h"
#include "../centaurus/volley.h"
#include "../centaurus/stomp.h"
#include "../centaurus/fan_volley.h"
#include "../centaurus/arrow_shower.h"
#include "../centaurus/rear_attack.h"
#include "../centaurus/rain.h"
#include "../centaurus/power_shot.h"
#include "../monoceros/kick.h"
#include "../monoceros/sweep.h"
#include "../monoceros/lance.h"
#include "../monoceros/return_charge.h"
#include "../monoceros/horn_wave.h"
#include "../monoceros/horn_dance.h"
#include "../monoceros/sword_flash.h"
#include "phase_controller.h"
#include "../../systems/attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
bool live(TechniqueStage stage) {return stage<TechniqueStage::Finished;}
bool kick(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1].kind==1;}
void command(RunRuntime &r,TechniqueState &t,TechniqueCommand c) {if (r.content->boss_techniques[t.definition-1].kind==40) CanisCommand::command(r,t,c);else if (r.content->boss_techniques[t.definition-1].kind==11) CentaurusPower::command(r,t,c);else if (r.content->boss_techniques[t.definition-1].kind==10) CentaurusRain::command(r,t,c);else if (r.content->boss_techniques[t.definition-1].kind==9) CentaurusRear::command(r,t,c);else if (r.content->boss_techniques[t.definition-1].kind==8) CentaurusVolley::command(r,t,c);else if (kick(r,t)) MonocerosKick::command(r,t,c);else MonocerosCharge::command(r,t,c);}
godot::PackedVector2Array shape(const RunRuntime &r,const TechniqueState &t,bool warning=false) {return r.content->boss_techniques[t.definition-1].kind>=8?godot::PackedVector2Array():r.content->boss_techniques[t.definition-1].kind==7?MonocerosSword::horn(r,t):r.content->boss_techniques[t.definition-1].kind==6?MonocerosDance::horn(r,t):r.content->boss_techniques[t.definition-1].kind==5?MonocerosHornWave::horn(r,t):r.content->boss_techniques[t.definition-1].kind==4?MonocerosReturn::horn(r,t,warning):r.content->boss_techniques[t.definition-1].kind==3?MonocerosLance::horn(r,t):r.content->boss_techniques[t.definition-1].kind==2?MonocerosSweep::horn(r,t):kick(r,t)?MonocerosKick::horn(r,t,warning):MonocerosCharge::horn(r,t,warning);}
}
bool TechniqueRunner::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && (r.content->boss_techniques[definition-1].kind==41?CanisHowl::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==40?CanisCommand::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==14?CentaurusShower::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==13?CentaurusFan::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==12?CentaurusStomp::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==11?CentaurusPower::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==10?CentaurusRain::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==9?CentaurusRear::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==8?CentaurusVolley::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==7?MonocerosSword::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==6?MonocerosDance::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==5?MonocerosHornWave::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==4?MonocerosReturn::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==3?MonocerosLance::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==2?MonocerosSweep::ready(r,actor,definition):r.content->boss_techniques[definition-1].kind==1?MonocerosKick::ready(r,actor,definition):MonocerosCharge::ready(r,actor,definition));}
double TechniqueRunner::attack_length(const BossTechniqueDefinition &p) {return p.kind==7?p.first_windup+(p.cuts-1)*p.warn+p.cuts*(p.swing_time+p.cut_gap)+p.return_time:p.kind==4?p.warn+p.passes*p.active+(p.passes-1)*(p.brake_time+p.turn_time):p.kind==3?p.warn+p.distance/std::max(p.speed,0.001)+p.stop_time:p.kind==9?p.warn+p.active+0.05:p.kind==2?p.approach_max+p.stop_time+p.active+p.hold+p.return_time:p.warn+p.active;}
bool TechniqueRunner::owns(const RunRuntime &run,EnemyHandle actor) {
    for (const auto &technique:run.state.bosses.techniques) if (same_handle(technique.actor,actor)) return true;
    return false;
}
bool TechniqueRunner::running(const RunRuntime &run,TechniqueHandle handle) {
    return run.state.bosses.handles.contains(handle) && live(run.state.bosses.techniques[handle.slot].stage);
}
TechniqueHandle TechniqueRunner::begin(RunRuntime &run,EnemyHandle actor,uint32_t definition) {
    auto &s=run.state;
    if (const auto *body=PhaseController::find(run,actor)) {
        if (!definition || definition>run.content->boss_techniques.size()) return {};
        const auto &base=run.content->boss_techniques[definition-1];
        if (base.boss!=run.content->boss_bodies[body->definition-1].boss) return {};
        definition=0;for (const auto &p:run.content->boss_techniques) if (p.boss==base.boss && p.external_id==base.external_id && p.phase==body->phase) {definition=p.id;break;}
    }
    if (!PhaseController::can_start(run,actor) || !definition || definition>run.content->boss_techniques.size() || !s.enemy_handles.contains(actor) || s.enemies[actor.slot].dead || s.bosses.next_id==INT64_MAX) return {};
    for (const auto &t:s.bosses.techniques) if (live(t.stage) && same_handle(t.actor,actor)) return {};
    size_t row=0;while (row<s.bosses.techniques.size() && (live(s.bosses.techniques[row].stage) || s.bosses.techniques[row].ticket_refs)) ++row;
    if (row==s.bosses.techniques.size()) s.bosses.techniques.emplace_back();
    else s.bosses.handles.release(s.bosses.handles.at(uint32_t(row)));
    auto &technique=s.bosses.techniques[row];technique={};technique.id=s.bosses.next_id++;technique.actor=actor;technique.definition=definition;
    const auto handle=s.bosses.handles.attach(uint32_t(row),technique.id);
    if (run.content->boss_techniques[technique.definition-1].kind==41) CanisHowl::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==40) CanisCommand::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==14) CentaurusShower::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==13) CentaurusFan::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==12) CentaurusStomp::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==11) CentaurusPower::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==10) CentaurusRain::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==9) CentaurusRear::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==8) CentaurusVolley::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==7) MonocerosSword::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==6) MonocerosDance::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==5) MonocerosHornWave::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==4) MonocerosReturn::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==3) MonocerosLance::begin(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==2) MonocerosSweep::begin(run,technique);else if (kick(run,technique)) MonocerosKick::begin(run,technique);else MonocerosCharge::begin(run,technique);
    s.enemies[actor.slot].mode=EnemyMode::Windup;
    // advance(0)と同じく、時刻0の命令だけは開始時に実行する。
    for (const auto &stage:run.content->boss_stages) if (stage.technique==definition && stage.at==0) {
        ++technique.command_cursor;command(run,technique,TechniqueCommand(stage.command));
        if (technique.stage!=TechniqueStage::Windup && technique.stage!=TechniqueStage::Active) break;
    }
    return handle;
}
void TechniqueRunner::cancel(RunRuntime &run,TechniqueHandle handle) {
    if (!running(run,handle)) return;
    auto &technique=run.state.bosses.techniques[handle.slot];if (run.content->boss_techniques[technique.definition-1].kind==41) CanisHowl::cancel(run,technique);else if (run.content->boss_techniques[technique.definition-1].kind==40) CanisCommand::cancel(run,technique);technique.stage=TechniqueStage::Cancelled;
    if (auto *rain=std::get_if<CentaurusRainState>(&technique.detail)) *rain={};
    if (auto *shower=std::get_if<CentaurusShowerState>(&technique.detail)) shower->marks.clear();
    if (auto *power=std::get_if<CentaurusPowerState>(&technique.detail)) power->alerting=false;
    if (run.state.enemy_handles.contains(technique.actor)) {auto &e=run.state.enemies[technique.actor.slot];e.vel={};e.charge=0;e.mode=EnemyMode::Move;}
    AttackSystem::end_technique(run.state,handle,true);
}
void TechniqueRunner::step(RunRuntime &run,double dt) {
    if (dt<=0) return;
    auto &s=run.state;
    for (uint32_t row=0;row<s.bosses.techniques.size();++row) {
        auto &technique=s.bosses.techniques[row];if (!live(technique.stage)) continue;
        const auto handle=s.bosses.handles.at(row);
        if (!s.enemy_handles.contains(technique.actor) || s.enemies[technique.actor.slot].dead) {cancel(run,handle);continue;}
        const auto before=technique.stage;
        if (run.content->boss_techniques[technique.definition-1].kind==41) CanisHowl::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==40) CanisCommand::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==14) CentaurusShower::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==13) CentaurusFan::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==12) CentaurusStomp::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==11) CentaurusPower::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==10) CentaurusRain::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==9) CentaurusRear::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==8) CentaurusVolley::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==7) MonocerosSword::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==6) MonocerosDance::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==5) MonocerosHornWave::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==4) MonocerosReturn::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==3) MonocerosLance::step(run,technique,dt);else if (run.content->boss_techniques[technique.definition-1].kind==2) MonocerosSweep::step(run,technique,dt);else if (kick(run,technique)) MonocerosKick::step(run,technique,dt);else MonocerosCharge::step(run,technique,dt);
        if ((before==TechniqueStage::Windup || before==TechniqueStage::Active) && (technique.stage==TechniqueStage::Windup || technique.stage==TechniqueStage::Active)) {
            technique.elapsed+=dt;uint32_t cursor=0;
            for (const auto &stage:run.content->boss_stages) if (stage.technique==technique.definition) {
                if (cursor++<technique.command_cursor) continue;
                if (stage.at>technique.elapsed && !godot::Math::is_equal_approx(stage.at,technique.elapsed)) break;
                ++technique.command_cursor;command(run,technique,TechniqueCommand(stage.command));
                if (technique.stage!=TechniqueStage::Windup && technique.stage!=TechniqueStage::Active) break;
            }
        }
        const auto &p=run.content->boss_techniques[technique.definition-1];auto &e=s.enemies[technique.actor.slot];
        e.charge=p.kind==7?std::get<MonocerosSwordState>(technique.detail).glow:p.kind==6?std::get<MonocerosDanceState>(technique.detail).glow:p.kind==5?std::get<MonocerosHornWaveState>(technique.detail).glow:p.kind==4?std::get<MonocerosReturnState>(technique.detail).glow:p.kind==3?std::get<MonocerosLanceState>(technique.detail).glow:p.kind==2 && (technique.stage==TechniqueStage::Windup || technique.stage==TechniqueStage::Active)?std::get<MonocerosSweepState>(technique.detail).glow:technique.stage==TechniqueStage::Windup?std::clamp(technique.elapsed/std::max(0.001,p.warn),0.0,1.0):0;
        e.mode=technique.stage==TechniqueStage::Windup?EnemyMode::Windup:technique.stage==TechniqueStage::Active?EnemyMode::Dash:live(technique.stage)?EnemyMode::Recover:EnemyMode::Move;
        technique.previous_ship=s.ship_pos;
        if (!live(technique.stage)) AttackSystem::end_technique(s,handle,technique.stage!=TechniqueStage::Finished);
    }
}
bool TechniqueRunner::validate(const godot::RunState &s,const ContentBundle &content) {
    std::vector<uint64_t> actors;
    for (uint32_t row=0;row<s.bosses.techniques.size();++row) {
        const auto &t=s.bosses.techniques[row];
        if (t.id<=0 || t.id>=s.bosses.next_id || s.bosses.handles.entity_id(s.bosses.handles.at(row))!=t.id || !t.definition || t.definition>content.boss_techniques.size() || t.stage>TechniqueStage::Cancelled || t.command_cursor>std::count_if(content.boss_stages.begin(),content.boss_stages.end(),[&](const auto &p){return p.technique==t.definition;}) || !t.aim.is_finite() || !t.direction.is_finite() || !t.previous_ship.is_finite() || !t.stuck_offset.is_finite() || !t.reposition_direction.is_finite()) return false;
        if (content.boss_techniques[t.definition-1].kind==41?!CanisHowl::validate(t):content.boss_techniques[t.definition-1].kind==40?!CanisCommand::validate(t):content.boss_techniques[t.definition-1].kind==14?!CentaurusShower::validate(t,content):content.boss_techniques[t.definition-1].kind==13?!CentaurusFan::validate(t,content):content.boss_techniques[t.definition-1].kind==11?!CentaurusPower::validate(t,content):content.boss_techniques[t.definition-1].kind==10?!CentaurusRain::validate(t,content):content.boss_techniques[t.definition-1].kind==8?!CentaurusVolley::validate(t,content):content.boss_techniques[t.definition-1].kind==7?!MonocerosSword::validate(t):content.boss_techniques[t.definition-1].kind==6?!MonocerosDance::validate(t):content.boss_techniques[t.definition-1].kind==5?!MonocerosHornWave::validate(t):content.boss_techniques[t.definition-1].kind==4?!MonocerosReturn::validate(t):content.boss_techniques[t.definition-1].kind==3?!MonocerosLance::validate(t):content.boss_techniques[t.definition-1].kind==2?!MonocerosSweep::validate(t):!std::holds_alternative<std::monostate>(t.detail)) return false;
        for (double value:{t.elapsed,t.remaining,t.reposition,t.started_at}) if (!std::isfinite(value) || value<0) return false;
        if (live(t.stage)) {
            if (!s.enemy_handles.contains(t.actor) || s.enemies[t.actor.slot].dead || std::find(actors.begin(),actors.end(),handle_key(t.actor))!=actors.end()) return false;
            actors.push_back(handle_key(t.actor));
        }
        if (t.stage==TechniqueStage::Stuck && t.stuck_body>=s.field.bodies.size()) return false;
    }
    return true;
}
godot::Array TechniqueRunner::snapshot(const RunRuntime &run) {
    godot::Array out;
    for (uint32_t row=0;row<run.state.bosses.techniques.size();++row) {
        const auto &t=run.state.bosses.techniques[row];godot::Dictionary item;
        item["kind"]=run.content->boss_techniques[t.definition-1].kind;item["technique"]=godot::String(run.content->boss_techniques[t.definition-1].external_id.c_str());item["id"]=t.id;item["definition"]=t.definition;item["actor"]=run.state.enemy_handles.entity_id(t.actor);item["stage"]=int(t.stage);
        const auto &p=run.content->boss_techniques[t.definition-1];const double back=p.return_speed>0?godot::Math::PI/p.return_speed:0;
        item["windup_progress"]=std::clamp(t.elapsed/std::max(0.001,p.warn),0.0,1.0);item["active_progress"]=std::clamp((t.elapsed-p.warn)/std::max(0.001,p.active*0.4),0.0,1.0);item["settle_progress"]=t.stage==TechniqueStage::Recovery?(back>0?std::clamp((back+p.recover-t.remaining)/back,0.0,1.0):1.0):0.0;
        if (p.kind==2) {const auto &v=std::get<MonocerosSweepState>(t.detail);item["stop_progress"]=std::clamp(v.elapsed/std::max(p.stop_time,0.001),0.0,1.0);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["angle"]=v.angle;item["side"]=v.side;item["speed"]=v.speed;item["glow"]=v.glow;item["booster"]=v.stage==MonocerosSweepState::Stage::Approach?0.55+1.95*v.speed/std::max(p.approach_speed_max,0.001):v.stage==MonocerosSweepState::Stage::Stop?0.3:0.55;}
        if (p.kind==3) {const auto &v=std::get<MonocerosLanceState>(t.detail);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["form"]=v.form;item["glow"]=v.glow;item["traveled"]=v.traveled;item["boom_time"]=v.boom_time;item["speed"]=v.speed;item["head_length"]=p.head_length;item["booster"]=v.stage==MonocerosLanceState::Stage::Gather?0.55+0.45*v.form:v.stage==MonocerosLanceState::Stage::Run?3.5:1.0;}
        if (p.kind==4) {const auto &v=std::get<MonocerosReturnState>(t.detail);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["angle"]=v.angle;item["glow"]=v.glow;item["travel"]=v.travel;item["traveled"]=v.traveled;item["completed"]=v.completed;item["brake_progress"]=std::clamp(v.elapsed/std::max(p.brake_time,0.001),0.0,1.0);item["booster"]=v.stage==MonocerosReturnState::Stage::Aim?0.55+0.45*v.glow:v.stage==MonocerosReturnState::Stage::Run?2.5:0.55;}
        if (p.kind==5) {const auto &v=std::get<MonocerosHornWaveState>(t.detail);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["angle"]=v.angle;item["glow"]=v.glow;item["side"]=v.direction;item["released"]=v.released;}
        if (p.kind==6) {const auto &v=std::get<MonocerosDanceState>(t.detail);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["angle"]=v.angle;item["glow"]=v.glow;item["travel"]=v.travel;item["traveled"]=v.traveled;item["completed"]=v.completed;item["heading"]=v.heading;item["speed"]=v.speed;item["run_speed"]=v.run_speed;item["booster"]=v.stage==MonocerosDanceState::Stage::Aim?0.55+0.45*v.glow:v.stage==MonocerosDanceState::Stage::Run?2.5:v.stage==MonocerosDanceState::Stage::Circle?1.2:0.55;}
        if (p.kind==7) {const auto &v=std::get<MonocerosSwordState>(t.detail);item["sequence_stage"]=int(v.stage);item["sequence_elapsed"]=v.elapsed;item["angle"]=v.angle;item["glow"]=v.glow;item["cut"]=v.cut;item["side"]=v.side;item["target"]=v.target;item["speed"]=v.speed;item["released"]=v.released;item["released_at"]=v.released_at;}
        if (p.kind==8) {item["released"]=std::get<CentaurusVolleyState>(t.detail).released;item["interval"]=run.content->centaurus_volleys[std::find_if(run.content->centaurus_volleys.begin(),run.content->centaurus_volleys.end(),[&](const auto &v){return v.technique==p.id;})-run.content->centaurus_volleys.begin()].interval;}
        if (p.kind==14) item["shower"]=CentaurusShower::snapshot(run,t);
        if (p.kind==41) {const auto howl=CanisHowl::snapshot(run,t);for (const auto &key:howl.keys()) item[key]=howl[key];}
        if (p.kind==13) {const auto fan=CentaurusFan::snapshot(run,t);for (const auto &key:fan.keys()) item[key]=fan[key];}
        if (p.kind==12) {const auto stomp=CentaurusStomp::snapshot(run,t);for (const auto &key:stomp.keys()) item[key]=stomp[key];}
        if (p.kind==11) {const auto power=CentaurusPower::snapshot(run,t);for (const auto &key:power.keys()) item[key]=power[key];}
        if (p.kind==10) item["rain"]=CentaurusRain::snapshot(run,t);
        if (p.kind==9) {const auto &v=*std::find_if(run.content->centaurus_rears.begin(),run.content->centaurus_rears.end(),[&](const auto &v){return v.technique==p.id;});item["back_offset"]=v.back_offset;item["range_radius"]=v.radius;}
        item["elapsed"]=t.elapsed;item["remaining"]=t.remaining;item["cursor"]=t.command_cursor;item["locked"]=t.locked;item["hit"]=t.hit;item["aim"]=t.aim;item["direction"]=t.direction;item["reposition"]=t.reposition;
        if (run.state.enemy_handles.contains(t.actor)) {item["facing"]=run.state.enemies[t.actor.slot].facing;item["radius"]=run.state.enemies[t.actor.slot].radius;item["width"]=p.kind==3?p.width:run.content->bosses[p.boss-1].horn_width;item["position"]=run.state.enemies[t.actor.slot].pos;item["horn"]=shape(run,t);item["warning"]=shape(run,t,true);}
        out.push_back(item);
    }
    return out;
}
}
