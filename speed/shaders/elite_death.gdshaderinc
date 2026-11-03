// 制作時に固定した各ピクセルの消失時刻。生存中の素材では無効。
uniform bool death_enabled = false;
uniform sampler2D death_map : filter_nearest, repeat_disable;
