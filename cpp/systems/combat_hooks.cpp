#include "../behaviors/weapons/massTow.h"
#include "combat_hooks.h"
#include "equipment.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/hydra/body.h"
#include "../behaviors/enemies/phoenix.h"
#include "../behaviors/enemies/crab.h"
#include "../behaviors/enemies/pump.h"
#include "../behaviors/enemies/corona_vortex.h"
#include "../behaviors/weapons/barrier.h"
#include "../behaviors/weapons/knockback.h"
#include "../behaviors/enemies/cepheus.h"
#include "../behaviors/enemies/triangle_star.h"
#include "../behaviors/traits/rampage.h"
#include "../behaviors/traits/critBeam.h"
#include "../behaviors/enemies/shield.h"
#include "../behaviors/enemies/sniper.h"
#include "../behaviors/enemies/split.h"
#include "attack_budget.h"
#include "attacks/friend_debris.h"
#include "../runtime/run_runtime.h"
#include "field.h"
#include "../../native/geometry.h"
#include <cmath>
namespace speed {
namespace {
bool development_capture(RunRuntime &run,const DeathContext &death) {
    return run.api_development && run.state.attacks.development_hull_captures.erase(death.corpse.id)>0;
}
void passive_death(RunRuntime &run,const DeathContext &death) {
    auto &state=run.state;if (state.world.attack_formation_mode || death.corpse.is_boss) return;
    AttackBudgetSystem(run).passive(std::to_string(death.corpse.id),death.target);
}
bool saw_allows(const RunRuntime &run,EnemyHandle target,const DamageRequest &) {return run.state.enemies[target.slot].stone>0;}
bool shield_allows(const RunRuntime &run,EnemyHandle target,const DamageRequest &request) {
    const auto &enemy=run.state.enemies[target.slot];
    return !ShieldBehavior::blocks_front(run,target,request.has_impact?request.impact:enemy.pos,request.direction);
}
}
CombatHooks::CombatHooks() {EnemyPolicy common_boss;common_boss.body_damaged=PhaseController::damaged;common_boss.can_defeat=PhaseController::can_defeat;common_boss.boss_defeated=PhaseController::defeated;policies[EnemyDefinition::Kind::Monoceros]=common_boss;policies[EnemyDefinition::Kind::Centaurus]=common_boss;policies[EnemyDefinition::Kind::CanisMajor]=common_boss;policies[EnemyDefinition::Kind::Hydra]=common_boss;policies[EnemyDefinition::Kind::Hydra].passes=HydraBody::passes;policies[EnemyDefinition::Kind::Draco]=common_boss;death_marked_hooks.push_back(HydraBody::part_defeated);policies[EnemyDefinition::Kind::TriangleStar].passes=TriangleStarBehavior::passes;policies[EnemyDefinition::Kind::Saw].allows=saw_allows;policies[EnemyDefinition::Kind::Shield].allows=shield_allows;death_marked_hooks.push_back(passive_death);death_marked_hooks.push_back(CepheusBehavior::died);death_marked_hooks.push_back(SniperBehavior::died);death_marked_hooks.push_back(PhoenixBehavior::died);death_marked_hooks.push_back(CrabBehavior::died);death_marked_hooks.push_back(PumpBehavior::death_marked);death_marked_hooks.push_back(CoronaVortex::death_marked);
    death_marked_hooks.push_back(FieldSystem::comet_gravity);barrier_hooks.push_back(BarrierBehavior::block);shatter_hooks.push_back(KnockbackBehavior::defeated);capture_hooks.push_back(MassTowBehavior::capture);capture_hooks.push_back(development_capture);trait_kill_hooks.push_back(EquipmentSystem::trait_kill);critical_hooks.push_back(CritBeamBehavior::critical);enemy_death_hooks.push_back(SplitBehavior::died);enemy_death_hooks.push_back(FriendDebrisSystem::development_death);enemy_death_hooks.push_back(PumpBehavior::died);}
bool CombatHooks::register_enemy(EnemyDefinition::Kind kind,EnemyPolicy policy) {
    if (dispatch_depth) return false;policies[kind]=policy;return true;
}
const CombatHooks::EnemyPolicy &CombatHooks::enemy_policy(EnemyDefinition::Kind kind) const {
    static const EnemyPolicy empty;const auto found=policies.find(kind);return found==policies.end()?empty:found->second;
}
bool CombatHooks::on_death_marked(DeathHook hook) {
    if (dispatch_depth || !hook) return false;death_marked_hooks.push_back(hook);return true;
}
bool CombatHooks::on_capture(CaptureHook hook) {
    if (dispatch_depth || !hook) return false;capture_hooks.push_back(hook);return true;
}
bool CombatHooks::on_shatter(DeathHook hook) {
    if (dispatch_depth || !hook) return false;shatter_hooks.push_back(hook);return true;
}
bool CombatHooks::on_enemy_death(DeathHook hook) {
    if (dispatch_depth || !hook) return false;enemy_death_hooks.push_back(hook);return true;
}
bool CombatHooks::on_trait_kill(DeathHook hook) {
    if (dispatch_depth || !hook) return false;trait_kill_hooks.push_back(hook);return true;
}
bool CombatHooks::on_weapon_kill(DeathHook hook) {
    if (dispatch_depth || !hook) return false;weapon_kill_hooks.push_back(hook);return true;
}
bool CombatHooks::on_critical(DamageHook hook) {
    if (dispatch_depth || !hook) return false;critical_hooks.push_back(hook);return true;
}
bool CombatHooks::on_damage_applied(DamageHook hook) {
    if (dispatch_depth || !hook) return false;damage_applied_hooks.push_back(hook);return true;
}
bool CombatHooks::on_hurt(ShipHook hook) {
    if (dispatch_depth || !hook) return false;hurt_hooks.push_back(hook);return true;
}
bool CombatHooks::on_barrier(BarrierHook hook) {
    if (dispatch_depth || !hook) return false;barrier_hooks.push_back(hook);return true;
}
void CombatHooks::death_marked(RunRuntime &run,const DeathContext &death) const {for (auto hook:death_marked_hooks) hook(run,death);}
void CombatHooks::shatter(RunRuntime &run,const DeathContext &death) const {for (auto hook:shatter_hooks) hook(run,death);}
void CombatHooks::enemy_death(RunRuntime &run,const DeathContext &death) const {for (auto hook:enemy_death_hooks) hook(run,death);}
void CombatHooks::trait_kill(RunRuntime &run,const DeathContext &death) const {for (auto hook:trait_kill_hooks) hook(run,death);}
void CombatHooks::weapon_kill(RunRuntime &run,const DeathContext &death) const {for (auto hook:weapon_kill_hooks) hook(run,death);}

bool CombatHooks::capture(RunRuntime &run,const DeathContext &death) const {for (auto hook:capture_hooks) if (hook(run,death)) return true;return false;}
void CombatHooks::critical(RunRuntime &run,const DamageRequest &request,const DamageResult &result) const {for (auto hook:critical_hooks) hook(run,request,result);}
void CombatHooks::damage_applied(RunRuntime &run,const DamageRequest &request,const DamageResult &result) const {for (auto hook:damage_applied_hooks) hook(run,request,result);}
void CombatHooks::hurt(RunRuntime &run,const ShipDamageRequest &request,const ShipDamageResult &result) const {for (auto hook:hurt_hooks) hook(run,request,result);}
bool CombatHooks::barrier(RunRuntime &run,const ShipDamageRequest &request,double amount) const {for (auto hook:barrier_hooks) if (hook(run,request,amount)) return true;return false;}
}
