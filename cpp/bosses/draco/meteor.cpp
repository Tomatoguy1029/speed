#include "meteor.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {
void DracoMeteor::begin(RunRuntime &r,TechniqueState &t) {DracoBreath::begin(r,t);if (!std::get<DracoBreathState>(t.detail.get<DracoTechniqueState>().move).rocks.empty()) r.state.observations.execute(t.observation_id);}
void DracoMeteor::end(RunRuntime &r,TechniqueState &t,bool cancelled) {if (cancelled) {DracoBreath::end(r,t,true);return;}auto *b=PhaseController::find(r,t.actor);if (!b) return;auto &v=t.detail.get<DracoTechniqueState>();b->draco->placed_meteors=std::get<DracoBreathState>(v.move).rocks;v.warning_paths.clear();}
void DracoMeteor::clear_placed(RunRuntime &r,BossBodyState &b) {for (auto h:b.draco->placed_meteors) if (r.state.field.rock_handles.contains(h)) {auto &rock=r.state.field.rocks[h.slot];rock.destroyed=true;if (r.state.enemy_handles.contains(rock.proxy)) EnemySystem::mark_dead(r,rock.proxy);}b.draco->placed_meteors.clear();}
}
