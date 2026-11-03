#include "../api/run_core.h"
#include "progression.h"
#include "pickup_system.h"
#include "../behaviors/enemies/crow.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_pickups(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
    PickupConfig c;
    const char *keys[] = {"drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "xp_bonus", "xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"};
    double *values[] = {&c.drop_base, &c.drop_max, &c.drop_power, &c.shift_time, &c.xp_bonus, &c.xp_mult, &c.xp_radius, &c.coin_radius, &c.speed_mult};
    for (int i = 0; i < 9; ++i) {
        const Dictionary &source = i < 5 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *values[i] = double(value);
        if (!std::isfinite(*values[i]) || *values[i] < 0) return false;
    }
    if (c.shift_time <= 0 || !config.has("gem_max")) return false;
    const Variant maximum = config["gem_max"];
    if ((maximum.get_type() != Variant::INT && maximum.get_type() != Variant::FLOAT) ||
            !std::isfinite(double(maximum)) || double(maximum) < 0 || double(maximum) > INT32_MAX || std::floor(double(maximum)) != double(maximum)) return false;
    c.gem_max = int64_t(maximum);
    const char *arrays[] = {"big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end"};
    std::vector<double> *dest[] = {&c.xp, &c.start_weights, &c.end_weights};
    for (int i = 0; i < 3; ++i) {
        if (!config.has(arrays[i])) return false;
        const Variant input = config[arrays[i]];
        if (input.get_type() != Variant::ARRAY && input.get_type() != Variant::PACKED_FLOAT32_ARRAY) return false;
        const Array values = input;
        if (values.is_empty()) return false;
        for (int64_t k = 0; k < values.size(); ++k) {
            const Variant v = values[k];
            if ((v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) || !std::isfinite(double(v)) || double(v) < 0) return false;
            dest[i]->push_back(double(v));
        }
    }
    if (c.xp.size() != c.start_weights.size() || c.xp.size() != c.end_weights.size()) return false;
    runtime.state.pickup_config = std::move(c); runtime.state.pickups_ready = true;
    return true;
}

