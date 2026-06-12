class_name CharacterData
extends Resource
## 플레이어 캐릭터 정의. 캐릭터마다 전용 무기(발사체)·발사음·기본 빌드(플레이스타일)가 다르다.

@export var display_name: String = ""
@export var description: String = ""
@export var mage_sprite: Texture2D
@export var projectile_sprite: Texture2D
@export var shoot_sound: AudioStream
# 시작 빌드 (무기 정체성)
@export var base_damage: float = 10.0
@export var base_fire_rate: float = 2.0
@export var base_projectile_count: int = 1
@export var base_pierce: int = 0
@export var unlock_wave: int = 0  ## 최고 도달 웨이브가 이 값 이상이면 해금 (0 = 기본 해금)
@export var accent_color: Color = Color(0.3, 0.5, 1.0)
