#pragma once
#include "technique.h"
namespace speed {class DracoScreenStaging {public:
    static void begin(RunRuntime &,TechniqueState &,DracoStagingState &);
    static bool advance(RunRuntime &,TechniqueState &,DracoStagingState &,double);
    static bool validate(const DracoStagingState &);
};}
