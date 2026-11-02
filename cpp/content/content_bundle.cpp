#include "content_bundle.h"
#include "../bosses/flow/flow_runner.h"
#include <godot_cpp/classes/hashing_context.hpp>
#include <algorithm>
#include <cstring>
#include <cmath>
#include <limits>
#include <unordered_set>
namespace speed {
std::shared_ptr<const ContentBundle> ContentBundle::read(const godot::PackedByteArray &bytes) {
    constexpr uint64_t header_size=88, table_entry_size=32;
    if (uint64_t(bytes.size())<header_size || std::memcmp(bytes.ptr(),"SPDRUN01",8)) return {};
    BinaryReader header(bytes.ptr()+8,bytes.size()-8);
    uint32_t version,abi,count,reserved;
    if (!header.read_u32(version) || !header.read_u32(abi) || !header.read_u32(count) || !header.read_u32(reserved) ||
        version!=FORMAT_VERSION || abi!=ABI_VERSION || count!=SECTION_COUNT || reserved) return {};
    const uint64_t payload_begin=header_size+uint64_t(count)*table_entry_size;
    if (payload_begin>uint64_t(bytes.size())) return {};
    godot::PackedByteArray payload; payload.resize(bytes.size()-payload_begin);
    if (payload.size()) std::memcpy(payload.ptrw(),bytes.ptr()+payload_begin,payload.size());
    godot::Ref<godot::HashingContext> hash;hash.instantiate();
    if (hash->start(godot::HashingContext::HASH_SHA256)!=godot::OK || hash->update(payload)!=godot::OK) return {};
    auto signature=hash->finish();
    if (signature.size()!=32 || std::memcmp(signature.ptr(),bytes.ptr()+56,32)) return {};
    BinaryReader table(bytes.ptr()+header_size,count*table_entry_size);
    struct Section { uint32_t kind,version,count;uint64_t offset,length; };
    std::vector<Section> sections;
    std::unordered_set<uint32_t> kinds;
    for (uint32_t i=0;i<count;++i) {
        Section section;uint32_t zero;
        if (!table.read_u32(section.kind) || !table.read_u32(section.version) || !table.read_u64(section.offset) ||
            !table.read_u64(section.length) || !table.read_u32(section.count) || !table.read_u32(zero) || zero ||
            section.kind<1 || !kinds.insert(section.kind).second ||
            section.offset<payload_begin || section.offset>uint64_t(bytes.size()) || section.length>uint64_t(bytes.size())-section.offset) return {};
        sections.push_back(section);
    }
    std::sort(sections.begin(),sections.end(),[](const auto &a,const auto &b){return a.offset<b.offset || (a.offset==b.offset && a.length<b.length);});
    uint64_t end=payload_begin;
    ContentRecords records;
    for (const auto &section:sections) {
        if (section.offset!=end) return {};
        end=section.offset+section.length;
        BinaryReader reader(bytes.ptr()+section.offset,section.length);
        if (!read_section(section.kind,section.version,section.count,reader,records)) return {};
    }
    if (end!=uint64_t(bytes.size()) || !validate_references(records) || records.RunConfig_rows.size()!=1 ||
        records.RunConfig_rows[0].aim_lag<=0 || records.RunConfig_rows[0].aim_speed<=0 ||
        records.DefinitionIndex_rows.size()!=records.EnemyRecord_rows.size()) return {};
    auto bundle=std::make_shared<ContentBundle>();
    std::copy(bytes.ptr()+24,bytes.ptr()+56,bundle->input_sha256.begin());
    std::copy(bytes.ptr()+56,bytes.ptr()+88,bundle->payload_sha256.begin());
    bundle->config=records.RunConfig_rows[0];
    if (records.HeroConfig_rows.size()!=1) return {};
    bundle->hero_config=records.HeroConfig_rows.front();
    bundle->perseus=records.PerseusDefinition_rows;
    bundle->leo=records.LeoDefinition_rows;
    bundle->gemini=records.GeminiDefinition_rows;
    bundle->hercules=records.HerculesDefinition_rows;
    if (bundle->hero_config.first_max<bundle->hero_config.first_min || bundle->hero_config.second_max<bundle->hero_config.second_min) return {};
    std::unordered_set<std::string> hero_names;
    for (const auto &row:records.HeroDefinition_rows) {
        if (row.id!=bundle->heroes.size()+1 || row.external_id.empty() || !hero_names.insert(row.external_id).second) return {};
        bundle->heroes.push_back({row,{},{}});
    }
    for (const auto &row:records.HeroStar_rows) bundle->heroes[row.hero-1].stars.emplace_back(row.x,row.y);
    for (const auto &row:records.HeroLink_rows) {
        auto &hero=bundle->heroes[row.hero-1];
        if (row.a>=hero.stars.size() || row.b>=hero.stars.size()) return {};
        hero.links.emplace_back(row.a,row.b);
    }
    for (const auto &hero:bundle->heroes) {
        if (hero.stars.empty() || hero.links.empty()) return {};
        const auto count=std::count_if(bundle->perseus.begin(),bundle->perseus.end(),[&](const auto &p){return p.hero==hero.definition.id;});
        if (count!=(hero.definition.external_id=="perseus"?1:0)) return {};
        if (std::count_if(bundle->hercules.begin(),bundle->hercules.end(),[&](const auto &p){return p.hero==hero.definition.id;})!=(hero.definition.external_id=="hercules"?1:0)) return {};
        if (std::count_if(bundle->gemini.begin(),bundle->gemini.end(),[&](const auto &p){return p.hero==hero.definition.id;})!=(hero.definition.external_id=="gemini"?1:0)) return {};
        if (std::count_if(bundle->leo.begin(),bundle->leo.end(),[&](const auto &p){return p.hero==hero.definition.id;})!=(hero.definition.external_id=="leo"?1:0)) return {};
    }

    bundle->aim_lag=records.RunConfig_rows[0].aim_lag;bundle->aim_speed=records.RunConfig_rows[0].aim_speed;
    bundle->crystal_values={records.RunConfig_rows[0].crystal_low,records.RunConfig_rows[0].crystal_mid,records.RunConfig_rows[0].crystal_high};
    bundle->visuals=records.ResourceKey_rows;
    bundle->forward_levels=records.ForwardDefinition_rows;
    bundle->scatter_levels=records.ScatterDefinition_rows;
    if (records.ScatterPostDefinition_rows.size()!=1) return {};
    bundle->scatter_post=records.ScatterPostDefinition_rows.front();
    bundle->rear_levels=records.RearDefinition_rows;
    if (records.RearPostDefinition_rows.size()!=1) return {};
    bundle->rear_post=records.RearPostDefinition_rows.front();
    bundle->knockback_levels=records.KnockbackDefinition_rows;
    bundle->mines_levels=records.MinesDefinition_rows;
    bundle->contact_arc_levels=records.ContactArcDefinition_rows;
    bundle->mass_tow_levels=records.MassTowDefinition_rows;
    bundle->bipolar_levels=records.BipolarDefinition_rows;
    bundle->interceptor_levels=records.InterceptorDefinition_rows;
    bundle->escort_levels=records.DashRangeDroneDefinition_rows;
    bundle->afterimage_levels=records.AfterimageDefinition_rows;
    bundle->flash_slash_levels=records.FlashSlashDefinition_rows;
    bundle->sonic_levels=records.SonicDefinition_rows;
    bundle->contact_wave_levels=records.ContactWaveDefinition_rows;
    bundle->end_blast_levels=records.EndBlastDefinition_rows;
    bundle->barrier_levels=records.BarrierDefinition_rows;
    if (records.BarrierPostDefinition_rows.size()!=1) return {};
    bundle->barrier_post=records.BarrierPostDefinition_rows.front();
    bundle->bites=records.BiteDefinition_rows;
    bundle->hounds=records.HoundDefinition_rows;
    bundle->gunners=records.GunnerDefinition_rows;
    bundle->beamers=records.BeamerDefinition_rows;
    bundle->missile_enemies=records.MissileEnemyDefinition_rows;
    bundle->rockets=records.RocketDefinition_rows;
    bundle->drifts=records.DriftDefinition_rows;
    bundle->dashes=records.DashDefinition_rows;
    bundle->battleships=records.BattleshipDefinition_rows;
    bundle->snipers=records.SniperDefinition_rows;
    bundle->marlins=records.MarlinDefinition_rows;
    bundle->pulsers=records.PulserDefinition_rows;
    bundle->dolphins=records.DolphinDefinition_rows;
    bundle->reticles=records.ReticleDefinition_rows;bundle->aquarius=records.AquariusDefinition_rows;bundle->cross_enemies=records.CrossEnemyDefinition_rows;bundle->bombers=records.BomberDefinition_rows;bundle->phoenixes=records.PhoenixDefinition_rows;bundle->aquilas=records.AquilaDefinition_rows;
    bundle->splits=records.SplitDefinition_rows;
    bundle->defenders=records.DefenderDefinition_rows;
    bundle->crabs=records.CrabDefinition_rows;
    bundle->crows=records.CrowDefinition_rows;
    bundle->boss_flows=records.BossFlowProgram_rows;
    bundle->flow_sections=records.BossFlowSection_rows;
    bundle->flow_conditions=records.BossFlowCondition_rows;
    bundle->flow_nodes=records.BossFlowNode_rows;
    bundle->flow_children=records.BossFlowChild_rows;
    bundle->flow_actions=records.BossFlowAction_rows;
    bundle->flow_filters=records.BossFlowFilter_rows;
    bundle->flow_weights=records.BossFlowWeight_rows;
    bundle->flow_forbidden=records.BossFlowForbidden_rows;
    bundle->canis_bodies=records.CanisBodyDefinition_rows;
    bundle->canis_commands=records.CanisCommandDefinition_rows;
    bundle->canis_howls=records.CanisHowlDefinition_rows;
    bundle->canis_flames=records.CanisFlameDefinition_rows;
    for (size_t i=0;i<bundle->canis_flames.size();++i) {const auto &p=bundle->canis_flames[i];if (p.id!=i+1 || records.BossDefinition_rows[p.boss-1].kind!=2 || p.particle_life<=0 || p.duration<=0) return {};}
    bundle->boss_bodies=records.BossBodyDefinition_rows;
    bundle->centaurus_bodies=records.CentaurusBodyDefinition_rows;
    bundle->centaurus_volleys=records.CentaurusVolleyDefinition_rows;
    bundle->centaurus_rears=records.CentaurusRearDefinition_rows;
    bundle->centaurus_rains=records.CentaurusRainDefinition_rows;
    bundle->centaurus_powers=records.CentaurusPowerDefinition_rows;
    bundle->centaurus_showers=records.CentaurusShowerDefinition_rows;
    bundle->centaurus_fans=records.CentaurusFanDefinition_rows;
    bundle->centaurus_sails=records.CentaurusSailDefinition_rows;
    bundle->centaurus_combos=records.CentaurusComboDefinition_rows;
    bundle->centaurus_stomps=records.CentaurusStompDefinition_rows;bundle->centaurus_stomp_feet=records.CentaurusStompFoot_rows;
    bundle->boss_finish=records.BossFinishDefinition_rows;
    if (bundle->boss_finish.size()>1 || (!bundle->boss_finish.empty() && (bundle->boss_finish.front().id!=1 || bundle->boss_finish.front().zoom<=0))) return {};
    bundle->bosses=records.BossDefinition_rows;
    bundle->boss_techniques=records.BossTechniqueDefinition_rows;
    bundle->boss_stages=records.BossTechniqueStage_rows;
    for (size_t i=0;i<bundle->bosses.size();++i) {
        const auto &p=bundle->bosses[i];
        if (p.id!=i+1 || (p.external_id!=(p.kind==0?"monoceros":p.kind==1?"centaurus":"canis_major")) || (p.kind==0 && (p.horn_length_ratio<=0 || p.horn_length_ratio_p2<=0))) return {};
    }
    for (size_t i=0;i<bundle->boss_techniques.size();++i) {
        const auto &p=bundle->boss_techniques[i];
        if (p.id!=i+1 || (p.kind>16 && p.kind!=40 && p.kind!=41) || (p.active<=0 && p.kind!=13 && p.kind!=14) || p.external_id!=(p.kind==0?"charge":p.kind==1?"kick":p.kind==2?"sweep":p.kind==3?"lance":p.kind==4?"return_charge":p.kind==5?"horn_wave":p.kind==6?"horn_dance":p.kind==7?"sword_flash":p.kind==8?"volley":p.kind==9?"rear_attack":p.kind==10?"rain":p.kind==11?"power_shot":p.kind==12?"stomp":p.kind==13?"fan_volley":p.kind==15?"sail_run":p.kind==40?"command":p.kind==41?"howl":p.external_id)) return {};
        std::vector<BossTechniqueStage> stages;
        for (const auto &stage:bundle->boss_stages) if (stage.technique==p.id) stages.push_back(stage);
        if (p.kind==16) {
            const auto combo=std::find_if(bundle->centaurus_combos.begin(),bundle->centaurus_combos.end(),[&](const auto &v){return v.technique==p.id;});
            if (combo==bundle->centaurus_combos.end() || bundle->bosses[p.boss-1].kind!=1 || p.external_id!="combo_rain_volley" || !stages.empty()) return {};
            const auto &a=bundle->boss_techniques[combo->first-1],&b=bundle->boss_techniques[combo->second-1];
            if (a.kind!=10 || b.kind!=8 || a.boss!=p.boss || b.boss!=p.boss || a.phase!=p.phase || b.phase!=p.phase) return {};continue;
        }
        if (p.kind==15) {
            const auto sail=std::find_if(bundle->centaurus_sails.begin(),bundle->centaurus_sails.end(),[&](const auto &v){return v.technique==p.id;});
            if (sail==bundle->centaurus_sails.end() || bundle->bosses[p.boss-1].kind!=1 || sail->radius_min>sail->radius_max || p.speed<=0 || !stages.empty() || p.active!=std::max(0.001,sail->duration)) return {};continue;
        }
        if (p.kind==41) {
            const auto v=std::find_if(bundle->canis_howls.begin(),bundle->canis_howls.end(),[&](const auto &v){return v.technique==p.id;});
            if (v==bundle->canis_howls.end() || bundle->bosses[p.boss-1].kind!=2 || uint64_t(v->ring_count)+uint64_t(v->gaps)*v->gap_slots>UINT32_MAX || v->lunge_time<=0 || !stages.empty() || p.active!=v->follow_time+std::max(0,int(v->ring_count)-1)*v->seq_interval+v->seq_warn+v->tail+0.05) return {};continue;
        }
        if (p.kind==40) {
            const auto v=std::find_if(bundle->canis_commands.begin(),bundle->canis_commands.end(),[&](const auto &v){return v.technique==p.id;});
            if (v==bundle->canis_commands.end() || bundle->bosses[p.boss-1].kind!=2 || v->lunge_time<=0 || p.active!=v->lunge_time+0.05 || stages.size()!=2 || stages[0].command!=1 || stages[0].at!=p.warn || stages[1].command!=2 || stages[1].at!=p.warn+v->lunge_time+0.05) return {};continue;
        }
        if (p.kind==14) {
            const auto shower=std::find_if(bundle->centaurus_showers.begin(),bundle->centaurus_showers.end(),[&](const auto &v){return v.technique==p.id;});
            if (shower==bundle->centaurus_showers.end() || bundle->bosses[p.boss-1].kind!=1 || !stages.empty() || shower->wall_min>shower->wall_max || p.external_id!=(shower->pattern==0?"shower_chase":shower->pattern==1?"shower_wall":"shower_path")) return {};continue;
        }
        if (p.kind==13) {
            const auto fan=std::find_if(bundle->centaurus_fans.begin(),bundle->centaurus_fans.end(),[&](const auto &v){return v.technique==p.id;});
            if (fan==bundle->centaurus_fans.end() || bundle->bosses[p.boss-1].kind!=1 || p.speed<=0 || fan->radius<=0 || fan->travel<=0 || !stages.empty() || p.active!=(fan->shots-1)*fan->interval) return {};continue;
        }
        if (p.kind==12) {
            const auto stomp=std::find_if(bundle->centaurus_stomps.begin(),bundle->centaurus_stomps.end(),[&](const auto &v){return v.technique==p.id;});
            if (stomp==bundle->centaurus_stomps.end() || bundle->bosses[p.boss-1].kind!=1 || !stages.empty()) return {};
            uint32_t count=0;for (const auto &foot:bundle->centaurus_stomp_feet) if (foot.technique==p.id) {if (foot.frame!=count/2 || foot.leg!=count%2) return {};++count;}
            if (!count || count%2) return {};continue;
        }
        if (p.kind==11) {
            const auto power=std::find_if(bundle->centaurus_powers.begin(),bundle->centaurus_powers.end(),[&](const auto &v){return v.technique==p.id;});
            if (power==bundle->centaurus_powers.end() || bundle->bosses[p.boss-1].kind!=1 || p.speed<=0 || power->radius<=0 || power->travel<=0 || p.active!=0.05 || stages.size()!=3) return {};
            bool alert=false,release=false,finish=false;double prior=-1;
            for (const auto &stage:stages) {
                if (stage.at<prior) return {};prior=stage.at;
                if (stage.command==7 && !alert && stage.at==std::max(0.01,p.warn-power->alert)) alert=true;
                else if (stage.command==3 && !release && stage.at==p.warn) release=true;
                else if (stage.command==4 && !finish && stage.at==p.warn+0.05) finish=true;
                else return {};
            }
            continue;
        }
        if (p.kind==10) {
            const auto rain=std::find_if(bundle->centaurus_rains.begin(),bundle->centaurus_rains.end(),[&](const auto &v){return v.technique==p.id;});
            if (rain==bundle->centaurus_rains.end() || bundle->bosses[p.boss-1].kind!=1 || stages.size()!=1 || stages[0].command!=6 || stages[0].at!=p.warn) return {};
            continue;
        }
        if (p.kind==9) {
            const auto rear=std::find_if(bundle->centaurus_rears.begin(),bundle->centaurus_rears.end(),[&](const auto &v){return v.technique==p.id;});
            if (rear==bundle->centaurus_rears.end() || bundle->bosses[p.boss-1].kind!=1 || stages.size()!=2 || stages[0].command!=5 || stages[0].at!=p.warn || stages[1].command!=4 || stages[1].at!=p.warn+p.active+0.05) return {};
            continue;
        }
        if (p.kind==8) {
            const auto volley=std::find_if(bundle->centaurus_volleys.begin(),bundle->centaurus_volleys.end(),[&](const auto &v){return v.technique==p.id;});
            if (volley==bundle->centaurus_volleys.end() || bundle->bosses[p.boss-1].kind!=1 || p.speed<=0 || volley->radius<=0 || volley->travel<=0 || stages.size()!=volley->count+1 || p.active!=volley->interval*(volley->count-1)+0.05) return {};
            for (size_t k=0;k<stages.size();++k) if (stages[k].command!=(k<volley->count?3:4) || stages[k].at!=(k<volley->count?p.warn+volley->interval*k:p.warn+p.active)) return {};
            continue;
        }
        if (stages.size()!=(p.kind>=2?0:3)) return {};
        const auto &boss=bundle->bosses[p.boss-1];
        bool commands[3]={};double prior=-1;
        for (const auto &stage:stages) {
            const double expected=stage.command==0?std::max(0.01,p.warn-boss.lock_lead):stage.command==1?p.warn:p.warn+p.active;
            if (commands[stage.command] || stage.at!=expected || stage.at<prior) return {};
            commands[stage.command]=true;prior=stage.at;
        }
    }
    for (size_t i=0;i<bundle->centaurus_combos.size();++i) if (bundle->centaurus_combos[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_combos[i].technique-1].kind!=16) return {};
    for (size_t i=0;i<bundle->centaurus_sails.size();++i) if (bundle->centaurus_sails[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_sails[i].technique-1].kind!=15) return {};
    for (size_t i=0;i<bundle->centaurus_showers.size();++i) if (bundle->centaurus_showers[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_showers[i].technique-1].kind!=14) return {};
    for (size_t i=0;i<bundle->canis_howls.size();++i) if (bundle->canis_howls[i].id!=i+1 || bundle->boss_techniques[bundle->canis_howls[i].technique-1].kind!=41) return {};
    for (size_t i=0;i<bundle->canis_commands.size();++i) if (bundle->canis_commands[i].id!=i+1 || bundle->boss_techniques[bundle->canis_commands[i].technique-1].kind!=40) return {};
    for (size_t i=0;i<bundle->centaurus_fans.size();++i) if (bundle->centaurus_fans[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_fans[i].technique-1].kind!=13) return {};
    for (size_t i=0;i<bundle->centaurus_stomps.size();++i) if (bundle->centaurus_stomps[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_stomps[i].technique-1].kind!=12) return {};
    for (size_t i=0;i<bundle->centaurus_stomp_feet.size();++i) if (bundle->centaurus_stomp_feet[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_stomp_feet[i].technique-1].kind!=12) return {};
    for (size_t i=0;i<bundle->centaurus_powers.size();++i) if (bundle->centaurus_powers[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_powers[i].technique-1].kind!=11) return {};
    for (size_t i=0;i<bundle->centaurus_rains.size();++i) if (bundle->centaurus_rains[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_rains[i].technique-1].kind!=10) return {};
    for (size_t i=0;i<bundle->centaurus_rears.size();++i) if (bundle->centaurus_rears[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_rears[i].technique-1].kind!=9) return {};
    for (size_t i=0;i<bundle->centaurus_volleys.size();++i) if (bundle->centaurus_volleys[i].id!=i+1 || bundle->boss_techniques[bundle->centaurus_volleys[i].technique-1].kind!=8) return {};
    for (size_t i=0;i<bundle->boss_stages.size();++i) if (bundle->boss_stages[i].id!=i+1) return {};
    bundle->pumps=records.PumpDefinition_rows;
    if (!FlowRunner::validate_content(*bundle)) return {};
    bundle->coronas=records.CoronaDefinition_rows;
    bundle->clocks=records.ClockDefinition_rows;
    bundle->aurigas=records.AurigaDefinition_rows;
    bundle->soldiers=records.SoldierDefinition_rows;bundle->cepheus=records.CepheusDefinition_rows;bundle->rulers=records.RulerDefinition_rows;bundle->triangles=records.TriangleDefinition_rows;
    bundle->lynxes=records.LynxDefinition_rows;
    bundle->contacts=records.ContactDefinition_rows;
    bundle->hostile_definitions=records.HostileDefinition_rows;
    bundle->beams=records.BeamDefinition_rows;
    bundle->waves=records.WaveDefinition_rows;
    bundle->walls=records.WallDefinition_rows;
    bundle->slashes=records.SlashDefinition_rows;
    bundle->bolts=records.BoltDefinition_rows;
    bundle->ring_holds=records.RingHoldDefinition_rows;
    bundle->lumps=records.LumpDefinition_rows;
    bundle->friend_debris=records.FriendDebrisDefinition_rows;
    bundle->shells=records.ShellDefinition_rows;bundle->shell_sources=records.ShellSource_rows;
    for (size_t i=0;i<bundle->shells.size();++i) if (bundle->shells[i].id!=i+1) return {};
    bundle->light_lances=records.LightLanceDefinition_rows;
    for (size_t i=0;i<bundle->light_lances.size();++i) {const auto &d=bundle->light_lances[i];if (d.id!=i+1 || d.life<=0 || d.flight_time<=0) return {};}
    bundle->zones=records.ZoneDefinition_rows;bundle->floods=records.FloodDefinition_rows;
    for (size_t i=0;i<bundle->floods.size();++i) if (bundle->floods[i].id!=i+1 || bundle->floods[i].tail<=0 || bundle->floods[i].collapse<=0 || bundle->floods[i].margin<1) return {};
    bundle->friend_hulls=records.FriendHullDefinition_rows;bundle->hull_looks=records.FriendHullLook_rows;bundle->saw_points=records.FriendSawPoint_rows;
    for (size_t i=0;i<bundle->zones.size();++i) {
        const auto &d=bundle->zones[i];if (d.id!=i+1 || d.style!=i || d.active<=0 || !std::isfinite(float(d.active)) || (d.hit && d.hit_duration<=0) || (d.fade && d.fade_duration<=0)) return {};
    }
    if (!bundle->friend_hulls.empty() && bundle->saw_points.size()!=24) return {};
    for (size_t i=0;i<bundle->saw_points.size();++i) if (bundle->saw_points[i].id!=i+1) return {};
    for (size_t i=0;i<bundle->lumps.size();++i) {
        const auto &d=bundle->lumps[i];if (d.id!=i+1 || d.life<=0 || !std::isfinite(float(d.life)) ||
            bundle->hostile_definitions[d.projectile-1].kind!=uint32_t(HostileKind::Bullet)) return {};
    }
    for (size_t i=0;i<bundle->ring_holds.size();++i) {
        const auto &d=bundle->ring_holds[i];if (d.id!=i+1 || d.life<=0 || !std::isfinite(float(d.projectile_radius)) || !std::isfinite(float(d.life)) ||
            bundle->hostile_definitions[d.projectile-1].kind!=uint32_t(HostileKind::Bullet)) return {};
    }
    bundle->star_bolts=records.StarBoltDefinition_rows;
    for (size_t i=0;i<bundle->star_bolts.size();++i) {
        const auto &s=bundle->star_bolts[i];if (s.id!=i+1 || s.radius<=0 || s.life<=0 || s.flight_scale<=0 ||
            !std::isfinite(float(s.radius)) || !std::isfinite(float(s.life)) || !std::isfinite(float(s.flight_scale))) return {};
    }
    bundle->light_arrows=records.LightArrowDefinition_rows;
    for (size_t i=0;i<bundle->light_arrows.size();++i) {
        const auto &arrow=bundle->light_arrows[i];if (arrow.id!=i+1 || arrow.flight_scale<=0 || arrow.shot_length_scale<=0 || arrow.shot_width_scale<=0) return {};
    }
    for (size_t i=0;i<bundle->bolts.size();++i) {
        const auto &bolt=bundle->bolts[i];
        if (bolt.id!=i+1 || bolt.radius<=0 || bolt.life<=0 || bolt.flight_scale<=0 ||
            !std::isfinite(float(bolt.radius)) || !std::isfinite(float(bolt.life)) || !std::isfinite(float(bolt.flight_scale))) return {};
    }
    if (!bundle->slashes.empty()) {
        if (bundle->slashes.size()!=51) return {};
        for (size_t i=0;i<bundle->slashes.size();++i) {
            const auto &point=bundle->slashes[i];
            if (point.id!=i+1 || point.claw!=i/17 || point.sample!=i%17 || point.thickness<=0 ||
                point.contact!=bundle->slashes.front().contact || point.thickness!=bundle->slashes.front().thickness) return {};
        }
    }
    bundle->friend_shots=records.FriendShotDefinition_rows;
    for (const auto &shot:bundle->hostile_definitions) {
        if (shot.life<=0 || shot.radius<=0) return {};
        for (double value:{shot.radius,shot.life,shot.slow,shot.turn}) if (!std::isfinite(float(value))) return {};
    }
    bundle->budget_phases=records.BudgetPhase_rows;
    if (records.ProgressionDefinition_rows.size()!=1 || records.ProgressionDefinition_rows.front().xp_base<=0) return {};
    bundle->progression=records.ProgressionDefinition_rows.front();
    bundle->post_max=records.PostMaxDefinition_rows;
    bundle->post_max_targets=records.PostMaxTarget_rows;
    bundle->post_max_intervals=records.PostMaxInterval_rows;
    std::unordered_set<std::string> post_ids;
    for (size_t i=0;i<bundle->post_max.size();++i) if (bundle->post_max[i].id!=i+1 || !post_ids.insert(bundle->post_max[i].external_id).second) return {};
    for (const auto &v:bundle->post_max_intervals) if (!v.base || v.level>records.LoadoutDefinition_rows[v.equipment-1].maximum_level || records.LoadoutDefinition_rows[v.equipment-1].kind!=0) return {};
    if (records.LifecycleDefinition_rows.size()!=1) return {};
    bundle->lifecycle=records.LifecycleDefinition_rows.front();
    bundle->field_bodies=records.FieldBodyDefinition_rows;
    for (const auto &body:bundle->field_bodies) if (body.radius<=0) return {};
    if (records.GravityDefinition_rows.size()!=1 || records.GravityDefinition_rows.front().life<=0) return {};
    bundle->gravity=records.GravityDefinition_rows.front();
    if (records.CometDefinition_rows.size()!=1) return {};bundle->comet=records.CometDefinition_rows.front();
    const auto &comet=bundle->comet;if (comet.interval_max<comet.interval_min || comet.speed<=0 || comet.rare_hp_mult<=0 || comet.rare_chance>1 || comet.warp_chance>1) return {};
    for (double value:{comet.interval_min,comet.interval_max,comet.speed,comet.rare_after,comet.rare_hp_mult}) if (!std::isfinite(float(value))) return {};
    if (records.WarpDefinition_rows.size()!=1) return {};bundle->warp=records.WarpDefinition_rows.front();
    for (double value:{bundle->warp.radius,bundle->warp.life,bundle->warp.bonus_time}) if (!std::isfinite(float(value))) return {};
    for (double value:{bundle->gravity.life,bundle->gravity.radius,bundle->gravity.pull}) if (!std::isfinite(float(value))) return {};
    bundle->rock_fields=records.RockFieldDefinition_rows;
    if (bundle->rock_fields.size()>1) return {};
    bundle->moon_definitions=records.MoonDefinition_rows;
    for (const auto &moon:bundle->moon_definitions) if (moon.orbit_max<moon.orbit_min || moon.radius_min<=0 || moon.radius_max<moon.radius_min) return {};
    bundle->equipment=records.LoadoutDefinition_rows;
    bundle->equipment_assets=records.LoadoutAsset_rows;
    bundle->numeric_traits=records.NumericTraitLevel_rows;
    bundle->full_charge_levels=records.FullChargeDefinition_rows;
    bundle->kill_sonic_levels=records.KillSonicDefinition_rows;
    bundle->crit_beam_levels=records.CritBeamDefinition_rows;
    bundle->vortex_levels=records.VortexDefinition_rows;
    bundle->run_up_levels=records.RunUpDefinition_rows;
    bundle->rampage_levels=records.RampageDefinition_rows;
    bundle->duplicator_levels=records.DuplicatorDefinition_rows;
    if (records.PostMaxChargeDefinition_rows.size()!=1) return {};
    bundle->post_charge=records.PostMaxChargeDefinition_rows.front();
    if (records.PostMaxCritDefinition_rows.size()!=1) return {};
    bundle->post_crit=records.PostMaxCritDefinition_rows.front();
    if (records.PostMaxMotionDefinition_rows.size()!=1) return {};
    bundle->post_motion=records.PostMaxMotionDefinition_rows.front();
    bundle->post_weapon_power=records.PostMaxWeaponPowerDefinition_rows;
    std::unordered_set<uint32_t> power_weapons;
    for (const auto &power:bundle->post_weapon_power) if (bundle->equipment[power.equipment-1].kind!=0 || !power_weapons.insert(power.equipment).second) return {};
    if (!power_weapons.count(1)) return {};
    if (records.PostMaxPickupDefinition_rows.size()!=1) return {};
    bundle->post_pickup=records.PostMaxPickupDefinition_rows.front();
    if (records.PostMaxDrawDefinition_rows.size()!=1) return {};
    bundle->post_draw=records.PostMaxDrawDefinition_rows.front();
    for (size_t i=1;i<bundle->budget_phases.size();++i) if (bundle->budget_phases[i].start<bundle->budget_phases[i-1].start) return {};
    for (const auto &bite:bundle->bites) {
        const auto &first=bundle->bites.front();
        if (bite.duration!=first.duration || bite.visual_key!=first.visual_key || bite.hit!=first.hit || bite.fade!=first.fade) return {};
    }
    if (records.LoadoutDefinition_rows.empty() || records.LoadoutDefinition_rows[0].id!=1 ||
        records.LoadoutDefinition_rows[0].kind!=0 || records.LoadoutDefinition_rows[0].external_id!="W01" ||
        records.LoadoutDefinition_rows[0].comet_only || bundle->forward_levels.size()!=records.LoadoutDefinition_rows[0].maximum_level) return {};
    for (size_t i=0;i<bundle->forward_levels.size();++i) {
        const auto &level=bundle->forward_levels[i];
        if (level.weapon!=1 || level.level!=i+1 || level.interval<=0) return {};
    }
    std::unordered_set<std::string> equipment_names;
    for (size_t index=0;index<bundle->equipment.size();++index) {
        const auto &d=bundle->equipment[index];
        if (d.id!=index+1 || !equipment_names.insert(d.external_id).second) return {};
        if (d.id==1) continue;
        if (d.external_id=="T37") {
            if (d.kind!=1 || d.maximum_level!=bundle->duplicator_levels.size()) return {};
            for (size_t i=0;i<bundle->duplicator_levels.size();++i) {const auto &level=bundle->duplicator_levels[i];if (level.equipment!=d.id || level.level!=i+1 || level.angle_min>level.angle_max) return {};}
            continue;
        }
        if (d.external_id=="T05") {
            if (d.kind!=1 || d.maximum_level!=bundle->kill_sonic_levels.size()) return {};
            for (size_t i=0;i<bundle->kill_sonic_levels.size();++i) {const auto &v=bundle->kill_sonic_levels[i];if (v.equipment!=d.id || v.level!=i+1 || v.life<=0) return {};}
            continue;
        }
        if (d.external_id=="T06") {
            if (d.kind!=1 || d.maximum_level!=bundle->crit_beam_levels.size() || bundle->light_lances.empty()) return {};
            for (size_t i=0;i<bundle->crit_beam_levels.size();++i) {const auto &c=bundle->crit_beam_levels[i];if (c.equipment!=d.id || c.level!=i+1 || c.length<=0 || c.width<=0) return {};}
            continue;
        }
        if (d.external_id=="T03") {
            if (d.kind!=1 || d.maximum_level!=bundle->vortex_levels.size()) return {};
            for (size_t i=0;i<bundle->vortex_levels.size();++i) {const auto &v=bundle->vortex_levels[i];if (v.equipment!=d.id || v.level!=i+1 || v.kills<=0 || v.charge+v.hold+v.collapse<=0) return {};}
            continue;
        }
        if (d.external_id=="T32") {
            if (d.kind!=1 || d.maximum_level!=bundle->run_up_levels.size()) return {};
            for (size_t i=0;i<bundle->run_up_levels.size();++i) if (bundle->run_up_levels[i].equipment!=d.id || bundle->run_up_levels[i].level!=i+1 || bundle->run_up_levels[i].distance<=0) return {};
            continue;
        }
        if (d.external_id=="T33") {
            if (d.kind!=1 || d.maximum_level!=bundle->rampage_levels.size()) return {};
            for (size_t i=0;i<bundle->rampage_levels.size();++i) if (bundle->rampage_levels[i].equipment!=d.id || bundle->rampage_levels[i].level!=i+1 || bundle->rampage_levels[i].half_life<=0) return {};
            continue;
        }
        if (d.external_id=="T04") {
            if (d.kind!=1 || d.maximum_level!=bundle->full_charge_levels.size()) return {};
            for (size_t i=0;i<bundle->full_charge_levels.size();++i) if (bundle->full_charge_levels[i].equipment!=d.id || bundle->full_charge_levels[i].level!=i+1) return {};
            continue;
        }
        if (d.external_id=="W28") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->flash_slash_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->flash_slash_levels.size();++i) {const auto &v=bundle->flash_slash_levels[i];if (v.weapon!=d.id || v.level!=i+1) return {};}
            continue;
        }
        if (d.external_id=="W27") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->afterimage_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->afterimage_levels.size();++i) {const auto &v=bundle->afterimage_levels[i];if (v.weapon!=d.id || v.level!=i+1) return {};}
            continue;
        }
        if (d.external_id=="W26") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->escort_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->escort_levels.size();++i) {const auto &v=bundle->escort_levels[i];if (v.weapon!=d.id || v.level!=i+1 || v.deploy_distance<=0) return {};}
            continue;
        }
        if (d.external_id=="W25") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->interceptor_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->interceptor_levels.size();++i) {const auto &v=bundle->interceptor_levels[i];if (v.weapon!=d.id || v.level!=i+1 || v.interval<=0 || v.burst_interval<=0 || v.life<=0 || v.range<=0) return {};}
            continue;
        }
        if (d.external_id=="W22") {
            if (d.kind!=0 || !d.comet_only || d.maximum_level!=bundle->bipolar_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->bipolar_levels.size();++i) {const auto &v=bundle->bipolar_levels[i];if (v.weapon!=d.id || v.level!=i+1 || v.radius_factor<=0 || v.delay<=0 || v.visual_life<=0) return {};}
            continue;
        }
        if (d.external_id=="W21") {
            if (d.kind!=0 || !d.comet_only || d.maximum_level!=bundle->mass_tow_levels.size() || !power_weapons.count(d.id) || bundle->friend_hulls.empty()) return {};
            for (size_t i=0;i<bundle->mass_tow_levels.size();++i) {const auto &v=bundle->mass_tow_levels[i];if (v.weapon!=d.id || v.level!=i+1 || v.size_ref<=0 || v.interval<=0 || v.life<=0) return {};}
            continue;
        }
        if (d.external_id=="W17") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->contact_arc_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->contact_arc_levels.size();++i) if (bundle->contact_arc_levels[i].weapon!=d.id || bundle->contact_arc_levels[i].level!=i+1) return {};
            continue;
        }
        if (d.external_id=="W08") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->sonic_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->sonic_levels.size();++i) {const auto &v=bundle->sonic_levels[i];if (v.weapon!=d.id || v.level!=i+1 || v.life<=0 || v.emit_spacing<=0 || v.distance<=0 || v.decay<=0) return {};}
            continue;
        }
        if (d.external_id=="W04") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->contact_wave_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->contact_wave_levels.size();++i) if (bundle->contact_wave_levels[i].weapon!=d.id || bundle->contact_wave_levels[i].level!=i+1) return {};
            continue;
        }
        if (d.external_id=="W03") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->knockback_levels.size() || !power_weapons.count(d.id) || bundle->friend_debris.empty()) return {};
            for (size_t i=0;i<bundle->knockback_levels.size();++i) if (bundle->knockback_levels[i].weapon!=d.id || bundle->knockback_levels[i].level!=i+1) return {};
            continue;
        }
        if (d.external_id=="W07") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->mines_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->mines_levels.size();++i) {const auto &m=bundle->mines_levels[i];if (m.weapon!=d.id || m.level!=i+1 || m.range_min>m.range_max || !m.maximum || m.visual_life<=0) return {};}
            continue;
        }
        if (d.external_id=="W29") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->end_blast_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->end_blast_levels.size();++i) if (bundle->end_blast_levels[i].weapon!=d.id || bundle->end_blast_levels[i].level!=i+1) return {};
            continue;
        }
        if (d.external_id=="W05") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->barrier_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->barrier_levels.size();++i) {
                const auto &level=bundle->barrier_levels[i];
                if (level.weapon!=d.id || level.level!=i+1 || level.durability<=0 || level.revive<=0) return {};
            }
            continue;
        }
        if (d.external_id=="W23") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->rear_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->rear_levels.size();++i) {
                const auto &level=bundle->rear_levels[i];
                if (level.weapon!=d.id || level.level!=i+1 || level.interval<=0) return {};
            }
            continue;
        }
        if (d.external_id=="W02") {
            if (d.kind!=0 || d.comet_only || d.maximum_level!=bundle->scatter_levels.size() || !power_weapons.count(d.id)) return {};
            for (size_t i=0;i<bundle->scatter_levels.size();++i) {
                const auto &level=bundle->scatter_levels[i];
                if (level.weapon!=d.id || level.level!=i+1 || level.interval<=0) return {};
            }
            continue;
        }
        // カプセルは未装備の彗星武器をIDで保持する。実行の登録は武器ごとに確認する。
        if (d.kind==0 && d.comet_only) continue;
        if (d.kind!=1 || (d.external_id!="T31" && d.external_id!="T14" && d.external_id!="T12" && d.external_id!="T11" && d.external_id!="T10" && d.external_id!="T09" && d.external_id!="T08" && d.external_id!="T07" && d.external_id!="T34" && d.external_id!="T35" && d.external_id!="T36")) return {};
        if (d.maximum_level>bundle->numeric_traits.size()) return {};
        for (uint32_t level=1;level<=d.maximum_level;++level) {
            if (std::count_if(bundle->numeric_traits.begin(),bundle->numeric_traits.end(),[&](const auto &v){return v.equipment==d.id && v.level==level;})!=1) return {};
        }
    }
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="W02";})!=1) return {};
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="W23";})!=1) return {};
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="W05";})!=1) return {};
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="T04";})!=1) return {};
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="T33";})!=1) return {};
    if (std::count_if(bundle->equipment.begin(),bundle->equipment.end(),[](const auto &d){return d.external_id=="T37";})!=1) return {};
    for (const auto &v:bundle->numeric_traits) {
        const auto &d=bundle->equipment[v.equipment-1];
        if (d.kind!=1 || v.level>d.maximum_level) return {};
    }
    for (const auto &visual:bundle->visuals) {
        if (visual.role>=uint32_t(VisualRole::Count)) return {};
    }
    std::unordered_set<std::string> names;
    for (const auto &row:records.EnemyRecord_rows) {
        if (row.id!=bundle->definitions.size()+1) return {};
        auto string=std::find_if(records.StringEntry_rows.begin(),records.StringEntry_rows.end(),[&](const auto &s){return s.id==row.id;});
        auto index=std::find_if(records.DefinitionIndex_rows.begin(),records.DefinitionIndex_rows.end(),[&](const auto &s){return s.id==row.id && s.enemy==row.id;});
        if (string==records.StringEntry_rows.end() || string->value.empty() || !names.insert(string->value).second ||
            index==records.DefinitionIndex_rows.end() || row.hp<=0 || row.radius<=0) return {};
        if (row.kind!=0 && row.kind!=1 && row.kind!=2 && row.kind!=3 && row.kind!=4 && row.kind!=5 && row.kind!=6 && row.kind!=7 && row.kind!=8 && row.kind!=9 && row.kind!=10 && row.kind!=11 && row.kind!=12 && row.kind!=13 && row.kind!=14 && row.kind!=15 && row.kind!=16 && row.kind!=17 && row.kind!=18 && row.kind!=19 && row.kind!=20 && row.kind!=21 && row.kind!=22 && row.kind!=23 && row.kind!=24 && row.kind!=25 && row.kind!=28 && row.kind!=29 && row.kind!=30 && row.kind!=26 && row.kind!=27 && row.kind!=34 && row.kind!=37 && row.kind!=31 && row.kind!=35 && row.kind!=32 && row.kind!=36 && row.kind!=33 && row.kind!=39 && row.kind!=40 && row.kind!=41 && row.kind!=38) return {};
        auto definition=to_enemy(row,godot::String::utf8(string->value.c_str(),string->value.size()));
        definition.gate=EnemyDefinition::Gate(row.gate);
        const auto shield=std::find_if(records.ShieldDefinition_rows.begin(),records.ShieldDefinition_rows.end(),[&](const auto &s){return s.id==row.id;});
        if (row.kind==1) {
            if (shield==records.ShieldDefinition_rows.end() || shield->reflected>bundle->hostile_definitions.size() || shield->turn<=0) return {};
            const auto &reflected=bundle->hostile_definitions[shield->reflected-1];if (reflected.kind!=uint32_t(HostileKind::Reflected)) return {};
            definition.accel=shield->accel;definition.turn=shield->turn;definition.weak_arc=shield->weak_arc;definition.front_arc=shield->front_arc;
            definition.reflect_speed=shield->reflect_speed;definition.reflect_interval=shield->reflect_interval;definition.shield_time=shield->shield_time;
            definition.reflected_definition=shield->reflected;definition.reflect_life=reflected.life;definition.reflect_damage=reflected.damage;
        } else if (shield!=records.ShieldDefinition_rows.end()) return {};
        const auto bite=std::find_if(bundle->bites.begin(),bundle->bites.end(),[&](const auto &b){return b.id==row.id;});
        if (row.kind==2 || row.kind==3 || row.kind==27) {
            if (bite==bundle->bites.end() || bite->warn<=0 || bite->duration<=0 || !bite->visual_key) return {};
            definition.bite={bite->reach,bite->warn,bite->rest,bite->radius,bite->damage};
        } else if (bite!=bundle->bites.end()) return {};
        const auto hound=std::find_if(bundle->hounds.begin(),bundle->hounds.end(),[&](const auto &h){return h.id==row.id;});
        if (row.kind==3) {
            if (hound==bundle->hounds.end()) return {};
            definition.pack={hound->count,hound->gap,hound->reach,hound->alignment,hound->cohesion,hound->separation};definition.accel=hound->accel;
        } else if (hound!=bundle->hounds.end()) return {};
        const auto gunner=std::find_if(bundle->gunners.begin(),bundle->gunners.end(),[&](const auto &g){return g.id==row.id;});
        if (row.kind==7) {
            if (gunner==bundle->gunners.end() || gunner->telegraph<=0 || row.fire_interval<=0) return {};
            for (double value:{gunner->accel,gunner->keep,gunner->telegraph,gunner->bullet_speed,gunner->bullet_damage,gunner->slow,gunner->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.gunner_definition=uint32_t(gunner-bundle->gunners.begin()+1);definition.accel=gunner->accel;
        } else if (gunner!=bundle->gunners.end()) return {};
        const auto beamer=std::find_if(bundle->beamers.begin(),bundle->beamers.end(),[&](const auto &b){return b.id==row.id;});
        if (row.kind==8) {
            if (beamer==bundle->beamers.end() || beamer->telegraph<=0 || row.fire_interval<=0) return {};
            for (double value:{beamer->accel,beamer->keep,beamer->telegraph,beamer->beam_time,beamer->beam_length,beamer->half_width,beamer->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.beamer_definition=uint32_t(beamer-bundle->beamers.begin()+1);definition.accel=beamer->accel;
        } else if (beamer!=bundle->beamers.end()) return {};
        const auto missile=std::find_if(bundle->missile_enemies.begin(),bundle->missile_enemies.end(),[&](const auto &m){return m.id==row.id;});
        if (row.kind==9) {
            if (missile==bundle->missile_enemies.end() || missile->warn<=0 || row.fire_interval<=0) return {};
            for (double value:{missile->accel,missile->keep,missile->warn,missile->missile_speed,missile->missile_turn,missile->damage,missile->slow,missile->admission_duration}) if (!std::isfinite(float(value))) return {};
            if (std::none_of(bundle->hostile_definitions.begin(),bundle->hostile_definitions.end(),[](const auto &h){return h.kind==uint32_t(HostileKind::Missile);})) return {};
            definition.missile_definition=uint32_t(missile-bundle->missile_enemies.begin()+1);definition.accel=missile->accel;
        } else if (missile!=bundle->missile_enemies.end()) return {};
        const auto visual=std::find_if(bundle->visuals.begin(),bundle->visuals.end(),[&](const auto &v){return v.id==definition.visual_id;});
        definition.polygon_visual=visual!=bundle->visuals.end() && visual->role==uint32_t(VisualRole::EnemyPolygon);
        const auto rocket=std::find_if(bundle->rockets.begin(),bundle->rockets.end(),[&](const auto &r){return r.id==row.id;});
        if (row.kind==10) {
            if (rocket==bundle->rockets.end() || rocket->life<=0 || rocket->blast_duration<=0) return {};
            for (double value:{rocket->life,rocket->fuse,rocket->blast_radius,rocket->blast_duration,rocket->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.rocket_definition=uint32_t(rocket-bundle->rockets.begin()+1);
        } else if (rocket!=bundle->rockets.end()) return {};
        const auto drift=std::find_if(bundle->drifts.begin(),bundle->drifts.end(),[&](const auto &d){return d.id==row.id;});
        if (row.kind==11) {
            if (drift==bundle->drifts.end()) return {};
            definition.drift_definition=uint32_t(drift-bundle->drifts.begin()+1);definition.ram_guard=drift->ram_guard;
        } else if (drift!=bundle->drifts.end()) return {};
        const auto star=std::find_if(records.TriangleStarDefinition_rows.begin(),records.TriangleStarDefinition_rows.end(),[&](const auto &p){return p.id==row.id;});
        if ((row.kind==32)!=(star!=records.TriangleStarDefinition_rows.end())) return {};
        const auto part=std::find_if(records.PartDefinition_rows.begin(),records.PartDefinition_rows.end(),[&](const auto &p){return p.id==row.id;});
        if ((row.kind==12)!=(part!=records.PartDefinition_rows.end())) return {};
        const auto dash=std::find_if(bundle->dashes.begin(),bundle->dashes.end(),[&](const auto &d){return d.id==row.id;});
        if (row.kind==13) {
            if (dash==bundle->dashes.end()) return {};
            for (double value:{dash->range,dash->warn,dash->dash_time,dash->dash_speed,dash->recover,dash->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.dash_definition=uint32_t(dash-bundle->dashes.begin()+1);
        } else if (dash!=bundle->dashes.end()) return {};
        const auto battleship=std::find_if(bundle->battleships.begin(),bundle->battleships.end(),[&](const auto &b){return b.id==row.id;});
        if (row.kind==14) {
            if (battleship==bundle->battleships.end() || battleship->warn<=0 || row.fire_interval<=0) return {};
            for (double value:{battleship->warn,battleship->bullet_speed,battleship->slow,battleship->spread,battleship->weak_arc,battleship->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.battleship_definition=uint32_t(battleship-bundle->battleships.begin()+1);definition.weak_arc=battleship->weak_arc;
        } else if (battleship!=bundle->battleships.end()) return {};
        const auto sniper=std::find_if(bundle->snipers.begin(),bundle->snipers.end(),[&](const auto &s){return s.id==row.id;});
        if (row.kind==15) {
            if (sniper==bundle->snipers.end() || sniper->lock_fill<=0 || sniper->search_period<=0 || sniper->band_width<=0 || sniper->band_narrow<=0 || sniper->laser_charge<=0) return {};
            for (double value:{sniper->accel,sniper->keep,sniper->band_len,sniper->band_width,sniper->band_narrow,sniper->track_turn,sniper->search_turn,sniper->search_sway,sniper->search_period,sniper->lock_fill,sniper->laser_charge,sniper->laser_delay,sniper->laser_time,sniper->laser_half_width,sniper->cooldown}) if (!std::isfinite(float(value))) return {};
            definition.sniper_definition=uint32_t(sniper-bundle->snipers.begin()+1);definition.accel=sniper->accel;
        } else if (sniper!=bundle->snipers.end()) return {};
        const auto marlin=std::find_if(bundle->marlins.begin(),bundle->marlins.end(),[&](const auto &m){return m.id==row.id;});
        if (row.kind==16) {
            if (marlin==bundle->marlins.end() || row.fire_interval<=0) return {};
            for (double value:{marlin->accel,marlin->keep,marlin->warn,marlin->dash_speed,marlin->dash_time,marlin->recover}) if (!std::isfinite(float(value))) return {};
            definition.marlin_definition=uint32_t(marlin-bundle->marlins.begin()+1);definition.accel=marlin->accel;
        } else if (marlin!=bundle->marlins.end()) return {};
        const auto pulser=std::find_if(bundle->pulsers.begin(),bundle->pulsers.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==17) {
            if (pulser==bundle->pulsers.end() || row.fire_interval<=0 || pulser->warn<=0) return {};
            for (double value:{pulser->accel,pulser->keep,pulser->warn,pulser->arc,pulser->radius,pulser->speed,pulser->width,pulser->damage}) if (!std::isfinite(float(value))) return {};
            definition.pulser_definition=uint32_t(pulser-bundle->pulsers.begin()+1);definition.accel=pulser->accel;
        } else if (pulser!=bundle->pulsers.end()) return {};
        const auto dolphin=std::find_if(bundle->dolphins.begin(),bundle->dolphins.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==18) {
            if (dolphin==bundle->dolphins.end() || row.fire_interval<=0 || dolphin->warn<=0) return {};
            for (double value:{dolphin->accel,dolphin->keep,dolphin->warn,dolphin->aim_turn,dolphin->arc,dolphin->radius,dolphin->speed,dolphin->width,dolphin->damage,dolphin->enemy_damage}) if (!std::isfinite(float(value))) return {};
            definition.dolphin_definition=uint32_t(dolphin-bundle->dolphins.begin()+1);definition.accel=dolphin->accel;
        } else if (dolphin!=bundle->dolphins.end()) return {};
        const auto item_lynx=std::find_if(bundle->lynxes.begin(),bundle->lynxes.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==19) {
            if (item_lynx==bundle->lynxes.end() || row.fire_interval<=0 || item_lynx->warn<=0) return {};
            for (double value:{item_lynx->accel,item_lynx->keep,item_lynx->warn,item_lynx->slash_speed,item_lynx->slash_size,item_lynx->slash_range,item_lynx->damage}) if (!std::isfinite(float(value))) return {};
            definition.lynx_definition=uint32_t(item_lynx-bundle->lynxes.begin()+1);definition.accel=item_lynx->accel;
        } else if (item_lynx!=bundle->lynxes.end()) return {};
        const auto triangle=std::find_if(bundle->triangles.begin(),bundle->triangles.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==38) {
            if (triangle==bundle->triangles.end() || triangle->move_time<=0 || triangle->star>records.EnemyRecord_rows.size() || records.EnemyRecord_rows[triangle->star-1].kind!=32) return {};
            for (double value:{triangle->move_time,triangle->stop_time,triangle->span,triangle->trail_width,triangle->trail_damage,triangle->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.triangle_definition=uint32_t(triangle-bundle->triangles.begin()+1);
        } else if (triangle!=bundle->triangles.end()) return {};
        const auto ruler=std::find_if(bundle->rulers.begin(),bundle->rulers.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==33) {
            if (ruler==bundle->rulers.end() || ruler->warn<=0) return {};
            for (double value:{ruler->accel,ruler->keep,ruler->split_delay,ruler->half_gap,ruler->emit_back,ruler->deploy_speed,ruler->deploy_time,ruler->warn,ruler->beam_len,ruler->beam_width,ruler->beam_time,ruler->beam_start_gap,ruler->damage,ruler->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.ruler_definition=uint32_t(ruler-bundle->rulers.begin()+1);definition.accel=ruler->accel;
        } else if (ruler!=bundle->rulers.end()) return {};
        const auto king=std::find_if(bundle->cepheus.begin(),bundle->cepheus.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==31) {
            if (king==bundle->cepheus.end() || king->summon_time<=0 || king->fire_interval<=0 || king->reinforce_interval<=0 || king->soldier>records.EnemyRecord_rows.size() || records.EnemyRecord_rows[king->soldier-1].kind!=20) return {};
            for (double value:{king->accel,king->keep,king->fire_interval,king->reinforce_interval,king->summon_time,king->mutiny_time,king->spacing,king->row_near,king->row_far,king->fan_radius,king->fan_step}) if (!std::isfinite(float(value))) return {};
            definition.cepheus_definition=uint32_t(king-bundle->cepheus.begin()+1);definition.accel=king->accel;
        } else if (king!=bundle->cepheus.end()) return {};
        const auto item_soldier=std::find_if(bundle->soldiers.begin(),bundle->soldiers.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==20) {
            if (item_soldier==bundle->soldiers.end()) return {};
            for (double value:{item_soldier->accel,item_soldier->bolt_speed,item_soldier->damage,item_soldier->mutiny_shot}) if (!std::isfinite(float(value))) return {};
            definition.soldier_definition=uint32_t(item_soldier-bundle->soldiers.begin()+1);definition.accel=item_soldier->accel;
        } else if (item_soldier!=bundle->soldiers.end()) return {};
        const auto item_auriga=std::find_if(bundle->aurigas.begin(),bundle->aurigas.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==21) {
            if (item_auriga==bundle->aurigas.end()) return {};
            for (double value:{item_auriga->accel,item_auriga->trail_step,item_auriga->trail_time,item_auriga->trail_width,item_auriga->wheel_gap,item_auriga->damage}) if (!std::isfinite(float(value))) return {};
            definition.auriga_definition=uint32_t(item_auriga-bundle->aurigas.begin()+1);definition.accel=item_auriga->accel;
        } else if (item_auriga!=bundle->aurigas.end()) return {};
        const auto item_clock=std::find_if(bundle->clocks.begin(),bundle->clocks.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==22) {
            if (item_clock==bundle->clocks.end()) return {};
            for (double value:{item_clock->accel,item_clock->warn,item_clock->hand_long,item_clock->hand_short,item_clock->hand_width,item_clock->long_speed,item_clock->short_speed,item_clock->damage}) if (!std::isfinite(float(value))) return {};
            definition.clock_definition=uint32_t(item_clock-bundle->clocks.begin()+1);definition.accel=item_clock->accel;
        } else if (item_clock!=bundle->clocks.end()) return {};
        const auto corona=std::find_if(bundle->coronas.begin(),bundle->coronas.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==36) {
            if (corona==bundle->coronas.end() || !corona->capture_max) return {};
            for (double value:{corona->capture_interval,corona->pull_radius,corona->pull,corona->ring,corona->spin,corona->telegraph,corona->align_angle,corona->throw_life,corona->throw_speed,corona->effect,corona->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.corona_definition=uint32_t(corona-bundle->coronas.begin()+1);
        } else if (corona!=bundle->coronas.end()) return {};
        const auto pump=std::find_if(bundle->pumps.begin(),bundle->pumps.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==35) {
            if (pump==bundle->pumps.end() || pump->telegraph<=0 || !pump->store_max) return {};
            for (double value:{pump->accel,pump->pull_radius,pump->pull,pump->swallow_reach,pump->swallow_interval,pump->grow,pump->telegraph,pump->lock_time,pump->shell_speed,pump->shell_radius,pump->shell_range,pump->burst_radius,pump->damage,pump->recover,pump->release_per,pump->release_speed,pump->release_damage,pump->release_radius,pump->mouth_radius,pump->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.pump_definition=uint32_t(pump-bundle->pumps.begin()+1);definition.accel=pump->accel;
        } else if (pump!=bundle->pumps.end()) return {};
        const auto crab=std::find_if(bundle->crabs.begin(),bundle->crabs.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==34) {
            if (crab==bundle->crabs.end()) return {};
            for (double value:{crab->approach,crab->reach,crab->telegraph,crab->open_time,crab->turn_angle,crab->damage,crab->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.crab_definition=uint32_t(crab-bundle->crabs.begin()+1);
        } else if (crab!=bundle->crabs.end()) return {};
        const auto aquila=std::find_if(bundle->aquilas.begin(),bundle->aquilas.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==30) {
            if (aquila==bundle->aquilas.end() || aquila->lock_time<=0 || aquila->dash_speed<=0 || aquila->drop_step<=0) return {};
            for (double value:{aquila->keep,aquila->aim_time,aquila->lock_time,aquila->dash_speed,aquila->dash_time,aquila->drop_step,aquila->blast_radius,aquila->blast_delay,aquila->damage,aquila->recover,aquila->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.aquila_definition=uint32_t(aquila-bundle->aquilas.begin()+1);
        } else if (aquila!=bundle->aquilas.end()) return {};
        const auto phoenix=std::find_if(bundle->phoenixes.begin(),bundle->phoenixes.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==29) {
            if (phoenix==bundle->phoenixes.end() || phoenix->retreat_time<0.01 || phoenix->telegraph<0.01 || phoenix->dive_time<0.01 || phoenix->recover_time<0.01 || phoenix->impact_time<0.05) return {};
            for (double value:{phoenix->retreat_distance,phoenix->retreat_time,phoenix->telegraph,phoenix->dive_time,phoenix->impact_radius,phoenix->impact_time,phoenix->impact_damage,phoenix->recover_time,phoenix->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.phoenix_definition=uint32_t(phoenix-bundle->phoenixes.begin()+1);
        } else if (phoenix!=bundle->phoenixes.end()) return {};
        const auto bomber=std::find_if(bundle->bombers.begin(),bundle->bombers.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==28) {
            if (bomber==bundle->bombers.end()) return {};
            for (double value:{bomber->accel,bomber->trigger,bomber->rush,bomber->blast_delay,bomber->blast_radius,bomber->blast_damage,bomber->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.bomber_definition=uint32_t(bomber-bundle->bombers.begin()+1);definition.accel=bomber->accel;
        } else if (bomber!=bundle->bombers.end()) return {};
        const auto cross=std::find_if(bundle->cross_enemies.begin(),bundle->cross_enemies.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==25) {
            if (cross==bundle->cross_enemies.end() || cross->telegraph<=0) return {};
            for (double value:{cross->accel,cross->stand_off,cross->align_tol,cross->beam_length,cross->half_width,cross->telegraph,cross->beam_time,cross->rest,cross->damage,cross->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.cross_definition=uint32_t(cross-bundle->cross_enemies.begin()+1);definition.accel=cross->accel;
        } else if (cross!=bundle->cross_enemies.end()) return {};
        const auto aquarius=std::find_if(bundle->aquarius.begin(),bundle->aquarius.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==24) {
            if (aquarius==bundle->aquarius.end() || aquarius->telegraph<=0) return {};
            for (double value:{aquarius->accel,aquarius->approach,aquarius->telegraph,aquarius->beam_time,aquarius->beam_length,aquarius->half_width,aquarius->spread,aquarius->rest,aquarius->damage,aquarius->admission_duration}) if (!std::isfinite(float(value))) return {};
            definition.aquarius_definition=uint32_t(aquarius-bundle->aquarius.begin()+1);definition.accel=aquarius->accel;
        } else if (aquarius!=bundle->aquarius.end()) return {};
        const auto crow=std::find_if(bundle->crows.begin(),bundle->crows.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==37) {if (crow==bundle->crows.end()) return {};definition.crow_definition=uint32_t(crow-bundle->crows.begin()+1);}
        else if (crow!=bundle->crows.end()) return {};
        const auto defender=std::find_if(bundle->defenders.begin(),bundle->defenders.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==27) {
            if (defender==bundle->defenders.end()) return {};
            definition.defender_definition=uint32_t(defender-bundle->defenders.begin()+1);definition.accel=defender->accel;
        } else if (defender!=bundle->defenders.end()) return {};
        const auto split=std::find_if(bundle->splits.begin(),bundle->splits.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==26) {
            if (split==bundle->splits.end() || split->death_split>INT32_MAX-split->split_extra || split->child>records.EnemyRecord_rows.size() || records.EnemyRecord_rows[split->child-1].kind!=0) return {};
            definition.split_definition=uint32_t(split-bundle->splits.begin()+1);
        } else if (split!=bundle->splits.end()) return {};
        const auto item_reticle=std::find_if(bundle->reticles.begin(),bundle->reticles.end(),[&](const auto &p){return p.id==row.id;});
        if (row.kind==23) {
            if (item_reticle==bundle->reticles.end() || item_reticle->aim_time<=0) return {};
            for (double value:{item_reticle->accel,item_reticle->aim_time,item_reticle->break_interval,item_reticle->exit_margin,item_reticle->follow_gap,item_reticle->follow_reach,item_reticle->retreat_speed,item_reticle->small_r}) if (!std::isfinite(float(value))) return {};
            definition.reticle_definition=uint32_t(item_reticle-bundle->reticles.begin()+1);definition.accel=item_reticle->accel;
        } else if (item_reticle!=bundle->reticles.end()) return {};
        bundle->definitions.push_back(std::move(definition));
    }
    if (records.EncounterDefinition_rows.size()!=1) return {};bundle->encounter=records.EncounterDefinition_rows.front();
    for (const auto &row:records.EncounterPattern_rows) {
        if (row.id!=bundle->encounter_patterns.size()+1) return {};EncounterPatternData p;
        p.attempts=row.attempts;p.min_fodder=row.min_fodder;p.margin=row.margin;p.window=row.window;p.draw_seconds=row.draw_seconds;p.exit_clearance=row.exit_clearance;p.rotation=row.rotation;p.scale_min=row.scale_min;p.scale_max=row.scale_max;p.min_spacing=row.min_spacing;bundle->encounter_patterns.push_back(std::move(p));
    }
    for (const auto &row:records.EncounterPoint_rows) {const godot::Vector2 point(row.x,row.y);if (!point.is_finite()) return {};bundle->encounter_patterns[row.pattern-1].route.push_back(point);}
    for (const auto &row:records.EncounterRegion_rows) {const godot::Vector2 point(row.x,row.y);if (!point.is_finite() || row.enemy>bundle->definitions.size() || row.max_count<row.min_count) return {};bundle->encounter_patterns[row.pattern-1].regions.push_back({row.enemy,row.min_count,row.max_count,point,row.angle,row.jitter,row.fodder,row.elite});}
    for (const auto &row:records.EncounterPhase_rows) bundle->encounter_phases.push_back(godot::String::utf8(row.name.c_str()));
    bundle->death_chains=records.DeathChainDefinition_rows;
    for (size_t i=0;i<bundle->death_chains.size();++i) bundle->definitions[bundle->death_chains[i].id-1].death_chain_definition=uint32_t(i+1);
    if (records.PopulationDefinition_rows.size()!=1) return {};
    bundle->population=records.PopulationDefinition_rows.front();const auto &pc=bundle->population;auto &timeline=bundle->population_timeline;
    if (pc.refill_time<=0) return {};
    timeline.boss_start=pc.boss_start;timeline.bonus_pop=pc.bonus_pop;timeline.density=pc.density;
    std::unordered_set<std::string> phases;
    for (const auto &row:records.PopulationPhase_rows) {
        if (row.id!=timeline.phases.size()+1 || row.wave_type>bundle->definitions.size() || row.external_id.empty() || !phases.insert(row.external_id).second || (!timeline.phases.empty() && row.start<timeline.phases.back().start) || row.attack_budget>INT32_MAX) return {};
        SpawnTimeline::Phase p;p.id=godot::String::utf8(row.external_id.c_str());p.start=row.start;p.pop_from=row.pop_from;p.pop_to=row.pop_to;p.rate=row.rate;p.xp_bonus=row.xp_bonus;p.budget=row.attack_budget;p.interval=row.surge_interval;p.pop=row.surge_pop;p.ranged=row.surge_ranged;p.elite=row.surge_elite;p.wave_interval=row.wave_interval;
        if (row.wave_type) p.wave_type=bundle->definitions[row.wave_type-1].id;else if (row.wave_interval>0) return {};
        timeline.phases.push_back(std::move(p));
    }
    if (pc.active && timeline.phases.empty()) return {};
    for (const auto &row:records.PopulationMix_rows) timeline.phases[row.phase-1].mix.emplace_back(bundle->definitions[row.enemy-1].id,row.weight);
    for (const auto &row:records.PopulationCurve_rows) {if (row.id!=timeline.curves.size()+1) return {};SpawnTimeline::Curve curve;curve.type=bundle->definitions[row.enemy-1].id;timeline.curves.push_back(std::move(curve));}
    for (const auto &row:records.PopulationPoint_rows) {auto &points=timeline.curves[row.curve-1].points;if (!points.empty() && row.time<points.back().time) return {};points.push_back({row.time,row.value,row.slope});}
    for (const auto &row:records.PopulationWindow_rows) {if (row.end!=-1 && row.end<row.start) return {};timeline.windows.emplace_back(row.start,row.end==-1?std::numeric_limits<double>::infinity():row.end);}
    if (records.PopulationType_rows.size()!=bundle->definitions.size()) return {};
    std::unordered_set<uint32_t> types;
    for (const auto &row:records.PopulationType_rows) {if (!types.insert(row.enemy).second) return {};timeline.types.push_back({bundle->definitions[row.enemy-1].id,row.rank,row.maximum,row.ranged});}
    // 配置の固定変換は生成済み。ここでは索引だけ作り、実際の画面・向きは出現時に読む。
    auto &formations=bundle->formations;
    for (const auto &row:records.FormationDefinition_rows) {
        if (row.id!=formations.size()+1 || (!formations.empty() && row.base_view!=bundle->formation_base_view)) return {};
        bundle->formation_base_view=row.base_view;formations.emplace_back();
    }
    std::vector<std::pair<size_t,size_t>> entries,layouts;
    for (const auto &row:records.FormationEntry_rows) {
        if (row.id!=entries.size()+1 || row.formation>formations.size() || !std::isfinite(float(row.x)) || !std::isfinite(float(row.y))) return {};
        auto &formation=formations[row.formation-1];entries.emplace_back(row.formation-1,formation.entries.size());
        formation.entries.push_back({row.weight,godot::Vector2(row.x,row.y)});
    }
    for (const auto &row:records.FormationLayout_rows) {
        if (row.id!=layouts.size()+1 || row.formation>formations.size()) return {};
        auto &formation=formations[row.formation-1];layouts.emplace_back(row.formation-1,formation.layouts.size());
        PopulationFormation::Layout layout;layout.weight=row.weight;layout.value=row.value;layout.managed=int32_t(row.managed);layout.placements.resize(formation.entries.size());formation.layouts.push_back(std::move(layout));
    }
    for (const auto &row:records.FormationType_rows) {
        if (row.layout>layouts.size()) return {};const auto [f,l]=layouts[row.layout-1];
        formations[f].layouts[l].types.push_back(bundle->definitions[row.enemy-1].id);
    }
    for (const auto &row:records.FormationMarker_rows) {
        if (row.layout>layouts.size() || row.entry>entries.size() || !std::isfinite(float(row.x)) || !std::isfinite(float(row.y))) return {};
        const auto [f,l]=layouts[row.layout-1];const auto [ef,e]=entries[row.entry-1];if (f!=ef) return {};
        auto &layout=formations[f].layouts[l];auto &markers=layout.placements[e];
        if (markers.size()>=layout.types.size() || layout.types[markers.size()]!=bundle->definitions[row.enemy-1].id) return {};
        markers.push_back({bundle->definitions[row.enemy-1].id,godot::Vector2(row.x,row.y),row.rotation});
    }
    for (const auto &formation:formations) {
        if (formation.entries.empty() || formation.layouts.empty()) return {};
        for (const auto &layout:formation.layouts) for (const auto &markers:layout.placements) if (markers.size()!=layout.types.size()) return {};
    }
    for (const auto &row:records.PopulationClip_rows) {
        if (row.id!=bundle->population_clips.size()+1 || (row.end!=-1 && row.end<row.start)) return {};
        PopulationClipData clip;clip.start=row.start;clip.end=row.end==-1?std::numeric_limits<double>::infinity():row.end;clip.interval=row.interval;clip.maximum=row.groups;clip.priority=row.priority;bundle->population_clips.push_back(std::move(clip));
    }
    for (const auto &row:records.PopulationClipType_rows) bundle->population_clips[row.clip-1].types.push_back(bundle->definitions[row.enemy-1].id);
    for (const auto &row:records.PopulationClipFormation_rows) bundle->population_clips[row.clip-1].formations.push_back(row.formation-1);
    bundle->corona_ammunition.resize(bundle->coronas.size());std::unordered_set<std::string> corona_names;
    for (const auto &row:records.CoronaType_rows) {
        if (row.owner>bundle->definitions.size() || row.name.empty() || !std::isfinite(row.weight) || !std::isfinite(row.damage) || !corona_names.insert(std::to_string(row.owner)+":"+row.name).second) return {};
        const auto &owner=bundle->definitions[row.owner-1];if (!owner.corona_definition) return {};
        const auto target=std::find_if(bundle->definitions.begin(),bundle->definitions.end(),[&](const auto &d){return godot::String(d.id).utf8().get_data()==row.name;});
        if (target!=bundle->definitions.end()) bundle->corona_ammunition[owner.corona_definition-1].push_back({uint32_t(target-bundle->definitions.begin()),row.weight,row.damage});
    }
    for (size_t i=0;i<bundle->centaurus_bodies.size();++i) {
        const auto &p=bundle->centaurus_bodies[i];
        if (p.id!=i+1 || bundle->bosses[bundle->boss_bodies[p.body-1].boss-1].kind!=1 || bundle->definitions[p.guard-1].kind!=EnemyDefinition::Kind::Defender || p.keep_max<p.keep_min || p.guard_min>p.guard_count || p.sail_guard_max<p.sail_guard_min || p.leap_time<=0) return {};
        for (size_t j=0;j<i;++j) if (bundle->centaurus_bodies[j].body==p.body) return {};
    }
    for (size_t i=0;i<bundle->boss_bodies.size();++i) {
        const auto &body=bundle->boss_bodies[i];const auto &boss=bundle->bosses[body.boss-1];
        if (boss.kind==1 && std::none_of(bundle->centaurus_bodies.begin(),bundle->centaurus_bodies.end(),[&](const auto &p){return p.body==body.id;})) return {};
        if (boss.kind==2 && std::none_of(bundle->canis_bodies.begin(),bundle->canis_bodies.end(),[&](const auto &p){return p.boss==body.boss;})) return {};
        if (body.id!=i+1 || body.phase_threshold<=0 || body.phase_threshold>=1 || body.final_widen_time<=0 || bundle->definitions[body.enemy-1].kind!=(boss.kind==0?EnemyDefinition::Kind::Monoceros:boss.kind==1?EnemyDefinition::Kind::Centaurus:EnemyDefinition::Kind::CanisMajor)) return {};
    }
    for (size_t i=0;i<bundle->canis_bodies.size();++i) {const auto &p=bundle->canis_bodies[i];if (p.id!=i+1 || bundle->bosses[p.boss-1].kind!=2 || bundle->definitions[p.hound-1].kind!=EnemyDefinition::Kind::Hound || p.lead_scan<=0) return {};}
    std::unordered_set<std::string> tuning_keys;
    for (const auto &row:records.EnemyTuningValue_rows) {
        if (row.id!=bundle->enemy_tuning.size()+1 || row.key.empty() || row.key.size()>128 || !std::isfinite(row.value) || !tuning_keys.insert(std::to_string(row.enemy)+":"+row.key).second) return {};
        bundle->enemy_tuning.push_back(row);
    }
    return bundle;
}
}
