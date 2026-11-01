#include "content_bundle.h"
#include <godot_cpp/classes/hashing_context.hpp>
#include <algorithm>
#include <cstring>
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
    for (const auto &bite:bundle->bites) {
        const auto &first=bundle->bites.front();
        if (bite.duration!=first.duration || bite.scene!=first.scene || bite.hit!=first.hit || bite.fade!=first.fade) return {};
    }
    if (records.LoadoutDefinition_rows.size()!=1 || records.LoadoutDefinition_rows[0].id!=1 ||
        records.LoadoutDefinition_rows[0].kind!=0 || bundle->forward_levels.size()!=records.LoadoutDefinition_rows[0].maximum_level) return {};
    for (size_t i=0;i<bundle->forward_levels.size();++i) {
        const auto &level=bundle->forward_levels[i];
        if (level.weapon!=1 || level.level!=i+1 || level.interval<=0) return {};
    }
    for (const auto &visual:bundle->visuals) {
        if (visual.role>6 || (visual.path.empty() && visual.role!=2 && visual.role!=4)) return {};
    }
    std::unordered_set<std::string> names;
    for (const auto &row:records.EnemyRecord_rows) {
        auto string=std::find_if(records.StringEntry_rows.begin(),records.StringEntry_rows.end(),[&](const auto &s){return s.id==row.id;});
        auto index=std::find_if(records.DefinitionIndex_rows.begin(),records.DefinitionIndex_rows.end(),[&](const auto &s){return s.id==row.id && s.enemy==row.id;});
        if (string==records.StringEntry_rows.end() || string->value.empty() || !names.insert(string->value).second ||
            index==records.DefinitionIndex_rows.end() || row.hp<=0 || row.radius<=0) return {};
        if (row.kind!=0 && row.kind!=2) return {};
        auto definition=to_enemy(row,godot::String::utf8(string->value.c_str(),string->value.size()));
        const auto bite=std::find_if(bundle->bites.begin(),bundle->bites.end(),[&](const auto &b){return b.id==row.id;});
        if (row.kind==2) {
            if (bite==bundle->bites.end() || bite->warn<=0 || bite->duration<=0 || bite->scene.empty()) return {};
            definition.bite={bite->reach,bite->warn,bite->rest,bite->radius,bite->damage};
        } else if (bite!=bundle->bites.end()) return {};
        bundle->definitions.push_back(std::move(definition));
    }
    return bundle;
}
}
