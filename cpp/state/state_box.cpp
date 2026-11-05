#include "state_box.h"
#include "boss_states.h"
#include "loadout_state.h"
#include "../bosses/canis_major/state.h"
#include "../bosses/centaurus/state.h"
#include "../bosses/draco/state.h"
#include "../bosses/hydra/state.h"
#include "../bosses/monoceros/state.h"
namespace speed {
template<class T> StateBox<T>::StateBox(): value(new T()) {}
template<class T> StateBox<T>::StateBox(const StateBox &other): value(new T(*other.value)) {}
template<class T> StateBox<T> &StateBox<T>::operator=(const StateBox &other) {
    if (this != &other) *value=*other.value;
    return *this;
}
template<class T> StateBox<T>::~StateBox() {delete value;}
template class StateBox<BossStates>;
template class StateBox<HydraBodyState>;
template class StateBox<DracoBodyState>;
template class StateBox<CanisBodyState>;
template class StateBox<CentaurusBodyState>;
template class StateBox<MonocerosBodyState>;
template class StateBox<LoadoutState>;
}
