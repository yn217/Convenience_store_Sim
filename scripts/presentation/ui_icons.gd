class_name UiIcons
extends RefCounted
## Original UI icon set (#61): assets/ui/icons/<name>.svg, 24x24 viewBox, drawn in #ffffff so callers tint
## with modulate / icon colour overrides. The SVG text is rasterised at the requested size on first use, so
## no .import sidecar is needed and a fresh checkout works in headless and windowed runs alike.

const DIR := "res://assets/ui/icons"
const VIEWBOX := 24.0

static var _cache: Dictionary = {}


## Icon `name` rendered `size` px square, or null when the file is missing or cannot be parsed. Cached per name+size.
static func texture(name: String, size: int = 24) -> Texture2D:
	var key := "%s@%d" % [name, maxi(size, 1)]
	if _cache.has(key):
		return _cache[key]
	var tex := _load(name, maxi(size, 1))
	_cache[key] = tex
	return tex


static func exists(name: String) -> bool:
	return FileAccess.file_exists("%s/%s.svg" % [DIR, name])


static func _load(name: String, size: int) -> Texture2D:
	if not exists(name):
		return null
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string("%s/%s.svg" % [DIR, name]), float(size) / VIEWBOX) != OK:
		return null
	return ImageTexture.create_from_image(img)
