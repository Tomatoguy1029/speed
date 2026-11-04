#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
struct CanisFlameAimSettings {double warn=0,lock=0,lead=0,turn=0;uint32_t flame=0;bool remaining_lead=false;};
class CanisFlameAim {public:
    static void begin(RunRuntime &,TechniqueState &,CanisFlameAimState &);
    static bool advance(RunRuntime &,TechniqueState &,CanisFlameAimState &,const CanisFlameAimSettings &,double);
    static double progress(const CanisFlameAimState &,double warn);
    static bool validate(const CanisFlameAimState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &,const CanisFlameAimState &,const CanisFlameAimSettings &);
};
}
