class_name Tuning
extends Object
## Mọi thông số gameplay. Bảng súng và xe nằm ở data/*.json.

const TILE := 64

# Lớp va chạm (khớp layer_names trong project.godot).
const LAYER_WORLD := 1
const LAYER_ACTORS := 2
const LAYER_VEHICLES := 4
const LAYER_PICKUPS := 8

# Người chơi
const WALK_SPEED := 220.0
const WALK_ACCEL := 1600.0
const MAX_HEALTH := 100.0
const MAX_ARMOR := 100.0
const INTERACT_RADIUS := 90.0
const LOOK_AHEAD := 150.0
const LOOK_AHEAD_DRIVING := 0.45  # giây nhìn trước theo vận tốc xe
const CAMERA_SMOOTH := 6.0
const MOUSE_AIM_IDLE := 2.0  # giây không động chuột thì chuyển sang ngắm bằng tay cầm

# Người (NPC)
const PED_SPEED := 70.0
const PED_FLEE_SPEED := 190.0
const PED_HEALTH := 40.0
const PED_FLEE_TIME := 6.0
const HEAR_GUNSHOT_RADIUS := 520.0
const KNOCKDOWN_TIME := 1.6
const CORPSE_TIME := 8.0
const COP_HEALTH := 70.0
const COP_SPEED := 170.0
const GANG_HEALTH := 65.0
const GANG_SPEED := 150.0
const NPC_SIGHT := 480.0
const NPC_SHOOT_RANGE := 380.0
const NPC_AIM_ERROR_DEG := 12.0
const NPC_REACTION := 0.5
const NPC_RATE_SCALE := 0.4  # NPC bắn chậm và yếu hơn súng cùng loại của người chơi
const NPC_DAMAGE_SCALE := 0.65
const PATH_REFRESH := 0.6
const OFFROAD_COST := 4.0  # A* lái xe: đi ngoài lòng đường đắt gấp mấy lần
const MONEY_DROP := Vector2i(40, 90)

# Đòn đánh
const KNOCKBACK_DAMP := 9.0
const FLASH_TIME := 0.08
const BURN_TIME := 3.0
const BURN_DPS := 10.0
const RUNOVER_SPEED := 110.0
const RUNOVER_DAMAGE_PER_SPEED := 0.18

# Xe
const VEHICLE_SCALE := 0.78
const CRASH_MIN_SPEED := 220.0
const CRASH_COOLDOWN := 0.35
const CRASH_BOUNCE := 0.35
const CRASH_DAMAGE_PER_SPEED := 0.08
const VEHICLE_SMOKE_RATIO := 0.35
const VEHICLE_BURN_TIME := 3.0
const VEHICLE_EXPLOSION_DAMAGE := 160.0
const VEHICLE_EXPLOSION_RADIUS := 170.0
const WRECK_TIME := 20.0
const DRIFT_GRIP := 2.2
const HANDBRAKE_GRIP := 1.2
const STEER_FULL_SPEED := 180.0  # tốc độ đạt bán kính lái đầy đủ
const BAIL_SPEED := 120.0  # xuống xe khi nhanh hơn thì ngã lăn

# Xe tự lái
const TRAFFIC_SPEED := 150.0
const TRAFFIC_ACCEL := 220.0
const TRAFFIC_LOOK := 120.0
const HONK_AFTER := 1.4
const HONK_COOLDOWN := 3.0

# Dân số quanh camera
const MAX_PEDS := 16
const MAX_CARS := 10
const SPAWN_MIN_DIST := 800.0
const SPAWN_MAX_DIST := 1150.0
const DESPAWN_DIST := 1500.0
const POPULATION_TICK := 0.5

# Truy nã
const MAX_STARS := 3
const HEAT_SHOOT_PED := 35.0
const HEAT_KILL_PED := 60.0
const HEAT_HIT_COP := 60.0
const HEAT_KILL_COP := 120.0
const HEAT_CARJACK_SEEN := 110.0
const HEAT_GUNFIRE_SEEN := 15.0
const LOSE_STAR_TIME := [0.0, 8.0, 12.0, 16.0]  # giây không bị thấy để giảm 1 sao (theo số sao hiện tại)
const COP_SIGHT := 560.0
const COPS_ON_FOOT := [0, 2, 3, 4]
const COP_CARS := [0, 0, 1, 2]
const MAX_COPS := 8
const COP_WEAPON := ["pistol", "pistol", "pistol", "smg"]
const COP_CAR_STOP_DIST := 260.0

# Tiền và chết
const START_MONEY := 300
const DEATH_FEE := 0.10
const CAR_SELL_PRICE := {"moto": 250, "car": 500, "police": 800, "sports": 900}
const ARMOR_PRICE := 400
const MEDKIT_PRICE := 150
const DEATH_SCREEN_DELAY := 1.2
const AUTOSAVE_INTERVAL := 30.0

# Nhiệm vụ
const MISSION1_TIME := 55.0
const MISSION_RADIUS := 56.0
const GANG_COUNT := 6

# Hiệu ứng
const SHAKE_DECAY := 2.2
const SHAKE_MAX_OFFSET := 18.0
const TRACER_TIME := 0.06
const MUZZLE_TIME := 0.05

# Ngưỡng nhiệt truy nã cho từng sao (1, 2, 3)
const STAR_HEAT := [40.0, 140.0, 260.0]
const MAX_HEAT := 400.0
const FADE_TIME := 0.25

# Quảng cáo
const AD_INTERSTITIAL_GRACE := 180.0  # không chiếu trong 3 phút đầu phiên
const AD_INTERSTITIAL_GAP := 180.0
const AD_FREE_AMMO_GAP := 300.0
const AD_DEBUG_DURATION := 2.0

# Dáng đi (Kenney không có frame bước: nhún và lắc sprite)
const BOB_FREQ := 11.0
const BOB_SCALE := 0.05
const SWAY_DEG := 4.0
const HUMAN_RADIUS := 13.0

# Vật phóng
const GRENADE_SPEED := 620.0
const GRENADE_DAMP := 2.0
const GRENADE_FUSE := 1.5
const GRENADE_BOUNCE := 0.45
const ROCKET_SPEED := 950.0
const EXPLOSION_KNOCKBACK := 420.0
const SELF_BLAST_SCALE := 0.5  # vụ nổ của chính mình gây nửa sát thương
const MAX_CASINGS := 40
const CASING_LIFE := 3.0

# Lái xe (thông số riêng từng loại ở data/vehicles.json)
const VEHICLE_DRAG := 160.0
const DRIFT_MIN_LATERAL := 110.0
const SKID_EVERY := 0.03
const SKID_LIFE := 6.0
const STUCK_TIME := 1.2
