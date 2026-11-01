#include "pickup_system.h"
#include "../runtime/run_runtime.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void drop_gem(RunRuntime &run,godot::Vector2 position,double value) {
    if (run.state.live_gems > run.state.pickup_config.gem_max) {
        while (run.state.gem_queue_head < run.state.gem_queue.size()) {
            const auto entry = run.state.gem_queue[run.state.gem_queue_head++];
            auto &old = run.state.gems[entry.first];
            if (old.alive && old.seq == entry.second) {
                value += old.value;
                old.alive = false;
                run.state.free_gems.push_back(entry.first);
                --run.state.live_gems;
                break;
            }
        }
        if (run.state.gem_queue_head >= 1024 && run.state.gem_queue_head * 2 >= run.state.gem_queue.size()) {
            run.state.gem_queue.erase(run.state.gem_queue.begin(), run.state.gem_queue.begin() + run.state.gem_queue_head);
            run.state.gem_queue_head = 0;
        }
    }
    const double angle = run.state.control.rng.randf() * (2.0 * godot::Math::PI);
    const godot::Vector2 at = position + godot::Vector2::from_angle(angle) * 8.0;
    size_t row = run.state.gems.size();
    if (run.state.free_gems.empty()) run.state.gems.emplace_back();
    else { row = run.state.free_gems.back(); run.state.free_gems.pop_back(); }
    run.state.gems[row] = {at, value, run.state.next_gem_seq, true, false};
    run.state.gem_queue.push_back({row, run.state.next_gem_seq++});
    ++run.state.live_gems;
}

void drop_legacy(RunRuntime &run,const Corpse &enemy) {
    const auto &c = run.state.pickup_config;
    const double value = enemy.xp * c.xp_mult * (c.xp_bonus > 0 ? c.xp_bonus : 1.0);
    run.state.xp_dropped += value;
    drop_gem(run,enemy.pos, value);
    const int64_t coin_count = enemy.elite ? 3 + run.state.control.rng.randi_range(0, 3).value() : (run.state.control.rng.randf() < 0.03 ? 1 : 0);
    for (int64_t k = 0; k < coin_count; ++k) {
        const double angle = run.state.control.rng.randf() * (2.0 * godot::Math::PI);
        const double share = run.state.control.rng.randf();
        const godot::RunState::Coin coin{enemy.pos + godot::Vector2::from_angle(angle) * share * enemy.radius, true, false};
        if (run.state.free_coins.empty()) run.state.coins.push_back(coin);
        else { run.state.coins[run.state.free_coins.back()] = coin; run.state.free_coins.pop_back(); }
    }
    if (run.state.control.rng.randf() < std::min(c.drop_max, c.drop_base * std::pow(enemy.xp, c.drop_power))) {
        const double fraction = std::clamp(run.state.time / c.shift_time, 0.0, 1.0);
        std::vector<float> weights;
        double total = 0;
        for (size_t k = 0; k < c.xp.size(); ++k) {
            const double weight = godot::Math::lerp(c.start_weights[k], c.end_weights[k], fraction);
            weights.push_back(weight); total += weight;
        }
        double roll = run.state.control.rng.randf() * total;
        size_t tier = weights.size() - 1;
        for (size_t k = 0; k < weights.size(); ++k) { roll -= weights[k]; if (roll < 0) { tier = k; break; } }
        run.state.xp_dropped += c.xp[tier];
        drop_gem(run,enemy.pos, c.xp[tier]);
    }
}

void drop_crystal(RunRuntime &run,godot::Vector2 pos,uint8_t kind) {
    auto &state=run.state;
    const double value=run.content->crystal_values[kind];state.xp_dropped+=value;
    // 満杯では新しい位置も乱数も作らず、最古の大結晶（なければ最古の結晶）へ加算する。
    if (state.live_gems>=state.pickup_config.gem_max && state.live_gems>0) {
        int64_t target=state.gem_absorber;
        if (target<0 || size_t(target)>=state.gems.size() || !state.gems[target].alive || state.gems[target].seq!=state.gem_absorber_seq) {
            int64_t oldest=-1,high=-1;
            for (size_t i=0;i<state.gems.size();++i) if (state.gems[i].alive) {
                if (oldest<0 || state.gems[i].seq<state.gems[oldest].seq) oldest=int64_t(i);
                if (state.gems[i].kind==2 && (high<0 || state.gems[i].seq<state.gems[high].seq)) high=int64_t(i);
            }
            target=high>=0?high:oldest;
            state.gems[target].kind=2;state.gem_absorber=target;state.gem_absorber_seq=state.gems[target].seq;
        }
        state.gems[target].value+=value;return;
    }
    const auto at=pos+godot::Vector2::from_angle(state.control.rng.randf()*2.0*godot::Math::PI)*8.0;
    size_t row=state.gems.size();
    if (state.free_gems.empty()) state.gems.emplace_back();else {row=state.free_gems.back();state.free_gems.pop_back();}
    state.gems[row]={at,value,state.next_gem_seq++,true,false,kind};++state.live_gems;
}
}
void PickupSystem::drop_enemy(RunRuntime &run,const Corpse &enemy) {
    auto &state=run.state;const auto &definition=run.content->definitions[enemy.definition-1];
    if (enemy.is_boss) return;
    if (!state.pickup_config.fixed_rewards) {drop_legacy(run,enemy);return;}
    for (uint8_t kind=0;kind<3;++kind) for (uint32_t i=0;i<definition.xp_rewards[kind];++i) drop_crystal(run,enemy.pos,kind);
    if (definition.gold_eligible && state.control.rng.randf()<state.pickup_config.strong_gold_chance) drop_crystal(run,enemy.pos,2);
    const bool meteor=definition.kind==EnemyDefinition::Kind::Meteor && !run.content->rock_fields.empty();
    const double chance=meteor?run.content->rock_fields.front().meteor_coin_chance:0.03;
    const int64_t count=enemy.elite?3+state.control.rng.randi_range(0,3).value():(state.control.rng.randf()<chance?(meteor?1+state.control.rng.randi_range(0,2).value():1):0);
    for (int64_t i=0;i<count;++i) {
        const double angle=state.control.rng.randf()*2.0*godot::Math::PI,share=state.control.rng.randf();
        const godot::RunState::Coin coin{enemy.pos+godot::Vector2::from_angle(angle)*share*enemy.radius,true,false};
        if (state.free_coins.empty()) state.coins.push_back(coin);else {state.coins[state.free_coins.back()]=coin;state.free_coins.pop_back();}
    }
    if (meteor) {
        const auto &config=run.content->rock_fields.front();
        if (state.control.rng.randf()<config.meteor_heal_chance) state.capsules.push_back({enemy.pos,0,godot::RunState::CapsuleKind::Heal});
        if (state.control.rng.randf()<config.meteor_magnet_chance) state.capsules.push_back({enemy.pos,0,godot::RunState::CapsuleKind::Magnet});
    }
}
}
