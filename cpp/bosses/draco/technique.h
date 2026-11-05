#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class DracoTechnique {public:
    static bool supports(uint32_t kind);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static RockHandle spawn_rock(RunRuntime &,uint32_t,godot::Vector2);
    static double smooth(double);
    static std::vector<godot::Vector2> neutral(const RunRuntime &,const BossBodyState &,godot::Vector2,double);
    static std::vector<godot::Vector2> fit(const std::vector<godot::Vector2> &,const std::vector<godot::Vector2> &,bool anchor_tip=false);
    static void neck(RunRuntime &,BossBodyState &,const std::vector<godot::Vector2> &,godot::Vector2);
    static void blend(RunRuntime &,BossBodyState &,const std::vector<godot::Vector2> &,const std::vector<godot::Vector2> &,double);
    static godot::Vector2 mouth(const RunRuntime &,const BossBodyState &);
    static godot::Vector2 predict(const RunRuntime &,EnemyHandle,double,double);
    static bool observe_contact(RunRuntime &,TechniqueState &,bool);
    static void hit_segment(RunRuntime &,TechniqueState &,godot::Vector2,godot::Vector2,double,Cause cause=Cause::Bite);
};}
