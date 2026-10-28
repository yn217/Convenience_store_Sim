extends RefCounted
## Cache fixed, convex coloured faces in paint order; alpha is retained per vertex.

static func from_faces(faces: Array) -> ArrayMesh:
	if faces.is_empty():
		return null
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for face in faces:
		var points: PackedVector2Array = face["points"]
		for k in range(1, points.size() - 1):
			for i in [0, k, k + 1]:
				vertices.append(points[i])
				colors.append(face["colors"][i] if face.has("colors") else face["color"])
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
