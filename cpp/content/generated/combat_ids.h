// 共通スキーマから生成。直接編集しない。
#pragma once
#include <cstdint>
#include <string_view>
namespace speed {
enum class Cause : uint32_t {None=0,Ram=1,Touch=2,Bump=3,Shot=4,Debris=5,Fire=6,Blast=7,Afterimage=8,FinalStrike=9,Debug=10,Missile=11,Homing=12,Slash=13,Wave=14,Chain=15,PumpBurst=16,Marlin=17,Collapse=18,Rain=19,ArrowShower=20,InhaleBite=21,SwordFlash=22,HoundLunge=23,Pounce=24,FlameJet=25,Bullet=26,Reflected=27,HullDebris=28,Saw=29,Count};
inline const char *symbol_name(Cause value) {
    switch(value) {
    case Cause::None: return "";
    case Cause::Ram: return "ram";
    case Cause::Touch: return "touch";
    case Cause::Bump: return "bump";
    case Cause::Shot: return "shot";
    case Cause::Debris: return "debris";
    case Cause::Fire: return "fire";
    case Cause::Blast: return "blast";
    case Cause::Afterimage: return "afterimage";
    case Cause::FinalStrike: return "final_strike";
    case Cause::Debug: return "debug";
    case Cause::Missile: return "missile";
    case Cause::Homing: return "homing";
    case Cause::Slash: return "slash";
    case Cause::Wave: return "wave";
    case Cause::Chain: return "chain";
    case Cause::PumpBurst: return "pump_burst";
    case Cause::Marlin: return "marlin";
    case Cause::Collapse: return "collapse";
    case Cause::Rain: return "rain";
    case Cause::ArrowShower: return "arrow_shower";
    case Cause::InhaleBite: return "inhale_bite";
    case Cause::SwordFlash: return "sword_flash";
    case Cause::HoundLunge: return "hound_lunge";
    case Cause::Pounce: return "pounce";
    case Cause::FlameJet: return "flame_jet";
    case Cause::Bullet: return "bullet";
    case Cause::Reflected: return "reflected";
    case Cause::HullDebris: return "hullDebris";
    case Cause::Saw: return "saw";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, Cause &out) {
    if (value=="") {out=Cause::None;return true;}
    if (value=="ram") {out=Cause::Ram;return true;}
    if (value=="touch") {out=Cause::Touch;return true;}
    if (value=="bump") {out=Cause::Bump;return true;}
    if (value=="shot") {out=Cause::Shot;return true;}
    if (value=="debris") {out=Cause::Debris;return true;}
    if (value=="fire") {out=Cause::Fire;return true;}
    if (value=="blast") {out=Cause::Blast;return true;}
    if (value=="afterimage") {out=Cause::Afterimage;return true;}
    if (value=="final_strike") {out=Cause::FinalStrike;return true;}
    if (value=="debug") {out=Cause::Debug;return true;}
    if (value=="missile") {out=Cause::Missile;return true;}
    if (value=="homing") {out=Cause::Homing;return true;}
    if (value=="slash") {out=Cause::Slash;return true;}
    if (value=="wave") {out=Cause::Wave;return true;}
    if (value=="chain") {out=Cause::Chain;return true;}
    if (value=="pump_burst") {out=Cause::PumpBurst;return true;}
    if (value=="marlin") {out=Cause::Marlin;return true;}
    if (value=="collapse") {out=Cause::Collapse;return true;}
    if (value=="rain") {out=Cause::Rain;return true;}
    if (value=="arrow_shower") {out=Cause::ArrowShower;return true;}
    if (value=="inhale_bite") {out=Cause::InhaleBite;return true;}
    if (value=="sword_flash") {out=Cause::SwordFlash;return true;}
    if (value=="hound_lunge") {out=Cause::HoundLunge;return true;}
    if (value=="pounce") {out=Cause::Pounce;return true;}
    if (value=="flame_jet") {out=Cause::FlameJet;return true;}
    if (value=="bullet") {out=Cause::Bullet;return true;}
    if (value=="reflected") {out=Cause::Reflected;return true;}
    if (value=="hullDebris") {out=Cause::HullDebris;return true;}
    if (value=="saw") {out=Cause::Saw;return true;}
    return false;
}
enum class VisualRole : uint32_t {EnemySprite=0,Ship=1,ForwardShot=2,Crystal=3,Coin=4,Cannon=5,EnemyLook=6,Equipment=7,AttackScene=8,Planet=9,Moon=10,Count};
inline const char *symbol_name(VisualRole value) {
    switch(value) {
    case VisualRole::EnemySprite: return "enemy_sprite";
    case VisualRole::Ship: return "ship";
    case VisualRole::ForwardShot: return "forward_shot";
    case VisualRole::Crystal: return "crystal";
    case VisualRole::Coin: return "coin";
    case VisualRole::Cannon: return "cannon";
    case VisualRole::EnemyLook: return "enemy_look";
    case VisualRole::Equipment: return "equipment";
    case VisualRole::AttackScene: return "attack_scene";
    case VisualRole::Planet: return "planet";
    case VisualRole::Moon: return "moon";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, VisualRole &out) {
    if (value=="enemy_sprite") {out=VisualRole::EnemySprite;return true;}
    if (value=="ship") {out=VisualRole::Ship;return true;}
    if (value=="forward_shot") {out=VisualRole::ForwardShot;return true;}
    if (value=="crystal") {out=VisualRole::Crystal;return true;}
    if (value=="coin") {out=VisualRole::Coin;return true;}
    if (value=="cannon") {out=VisualRole::Cannon;return true;}
    if (value=="enemy_look") {out=VisualRole::EnemyLook;return true;}
    if (value=="equipment") {out=VisualRole::Equipment;return true;}
    if (value=="attack_scene") {out=VisualRole::AttackScene;return true;}
    if (value=="planet") {out=VisualRole::Planet;return true;}
    if (value=="moon") {out=VisualRole::Moon;return true;}
    return false;
}
enum class EventType : uint32_t {AttackStart=0,AttackEnd=1,AttackRetired=2,AttackVisualEnd=3,Bonus=4,BlockImpact=5,Bounce=6,ClipGroupEnd=7,ClipGroup=8,CombatDamage=9,CombatPlayerDamage=10,CriticalHit=11,DebrisTrail=12,DrawStart=13,Duplicate=14,EnemyRetire=15,GameOver=16,GaugeFull=17,Hit=18,HullScatter=19,Hurt=20,Kill=21,Launch=22,LevelBonus=23,Levelup=24,Phase=25,Pickup=26,Reroll=27,ShieldBlock=28,ShieldExpired=29,ShieldReflect=30,ShieldStolen=31,ShipDeath=32,ShipExplode=33,ShotHit=34,StrongSpawn=35,Text=36,TimeLimitReached=37,TraceEnd=38,Upgrade=39,Wave=40,WeaponFire=41,Offer=42,Choice=43,Loadout=44,RunFinished=45,Crash=46,Ring=47,Count};
inline const char *symbol_name(EventType value) {
    switch(value) {
    case EventType::AttackStart: return "attack_start";
    case EventType::AttackEnd: return "attack_end";
    case EventType::AttackRetired: return "attack_retired";
    case EventType::AttackVisualEnd: return "attack_visual_end";
    case EventType::Bonus: return "bonus";
    case EventType::BlockImpact: return "block_impact";
    case EventType::Bounce: return "bounce";
    case EventType::ClipGroupEnd: return "clip_group_end";
    case EventType::ClipGroup: return "clip_group";
    case EventType::CombatDamage: return "combat_damage";
    case EventType::CombatPlayerDamage: return "combat_player_damage";
    case EventType::CriticalHit: return "critical_hit";
    case EventType::DebrisTrail: return "debris_trail";
    case EventType::DrawStart: return "draw_start";
    case EventType::Duplicate: return "duplicate";
    case EventType::EnemyRetire: return "enemy_retire";
    case EventType::GameOver: return "game_over";
    case EventType::GaugeFull: return "gauge_full";
    case EventType::Hit: return "hit";
    case EventType::HullScatter: return "hull_scatter";
    case EventType::Hurt: return "hurt";
    case EventType::Kill: return "kill";
    case EventType::Launch: return "launch";
    case EventType::LevelBonus: return "level_bonus";
    case EventType::Levelup: return "levelup";
    case EventType::Phase: return "phase";
    case EventType::Pickup: return "pickup";
    case EventType::Reroll: return "reroll";
    case EventType::ShieldBlock: return "shield_block";
    case EventType::ShieldExpired: return "shield_expired";
    case EventType::ShieldReflect: return "shield_reflect";
    case EventType::ShieldStolen: return "shield_stolen";
    case EventType::ShipDeath: return "ship_death";
    case EventType::ShipExplode: return "ship_explode";
    case EventType::ShotHit: return "shot_hit";
    case EventType::StrongSpawn: return "strong_spawn";
    case EventType::Text: return "text";
    case EventType::TimeLimitReached: return "time_limit_reached";
    case EventType::TraceEnd: return "trace_end";
    case EventType::Upgrade: return "upgrade";
    case EventType::Wave: return "wave";
    case EventType::WeaponFire: return "weapon_fire";
    case EventType::Offer: return "offer";
    case EventType::Choice: return "choice";
    case EventType::Loadout: return "loadout";
    case EventType::RunFinished: return "run_finished";
    case EventType::Crash: return "crash";
    case EventType::Ring: return "ring";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, EventType &out) {
    if (value=="attack_start") {out=EventType::AttackStart;return true;}
    if (value=="attack_end") {out=EventType::AttackEnd;return true;}
    if (value=="attack_retired") {out=EventType::AttackRetired;return true;}
    if (value=="attack_visual_end") {out=EventType::AttackVisualEnd;return true;}
    if (value=="bonus") {out=EventType::Bonus;return true;}
    if (value=="block_impact") {out=EventType::BlockImpact;return true;}
    if (value=="bounce") {out=EventType::Bounce;return true;}
    if (value=="clip_group_end") {out=EventType::ClipGroupEnd;return true;}
    if (value=="clip_group") {out=EventType::ClipGroup;return true;}
    if (value=="combat_damage") {out=EventType::CombatDamage;return true;}
    if (value=="combat_player_damage") {out=EventType::CombatPlayerDamage;return true;}
    if (value=="critical_hit") {out=EventType::CriticalHit;return true;}
    if (value=="debris_trail") {out=EventType::DebrisTrail;return true;}
    if (value=="draw_start") {out=EventType::DrawStart;return true;}
    if (value=="duplicate") {out=EventType::Duplicate;return true;}
    if (value=="enemy_retire") {out=EventType::EnemyRetire;return true;}
    if (value=="game_over") {out=EventType::GameOver;return true;}
    if (value=="gauge_full") {out=EventType::GaugeFull;return true;}
    if (value=="hit") {out=EventType::Hit;return true;}
    if (value=="hull_scatter") {out=EventType::HullScatter;return true;}
    if (value=="hurt") {out=EventType::Hurt;return true;}
    if (value=="kill") {out=EventType::Kill;return true;}
    if (value=="launch") {out=EventType::Launch;return true;}
    if (value=="level_bonus") {out=EventType::LevelBonus;return true;}
    if (value=="levelup") {out=EventType::Levelup;return true;}
    if (value=="phase") {out=EventType::Phase;return true;}
    if (value=="pickup") {out=EventType::Pickup;return true;}
    if (value=="reroll") {out=EventType::Reroll;return true;}
    if (value=="shield_block") {out=EventType::ShieldBlock;return true;}
    if (value=="shield_expired") {out=EventType::ShieldExpired;return true;}
    if (value=="shield_reflect") {out=EventType::ShieldReflect;return true;}
    if (value=="shield_stolen") {out=EventType::ShieldStolen;return true;}
    if (value=="ship_death") {out=EventType::ShipDeath;return true;}
    if (value=="ship_explode") {out=EventType::ShipExplode;return true;}
    if (value=="shot_hit") {out=EventType::ShotHit;return true;}
    if (value=="strong_spawn") {out=EventType::StrongSpawn;return true;}
    if (value=="text") {out=EventType::Text;return true;}
    if (value=="time_limit_reached") {out=EventType::TimeLimitReached;return true;}
    if (value=="trace_end") {out=EventType::TraceEnd;return true;}
    if (value=="upgrade") {out=EventType::Upgrade;return true;}
    if (value=="wave") {out=EventType::Wave;return true;}
    if (value=="weapon_fire") {out=EventType::WeaponFire;return true;}
    if (value=="offer") {out=EventType::Offer;return true;}
    if (value=="choice") {out=EventType::Choice;return true;}
    if (value=="loadout") {out=EventType::Loadout;return true;}
    if (value=="run_finished") {out=EventType::RunFinished;return true;}
    if (value=="crash") {out=EventType::Crash;return true;}
    if (value=="ring") {out=EventType::Ring;return true;}
    return false;
}
enum class ResultKind : uint32_t {Clear=0,Death=1,Abort=2,Count};
inline const char *symbol_name(ResultKind value) {
    switch(value) {
    case ResultKind::Clear: return "Clear";
    case ResultKind::Death: return "Death";
    case ResultKind::Abort: return "Abort";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, ResultKind &out) {
    if (value=="Clear") {out=ResultKind::Clear;return true;}
    if (value=="Death") {out=ResultKind::Death;return true;}
    if (value=="Abort") {out=ResultKind::Abort;return true;}
    return false;
}
enum class ContactShapeKind : uint32_t {PointCircle=0,SegmentCircle=1,SweptSegment=2,Polyline=3,Fan=4,RingBand=5,Rect=6,Count};
inline const char *symbol_name(ContactShapeKind value) {
    switch(value) {
    case ContactShapeKind::PointCircle: return "point_circle";
    case ContactShapeKind::SegmentCircle: return "segment_circle";
    case ContactShapeKind::SweptSegment: return "sweep_segment";
    case ContactShapeKind::Polyline: return "polyline";
    case ContactShapeKind::Fan: return "fan";
    case ContactShapeKind::RingBand: return "ring_band";
    case ContactShapeKind::Rect: return "rect";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, ContactShapeKind &out) {
    if (value=="point_circle") {out=ContactShapeKind::PointCircle;return true;}
    if (value=="segment_circle") {out=ContactShapeKind::SegmentCircle;return true;}
    if (value=="sweep_segment") {out=ContactShapeKind::SweptSegment;return true;}
    if (value=="polyline") {out=ContactShapeKind::Polyline;return true;}
    if (value=="fan") {out=ContactShapeKind::Fan;return true;}
    if (value=="ring_band") {out=ContactShapeKind::RingBand;return true;}
    if (value=="rect") {out=ContactShapeKind::Rect;return true;}
    return false;
}
enum class AttackCategory : uint32_t {Aimed=0,Homing=1,Dash=2,Beam=3,Zone=4,Wave=5,Residue=6,Count};
inline const char *symbol_name(AttackCategory value) {
    switch(value) {
    case AttackCategory::Aimed: return "aimed";
    case AttackCategory::Homing: return "homing";
    case AttackCategory::Dash: return "dash";
    case AttackCategory::Beam: return "beam";
    case AttackCategory::Zone: return "zone";
    case AttackCategory::Wave: return "wave";
    case AttackCategory::Residue: return "residue";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, AttackCategory &out) {
    if (value=="aimed") {out=AttackCategory::Aimed;return true;}
    if (value=="homing") {out=AttackCategory::Homing;return true;}
    if (value=="dash") {out=AttackCategory::Dash;return true;}
    if (value=="beam") {out=AttackCategory::Beam;return true;}
    if (value=="zone") {out=AttackCategory::Zone;return true;}
    if (value=="wave") {out=AttackCategory::Wave;return true;}
    if (value=="residue") {out=AttackCategory::Residue;return true;}
    return false;
}
enum class CardKind : uint32_t {Weapon=0,Trait=1,PostMax=2,Heal=3,Swap=4,Keep=5,Count};
inline const char *symbol_name(CardKind value) {
    switch(value) {
    case CardKind::Weapon: return "weapon";
    case CardKind::Trait: return "trait";
    case CardKind::PostMax: return "post_max";
    case CardKind::Heal: return "heal";
    case CardKind::Swap: return "swap";
    case CardKind::Keep: return "keep";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, CardKind &out) {
    if (value=="weapon") {out=CardKind::Weapon;return true;}
    if (value=="trait") {out=CardKind::Trait;return true;}
    if (value=="post_max") {out=CardKind::PostMax;return true;}
    if (value=="heal") {out=CardKind::Heal;return true;}
    if (value=="swap") {out=CardKind::Swap;return true;}
    if (value=="keep") {out=CardKind::Keep;return true;}
    return false;
}
enum class RockKind : uint32_t {Belt=0,Drift=1,Iron=2,Saw=3,Comet=4,Count};
inline const char *symbol_name(RockKind value) {
    switch(value) {
    case RockKind::Belt: return "belt";
    case RockKind::Drift: return "drift";
    case RockKind::Iron: return "iron";
    case RockKind::Saw: return "saw";
    case RockKind::Comet: return "comet";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, RockKind &out) {
    if (value=="belt") {out=RockKind::Belt;return true;}
    if (value=="drift") {out=RockKind::Drift;return true;}
    if (value=="iron") {out=RockKind::Iron;return true;}
    if (value=="saw") {out=RockKind::Saw;return true;}
    if (value=="comet") {out=RockKind::Comet;return true;}
    return false;
}
inline bool event_field_allowed(EventType type, std::string_view field) {
    switch(type) {
    case EventType::AttackStart: return field=="owner" || field=="row" || field=="id" || field=="categories" || field=="token";
    case EventType::AttackEnd: return field=="token" || field=="owner";
    case EventType::AttackRetired: return field=="pos" || field=="id" || field=="source_id" || field=="reason";
    case EventType::AttackVisualEnd: return field=="scene" || field=="phase" || field=="pos" || field=="visual_key";
    case EventType::Bonus: return field=="enter" || field=="pos";
    case EventType::BlockImpact: return field=="pos" || field=="normal" || field=="enemy_pos" || field=="r" || field=="armor_bounce";
    case EventType::Bounce: return field=="pos";
    case EventType::ClipGroupEnd: return field=="clip" || field=="key";
    case EventType::ClipGroup: return field=="clip" || field=="key" || field=="n";
    case EventType::CombatDamage: return field=="pos" || field=="target" || field=="struck_id" || field=="target_id" || field=="cause" || field=="weapon_id" || field=="requested" || field=="resolved" || field=="applied" || field=="overkill" || field=="discarded" || field=="hp_before" || field=="hp_after" || field=="reason" || field=="impact" || field=="shatter_depth";
    case EventType::CombatPlayerDamage: return field=="pos" || field=="cause" || field=="source" || field=="technique" || field=="requested" || field=="amount" || field=="accepted" || field=="reason" || field=="hp_before" || field=="hp_after";
    case EventType::CriticalHit: return field=="pos" || field=="enemy_pos" || field=="r" || field=="dir";
    case EventType::DebrisTrail: return field=="points" || field=="color";
    case EventType::DrawStart: return false;
    case EventType::Duplicate: return field=="pos" || field=="directions";
    case EventType::EnemyRetire: return field=="pos" || field=="id" || field=="reason" || field=="enemy_type";
    case EventType::GameOver: return false;
    case EventType::GaugeFull: return false;
    case EventType::Hit: return field=="pos" || field=="crit" || field=="dmg" || field=="cause" || field=="id";
    case EventType::HullScatter: return field=="pos" || field=="count";
    case EventType::Hurt: return field=="pos" || field=="amount" || field=="cause" || field=="source" || field=="hp_after";
    case EventType::Kill: return field=="pos" || field=="id" || field=="r" || field=="crit" || field=="enemy_type" || field=="meteor_index" || field=="facing" || field=="elite" || field=="cause" || field=="dir" || field=="color" || field=="silent";
    case EventType::Launch: return field=="pos" || field=="dir" || field=="gauge";
    case EventType::LevelBonus: return field=="kind" || field=="id" || field=="level" || field=="count";
    case EventType::Levelup: return field=="level";
    case EventType::Phase: return field=="id";
    case EventType::Pickup: return field=="kind";
    case EventType::Reroll: return false;
    case EventType::ShieldBlock: return field=="pos";
    case EventType::ShieldExpired: return field=="pos";
    case EventType::ShieldReflect: return field=="pos" || field=="normal";
    case EventType::ShieldStolen: return field=="pos" || field=="facing" || field=="r" || field=="arc" || field=="enemy_type";
    case EventType::ShipDeath: return field=="pos";
    case EventType::ShipExplode: return field=="pos";
    case EventType::ShotHit: return field=="pos" || field=="dir" || field=="visual_key" || field=="kind";
    case EventType::StrongSpawn: return field=="id" || field=="enemy_type";
    case EventType::Text: return field=="pos" || field=="text" || field=="color" || field=="size";
    case EventType::TimeLimitReached: return false;
    case EventType::TraceEnd: return field=="completed";
    case EventType::Upgrade: return field=="card";
    case EventType::Wave: return false;
    case EventType::WeaponFire: return field=="id" || field=="pos" || field=="angle" || field=="visual_key";
    case EventType::Offer: return field=="offer_id" || field=="initial" || field=="count";
    case EventType::Choice: return field=="offer_id" || field=="candidate_id" || field=="kind" || field=="id" || field=="level";
    case EventType::Loadout: return field=="kind" || field=="id" || field=="level";
    case EventType::RunFinished: return field=="result_id" || field=="kind";
    case EventType::Crash: return field=="pos" || field=="power";
    case EventType::Ring: return field=="pos" || field=="radius" || field=="color" || field=="life";
    default: return false;
    }
}
}
