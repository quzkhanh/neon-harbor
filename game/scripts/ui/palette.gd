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
const TRACER := Color(1.0, 0.92, 0.6, 0.85)
const HIT_FLASH := Color(1, 1, 1)
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
