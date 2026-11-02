#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisSequence {public:
    static std::vector<EnemyHandle> shuffled(RunRuntime &,const BossBodyState &);
    static double begin(std::vector<CanisSequenceItem> &,const std::vector<EnemyHandle> &,double,double,double);
    static void tick(RunRuntime &,TechniqueState &,BossBodyState &,std::vector<CanisSequenceItem> &,double,double,double,const char *);
    static void cancel(RunRuntime &,TechniqueState &,std::vector<CanisSequenceItem> &);
};}
