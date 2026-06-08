# player/ArmorPathMount.gd
# Centraliza a montagem de paths de animação da armadura.
# ArmorManager delega toda construção de path para cá via ArmorPathMount.build().
class_name ArmorPathMount
extends RefCounted

const BASE_DIR    := "res://resources/animations/"
const CHAR_PREFIX := "spr_x_"

# Resultado da montagem de path para um slot.
class PathResult:
	var has_trans:  bool   = false
	var trans_path: String = ""
	var trans_anim: String = ""
	var main_path:  String = ""
	var main_anim:  String = ""


static func build(
	armor_data: StateArmorVisualData,
	slot: String,
	action: String,
	is_buster_arms: bool,
	is_buster_active: bool,
	is_transitioning_walk: bool
) -> PathResult:
	var r := PathResult.new()

	# ── Braço durante buster ─────────────────────────────────────
	# Arms em modo buster usa arquivo dedicado (buster_file) sem slot no nome.
	# ex: spr_x_fourth_buster_hoveringfront.tres
	if is_buster_arms and slot == "arms":
		r.trans_anim = armor_data.armor_shoot_transition_anim
		r.main_anim  = armor_data.armor_shoot_main_anim
		r.has_trans  = not r.trans_anim.is_empty() and is_transitioning_walk
		if r.has_trans:
			r.trans_path = BASE_DIR + CHAR_PREFIX \
				+ armor_data.buster_transition_file + "_" + action + ".tres"
		r.main_path = BASE_DIR + CHAR_PREFIX \
			+ armor_data.buster_file + "_" + action + ".tres"

	# ── Slots normais durante buster (head, body, legs) ──────────
	# Usa arquivo de shoot com slot no nome.
	# ex: spr_x_fourth_shoot_legs_hoveringfront.tres
	elif is_buster_active and not armor_data.armor_shoot_file.is_empty() and slot != "arms":
		r.trans_anim = armor_data.armor_shoot_transition_anim
		r.main_anim  = armor_data.armor_shoot_main_anim
		r.has_trans  = not r.trans_anim.is_empty() and is_transitioning_walk
		if r.has_trans:
			r.trans_path = BASE_DIR + CHAR_PREFIX \
				+ armor_data.armor_shoot_file + "_" + slot + "_" + action + ".tres"
		r.main_path = BASE_DIR + CHAR_PREFIX \
			+ armor_data.armor_shoot_file + "_" + slot + "_" + action + ".tres"

	# ── Estado normal ─────────────────────────────────────────────
	# ex: spr_x_fourth_legs_hoveringfront.tres
	else:
		var raw_has_trans := armor_data.has_transition \
			and not armor_data.transition_file.is_empty() \
			and not armor_data.transition_anim.is_empty()
		r.has_trans  = raw_has_trans and is_transitioning_walk
		r.trans_anim = armor_data.transition_anim
		r.main_anim  = armor_data.main_anim
		if r.has_trans:
			r.trans_path = BASE_DIR + CHAR_PREFIX \
				+ armor_data.transition_file + "_" + slot + "_" + action + ".tres"
		r.main_path = BASE_DIR + CHAR_PREFIX \
			+ armor_data.main_file + "_" + slot + "_" + action + ".tres"

	return r
