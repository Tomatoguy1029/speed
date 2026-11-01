#pragma once
#include <cstdint>
#include <limits>
#include <vector>

namespace speed {
// タグの違う参照は互いに代入できない。値の表と同じslotを使う。
template<class Tag> struct Handle {
    uint32_t slot = UINT32_MAX;
    uint32_t generation = 0;
};
struct EnemyTag {};
using EnemyHandle = Handle<EnemyTag>;

template<class Tag> class EntityStore {
    struct Slot { uint32_t generation = 1; int64_t id = 0; };
    std::vector<Slot> slots;
public:
    Handle<Tag> attach(uint32_t slot, int64_t id) {
        if (slot == UINT32_MAX || id <= 0) return {};
        if (slot >= slots.size()) slots.resize(size_t(slot) + 1);
        auto &entry = slots[slot];
        if (entry.id || entry.generation == UINT32_MAX) return {};
        entry.id = id;
        return {slot, entry.generation};
    }
    bool contains(Handle<Tag> handle) const {
        return handle.slot < slots.size() && slots[handle.slot].id > 0 &&
               slots[handle.slot].generation == handle.generation;
    }
    Handle<Tag> at(uint32_t slot) const {
        return slot < slots.size() && slots[slot].id > 0 ? Handle<Tag>{slot, slots[slot].generation} : Handle<Tag>{};
    }
    bool release(Handle<Tag> handle) {
        if (!contains(handle)) return false;
        auto &entry = slots[handle.slot];
        entry.id = 0;
        ++entry.generation;
        return true;
    }
    bool reusable(uint32_t slot) const {
        return slot < slots.size() && !slots[slot].id && slots[slot].generation < UINT32_MAX;
    }
};
}
