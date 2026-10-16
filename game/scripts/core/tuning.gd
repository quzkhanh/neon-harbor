class_name Tuning
extends Object
## Mọi thông số gameplay. Bảng súng và xe nằm ở data/*.json.

const TILE := 64

# Lớp va chạm (khớp layer_names trong project.godot).
const LAYER_WORLD := 1
const LAYER_ACTORS := 2
const LAYER_VEHICLES := 4
const LAYER_PICKUPS := 8
const LAYER_AIR := 16  # trực thăng: trúng đạn được, không va chạm với ai
const LAYER_WATER := 32  # mặt nước: chặn xe và NPC; Jay đi bộ thì bơi qua được, thuyền thì chỉ chạy trên nước
const MASK_HUMAN := LAYER_WORLD | LAYER_VEHICLES | LAYER_ACTORS | LAYER_WATER
const MASK_SWIMMER := LAYER_WORLD | LAYER_VEHICLES | LAYER_ACTORS
const MASK_CAR := LAYER_WORLD | LAYER_VEHICLES | LAYER_WATER

# Người chơi
const WALK_SPEED := 220.0
const WALK_ACCEL := 1600.0
const SWIM_SPEED := 110.0
const SWIM_BREATH := 20.0  # giây bơi trước khi hết hơi
const SWIM_RECOVER := 3.0  # lên bờ: hồi hơi nhanh gấp chừng này
const SWIM_DROWN_DPS := 10.0
const MAX_HEALTH := 100.0
const MAX_ARMOR := 100.0
const REGEN_DELAY := 4.0  # giây không trúng đòn thì bắt đầu hồi máu
const REGEN_RATE := 6.0  # máu/giây
const REGEN_CAP := 60.0  # chỉ tự hồi tới mức này; trên nữa cần hộp máu hoặc bệnh viện
const MEDKIT_PICKUP := 50.0  # hộp máu nhặt trên đường
const ARMOR_PICKUP := 50.0
const PICKUP_RESPAWN := 60.0
const DROP_HEALTH := 20.0  # hộp máu nhỏ kẻ địch rơi
const GANG_HEALTH_DROP := 0.35  # xác suất rơi
const COP_HEALTH_DROP := 0.2
const INTERACT_RADIUS := 90.0
const LOOK_AHEAD := 150.0
const LOOK_AHEAD_DRIVING := 0.45  # giây nhìn trước theo vận tốc xe
const CAMERA_SMOOTH := 6.0
const LOOK_SMOOTH := 2.5  # điểm nhìn trước đổi dần: xe bật ngược khi đâm không quét cả khung hình theo
# Điều khiển cảm ứng (đơn vị khung 1280×720; nhân Game.settings.touch_scale)
const TOUCH_STICK_RADIUS := 110.0
const TOUCH_KNOB := 46.0
const TOUCH_BUTTON := 110.0
const TOUCH_FIRE := 170.0  # nút BẮN to hơn các nút phụ
const TOUCH_OPACITY_RANGE := Vector2(0.4, 1.0)  # thanh trượt "Độ đậm nút"
const TOUCH_HAPTIC_MS := 18  # rung ngắn khi bấm nút (nếu máy hỗ trợ)
const TOUCH_GAP := 14.0
const TOUCH_EDGE := 20.0
const TOUCH_SCALE_RANGE := Vector2(0.9, 1.4)  # thanh trượt "Cỡ nút điều khiển" (0,9: nút vẫn ≥ 56px ở 915×412)
const AIM_ASSIST_DEG := 20.0  # joystick/analog: hút tâm vào kẻ địch lệch tối đa chừng này độ
const MOUSE_AIM_IDLE := 2.0  # giây không động chuột thì chuyển sang ngắm bằng tay cầm
const WHEEL_HOLD := 0.25  # giữ phím đổi súng chừng này giây thì mở vòng chọn súng
const WHEEL_SLOWMO := 0.25

