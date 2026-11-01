#pragma once
namespace speed {
// 射撃型の実体登録はE_gunner。予告と再装填の残り時間は共通部品で進める。
class GunnerTiming {
public:
    static bool advance(double &remaining,double &charge,double dt,double warn,double interval);
};
}
