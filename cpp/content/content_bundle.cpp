#include "content_bundle.h"
#include <godot_cpp/classes/hashing_context.hpp>
#include <algorithm>
#include <cstring>
#include <cmath>
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
            section.kind<1 || section.kind>SECTION_COUNT || !kinds.insert(section.kind).second ||
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
    bundle->aim_lag=records.RunConfig_rows[0].aim_lag;bundle->aim_speed=records.RunConfig_rows[0].aim_speed;
    bundle->crystal_values={records.RunConfig_rows[0].crystal_low,records.RunConfig_rows[0].crystal_mid,records.RunConfig_rows[0].crystal_high};
    bundle->visuals=records.ResourceKey_rows;
    bundle->forward_levels=records.ForwardDefinition_rows;
    bundle->bites=records.BiteDefinition_rows;
    bundle->hounds=records.HoundDefinition_rows;
    bundle->gunners=records.GunnerDefinition_rows;
    bundle->beamers=records.BeamerDefinition_rows;
    bundle->contacts=records.ContactDefinition_rows;
    bundle->hostile_definitions=records.HostileDefinition_rows;
    bundle->beams=records.BeamDefinition_rows;
    bundle->friend_shots=records.FriendShotDefinition_rows;
    for (const auto &shot:bundle->hostile_definitions) {
        if (shot.life<=0 || shot.radius<=0) return {};
        for (double value:{shot.radius,shot.life,shot.slow,shot.turn}) if (!std::isfinite(float(value))) return {};
    }
    bundle->budget_phases=records.BudgetPhase_rows;
    if (records.ProgressionDefinition_rows.size()!=1 || records.ProgressionDefinition_rows.front().xp_base<=0) return {};
    bundle->progression=records.ProgressionDefinition_rows.front();
    if (records.LifecycleDefinition_rows.size()!=1) return {};
    bundle->lifecycle=records.LifecycleDefinition_rows.front();
    bundle->field_bodies=records.FieldBodyDefinition_rows;
    for (const auto &body:bundle->field_bodies) if (body.radius<=0) return {};
    bundle->rock_fields=records.RockFieldDefinition_rows;
    if (bundle->rock_fields.size()>1) return {};
    bundle->moon_definitions=records.MoonDefinition_rows;
    for (const auto &moon:bundle->moon_definitions) if (moon.orbit_max<moon.orbit_min || moon.radius_min<=0 || moon.radius_max<moon.radius_min) return {};
    bundle->equipment=records.LoadoutDefinition_rows;
    bundle->equipment_assets=records.LoadoutAsset_rows;
    bundle->numeric_traits=records.NumericTraitLevel_rows;
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
        // カプセルは未装備の彗星武器をIDで保持する。実行の登録は武器ごとに確認する。
        if (d.kind==0 && d.comet_only) continue;
        if (d.kind!=1 || (d.external_id!="T34" && d.external_id!="T35" && d.external_id!="T36")) return {};
        if (d.maximum_level>bundle->numeric_traits.size()) return {};
        for (uint32_t level=1;level<=d.maximum_level;++level) {
            if (std::count_if(bundle->numeric_traits.begin(),bundle->numeric_traits.end(),[&](const auto &v){return v.equipment==d.id && v.level==level;})!=1) return {};
        }
    }
    for (const auto &v:bundle->numeric_traits) {
        const auto &d=bundle->equipment[v.equipment-1];
        if (d.kind!=1 || v.level>d.maximum_level) return {};
    }
    for (const auto &visual:bundle->visuals) {
        if (visual.role>13) return {};
    }
    std::unordered_set<std::string> names;
    for (const auto &row:records.EnemyRecord_rows) {
        auto string=std::find_if(records.StringEntry_rows.begin(),records.StringEntry_rows.end(),[&](const auto &s){return s.id==row.id;});
        auto index=std::find_if(records.DefinitionIndex_rows.begin(),records.DefinitionIndex_rows.end(),[&](const auto &s){return s.id==row.id && s.enemy==row.id;});
        if (string==records.StringEntry_rows.end() || string->value.empty() || !names.insert(string->value).second ||
            index==records.DefinitionIndex_rows.end() || row.hp<=0 || row.radius<=0) return {};
        if (row.kind!=0 && row.kind!=1 && row.kind!=2 && row.kind!=3 && row.kind!=4 && row.kind!=5 && row.kind!=6 && row.kind!=7 && row.kind!=8) return {};
        auto definition=to_enemy(row,godot::String::utf8(string->value.c_str(),string->value.size()));
        const auto shield=std::find_if(records.ShieldDefinition_rows.begin(),records.ShieldDefinition_rows.end(),[&](const auto &s){return s.id==row.id;});
        if (row.kind==1) {
            if (shield==records.ShieldDefinition_rows.end() || shield->reflected>bundle->hostile_definitions.size() || shield->turn<=0) return {};
            const auto &reflected=bundle->hostile_definitions[shield->reflected-1];if (reflected.kind!=uint32_t(HostileKind::Reflected)) return {};
            definition.accel=shield->accel;definition.turn=shield->turn;definition.weak_arc=shield->weak_arc;definition.front_arc=shield->front_arc;
            definition.reflect_speed=shield->reflect_speed;definition.reflect_interval=shield->reflect_interval;definition.shield_time=shield->shield_time;
            definition.reflected_definition=shield->reflected;definition.reflect_life=reflected.life;definition.reflect_damage=reflected.damage;
        } else if (shield!=records.ShieldDefinition_rows.end()) return {};
        const auto bite=std::find_if(bundle->bites.begin(),bundle->bites.end(),[&](const auto &b){return b.id==row.id;});
        if (row.kind==2 || row.kind==3) {
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
        bundle->definitions.push_back(std::move(definition));
    }
    return bundle;
}
}
