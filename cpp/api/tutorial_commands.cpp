#include "run_core.h"
#include "../systems/enemy_system.h"
#include "../systems/progression.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
using namespace godot;

// 初回の操作練習だけが使う命令。通常版でも受け付け、練習中のランに限る。
Dictionary SpeedRunCore::tutorial_command(const Dictionary &p) {
    const auto reply=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:4;out["field"]=ok?"":"tutorial";out["message"]=ok?"":"操作練習の段階と入力を確認してください";out["value"]=value;return out;};
    auto &s=runtime.state;auto &c=s.control;
    if (p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
    const String action=p["action"];
    if (action=="status" && p.size()==1) {
        // 段の進行に使う数だけを返す。
        // 画面の外へ離れたときに向きを示せるよう、機体に最も近い敵と星のかけらの位置も返す。
        int64_t enemies=0,gems=0;Vector2 enemy_at=s.ship.pos,gem_at=s.ship.pos;double enemy_d=-1,gem_d=-1;
        for (const auto &e:s.enemies) if (e.alive && !e.dead && !e.is_boss && e.origin==speed::SpawnOrigin::DevPlacement) {
            ++enemies;const double d=s.ship.pos.distance_squared_to(e.pos);if (enemy_d<0 || d<enemy_d) {enemy_d=d;enemy_at=e.pos;}
        }
        for (const auto &g:s.pickups.gems) if (g.alive) {
            ++gems;const double d=s.ship.pos.distance_squared_to(g.pos);if (gem_d<0 || d<gem_d) {gem_d=d;gem_at=g.pos;}
        }
        Dictionary value;value["active"]=c.tutorial;value["enemies"]=enemies;value["gems"]=gems;value["nearest_enemy"]=enemy_at;value["nearest_gem"]=gem_at;return reply(true,value);
    }
    if (!c.tutorial) return reply(false);
    if (action=="spawn" && p.size()==3 && p.get("enemy",Variant()).get_type()==Variant::STRING && p.get("positions",Variant()).get_type()==Variant::PACKED_VECTOR2_ARRAY) {
        const String id=p["enemy"];const PackedVector2Array positions=p["positions"];
        size_t definition=runtime.content->definitions.size();
        for (size_t i=0;i<runtime.content->definitions.size();++i) if (String(runtime.content->definitions[i].id)==id) definition=i;
        if (definition>=runtime.content->definitions.size() || positions.size()>64) return reply(false);
        for (const Vector2 &at:positions) if (!at.is_finite()) return reply(false);
        Array ids;
        for (const Vector2 &at:positions) {
            speed::EnemySpawn options;options.origin=speed::SpawnOrigin::DevPlacement;options.position=at;
            options.facing=(s.ship.pos-at).angle();options.has_facing=true;
            ids.push_back(speed::EnemySystem::spawn(runtime,definition,options));
        }
        speed::EnemySystem::flush_spawns(runtime);
        return reply(true,ids);
    }
    if (action=="pickups" && p.size()==2 && p.get("enabled",Variant()).get_type()==Variant::BOOL) {
        c.tutorial_pickups=p["enabled"];
        if (c.tutorial_pickups && s.loadout->ready) {
            // 置いてある分を拾い切ると次のレベルへ届くよう、手持ちの経験値を底上げする。
            double field=0;for (const auto &g:s.pickups.gems) if (g.alive) field+=g.value;
            const double need=speed::ProgressionSystem::next_xp(runtime);
            if (field>0 && s.loadout->xp+field<need) s.loadout->xp=need-field;
        }
        return reply(true);
    }
    if (action=="finish" && p.size()==1) {
        c.tutorial=false;c.tutorial_pickups=false;c.tutorial_start_pending=true;
        s.invincible=false;s.world.boss_spawned=false;
        s.population.frame_enabled=s.population.ready;
        speed::EnemySystem::clear_regular(runtime);
        return reply(true);
    }
    return reply(false);
}
