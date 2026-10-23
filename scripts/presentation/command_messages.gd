class_name CommandMessages
extends RefCounted
## CommandResult.code / message_key -> player-facing Japanese text (04 §2: never colour alone).

const BY_KEY := {
	&"outside_store": "店舗の外には設置できません",
	&"cell_occupied": "ほかの什器と重なるため設置できません",
	&"blocks_entrance": "入口を塞ぐため設置できません",
	&"no_access_tile": "客が使える面の前が空いていないため設置できません",
	&"blocks_other_access": "ほかの什器のアクセス面または通路を塞ぐため設置できません",
	&"access_unreachable": "入口から客が歩いて届かないため設置できません",
	&"no_queue_space": "レジの前に待機列ができる場所がないため設置できません",
	&"blocks_register_queue": "レジの待機列を塞ぐため設置できません",
	&"not_enough_cash": "資金が足りません",
	&"construction_needs_setup": "営業を終了して準備中に戻すと建設できます",
	&"reservation_active": "客が商品を予約中のため操作できません",
	&"nothing_to_undo": "元に戻す操作がありません",
	&"nothing_to_redo": "やり直す操作がありません",
	&"no_change": "位置も向きも変わっていません",
	&"unknown_instance": "対象の什器が見つかりません",
	&"unknown_type_or_rotation": "什器の種類または向きが不正です",
}
const BY_CODE := {
	&"OUT_OF_BOUNDS": "店舗の外には設置できません",
	&"OCCUPIED": "ほかの什器と重なるため設置できません",
	&"ENTRANCE_BLOCKED": "入口を塞ぐため設置できません",
	&"UNREACHABLE_ACCESS": "客が使える面の前が空いていないため設置できません",
	&"REGISTER_BLOCKED": "レジの前が空いていないため設置できません",
	&"INSUFFICIENT_CASH": "資金が足りません",
	&"NOT_IN_SETUP": "営業を終了して準備中に戻すと建設できます",
	&"RESERVATION_ACTIVE": "客が商品を予約中のため操作できません",
	&"ALREADY_APPLIED": "この操作は実行済みです",
}


static func text(code: StringName, message_key: StringName = &"") -> String:
	if BY_KEY.has(message_key):
		return BY_KEY[message_key]
	if BY_CODE.has(code):
		return BY_CODE[code]
	return "操作できません (%s)" % code
