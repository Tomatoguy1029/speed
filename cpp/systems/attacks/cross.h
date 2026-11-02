#pragma once
#include "beam.h"
namespace speed {
class CrossSystem {
public:
    static std::vector<AttackHandle> emit(RunRuntime &,const BeamParams &);
};
}
