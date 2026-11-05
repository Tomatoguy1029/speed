#include "run_core.h"
#include "../systems/heroes.h"
#include "../runtime/run_runner.h"
#include "../content/content_bundle.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary result(bool ok) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"hero";out["message"]=ok?"":"英雄の試行入力が不正です";out["value"]=Variant();return out;}
bool point(const Dictionary &p,const char *key) {return p.has(key) && p[key].get_type()==Variant::VECTOR2 && Vector2(p[key]).is_finite();}
}
Dictionary SpeedRunCore::development_hero_command(const String &kind,const Dictionary &p) {
    if (!runtime.api_development) return result(false);
    if (kind=="dev_set_hero" && p.size()==1 && p.get("id",Variant()).get_type()==Variant::STRING) {
        if (String(p["id"]).is_empty()) {speed::HeroesSystem::select_power(runtime,0);return result(true);}
        for (const auto &hero:runtime.content->heroes) if (String::utf8(hero.definition.external_id.c_str())==String(p["id"])) {speed::HeroesSystem::select_power(runtime,hero.definition.id);return result(true);}return result(false);
    }
    if (kind=="dev_hero_place" && p.size()==1 && p.get("id",Variant()).get_type()==Variant::STRING) {
        for (const auto &hero:runtime.content->heroes) if (String::utf8(hero.definition.external_id.c_str())==String(p["id"])) {speed::HeroesSystem::place(runtime,hero.definition.id);return result(true);}return result(false);
    }
    if (kind=="dev_hero_pass" && p.size()==3 && point(p,"from") && point(p,"to") && p.get("dash",Variant()).get_type()==Variant::INT && int64_t(p["dash"])>=0) {speed::HeroesSystem::pass_stars(runtime,p["from"],p["to"],p["dash"]);return result(true);}
    if (kind=="dev_tick_heroes" && p.size()==2 && p.get("dt",Variant()).get_type()==Variant::FLOAT && p.get("run_time",Variant()).get_type()==Variant::FLOAT && std::isfinite(double(p["dt"])) && double(p["dt"])>=0 && std::isfinite(double(p["run_time"])) && double(p["run_time"])>=0) {runtime.state.time=p["run_time"];speed::RunRunner::camera(*this,0,Vector2(1280,720));speed::HeroesSystem::step(runtime,p["dt"],0);return result(true);}
    if (kind=="dev_hero_activate" && p.is_empty()) {speed::HeroesSystem::activate(runtime);return result(true);}
    return result(false);
}