# Người (NPC)
const PED_SPEED := 70.0
const PED_FLEE_SPEED := 190.0
const PED_HEALTH := 40.0
const PED_FLEE_TIME := 6.0
const ARMED_PED_CHANCE := 0.15  # người đi đường có súng, bị tấn công thì bắn trả
const ANGRY_TIME := 8.0
const CARJACK_FIGHT_CHANCE := 0.25  # tài xế bị cướp xe đánh lại
const WITNESS_DELAY := 3.5  # người chứng kiến còn sống sau chừng này giây thì cuộc gọi báo cảnh sát tới nơi
const WITNESS_COOLDOWN := 10.0
const ZOMBIE_SPEED := 95.0
const ZOMBIE_SENSE := 700.0
const ZOMBIE_REACH := 34.0
const ZOMBIE_BITE := 8.0
const ZOMBIE_BITE_EVERY := 0.9
const HEAT_WITNESS := 45.0
const HEAR_GUNSHOT_RADIUS := 520.0
const KNOCKDOWN_TIME := 1.6
const CORPSE_TIME := 25.0
const CORPSE_FADE := 1.5
const CORPSE_SLIDE := 18.0  # xác trượt theo hướng trúng đòn
const BLOOD_GROW_TIME := 2.0
const BLOOD_POOL_SCALE := 1.2
const HEALTH_BAR_TIME := 2.5  # thanh máu trên đầu NPC hiện bao lâu sau khi trúng đòn
const KILL_MARK_TIME := 0.7
const COP_HEALTH := 70.0
const COP_SPEED := 170.0
const GANG_HEALTH := 65.0
const GANG_SPEED := 150.0
const NPC_SIGHT := 480.0
const NPC_SHOOT_RANGE := 380.0
const NPC_AIM_ERROR_DEG := 12.0
const NPC_REACTION := 0.5
const NPC_RATE_SCALE := 0.4  # NPC bắn chậm và yếu hơn súng cùng loại của người chơi
const NPC_DAMAGE_SCALE := 0.55
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
const PLAYER_CRASH_SCALE := 0.5  # xe người chơi lái chịu nửa sát thương va chạm
const PLAYER_VEHICLE_BULLET_SCALE := 0.35  # ... và nửa sát thương đạn của NPC
const VEHICLE_SMOKE_RATIO := 0.35
const VEHICLE_BURN_TIME := 3.0
const VEHICLE_EXPLOSION_DAMAGE := 160.0
const VEHICLE_EXPLOSION_RADIUS := 170.0
const WRECK_TIME := 20.0
const DRIFT_GRIP := 2.2
const HANDBRAKE_GRIP := 1.2
const STEER_FULL_SPEED := 180.0  # tốc độ đạt bán kính lái đầy đủ
const BAIL_SPEED := 120.0  # xuống xe khi nhanh hơn thì ngã lăn
const NITRO_TIME := 2.5  # giây đốt hết bình
const NITRO_RECHARGE := 8.0  # giây nạp đầy bình
const NITRO_REARM := 0.25  # đốt cạn thì phải nạp lại tới mức này mới bật lại
const NITRO_ACCEL := 1.8
const NITRO_SPEED := 1.35
const NITRO_SHAKE := 12.0  # độ rung mỗi giây khi đốt
const OVERSPEED_DRAG := 260.0
const FLAT_SPEED := 0.55  # lốp thủng: tốc tối đa và độ bám còn lại
const FLAT_GRIP := 0.6
const HORN_SCARE_RADIUS := 260.0

# Xe tự lái
const TRAFFIC_SPEED := 150.0
const TRAFFIC_ACCEL := 220.0
const TRAFFIC_LOOK := 120.0
const HONK_AFTER := 1.4
const HONK_COOLDOWN := 3.0

# Dân số quanh camera
const MAX_PEDS := 16
const NIGHT_FROM := 21.0  # giờ bắt đầu "ban đêm" (người đi đường đổi kiểu, thoại về đêm)
const NIGHT_TO := 5.0
## [giờ, tỉ lệ MAX_PEDS]: mật độ người đi đường theo giờ, nội suy giữa các mốc. Đêm vắng hơn nhưng không trống.
const PED_DENSITY := [[0.0, 0.4], [5.0, 0.4], [7.0, 1.0], [18.0, 1.0], [22.0, 0.4], [24.0, 0.4]]
const MAX_CARS := 10
const SPAWN_MIN_DIST := 800.0
const SPAWN_MAX_DIST := 1150.0
const DESPAWN_DIST := 1500.0
const POPULATION_TICK := 0.5

