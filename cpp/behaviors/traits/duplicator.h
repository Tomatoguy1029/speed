#pragma once
#include "../../state/entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <vector>
namespace speed {
class RunRuntime;
class FriendlyBirthScope {
    RunRuntime &run;
    bool active;
public:
    explicit FriendlyBirthScope(RunRuntime &,bool enabled=true);
    ~FriendlyBirthScope();
    FriendlyBirthScope(const FriendlyBirthScope &)=delete;
    void finish();
};
class DuplicatorBehavior {
public:
    static std::vector<godot::Vector2> vectors(RunRuntime &,godot::Vector2 velocity);
    static double damage_factor(const RunRuntime &);
    static void duplicate(RunRuntime &,AttackHandle source);
};
}
