#include "run_core.h"
#include "../bosses/flow/technique_runner.h"
#include "../bosses/flow/flow_runner.h"
using namespace godot;
Dictionary SpeedRunCore::development_boss_command(const String &kind,const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()){Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"boss";out["message"]=ok?"":"ボス技の命令が不正です";out["value"]=value;return out;};
    if (!runtime.api_development) return result(false);
    if (kind=="dev_boss_flow_state") return result(p.is_empty(),speed::FlowRunner::snapshot(runtime));
    if (kind=="dev_cancel_flow") {
        if (p.size()!=1 || p.get("entity_id",Variant()).get_type()!=Variant::INT) return result(false);
        for (auto &flow:runtime.state.bosses.flows) if (runtime.state.enemy_handles.entity_id(flow.actor)==int64_t(p["entity_id"])) {speed::FlowRunner::cancel(runtime,flow);flow.selection_enabled=false;return result(true);}
        return result(false);
    }
    if (kind=="dev_boss_flow") {
        if ((p.size()!=2 && p.size()!=3) || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("definition",Variant()).get_type()!=Variant::INT || (p.has("participants") && p["participants"].get_type()!=Variant::PACKED_INT64_ARRAY)) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));const int64_t definition=p["definition"];std::vector<speed::EnemyHandle> participants;
        if (p.has("participants")) {const PackedInt64Array ids=p["participants"];for (auto id:ids) {const auto item=runtime.state.rows_by_id.find(id);if (item==runtime.state.rows_by_id.end()) return result(false);participants.push_back(runtime.state.enemy_handles.at(item->second));}}
        return result(found!=runtime.state.rows_by_id.end() && definition>0 && uint64_t(definition)<=runtime.content->boss_flows.size() && speed::FlowRunner::attach(runtime,runtime.state.enemy_handles.at(found->second),definition,participants));
    }
    if (kind=="dev_boss_state") return result(p.is_empty(),speed::TechniqueRunner::snapshot(runtime));
    if (kind=="dev_boss_technique") {
        if (p.size()!=2 || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("definition",Variant()).get_type()!=Variant::INT) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));const int64_t definition=p["definition"];
        if (found==runtime.state.rows_by_id.end() || definition<=0 || uint64_t(definition)>runtime.content->boss_techniques.size()) return result(false);
        const auto handle=speed::TechniqueRunner::begin(runtime,runtime.state.enemy_handles.at(found->second),uint32_t(definition));
        if (!runtime.state.bosses.handles.contains(handle)) return result(false);
        PackedInt64Array ticket;ticket.push_back(handle.slot);ticket.push_back(handle.generation);return result(true,ticket);
    }
    if (p.size()!=1 || p.get("ticket",Variant()).get_type()!=Variant::PACKED_INT64_ARRAY) return result(false);
    const PackedInt64Array ticket=p["ticket"];if (ticket.size()!=2 || ticket[0]<0 || ticket[0]>=UINT32_MAX || ticket[1]<=0 || ticket[1]>UINT32_MAX) return result(false);
    const speed::TechniqueHandle handle{uint32_t(ticket[0]),uint32_t(ticket[1])};
    if (!speed::TechniqueRunner::running(runtime,handle)) return result(false);
    speed::TechniqueRunner::cancel(runtime,handle);return result(true);
}
