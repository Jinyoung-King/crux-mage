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
# 전용 패시브 (캐릭터마다 하나씩, 해당 필드만 채움)
@export var passive_wave_heal: float = 0.0       ## 견습: 웨이브 시작 시 회복량
@export var passive_burn_dps: float = 0.0        ## 화염: 명중 시 화상 초당 피해
@export var passive_burn_duration: float = 0.0   ## 화상 지속(초)
@export var passive_crit_chance: float = 0.0     ## 궁사: 치명타 확률(0~1)
@export var passive_crit_mult: float = 1.0       ## 치명타 데미지 배수
@export var passive_slow_factor: float = 1.0     ## 서리: 둔화 시 속도 배수(1=둔화 없음)
@export var passive_slow_duration: float = 0.0   ## 둔화 지속(초). 0이면 둔화 없음
@export var passive_chain_count: int = 0         ## 뇌전: 명중 시 인근 적에게 연쇄하는 횟수
@export var passive_chain_factor: float = 0.0    ## 연쇄 1회당 데미지 비율
@export var passive_chain_range: float = 220.0   ## 연쇄 사정거리(px)
@export var passive_splash_factor: float = 0.0   ## 포격: 명중 시 반경 내 적에게 (명중피해×이 비율) 광역 피해
@export var passive_splash_radius: float = 90.0  ## 광역 반경(px)