Dictionary SpeedRunCore::pickups_snapshot() const {
    Array visible_gems, visible_coins;
    const auto crystal_record=[&](const speed::CrystalState &gem) {
        Dictionary row; row["pos"] = gem.pos; row["value"] = gem.value; row["seq"] = gem.order; row["pulled"] = gem.pulled;
        if (runtime.state.pickup_config.fixed_rewards) {
            row["ground_order"]=int64_t(gem.order);row["id"]=int64_t(gem.id);row["kind"]=int(gem.kind);row["base_xp"]=gem.value;row["velocity"]=gem.velocity;row["wait"]=gem.wait;
            Dictionary origin;origin["source"]=gem.origin.source==speed::CrystalSource::Enemy?"enemy":gem.origin.source==speed::CrystalSource::StrongGold?"strong_gold":"direct";
            origin["enemy"]=gem.origin.definition?runtime.content->definitions[gem.origin.definition-1].source_id():StringName();origin["enemy_id"]=gem.origin.enemy_id;
            origin["spawn_t"]=gem.origin.run_time;origin["spawn_world_t"]=gem.origin.world_time;row["origin"]=origin;
        }
        return row;
    };
    for (const auto &gem:runtime.state.pickups.gems) if (gem.alive) visible_gems.append(crystal_record(gem));
    for (const auto &coin : runtime.state.pickups.coins) if (coin.alive) {
        Dictionary row; row["pos"] = coin.pos; row["pulled"] = coin.pulled; visible_coins.append(row);
    }
    Array capsules;for (const auto &capsule:runtime.state.pickups.capsules) {Dictionary row;row["kind"]=int(capsule.kind);row["pos"]=capsule.pos;row["age"]=capsule.age;row["weapon"]=capsule.weapon;row["drop"]=capsule.drop;capsules.push_back(row);}
    Array pending;for (auto weapon:runtime.state.loadout.pending_comet_weapons) pending.push_back(String::utf8(runtime.content->equipment[weapon-1].external_id.c_str()));
    Dictionary out;out["pending_comet_weapons"]=pending;out["capsules"]=capsules;out["gems"] = visible_gems; out["coins"] = visible_coins; out["xp_dropped"] = runtime.state.pickups.xp_dropped;
    if (runtime.state.pickup_config.fixed_rewards) {
        const auto totals=[](const std::array<speed::CrystalTotal,3> &source) {
            Array values;for (const auto &total:source) {Dictionary value;value["count"]=int64_t(total.count);value["base_xp"]=total.base_xp;value["actual_xp"]=total.actual_xp;values.push_back(value);}return values;
        };
        Array cargo;std::array<speed::CrystalTotal,3> ground_totals{},carried_totals{};
        for (const auto &gem:runtime.state.pickups.gems) if (gem.alive) {++ground_totals[gem.kind].count;ground_totals[gem.kind].base_xp+=gem.value;}
        for (const auto &entry:runtime.state.pickups.cargo) {
            Dictionary carrier;carrier["enemy_id"]=entry.enemy_id;Array crystals;
            for (const auto &gem:entry.crystals) {crystals.push_back(crystal_record(gem));++carried_totals[gem.kind].count;carried_totals[gem.kind].base_xp+=gem.value;}
            carrier["crystals"]=crystals;cargo.push_back(carrier);
        }
        out["cargo"]=cargo;
        Dictionary stats;stats["ground"]=totals(ground_totals);stats["carried"]=totals(carried_totals);stats["supplied"]=totals(runtime.state.pickups.supplied);stats["collected"]=totals(runtime.state.pickups.collected);stats["lost"]=totals(runtime.state.pickups.lost);
        stats["collected_actual_xp"]=runtime.state.pickups.collected_actual_xp;stats["gold_rolls"]=int64_t(runtime.state.pickups.gold_rolls);stats["gold_won"]=int64_t(runtime.state.pickups.gold_won);out["xp_statistics"]=stats;
        out["absorber_id"]=int64_t(runtime.state.pickups.gem_absorber_id);out["next_ground_order"]=int64_t(runtime.state.pickups.next_ground_order);

    }
    return out;
}

void SpeedRunCore::collect_pickup(StringName kind, double value) {
    // 共通回収は倍率を一度適用して最終XPを渡す。旧比較入口は撤去まで分ける。
    if (runtime.state.loadout.ready && kind == StringName("gem")) speed::ProgressionSystem::add_experience(*this,value*runtime.state.pickup_config.xp_mult*runtime.state.loadout.xp_gain_mult);
    else if (runtime.state.legacy_progression.ready && kind == StringName("gem")) add_xp(value);
    else { Dictionary item; item["kind"] = kind; item["value"] = value; runtime.state.collections.append(item); }
    if (runtime.api_configured && kind==StringName("coin")) ++runtime.state.lifecycle.coins;
    Dictionary event; event["kind"] = kind; emit_event("pickup", event);
}

Array SpeedRunCore::drain_collections() { Array out = runtime.state.collections; runtime.state.collections = Array(); return out; }

