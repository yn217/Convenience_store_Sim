class_name NotificationPolicy
extends RefCounted
## Presentation-only rules for the notification column (UI Phase 4). Four levels with a fixed rank
## (error > warning > achievement > info), at most MAX_VISIBLE live toasts, duplicates of one kind merged into a
## single toast inside MERGE_WINDOW seconds, a lifetime per level (errors stay until dismissed), and one compact
## sales pop-up per register. It reads no game state and writes none: CuePlayer feeds it cue requests and
## advances it with the UI clock.

const MAX_VISIBLE := 3
const MERGE_WINDOW := 8.0          # seconds from the first notice of a kind in which later ones merge into it
const SALE_MERGE_SECONDS := 0.3    # sales on one register within this time share one pop-up
const SALE_TTL := 0.8
const RANK := {"error": 3, "warning": 2, "achievement": 1, "info": 0}
const DURATION := {"error": INF, "warning": 6.0, "achievement": 4.0, "info": 3.0}

## Live toasts, oldest first. Each: key, level, amount, count, text, age (since the last merge),
## born (since the first notice of the kind), ttl.
var items: Array[Dictionary] = []


## Adds a notice, or merges it into a live one with the same key that started within MERGE_WINDOW.
## `text_for.call(amount, count)` builds the text, so a merged notice always reads with its totals.
func offer(key: String, level: String, amount: int, text_for: Callable) -> Dictionary:
	for live in items:
		if live["key"] == key and float(live["born"]) < MERGE_WINDOW:
			live["amount"] = int(live["amount"]) + amount
			live["count"] = int(live["count"]) + 1
			live["text"] = String(text_for.call(live["amount"], live["count"]))
			live["age"] = 0.0
			return live
	var fresh := {
		"key": key, "level": level, "amount": amount, "count": 1,
		"text": String(text_for.call(amount, 1)), "age": 0.0, "born": 0.0,
		"ttl": float(DURATION.get(level, DURATION["info"])),
	}
	items.append(fresh)
	_trim()
	return fresh


## Real-time step: ages every toast and drops the expired ones (errors never expire).
func advance(delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		item["age"] = float(item["age"]) + delta
		item["born"] = float(item["born"]) + delta
		if float(item["age"]) >= float(item["ttl"]):
			items.remove_at(i)


## Dismisses one toast (a click on an error toast).
func dismiss(item: Dictionary) -> void:
	for i in items.size():
		if is_same(items[i], item):
			items.remove_at(i)
			return


static func rank_of(level: String) -> int:
	return int(RANK.get(level, 0))


## Over the limit, the lowest rank goes; on a tie the oldest goes. A newer notice of a higher rank
## therefore takes the place of an older lower one, never the other way round.
func _trim() -> void:
	while items.size() > MAX_VISIBLE:
		var victim := 0
		for i in range(1, items.size()):
			if rank_of(items[i]["level"]) < rank_of(items[victim]["level"]):
				victim = i
		items.remove_at(victim)


## One pop-up per register in `sales`: a sale within SALE_MERGE_SECONDS of the pop-up's start adds to it
## (+¥450 ×2); a later sale replaces it. Returns the pop-up that now shows the sale.
static func add_sale(sales: Array, register_id: String, yen: int) -> Dictionary:
	for sale in sales:
		if sale["register_id"] == register_id:
			if float(sale["age"]) < SALE_MERGE_SECONDS:
				sale["yen"] = int(sale["yen"]) + yen
				sale["count"] = int(sale["count"]) + 1
				sale["text"] = sale_text(int(sale["yen"]), int(sale["count"]))
				return sale
			sales.erase(sale)
			break
	var fresh := {"register_id": register_id, "yen": yen, "count": 1, "text": sale_text(yen, 1), "age": 0.0, "ttl": SALE_TTL}
	sales.append(fresh)
	return fresh


static func sale_text(yen: int, count: int) -> String:
	var text := "+¥%s" % GameHud.format_yen(yen).trim_prefix("¥")
	if count > 1:
		text += " ×%d" % count
	return text
