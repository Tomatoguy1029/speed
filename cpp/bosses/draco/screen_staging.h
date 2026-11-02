#pragma once
#include "technique.h"
namespace speed {class DracoScreenStaging {public:
    static void begin(RunRuntime &,TechniqueState &,DracoStagingState &,bool enter=false,double height=0);
    static bool advance(RunRuntime &,TechniqueState &,DracoStagingState &,double);
    static bool validate(const DracoStagingState &);
};}
