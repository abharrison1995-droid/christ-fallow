extends RefCounted
## Shared HUD squad and role option definitions.

const SQUAD_CLASS_SPECS := [
	{"id": -1, "short": "[1] All (0)", "full": "All Warriors"},
	{"id": GameData.WarriorClass.SPEARMAN, "short": "[2] Spears (0)", "full": "Spearmen"},
	{"id": GameData.WarriorClass.KNIFE_RAIDER, "short": "[3] Knives (0)", "full": "Knife Raiders"},
	{"id": GameData.WarriorClass.ARCHER, "short": "[4] Archers (0)", "full": "Archers"},
	{"id": GameData.WarriorClass.BRUTE, "short": "[5] Brutes (0)", "full": "Club Brutes"},
	{"id": GameData.WarriorClass.JAVELINEER, "short": "[6] Javelins (0)", "full": "Javelineers"},
]

const TACTICAL_ORDER_SPECS := [
	{"id": GameData.SquadOrder.FOLLOW, "short": "Follow  F1", "full": "Follow Leader"},
	{"id": GameData.SquadOrder.HOLD, "short": "Hold  F2", "full": "Hold Position"},
	{"id": GameData.SquadOrder.CHARGE, "short": "Charge  F3", "full": "Charge Enemies"},
	{"id": GameData.SquadOrder.RETREAT, "short": "Retreat  F4", "full": "Retreat Camp"},
	{"id": GameData.SquadOrder.GUARD_BASE, "short": "Guard  F6", "full": "Guard Base"},
]


static func fill_role_options(opt: OptionButton) -> void:
	for r_id in GameData.ROLE_NAMES.keys():
		opt.add_item(GameData.ROLE_NAMES[r_id], r_id)


static func fill_class_options(opt: OptionButton) -> void:
	for c_id in GameData.WARRIOR_CLASS_NAMES.keys():
		opt.add_item(GameData.WARRIOR_CLASS_NAMES[c_id], c_id)
