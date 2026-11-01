// 共通スキーマから生成。直接編集しない。
#pragma once
#include <cstdint>
#include <string_view>
namespace speed {
enum class Cause : uint32_t {None=0,Ram=1,Touch=2,Bump=3,Shot=4,Debris=5,Fire=6,Blast=7,Afterimage=8,FinalStrike=9,Debug=10,Missile=11,Homing=12,Slash=13,Wave=14,Chain=15,PumpBurst=16,Marlin=17,Collapse=18,Rain=19,ArrowShower=20,InhaleBite=21,SwordFlash=22,HoundLunge=23,Pounce=24,FlameJet=25,Bullet=26,Reflected=27,Count};
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
    return false;
}
}
