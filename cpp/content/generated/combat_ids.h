// 共通スキーマから生成。直接編集しない。
#pragma once
#include <cstdint>
#include <string_view>
namespace speed {
enum class Cause : uint32_t {None=0,Ram=1,Touch=2,Bump=3,Shot=4,Debris=5,Fire=6,Blast=7,Afterimage=8,FinalStrike=9,Debug=10,Missile=11,Homing=12,Slash=13,Wave=14,Chain=15,PumpBurst=16,Marlin=17,Collapse=18,Rain=19,ArrowShower=20,InhaleBite=21,SwordFlash=22,HoundLunge=23,Pounce=24,FlameJet=25,Bullet=26,Reflected=27,HullDebris=28,Saw=29,Beam=30,Wall=31,Bolt=32,Arrow=33,StarBolt=34,Barrier=35,Corpse=36,TowShot=37,Interceptor=38,EndBlast=39,CritBeam=40,RunUp=41,Mine=42,Vortex=43,Horn=44,CoronaThrow=45,ContactWave=46,Sonic=47,ContactArc=48,KillSonic=49,HornWave=50,Bipolar=51,DashRangeDrone=52,Finale=53,FlashSlash=54,RearAttack=55,SiriusFlame=56,SiriusTrail=57,Stomp=58,Count};
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
    case Cause::Beam: return "beam";
    case Cause::Wall: return "wall";
    case Cause::Bolt: return "bolt";
    case Cause::Arrow: return "arrow";
    case Cause::StarBolt: return "star_bolt";
    case Cause::Barrier: return "barrier";
    case Cause::Corpse: return "corpse";
    case Cause::TowShot: return "towShot";
    case Cause::Interceptor: return "interceptor";
    case Cause::EndBlast: return "endBlast";
    case Cause::CritBeam: return "critBeam";
    case Cause::RunUp: return "runUp";
    case Cause::Mine: return "mine";
    case Cause::Vortex: return "vortex";
    case Cause::Horn: return "horn";
    case Cause::CoronaThrow: return "corona_throw";
    case Cause::ContactWave: return "contactWave";
    case Cause::Sonic: return "sonic";
    case Cause::ContactArc: return "contactArc";
    case Cause::KillSonic: return "killSonic";
    case Cause::HornWave: return "horn_wave";
    case Cause::Bipolar: return "bipolar";
    case Cause::DashRangeDrone: return "dashRangeDrone";
    case Cause::Finale: return "finale";
    case Cause::FlashSlash: return "flashSlash";
    case Cause::RearAttack: return "rear_attack";
    case Cause::SiriusFlame: return "sirius_flame";
    case Cause::SiriusTrail: return "sirius_trail";
    case Cause::Stomp: return "stomp";
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
    if (value=="beam") {out=Cause::Beam;return true;}
    if (value=="wall") {out=Cause::Wall;return true;}
    if (value=="bolt") {out=Cause::Bolt;return true;}
    if (value=="arrow") {out=Cause::Arrow;return true;}
    if (value=="star_bolt") {out=Cause::StarBolt;return true;}
    if (value=="barrier") {out=Cause::Barrier;return true;}
    if (value=="corpse") {out=Cause::Corpse;return true;}
    if (value=="towShot") {out=Cause::TowShot;return true;}
    if (value=="interceptor") {out=Cause::Interceptor;return true;}
    if (value=="endBlast") {out=Cause::EndBlast;return true;}
    if (value=="critBeam") {out=Cause::CritBeam;return true;}
    if (value=="runUp") {out=Cause::RunUp;return true;}
    if (value=="mine") {out=Cause::Mine;return true;}
    if (value=="vortex") {out=Cause::Vortex;return true;}
    if (value=="horn") {out=Cause::Horn;return true;}
    if (value=="corona_throw") {out=Cause::CoronaThrow;return true;}
    if (value=="contactWave") {out=Cause::ContactWave;return true;}
    if (value=="sonic") {out=Cause::Sonic;return true;}
    if (value=="contactArc") {out=Cause::ContactArc;return true;}
    if (value=="killSonic") {out=Cause::KillSonic;return true;}
    if (value=="horn_wave") {out=Cause::HornWave;return true;}
    if (value=="bipolar") {out=Cause::Bipolar;return true;}
    if (value=="dashRangeDrone") {out=Cause::DashRangeDrone;return true;}
    if (value=="finale") {out=Cause::Finale;return true;}
    if (value=="flashSlash") {out=Cause::FlashSlash;return true;}
    if (value=="rear_attack") {out=Cause::RearAttack;return true;}
    if (value=="sirius_flame") {out=Cause::SiriusFlame;return true;}
    if (value=="sirius_trail") {out=Cause::SiriusTrail;return true;}
    if (value=="stomp") {out=Cause::Stomp;return true;}
    return false;
}
enum class VisualRole : uint32_t {EnemySprite=0,Ship=1,ForwardShot=2,Crystal=3,Coin=4,Cannon=5,EnemyLook=6,Equipment=7,AttackScene=8,Planet=9,Moon=10,HostileShot=11,StoneShot=12,ReflectedShot=13,EnemyPolygon=14,StarBolt=15,BossFinish=16,Count};
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
    case VisualRole::HostileShot: return "hostile_shot";
    case VisualRole::StoneShot: return "stone_shot";
    case VisualRole::ReflectedShot: return "reflected_shot";
    case VisualRole::EnemyPolygon: return "enemy_polygon";
    case VisualRole::StarBolt: return "star_bolt";
    case VisualRole::BossFinish: return "boss_finish";
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
    if (value=="hostile_shot") {out=VisualRole::HostileShot;return true;}
    if (value=="stone_shot") {out=VisualRole::StoneShot;return true;}
    if (value=="reflected_shot") {out=VisualRole::ReflectedShot;return true;}
    if (value=="enemy_polygon") {out=VisualRole::EnemyPolygon;return true;}
    if (value=="star_bolt") {out=VisualRole::StarBolt;return true;}
    if (value=="boss_finish") {out=VisualRole::BossFinish;return true;}
    return false;
}
enum class EventType : uint32_t {AttackStart=0,AttackEnd=1,AttackRetired=2,AttackVisualEnd=3,Bonus=4,BlockImpact=5,Bounce=6,ClipGroupEnd=7,ClipGroup=8,CombatDamage=9,CombatPlayerDamage=10,CriticalHit=11,DebrisTrail=12,DrawStart=13,Duplicate=14,EnemyRetire=15,GameOver=16,GaugeFull=17,Hit=18,HullScatter=19,Hurt=20,Kill=21,Launch=22,LevelBonus=23,Levelup=24,Phase=25,Pickup=26,Reroll=27,ShieldBlock=28,ShieldExpired=29,ShieldReflect=30,ShieldStolen=31,ShipDeath=32,ShipExplode=33,ShotHit=34,StrongSpawn=35,Text=36,TimeLimitReached=37,TraceEnd=38,Upgrade=39,Wave=40,WeaponFire=41,Offer=42,Choice=43,Loadout=44,RunFinished=45,Crash=46,Ring=47,Shoot=48,EnemyLaserCharge=49,EnemyLaserFire=50,EnemyLaserCancel=51,CrystalDrop=52,CrystalGoldRoll=53,GemBurst=54,CrystalAbsorb=55,CrystalAbsorber=56,CrystalTransfer=57,CrystalLost=58,CrystalCollect=59,BarrierHit=60,BarrierRestore=61,TelescopeCharge=62,TelescopeFire=63,Explode=64,FullBurstReady=65,FloodEnd=66,Beam=67,CriticalLance=68,CriticalLanceHit=69,RockBreak=70,RunUpHit=71,EndHole=72,HoleCapture=73,HoleRecover=74,AquariusAim=75,BomberExplode=76,SummonMark=77,CepheusSummon=78,RulerSplit=79,BossSpawn=80,BossPhase=81,BossDefeated=82,BossCancelled=83,FinalStrike=84,Swallow=85,SpaceQuake=86,SonicPush=87,SonicImpact=88,ContactBolt=89,LanceLaunch=90,SonicBoom=91,LanceShatter=92,ChainShock=93,WaveRelease=94,AnchorCapture=95,AnchorFire=96,BipolarCharge=97,RouteOpportunity=98,EncounterDeferred=99,SlashRelease=100,EscortDeploy=101,EscortSlash=102,EnemyTuningChanged=103,EnemyTuningSaved=104,BossFinish=105,BossExplode=106,ClearBanner=107,SlashMark=108,FlashSlash=109,MonocerosSlashRelease=110,HeroDiscovered=111,HeroLink=112,HeroFreed=113,HeroPower=114,HeroPowerEnd=115,Landmark=116,TwinFirst=117,CentaurusCue=118,CanisIgniteArrived=119,CanisCue=120,Count};
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
    case EventType::Shoot: return "shoot";
    case EventType::EnemyLaserCharge: return "enemy_laser_charge";
    case EventType::EnemyLaserFire: return "enemy_laser_fire";
    case EventType::EnemyLaserCancel: return "enemy_laser_cancel";
    case EventType::CrystalDrop: return "xp_drop";
    case EventType::CrystalGoldRoll: return "xp_gold_roll";
    case EventType::GemBurst: return "gem_burst";
    case EventType::CrystalAbsorb: return "xp_absorb";
    case EventType::CrystalAbsorber: return "xp_absorber";
    case EventType::CrystalTransfer: return "xp_transfer";
    case EventType::CrystalLost: return "xp_lost";
    case EventType::CrystalCollect: return "xp_collect";
    case EventType::BarrierHit: return "barrier_hit";
    case EventType::BarrierRestore: return "barrier_restore";
    case EventType::TelescopeCharge: return "telescope_charge";
    case EventType::TelescopeFire: return "telescope_fire";
    case EventType::Explode: return "explode";
    case EventType::FullBurstReady: return "full_burst_ready";
    case EventType::FloodEnd: return "flood_end";
    case EventType::Beam: return "beam";
    case EventType::CriticalLance: return "critical_lance";
    case EventType::CriticalLanceHit: return "critical_lance_hit";
    case EventType::RockBreak: return "rock_break";
    case EventType::RunUpHit: return "run_up_hit";
    case EventType::EndHole: return "end_hole";
    case EventType::HoleCapture: return "hole_capture";
    case EventType::HoleRecover: return "hole_recover";
    case EventType::AquariusAim: return "aquarius_aim";
    case EventType::BomberExplode: return "bomber_explode";
    case EventType::SummonMark: return "summon_mark";
    case EventType::CepheusSummon: return "cepheus_summon";
    case EventType::RulerSplit: return "ruler_split";
    case EventType::BossSpawn: return "boss_spawn";
    case EventType::BossPhase: return "boss_phase";
    case EventType::BossDefeated: return "boss_defeated";
    case EventType::BossCancelled: return "boss_cancelled";
    case EventType::FinalStrike: return "final_strike";
    case EventType::Swallow: return "swallow";
    case EventType::SpaceQuake: return "space_quake";
    case EventType::SonicPush: return "sonic_push";
    case EventType::SonicImpact: return "sonic_impact";
    case EventType::ContactBolt: return "bolt";
    case EventType::LanceLaunch: return "lance_launch";
    case EventType::SonicBoom: return "sonic_boom";
    case EventType::LanceShatter: return "lance_shatter";
    case EventType::ChainShock: return "chain_shock";
    case EventType::WaveRelease: return "wave_release";
    case EventType::AnchorCapture: return "anchor_capture";
    case EventType::AnchorFire: return "anchor_fire";
    case EventType::BipolarCharge: return "bipolar_charge";
    case EventType::RouteOpportunity: return "route_opportunity";
    case EventType::EncounterDeferred: return "encounter_deferred";
    case EventType::SlashRelease: return "slash_release";
    case EventType::EscortDeploy: return "escort_deploy";
    case EventType::EscortSlash: return "escort_slash";
    case EventType::EnemyTuningChanged: return "enemy_tuning_changed";
    case EventType::EnemyTuningSaved: return "enemy_tuning_saved";
    case EventType::BossFinish: return "boss_finish";
    case EventType::BossExplode: return "boss_explode";
    case EventType::ClearBanner: return "clear_banner";
    case EventType::SlashMark: return "slash_mark";
    case EventType::FlashSlash: return "flash_slash";
    case EventType::MonocerosSlashRelease: return "monoceros_slash_release";
    case EventType::HeroDiscovered: return "hero_discovered";
    case EventType::HeroLink: return "hero_link";
    case EventType::HeroFreed: return "hero_freed";
    case EventType::HeroPower: return "hero_power";
    case EventType::HeroPowerEnd: return "hero_power_end";
    case EventType::Landmark: return "landmark";
    case EventType::TwinFirst: return "twin_first";
    case EventType::CentaurusCue: return "centaurus_cue";
    case EventType::CanisIgniteArrived: return "canis_ignite_arrived";
    case EventType::CanisCue: return "canis_cue";
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
    if (value=="shoot") {out=EventType::Shoot;return true;}
    if (value=="enemy_laser_charge") {out=EventType::EnemyLaserCharge;return true;}
    if (value=="enemy_laser_fire") {out=EventType::EnemyLaserFire;return true;}
    if (value=="enemy_laser_cancel") {out=EventType::EnemyLaserCancel;return true;}
    if (value=="xp_drop") {out=EventType::CrystalDrop;return true;}
    if (value=="xp_gold_roll") {out=EventType::CrystalGoldRoll;return true;}
    if (value=="gem_burst") {out=EventType::GemBurst;return true;}
    if (value=="xp_absorb") {out=EventType::CrystalAbsorb;return true;}
    if (value=="xp_absorber") {out=EventType::CrystalAbsorber;return true;}
    if (value=="xp_transfer") {out=EventType::CrystalTransfer;return true;}
    if (value=="xp_lost") {out=EventType::CrystalLost;return true;}
    if (value=="xp_collect") {out=EventType::CrystalCollect;return true;}
    if (value=="barrier_hit") {out=EventType::BarrierHit;return true;}
    if (value=="barrier_restore") {out=EventType::BarrierRestore;return true;}
    if (value=="telescope_charge") {out=EventType::TelescopeCharge;return true;}
    if (value=="telescope_fire") {out=EventType::TelescopeFire;return true;}
    if (value=="explode") {out=EventType::Explode;return true;}
    if (value=="full_burst_ready") {out=EventType::FullBurstReady;return true;}
    if (value=="flood_end") {out=EventType::FloodEnd;return true;}
    if (value=="beam") {out=EventType::Beam;return true;}
    if (value=="critical_lance") {out=EventType::CriticalLance;return true;}
    if (value=="critical_lance_hit") {out=EventType::CriticalLanceHit;return true;}
    if (value=="rock_break") {out=EventType::RockBreak;return true;}
    if (value=="run_up_hit") {out=EventType::RunUpHit;return true;}
    if (value=="end_hole") {out=EventType::EndHole;return true;}
    if (value=="hole_capture") {out=EventType::HoleCapture;return true;}
    if (value=="hole_recover") {out=EventType::HoleRecover;return true;}
    if (value=="aquarius_aim") {out=EventType::AquariusAim;return true;}
    if (value=="bomber_explode") {out=EventType::BomberExplode;return true;}
    if (value=="summon_mark") {out=EventType::SummonMark;return true;}
    if (value=="cepheus_summon") {out=EventType::CepheusSummon;return true;}
    if (value=="ruler_split") {out=EventType::RulerSplit;return true;}
    if (value=="boss_spawn") {out=EventType::BossSpawn;return true;}
    if (value=="boss_phase") {out=EventType::BossPhase;return true;}
    if (value=="boss_defeated") {out=EventType::BossDefeated;return true;}
    if (value=="boss_cancelled") {out=EventType::BossCancelled;return true;}
    if (value=="final_strike") {out=EventType::FinalStrike;return true;}
    if (value=="swallow") {out=EventType::Swallow;return true;}
    if (value=="space_quake") {out=EventType::SpaceQuake;return true;}
    if (value=="sonic_push") {out=EventType::SonicPush;return true;}
    if (value=="sonic_impact") {out=EventType::SonicImpact;return true;}
    if (value=="bolt") {out=EventType::ContactBolt;return true;}
    if (value=="lance_launch") {out=EventType::LanceLaunch;return true;}
    if (value=="sonic_boom") {out=EventType::SonicBoom;return true;}
    if (value=="lance_shatter") {out=EventType::LanceShatter;return true;}
    if (value=="chain_shock") {out=EventType::ChainShock;return true;}
    if (value=="wave_release") {out=EventType::WaveRelease;return true;}
    if (value=="anchor_capture") {out=EventType::AnchorCapture;return true;}
    if (value=="anchor_fire") {out=EventType::AnchorFire;return true;}
    if (value=="bipolar_charge") {out=EventType::BipolarCharge;return true;}
    if (value=="route_opportunity") {out=EventType::RouteOpportunity;return true;}
    if (value=="encounter_deferred") {out=EventType::EncounterDeferred;return true;}
    if (value=="slash_release") {out=EventType::SlashRelease;return true;}
    if (value=="escort_deploy") {out=EventType::EscortDeploy;return true;}
    if (value=="escort_slash") {out=EventType::EscortSlash;return true;}
    if (value=="enemy_tuning_changed") {out=EventType::EnemyTuningChanged;return true;}
    if (value=="enemy_tuning_saved") {out=EventType::EnemyTuningSaved;return true;}
    if (value=="boss_finish") {out=EventType::BossFinish;return true;}
    if (value=="boss_explode") {out=EventType::BossExplode;return true;}
    if (value=="clear_banner") {out=EventType::ClearBanner;return true;}
    if (value=="slash_mark") {out=EventType::SlashMark;return true;}
    if (value=="flash_slash") {out=EventType::FlashSlash;return true;}
    if (value=="monoceros_slash_release") {out=EventType::MonocerosSlashRelease;return true;}
    if (value=="hero_discovered") {out=EventType::HeroDiscovered;return true;}
    if (value=="hero_link") {out=EventType::HeroLink;return true;}
    if (value=="hero_freed") {out=EventType::HeroFreed;return true;}
    if (value=="hero_power") {out=EventType::HeroPower;return true;}
    if (value=="hero_power_end") {out=EventType::HeroPowerEnd;return true;}
    if (value=="landmark") {out=EventType::Landmark;return true;}
    if (value=="twin_first") {out=EventType::TwinFirst;return true;}
    if (value=="centaurus_cue") {out=EventType::CentaurusCue;return true;}
    if (value=="canis_ignite_arrived") {out=EventType::CanisIgniteArrived;return true;}
    if (value=="canis_cue") {out=EventType::CanisCue;return true;}
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
enum class RenderShapeKind : uint32_t {Polyline=0,Circle=1,Wave=2,Blast=3,LightArrow=4,FriendDebris=5,FriendHull=6,Zone=7,Flood=8,Shell=9,Count};
inline const char *symbol_name(RenderShapeKind value) {
    switch(value) {
    case RenderShapeKind::Polyline: return "polyline";
    case RenderShapeKind::Circle: return "circle";
    case RenderShapeKind::Wave: return "wave";
    case RenderShapeKind::Blast: return "blast";
    case RenderShapeKind::LightArrow: return "light_arrow";
    case RenderShapeKind::FriendDebris: return "friend_debris";
    case RenderShapeKind::FriendHull: return "friend_hull";
    case RenderShapeKind::Zone: return "zone";
    case RenderShapeKind::Flood: return "flood";
    case RenderShapeKind::Shell: return "shell";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, RenderShapeKind &out) {
    if (value=="polyline") {out=RenderShapeKind::Polyline;return true;}
    if (value=="circle") {out=RenderShapeKind::Circle;return true;}
    if (value=="wave") {out=RenderShapeKind::Wave;return true;}
    if (value=="blast") {out=RenderShapeKind::Blast;return true;}
    if (value=="light_arrow") {out=RenderShapeKind::LightArrow;return true;}
    if (value=="friend_debris") {out=RenderShapeKind::FriendDebris;return true;}
    if (value=="friend_hull") {out=RenderShapeKind::FriendHull;return true;}
    if (value=="zone") {out=RenderShapeKind::Zone;return true;}
    if (value=="flood") {out=RenderShapeKind::Flood;return true;}
    if (value=="shell") {out=RenderShapeKind::Shell;return true;}
    return false;
}
enum class ContactShapeKind : uint32_t {PointCircle=0,SegmentCircle=1,SweptSegment=2,Polyline=3,Fan=4,RingBand=5,Rect=6,TaperedBeam=7,Count};
inline const char *symbol_name(ContactShapeKind value) {
    switch(value) {
    case ContactShapeKind::PointCircle: return "point_circle";
    case ContactShapeKind::SegmentCircle: return "segment_circle";
    case ContactShapeKind::SweptSegment: return "sweep_segment";
    case ContactShapeKind::Polyline: return "polyline";
    case ContactShapeKind::Fan: return "fan";
    case ContactShapeKind::RingBand: return "ring_band";
    case ContactShapeKind::Rect: return "rect";
    case ContactShapeKind::TaperedBeam: return "tapered_beam";
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
    if (value=="tapered_beam") {out=ContactShapeKind::TaperedBeam;return true;}
    return false;
}
enum class HostileKind : uint32_t {Bullet=0,Missile=1,Reflected=2,Slash=3,Bolt=4,LightArrow=5,CosmicArrow=6,StarBolt=7,Shell=8,Count};
inline const char *symbol_name(HostileKind value) {
    switch(value) {
    case HostileKind::Bullet: return "bullet";
    case HostileKind::Missile: return "missile";
    case HostileKind::Reflected: return "reflected";
    case HostileKind::Slash: return "slash";
    case HostileKind::Bolt: return "bolt";
    case HostileKind::LightArrow: return "light_arrow";
    case HostileKind::CosmicArrow: return "cosmic_arrow";
    case HostileKind::StarBolt: return "star_bolt";
    case HostileKind::Shell: return "shell";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, HostileKind &out) {
    if (value=="bullet") {out=HostileKind::Bullet;return true;}
    if (value=="missile") {out=HostileKind::Missile;return true;}
    if (value=="reflected") {out=HostileKind::Reflected;return true;}
    if (value=="slash") {out=HostileKind::Slash;return true;}
    if (value=="bolt") {out=HostileKind::Bolt;return true;}
    if (value=="light_arrow") {out=HostileKind::LightArrow;return true;}
    if (value=="cosmic_arrow") {out=HostileKind::CosmicArrow;return true;}
    if (value=="star_bolt") {out=HostileKind::StarBolt;return true;}
    if (value=="shell") {out=HostileKind::Shell;return true;}
    return false;
}
enum class FriendKind : uint32_t {Shot=0,Debris=1,Hull=2,Count};
inline const char *symbol_name(FriendKind value) {
    switch(value) {
    case FriendKind::Shot: return "shot";
    case FriendKind::Debris: return "debris";
    case FriendKind::Hull: return "hull";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, FriendKind &out) {
    if (value=="shot") {out=FriendKind::Shot;return true;}
    if (value=="debris") {out=FriendKind::Debris;return true;}
    if (value=="hull") {out=FriendKind::Hull;return true;}
    return false;
}
enum class BeamStyle : uint32_t {Plain=0,Guide=1,Telescope=2,Flood=3,Count};
inline const char *symbol_name(BeamStyle value) {
    switch(value) {
    case BeamStyle::Plain: return "plain";
    case BeamStyle::Guide: return "guide";
    case BeamStyle::Telescope: return "telescope";
    case BeamStyle::Flood: return "flood";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, BeamStyle &out) {
    if (value=="plain") {out=BeamStyle::Plain;return true;}
    if (value=="guide") {out=BeamStyle::Guide;return true;}
    if (value=="telescope") {out=BeamStyle::Telescope;return true;}
    if (value=="flood") {out=BeamStyle::Flood;return true;}
    return false;
}
enum class WaveStyle : uint32_t {Plain=0,Ripple=1,Lightning=2,Pulser=3,Count};
inline const char *symbol_name(WaveStyle value) {
    switch(value) {
    case WaveStyle::Plain: return "plain";
    case WaveStyle::Ripple: return "ripple";
    case WaveStyle::Lightning: return "lightning";
    case WaveStyle::Pulser: return "pulser";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, WaveStyle &out) {
    if (value=="plain") {out=WaveStyle::Plain;return true;}
    if (value=="ripple") {out=WaveStyle::Ripple;return true;}
    if (value=="lightning") {out=WaveStyle::Lightning;return true;}
    if (value=="pulser") {out=WaveStyle::Pulser;return true;}
    return false;
}
enum class WallStyle : uint32_t {Plain=0,Trail=1,Ray=2,Lightning=3,Count};
inline const char *symbol_name(WallStyle value) {
    switch(value) {
    case WallStyle::Plain: return "plain";
    case WallStyle::Trail: return "trail";
    case WallStyle::Ray: return "ray";
    case WallStyle::Lightning: return "lightning";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, WallStyle &out) {
    if (value=="plain") {out=WallStyle::Plain;return true;}
    if (value=="trail") {out=WallStyle::Trail;return true;}
    if (value=="ray") {out=WallStyle::Ray;return true;}
    if (value=="lightning") {out=WallStyle::Lightning;return true;}
    return false;
}
enum class DebrisStyle : uint32_t {Plain=0,Stardust=1,Pump=2,Count};
inline const char *symbol_name(DebrisStyle value) {
    switch(value) {
    case DebrisStyle::Plain: return "plain";
    case DebrisStyle::Stardust: return "stardust";
    case DebrisStyle::Pump: return "pump";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, DebrisStyle &out) {
    if (value=="plain") {out=DebrisStyle::Plain;return true;}
    if (value=="stardust") {out=DebrisStyle::Stardust;return true;}
    if (value=="pump") {out=DebrisStyle::Pump;return true;}
    return false;
}
enum class ZoneStyle : uint32_t {Plain=0,Reticle=1,Lightning=2,Bite=3,Aquila=4,Phoenix=5,Bomber=6,Pump=7,Count};
inline const char *symbol_name(ZoneStyle value) {
    switch(value) {
    case ZoneStyle::Plain: return "plain";
    case ZoneStyle::Reticle: return "reticle";
    case ZoneStyle::Lightning: return "lightning";
    case ZoneStyle::Bite: return "bite";
    case ZoneStyle::Aquila: return "aquila";
    case ZoneStyle::Phoenix: return "phoenix";
    case ZoneStyle::Bomber: return "bomber";
    case ZoneStyle::Pump: return "pump";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, ZoneStyle &out) {
    if (value=="plain") {out=ZoneStyle::Plain;return true;}
    if (value=="reticle") {out=ZoneStyle::Reticle;return true;}
    if (value=="lightning") {out=ZoneStyle::Lightning;return true;}
    if (value=="bite") {out=ZoneStyle::Bite;return true;}
    if (value=="aquila") {out=ZoneStyle::Aquila;return true;}
    if (value=="phoenix") {out=ZoneStyle::Phoenix;return true;}
    if (value=="bomber") {out=ZoneStyle::Bomber;return true;}
    if (value=="pump") {out=ZoneStyle::Pump;return true;}
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
enum class SpawnOrigin : uint32_t {Normal=0,Refill=1,Summon=2,Split=3,BossPart=4,HeroLandmark=5,DevPlacement=6,Count};
inline const char *symbol_name(SpawnOrigin value) {
    switch(value) {
    case SpawnOrigin::Normal: return "normal";
    case SpawnOrigin::Refill: return "refill";
    case SpawnOrigin::Summon: return "summon";
    case SpawnOrigin::Split: return "split";
    case SpawnOrigin::BossPart: return "boss_part";
    case SpawnOrigin::HeroLandmark: return "hero_landmark";
    case SpawnOrigin::DevPlacement: return "dev_placement";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, SpawnOrigin &out) {
    if (value=="normal") {out=SpawnOrigin::Normal;return true;}
    if (value=="refill") {out=SpawnOrigin::Refill;return true;}
    if (value=="summon") {out=SpawnOrigin::Summon;return true;}
    if (value=="split") {out=SpawnOrigin::Split;return true;}
    if (value=="boss_part") {out=SpawnOrigin::BossPart;return true;}
    if (value=="hero_landmark") {out=SpawnOrigin::HeroLandmark;return true;}
    if (value=="dev_placement") {out=SpawnOrigin::DevPlacement;return true;}
    return false;
}
enum class SpawnRole : uint32_t {Regular=0,Terrain=1,BossBody=2,BossPart=3,Count};
inline const char *symbol_name(SpawnRole value) {
    switch(value) {
    case SpawnRole::Regular: return "regular";
    case SpawnRole::Terrain: return "terrain";
    case SpawnRole::BossBody: return "boss_body";
    case SpawnRole::BossPart: return "boss_part";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, SpawnRole &out) {
    if (value=="regular") {out=SpawnRole::Regular;return true;}
    if (value=="terrain") {out=SpawnRole::Terrain;return true;}
    if (value=="boss_body") {out=SpawnRole::BossBody;return true;}
    if (value=="boss_part") {out=SpawnRole::BossPart;return true;}
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
enum class FriendHitKind : uint32_t {None=0,Interceptor=1,Count};
inline const char *symbol_name(FriendHitKind value) {
    switch(value) {
    case FriendHitKind::None: return "none";
    case FriendHitKind::Interceptor: return "interceptor";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, FriendHitKind &out) {
    if (value=="none") {out=FriendHitKind::None;return true;}
    if (value=="interceptor") {out=FriendHitKind::Interceptor;return true;}
    return false;
}
enum class HydraHeadKind : uint32_t {Bite=0,Vortex=1,Debris=2,Beam=3,Thunder=4,Count};
inline const char *symbol_name(HydraHeadKind value) {
    switch(value) {
    case HydraHeadKind::Bite: return "bite";
    case HydraHeadKind::Vortex: return "vortex";
    case HydraHeadKind::Debris: return "debris";
    case HydraHeadKind::Beam: return "beam";
    case HydraHeadKind::Thunder: return "thunder";
    default: return "";
    }
}
inline bool parse_symbol(std::string_view value, HydraHeadKind &out) {
    if (value=="bite") {out=HydraHeadKind::Bite;return true;}
    if (value=="vortex") {out=HydraHeadKind::Vortex;return true;}
    if (value=="debris") {out=HydraHeadKind::Debris;return true;}
    if (value=="beam") {out=HydraHeadKind::Beam;return true;}
    if (value=="thunder") {out=HydraHeadKind::Thunder;return true;}
    return false;
}
inline bool event_field_allowed(EventType type, std::string_view field) {
    switch(type) {
    case EventType::AttackStart: return field=="owner" || field=="row" || field=="id" || field=="categories" || field=="token";
    case EventType::AttackEnd: return field=="token" || field=="owner";
    case EventType::AttackRetired: return field=="pos" || field=="id" || field=="source_id" || field=="reason";
    case EventType::AttackVisualEnd: return field=="scene" || field=="phase" || field=="pos" || field=="visual_key" || field=="duration" || field=="tint";
    case EventType::Bonus: return field=="enter" || field=="pos";
    case EventType::BlockImpact: return field=="pos" || field=="normal" || field=="enemy_pos" || field=="r" || field=="armor_bounce";
    case EventType::Bounce: return field=="pos";
    case EventType::ClipGroupEnd: return field=="clip" || field=="key";
    case EventType::ClipGroup: return field=="clip" || field=="key" || field=="n";
    case EventType::CombatDamage: return field=="pos" || field=="target" || field=="struck_id" || field=="target_id" || field=="cause" || field=="weapon_id" || field=="requested" || field=="resolved" || field=="applied" || field=="overkill" || field=="discarded" || field=="hp_before" || field=="hp_after" || field=="reason" || field=="impact" || field=="shatter_depth";
    case EventType::CombatPlayerDamage: return field=="pos" || field=="cause" || field=="source" || field=="technique" || field=="requested" || field=="amount" || field=="accepted" || field=="reason" || field=="hp_before" || field=="hp_after";
    case EventType::CriticalHit: return field=="pos" || field=="enemy_pos" || field=="r" || field=="dir";
    case EventType::DebrisTrail: return field=="points" || field=="color" || field=="life";
    case EventType::DrawStart: return false;
    case EventType::Duplicate: return field=="pos" || field=="directions";
    case EventType::EnemyRetire: return field=="pos" || field=="id" || field=="reason" || field=="enemy_type" || field=="spawn_origin" || field=="spawn_role";
    case EventType::GameOver: return false;
    case EventType::GaugeFull: return false;
    case EventType::Hit: return field=="pos" || field=="crit" || field=="dmg" || field=="cause" || field=="id";
    case EventType::HullScatter: return field=="pos" || field=="count" || field=="visual_key";
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
    case EventType::TimeLimitReached: return field=="t";
    case EventType::TraceEnd: return field=="completed";
    case EventType::Upgrade: return field=="card";
    case EventType::Wave: return false;
    case EventType::WeaponFire: return field=="id" || field=="pos" || field=="angle" || field=="visual_key";
    case EventType::Offer: return field=="offer_id" || field=="initial" || field=="count";
    case EventType::Choice: return field=="offer_id" || field=="candidate_id" || field=="kind" || field=="id" || field=="level";
    case EventType::Loadout: return field=="kind" || field=="id" || field=="level";
    case EventType::RunFinished: return field=="result_id" || field=="kind";
    case EventType::Crash: return field=="pos" || field=="power";
    case EventType::Ring: return field=="pos" || field=="radius" || field=="color" || field=="life" || field=="visual_key";
    case EventType::Shoot: return field=="pos" || field=="kind";
    case EventType::EnemyLaserCharge: return field=="id" || field=="row";
    case EventType::EnemyLaserFire: return field=="id";
    case EventType::EnemyLaserCancel: return field=="id";
    case EventType::CrystalDrop: return field=="id" || field=="kind" || field=="base_xp" || field=="source" || field=="enemy" || field=="enemy_id" || field=="spawn_t" || field=="spawn_world_t" || field=="pos" || field=="new_supply" || field=="ground_count" || field=="carrier_id" || field=="origin" || field=="xp";
    case EventType::CrystalGoldRoll: return field=="enemy" || field=="enemy_id" || field=="chance" || field=="won";
    case EventType::GemBurst: return field=="pos" || field=="r";
    case EventType::CrystalAbsorb: return field=="id" || field=="kind" || field=="base_xp" || field=="source" || field=="enemy" || field=="enemy_id" || field=="spawn_t" || field=="spawn_world_t" || field=="new_supply" || field=="target_id" || field=="target_kind" || field=="before_base_xp" || field=="after_base_xp" || field=="requested_pos" || field=="ground_count" || field=="carrier_id" || field=="origin" || field=="xp";
    case EventType::CrystalAbsorber: return field=="reason" || field=="id" || field=="previous_id" || field=="before_kind" || field=="after_kind" || field=="before_base_xp" || field=="after_base_xp";
    case EventType::CrystalTransfer: return field=="id" || field=="kind" || field=="base_xp" || field=="method" || field=="enemy_id" || field=="enemy" || field=="spawn_t" || field=="spawn_world_t" || field=="was_absorber" || field=="origin" || field=="xp";
    case EventType::CrystalLost: return field=="id" || field=="kind" || field=="base_xp" || field=="method" || field=="enemy_id" || field=="enemy" || field=="spawn_t" || field=="spawn_world_t" || field=="reason" || field=="origin" || field=="xp";
    case EventType::CrystalCollect: return field=="method" || field=="base_xp" || field=="xp" || field=="actual_xp" || field=="multiplier" || field=="count" || field=="gems" || field=="id" || field=="kind" || field=="origin";
    case EventType::BarrierHit: return field=="pos" || field=="hit" || field=="angle" || field=="radius" || field=="broken";
    case EventType::BarrierRestore: return field=="pos";
    case EventType::TelescopeCharge: return field=="pos";
    case EventType::TelescopeFire: return field=="pos" || field=="angle" || field=="length" || field=="width";
    case EventType::Explode: return field=="pos" || field=="radius" || field=="cause" || field=="color" || field=="life";
    case EventType::FullBurstReady: return field=="pos";
    case EventType::FloodEnd: return field=="id" || field=="row" || field=="pos" || field=="angle" || field=="length" || field=="width" || field=="spread" || field=="age" || field=="tail" || field=="collapse" || field=="margin";
    case EventType::Beam: return field=="from" || field=="to" || field=="width" || field=="life" || field=="color" || field=="visual_key" || field=="width_scale";
    case EventType::CriticalLance: return field=="from" || field=="to" || field=="width";
    case EventType::CriticalLanceHit: return field=="pos" || field=="radius" || field=="direction";
    case EventType::RockBreak: return field=="pos" || field=="r" || field=="meteor_index" || field=="facing" || field=="dir" || field=="color";
    case EventType::RunUpHit: return field=="pos" || field=="dir" || field=="strength";
    case EventType::EndHole: return field=="pos" || field=="life";
    case EventType::HoleCapture: return field=="pos" || field=="radius" || field=="enemy_type" || field=="color" || field=="facing";
    case EventType::HoleRecover: return field=="pos" || field=="amount";
    case EventType::AquariusAim: return field=="pos" || field=="angle" || field=="count" || field=="length" || field=="width" || field=="spread" || field=="delay" || field=="active" || field=="color" || field=="row" || field=="id";
    case EventType::BomberExplode: return field=="pos";
    case EventType::SummonMark: return field=="pos" || field=="king" || field=="life" || field=="color";
    case EventType::CepheusSummon: return field=="pos" || field=="color";
    case EventType::RulerSplit: return field=="pos" || field=="angle" || field=="color";
    case EventType::BossSpawn: return field=="pos";
    case EventType::BossPhase: return field=="id" || field=="boss" || field=="phase" || field=="reason";
    case EventType::BossDefeated: return field=="pos" || field=="id" || field=="dir" || field=="cause";
    case EventType::BossCancelled: return field=="id" || field=="boss";
    case EventType::FinalStrike: return field=="t";
    case EventType::Swallow: return field=="enemy_type" || field=="pos" || field=="r" || field=="facing" || field=="color" || field=="row" || field=="id" || field=="visual_id" || field=="sprite_radius" || field=="sprite_angle";
    case EventType::SpaceQuake: return field=="pos" || field=="radius" || field=="life";
    case EventType::SonicPush: return field=="pos" || field=="dir" || field=="row" || field=="id";
    case EventType::SonicImpact: return field=="pos" || field=="dir" || field=="dead";
    case EventType::ContactBolt: return field=="segments";
    case EventType::LanceLaunch: return field=="pos" || field=="direction" || field=="horn" || field=="head_length";
    case EventType::SonicBoom: return field=="pos" || field=="direction" || field=="horn" || field=="head_length";
    case EventType::LanceShatter: return field=="pos" || field=="direction" || field=="horn" || field=="head_length";
    case EventType::ChainShock: return field=="pos" || field=="radius" || field=="life" || field=="generation";
    case EventType::WaveRelease: return field=="pos";
    case EventType::AnchorCapture: return field=="pos" || field=="to";
    case EventType::AnchorFire: return field=="pos" || field=="dir" || field=="radius";
    case EventType::BipolarCharge: return field=="from" || field=="to";
    case EventType::RouteOpportunity: return field=="route" || field=="status" || field=="start" || field=="window" || field=="margin";
    case EventType::EncounterDeferred: return field=="reason";
    case EventType::SlashRelease: return field=="path" || field=="count" || field=="sweep" || field=="pause";
    case EventType::EscortDeploy: return field=="pos" || field=="targets";
    case EventType::EscortSlash: return field=="pos" || field=="dir";
    case EventType::EnemyTuningChanged: return field=="values";
    case EventType::EnemyTuningSaved: return field=="path" || field=="values";
    case EventType::BossFinish: return field=="pos";
    case EventType::BossExplode: return field=="pos";
    case EventType::ClearBanner: return false;
    case EventType::SlashMark: return field=="pos" || field=="radius" || field=="id" || field=="dash";
    case EventType::FlashSlash: return field=="pos" || field=="length" || field=="width" || field=="id" || field=="dash" || field=="cut";
    case EventType::MonocerosSlashRelease: return field=="line" || field=="width";
    case EventType::HeroDiscovered: return field=="id";
    case EventType::HeroLink: return field=="from" || field=="to";
    case EventType::HeroFreed: return field=="id" || field=="pos";
    case EventType::HeroPower: return field=="id" || field=="pos";
    case EventType::HeroPowerEnd: return field=="id";
    case EventType::Landmark: return field=="pos";
    case EventType::TwinFirst: return false;
    case EventType::CentaurusCue: return field=="id" || field=="technique" || field=="cue" || field=="position" || field=="angle" || field=="world_time";
    case EventType::CanisIgniteArrived: return field=="id" || field=="boss_id" || field=="target" || field=="profile" || field=="pos" || field=="from" || field=="life" || field=="observation";
    case EventType::CanisCue: return field=="id" || field=="technique" || field=="cue" || field=="position" || field=="angle" || field=="world_time";
    default: return false;
    }
}
}
