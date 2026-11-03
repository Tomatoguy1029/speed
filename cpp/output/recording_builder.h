#pragma once
#include "../state/combat_types.h"
#include <godot_cpp/variant/dictionary.hpp>
namespace speed {
class RunRuntime;
class RecordingBuilder {
public:
    static void set_active(RunRuntime &,bool);
    static void enemy_spawned(RunRuntime &,EnemyHandle);
    static void enemy_released(RunRuntime &,EnemyHandle);
    static void enemy_damage(RunRuntime &,const DamageRequest &,const DamageResult &);
    static void enemy_killed(RunRuntime &,const DeathContext &);
    static void player_damage(RunRuntime &,const ShipDamageRequest &,const ShipDamageResult &);
    static void budget(RunRuntime &);
    static godot::Dictionary read(const RunRuntime &);
};
}
