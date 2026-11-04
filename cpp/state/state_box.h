#pragma once
namespace speed {
// 状態の定義を読まずに RunState を扱えるよう、値の意味を保ったまま別領域に置く。
// 実体は state_box.cpp の明示的なインスタンス化で用意する。
template<class T> class StateBox {
    T *value;
public:
    StateBox();
    StateBox(const StateBox &other);
    StateBox &operator=(const StateBox &other);
    ~StateBox();
    T *operator->() {return value;}
    const T *operator->() const {return value;}
    T &operator*() {return *value;}
    const T &operator*() const {return *value;}
};
struct BossStates;
struct LoadoutState;
}