# Truy nã
const MAX_STARS := 5
const HEAT_SHOOT_PED := 35.0
const HEAT_KILL_PED := 60.0
const HEAT_HIT_COP := 60.0
const HEAT_KILL_COP := 120.0
const HEAT_CARJACK_SEEN := 110.0
const HEAT_GUNFIRE_SEEN := 15.0
const LOSE_STAR_TIME := [0.0, 8.0, 12.0, 16.0, 20.0, 24.0]  # giây không bị thấy để giảm 1 sao (theo số sao hiện tại)
const COP_SIGHT := 560.0
const COPS_ON_FOOT := [0, 2, 3, 4, 4, 4]
const COP_CARS := [0, 0, 1, 2, 2, 2]
const SWAT_VANS := [0, 0, 0, 0, 1, 2]  # 4★: đặc nhiệm; mỗi xe thả SWAT_PER_VAN người
const SWAT_PER_VAN := 3
const COP_SHOOTERS := [0, 2, 2, 2, 3, 3]  # cùng lúc chỉ chừng này cảnh sát gần nhất được nổ súng, số còn lại bao vây
const FIRE_TURN_EVERY := 0.3
const MAX_COPS := 12  # tổng cảnh sát còn sống (bộ, thả từ xe, rào chắn)
const COP_WEAPON := ["pistol", "pistol", "pistol", "smg", "smg", "smg"]  # súng trường chỉ đặc nhiệm có
const COP_CAR_STOP_DIST := 260.0
const SWAT_HEALTH := 150.0
const SWAT_WEAPON := "rifle"
const ROADBLOCK_STARS := 4  # từ mức sao này cảnh sát lập rào chắn phía trước xe người chơi
const ROADBLOCK_EVERY := 14.0
const ROADBLOCK_AHEAD := Vector2i(13, 20)  # khoảng cách (ô) phía trước theo hướng chạy
const ROADBLOCK_MIN_SPEED := 160.0  # chỉ chặn khi người chơi đang lái nhanh hơn mức này
const MAX_ROADBLOCKS := 2
const HELI_STARS := 5
const HELI_HP := 650.0
const HELI_SPEED := 340.0  # chậm hơn xe nhanh: chạy thẳng đủ lâu thì thoát được đèn rọi
const HELI_SPOT_RADIUS := 230.0  # chỉ "thấy" người chơi trong vòng đèn rọi
const HELI_FIRE_EVERY := 2.2
const HELI_BURST := 4
const HELI_HIT_CHANCE := 0.35
const HELI_DAMAGE := 9.0
const HELI_RESPAWN := 30.0
const HELI_HEAT := 200.0  # bắn rơi trực thăng
const BADGE_RESPAWN := 180.0

# Tiền và chết
const START_MONEY := 300
const DEATH_FEE := 0.10
const REVIVE_HERE_FEE := 0.20  # hồi sinh tại chỗ: đắt hơn, giữ nguyên sao truy nã
const JAIL_SECONDS := 10.0  # ngồi tù: miễn phí nhưng phải chờ
const REVIVE_GRACE := 2.5  # giây bất tử sau khi hồi sinh tại chỗ
const ARMOR_PRICE := 400
const MEDKIT_PRICE := 150
const RESPRAY_PRICE := 250
const DEATH_SCREEN_DELAY := 1.2
const AUTOSAVE_INTERVAL := 30.0
const START_HINT_DELAY := 1.5

# Kinh tế và tiến trình (đợt 8)
const SAFEHOUSE_PRICES := [3000, 5000, 8000]  # theo thứ tự ô "Z" trên bản đồ (trên xuống, trái sang)
const BUSINESS_PRICES := [4000, 7000, 10000, 15000]
const BUSINESS_INCOME := [400, 800, 1200, 2000]  # trả mỗi nửa đêm trong game
const ALLY_PRICE := 500
const ALLY_MAX := 2
const ALLY_HEALTH := 120.0
const SKINS := ["hitman1", "manBrown", "manOld", "survivor1", "womanGreen", "soldier1", "robot1", "zombie1"]  # cuối: mở sau cốt truyện
const STATS_FLUSH := 1.0  # giây giữa hai lần ghi quãng đường/thời gian chơi vào Game.stats

