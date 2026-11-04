#include "state_box.h"
#include "boss_states.h"
#include "loadout_state.h"
namespace speed {
template<class T> StateBox<T>::StateBox(): value(new T()) {}
template<class T> StateBox<T>::StateBox(const StateBox &other): value(new T(*other.value)) {}
template<class T> StateBox<T> &StateBox<T>::operator=(const StateBox &other) {
    if (this != &other) *value=*other.value;
    return *this;
}
template<class T> StateBox<T>::~StateBox() {delete value;}
template class StateBox<BossStates>;
template class StateBox<LoadoutState>;
}
