#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
namespace speed {class DracoScreenStaging {public:
    static void side_entry(RunRuntime &,TechniqueState &,DracoSideEntryState &);
    static void advance_side(RunRuntime &,TechniqueState &,const DracoSideEntryState &,double);
    static bool validate_side(const DracoSideEntryState &);
    static void begin(RunRuntime &,TechniqueState &,DracoStagingState &,bool enter=false,double height=0);
    static bool advance(RunRuntime &,TechniqueState &,DracoStagingState &,double);
    static bool validate(const DracoStagingState &);
};}
