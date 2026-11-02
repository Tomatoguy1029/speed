#pragma once
#include "entity_store.h"
#include <vector>
#include <algorithm>
#include <cstdint>
namespace speed {
struct ActionObservation {
    int64_t id=0,actor_id=0;uint32_t definition=0;
    uint64_t checks=0,contacts=0,attacks=0;
    double applied=0;
    bool executed=false,observed_start=true,running=true;
};
struct ObservationEvent {ActionObservation action;enum Step {Selected,Execute,Finished,RecordingEnd,ActorEnd} step=Selected;};
// 行動と発生攻撃が同じ値IDを保持する。終了済みの行動も残留攻撃の間は保持する。
struct ObservationState {
    bool recording=false;int64_t next_id=1;
    std::vector<ActionObservation> actions;
    std::vector<ObservationEvent> pending;
    ActionObservation *find(int64_t id) {for (auto &a:actions) if (a.id==id) return &a;return nullptr;}
    int64_t begin(int64_t actor,uint32_t definition,bool observed=true) {
        if (!recording || next_id==INT64_MAX) return 0;
        ActionObservation a;a.id=next_id++;a.actor_id=actor;a.definition=definition;a.observed_start=observed;
        actions.push_back(a);pending.push_back({a,ObservationEvent::Selected});return a.id;
    }
    void execute(int64_t id) {if (auto *a=find(id);a && !a->executed) {a->executed=true;pending.push_back({*a,ObservationEvent::Execute});}}
    void retain(int64_t id) {if (auto *a=find(id)) {++a->attacks;execute(id);}}
    void close(int64_t id,ObservationEvent::Step step=ObservationEvent::Finished) {
        for (auto it=actions.begin();it!=actions.end();++it) if (it->id==id) {pending.push_back({*it,step});actions.erase(it);return;}
    }
    void release(int64_t id) {if (auto *a=find(id)) {if (a->attacks) --a->attacks;if (!a->running && !a->attacks) close(id);}}
    void finish(int64_t id) {if (auto *a=find(id)) {a->running=false;if (!a->attacks) close(id);}}
    void actor_ended(int64_t actor) {for (size_t i=actions.size();i>0;--i) if (actions[i-1].actor_id==actor) close(actions[i-1].id,ObservationEvent::ActorEnd);}
    void stop() {while (!actions.empty()) close(actions.back().id,ObservationEvent::RecordingEnd);recording=false;}
};
}
