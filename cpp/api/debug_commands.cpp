#include "run_core.h"
#include "../systems/equipment.h"
#include "../systems/progression.h"
#include "../systems/enemy_system.h"
#include "../systems/field.h"
#include "../systems/combat_resolver.h"
#include "../bosses/flow/phase_controller.h"
#include "../systems/attacks/beam.h"
#include "../systems/attacks/cross.h"
#include "../systems/attacks/zone.h"
#include "../systems/attacks/wave.h"
#include "../systems/attacks/wall.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include "../output/frame_builder.h"
#include <algorithm>
#include <cmath>
#include <climits>
using namespace godot;
Dictionary SpeedRunCore::development_debug_command(const Dictionary &p) {
    const auto reply=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"debug";out["message"]=ok?"":"開発操作の入力かランの状態を確認してください";out["value"]=value;return out;};
    auto &s=runtime.state;
    if (!runtime.api_development || (s.phase!=Phase::Play && s.phase!=Phase::Paused && s.phase!=Phase::LevelUp) || p.get("action",Variant()).get_type()!=Variant::STRING || p.get("args",Variant()).get_type()!=Variant::DICTIONARY || p.size()!=2) return reply(false);
    if (s.phase==Phase::Paused && s.control.resume_phase!=int32_t(Phase::Play) && s.control.resume_phase!=int32_t(Phase::LevelUp)) return reply(false);
    const String action=p["action"];const Dictionary args=p["args"];
    if (action=="rank_hitstop") {
        if (args.size()!=2 || args.get("rank",Variant()).get_type()!=Variant::INT) return reply(false);
        const int64_t rank=args["rank"];const Variant value=args.get("multiplier",Variant());
        if (rank<1 || rank>10 || (value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value)) || double(value)<0 || double(value)>10) return reply(false);
        s.debug_rank_hitstop[rank-1]=double(value);
        Dictionary changed;changed["rank"]=rank;changed["multiplier"]=double(value);speed::FrameBuilder::append(runtime,"debug_rank_hitstop_changed",changed);
        return reply(true);
    }
    if (action=="random") {
        if (args.size()!=2 || args.get("ids",Variant()).get_type()!=Variant::PACKED_STRING_ARRAY || args.get("count",Variant()).get_type()!=Variant::INT) return reply(false);
        const PackedStringArray ids=args["ids"];const int64_t count=args["count"];if (ids.is_empty() || count<1 || count>10000) return reply(false);
        std::vector<size_t> choices;
        for (const String id:ids) {
            const auto found=std::find_if(runtime.content->definitions.begin(),runtime.content->definitions.end(),[&](const auto &d){return String(d.id)==id;});
            if (found==runtime.content->definitions.end() || found->kind==speed::EnemyDefinition::Kind::Part || found->kind==speed::EnemyDefinition::Kind::Meteor || found->kind==speed::EnemyDefinition::Kind::Obstacle || found->kind==speed::EnemyDefinition::Kind::Saw || found->kind==speed::EnemyDefinition::Kind::TriangleStar) return reply(false);
            choices.push_back(found-runtime.content->definitions.begin());
        }
        PackedInt64Array spawned;
        for (int64_t n=0;n<count;++n) {
            const size_t definition=choices[*s.control.rng.randi_range(0,choices.size()-1)];const auto &d=runtime.content->definitions[definition];
            speed::EnemySpawn options;const double x=s.control.rng.randf_range(s.view_center.x-s.view_half.x,s.view_center.x+s.view_half.x);const double y=s.control.rng.randf_range(s.view_center.y-s.view_half.y,s.view_center.y+s.view_half.y);options.position=Vector2(x,y);
            options.has_facing=true;options.facing=(s.ship.pos-options.position).angle();options.origin=speed::SpawnOrigin::DevPlacement;
            if (d.size_var) options.size=d.scaling.radius*s.control.rng.randf_range(0.85,1.45);
            const int64_t id=speed::EnemySystem::spawn(runtime,definition,options);if (id<=0) return reply(false);
            auto &enemy=s.enemies[s.rows_by_id.at(id)];auto at=speed::FieldSystem::push_out(runtime,enemy.pos,enemy.radius+4);
            const double edge=s.ship_config.field_radius-enemy.radius;if (at.length()>edge) at=at.normalized()*edge;enemy.pos=at;spawned.push_back(id);
        }
        rebuild_enemy_grid(s.frame_grid_cell);return reply(true,spawned);
    }
    if (action=="time" || action=="coins") {
        if (args.size()!=1) return reply(false);const char *key=action=="time"?"seconds":"amount";const Variant value=args.get(key,Variant());
        if (action=="time") {if ((value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value)) || double(value)<0 || !std::isfinite(s.time+double(value))) return reply(false);s.time+=double(value);}
        else {if (value.get_type()!=Variant::INT || int64_t(value)<0 || s.lifecycle.coins>INT64_MAX-int64_t(value)) return reply(false);s.lifecycle.coins+=int64_t(value);}return reply(true);
    }
    if (!args.is_empty()) return reply(false);
    if (action=="invincible") s.invincible=!s.invincible;
    else if (action=="boss_time") s.time=std::max(s.time,runtime.content->population.boss_start-1.0);
    else if (action=="kill_boss") {
        for (uint32_t row=0;row<s.enemies.size();++row) {
            const auto &enemy=s.enemies[row];if (!enemy.alive || enemy.dead || !enemy.is_boss) continue;
            const auto actor=s.enemy_handles.at(row);if (!speed::PhaseController::find(runtime,actor)) continue;
            speed::DeathContext death;death.target=death.request.struck=actor;death.request.cause=speed::Cause::Debug;death.corpse.id=enemy.id;death.corpse.pos=enemy.pos;
            speed::PhaseController::defeated(runtime,death);return reply(true);
        }
        return reply(false);
    }
    else if (action=="level_up") return reply(speed::ProgressionSystem::add_experience(*this,speed::ProgressionSystem::next_xp(runtime)-s.loadout->xp+0.01));
    else if (action=="gauge_full") s.draw.gauge=1;
    else if (action=="heal") s.ship.hp=s.ship_config.max_hp;
    else if (action=="clear_enemies") {speed::EnemySystem::clear_regular(runtime);rebuild_enemy_grid(s.frame_grid_cell);}
    else if (action=="hurt" || action=="die") {
        const bool keep=s.invincible;const double shield=s.ship.shield_t;s.invincible=false;s.ship.invuln=s.ship.shield_t=0;
        speed::ShipDamageRequest hit;hit.amount=action=="hurt"?1:s.ship.hp+1;hit.cause=speed::Cause::Debug;speed::CombatResolver::ship_damage(runtime,hit);
        if (action=="hurt") {s.invincible=keep;s.ship.shield_t=shield;}
    } else if (action=="reset_loadout") {
        auto weapons=s.loadout->weapons,traits=s.loadout->traits;
        for (const auto &v:weapons) if (!speed::EquipmentSystem::remove_weapon(runtime,v.definition)) return reply(false);
        for (const auto &v:traits) if (!speed::EquipmentSystem::remove_trait(runtime,v.definition)) return reply(false);
        for (const auto &d:runtime.content->post_max) if (auto stack=speed::ProgressionSystem::post_stacks(*s.loadout,d.external_id)) *stack=0;
        s.loadout->candidates.clear();s.loadout->offer_id=s.loadout->selected_id=0;s.loadout->initial_offer=false;s.loadout->comet_weapon=0;s.loadout->comet_direct=false;s.loadout->pending_comet_weapons.clear();runtime.resource_workspace.requests.clear();
        s.loadout->boost_distance=0;s.loadout->contact_wave={};s.loadout->kill_sonic={};s.loadout->crit_beam={};s.loadout->vortex={};s.loadout->run_up={};s.loadout->rampage={};
        if (s.phase==Phase::LevelUp) s.phase=Phase::Play;else if (s.phase==Phase::Paused && s.control.resume_phase==int32_t(Phase::LevelUp)) s.control.resume_phase=int32_t(Phase::Play);
        speed::EquipmentSystem::refresh_effects(runtime);
    } else if (action=="hazards") {
        const auto at=s.ship.pos;const double a=s.control.rng.randf()*(2.0*3.14159265358979323846);
        const auto position=[&](double angle,double radius){return at+Vector2::from_angle(angle)*radius;};
        speed::BeamParams beam;beam.position=position(a,420);beam.angle=a+3.14159265358979323846;beam.length=900;beam.half_width=13;beam.delay=0.8;beam.active=0.35;beam.damage=10;speed::BeamSystem::emit(runtime,beam);
        beam.color=Color::html("ffe0a0");beam.position=position(a+2,260);beam.angle=0;beam.length=700;beam.half_width=9;beam.delay=0.9;beam.active=0.3;speed::CrossSystem::emit(runtime,beam);
        speed::ZoneParams zone;zone.position=position(a+4,160);zone.radius=90;zone.delay=1;zone.damage=10;zone.style=speed::ZoneStyle::Reticle;speed::ZoneSystem::emit(runtime,zone);
        zone.position=at;zone.radius=70;zone.delay=1.2;zone.style=speed::ZoneStyle::Lightning;zone.color=Color::html("ffe46b");speed::ZoneSystem::emit(runtime,zone);
        zone.position=position(a+1,220);zone.radius=110;zone.delay=0.6;zone.style=speed::ZoneStyle::Plain;zone.color=Color::html("ffb36b");speed::ZoneSystem::emit(runtime,zone);
        speed::WaveParams wave;wave.position=position(a+3,300);wave.angle=a;wave.arc=0.5;wave.radius=500;wave.speed=420;wave.width=18;wave.delay=0.5;wave.damage=10;speed::WaveSystem::emit(runtime,wave);
        wave.position=position(a+5,350);wave.angle=0;wave.arc=(2.0*3.14159265358979323846);wave.radius=700;wave.speed=380;wave.width=16;wave.delay=0.6;wave.gap=a;wave.gap_arc=0.35;speed::WaveSystem::emit_layers(runtime,wave,4,0.35,0.6);
        speed::WallParams wall;wall.position=position(a+0.5,200);wall.angle=a+3.14159265358979323846/2;wall.length=500;wall.half_width=8;wall.delay=0.5;wall.active=3;wall.damage=10;speed::WallSystem::emit(runtime,wall);
    } else return reply(false);
    return reply(true);
}
