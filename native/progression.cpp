#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;
namespace {
double number(const Dictionary &d, const char *key, double fallback=0) { return d.get(key,fallback); }
bool numeric(const Variant &v) { return (v.get_type()==Variant::FLOAT || v.get_type()==Variant::INT) && std::isfinite(double(v)); }
Dictionary card(StringName kind, StringName id, int64_t level, bool initial=false, double weight=1) {
    Dictionary c; c["kind"]=kind; c["id"]=id; c["level"]=level;
    if (initial) c["start"]=true; else c["weight"]=weight;
    return c;
}
}
bool SpeedRunCore::configure_progression(const Dictionary &data) {
    if (started || closed || !ship_ready || data.get("version",Variant())!=Variant(1)) return false;
    for (const char *key : {"config","profile","bonuses","forward"}) if (data.get(key,Variant()).get_type()!=Variant::DICTIONARY) return false;
    for (const char *key : {"weapons","traits"}) {
        if (data.get(key,Variant()).get_type()!=Variant::ARRAY) return false;
        const Array rows=data[key]; std::unordered_set<std::string> ids;
        for (int i=0;i<rows.size();++i) {
            if (rows[i].get_type()!=Variant::DICTIONARY) return false;
            const Dictionary row=rows[i]; const Variant id=row.get("id",Variant());
            if ((id.get_type()!=Variant::STRING_NAME && id.get_type()!=Variant::STRING) || String(id).is_empty() || !ids.insert(String(id).utf8().get_data()).second || row.get("comet_only",Variant()).get_type()!=Variant::BOOL) return false;
        }
    }
    const Dictionary c=data["config"];
    const char *keys[]={"xp_base","xp_growth","xp_curve","level_heal","weapon_slots","trait_slots","weapon_max_level","trait_max_stacks","start_weapon_choices","owned_card_bias","reroll_count","levelup_bonus_chance","levelup_bonus_more","levelup_bonus_last","fallback_heal","base_max_speed","base_hp","dash_charge_time","base_crit_chance","crit_mult","pickup_radius","steer_accel","steer_rate","invuln_time","meteor_heal_frac"};
    for (const char *key:keys) if (!numeric(c.get(key,Variant())) || number(c,key)<0) return false;
    if (number(c,"xp_base")<=0 || number(c,"base_hp")<=0 || number(c,"dash_charge_time")<=0) return false;
    for (const char *key:{"weapon_slots","trait_slots","weapon_max_level","trait_max_stacks","start_weapon_choices","reroll_count"}) if (std::floor(number(c,key))!=number(c,key)) return false;
    const Dictionary profile=data["profile"];
    for (const char *key:{"mult","add","reduce"}) {
        if (profile.get(key,Variant()).get_type()!=Variant::DICTIONARY) return false;
        const Dictionary row=profile[key]; const Array values=row.values();
        for (int i=0;i<values.size();++i) if (!numeric(values[i]) || double(values[i])<0) return false;
    }
    const Dictionary bonuses=data["bonuses"]; const Array traits=data["traits"];
    for (int i=0;i<traits.size();++i) {
        const StringName id=Dictionary(traits[i])["id"];
        if (bonuses.get(id,Variant()).get_type()!=Variant::ARRAY) return false;
        const Array values=bonuses[id]; if (values.size()!=int64_t(number(c,"trait_max_stacks"))+1) return false;
        for (int j=0;j<values.size();++j) if (!numeric(values[j]) || double(values[j])<0) return false;
    }
    if (!numeric(data.get("crit_max",Variant())) || !numeric(data.get("character_scale",Variant())) || double(data["character_scale"])<=0 || data.get("rerolls",Variant()).get_type()!=Variant::INT || int64_t(data["rerolls"])<0) return false;
    const ForwardWeapon previous=forward;
    const bool forward_valid=configure_forward(data["forward"],1,data["character_scale"]); forward=previous;
    if (!forward_valid) return false;
    Progression parsed; parsed.data=data.duplicate(true); parsed.rerolls=data["rerolls"]; parsed.ready=true;
    progression=parsed; refresh_progression_stats(); return true;
}
void SpeedRunCore::refresh_progression_stats() {
    auto &p=progression; const Dictionary c=p.data["config"], profile=p.data["profile"], mult=profile["mult"], add=profile["add"], reduce=profile["reduce"], bonuses=p.data["bonuses"];
    auto bonus=[&](const char *id) { const Array values=bonuses.get(id,Array()); const int64_t n=p.traits.get(id,0); return values.is_empty()?0.0:double(values[std::min(n,values.size()-1)]); };
    const double old_max=number(p.stats,"max_hp"); Dictionary s;
    s["max_speed"]=number(c,"base_max_speed")*number(mult,"max_speed",1)*(1+bonus("T10"));
    s["attack_mult"]=number(mult,"attack",1)*(1+bonus("T11")); s["max_hp"]=number(c,"base_hp")+number(add,"max_hp");
    s["capacity"]=1+bonus("T08"); s["charge_time"]=number(c,"dash_charge_time")*number(reduce,"charge_time",1)/(1+bonus("T07"));
    s["crit_chance"]=std::min(double(p.data["crit_max"]),number(c,"base_crit_chance")+bonus("T09")); s["crit_mult"]=number(c,"crit_mult");
    s["pickup_radius"]=number(c,"pickup_radius")*number(mult,"pickup",1)*(1+bonus("T12")); s["xp_pickup_radius"]=s["pickup_radius"];
    s["length_mult"]=number(mult,"length",1)*(1+bonus("T14")); s["glide_duration_mult"]=1+bonus("T31");
    s["xp_mult"]=number(mult,"xp",1); s["xp_gain_mult"]=1.0;
    s["acceleration"]=number(c,"steer_accel"); s["turn_rate"]=number(c,"steer_rate"); s["invulnerability"]=number(c,"invuln_time");
    s["repair_fraction"]=number(c,"meteor_heal_frac"); s["pickup_speed_mult"]=1.0;
    const double maximum=s["max_hp"]; if (old_max>0 && maximum>old_max) ship.hp+=maximum-old_max; ship.hp=std::min(ship.hp,maximum);
    p.stats=s; apply_stat_values(s);
}
void SpeedRunCore::apply_stat_values(const Dictionary &s) {
    ship_config.max_hp=s["max_hp"]; ship_config.max_speed=s["max_speed"]; ship_config.acceleration=s["acceleration"]; ship_config.turn_rate=s["turn_rate"]; ship_config.glide_duration_mult=s["glide_duration_mult"]; ship_config.invulnerability=s["invulnerability"];
    draw_config.capacity=s["capacity"]; draw_config.charge_time=s["charge_time"]; draw_config.length_mult=s["length_mult"];
    combat_config.attack_mult=s["attack_mult"]; combat_config.crit_chance=s["crit_chance"]; combat_config.crit_mult=s["crit_mult"];
    pickup_config.xp_mult=s["xp_mult"]; pickup_config.xp_radius=s["xp_pickup_radius"]; pickup_config.coin_radius=s["pickup_radius"]; pickup_config.speed_mult=s["pickup_speed_mult"];
}
bool SpeedRunCore::grant_equipment(StringName kind, StringName id, int64_t levels) {
    if (!started || closed || !progression.ready || levels<1 || (kind!=StringName("weapon") && kind!=StringName("trait"))) return false;
    auto &p=progression; const bool weapon=kind==StringName("weapon"); const Array definitions=p.data[weapon?"weapons":"traits"];
    bool found=false; for (int i=0;i<definitions.size();++i) if (StringName(Dictionary(definitions[i])["id"])==id) found=true;
    if (!found) return false;
    Dictionary owned=weapon?p.weapons:p.traits; const Dictionary c=p.data["config"];
    const int64_t lv=owned.get(id,0), maximum=c[weapon?"weapon_max_level":"trait_max_stacks"], slots=c[weapon?"weapon_slots":"trait_slots"];
    if ((lv==0 && owned.size()>=slots) || lv>=maximum) return false;
    owned[id]=std::min(maximum, lv+std::min(levels,maximum));
    // W01の同じ実体の発射待ち時間を保って編集値だけ更新する。
    if (weapon && id==StringName("W01")) {
        const Dictionary params=p.data["forward"]; const int64_t index=int64_t(owned[id])-1;
        const Array intervals=params["interval_by_level"], damages=params["damage_by_level"], pierces=params["pierce_by_level"];
        forward.interval=intervals[std::min(index,intervals.size()-1)]; forward.damage=damages[std::min(index,damages.size()-1)]; forward.pierce=int64_t(pierces[std::min(index,pierces.size()-1)]);
        forward.life=params["life"]; forward.spread=params["spread_step"]; forward.knock=params["knock"]; forward.character_scale=p.data["character_scale"]; forward.ready=true;
    }
    refresh_progression_stats(); return true;
}
bool SpeedRunCore::add_xp(double amount) {
    if (!started || closed || !progression.ready || !std::isfinite(amount) || amount<0) return false;
    auto &p=progression; const Dictionary c=p.data["config"];
    amount*=number(p.stats,"xp_gain_mult",1); if (!std::isfinite(p.xp+amount) || !std::isfinite(p.gained+amount)) return false;
    p.xp+=amount; p.gained+=amount;
    auto needed=[&]() { const double l=p.level; return number(c,"xp_base")+number(c,"xp_growth")*l+number(c,"xp_curve")*l*l; };
    while (p.xp>=needed()) {
        p.xp-=needed(); ++p.level; ++p.pending_levels; ship.hp=std::min(ship_config.max_hp,ship.hp+ship_config.max_hp*number(c,"level_heal"));
        Dictionary level; level["level"]=p.level; emit_event("levelup",level);
        Dictionary text; text["pos"]=ship.pos+Vector2(0,-34); text["text"]=String("Lv ")+String::num_int64(p.level); text["color"]=Color::html("6dffb0"); text["size"]=18; emit_event("text",text);
        refresh_progression_stats();
    }
    return true;
}
Array SpeedRunCore::roll_cards(bool initial) {
    auto &p=progression; const Dictionary c=p.data["config"]; Array pool,out;
    for (const char *kind:{"weapon","trait"}) {
        if (initial && String(kind)=="trait") break;
        const bool weapon=String(kind)=="weapon"; const Array definitions=p.data[weapon?"weapons":"traits"]; const Dictionary owned=weapon?p.weapons:p.traits;
        const int64_t slots=c[weapon?"weapon_slots":"trait_slots"], maximum=c[weapon?"weapon_max_level":"trait_max_stacks"];
        for (int i=0;i<definitions.size();++i) {
            const Dictionary def=definitions[i]; const StringName id=def["id"]; const int64_t lv=owned.get(id,0);
            if (weapon && bool(def["comet_only"])) continue;
            if (!initial && (lv>=maximum || (lv==0 && owned.size()>=slots))) continue;
            pool.append(card(kind,id,initial?1:lv+1,initial,lv>0?number(c,"owned_card_bias"):1));
        }
    }
    const int64_t count=initial?int64_t(c["start_weapon_choices"]):3;
    while (out.size()<count && !pool.is_empty()) {
        int64_t index=0;
        if (initial) index=rng->randi_range(0,pool.size()-1);
        else {
            double total=0; for (int i=0;i<pool.size();++i) total+=double(Dictionary(pool[i])["weight"]);
            double roll=rng->randf()*total;
            while (index<pool.size()-1 && roll>=double(Dictionary(pool[index])["weight"])) { roll-=double(Dictionary(pool[index])["weight"]); ++index; }
        }
        out.append(pool[index]); pool.remove_at(index);
    }
    return out;
}
void SpeedRunCore::publish_cards() {
    auto &p=progression; ++p.revision; p.pending_choice=-1; p.resource_status.clear(); p.resource_requests.clear();
    for (int i=0;i<p.cards.size();++i) {
        const Dictionary c=p.cards[i]; const StringName id=c["id"];
        if (p.resource_status.has(id)) continue;
        p.resource_status[id]=0; Dictionary request; request["revision"]=p.revision; request["id"]=id; request["category"]=StringName(c["kind"])==StringName("weapon")?"weapons":"traits"; p.resource_requests.append(request);
    }
    phase=Phase::LevelUp; hitstop=0;
}
bool SpeedRunCore::open_cards(bool initial) {
    if (!started || closed || !progression.ready || draw.drawing || draw.tracing || !progression.cards.is_empty() || (phase!=Phase::Play && phase!=Phase::LevelUp)) return false;
    auto &p=progression; if (!initial && p.pending_levels<=0) return false;
    p.cards=roll_cards(initial); if (p.cards.is_empty()) { p.pending_levels=0; return false; }
    p.start_pick=initial; publish_cards(); return true;
}
bool SpeedRunCore::reroll_cards() {
    if (!started || closed || !progression.ready || progression.cards.is_empty() || progression.rerolls<=0) return false;
    progression.cards=roll_cards(progression.start_pick); --progression.rerolls; emit_event("reroll"); publish_cards(); return true;
}
void SpeedRunCore::level_bonus() {
    auto &p=progression; const Dictionary c=p.data["config"]; int count=0;
    for (const char *chance:{"levelup_bonus_chance","levelup_bonus_more","levelup_bonus_last"}) {
        if (rng->randf()>=number(c,chance)) return;
        Array choices;
        for (const char *kind:{"weapon","trait"}) {
            const bool weapon=String(kind)=="weapon"; const Dictionary owned=weapon?p.weapons:p.traits; const Array ids=owned.keys(); const int64_t maximum=c[weapon?"weapon_max_level":"trait_max_stacks"];
            for (int i=0;i<ids.size();++i) if (int64_t(owned[ids[i]])<maximum) choices.append(card(kind,ids[i],0));
        }
        if (choices.is_empty()) return;
        const Dictionary picked=choices[rng->randi_range(0,choices.size()-1)]; const StringName kind=picked["kind"], id=picked["id"];
        grant_equipment(kind,id,1); Dictionary event; event["kind"]=kind; event["id"]=id; event["level"]=(kind==StringName("weapon")?p.weapons:p.traits)[id]; event["count"]=++count; emit_event("level_bonus",event);
    }
}
bool SpeedRunCore::apply_card(int64_t index) {
    auto &p=progression; const Dictionary c=p.cards[index]; const bool initial=p.start_pick;
    if (!grant_equipment(c["kind"],c["id"],1)) return false;
    p.start_pick=false;
    if (!initial) { Dictionary event; event["card"]=c.duplicate(true); emit_event("upgrade",event); level_bonus(); p.pending_levels=std::max(int64_t(0),p.pending_levels-1); }
    p.cards.clear(); p.resource_status.clear(); p.pending_choice=-1; ++p.revision; phase=Phase::Play;
    if (!initial && p.pending_levels>0) open_cards(false);
    return true;
}
bool SpeedRunCore::choose_card(int64_t index, int64_t revision) {
    if (!started || closed || !progression.ready || phase!=Phase::LevelUp || revision!=progression.revision || index<0 || index>=progression.cards.size()) return false;
    auto &p=progression; const StringName id=Dictionary(p.cards[index])["id"]; const int status=p.resource_status[id];
    if (status<0) { p.pending_choice=-1; return false; }
    if (status==0) { p.pending_choice=index; return true; }
    return apply_card(index);
}
bool SpeedRunCore::resources_ready(int64_t revision, StringName id, int64_t status) {
    if (!started || closed || !progression.ready || revision!=progression.revision || !progression.resource_status.has(id) || (status!=1 && status!=-1 && status!=-2)) return false;
    auto &p=progression; if (p.resource_status[id]!=0) return false; p.resource_status[id]=status;
    if (p.pending_choice>=0 && StringName(Dictionary(p.cards[p.pending_choice])["id"])==id) {
        const int64_t index=p.pending_choice; p.pending_choice=-1;
        if (status==1) return apply_card(index);
    }
    return true;
}
Array SpeedRunCore::drain_resource_requests() { Array out=progression.resource_requests; progression.resource_requests=Array(); return out; }
Dictionary SpeedRunCore::progression_snapshot() const {
    const auto &p=progression; Dictionary out;
    out["level"]=p.level; out["xp"]=p.xp; out["xp_gained"]=p.gained; out["pending_levels"]=p.pending_levels; out["rerolls_left"]=p.rerolls;
    out["start_pick"]=p.start_pick; out["weapons"]=p.weapons.duplicate(true); out["traits"]=p.traits.duplicate(true); out["stats"]=p.stats.duplicate(true); out["cards"]=p.cards.duplicate(true);
    out["revision"]=p.revision; out["pending_choice"]=p.pending_choice; out["ship_hp"]=ship.hp; return out;
}

int64_t SpeedRunCore::random_state() const { return rng.is_valid()?int64_t(rng->get_state()):0; }
bool SpeedRunCore::apply_external_progression(const Dictionary &stats, double hp, bool waiting, int64_t random_state) {
    if (!started || closed || progression.ready || !ship_ready || (phase!=Phase::Play && phase!=Phase::LevelUp) || !std::isfinite(hp) || hp<0) return false;
    for (const char *key:{"max_hp","max_speed","acceleration","turn_rate","glide_duration_mult","invulnerability","capacity","charge_time","length_mult","attack_mult","crit_chance","crit_mult","xp_mult","xp_pickup_radius","pickup_radius","pickup_speed_mult"})
        if (!numeric(stats.get(key,Variant())) || double(stats[key])<0) return false;
    if (double(stats["max_hp"])<=0 || double(stats["capacity"])<=0 || double(stats["charge_time"])<=0 || hp>double(stats["max_hp"])) return false;
    apply_stat_values(stats); ship.hp=hp; phase=waiting?Phase::LevelUp:Phase::Play; rng->set_state(uint64_t(random_state)); return true;
}

int64_t SpeedRunCore::progression_revision() const { return progression.revision; }
