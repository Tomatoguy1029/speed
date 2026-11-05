#pragma once
#include "../content/runtime_data.h"
#include "../content/population_data.h"
#include "entity_store.h"
#include "enemy_states.h"
#include "state_box.h"
#include "combat_types.h"
#include "attack_state.h"
#include "observation_state.h"
#include "recording_state.h"
#include "world_state.h"
#include "forward_weapon_state.h"
#include "pickup_state.h"
#include "group_state.h"
#include "lifecycle_state.h"
#include "field_state.h"
#include "hazard_state.h"
#include "previous_pose_state.h"
#include "../systems/timing.h"
#include "../systems/boss_contact.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include "run_control_state.h"
#include "hero_state.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <unordered_map>
#include <unordered_set>
#include <deque>
#include <array>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {
// ランの値状態。保持・複製は全フィールドをまとめてコピーする。
struct RunState {
    speed::HeroState heroes;
    speed::StateBox<speed::BossStates> bosses;
    std::vector<speed::BossLandingContact> boss_landings;
    bool boss_contact_interrupt_trace=false;
    speed::RunControlState control;
    speed::PreviousPoseState previous_poses;
    speed::AttackState attacks;
    speed::ObservationState observations;
    speed::RecordingState recording;
    using EnemyMode=speed::EnemyMode;
    using Enemy=speed::Enemy;
    std::deque<Enemy> enemies;
    std::vector<speed::PendingEnemySpawn> pending_enemies;
    speed::EntityStore<speed::EnemyTag> enemy_handles;
    speed::GroupState groups;
    std::vector<speed::CoronaMemberRef> corona_members;
    uint64_t corona_serial=0;
    using AttackBudget=speed::AttackBudgetState;
    speed::WorldState world;
    speed::FieldState field;
    using Formation=speed::PopulationFormation;
    std::vector<Formation> formations;
    double formation_base_view = 1;
    struct Clip : speed::PopulationClipData {
        struct Group { std::vector<std::pair<size_t,int64_t>> members; bool arrived = false; };
        double next = -1e9;
        std::vector<Group> groups;
    };
    std::vector<Clip> clips;
    bool clips_ready = false;
    struct Encounter {double next=0,start=0,window=0,margin=0;bool opportunity=false;std::vector<Vector2> route;} encounter;
    std::vector<speed::EnemyDefinition::Kind> behavior_kinds;
    std::vector<std::vector<size_t>> behavior_rows;
    std::vector<size_t> free_rows, dead_rows;
    std::unordered_map<int64_t, size_t> rows_by_id;
    struct EnemyGrid {
        Vector2 origin;
        double cell = 160, max_radius = 0;
        int64_t cols = 0, rows = 0;
        std::vector<int64_t> head, next, used;
    } grid;
    int64_t next_id = 1;
    Vector2 ship_pos, enemy_aim, view_center, view_half;
    double enemy_aim_lag = 0, enemy_aim_speed = 0;
    bool aim_ready = false;
    struct Ship {
        uint32_t shield_source_definition=0;
        Vector2 pos, vel, heading = Vector2(0, -1);
        double hp = 0, hurt = 0, invuln = 0, shield_flash = 0, shield_t = 0, shield_max = 0;
        double boost_t = 0, fade_t = 0, glide_t = 0, glide_speed = 0, peak_speed = 0;
        bool glide = false;
    } ship;
    struct ShipConfig {
        double start_radius, base_max_speed, stick_dead_zone, mouse_dead_zone, steer_cruise;
        double glide_hold, glide_fade, cruise_floor, energy_cut, cruise_drag, overcap_decay;
        double field_radius, boundary_push, ship_radius, crash_restitution, ship_hurt_time;
        double max_hp, max_speed, turn_rate, acceleration, glide_duration_mult, invulnerability;
    } ship_config{};
    struct DrawConfig {
        double min_charge, length, point_step, confirm_delay, run_time, time_scale, slow_ref, scale_min;
        double boost_duration, carry, launch_ratio, glide_ratio, capacity, charge_time, length_mult;
    } draw_config{};
    struct Draw {
        double gauge = 1, start_charge = 0, amount = 0, limit = 0, length = 0, before_speed = 0;
        double speed = 0, rate = 0, seg_pos = 0, total = 0, progress = 0;
        bool drawing = false, started = false, blocked = false, full_charge = false, tracing = false;
        int64_t first_msec = 0, dash_id = 0, segment = 0;
        std::unordered_map<int64_t, size_t> inside;
        std::unordered_map<int64_t, int64_t> passes;
        PackedVector2Array points, path;
        PackedFloat32Array lengths;
    } draw;
    struct Progression {
        bool ready = false, start_pick = false;
        Dictionary data, stats, weapons, traits;
        Array cards, resource_requests;
        HashMap<StringName, int> resource_status;
        int64_t level = 0, pending_levels = 0, rerolls = 0, revision = 0, pending_choice = -1;
        double xp = 0, gained = 0;
    } legacy_progression;
    speed::StateBox<speed::LoadoutState> loadout;
    bool draw_ready = false;
    bool ship_ready = false;
    struct CombatConfig {
        double base_attack, atk_scale, ram_speed_ratio, crit_armor, touch_damage, contact_cooldown;
        double bounce_keep, bounce_min_speed, kill_hitstop, kill_hitstop_cap, kill_hitstop_regen;
        double hitstop_big_mult, hitstop_crit_mult, max_enemy_radius, attack_mult, crit_chance, crit_mult;
    } combat_config{};
    bool combat_ready = false;
    double hitstop = 0, dash_stop = 0;
    int64_t kills = 0;
    Array events;
    std::vector<speed::CombatEvent> combat_events;
    bool boss_dead=false;
    struct PickupConfig {
        int64_t gem_max = 0;
        int64_t gem_draw_max = 0;
        bool fixed_rewards=false;
        double strong_gold_chance=0;
        double drop_base = 0, drop_max = 0, drop_power = 0, shift_time = 0, xp_bonus = 1, xp_mult = 1;
        double xp_radius = 0, coin_radius = 0, speed_mult = 1;
        double repair_fraction=0,pickup_life=0;
        std::vector<double> xp, start_weights, end_weights;
    } pickup_config;
    using Gem=speed::CrystalState;
    using Coin=speed::CoinState;
    using CapsuleKind=speed::CapsuleKind;
    using Capsule=speed::CapsuleState;
    speed::PickupState pickups;
    Array collections;
    bool pickups_ready = false;
    struct Friendly {
        speed::FriendDebrisState debris;
        speed::FriendHullState hull;
        uint32_t definition=0;
        bool alive = true, pierce = false, no_crit = false;
        int64_t kind = 0, pierce_left = 0, id = 0;
        speed::AttackHandle attack;
        struct HitCallback {speed::FriendHitKind kind=speed::FriendHitKind::None;double knock=160;bool no_crit=true;} callback;
        int32_t shatter_depth=0;
        Vector2 pos, vel;
        float radius = 5, life = 0.9f, age = 0, knock = 250, angle = 0, spin = 0;
        double damage = 0;
        StringName cause = "shot", weapon_id, visual, type;
        Color color;
        std::unordered_set<int64_t> hit_ids;
        PackedVector2Array trail;
    };
    // 命中中に後ろへ追加しても、処理中の弾への参照を保つ。
    std::deque<Friendly> friends;
    std::vector<size_t> free_friends;
    size_t live_friends = 0, live_debris = 0;
    struct ProjectileConfig {
        double debris_life = 0, debris_knock = 0;
        int64_t trail_points = 0;
        bool ready = false, split = false;
        double chance = 0, damage = 1, angle_min = 0, angle_max = 0;
        int64_t generations = 0, maximum = 0;
    } projectile_config;
    struct Hostile {
        speed::SlashState slash;
        speed::BoltState bolt;
        speed::StarBoltState star_bolt;
        speed::LightArrowState arrow;
        speed::ShellState shell;
        uint32_t definition=0;
        bool alive = true;
        int64_t kind = 0;
        speed::AttackHandle attack;
        Vector2 pos, vel;
        float speed = 0, radius = 0, life = 0, slow = 0, turn = 0, gap = 0, stone = 0, wait = 0;
        double damage = 0;
    };
    using Hazard=speed::HazardState;
    std::deque<Hazard> hazards;
    std::vector<size_t> free_hazards;
    struct BiteZoneConfig {
        uint32_t visual_key=0;
        bool ready = false, hit = false, fade = false;
        float duration = 0;
        String scene;
    } bite_zone_config;
    std::deque<Hostile> hostiles;
    std::vector<size_t> free_hostiles;
    using ForwardWeapon=speed::ForwardWeaponState;
    ForwardWeapon forward;
    Dictionary forward_parameters;
    bool motion_ready = false;
    bool started = false;
    bool closed = false;
    double time = 0.0, world_time = 0.0, sim_time = 0.0;
    double frame_grid_cell = 160, trace_radius = 0;
    bool frame_ready = false;
    enum class Phase { Play = 0, LevelUp = 1, Paused = 2, Dying = 3, Finishing = 4, Ended = 5 };
    Phase phase = Phase::Play;
    struct Population {
        bool ready = false, refill_ready = false;
        bool frame_enabled = false, bonus = false, blocked = false;
        double wave_time = 0;
        double accumulator = 0, total_cap = 0, refill_time = 0;
        StringName phase_id;
        double recycle_scale = 0, region_cap = 0, margin = 0, field_radius = 0, planet_radius = 0;
        std::vector<double> maximum, effective;
        std::vector<int64_t> type_counts, region_types;
        std::vector<size_t> far_rows;
        std::array<int64_t, 4> edges{};
        std::array<int64_t, 5> regions{};
        int64_t raw = 0;
    } population;
    speed::SpawnTimeline spawn_timeline;
    bool spawn_timeline_ready = false;
    speed::LifecycleState lifecycle;
    bool lifecycle_ready = false;
    double sequence_t = 0, death_freeze = 0, death_explosion = 0, death_game_over = 0;
    bool controls_locked = false, encounter_protected = false, steering_locked = false;
    bool invincible = false, hitstop_enabled = true;
    int64_t ticks = 0;
};
}
