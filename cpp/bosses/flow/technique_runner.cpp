#include "technique_runner.h"
#include "../monoceros/charge.h"
#include "../monoceros/kick.h"
#include "phase_controller.h"
#include "../../systems/attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
bool live(TechniqueStage stage) {return stage<TechniqueStage::Finished;}
bool kick(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1].kind==1;}
void command(RunRuntime &r,TechniqueState &t,TechniqueCommand c) {if (kick(r,t)) MonocerosKick::command(r,t,c);else MonocerosCharge::command(r,t,c);}
godot::PackedVector2Array shape(const RunRuntime &r,const TechniqueState &t,bool warning=false) {return kick(r,t)?MonocerosKick::horn(r,t,warning):MonocerosCharge::horn(r,t,warning);}
}
bool TechniqueRunner::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && (r.content->boss_techniques[definition-1].kind==1?MonocerosKick::ready(r,actor,definition):MonocerosCharge::ready(r,actor,definition));}
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
    if (kick(run,technique)) MonocerosKick::begin(run,technique);else MonocerosCharge::begin(run,technique);
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
    auto &technique=run.state.bosses.techniques[handle.slot];technique.stage=TechniqueStage::Cancelled;
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
        if (kick(run,technique)) MonocerosKick::step(run,technique,dt);else MonocerosCharge::step(run,technique,dt);
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
        e.charge=technique.stage==TechniqueStage::Windup?std::clamp(technique.elapsed/std::max(0.001,p.warn),0.0,1.0):0;
        e.mode=technique.stage==TechniqueStage::Windup?EnemyMode::Windup:technique.stage==TechniqueStage::Active?EnemyMode::Dash:live(technique.stage)?EnemyMode::Recover:EnemyMode::Move;
        technique.previous_ship=s.ship_pos;
        if (!live(technique.stage)) AttackSystem::end_technique(s,handle,technique.stage!=TechniqueStage::Finished);
    }
}
bool TechniqueRunner::validate(const godot::RunState &s,const ContentBundle &content) {
    std::vector<uint64_t> actors;
    for (uint32_t row=0;row<s.bosses.techniques.size();++row) {
        const auto &t=s.bosses.techniques[row];
        if (t.id<=0 || t.id>=s.bosses.next_id || s.bosses.handles.entity_id(s.bosses.handles.at(row))!=t.id || !t.definition || t.definition>content.boss_techniques.size() || t.stage>TechniqueStage::Cancelled || t.command_cursor>3 || !t.aim.is_finite() || !t.direction.is_finite() || !t.previous_ship.is_finite() || !t.stuck_offset.is_finite() || !t.reposition_direction.is_finite()) return false;
        for (double value:{t.elapsed,t.remaining,t.reposition}) if (!std::isfinite(value) || value<0) return false;
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
        item["technique"]=godot::String(run.content->boss_techniques[t.definition-1].external_id.c_str());item["id"]=t.id;item["definition"]=t.definition;item["actor"]=run.state.enemy_handles.entity_id(t.actor);item["stage"]=int(t.stage);
        const auto &p=run.content->boss_techniques[t.definition-1];const double back=p.return_speed>0?godot::Math::PI/p.return_speed:0;
        item["windup_progress"]=std::clamp(t.elapsed/std::max(0.001,p.warn),0.0,1.0);item["active_progress"]=std::clamp((t.elapsed-p.warn)/std::max(0.001,p.active*0.4),0.0,1.0);item["settle_progress"]=t.stage==TechniqueStage::Recovery?(back>0?std::clamp((back+p.recover-t.remaining)/back,0.0,1.0):1.0):0.0;
        item["elapsed"]=t.elapsed;item["remaining"]=t.remaining;item["cursor"]=t.command_cursor;item["locked"]=t.locked;item["hit"]=t.hit;item["aim"]=t.aim;item["direction"]=t.direction;item["reposition"]=t.reposition;
        if (run.state.enemy_handles.contains(t.actor)) {item["position"]=run.state.enemies[t.actor.slot].pos;item["horn"]=shape(run,t);item["warning"]=shape(run,t,true);}
        out.push_back(item);
    }
    return out;
}
}
