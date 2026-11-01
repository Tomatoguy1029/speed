// 共通スキーマから生成。直接編集しない。
#pragma once
#include "../binary_reader.h"
#include <vector>
#include <unordered_set>
namespace speed {
struct RunConfig {
    uint32_t id{};
    double aim_lag{};
    double aim_speed{};
    double crystal_low{};
    double crystal_mid{};
    double crystal_high{};
};
inline bool read(BinaryReader &input, RunConfig &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.aim_lag)) return false;
    if (out.aim_lag < 0) return false;
    if (!input.read_f64(out.aim_speed)) return false;
    if (out.aim_speed < 0) return false;
    if (!input.read_f64(out.crystal_low)) return false;
    if (out.crystal_low < 0) return false;
    if (!input.read_f64(out.crystal_mid)) return false;
    if (out.crystal_mid < 0) return false;
    if (!input.read_f64(out.crystal_high)) return false;
    if (out.crystal_high < 0) return false;
    return true;
}
struct StringEntry {
    uint32_t id{};
    std::string value{};
};
inline bool read(BinaryReader &input, StringEntry &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.value)) return false;
    return true;
}
struct DefinitionIndex {
    uint32_t id{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, DefinitionIndex &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    return true;
}
struct ChaseDefinition {
    uint32_t id{};
    double hp{};
    double armor{};
    double radius{};
    double speed{};
    double fire_interval{};
    double xp{};
    double knockback{};
    double hitstop_multiplier{};
    double attack_value{};
    double attack_priority{};
    double attack_weight{};
    double warn{};
    bool attack_managed{};
    int64_t rank{};
    bool size_var{};
    float color_r{};
    float color_g{};
    float color_b{};
    float color_a{};
    double scaling_radius{};
    double scaling_hp{};
    double scaling_armor{};
    double scaling_hp_mult{};
    double scaling_armor_mult{};
    double scaling_character{};
    double scaling_visual{};
    double scaling_collision{};
    bool fixed_sprite{};
    uint32_t reward_low{};
    uint32_t reward_mid{};
    uint32_t reward_high{};
    bool gold_eligible{};
};
inline bool read(BinaryReader &input, ChaseDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.hp)) return false;
    if (out.hp < 0) return false;
    if (!input.read_f64(out.armor)) return false;
    if (out.armor < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.fire_interval)) return false;
    if (out.fire_interval < 0) return false;
    if (!input.read_f64(out.xp)) return false;
    if (out.xp < 0) return false;
    if (!input.read_f64(out.knockback)) return false;
    if (out.knockback < 0) return false;
    if (!input.read_f64(out.hitstop_multiplier)) return false;
    if (out.hitstop_multiplier < 0) return false;
    if (!input.read_f64(out.attack_value)) return false;
    if (out.attack_value < 0) return false;
    if (!input.read_f64(out.attack_priority)) return false;
    if (!input.read_f64(out.attack_weight)) return false;
    if (out.attack_weight < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_bool(out.attack_managed)) return false;
    if (!input.read_i64(out.rank)) return false;
    if (out.rank < 0) return false;
    if (!input.read_bool(out.size_var)) return false;
    if (!input.read_f32(out.color_r)) return false;
    if (!input.read_f32(out.color_g)) return false;
    if (!input.read_f32(out.color_b)) return false;
    if (!input.read_f32(out.color_a)) return false;
    if (!input.read_f64(out.scaling_radius)) return false;
    if (out.scaling_radius < 0) return false;
    if (!input.read_f64(out.scaling_hp)) return false;
    if (out.scaling_hp < 0) return false;
    if (!input.read_f64(out.scaling_armor)) return false;
    if (out.scaling_armor < 0) return false;
    if (!input.read_f64(out.scaling_hp_mult)) return false;
    if (out.scaling_hp_mult < 0) return false;
    if (!input.read_f64(out.scaling_armor_mult)) return false;
    if (out.scaling_armor_mult < 0) return false;
    if (!input.read_f64(out.scaling_character)) return false;
    if (out.scaling_character < 0) return false;
    if (!input.read_f64(out.scaling_visual)) return false;
    if (out.scaling_visual < 0) return false;
    if (!input.read_f64(out.scaling_collision)) return false;
    if (out.scaling_collision < 0) return false;
    if (!input.read_bool(out.fixed_sprite)) return false;
    if (!input.read_u32(out.reward_low)) return false;
    if (!input.read_u32(out.reward_mid)) return false;
    if (!input.read_u32(out.reward_high)) return false;
    if (!input.read_bool(out.gold_eligible)) return false;
    return true;
}
struct LoadoutDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, LoadoutDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct HeroDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, HeroDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct FieldDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, FieldDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct PopulationDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, PopulationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct FormationDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, FormationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct BossFlowDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, BossFlowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct TechniqueDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, TechniqueDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct ResourceKey {
    uint32_t id{};
};
inline bool read(BinaryReader &input, ResourceKey &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct ContentRecords {
    std::vector<RunConfig> RunConfig_rows;
    std::vector<StringEntry> StringEntry_rows;
    std::vector<DefinitionIndex> DefinitionIndex_rows;
    std::vector<ChaseDefinition> ChaseDefinition_rows;
    std::vector<LoadoutDefinition> LoadoutDefinition_rows;
    std::vector<HeroDefinition> HeroDefinition_rows;
    std::vector<FieldDefinition> FieldDefinition_rows;
    std::vector<PopulationDefinition> PopulationDefinition_rows;
    std::vector<FormationDefinition> FormationDefinition_rows;
    std::vector<BossFlowDefinition> BossFlowDefinition_rows;
    std::vector<TechniqueDefinition> TechniqueDefinition_rows;
    std::vector<ResourceKey> ResourceKey_rows;
};
inline bool read_section(uint32_t kind, uint32_t version, uint32_t count, BinaryReader &input, ContentRecords &out) {
    if (version != 1) return false;
    switch(kind) {
    case 1: {
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { RunConfig row; if (!read(input,row)) return false; out.RunConfig_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 2: {
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { StringEntry row; if (!read(input,row)) return false; out.StringEntry_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 3: {
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { DefinitionIndex row; if (!read(input,row)) return false; out.DefinitionIndex_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 4: {
        if (count > input.remaining()/204) return false;
        for (uint32_t i=0; i<count; ++i) { ChaseDefinition row; if (!read(input,row)) return false; out.ChaseDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 5: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { LoadoutDefinition row; if (!read(input,row)) return false; out.LoadoutDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 6: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { HeroDefinition row; if (!read(input,row)) return false; out.HeroDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 7: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { FieldDefinition row; if (!read(input,row)) return false; out.FieldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 8: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationDefinition row; if (!read(input,row)) return false; out.PopulationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 9: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { FormationDefinition row; if (!read(input,row)) return false; out.FormationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 10: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowDefinition row; if (!read(input,row)) return false; out.BossFlowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 11: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { TechniqueDefinition row; if (!read(input,row)) return false; out.TechniqueDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 12: {
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { ResourceKey row; if (!read(input,row)) return false; out.ResourceKey_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    default: return false;
    }
}
inline bool validate_references(const ContentRecords &data) {
    std::unordered_set<uint32_t> RunConfig_ids;
    for (const auto &row:data.RunConfig_rows) if (!RunConfig_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> StringEntry_ids;
    for (const auto &row:data.StringEntry_rows) if (!StringEntry_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DefinitionIndex_ids;
    for (const auto &row:data.DefinitionIndex_rows) if (!DefinitionIndex_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ChaseDefinition_ids;
    for (const auto &row:data.ChaseDefinition_rows) if (!ChaseDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LoadoutDefinition_ids;
    for (const auto &row:data.LoadoutDefinition_rows) if (!LoadoutDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HeroDefinition_ids;
    for (const auto &row:data.HeroDefinition_rows) if (!HeroDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FieldDefinition_ids;
    for (const auto &row:data.FieldDefinition_rows) if (!FieldDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationDefinition_ids;
    for (const auto &row:data.PopulationDefinition_rows) if (!PopulationDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationDefinition_ids;
    for (const auto &row:data.FormationDefinition_rows) if (!FormationDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowDefinition_ids;
    for (const auto &row:data.BossFlowDefinition_rows) if (!BossFlowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> TechniqueDefinition_ids;
    for (const auto &row:data.TechniqueDefinition_rows) if (!TechniqueDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ResourceKey_ids;
    for (const auto &row:data.ResourceKey_rows) if (!ResourceKey_ids.insert(row.id).second) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!StringEntry_ids.count(row.id)) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!ChaseDefinition_ids.count(row.enemy)) return false;
    for (const auto &row:data.ChaseDefinition_rows) if (!StringEntry_ids.count(row.id)) return false;
    return true;
}
inline EnemyDefinition to_enemy(const ChaseDefinition &row, const godot::StringName &id) {
    EnemyDefinition out; out.id=id; out.spawn_ready=true; out.scaling.ready=true;
    out.hp=row.hp;
    out.armor=row.armor;
    out.radius=row.radius;
    out.speed=row.speed;
    out.fire_interval=row.fire_interval;
    out.xp=row.xp;
    out.knockback=row.knockback;
    out.hitstop_multiplier=row.hitstop_multiplier;
    out.attack_value=row.attack_value;
    out.attack_priority=row.attack_priority;
    out.attack_weight=row.attack_weight;
    out.attack_telegraph=row.warn;
    out.attack_managed=row.attack_managed;
    out.rank=row.rank;
    out.size_var=row.size_var;
    out.color.r=row.color_r;
    out.color.g=row.color_g;
    out.color.b=row.color_b;
    out.color.a=row.color_a;
    out.scaling.radius=row.scaling_radius;
    out.scaling.hp=row.scaling_hp;
    out.scaling.armor=row.scaling_armor;
    out.scaling.hp_mult=row.scaling_hp_mult;
    out.scaling.armor_mult=row.scaling_armor_mult;
    out.scaling.character=row.scaling_character;
    out.scaling.visual=row.scaling_visual;
    out.scaling.collision=row.scaling_collision;
    out.scaling.fixed_sprite=row.fixed_sprite;
    out.xp_rewards[0]=row.reward_low;
    out.xp_rewards[1]=row.reward_mid;
    out.xp_rewards[2]=row.reward_high;
    out.gold_eligible=row.gold_eligible;
    return out;
}
inline constexpr uint32_t FORMAT_VERSION=1, ABI_VERSION=1, SECTION_COUNT=12;
}
