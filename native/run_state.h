#pragma once
#include "runtime_data.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
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
struct SpeedRunState {
    Ref<RandomNumberGenerator> rng;
    std::vector<speed::EnemyDefinition> definitions;
    enum class EnemyMode { Move, Windup, Dash, Recover };
    struct Enemy {
        int64_t id = 0;
        int64_t attack_group = 0;
        double attack_value = 1, attack_priority = 0;
        bool attack_managed = false;
        size_t definition = 0, behavior_group = 0, behavior_slot = 0;
        Vector2 pos, vel;
        double hp = 0.0, max_hp = 0.0, radius = 0.0, armor = 0.0, xp = 0.0, speed = 0.0;
        double facing = 0.0, age = 0.0, fire_t = 0.0;
        EnemyMode mode = EnemyMode::Move;
        double timer = 0, charge = 0;
        bool alive = false, dead = false, elite = false;
        double hit_cd = 0, flash = 0;
        double stone = 0, knock_t = 0, shove_time = 0;
        Vector2 shove_vel, shove_from;
        bool held = false, slash_hold = false, shoved = false;
        int64_t pack = 0;
        bool in_pack = false, pursuit_ready = false, follow_ready = false;
        Vector2 pursuit, follow_goal;
        double follow_until = 0, follow_scale = 1;
        int64_t dash_seen = -1;
        bool dash_fresh = false;
    };
    std::vector<Enemy> enemies;
    std::vector<int64_t> avoidance_ids;
    std::vector<Vector2> avoidance_from;
    HashMap<int64_t, std::vector<size_t>> hound_packs;
    bool attack_formation_mode = false;
    struct AttackBudget {
        struct Member { size_t row = 0; double until = 0; bool begun = false, closed = false; };
        struct Group {
            StringName owner, type;
            int64_t id = 0; size_t row = 0;
            double cost = 1, until = 0, start = 0;
            bool passive = false;
            Vector2 pos;
            PackedStringArray categories;
            HashMap<int64_t, Member> members;
            std::unordered_set<std::string> external;
        };
        struct Waiting {
            int64_t id = 0; size_t row = 0;
            double since = 0, priority = 0, cost = 1, ready = 0;
            bool has_ready = false;
            PackedStringArray categories;
        };
        // HashMapの列挙は登録順。優先度が同点の待機と加算順を保持する。
        HashMap<int64_t, Group> groups;
        HashMap<StringName, int64_t> owners;
        HashMap<StringName, Waiting> waiting;
        bool enabled = false, guard = false, frame_enabled = false, stage_budget = false;
        double budget = 4, jitter = 0.3, now = 0, guard_until = -1;
        int64_t serial = 0;
    } attack_budget;
    struct Formation {
        struct Marker { StringName type; Vector2 offset; double rotation = 0; };
        struct Entry { double weight = 0; Vector2 pos; };
        struct Layout { double weight = 0, value = -1; Variant managed; std::vector<StringName> types; std::vector<std::vector<Marker>> placements; };
        std::vector<Entry> entries;
        std::vector<Layout> layouts;
    };
    std::vector<Formation> formations;
    double formation_base_view = 1;
    struct Clip {
        struct Group { std::vector<std::pair<size_t,int64_t>> members; bool arrived = false; };
        double start = 0, end = 0, interval = 0, priority = 0, next = -1e9;
        int64_t maximum = 0;
        PackedStringArray types;
        std::vector<size_t> formations;
        std::vector<Group> groups;
    };
    std::vector<Clip> clips;
    bool clips_ready = false;
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
    } progression;
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
    struct PickupConfig {
        int64_t gem_max = 0;
        double drop_base = 0, drop_max = 0, drop_power = 0, shift_time = 0, xp_bonus = 1, xp_mult = 1;
        double xp_radius = 0, coin_radius = 0, speed_mult = 1;
        std::vector<double> xp, start_weights, end_weights;
    } pickup_config;
    struct Gem { Vector2 pos; double value = 0; int64_t seq = 0; bool alive = false, pulled = false; };
    struct Coin { Vector2 pos; bool alive = true, pulled = false; };
    std::vector<Gem> gems;
    std::vector<Coin> coins;
    std::vector<size_t> free_gems, free_coins;
    Array collections;
    std::vector<std::pair<size_t, int64_t>> gem_queue;
    size_t gem_queue_head = 0;
    int64_t next_gem_seq = 0, live_gems = 0;
    double xp_dropped = 0;
    bool pickups_ready = false;
    struct Friendly {
        bool alive = true, pierce = false, no_crit = false;
        int64_t kind = 0, generation = 0, pierce_left = 0;
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
        bool alive = true;
        int64_t kind = 0, attack_token = 0;
        Vector2 pos, vel;
        float speed = 0, radius = 0, life = 0, slow = 0, turn = 0, gap = 0, stone = 0, wait = 0;
        double damage = 0;
    };
    struct BiteZone {
        Vector2 pos;
        float radius = 0, time = 0, delay = 0;
        double damage = 0;
        Color color;
        int64_t attack_token = 0;
        bool alive = true, hit = false;
    };
    std::vector<BiteZone> bite_zones;
    std::vector<size_t> free_bite_zones;
    struct BiteZoneConfig {
        bool ready = false, hit = false, fade = false;
        float duration = 0;
        String scene;
    } bite_zone_config;
    std::deque<Hostile> hostiles;
    std::vector<size_t> free_hostiles;
    struct ForwardWeapon {
        bool ready = false;
        double elapsed = 0, recoil = 0;
        double interval = 0, damage = 0, life = 0, spread = 0, knock = 0, character_scale = 0;
        int64_t pierce = 0;
    } forward;
    Dictionary forward_parameters;
    bool motion_ready = false;
    bool started = false;
    bool closed = false;
    double time = 0.0, world_time = 0.0, sim_time = 0.0, world_accum = 0.0;
    double frame_grid_cell = 160, trace_radius = 0;
    int64_t world_div = 1, world_steps = 0;
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
    bool lifecycle_ready = false;
    double sequence_t = 0, death_freeze = 0, death_explosion = 0, death_game_over = 0;
    bool controls_locked = false, encounter_protected = false, steering_locked = false;
    bool invincible = false, hitstop_enabled = true;
    int64_t ticks = 0;
};
}
