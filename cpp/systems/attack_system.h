#pragma once
#include "../state/run_state.h"
namespace speed {
class AttackSystem {
public:
    static AttackHandle emit_friendly(godot::RunState &,godot::RunState::Friendly,AttackSpec);
    static AttackHandle emit_hostile(godot::RunState &,godot::RunState::Hostile,AttackSpec);
    static AttackHandle emit_hazard(godot::RunState &,godot::RunState::BiteZone,AttackSpec);
    static const AttackRecord *get(const godot::RunState &,AttackHandle);
    static bool end(godot::RunState &,AttackHandle,AttackEndReason);
    static void source_ended(godot::RunState &,EnemyHandle,AttackEndReason);
    static void end_technique(godot::RunState &,TechniqueHandle,bool cancelled);
    static void end_participant(godot::RunState &,ParticipantHandle);
    static void end_boss(godot::RunState &,BossHandle);
    static void end_encounter(godot::RunState &,EncounterHandle);
    static void clear_bonus(godot::RunState &);
    static void clear_hostile(godot::RunState &,AttackEndReason);
    static bool begin_hostile_update(godot::RunState &);
    static void finish_hostile_update(godot::RunState &);
    static bool hazard_act(const godot::RunState &,AttackHandle,double dt);
    static bool hazard_before_touch(const godot::RunState &,AttackHandle);
    static bool rebuild(godot::RunState &);
};
}