# Tiếng tăm (xem Fame): điểm theo việc là [Thiện cảm, Uy danh]
const FAME_MAX := 100.0
const FAME_TIERS := [10.0, 25.0, 45.0, 70.0, 90.0]  # ngưỡng lên bậc 1..5
const FAME_DEEDS := {
	"ped_hit": [0.0, 2.0], "ped_kill": [-3.0, 8.0], "taxi_fare": [3.0, 0.0], "delivery": [3.0, 0.0],
	"errand": [4.0, 0.0], "criminal": [4.0, 3.0],
}
const FAME_DECAY := 1.0 / 60.0  # điểm Uy danh mất mỗi giây chơi
const FAME_DISCOUNT := 0.05  # giảm giá cửa hàng, tiệm sơn, viện phí mỗi bậc Thiện cảm (bậc 5: 25%)
const FAME_TIP_BONUS := 0.2  # tip taxi tăng thêm mỗi bậc Thiện cảm
const FAME_BADGE_FASTER := 0.1  # huy hiệu hối lộ hồi nhanh hơn mỗi bậc Thiện cảm
const FAME_WITNESS_CUT := 0.15  # xác suất nhân chứng sợ không dám báo mỗi bậc Uy danh
const FAME_FEAR_RADIUS := 0.15  # tầm nghe tiếng súng (để bỏ chạy) rộng thêm mỗi bậc Uy danh
const FAME_PROTECTION := [0, 60, 120, 180, 250, 320]  # tiền bảo kê mỗi nửa đêm theo bậc Uy danh
const FAME_CHAT_CHANCE := 0.4  # người đi đường nói câu theo tiếng tăm (từ bậc 2)

# Việc phụ (đợt 8)
const RACE_TIME_LIMIT := 240.0
const RACE_STOP_TIME := 1.0  # dừng xe trên cờ đua chừng này giây thì xuất phát
const RACE_STOP_SPEED := 25.0
const RACE_PRIZES := [1200, 500, 200, 0]  # theo hạng về đích
const DELIVERY_DROPS := 5
const DELIVERY_RANGE := Vector2(700, 1800)  # px từ chỗ đang đứng tới điểm giao kế tiếp
const DELIVERY_TIME_BASE := 12.0
const DELIVERY_TIME_SPEED := 160.0  # px/giây coi là tốc độ đi "vừa kịp"
const DELIVERY_PAY_BASE := 60
const DELIVERY_PAY_PER_PX := 0.06
const DELIVERY_BONUS := 400
const SWEEP_COUNT := 8
const SWEEP_TIME := 90.0
const SWEEP_REWARD := 1500
const TAXI_PICKUP_RANGE := Vector2(300, 900)
const TAXI_DROP_RANGE := Vector2(1000, 2400)
const TAXI_TIME_BASE := 10.0
const TAXI_TIME_SPEED := 170.0
const TAXI_PAY_BASE := 40
const TAXI_PAY_PER_PX := 0.07
const TAXI_TIP := 50  # tới trong nửa đầu thời gian
const FLEE_SPEED_RATIO := 0.8
const VIGILANTE_TIME := 120.0
const VIGILANTE_DISABLE := 0.35  # xe tội phạm còn dưới tỉ lệ máu này thì hắn nhảy ra
const VIGILANTE_REWARD := 250  # nhân với số tên đã bắt trong lượt
const TOKEN_VALUE := 100
const TOKEN_ALL_BONUS := 10000
const RAMP_MIN_SPEED := 240.0
const RAMP_AIR_PER_SPEED := 1.0 / 600.0  # giây bay theo tốc độ lúc rời dốc
const RAMP_AIR := Vector2(0.5, 1.4)
const RAMP_LIFT := 0.35  # sprite phóng to tối đa chừng này khi lên cao nhất
const STUNT_PAY_PER_SEC := 300
const STUNT_REPEAT_SCALE := 0.1  # nhảy lại dốc đã nhảy: thưởng chừng này

