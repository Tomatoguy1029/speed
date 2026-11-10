#include "run_core.h"
#include "../runtime/checkpoint.h"
#include "../systems/equipment.h"
#include "../systems/attack_system.h"
#include "../systems/population_system.h"
#include "../bosses/flow/phase_controller.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
using namespace godot;

Dictionary SpeedRunCore::review_command(const String &kind,const Dictionary &p) {
    const auto reply=[](bool ok) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:4;out["field"]=ok?"":"review";out["message"]=ok?"":"停止中の状態・所持枠・指定レベルを確認してください";out["value"]=Variant();return out;};
    auto &s=runtime.state;
    if (!runtime.api_review || s.phase!=Phase::Paused || s.control.resume_phase!=int32_t(Phase::Play) || s.loadout->selected_id) return reply(false);
    if (kind=="review_catalog" && p.is_empty()) {
        Dictionary info,limits,out=reply(true);for (const auto &d:runtime.content->equipment) limits[String::utf8(d.external_id.c_str())]=int64_t(d.maximum_level);
        info["limits"]=limits;info["weapon_slots"]=int64_t(runtime.content->progression.weapon_slots);info["trait_slots"]=int64_t(runtime.content->progression.trait_slots);out["value"]=info;return out;
    }
    if (kind=="review_equipment") {
        if (p.size()!=4 || p.get("kind",Variant()).get_type()!=Variant::STRING || p.get("id",Variant()).get_type()!=Variant::STRING || p.get("replace",Variant()).get_type()!=Variant::STRING || p.get("level",Variant()).get_type()!=Variant::INT) return reply(false);
        const String category=p["kind"],id=p["id"],replace=p["replace"];const int64_t level=p["level"];
        if (category!="weapon" && category!="trait") return reply(false);
        const uint32_t type=category=="weapon"?0:1;
        const auto find=[&](const String &key)->const speed::LoadoutDefinition * {for (const auto &d:runtime.content->equipment) if (d.kind==type && String::utf8(d.external_id.c_str())==key) return &d;return nullptr;};
        const auto *target=find(id);if (!target || level<0 || uint64_t(level)>target->maximum_level) return reply(false);
        // 交換とレベル変更は候補へ適用し、失敗時は元の装備を保持する。
        speed::RunRuntime next;next.content=runtime.content;next.state=speed::clone_state(s);
        const auto remove=[&](uint32_t key) {return type==0?speed::EquipmentSystem::remove_weapon(next,key):speed::EquipmentSystem::remove_trait(next,key);};
        const auto &owned=type==0?next.state.loadout->weapons:next.state.loadout->traits;
        if (!replace.is_empty() && replace!=id) {
            if (std::any_of(owned.begin(),owned.end(),[&](const auto &v){return v.definition==target->id;})) return reply(false);
            const auto *old=find(replace);if (!old || level==0 || !remove(old->id)) return reply(false);}
        const bool has=std::any_of(owned.begin(),owned.end(),[&](const auto &v){return v.definition==target->id;});
        if (has && !remove(target->id)) return reply(false);
        if (level>0 && !speed::EquipmentSystem::grant(next,target->id,uint32_t(level))) return reply(false);
        if (!has && level==0) return reply(false);
        s=std::move(next.state);return reply(true);
    }
    if (kind=="review_invincible" && p.size()==1 && p.get("value",Variant()).get_type()==Variant::BOOL) {s.invincible=p["value"];return reply(true);}
    if (kind=="review_hero") return development_hero_command("dev_set_hero",p);
    if (kind=="review_meta") {
        const auto old=int64_t(s.loadout->reroll_profile_add);Dictionary envelope;envelope["kind"]="meta";envelope["payload"]=p;
        const Dictionary result=development_lab_command("dev_edit",envelope);
        if (bool(result["ok"])) s.loadout->rerolls=std::max<int64_t>(0,s.loadout->rerolls+int64_t(s.loadout->reroll_profile_add)-old);
        return result;
    }
    if (kind=="review_boss" && p.is_empty()) {
        if (s.lifecycle.endless || s.world.boss_spawned || runtime.content->stage_boss.empty() || s.control.bonus_remaining>0) return reply(false);
        Dictionary clear;clear["kind"]="clear";clear["payload"]=Dictionary();
        const Dictionary cleared=development_lab_command("dev_edit",clear);if (!bool(cleared["ok"])) return cleared;
        speed::AttackSystem::clear_friendly(s,speed::AttackEndReason::BossClear);
        // 通常プレイで決まった出現時刻を使い、その場で通常の登場処理を通す。
        if (s.control.boss_at<0) {const auto &boss=runtime.content->stage_boss.front();s.control.boss_at=boss.start+(boss.spread>0?s.control.rng.randf()*boss.spread:0);}
        s.time=s.control.boss_at;speed::PopulationSystem::sync_attack_budget(runtime);
        return reply(speed::PhaseController::automatic(runtime) && rebuild_enemy_grid(s.frame_grid_cell));
    }
    return reply(false);
}
