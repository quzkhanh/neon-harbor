class_name Palette
extends Object
## Màu giao diện và hiệu ứng (một chỗ duy nhất).

const BG := Color("0d0f19")
const PANEL := Color(0.071, 0.086, 0.149, 0.94)
const PANEL_SOFT := Color(0.071, 0.086, 0.149, 0.78)
const PANEL_LIGHT := Color("1d2340")
const PANEL_HOVER := Color("283056")
const BORDER := Color("2e3760")
const ACCENT := Color("ff3d7f")
const ACCENT_DARK := Color("c21f5b")
const CYAN := Color("2de2e6")
const TEXT := Color("f2f4ff")
const TEXT_DIM := Color("9aa3c7")
const TEXT_MUTED := Color("6b7396")
const MONEY := Color("7ee081")
const HEALTH := Color("ff4d5e")
const ARMOR := Color("4da3ff")
const GOLD := Color("ffd23f")
## Màu tóc: NATURAL_COLORS màu đầu tự nhiên, còn lại là màu nhuộm/mũ (xem Hair).
const HAIR: Array[Color] = [Color("2b2118"), Color("5b3a22"), Color("d8b45a"), Color("a8431f"), Color("b9b9b9"),
	Color("2f6fd0"), Color("2fae6a"), Color("e0489a")]
const OUTFITS: Array[Color] = [Color("d94b4b"), Color("e0a030"), Color("3b8ed8"), Color("8a5cd0"), Color("2fae8a"),
	Color("e8e8e8"), Color("d96aa8")]  # nhuộm áo xám/đen của người đi đường
const ICON_WELL := Color("9fb2c4")
const SHADOW := Color(0, 0, 0, 0.45)
const OUTLINE := Color(0.03, 0.035, 0.07, 0.9)
const DIM_SCREEN := Color(0.02, 0.025, 0.05, 0.62)
const NIGHT_TINT := Color(0.6, 0.6, 0.78)
const SKY := {"night": NIGHT_TINT, "dawn": Color(0.82, 0.72, 0.78), "day": Color(1.0, 0.98, 0.94), "dusk": Color(0.92, 0.7, 0.62)}
const RAIN_DIM := Color(0.78, 0.8, 0.86)
const RAIN := Color(0.75, 0.82, 1.0, 0.45)
const GROUND_SHADOW := Color(0, 0, 0, 0.35)
const WALL_BASE := Color(0.35, 0.33, 0.4)  # chân nhà (lớp va chạm)
const WALL_SHADE := {"orange": Color("8a5a40"), "wood": Color("7a6650"), "steel": Color("566478")}
const ROOF_TINT := {"orange": Color("f6b080"), "wood": Color("e6c48a"), "steel": Color("7fc4b4")}
const NEON := [Color(1.0, 0.24, 0.5, 0.75), Color(0.18, 0.89, 0.9, 0.7), Color(0.65, 0.35, 1.0, 0.75), Color(1.0, 0.82, 0.25, 0.6)]
const LAMP := Color(1.0, 0.7, 0.35, 0.22)
const HEADLAMP := Color("fff3c0")
const TAIL_LAMP := Color("d92b3a")
const BRAKE_LAMP := Color("ff6a6a")
const HAZARD_LAMP := Color("ffb02e")
const HEADLIGHT := Color(1.0, 0.92, 0.7, 0.16)
const NITRO_FLAME := Color(0.45, 0.75, 1.0)
const HELI_SPOT := Color(0.85, 0.95, 1.0, 0.45)
const WAKE := Color(0.9, 0.96, 1.0, 0.6)
const SWIM_TINT := Color(0.55, 0.75, 1.0, 0.85)
const MARKER := Color("ffd23f")
const MARKER_MISSION := Color("ff3d7f")
const ICON_RACE := Color("ff9f1c")
const ICON_JOB := Color("b48cff")
const ICON_BUSINESS := Color("3ddc97")
const ICON_SWEEP := Color("c9cfe6")
const ICON_STREAMER := Color("ff5ac8")
const LIVE_DOT := Color("ff2a3d")
const LUCKY_SCALP := Color("f0c39a")
const SHADES := Color("15161c")
const TRACER := Color(1.0, 0.92, 0.6, 0.85)
const HIT_FLASH := Color(1, 1, 1)
const SWING_FISTS := Color(1, 1, 1, 0.85)
const SWING_BAT := Color(1.0, 0.62, 0.22, 0.9)
const BAT_WOOD := Color("b07a45")
const BAT_OUTLINE := Color("3b2412")
const BAT_GRIP := Color("1f1f26")
const BAT_HIGHLIGHT := Color("e2b980")
const CRITTER_SHADOW := Color(0, 0, 0, 0.26)
const PIGEON_BODY := Color("8e93a6")
const PIGEON_NECK := Color("5fae9a")
const GULL_BODY := Color("f2f4f8")
const GULL_WING := Color("8d96ad")
const GULL_TIP := Color("3a3f52")
const PIGEON_WING := Color("646a80")
const PIGEON_HEAD := Color("6e7488")
const PIGEON_BEAK := Color("2c2a30")
const WING_BAR := Color("2a2d38")
const BEAK := Color("f2a33a")
const CAT_NOSE := Color("e88a9a")
const DOG_COLLAR := Color("d8343f")
const CAT_COATS := [Color("e08a3c"), Color("3b3b44"), Color("b9b9c4"), Color("8a6a4a")]
const DOG_COATS := [Color("a86f3f"), Color("e7dcc6"), Color("5a4636")]
const CRAB_BODY := Color("e4553a")
const CRITTER_EYE := Color("15161c")
const HIT_STAR := Color(1.0, 0.93, 0.6)
const EMOTE_BUBBLE := Color(0.98, 0.98, 1.0)
const EMOTE_ALERT := Color("ff9f1c")
const EMOTE_ANGRY := Color("e8283c")
const EMOTE_FEAR := Color("4da3ff")
const CORPSE := Color(0.5, 0.48, 0.52)
const BLOOD := Color(0.55, 0.06, 0.08)
const KILL_MARK := Color("ff3b4a")
const BOSS_TINT := Color(1.0, 0.55, 0.5)
const ALLY_TINT := Color(0.6, 1.0, 0.7)
const MAP_COLORS := {
	"#": Color("3a3f55"), "T": Color("2f8f5b"), "x": Color("8a6a3f"), "~": Color("1f5f8f"),
	",": Color("8fa5b0"), "\"": Color("2f9e62"), ".": Color("9a7650"), "_": Color("a77b4a"),
	"-": Color("4a4d57"), ":": Color("b8754a"), "M": Color("d65a3a"), "road": Color("2a2c33"),
}
const SIREN_RED := Color(1.0, 0.18, 0.25)
const SIREN_BLUE := Color(0.2, 0.45, 1.0)
