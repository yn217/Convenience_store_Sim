"""Procedural EEVEE looks for fixture parts (Issue #61 Phase B). Runs inside Blender only.

Each look is a function `look(mat)` that rebuilds the material's node tree on a fresh material
(Blender 2.91 node names). Textures use Object texture coordinates: the renderer builds every box
in world metres with an identity object transform, so a pattern is continuous across boxes that
share a look and does not stretch with box size. Looks are looked up by material id in LOOKS;
render_fixtures.py falls back to its flat PALETTE for ids that are not listed here, so the other
fixture types keep their existing materials.

Reusable helpers (for the remaining fixture types): `fresh_tree`, `principled`, `object_vector`,
`ramp`, `emissive`. Add a new look by writing one function and registering it in LOOKS.
"""
import bpy


def fresh_tree(mat):
    """Enable nodes and clear the default tree. Returns (node_tree, nodes, links)."""
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return nt, nt.nodes, nt.links


def output(nodes, links, shader_socket):
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(shader_socket, out.inputs[0])
    return out


def principled(nodes, links, color, metallic=0.0, roughness=0.5, specular=0.5):
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = tuple(color) + (1.0,)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular"].default_value = specular
    return bsdf


def object_vector(nodes, links, scale=(1.0, 1.0, 1.0)):
    """Object-space coordinates (world metres) through a Mapping node. Returns the vector socket."""
    tc = nodes.new("ShaderNodeTexCoord")
    mp = nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = tuple(scale)
    links.new(tc.outputs["Object"], mp.inputs[0])
    return mp.outputs[0]


def ramp(nodes, links, fac_socket, stops):
    """ColorRamp from [(position, (r, g, b)), ...]. Returns the colour output socket."""
    node = nodes.new("ShaderNodeValToRGB")
    elements = node.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], tuple(stops[0][1]) + (1.0,)
    elements[1].position, elements[1].color = stops[-1][0], tuple(stops[-1][1]) + (1.0,)
    for pos, col in stops[1:-1]:
        el = elements.new(pos)
        el.color = tuple(col) + (1.0,)
    links.new(fac_socket, node.inputs["Fac"])
    return node.outputs["Color"]


def emissive(mat, color, strength):
    nt, nodes, links = fresh_tree(mat)
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = tuple(color) + (1.0,)
    em.inputs["Strength"].default_value = strength
    output(nodes, links, em.outputs[0])


def wood_laminate(mat):
    """Counter front: warm wood-grain laminate (horizontal bands with distortion)."""
    nt, nodes, links = fresh_tree(mat)
    vec = object_vector(nodes, links, (1.0, 1.0, 1.0))
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 5.0
    wave.inputs["Distortion"].default_value = 1.6
    wave.inputs["Detail"].default_value = 1.0
    links.new(vec, wave.inputs["Vector"])
    col = ramp(nodes, links, wave.outputs["Fac"], [(0.0, (0.56, 0.41, 0.26)), (0.6, (0.66, 0.51, 0.34)), (1.0, (0.72, 0.58, 0.40))])
    bsdf = principled(nodes, links, (0.6, 0.5, 0.4), roughness=0.46, specular=0.4)
    links.new(col, bsdf.inputs["Base Color"])
    output(nodes, links, bsdf.outputs[0])


def stainless(mat):
    """Brushed stainless top: metallic with a fine noise roughness so edges catch light."""
    nt, nodes, links = fresh_tree(mat)
    vec = object_vector(nodes, links, (40.0, 40.0, 40.0))
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Detail"].default_value = 4.0
    links.new(vec, noise.inputs["Vector"])
    rng = nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = 0.3
    rng.inputs["From Max"].default_value = 0.7
    rng.inputs["To Min"].default_value = 0.20
    rng.inputs["To Max"].default_value = 0.36
    links.new(noise.outputs["Fac"], rng.inputs["Value"])
    bsdf = principled(nodes, links, (0.76, 0.78, 0.81), metallic=1.0, roughness=0.3)
    links.new(rng.outputs["Result"], bsdf.inputs["Roughness"])
    output(nodes, links, bsdf.outputs[0])


