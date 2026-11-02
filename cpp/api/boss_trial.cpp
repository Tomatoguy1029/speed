#include "run_core.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/flow/flow_runner.h"
#include "../bosses/flow/technique_runner.h"
#include "../bosses/canis_major/body.h"
#include "../systems/attack_system.h"
#include <algorithm>
#include <cmath>
using namespace godot;

// 制作専用の単独ボス試行。番号の解決・取消・状態変更はランの所有側で完結する。
Dictionary SpeedRunCore::development_boss_trial_command(const Dictionary &p) {
    const auto reply=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"boss_trial";out["message"]=ok?String():String::utf8("単独ボス試行の状態または引数が不正です");out["value"]=value;return out;};
    if (!runtime.api_development || !runtime.state.control.lab_mode || runtime.state.bosses.bodies.size()!=1 || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
    const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));
    if (found==runtime.state.rows_by_id.end()) return reply(false);
    const auto actor=runtime.state.enemy_handles.at(found->second);auto *body=speed::PhaseController::find(runtime,actor);
    if (!body || body->mode>=speed::BossMode::Final) return reply(false);
    const auto boss=runtime.content->boss_bodies[body->definition-1].boss;
    if (runtime.content->bosses[boss-1].kind>2) return reply(false);
    const auto flow=std::find_if(runtime.state.bosses.flows.begin(),runtime.state.bosses.flows.end(),[&](const auto &f){return speed::same_handle(f.actor,actor);});
    if (flow==runtime.state.bosses.flows.end()) return reply(false);
    const String action=p["action"];
    if (action=="state" && p.size()==2) {
        Dictionary value;for (const auto &item:speed::PhaseController::snapshot(runtime)) {const Dictionary row=item;if (int64_t(row["actor"])==int64_t(p["entity_id"])) value=row;}
        value["pinned"]=runtime.state.control.lab_pinned;value["pin"]=runtime.state.control.lab_pin;value["selection"]=flow->selection_enabled;value["flow_index"]=flow->index;value["flow_active"]=flow->active;value["guard"]=runtime.state.enemies[actor.slot].guard;value["steering_locked"]=runtime.state.steering_locked;
        bool busy=!flow->roots.empty();String technique;
        for (const auto &t:runtime.state.bosses.techniques) if (speed::same_handle(t.actor,actor) && t.stage<speed::TechniqueStage::Finished) {busy=true;technique=String::utf8(runtime.content->boss_techniques[t.definition-1].external_id.c_str());}
        value["busy"]=busy;value["technique"]=technique;return reply(true,value);
    }
    if (action=="start" && p.size()==3 && p.get("technique",Variant()).get_type()==Variant::STRING) {
        const String name=p["technique"];
        const auto definition=std::find_if(runtime.content->boss_techniques.begin(),runtime.content->boss_techniques.end(),[&](const auto &t){return t.boss==boss && t.phase==body->phase && String::utf8(t.external_id.c_str())==name;});
        if (definition==runtime.content->boss_techniques.end() || flow->selection_enabled) return reply(false);
        const auto ticket=speed::TechniqueRunner::begin(runtime,actor,definition->id);
        return reply(runtime.state.bosses.handles.contains(ticket));
    }
    if (action!="prepare" || p.size()!=8 || p.get("phase",Variant()).get_type()!=Variant::INT || p.get("origin",Variant()).get_type()!=Variant::VECTOR2 || p.get("target",Variant()).get_type()!=Variant::VECTOR2 || p.get("selection",Variant()).get_type()!=Variant::BOOL || p.get("steering_locked",Variant()).get_type()!=Variant::BOOL) return reply(false);
    const int64_t phase=p["phase"];const Vector2 origin=p["origin"],target=p["target"];const Variant guard=p.get("guard",Variant());
    if (phase<1 || phase>2 || !origin.is_finite() || !target.is_finite() || (guard.get_type()!=Variant::INT && guard.get_type()!=Variant::FLOAT) || !std::isfinite(double(guard)) || double(guard)<0 || double(guard)>1) return reply(false);
    speed::FlowRunner::cancel(runtime,*flow);
    for (uint32_t row=0;row<runtime.state.bosses.techniques.size();++row) if (speed::same_handle(runtime.state.bosses.techniques[row].actor,actor)) speed::TechniqueRunner::cancel(runtime,runtime.state.bosses.handles.at(row));
    speed::AttackSystem::clear_hostile(runtime.state,speed::AttackEndReason::BossClear);
    const auto definition=flow->definition;const auto participants=flow->participants;*flow={};flow->actor=actor;flow->definition=definition;flow->participants=participants;flow->phase=phase;flow->selection_enabled=p["selection"];flow->stamina=runtime.content->boss_flows[definition-1].maximum_stamina;
    body->mode=speed::BossMode::Idle;body->phase=phase;body->phase_pending=false;body->phase_remaining=0;body->initial_wait=0;body->sweep_side=1;body->has_slash=false;
    body->centaurus.leaping=false;body->centaurus.path_hold=body->centaurus.turn_motion=0;body->centaurus.cooldowns.clear();body->centaurus.leap_ready_at=body->centaurus.retreat_ready_at=body->clock;
    auto &e=runtime.state.enemies[actor.slot];e.pos=origin;e.vel={};e.facing=0;e.charge=0;e.guard=guard;e.mode=EnemyMode::Move;
    if (runtime.content->bosses[boss-1].kind==2) speed::CanisMajorBody::reset_trial(runtime,*body);
    runtime.state.ship.pos=runtime.state.ship_pos=target;runtime.state.ship.vel={};runtime.state.enemy_aim=target;runtime.state.view_center=target;runtime.state.steering_locked=p["steering_locked"];
    rebuild_enemy_grid(runtime.state.frame_grid_cell);return reply(true);
}
