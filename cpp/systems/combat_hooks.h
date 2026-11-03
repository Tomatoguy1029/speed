#pragma once
#include "../state/combat_types.h"
#include "../content/runtime_data.h"
#include <map>
#include <vector>
namespace speed {
class RunRuntime;
class CombatHooks {
public:
    using DeathHook=void(*)(RunRuntime &,const DeathContext &);
    using CaptureHook=bool(*)(RunRuntime &,const DeathContext &);
    using DamageHook=void(*)(RunRuntime &,const DamageRequest &,const DamageResult &);
    using ShipHook=void(*)(RunRuntime &,const ShipDamageRequest &,const ShipDamageResult &);
    using BarrierHook=bool(*)(RunRuntime &,const ShipDamageRequest &,double);
    struct EnemyPolicy {
        bool (*allows)(const RunRuntime &,EnemyHandle,const DamageRequest &)=nullptr;
        double (*ram_damage)(const RunRuntime &,EnemyHandle,double)=nullptr;
        void (*body_damaged)(RunRuntime &,EnemyHandle)=nullptr;
        bool (*can_defeat)(RunRuntime &,EnemyHandle)=nullptr;
        DeathHook boss_defeated=nullptr;
        bool (*passes)(const RunRuntime &,EnemyHandle)=nullptr;
    };
    class Dispatch {
        CombatHooks &owner;
    public:
        explicit Dispatch(CombatHooks &hooks):owner(hooks) {++owner.dispatch_depth;}
        ~Dispatch() {--owner.dispatch_depth;}
        Dispatch(const Dispatch &)=delete;
    };
    CombatHooks();
    bool register_enemy(EnemyDefinition::Kind kind,EnemyPolicy policy);
    bool on_death_marked(DeathHook hook);
    bool on_capture(CaptureHook hook);
    bool on_shatter(DeathHook hook);
    bool on_enemy_death(DeathHook hook);
    bool on_trait_kill(DeathHook hook);
    bool on_weapon_kill(DeathHook hook);
    bool on_critical(DamageHook hook);
    bool on_damage_applied(DamageHook hook);
    bool on_hurt(ShipHook hook);
    bool on_barrier(BarrierHook hook);
    const EnemyPolicy &enemy_policy(EnemyDefinition::Kind kind) const;
    void death_marked(RunRuntime &,const DeathContext &) const;
    bool capture(RunRuntime &,const DeathContext &) const;
    void shatter(RunRuntime &,const DeathContext &) const;
    void enemy_death(RunRuntime &,const DeathContext &) const;
    void trait_kill(RunRuntime &,const DeathContext &) const;
    void weapon_kill(RunRuntime &,const DeathContext &) const;
    void critical(RunRuntime &,const DamageRequest &,const DamageResult &) const;
    void damage_applied(RunRuntime &,const DamageRequest &,const DamageResult &) const;
    void hurt(RunRuntime &,const ShipDamageRequest &,const ShipDamageResult &) const;
    bool barrier(RunRuntime &,const ShipDamageRequest &,double) const;
private:
    uint32_t dispatch_depth=0;
    std::map<EnemyDefinition::Kind,EnemyPolicy> policies;
    std::vector<DeathHook> death_marked_hooks,shatter_hooks,enemy_death_hooks,trait_kill_hooks,weapon_kill_hooks;
    std::vector<CaptureHook> capture_hooks;
    std::vector<DamageHook> critical_hooks,damage_applied_hooks;
    std::vector<ShipHook> hurt_hooks;
    std::vector<BarrierHook> barrier_hooks;
};
}
