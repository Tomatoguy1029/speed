#include "boss_states_box.h"
#include "boss_states.h"
namespace speed {
BossStatesBox::BossStatesBox(): value(new BossStates()) {}
BossStatesBox::BossStatesBox(const BossStatesBox &other): value(new BossStates(*other.value)) {}
BossStatesBox &BossStatesBox::operator=(const BossStatesBox &other) {
    if (this != &other) *value=*other.value;
    return *this;
}
BossStatesBox::~BossStatesBox() {delete value;}
}
