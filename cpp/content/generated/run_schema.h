// 共通スキーマから生成。直接編集しない。
#pragma once
#include "../binary_reader.h"
#include <vector>
#include <unordered_set>
#include "../../state/run_state.h"
namespace speed {
struct RunConfig {
    uint32_t id{};
    double aim_lag{};
    double aim_speed{};
    double crystal_low{};
    double crystal_mid{};
    double crystal_high{};
    double ship_config_start_radius{};
    double ship_config_base_max_speed{};
    double ship_config_stick_dead_zone{};
    double ship_config_mouse_dead_zone{};
    double ship_config_steer_cruise{};
    double ship_config_glide_hold{};
    double ship_config_glide_fade{};
    double ship_config_cruise_floor{};
    double ship_config_energy_cut{};
    double ship_config_cruise_drag{};
    double ship_config_overcap_decay{};
    double ship_config_field_radius{};
    double ship_config_boundary_push{};
    double ship_config_ship_radius{};
    double ship_config_crash_restitution{};
    double ship_config_ship_hurt_time{};
    double ship_config_max_hp{};
    double ship_config_max_speed{};
    double ship_config_turn_rate{};
    double ship_config_acceleration{};
    double ship_config_glide_duration_mult{};
    double ship_config_invulnerability{};
    double draw_config_min_charge{};
    double draw_config_length{};
    double draw_config_point_step{};
    double draw_config_confirm_delay{};
    double draw_config_run_time{};
    double draw_config_time_scale{};
    double draw_config_slow_ref{};
    double draw_config_scale_min{};
    double draw_config_boost_duration{};
    double draw_config_carry{};
    double draw_config_launch_ratio{};
    double draw_config_glide_ratio{};
    double draw_config_capacity{};
    double draw_config_charge_time{};
    double draw_config_length_mult{};
    double camera_base_view{};
    double camera_zoom_ref_speed{};
    double camera_zoom_exp{};
    double camera_zoom_min{};
    double camera_look_ahead{};
    uint32_t world_tick_div{};
    double grid_cell{};
    double time_limit{};
    double combat_base_attack{};
    double combat_atk_scale{};
    double combat_ram_speed_ratio{};
    double combat_crit_armor{};
    double combat_touch_damage{};
    double combat_contact_cooldown{};
    double combat_bounce_keep{};
    double combat_bounce_min_speed{};
    double combat_kill_hitstop{};
    double combat_kill_hitstop_cap{};
    double combat_kill_hitstop_regen{};
    double combat_hitstop_big_mult{};
    double combat_hitstop_crit_mult{};
    double combat_max_enemy_radius{};
    double combat_attack_mult{};
    double combat_crit_chance{};
    double combat_crit_mult{};
    bool combat_ready{};
    bool pickups_ready{};
    int64_t gem_max{};
    double strong_gold_chance{};
    double coin_radius{};
    double pickup_xp_mult{};
    double pickup_speed_mult{};
    double pickup_xp_radius{};
    bool fixed_rewards{};
    double character_scale{};
    bool projectiles_ready{};
    double debris_life{};
    double debris_knock{};
    int64_t trail_points{};
    uint32_t ship_visual{};
    uint32_t shot_visual{};
    uint32_t crystal_visual{};
    uint32_t coin_visual{};
    uint32_t cannon_visual{};
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
    if (!input.read_f64(out.ship_config_start_radius)) return false;
    if (out.ship_config_start_radius < 0) return false;
    if (!input.read_f64(out.ship_config_base_max_speed)) return false;
    if (out.ship_config_base_max_speed < 0) return false;
    if (!input.read_f64(out.ship_config_stick_dead_zone)) return false;
    if (out.ship_config_stick_dead_zone < 0) return false;
    if (!input.read_f64(out.ship_config_mouse_dead_zone)) return false;
    if (out.ship_config_mouse_dead_zone < 0) return false;
    if (!input.read_f64(out.ship_config_steer_cruise)) return false;
    if (out.ship_config_steer_cruise < 0) return false;
    if (!input.read_f64(out.ship_config_glide_hold)) return false;
    if (out.ship_config_glide_hold < 0) return false;
    if (!input.read_f64(out.ship_config_glide_fade)) return false;
    if (out.ship_config_glide_fade < 0) return false;
    if (!input.read_f64(out.ship_config_cruise_floor)) return false;
    if (out.ship_config_cruise_floor < 0) return false;
    if (!input.read_f64(out.ship_config_energy_cut)) return false;
    if (out.ship_config_energy_cut < 0) return false;
    if (!input.read_f64(out.ship_config_cruise_drag)) return false;
    if (out.ship_config_cruise_drag < 0) return false;
    if (!input.read_f64(out.ship_config_overcap_decay)) return false;
    if (out.ship_config_overcap_decay < 0) return false;
    if (!input.read_f64(out.ship_config_field_radius)) return false;
    if (out.ship_config_field_radius < 0) return false;
    if (!input.read_f64(out.ship_config_boundary_push)) return false;
    if (out.ship_config_boundary_push < 0) return false;
    if (!input.read_f64(out.ship_config_ship_radius)) return false;
    if (out.ship_config_ship_radius < 0) return false;
    if (!input.read_f64(out.ship_config_crash_restitution)) return false;
    if (out.ship_config_crash_restitution < 0) return false;
    if (!input.read_f64(out.ship_config_ship_hurt_time)) return false;
    if (out.ship_config_ship_hurt_time < 0) return false;
    if (!input.read_f64(out.ship_config_max_hp)) return false;
    if (out.ship_config_max_hp < 0) return false;
    if (!input.read_f64(out.ship_config_max_speed)) return false;
    if (out.ship_config_max_speed < 0) return false;
    if (!input.read_f64(out.ship_config_turn_rate)) return false;
    if (out.ship_config_turn_rate < 0) return false;
    if (!input.read_f64(out.ship_config_acceleration)) return false;
    if (out.ship_config_acceleration < 0) return false;
    if (!input.read_f64(out.ship_config_glide_duration_mult)) return false;
    if (out.ship_config_glide_duration_mult < 0) return false;
    if (!input.read_f64(out.ship_config_invulnerability)) return false;
    if (out.ship_config_invulnerability < 0) return false;
    if (!input.read_f64(out.draw_config_min_charge)) return false;
    if (out.draw_config_min_charge < 0) return false;
    if (!input.read_f64(out.draw_config_length)) return false;
    if (out.draw_config_length < 0) return false;
    if (!input.read_f64(out.draw_config_point_step)) return false;
    if (out.draw_config_point_step < 0) return false;
    if (!input.read_f64(out.draw_config_confirm_delay)) return false;
    if (out.draw_config_confirm_delay < 0) return false;
    if (!input.read_f64(out.draw_config_run_time)) return false;
    if (out.draw_config_run_time < 0) return false;
    if (!input.read_f64(out.draw_config_time_scale)) return false;
    if (out.draw_config_time_scale < 0) return false;
    if (!input.read_f64(out.draw_config_slow_ref)) return false;
    if (out.draw_config_slow_ref < 0) return false;
    if (!input.read_f64(out.draw_config_scale_min)) return false;
    if (out.draw_config_scale_min < 0) return false;
    if (!input.read_f64(out.draw_config_boost_duration)) return false;
    if (out.draw_config_boost_duration < 0) return false;
    if (!input.read_f64(out.draw_config_carry)) return false;
    if (out.draw_config_carry < 0) return false;
    if (!input.read_f64(out.draw_config_launch_ratio)) return false;
    if (out.draw_config_launch_ratio < 0) return false;
    if (!input.read_f64(out.draw_config_glide_ratio)) return false;
    if (out.draw_config_glide_ratio < 0) return false;
    if (!input.read_f64(out.draw_config_capacity)) return false;
    if (out.draw_config_capacity < 0) return false;
    if (!input.read_f64(out.draw_config_charge_time)) return false;
    if (out.draw_config_charge_time < 0) return false;
    if (!input.read_f64(out.draw_config_length_mult)) return false;
    if (out.draw_config_length_mult < 0) return false;
    if (!input.read_f64(out.camera_base_view)) return false;
    if (out.camera_base_view < 0) return false;
    if (!input.read_f64(out.camera_zoom_ref_speed)) return false;
    if (out.camera_zoom_ref_speed < 0) return false;
    if (!input.read_f64(out.camera_zoom_exp)) return false;
    if (out.camera_zoom_exp < 0) return false;
    if (!input.read_f64(out.camera_zoom_min)) return false;
    if (out.camera_zoom_min < 0) return false;
    if (!input.read_f64(out.camera_look_ahead)) return false;
    if (out.camera_look_ahead < 0) return false;
    if (!input.read_u32(out.world_tick_div)) return false;
    if (out.world_tick_div < 1) return false;
    if (!input.read_f64(out.grid_cell)) return false;
    if (out.grid_cell < 0) return false;
    if (!input.read_f64(out.time_limit)) return false;
    if (!input.read_f64(out.combat_base_attack)) return false;
    if (out.combat_base_attack < 0) return false;
    if (!input.read_f64(out.combat_atk_scale)) return false;
    if (out.combat_atk_scale < 0) return false;
    if (!input.read_f64(out.combat_ram_speed_ratio)) return false;
    if (out.combat_ram_speed_ratio < 0) return false;
    if (!input.read_f64(out.combat_crit_armor)) return false;
    if (out.combat_crit_armor < 0) return false;
    if (!input.read_f64(out.combat_touch_damage)) return false;
    if (out.combat_touch_damage < 0) return false;
    if (!input.read_f64(out.combat_contact_cooldown)) return false;
    if (out.combat_contact_cooldown < 0) return false;
    if (!input.read_f64(out.combat_bounce_keep)) return false;
    if (out.combat_bounce_keep < 0) return false;
    if (!input.read_f64(out.combat_bounce_min_speed)) return false;
    if (out.combat_bounce_min_speed < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop)) return false;
    if (out.combat_kill_hitstop < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop_cap)) return false;
    if (out.combat_kill_hitstop_cap < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop_regen)) return false;
    if (out.combat_kill_hitstop_regen < 0) return false;
    if (!input.read_f64(out.combat_hitstop_big_mult)) return false;
    if (out.combat_hitstop_big_mult < 0) return false;
    if (!input.read_f64(out.combat_hitstop_crit_mult)) return false;
    if (out.combat_hitstop_crit_mult < 0) return false;
    if (!input.read_f64(out.combat_max_enemy_radius)) return false;
    if (out.combat_max_enemy_radius < 0) return false;
    if (!input.read_f64(out.combat_attack_mult)) return false;
    if (out.combat_attack_mult < 0) return false;
    if (!input.read_f64(out.combat_crit_chance)) return false;
    if (out.combat_crit_chance < 0) return false;
    if (!input.read_f64(out.combat_crit_mult)) return false;
    if (out.combat_crit_mult < 0) return false;
    if (!input.read_bool(out.combat_ready)) return false;
    if (!input.read_bool(out.pickups_ready)) return false;
    if (!input.read_i64(out.gem_max)) return false;
    if (out.gem_max < 1) return false;
    if (!input.read_f64(out.strong_gold_chance)) return false;
    if (out.strong_gold_chance < 0) return false;
    if (!input.read_f64(out.coin_radius)) return false;
    if (out.coin_radius < 0) return false;
    if (!input.read_f64(out.pickup_xp_mult)) return false;
    if (out.pickup_xp_mult < 0) return false;
    if (!input.read_f64(out.pickup_speed_mult)) return false;
    if (out.pickup_speed_mult < 0) return false;
    if (!input.read_f64(out.pickup_xp_radius)) return false;
    if (out.pickup_xp_radius < 0) return false;
    if (!input.read_bool(out.fixed_rewards)) return false;
    if (!input.read_f64(out.character_scale)) return false;
    if (out.character_scale < 0) return false;
    if (!input.read_bool(out.projectiles_ready)) return false;
    if (!input.read_f64(out.debris_life)) return false;
    if (out.debris_life < 0) return false;
    if (!input.read_f64(out.debris_knock)) return false;
    if (out.debris_knock < 0) return false;
    if (!input.read_i64(out.trail_points)) return false;
    if (out.trail_points < 0) return false;
    if (!input.read_u32(out.ship_visual)) return false;
    if (!input.read_u32(out.shot_visual)) return false;
    if (!input.read_u32(out.crystal_visual)) return false;
    if (!input.read_u32(out.coin_visual)) return false;
    if (!input.read_u32(out.cannon_visual)) return false;
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
    uint32_t visual_id{};
    double sprite_scale{};
    double sprite_angle{};
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
    if (!input.read_u32(out.visual_id)) return false;
    if (!input.read_f64(out.sprite_scale)) return false;
    if (out.sprite_scale < 0) return false;
    if (!input.read_f64(out.sprite_angle)) return false;
    return true;
}
struct LoadoutDefinition {
    uint32_t id{};
    uint32_t kind{};
    uint32_t maximum_level{};
};
inline bool read(BinaryReader &input, LoadoutDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 0) return false;
    if (!input.read_u32(out.maximum_level)) return false;
    if (out.maximum_level < 1) return false;
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
    uint32_t role{};
    std::string path{};
};
inline bool read(BinaryReader &input, ResourceKey &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.role)) return false;
    if (out.role > 5) return false;
    if (!input.read_string(out.path)) return false;
    return true;
}
struct ForwardDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double interval{};
    double damage{};
    double life{};
    double spread{};
    double knock{};
    uint32_t pierce{};
};
inline bool read(BinaryReader &input, ForwardDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_u32(out.pierce)) return false;
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
    std::vector<ForwardDefinition> ForwardDefinition_rows;
};
inline bool read_section(uint32_t kind, uint32_t version, uint32_t count, BinaryReader &input, ContentRecords &out) {
    switch(kind) {
    case 1: {
        if (version != 6) return false;
        if (count > input.remaining()/640) return false;
        for (uint32_t i=0; i<count; ++i) { RunConfig row; if (!read(input,row)) return false; out.RunConfig_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 2: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { StringEntry row; if (!read(input,row)) return false; out.StringEntry_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 3: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { DefinitionIndex row; if (!read(input,row)) return false; out.DefinitionIndex_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 4: {
        if (version != 3) return false;
        if (count > input.remaining()/224) return false;
        for (uint32_t i=0; i<count; ++i) { ChaseDefinition row; if (!read(input,row)) return false; out.ChaseDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 5: {
        if (version != 2) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { LoadoutDefinition row; if (!read(input,row)) return false; out.LoadoutDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 6: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { HeroDefinition row; if (!read(input,row)) return false; out.HeroDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 7: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { FieldDefinition row; if (!read(input,row)) return false; out.FieldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 8: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationDefinition row; if (!read(input,row)) return false; out.PopulationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 9: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { FormationDefinition row; if (!read(input,row)) return false; out.FormationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 10: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowDefinition row; if (!read(input,row)) return false; out.BossFlowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 11: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { TechniqueDefinition row; if (!read(input,row)) return false; out.TechniqueDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 12: {
        if (version != 2) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { ResourceKey row; if (!read(input,row)) return false; out.ResourceKey_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 13: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { ForwardDefinition row; if (!read(input,row)) return false; out.ForwardDefinition_rows.push_back(std::move(row)); }
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
    std::unordered_set<uint32_t> ForwardDefinition_ids;
    for (const auto &row:data.ForwardDefinition_rows) if (!ForwardDefinition_ids.insert(row.id).second) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.ship_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.shot_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.crystal_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.coin_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.cannon_visual)) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!StringEntry_ids.count(row.id)) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!ChaseDefinition_ids.count(row.enemy)) return false;
    for (const auto &row:data.ChaseDefinition_rows) if (!StringEntry_ids.count(row.id)) return false;
    for (const auto &row:data.ChaseDefinition_rows) if (!ResourceKey_ids.count(row.visual_id)) return false;
    for (const auto &row:data.ForwardDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    return true;
}
inline void apply_config(const RunConfig &config, godot::RunState &state) {
    state.ship_config.start_radius=config.ship_config_start_radius;
    state.ship_config.base_max_speed=config.ship_config_base_max_speed;
    state.ship_config.stick_dead_zone=config.ship_config_stick_dead_zone;
    state.ship_config.mouse_dead_zone=config.ship_config_mouse_dead_zone;
    state.ship_config.steer_cruise=config.ship_config_steer_cruise;
    state.ship_config.glide_hold=config.ship_config_glide_hold;
    state.ship_config.glide_fade=config.ship_config_glide_fade;
    state.ship_config.cruise_floor=config.ship_config_cruise_floor;
    state.ship_config.energy_cut=config.ship_config_energy_cut;
    state.ship_config.cruise_drag=config.ship_config_cruise_drag;
    state.ship_config.overcap_decay=config.ship_config_overcap_decay;
    state.ship_config.field_radius=config.ship_config_field_radius;
    state.ship_config.boundary_push=config.ship_config_boundary_push;
    state.ship_config.ship_radius=config.ship_config_ship_radius;
    state.ship_config.crash_restitution=config.ship_config_crash_restitution;
    state.ship_config.ship_hurt_time=config.ship_config_ship_hurt_time;
    state.ship_config.max_hp=config.ship_config_max_hp;
    state.ship_config.max_speed=config.ship_config_max_speed;
    state.ship_config.turn_rate=config.ship_config_turn_rate;
    state.ship_config.acceleration=config.ship_config_acceleration;
    state.ship_config.glide_duration_mult=config.ship_config_glide_duration_mult;
    state.ship_config.invulnerability=config.ship_config_invulnerability;
    state.draw_config.min_charge=config.draw_config_min_charge;
    state.draw_config.length=config.draw_config_length;
    state.draw_config.point_step=config.draw_config_point_step;
    state.draw_config.confirm_delay=config.draw_config_confirm_delay;
    state.draw_config.run_time=config.draw_config_run_time;
    state.draw_config.time_scale=config.draw_config_time_scale;
    state.draw_config.slow_ref=config.draw_config_slow_ref;
    state.draw_config.scale_min=config.draw_config_scale_min;
    state.draw_config.boost_duration=config.draw_config_boost_duration;
    state.draw_config.carry=config.draw_config_carry;
    state.draw_config.launch_ratio=config.draw_config_launch_ratio;
    state.draw_config.glide_ratio=config.draw_config_glide_ratio;
    state.draw_config.capacity=config.draw_config_capacity;
    state.draw_config.charge_time=config.draw_config_charge_time;
    state.draw_config.length_mult=config.draw_config_length_mult;
    state.control.base_view=config.camera_base_view;
    state.control.zoom_ref_speed=config.camera_zoom_ref_speed;
    state.control.zoom_exp=config.camera_zoom_exp;
    state.control.zoom_min=config.camera_zoom_min;
    state.control.look_ahead=config.camera_look_ahead;
    state.control.world_tick_div=config.world_tick_div;
    state.frame_grid_cell=config.grid_cell;
    state.control.time_limit=config.time_limit;
    state.combat_config.base_attack=config.combat_base_attack;
    state.combat_config.atk_scale=config.combat_atk_scale;
    state.combat_config.ram_speed_ratio=config.combat_ram_speed_ratio;
    state.combat_config.crit_armor=config.combat_crit_armor;
    state.combat_config.touch_damage=config.combat_touch_damage;
    state.combat_config.contact_cooldown=config.combat_contact_cooldown;
    state.combat_config.bounce_keep=config.combat_bounce_keep;
    state.combat_config.bounce_min_speed=config.combat_bounce_min_speed;
    state.combat_config.kill_hitstop=config.combat_kill_hitstop;
    state.combat_config.kill_hitstop_cap=config.combat_kill_hitstop_cap;
    state.combat_config.kill_hitstop_regen=config.combat_kill_hitstop_regen;
    state.combat_config.hitstop_big_mult=config.combat_hitstop_big_mult;
    state.combat_config.hitstop_crit_mult=config.combat_hitstop_crit_mult;
    state.combat_config.max_enemy_radius=config.combat_max_enemy_radius;
    state.combat_config.attack_mult=config.combat_attack_mult;
    state.combat_config.crit_chance=config.combat_crit_chance;
    state.combat_config.crit_mult=config.combat_crit_mult;
    state.combat_ready=config.combat_ready;
    state.pickups_ready=config.pickups_ready;
    state.pickup_config.gem_max=config.gem_max;
    state.pickup_config.strong_gold_chance=config.strong_gold_chance;
    state.pickup_config.coin_radius=config.coin_radius;
    state.pickup_config.xp_mult=config.pickup_xp_mult;
    state.pickup_config.speed_mult=config.pickup_speed_mult;
    state.pickup_config.xp_radius=config.pickup_xp_radius;
    state.pickup_config.fixed_rewards=config.fixed_rewards;
    state.projectile_config.ready=config.projectiles_ready;
    state.projectile_config.debris_life=config.debris_life;
    state.projectile_config.debris_knock=config.debris_knock;
    state.projectile_config.trail_points=config.trail_points;
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
    out.visual_id=row.visual_id;
    out.sprite_scale=row.sprite_scale;
    out.sprite_angle=row.sprite_angle;
    return out;
}
inline constexpr uint32_t FORMAT_VERSION=1, ABI_VERSION=1, SECTION_COUNT=13;
}
