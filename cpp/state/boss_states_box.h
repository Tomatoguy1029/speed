#pragma once
namespace speed {
struct BossStates;
// ボス状態の定義を読まずに RunState を扱えるよう、値の意味を保ったまま別領域に置く。
class BossStatesBox {
    BossStates *value;
public:
    BossStatesBox();
    BossStatesBox(const BossStatesBox &other);
    BossStatesBox &operator=(const BossStatesBox &other);
    ~BossStatesBox();
    BossStates *operator->() {return value;}
    const BossStates *operator->() const {return value;}
    BossStates &operator*() {return *value;}
    const BossStates &operator*() const {return *value;}
};
}
