#pragma once
#include "../../native/runtime_data.h"
#include <vector>
#include <array>
#include <memory>
#include "generated/run_schema.h"

namespace speed {
// ランと保持したランで共有する読み取り専用の定義。
struct ContentBundle {
    std::array<uint8_t,32> input_sha256{}, payload_sha256{};
    RunConfig config;
    std::array<double,3> crystal_values{};
    double aim_lag=0, aim_speed=0;
    std::vector<EnemyDefinition> definitions;
    std::vector<ResourceKey> visuals;
    std::vector<ForwardDefinition> forward_levels;
    std::vector<BiteDefinition> bites;
    std::vector<HoundDefinition> hounds;
    std::vector<GunnerDefinition> gunners;
    std::vector<BeamerDefinition> beamers;
    std::vector<MissileEnemyDefinition> missile_enemies;
    std::vector<ContactDefinition> contacts;
    std::vector<HostileDefinition> hostile_definitions;
    std::vector<BeamDefinition> beams;
    std::vector<WaveDefinition> waves;
    std::vector<WallDefinition> walls;
    std::vector<FriendShotDefinition> friend_shots;
    std::vector<BudgetPhase> budget_phases;
    ProgressionDefinition progression;
    LifecycleDefinition lifecycle;
    std::vector<FieldBodyDefinition> field_bodies;
    std::vector<MoonDefinition> moon_definitions;
    std::vector<RockFieldDefinition> rock_fields;
    std::vector<LoadoutDefinition> equipment;
    std::vector<LoadoutAsset> equipment_assets;
    std::vector<NumericTraitLevel> numeric_traits;
    PostMaxChargeDefinition post_charge;
    PostMaxCritDefinition post_crit;
    PostMaxMotionDefinition post_motion;
    std::vector<PostMaxWeaponPowerDefinition> post_weapon_power;
    PostMaxPickupDefinition post_pickup;
    PostMaxDrawDefinition post_draw;
    static std::shared_ptr<const ContentBundle> read(const godot::PackedByteArray &bytes);
};
}