bool SpeedRunCore::step_pickups(double world_dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.pickups_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    speed::PickupSystem::prune(runtime);
    if (world_dt == 0) return true;
    const double reach = runtime.state.ship_config.ship_radius + 14.0;
    const double gem_radius = runtime.state.pickup_config.xp_radius;
    const double step = (700.0 + runtime.state.ship.vel.length() * 1.2) * runtime.state.pickup_config.speed_mult * world_dt;
    const double far = std::max(gem_radius, reach), far_sq = far * far;
    auto &pickups=runtime.state.pickups;
    const std::vector<size_t> moving(pickups.moving_gems.begin(),pickups.moving_gems.end());
    for (auto row:moving) {
        auto &gem=pickups.gems[row];
        if (gem.wait<=0) continue;
        const auto next=gem.pos+gem.velocity*world_dt;
        gem.velocity*=std::exp(-world_dt*5.0);gem.wait=speed::remaining_time(gem.wait,world_dt);
        pickups.move_gem(row,next);
    }
    speed::CrowBehavior::gather(runtime,world_dt);
    auto candidates=pickups.query_gems(Rect2(runtime.state.ship.pos-Vector2(far,far),Vector2(far*2,far*2)));
    candidates.insert(candidates.end(),pickups.moving_gems.begin(),pickups.moving_gems.end());
    std::sort(candidates.begin(),candidates.end());candidates.erase(std::unique(candidates.begin(),candidates.end()),candidates.end());
    std::vector<size_t> collected;
    for (size_t row:candidates) {
        auto &gem=pickups.gems[row];
        if (!gem.alive || gem.wait>0) continue;
        if (!gem.pulled && runtime.state.ship.pos.distance_squared_to(gem.pos)>=far_sq) continue;
        const Vector2 p=gem.pos,d=runtime.state.ship.pos-p;
        const double distance=d.length();
        if (distance<gem_radius || gem.pulled) {
            gem.pulled=true;
            pickups.move_gem(row,p+d/std::max(distance,1.0)*std::min(step,distance));
        }
        if (distance<reach) {
            if (runtime.state.pickup_config.fixed_rewards) collected.push_back(row);
            else {collect_pickup("gem",gem.value);speed::PickupSystem::release_crystal(runtime,row,speed::CrystalRemoval::Collected);}
        }
    }
    if (!collected.empty()) speed::PickupSystem::collect_rows(*this,collected,speed::CrystalCollectMethod::Ship);
    const double coin_radius = runtime.state.pickup_config.coin_radius * 1.3;
    const double coin_step = (700.0 + runtime.state.ship.vel.length() * 1.2) * world_dt;
    const double coin_far = std::max(coin_radius, reach), coin_far_sq = coin_far * coin_far;
    for (size_t row = 0; row < runtime.state.pickups.coins.size(); ++row) {
        auto &coin = runtime.state.pickups.coins[row];
        if (!coin.alive) continue;
        if (!coin.pulled && runtime.state.ship.pos.distance_squared_to(coin.pos) >= coin_far_sq) continue;
        const Vector2 p = coin.pos, d = runtime.state.ship.pos - p;
        const double distance = d.length();
        if (distance < coin_radius || coin.pulled) {
            coin.pulled = true;
            coin.pos = p + d / std::max(distance, 1.0) * std::min(coin_step, distance);
        }
        if (distance < reach) {
            collect_pickup("coin");
            coin.alive = false;
            runtime.state.pickups.free_coins.push_back(row);
        }
    }
    speed::PickupSystem::step_capsules(*this,world_dt);
    return true;
}

PackedFloat32Array SpeedRunCore::pickup_buffer(StringName kind, double size, Color color, Rect2 view) const {
    PackedFloat32Array buffer;
    if (!runtime.state.started || runtime.state.closed || !runtime.state.pickups_ready || !std::isfinite(size) || size <= 0 || !view.position.is_finite() || !view.size.is_finite() || view.size.x < 0 || view.size.y < 0) return buffer;
    const bool is_gem = kind == StringName("gem");
    if (!is_gem && kind != StringName("coin")) return buffer;
    int64_t count = 0;
    const auto gem_rows=is_gem?runtime.state.pickups.query_gems(view):std::vector<size_t>{};
    if (is_gem) count=int64_t(gem_rows.size());
    else { for (const auto &coin : runtime.state.pickups.coins) if (coin.alive && view.has_point(coin.pos)) ++count; }
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    const auto append = [&](Vector2 pos, double radius) {
        out[index++] = radius; out[index++] = 0; out[index++] = 0; out[index++] = pos.x;
        out[index++] = 0; out[index++] = radius; out[index++] = 0; out[index++] = pos.y;
        out[index++] = color.r; out[index++] = color.g; out[index++] = color.b; out[index++] = color.a;
    };
    if (is_gem) {
        for (auto row:gem_rows) append(runtime.state.pickups.gems[row].pos,size);
    } else { for (const auto &coin : runtime.state.pickups.coins) if (coin.alive && view.has_point(coin.pos)) append(coin.pos, size); }
    return buffer;
}
