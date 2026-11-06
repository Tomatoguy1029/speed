#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
namespace speed {class DracoClones {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &,double);
    static void clear(RunRuntime &,BossBodyState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static bool validate_handles(const godot::RunState &,const ContentBundle &,const TechniqueState &);
    static bool validate(const DracoClonesState &,const ContentBundle &);
    static void snapshot_body(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
