#include "cross.h"
#include "../attack_system.h"
namespace speed {
std::vector<AttackHandle> CrossSystem::emit(RunRuntime &run,const BeamParams &params) {
    std::vector<AttackHandle> handles;
    for (int k=0;k<4;++k) {
        auto beam=params;beam.angle=params.angle+k*godot::Math::PI/2.0;beam.arc=0;beam.style=BeamStyle::Plain;
        const auto handle=BeamSystem::emit(run,beam);
        if (!AttackSystem::get(run.state,handle)) {
            for (auto created:handles) AttackSystem::end(run.state,created,AttackEndReason::TechniqueCancel);
            return {};
        }
        handles.push_back(handle);
    }
    return handles;
}
}
