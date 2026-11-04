#pragma once
#include <cstdint>
#include <optional>
namespace speed {
// 戦闘用PCG32。表示の乱数とは独立した値型。
class RunRandom {
    uint64_t state=0;
public:
    uint32_t next_u32() {
        const uint64_t old=state;
        state=old*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407);
        const uint32_t value=uint32_t(((old>>18)^old)>>27);
        const uint32_t rotation=uint32_t(old>>59);
        return (value>>rotation)|(value<<((0-rotation)&31));
    }
    void set_seed(uint64_t seed) { state=0;next_u32();state+=seed;next_u32(); }
    uint64_t get_state() const { return state; }
    void set_state(uint64_t value) { state=value; }
    double randf() { return double(next_u32())/4294967296.0; }
    double randf_range(double a,double b) { return a+(b-a)*randf(); }
    std::optional<int64_t> randi_range(int64_t a,int64_t b) {
        if (a>b) return {};
        const uint64_t difference=uint64_t(b)-uint64_t(a);
        if (difference>=UINT64_C(4294967296)) return {};
        const uint64_t span=difference+1;
        if (span==UINT64_C(4294967296)) return a+int64_t(next_u32());
        const uint32_t width=uint32_t(span);
        const uint32_t threshold=uint32_t(0-width)%width;
        uint32_t value;
        do {value=next_u32();} while (value<threshold);
        return a+int64_t(value%width);
    }
};
}
