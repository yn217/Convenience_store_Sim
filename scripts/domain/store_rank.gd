class_name StoreRank
extends RefCounted
## Store rank ★1..★5 (data/progression/store_ranks_v1.json, user's decision 2026-11-13). Pure rules: the rank a store
## qualifies for from the company's total revenue and its reputation, and the rank that opens a fixture or a feature.
## A fixture or feature no rank lists is open from the start. The rank reached is kept by ProgressionService.

const DATA_PATH := "res://data/progression/store_ranks_v1.json"
const FEATURES := ["promotions", "media", "expand_store", "lottery", "open_store"]
const FEATURE_JA := {"promotions": "店頭販促", "media": "広告キャンペーン", "expand_store": "店舗の増築", "lottery": "店頭くじ", "open_store": "新しいお店の出店"}

static var _ranks: Array = []


static func ranks() -> Array:
	if _ranks.is_empty():
		var errors: Array[String] = []
		_ranks = parse(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)), errors)
		if not errors.is_empty():
			push_error("store ranks: %s" % str(errors))
	return _ranks


## Ranks in order 1..n; a bad file gives problems and only rank 1 with everything open.
static func parse(data, errors: Array[String] = []) -> Array:
	var out: Array = []
	var rows = data.get("ranks", null) if typeof(data) == TYPE_DICTIONARY else null
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		errors.append("ranks: missing")
		return [{"rank": 1, "name_ja": "", "revenue_yen": 0, "reputation": 0, "fixtures": [], "features": []}]
	var seen := {}
	for i in rows.size():
		var r = rows[i]
		if typeof(r) != TYPE_DICTIONARY or not JsonCheck.is_int(r.get("rank")) or int(r["rank"]) != i + 1:
			errors.append("ranks[%d]: rank must be %d" % [i, i + 1])
			continue
		var fixtures: Array = r.get("fixtures", []) if typeof(r.get("fixtures")) == TYPE_ARRAY else []
		var features: Array = r.get("features", []) if typeof(r.get("features")) == TYPE_ARRAY else []
		for f in fixtures + features:
			if seen.has(f):
				errors.append("ranks[%d]: %s is opened twice" % [i, f])
			seen[f] = true
		for f in features:
			if not FEATURES.has(f):
				errors.append("ranks[%d]: unknown feature %s" % [i, f])
		out.append({"rank": i + 1, "name_ja": String(r.get("name_ja", "")), "revenue_yen": maxi(int(r.get("revenue_yen", 0)), 0),
			"reputation": clampi(int(r.get("reputation", 0)), 0, 100), "fixtures": fixtures.duplicate(), "features": features.duplicate()})
	return out


static func top() -> int:
	return ranks().size()


static func rank_info(rank: int) -> Dictionary:
	var all := ranks()
	return all[clampi(rank, 1, all.size()) - 1]


## The highest rank whose revenue and reputation are both met (ranks are climbed in order).
static func qualified(revenue_yen: int, reputation: int) -> int:
	var best := 1
	for r in ranks():
		if revenue_yen >= int(r["revenue_yen"]) and reputation >= int(r["reputation"]):
			best = int(r["rank"])
		else:
			break
	return best


## The rank that opens a fixture type or a feature; 1 when no rank lists it.
static func rank_for(item: String) -> int:
	for r in ranks():
		if (r["fixtures"] as Array).has(item) or (r["features"] as Array).has(item):
			return int(r["rank"])
	return 1


## Fixture types and features still closed at `rank`: {item: rank that opens it}.
static func locked(rank: int) -> Dictionary:
	var out := {}
	for r in ranks():
		if int(r["rank"]) > rank:
			for f in r["fixtures"] + r["features"]:
				out[f] = int(r["rank"])
	return out


static func stars(rank: int) -> String:
	return "★%d" % rank
