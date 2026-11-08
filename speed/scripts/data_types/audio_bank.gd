## 制作工程で音の表からまとめた効果音とBGM。キーは音の表の欄ID。
class_name AudioBank
extends Resource
## 欄ID → 鳴らす効果音。音のない欄は入れない。
@export var sounds: Dictionary = {}
## 欄ID → 鳴らす曲。音のない欄は入れない。
@export var music: Dictionary = {}
## 欄ID → 鳴らし方（volume_db・pitch_min・pitch_max・max_voices・loop・trim_start・trim_end・loop_start）。全欄を入れる。
@export var params: Dictionary = {}