def pegboard(mat):
    """Perforated pegboard: white board with a regular grid of round holes (Voronoi F1 distance)."""
    nt, nodes, links = fresh_tree(mat)
    vec = object_vector(nodes, links, (1.0, 1.0, 1.0))
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "F1"
    vor.distance = "EUCLIDEAN"
    vor.inputs["Randomness"].default_value = 0.0
    vor.inputs["Scale"].default_value = 30.0
    links.new(vec, vor.inputs["Vector"])
    col = ramp(nodes, links, vor.outputs["Distance"], [(0.0, (0.03, 0.03, 0.035)), (0.2, (0.03, 0.03, 0.035)), (0.26, (0.80, 0.82, 0.84))])
    bsdf = principled(nodes, links, (0.8, 0.82, 0.84), roughness=0.6)
    links.new(col, bsdf.inputs["Base Color"])
    output(nodes, links, bsdf.outputs[0])


def slotted_upright(mat):
    """Gondola end upright: grey standard with a fine slot pattern (Brick mortar lines)."""
    nt, nodes, links = fresh_tree(mat)
    vec = object_vector(nodes, links, (9.0, 9.0, 9.0))
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Color1"].default_value = (0.50, 0.53, 0.57, 1.0)
    brick.inputs["Color2"].default_value = (0.44, 0.47, 0.51, 1.0)
    brick.inputs["Mortar"].default_value = (0.10, 0.10, 0.11, 1.0)
    brick.inputs["Mortar Size"].default_value = 0.05
    brick.inputs["Brick Width"].default_value = 0.5
    brick.inputs["Row Height"].default_value = 0.25
    links.new(vec, brick.inputs["Vector"])
    bsdf = principled(nodes, links, (0.5, 0.53, 0.57), metallic=0.6, roughness=0.42)
    links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
    output(nodes, links, bsdf.outputs[0])


def glass_gradient(mat):
    """Glass door: alpha rises from the bottom to the top, so products stay readable and the
    upper part reflects more light (a soft vertical reflection gradient)."""
    nt, nodes, links = fresh_tree(mat)
    vec = object_vector(nodes, links, (1.0, 1.0, 1.0))
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(vec, sep.inputs[0])
    rng = nodes.new("ShaderNodeMapRange")
    rng.clamp = True
    rng.inputs["From Min"].default_value = 0.1
    rng.inputs["From Max"].default_value = 1.9
    rng.inputs["To Min"].default_value = 0.05
    rng.inputs["To Max"].default_value = 0.20
    links.new(sep.outputs["Z"], rng.inputs["Value"])
    bsdf = principled(nodes, links, (0.78, 0.9, 0.98), roughness=0.05, specular=0.7)
    links.new(rng.outputs["Result"], bsdf.inputs["Alpha"])
    output(nodes, links, bsdf.outputs[0])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"


def pos_screen(mat):
    emissive(mat, (0.62, 0.88, 1.0), 1.6)


def header_emit(mat):
    emissive(mat, (0.20, 0.55, 1.0), 1.1)


def plain(color, metallic=0.0, roughness=0.5):
    """Flat principled look for the new brand-neutral accents."""
    def look(mat):
        nt, nodes, links = fresh_tree(mat)
        bsdf = principled(nodes, links, color, metallic=metallic, roughness=roughness)
        output(nodes, links, bsdf.outputs[0])
    return look


LOOKS = {
    "wood_laminate": wood_laminate,
    "stainless": stainless,
    "pegboard": pegboard,
    "slotted_upright": slotted_upright,
    "glass_gradient": glass_gradient,
    "pos_screen": pos_screen,
    "header_emit": header_emit,
    "accent_strip": plain((0.10, 0.52, 0.50), roughness=0.4),
    "price_rail": plain((0.80, 0.81, 0.83), roughness=0.4),
    "cabinet_grey": plain((0.58, 0.61, 0.65), roughness=0.5),
}


def build(mat_id, mat):
    """Apply the look for mat_id to mat. Returns False when mat_id has no procedural look."""
    look = LOOKS.get(mat_id)
    if look is None:
        return False
    look(mat)
    return True
