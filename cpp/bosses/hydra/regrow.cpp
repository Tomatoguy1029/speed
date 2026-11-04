#include "regrow.h"
#include "body.h"
#include "../flow/flow_runner.h"
#include "../flow/technique_runner.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attacks/friend_debris.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void cue(RunRuntime &r,const BossBodyState &b,const char *name,int32_t neck=-1,double duration=0,double damage=0,uint32_t count=0) {
    godot::Dictionary e;e["id"]=r.state.enemy_handles.entity_id(b.actor);e["cue"]=name;e["technique"]="";e["neck"]=neck;const auto *part=neck>=0 && size_t(neck)<b.hydra.necks.size()?&b.hydra.necks[neck]:neck==-2?&b.hydra.bearer:nullptr;e["position"]=part?HydraBody::head_position(r,b,*part):r.state.enemies[b.actor.slot].pos;e["kind"]=part?symbol_name(part->kind):"body";e["duration"]=duration;e["damage"]=damage;e["next_count"]=count;e["target"]="hydra";FrameBuilder::append(r,"hydra_cue",e);
}
void interrupt(RunRuntime &r,BossBodyState &b) {
    for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) FlowRunner::cancel(r,f);
    for (uint32_t i=0;i<r.state.bosses->techniques.size();++i) {const auto actor=r.state.bosses->techniques[i].actor;if (same_handle(actor,b.actor) || std::any_of(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &n){return same_handle(n.actor,actor);})) TechniqueRunner::cancel(r,r.state.bosses->handles.at(i));}
}
void suspend(RunRuntime &r,const BossBodyState &b,bool value) {for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) f.suspended=value;}
bool busy(const RunRuntime &r,const BossBodyState &b) {return std::any_of(r.state.bosses->techniques.begin(),r.state.bosses->techniques.end(),[&](const auto &t){return same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished;});}
void grow(RunRuntime &r,BossBodyState &b,HydraNeckState &n) {
    const auto &p=HydraBody::rule(r,b);n.length=p.neck_rest*0.3;n.angle=n.base_angle+r.state.enemies[b.actor.slot].facing;const uint32_t definitions[]={p.bite,p.vortex,p.debris,p.beam,p.thunder};const auto id=EnemySystem::spawn_part(r,b.actor,definitions[uint32_t(n.kind)]-1,HydraBody::head_position(r,b,n));if (id<0) return;
    n.actor=r.state.enemy_handles.at(r.state.rows_by_id.at(id));n.id=id;auto &e=r.state.enemies[n.actor.slot];e.hp=e.max_hp=p.head_hp*r.content->definitions[r.content->boss_bodies[b.definition-1].enemy-1].scaling.hp_mult;n.head_hp=e.hp;n.normal=0;n.glow=0;n.points.clear();n.trail.clear();
    const auto index=uint32_t(&n-b.hydra.necks.data());b.participants[index+1]={n.actor,n.actor,id,false,true};HydraBody::follow_neck(r,b,n,0);
}
void check_growth(RunRuntime &r,BossBodyState &b) {
    if (b.hydra.growth_left>0 || b.hydra.separated) return;const auto &p=HydraRegrow::rule(r,b);const auto &e=r.state.enemies[b.actor.slot];const double ratio=e.hp/e.max_hp;const auto count=b.hydra.necks.size();const uint32_t next=count==3 && ratio<=p.growth_first?5:count==5 && ratio<=p.growth_second?8:0;if (!next) return;
    interrupt(r,b);HydraRegrow::set_count(r,b,next);b.hydra.growth_left=p.growth_time;r.state.enemies[b.actor.slot].guard=p.growth_time;for (const auto &n:b.hydra.necks) if (HydraRegrow::alive(r,n)) r.state.enemies[n.actor.slot].guard=p.growth_time;cue(r,b,"growth_started",-1,p.growth_time);suspend(r,b,true);
}
}
const HydraRegrowDefinition &HydraRegrow::rule(const RunRuntime &r,const BossBodyState &b) {const auto boss=r.content->boss_bodies[b.definition-1].boss;return *std::find_if(r.content->hydra_regrow.begin(),r.content->hydra_regrow.end(),[&](const auto &p){return p.boss==boss;});}
bool HydraRegrow::alive(const RunRuntime &r,const HydraNeckState &n) {return r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead;}
void HydraRegrow::set_count(RunRuntime &r,BossBodyState &b,uint32_t count) {
    const auto &p=HydraBody::rule(r,b);const auto previous=b.hydra.necks.size();const HydraHeadKind kinds[]={HydraHeadKind::Bite,HydraHeadKind::Vortex,HydraHeadKind::Debris,HydraHeadKind::Beam,HydraHeadKind::Thunder,HydraHeadKind::Bite,HydraHeadKind::Beam,HydraHeadKind::Vortex};cue(r,b,"phase_changed",-1,0,0,count);b.hydra.necks.resize(count);b.participants.resize(count+1);
    for (uint32_t i=0;i<count;++i) {auto &n=b.hydra.necks[i];if (i>=previous) n.cd=p.attack_cd*(0.5+0.5*r.state.control.rng.randf());n.kind=kinds[i];if (alive(r,n)) EnemySystem::retire(r,n.actor,RetireReason::Regenerate);n.actor={};n.normal=0;n.locked=n.extension=n.lunge_done=false;n.trail.clear();n.base_angle=6.283185307179586*i/count;n.burned=false;n.regrow=0;grow(r,b,n);}
}
void HydraRegrow::damaged(RunRuntime &r,BossBodyState &b) {if (!b.hydra.separated) check_growth(r,b);}
bool HydraRegrow::growth_tick(RunRuntime &r,BossBodyState &b,double dt) {
    if (b.hydra.growth_left>0) {b.hydra.growth_left=std::max(0.0,b.hydra.growth_left-dt);r.state.enemies[b.actor.slot].guard=b.hydra.growth_left;const double rest=HydraBody::rule(r,b).neck_rest;for (auto &n:b.hydra.necks) if (alive(r,n)) {auto &e=r.state.enemies[n.actor.slot];e.guard=b.hydra.growth_left;n.length+=std::clamp(rest-n.length,-rest*dt,rest*dt);e.pos=HydraBody::head_position(r,b,n);HydraBody::follow_neck(r,b,n,dt);}if (b.hydra.growth_left<=0) check_growth(r,b);suspend(r,b,true);return true;}
    check_growth(r,b);const bool growing=b.hydra.growth_left>0;suspend(r,b,growing || b.hydra.chance_left>0 || b.hydra.separation_pending);return growing;
}
void HydraRegrow::chance_tick(RunRuntime &r,BossBodyState &b,double dt) {
    if (b.hydra.separated || b.hydra.separation_pending) return;
    if (b.hydra.chance_left>0) {b.hydra.chance_left=std::max(0.0,b.hydra.chance_left-dt);if (b.hydra.chance_left<=0) for (auto &n:b.hydra.necks) if (!alive(r,n)) grow(r,b,n);}
    else if (!b.hydra.necks.empty() && std::none_of(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &n){return alive(r,n);})) {interrupt(r,b);b.hydra.chance_left=rule(r,b).chance_time;cue(r,b,"recovery_started",-1,b.hydra.chance_left);}
    suspend(r,b,b.hydra.chance_left>0 || b.hydra.growth_left>0 || b.hydra.separation_pending);
}
bool HydraRegrow::tick_dead(RunRuntime &r,BossBodyState &b,HydraNeckState &n,double dt) {
    if (alive(r,n)) return false;
    if (n.actor.generation) {for (auto &p:b.participants) if (same_handle(p.actor,n.actor)) p.active=false;n.actor={};}
    if (!b.hydra.separated && b.hydra.chance_left<=0 && b.hydra.growth_left<=0 && !busy(r,b) && b.hydra.recovery_left<=0) {n.regrow-=dt;if (n.regrow<=0) grow(r,b,n);}
    n.length=std::max(0.0,n.length-HydraBody::rule(r,b).neck_rest*dt);return true;
}
void HydraRegrow::part_defeated(RunRuntime &r,const DeathContext &death) {
    for (auto &b:r.state.bosses->bodies) for (size_t k=0;k<b.hydra.necks.size();++k) {auto &n=b.hydra.necks[k];if (!same_handle(n.actor,death.target)) continue;const auto &p=rule(r,b);const auto &e=r.state.enemies[death.target.slot];if (e.hp<n.head_hp) cue(r,b,"hit",k,0,n.head_hp-std::max(0.0,e.hp));cue(r,b,"head_destroyed",k);n.burned=r.state.world_time-e.fire_hit<0.5;uint32_t combo=1;if (r.state.draw.tracing) combo=++b.hydra.dash_kills[r.state.draw.dash_id];
        DebrisBurstParams debris;debris.position=death.corpse.pos;debris.count=8;debris.speed=700;debris.damage=p.debris_dmg*r.state.combat_config.atk_scale;debris.color=godot::Color::html("a89a86");debris.source_id=death.corpse.id;FriendDebrisSystem::burst(r,debris);
        for (uint32_t i=0;i<r.state.bosses->techniques.size();++i) if (same_handle(r.state.bosses->techniques[i].actor,n.actor)) TechniqueRunner::cancel(r,r.state.bosses->handles.at(i));for (auto &part:b.participants) if (same_handle(part.actor,n.actor)) part.active=false;n.actor={};n.normal=0;n.locked=n.extension=false;const size_t remaining=std::count_if(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &v){return alive(r,v);});const double grace=(p.regrow+p.regrow_per_head*remaining)*(1+p.regrow_combo*(combo-1));for (auto &v:b.hydra.necks) if (!v.actor.generation) v.regrow=std::max(v.regrow,grace);if (n.burned) n.regrow=std::max(n.regrow,p.regrow*p.fire_regrow_scale);return;
    }
}
bool HydraRegrow::validate(const BossBodyState &b) {for (double v:{b.hydra.growth_left,b.hydra.chance_left,b.hydra.recovery_left,b.hydra.major_cd,b.hydra.combo_left,b.hydra.major_padding_left}) if (!std::isfinite(v) || v<0) return false;for (const auto &n:b.hydra.necks) if (!std::isfinite(n.regrow)) return false;for (const auto &v:b.hydra.dash_kills) if (v.first<0 || !v.second) return false;return true;}
}
