#include "dev_commands.h"
#include "checkpoint.h"
#include "../systems/equipment.h"
#include "../systems/enemy_system.h"
#include "../systems/field.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/draco/body.h"
#include "../output/frame_builder.h"
#include "../content/generated/run_schema_read.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <climits>

namespace speed {
namespace {
godot::Dictionary reply(bool ok,int code=1,const char *message="編集する定義と現在の版を確認してください") {
    godot::Dictionary out;out["ok"]=ok;out["code"]=ok?0:code;out["field"]=ok?"":"replacement";out["message"]=ok?"":message;out["value"]=godot::Variant();return out;
}
bool same_layout(const ContentBundle &a,const ContentBundle &b,bool append) {
    if ((!append && a.definitions.size()!=b.definitions.size()) || a.definitions.size()>b.definitions.size() || a.equipment.size()!=b.equipment.size()) return false;
    for (size_t i=0;i<a.definitions.size();++i) if (a.definitions[i].id!=b.definitions[i].id || a.definitions[i].kind!=b.definitions[i].kind) return false;
    for (size_t i=0;i<a.equipment.size();++i) if (a.equipment[i].id!=b.equipment[i].id || a.equipment[i].external_id!=b.equipment[i].external_id || a.equipment[i].kind!=b.equipment[i].kind || a.equipment[i].maximum_level!=b.equipment[i].maximum_level) return false;
    // 表示資源の追加は別の準備境界が必要。数値だけの編集は同じ資源番号を保つ。
    if ((!append && a.visuals.size()!=b.visuals.size()) || a.visuals.size()>b.visuals.size()) return false;
    for (size_t i=0;i<a.visuals.size();++i) if (a.visuals[i].id!=b.visuals[i].id || a.visuals[i].role!=b.visuals[i].role) return false;
    return true;
}
godot::Dictionary tuning_values(const ContentBundle &content) {
    godot::Dictionary values;
    for (const auto &v:content.enemy_tuning) {const godot::String id=content.definitions[v.enemy-1].id;godot::Dictionary fields=values.get(id,godot::Dictionary());fields[godot::String::utf8(v.key.c_str())]=v.value;values[id]=fields;}
    return values;
}
bool migrate_enemy(godot::RunState::Enemy &e,const EnemyDefinition &old,const EnemyDefinition &next) {
    const double old_hp=old.scaling.ready?old.scaling.hp:old.hp,new_hp=next.scaling.ready?next.scaling.hp:next.hp;
    const double old_armor=old.scaling.ready?old.scaling.armor:old.armor,new_armor=next.scaling.ready?next.scaling.armor:next.armor;
    const double size=std::sqrt(e.max_hp/std::max(0.001,old_hp*(old.scaling.ready?old.scaling.hp_mult:1.0)*(e.elite?3.0:1.0)));
    if (old_hp!=new_hp) {const double ratio=e.hp/std::max(0.001,e.max_hp);e.max_hp*=new_hp/std::max(0.001,old_hp);e.hp=e.max_hp*ratio;}
    if (old_armor!=new_armor) e.armor=old_armor>0?e.armor*new_armor/old_armor:new_armor*size*(next.scaling.ready?next.scaling.armor_mult:1.0)*(e.elite?1.3:1.0);
    if (old.speed!=next.speed) e.speed=old.speed>0?e.speed*next.speed/old.speed:next.speed;
    if (old.radius!=next.radius) e.radius*=next.radius/std::max(0.001,old.radius);
    if (old.fire_interval>0 && next.fire_interval!=old.fire_interval) e.fire_t*=next.fire_interval/old.fire_interval;
    if (old.xp!=next.xp) e.xp=old.xp>0?e.xp*next.xp/old.xp:next.xp;
    if (old.attack_weight!=next.attack_weight) e.attack_managed=next.attack_weight>0;
    if (!std::isfinite(e.fire_t)) return false;
    for (double value:{e.hp,e.max_hp,e.armor,e.speed,e.radius,e.xp}) if (!std::isfinite(value) || value<0) return false;
    return true;
}
}
int64_t DevCommands::place_lab_actor(RunRuntime &run,size_t definition,const EnemySpawn &options) {
    if (definition>=run.content->definitions.size()) return -1;
    for (const auto &body:run.content->boss_bodies) if (body.enemy==definition+1) {
        const auto actor=run.content->bosses[body.boss-1].kind==4?DracoBody::spawn(run,body.id,options.position,false):PhaseController::spawn(run,body.id,options.position,false);
        return run.state.enemy_handles.entity_id(actor);
    }
    const auto &d=run.content->definitions[definition];auto placed=options;
    if (d.id==godot::StringName("meteor") || d.id==godot::StringName("iron") || d.id==godot::StringName("saw")) {
        if (!d.scaling.ready) return -1;
        FieldRock rock;rock.manual=true;rock.position=options.position;rock.facing=options.facing;
        rock.kind=d.id==godot::StringName("meteor")?RockKind::Belt:d.id==godot::StringName("iron")?RockKind::Iron:RockKind::Saw;
        rock.size=d.scaling.radius*d.scaling.character;placed.size=rock.size;
        placed.rock=FieldSystem::add_rock(run,rock);
        if (!run.state.field.rock_handles.contains(placed.rock)) return -1;
    }
    const auto id=EnemySystem::spawn(run,definition,placed);
    if (run.state.field.rock_handles.contains(placed.rock)) {
        if (id>0) run.state.field.rocks[placed.rock.slot].proxy=run.state.enemy_handles.at(run.state.rows_by_id.at(id));
        else {run.state.field.rock_handles.release(placed.rock);run.state.field.rocks.pop_back();}
    }
    return id;
}
godot::Dictionary DevCommands::replace_definition(RunRuntime &run,const godot::Dictionary &payload,bool append) {
    using godot::Variant;
    if (!run.api_development || run.state.phase!=godot::RunState::Phase::Paused) return reply(false,4,"定義の編集は開発ランの停止中だけ行えます");
    if (payload.size()!=3 || !payload.has("definition_id") || payload["definition_id"].get_type()!=Variant::STRING || !payload.has("expected_revision") || payload["expected_revision"].get_type()!=Variant::INT || !payload.has("replacement") || payload["replacement"].get_type()!=Variant::PACKED_BYTE_ARRAY) return reply(false);
    if (int64_t(payload["expected_revision"])!=run.state.control.revision) return reply(false,3,"編集元の版が変わりました");
    const godot::String target=payload["definition_id"];
    if (std::none_of(run.content->definitions.begin(),run.content->definitions.end(),[&](const auto &d){return godot::String(d.id)==target;}) && target!="config") return reply(false,5,"編集する定義がありません");
    auto next=ContentBundle::read(payload["replacement"]);
    if (!next || !same_layout(*run.content,*next,append)) return reply(false,2,"種類・番号・資源を変える編集は再開始してください");
    RunRuntime candidate;candidate.state=clone_state(run.state);candidate.content=next;
    for (auto &e:candidate.state.enemies) if (e.alive && !e.dead && !migrate_enemy(e,run.content->definitions[e.definition],next->definitions[e.definition])) return reply(false);
    apply_config(next->config,candidate.state);
    EquipmentSystem::refresh_effects(candidate);
    if (!rebuild_state_indexes(candidate.state,*next)) return reply(false,2,"現在の状態を変換できないため再開始してください");
    // 検査が全て成功してから公開する。旧ContentBundleは保持点が所有し続ける。
    run.state=std::move(candidate.state);run.content=std::move(next);run.state.groups.defender_posts_tick=-1;run.full_output_dirty=true;
    godot::Dictionary changed;changed["values"]=tuning_values(*run.content);FrameBuilder::append(run,"enemy_tuning_changed",changed);
    return reply(true);
}
godot::Dictionary DevCommands::set_profile(RunRuntime &run,const godot::Dictionary &profile) {
    using godot::Dictionary;using godot::String;using godot::Variant;
    for (auto key:profile.keys()) if (String(key)!="mult" && String(key)!="reduce" && String(key)!="add") return reply(false);
    double charge=1,speed=1,attack=1,pickup=1,length=1,xp=1,hp=0,reroll=0;
    for (const char *group:{"mult","reduce","add"}) {
        if (!profile.has(group)) continue;
        if (profile[group].get_type()!=Variant::DICTIONARY) return reply(false);
        const Dictionary values=profile[group];
        for (auto key:values.keys()) {
            const String name=key;double *target=nullptr;
            if (String(group)=="mult") {
                if (name=="max_speed") target=&speed;else if (name=="attack") target=&attack;else if (name=="pickup") target=&pickup;else if (name=="length") target=&length;else if (name=="xp") target=&xp;
            } else if (String(group)=="reduce" && name=="charge_time") target=&charge;
            else if (String(group)=="add") {if (name=="max_hp") target=&hp;else if (name=="reroll") target=&reroll;}
            const Variant value=values[key];
            if (!target || (value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value)) || double(value)<0 || ((target==&charge || target==&speed || target==&length) && double(value)==0) || (target==&reroll && double(value)>1000000)) return reply(false);
            *target=value;
        }
    }
    auto &p=*run.state.loadout;p.charge_profile_factor=charge;p.speed_profile_factor=speed;p.attack_profile_factor=attack;p.pickup_profile_factor=pickup;p.length_profile_factor=length;p.xp_profile_factor=xp;p.hp_profile_add=hp;p.reroll_profile_add=reroll;
    if (p.ready) EquipmentSystem::refresh_effects(run);
    return reply(true);
}
godot::Dictionary DevCommands::tuning_saved(RunRuntime &run,const godot::Dictionary &payload) {
    using godot::Variant;
    if (!run.api_development) return reply(false,4);
    if (payload.size()!=2 || payload.get("path",Variant()).get_type()!=Variant::STRING || payload.get("bundle",Variant()).get_type()!=Variant::PACKED_BYTE_ARRAY) return reply(false);
    const auto saved=ContentBundle::read(payload["bundle"]);if (!saved) return reply(false);
    godot::Dictionary event;event["path"]=payload["path"];event["values"]=tuning_values(*saved);FrameBuilder::append(run,"enemy_tuning_saved",event);
    return reply(true);
}
}
