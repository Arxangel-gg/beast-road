"""The forge's Blender half. Run by `forge.py`, never by hand:

    blender --background --python tools/vfx_forge/render.py -- <effect> <out_dir> <frames> <size>

Builds one plane under an orthographic camera and one material that is the
whole effect - the "five nodes" of docs/VFX_FORGE.md: a frame turned into an
`age` in 0..1, a radial coordinate, noise put through a hard threshold so the
shape is graphic rather than soft, a swirl toward the middle, and emission
whose alpha is the mask. Renders the frames as RGBA PNGs on a transparent
film. Everything is white on transparent so the game tints it once per use;
the rim is greyed so a tint reads as a bright core inside a darker edge.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
EFFECT = argv[0] if len(argv) > 0 else "burst"
OUT = argv[1] if len(argv) > 1 else "/tmp/forge"
FRAMES = int(argv[2]) if len(argv) > 2 else 16
SIZE = int(argv[3]) if len(argv) > 3 else 96

# ------------------------------------------------------------------ the scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.frame_start = 1
scene.frame_end = FRAMES
try:
    scene.eevee.taa_render_samples = 16
except AttributeError:
    pass
# Standard rather than AgX or Filmic: a white emission must render white, or
# the game's tint lands on a grey the tone-mapper invented.
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

cam_data = bpy.data.cameras.new("ForgeCamera")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.0
cam = bpy.data.objects.new("ForgeCamera", cam_data)
cam.location = (0.0, 0.0, 5.0)
scene.collection.objects.link(cam)
scene.camera = cam

bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0.0, 0.0, 0.0))
plane = bpy.context.active_object
plane.name = "ForgePlane"

# --------------------------------------------------------------- the material
mat = bpy.data.materials.new("Forge_" + EFFECT)
mat.use_nodes = True
try:
    mat.surface_render_method = "BLENDED"
except AttributeError:
    mat.blend_method = "BLEND"
try:
    mat.blend_method = "BLEND"
except (AttributeError, TypeError):
    pass
tree = mat.node_tree
nodes = tree.nodes
links = tree.links
for node in list(nodes):
    nodes.remove(node)


def new(kind, name, **props):
    node = nodes.new(kind)
    node.name = name
    for key, value in props.items():
        setattr(node, key, value)
    return node


def math(name, op, a=None, b=None, clamp=False):
    node = new("ShaderNodeMath", name, operation=op, use_clamp=clamp)
    if a is not None:
        _plug(a, node.inputs[0])
    if b is not None:
        _plug(b, node.inputs[1])
    return node


def _plug(source, socket):
    if isinstance(source, (int, float)):
        socket.default_value = float(source)
    else:
        links.new(source, socket)


# 1. Scene time -> age in 0..1, keyframed rather than driven: a driver needs
#    the expression sandbox and a keyframe needs nothing.
age_node = new("ShaderNodeValue", "Age")
age_out = age_node.outputs[0]
for frame in range(1, FRAMES + 1):
    age_out.default_value = (frame - 1) / max(FRAMES - 1, 1)
    age_out.keyframe_insert("default_value", frame=frame)
# Linear in, eased out: the effect leaps then lingers.
eased = math("Eased", "POWER", age_out, 0.7)
age = eased.outputs[0]

# 2. Radial coordinate from the plane's own object space, in 0..~1.4.
coords = new("ShaderNodeTexCoord", "Coords")
radial = new("ShaderNodeVectorMath", "Radial", operation="LENGTH")
links.new(coords.outputs["Object"], radial.inputs[0])
r = radial.outputs["Value"]

# 3. A swirl: rotate the noise lookup more toward the middle, and with age.
sep = new("ShaderNodeSeparateXYZ", "Sep")
links.new(coords.outputs["Object"], sep.inputs[0])
angle = new("ShaderNodeMath", "Angle", operation="ARCTAN2")
links.new(sep.outputs["Y"], angle.inputs[0])
links.new(sep.outputs["X"], angle.inputs[1])
inward = math("Inward", "SUBTRACT", 1.4, r)
twist_age = math("TwistAge", "MULTIPLY", age, 2.6)
twist = math("Twist", "MULTIPLY", inward.outputs[0], twist_age.outputs[0])
turned = math("Turned", "ADD", angle.outputs[0], twist.outputs[0])
cos_n = math("Cos", "COSINE", turned.outputs[0])
sin_n = math("Sin", "SINE", turned.outputs[0])
sx = math("SX", "MULTIPLY", cos_n.outputs[0], r)
sy = math("SY", "MULTIPLY", sin_n.outputs[0], r)
swirled = new("ShaderNodeCombineXYZ", "Swirled")
links.new(sx.outputs[0], swirled.inputs[0])
links.new(sy.outputs[0], swirled.inputs[1])
age_z = math("AgeZ", "MULTIPLY", age, 1.7)
links.new(age_z.outputs[0], swirled.inputs[2])

# 4. Noise through a hard threshold: the stylisation.
noise = new("ShaderNodeTexNoise", "Noise")
links.new(swirled.outputs[0], noise.inputs["Vector"])
noise.inputs["Scale"].default_value = 3.2
noise.inputs["Detail"].default_value = 3.0
noise.inputs["Roughness"].default_value = 0.55
noise_fac = noise.outputs["Fac"]

if EFFECT == "burst":
    # A shock ring that runs outward and thins, broken by the noise; a core
    # that blooms and dies; embers thrown along the swirl.
    edge = math("Edge", "MULTIPLY", age, 1.25)
    edge_off = math("EdgeOff", "ADD", edge.outputs[0], 0.08)
    dist = math("Dist", "SUBTRACT", r, edge_off.outputs[0])
    adist = math("ADist", "ABSOLUTE", dist.outputs[0])
    # The band thins as it runs and never below a visible width: the first
    # render fell to a hairline by the fifth frame and read as a wire.
    thin_fall = math("ThinFall", "MULTIPLY", age, 0.20)
    thin = math("Thin", "SUBTRACT", 0.28, thin_fall.outputs[0])   # 0.28 -> 0.08
    thin_c = math("ThinC", "MAXIMUM", thin.outputs[0], 0.07)
    ring_soft = math("RingSoft", "LESS_THAN", adist.outputs[0], thin_c.outputs[0])
    # Roughened by the noise: the ring only survives where the noise is high
    # enough, and the bar rises with age so the ring frays as it goes.
    bar = math("Bar", "MULTIPLY", age, 0.45)
    bar_off = math("BarOff", "ADD", bar.outputs[0], 0.25)
    grain = math("Grain", "GREATER_THAN", noise_fac, bar_off.outputs[0])
    ring = math("Ring", "MULTIPLY", ring_soft.outputs[0], grain.outputs[0])

    core_r = math("CoreR", "SUBTRACT", 0.55, age)      # 0.55 -> -0.45
    core_rc = math("CoreRC", "MULTIPLY", core_r.outputs[0], 1.0)
    core = math("Core", "LESS_THAN", r, core_rc.outputs[0])

    ember_bar = math("EmberBar", "ADD", 0.62, math("EmberAge", "MULTIPLY", age, 0.2).outputs[0])
    embers_n = math("EmbersN", "GREATER_THAN", noise_fac, ember_bar.outputs[0])
    ember_reach = math("EmberReach", "MULTIPLY", age, 1.5)
    ember_reach2 = math("EmberReach2", "ADD", ember_reach.outputs[0], 0.15)
    ember_in = math("EmberIn", "LESS_THAN", r, ember_reach2.outputs[0])
    ember_live = math("EmberLive", "LESS_THAN", age, 0.92)
    embers_a = math("EmbersA", "MULTIPLY", embers_n.outputs[0], ember_in.outputs[0])
    embers = math("Embers", "MULTIPLY", embers_a.outputs[0], ember_live.outputs[0])

    # A second, fainter ring runs behind the first at two thirds of its reach,
    # so the shock reads as a wave with a wake rather than as one line.
    edge2 = math("Edge2", "MULTIPLY", age, 0.8)
    edge2_off = math("Edge2Off", "ADD", edge2.outputs[0], 0.04)
    dist2 = math("Dist2", "SUBTRACT", r, edge2_off.outputs[0])
    adist2 = math("ADist2", "ABSOLUTE", dist2.outputs[0])
    ring2_soft = math("Ring2Soft", "LESS_THAN", adist2.outputs[0], 0.05)
    grain2 = math("Grain2", "GREATER_THAN", noise_fac, 0.55)
    ring2_a = math("Ring2A", "MULTIPLY", ring2_soft.outputs[0], grain2.outputs[0])
    ring2_live = math("Ring2Live", "GREATER_THAN", age, 0.2)
    ring2 = math("Ring2", "MULTIPLY", ring2_a.outputs[0], ring2_live.outputs[0])
    rc0 = math("RingCore0", "MAXIMUM", ring.outputs[0], ring2.outputs[0])
    rc = math("RingCore", "MAXIMUM", rc0.outputs[0], core.outputs[0])
    mask_n = math("Mask", "MAXIMUM", rc.outputs[0], embers.outputs[0])
    mask = mask_n.outputs[0]
    # The core is brighter than the rim and the embers: the tint lands on a
    # bright middle inside a darker edge.
    tone_a = math("ToneA", "MULTIPLY", core.outputs[0], 0.45)
    tone_b = math("ToneB", "MULTIPLY", ring.outputs[0], 0.25)
    tone_c = math("ToneC", "ADD", tone_a.outputs[0], tone_b.outputs[0])
    tone = math("Tone", "ADD", tone_c.outputs[0], 0.55, clamp=True)
    tone_out = tone.outputs[0]
else:
    raise SystemExit("unknown effect %s" % EFFECT)

# 5. Emission, and the mask drives the alpha.
tone_rgb = new("ShaderNodeCombineColor", "ToneRGB")
links.new(tone_out, tone_rgb.inputs[0])
links.new(tone_out, tone_rgb.inputs[1])
links.new(tone_out, tone_rgb.inputs[2])
emission = new("ShaderNodeEmission", "Emit")
links.new(tone_rgb.outputs[0], emission.inputs["Color"])
emission.inputs["Strength"].default_value = 1.0
clear = new("ShaderNodeBsdfTransparent", "Clear")
mix = new("ShaderNodeMixShader", "Mix")
links.new(mask, mix.inputs[0])
links.new(clear.outputs[0], mix.inputs[1])
links.new(emission.outputs[0], mix.inputs[2])
out = new("ShaderNodeOutputMaterial", "Out")
links.new(mix.outputs[0], out.inputs["Surface"])
plane.data.materials.append(mat)

# ------------------------------------------------------------------ the render
scene.render.filepath = OUT.rstrip("/") + "/frame_"
bpy.ops.render.render(animation=True)
print("forge rendered %d frames of %s at %d to %s" % (FRAMES, EFFECT, SIZE, OUT))