# Nhiệm vụ
const MISSION1_TIME := 75.0
const MISSION_RADIUS := 56.0
const GANG_COUNT := 6
const M4_COURIER_SPEED := 0.55  # tỉ lệ tốc tối đa của xe đưa tin
const M4_TOO_CLOSE := 150.0
const M4_SPOT_TIME := 2.5  # bám sát quá lâu thì bị phát hiện
const M4_TOO_FAR := 1400.0
const M4_LAG_SLOWDOWN := 0.45
const M4_COURIER_HP := 1500.0
const M5_WAVES := [4, 5, 6]
const M5_LEAVE_RADIUS := 900.0
const M6_MIN_SPEED := 150.0  # dưới tốc độ vào cua tự phanh (CORNER_SPEED) để rẽ được
const M6_GRACE := 3.5  # chậm hơn tốc tối thiểu quá chừng này giây là nổ (bot lái thật: 2 giây là nổ giữa dòng xe)
const M6_BAIL_RADIUS := 380.0
const M6_CAR_HP := 650.0
const M6_FUSE := 3.0  # nhảy ra rồi, xe nổ chậm nhất sau chừng này giây
const M7_CHASERS := 2
const M7_CAR_HP := 600.0
const M8_GUARDS := 5
const M8_TRUCK_HP := 700.0
const M8_ALARM_DIST := 500.0  # chạy xe tải khỏi bãi chừng này px thì cảnh sát mới được báo
const M9_GUARDS := 6
const BOSS_HEALTH := 500.0
const GANG_TURF := ["DISTRICT_HARBOR", "DISTRICT_RAILYARD", "DISTRICT_MARINA"]  # Red Fangs tuần tra sau NV2, tới khi xong NV9
const MAX_TURF_GANG := 3

# Ngày/đêm và thời tiết (đợt 8)
const DAY_LENGTH := 960.0  # giây thật cho 24 giờ trong game
const START_HOUR := 20.0
const LIGHTS_DAY := 0.12  # độ sáng còn lại của đèn đường/neon/đèn pha giữa trưa
const RAIN_START := 0.18  # mỗi giờ trong game: xác suất bắt đầu mưa
const RAIN_STAY := 0.6  # đang mưa: xác suất mưa tiếp giờ sau
const RAIN_FADE := 6.0  # giây để mưa nặng hạt dần / tạnh dần
const RAIN_DROPS := 260
const RAIN_GRIP := 0.72  # đường ướt: độ bám còn lại

# Hiệu ứng
const SHAKE_DECAY := 2.2
const SHAKE_MAX_OFFSET := 18.0
const SHAKE_FREQ := 14.0  # rung theo nhiễu mượt chừng này nhịp mỗi giây, không nhảy ngẫu nhiên từng frame
const TRACER_TIME := 0.06
const MUZZLE_TIME := 0.05

# Ngưỡng nhiệt truy nã cho từng sao (1..5)
const STAR_HEAT := [40.0, 140.0, 260.0, 420.0, 600.0]
const MAX_HEAT := 760.0
const FADE_TIME := 0.25


# Nhà nổi khối (BuildingDepth): mái lệch = (vị trí - tâm camera) × hệ số; ở mép màn hình 640px lệch 640 × hệ số
const BUILDING_RISE_LOW := 0.06
const BUILDING_RISE_HIGH := 0.11
const WALL_DARKEN := 0.5  # lớp tường sát đất tối hơn lớp sát mái chừng này
const ROOF_TINT_AMOUNT := 0.6  # mái: kéo màu tile về Palette.ROOF_TINT chừng này (giữ nét viền)
const WALL_TINT_AMOUNT := 0.85  # tường gần như phẳng màu, không lộ viền thành sọc
const SHADOW_OFFSET := Vector2(10, 14)  # bóng đổ chéo xuống phải

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

# Lái theo hướng phím (mặc định): xe tự xoay về hướng bấm trên màn hình
const STEER_GAIN := 2.5  # độ lái đầy đủ khi lệch ~0,4 rad
const CORNER_ANGLE := 0.7  # rad: lệch hơn mức này thì coi là vào cua
const CORNER_SPEED := 230.0  # tự phanh xuống tốc độ này khi vào cua
const TURN_BACK_ANGLE := 2.27  # rad (~130°): bấm ngược hướng xe thì phanh rồi lùi vòng quay đầu
const TURN_BACK_SPEED := 60.0
const ASSIST_STEER_FULL_SPEED := 80.0  # xe xoay được ngay từ tốc độ thấp
const ASSIST_TURN_SCALE := 1.2
const ASSIST_DRAG := 420.0  # nhả phím thì xe dừng nhanh như người đi bộ
