#include "normal_attack.h"
#include "../../state/boss_states.h"
#include <algorithm>
namespace speed {
void HydraNormalAttack::step_headbutt(RunRuntime &r,TechniqueState &t,double dt) {
    const auto &v=*std::find_if(r.content->hydra_thunders.begin(),r.content->hydra_thunders.end(),[&](const auto &v){return v.technique==t.definition;});step_thrust(r,t,dt,&v);
}
}
