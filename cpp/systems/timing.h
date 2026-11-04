#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include "../runtime/run_random.h"
namespace speed {
struct RemainingTimer {
    double remaining=0;
    void advance(double dt) {remaining=std::max(0.0,remaining-dt);}
    bool due() const {return remaining<=0;}
};
inline double remaining_time(double value,double dt) {RemainingTimer timer{value};timer.advance(dt);return timer.remaining;}
struct IntervalTimer {
    double remaining=0;
    void advance(double dt) {remaining-=dt;}
    bool due() const {return remaining<=0;}
    void fired(double interval) {remaining+=interval;}
    // W01は端数を保ち、同じ更新で不足分の弾をまとめて撃たない。
    void skip_missed(double interval) {if (due()) remaining=interval+std::fmod(remaining,interval);}
};
inline bool expired(double now,double deadline) {return now>=deadline;}
template<class Rows,class Weight> int64_t weighted_choice(const Rows &rows,RunRandom &random,Weight weight) {
    double total=0;for (const auto &row:rows) total+=weight(row);
    if (rows.empty() || total<=0) return -1;
    double roll=random.randf()*total;
    for (size_t i=0;i<rows.size();++i) {roll-=weight(rows[i]);if (roll<0) return int64_t(i);}
    return int64_t(rows.size()-1);
}
}
