"""The forge's shared vocabulary: the scene, the five nodes, and the context
an effect file is handed.

Imported by `render.py` inside Blender. Nothing here is Wilderhold-specific;
everything Wilderhold-specific is a file in `effects/`.

**An effect is a file, which is what `docs/VFX_FORGE.md` asked for** - *"an
effect is a declarative file, not a `.blend`... adding an effect means adding
a file - working rule 3, applied to art"*. The pilot wrote its one effect as a
branch inside `render.py`, which was right for one and is wrong for thirty:
two people cannot author two effects in one `if/elif`, and a thirty-branch
chain is the hardcoded stat table working rule 3 exists to refuse.

An effect module declares a `SPEC` and a `build(f)`:

    SPEC = {"frames": 16, "size": 96, "variants": 3,
            "why": "one line on what this is for"}

    def build(f):
        ring = f.band(f.grow(1.25), 0.24, 0.07)
        return f.Look(mask=ring, tone=f.lit(ring, 0.5))

`build` is handed a `Forge` and returns a `Look`: a mask socket that becomes
the alpha, and a tone socket that becomes the grey. Everything else - the
camera, the film, the keyframed clock, the radial coordinate, the swirl, the
noise, the emission - is here and identical for every effect, so no two
effects can disagree about what a frame or a radius means.
"""

from __future__ import annotations

import bpy


class Look:
    """What an effect returns: what is drawn, and how bright it is.

    `mask` is the alpha - one where the effect exists, zero where it does
    not - and `tone` is the grey the tint lands on, so a bright core inside a
    darker rim is a tone difference rather than two colours. Both are node
    *sockets*, not values.
    """

    def __init__(self, mask, tone=None):
        self.mask = mask
        self.tone = tone


class Forge:
    """The scene, and every primitive an effect may use.

    The rule for what belongs here: anything two effects would otherwise write
    twice. A helper used by one effect belongs in that effect's own file.
    """

    def __init__(self, tree, frames, size, seed):
        self.tree = tree
        self.nodes = tree.nodes
        self.links = tree.links
        self.frames = frames
        self.size = size
        self.seed = float(seed)
        self._n = 0

    # ---------------------------------------------------------------- nodes

    def new(self, kind, name=None, **props):
        self._n += 1
        node = self.nodes.new(kind)
        node.name = name or ("N%d" % self._n)
        for key, value in props.items():
            setattr(node, key, value)
        return node

    def plug(self, source, socket):
        if isinstance(source, (int, float)):
            socket.default_value = float(source)
        else:
            self.links.new(source, socket)

    def math(self, op, a=None, b=None, clamp=False, name=None):
        node = self.new("ShaderNodeMath", name, operation=op, use_clamp=clamp)
        if a is not None:
            self.plug(a, node.inputs[0])
        if b is not None:
            self.plug(b, node.inputs[1])
        return node.outputs[0]

    # ------------------------------------------------------- the five nodes

    def build_scene(self):
        """The clock, the radius, the angle, the swirl and the noise.

        Called once by `render.py` before the effect's own `build`.
        """
        # 1. Scene time -> age in 0..1, keyframed rather than driven: a driver
        #    needs the expression sandbox and a keyframe needs nothing.
        clock = self.new("ShaderNodeValue", "Age")
        out = clock.outputs[0]
        for frame in range(1, self.frames + 1):
            out.default_value = (frame - 1) / max(self.frames - 1, 1)
            out.keyframe_insert("default_value", frame=frame)
        self.raw_age = out
        # Linear in, eased out: an effect leaps and then lingers, which is
        # what every impact in this game does.
        self.age = self.math("POWER", out, 0.7, name="Eased")

        # 2. Radial coordinate from the plane's own object space, 0..~1.4.
        coords = self.new("ShaderNodeTexCoord", "Coords")
        self.coords = coords
        radial = self.new("ShaderNodeVectorMath", "Radial", operation="LENGTH")
        self.links.new(coords.outputs["Object"], radial.inputs[0])
        self.r = radial.outputs["Value"]

        # The angle, for anything with spokes, petals or a sweep.
        sep = self.new("ShaderNodeSeparateXYZ", "Sep")
        self.links.new(coords.outputs["Object"], sep.inputs[0])
        self.sep = sep
        self.x = sep.outputs["X"]
        self.y = sep.outputs["Y"]
        angle = self.new("ShaderNodeMath", "Angle", operation="ARCTAN2")
        self.links.new(sep.outputs["Y"], angle.inputs[0])
        self.links.new(sep.outputs["X"], angle.inputs[1])
        self.angle = angle.outputs[0]

        # 3. A swirl: rotate the noise lookup more toward the middle and with
        #    age, which is what stops a noise field reading as static grain.
        inward = self.math("SUBTRACT", 1.4, self.r, name="Inward")
        twist_age = self.math("MULTIPLY", self.age, 2.6, name="TwistAge")
        twist = self.math("MULTIPLY", inward, twist_age, name="Twist")
        turned = self.math("ADD", self.angle, twist, name="Turned")
        sx = self.math("MULTIPLY", self.math("COSINE", turned), self.r, name="SX")
        sy = self.math("MULTIPLY", self.math("SINE", turned), self.r, name="SY")
        swirled = self.new("ShaderNodeCombineXYZ", "Swirled")
        self.links.new(sx, swirled.inputs[0])
        self.links.new(sy, swirled.inputs[1])
        # The variant's own slice of the noise field, plus the age so the
        # grain moves. An irrational step, so two takes never land on the same
        # neighbourhood of it and a take is a different break-up of the same
        # effect rather than a recolour.
        drift = self.math("MULTIPLY", self.age, 1.7, name="AgeZ")
        self.links.new(self.math("ADD", drift, self.seed * 7.3197, name="Slice"),
                       swirled.inputs[2])
        self.swirled = swirled.outputs[0]

        # 4. Noise through a hard threshold: the whole stylisation.
        noise = self.new("ShaderNodeTexNoise", "Noise")
        self.links.new(self.swirled, noise.inputs["Vector"])
        noise.inputs["Scale"].default_value = 3.2
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.55
        self.noise = noise
        self.noise_fac = noise.outputs["Fac"]

    # ------------------------------------------------- the effect's toolbox
    #
    # Every one of these is a shape an effect wants rather than a maths node
    # it happens to need. An effect that reaches past these for raw `math` is
    # allowed; an effect that reaches past them for something *three* effects
    # want is a helper missing from here.

    def grain(self, above, source=None):
        """Where the noise is high enough. The hard threshold, by name."""
        return self.math("GREATER_THAN", source or self.noise_fac, above)

    def hole(self, below, source=None):
        """And its inverse: where the noise is low."""
        return self.math("LESS_THAN", source or self.noise_fac, below)

    def grow(self, rate, start=0.08, of=None):
        """A radius that runs outward with age. The spine of every ring."""
        return self.math("ADD", self.math("MULTIPLY", of or self.age, rate), start)

    def shrink(self, frm, rate=1.0, of=None):
        """And one that closes in: `frm` at birth, falling as it ages."""
        return self.math("SUBTRACT", frm, self.math("MULTIPLY", of or self.age, rate))

    def band(self, at, thick, floor=0.0):
        """A ring of a given thickness at a given radius.

        `thick` may be a socket, so a band can thin as it runs - which is what
        makes a shock read as a wave rather than as a hoop. It never reaches
        zero: the pilot's first render fell to a hairline by the fifth frame
        and read as a wire.
        """
        gap = self.math("ABSOLUTE", self.math("SUBTRACT", self.r, at))
        wide = self.math("MAXIMUM", thick, floor) if floor > 0.0 else thick
        return self.math("LESS_THAN", gap, wide)

    def disc(self, to):
        """Everything inside a radius."""
        return self.math("LESS_THAN", self.r, to)

    def ring_gap(self, inner, outer):
        """The area between two radii."""
        return self.both(self.math("GREATER_THAN", self.r, inner), self.disc(outer))

    def spokes(self, count, duty=0.5, turn=0.0):
        """`count` wedges around the middle: spikes, petals, shards.

        Built from the angle rather than from noise, because a spoke has to be
        even and noise never is.
        """
        turned = self.math("ADD", self.angle, turn)
        wave = self.math("SINE", self.math("MULTIPLY", turned, float(count) * 0.5))
        return self.math("GREATER_THAN", self.math("ABSOLUTE", wave), 1.0 - duty)

    def wedge(self, half_width, turn=0.0):
        """One cone of a given half-angle, for a lance or a spray."""
        turned = self.math("ADD", self.angle, turn)
        return self.math("LESS_THAN",
                         self.math("ABSOLUTE", self.math("SINE", turned)), half_width)

    def before(self, when):
        """One until `when` of the life, zero after: a part that dies early."""
        return self.math("LESS_THAN", self.age, when)

    def after(self, when):
        """And one that has not started yet."""
        return self.math("GREATER_THAN", self.age, when)

    def both(self, a, b):
        return self.math("MULTIPLY", a, b)

    def either(self, *parts):
        out = parts[0]
        for part in parts[1:]:
            out = self.math("MAXIMUM", out, part)
        return out

    def rise(self, by, of=None):
        """Shifts the whole effect along Y, for anything that lifts off the
        ground - a flame tongue, a dust column, a level-up shaft."""
        return self.math("SUBTRACT", self.y, self.math("MULTIPLY", of or self.age, by))

    def lit(self, *parts_and_weights):
        """The tone: a weighted sum over a base, clamped.

        Call as `lit(core, 0.45, rim, 0.2)` or `lit(core, 0.5)`. The base is
        0.55 so a rim is grey and a core is near-white, which is what makes a
        tint read as a bright middle in a darker edge.
        """
        total = None
        pairs = list(zip(parts_and_weights[0::2], parts_and_weights[1::2]))
        for part, weight in pairs:
            term = self.math("MULTIPLY", part, float(weight))
            total = term if total is None else self.math("ADD", total, term)
        if total is None:
            return 0.75
        return self.math("ADD", total, 0.55, clamp=True)


# Reachable as `f.Look(...)` so an effect file needs no import of its own.
Forge.Look = Look


def build_world(frames, size):
    """The scene every effect is rendered in. Identical for all of them, so a
    sheet's cell size and timing cannot vary by effect author."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.frame_start = 1
    scene.frame_end = frames
    try:
        scene.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    # Standard rather than AgX or Filmic: a white emission must render white,
    # or the game's tint lands on a grey the tone-mapper invented.
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
    return scene, plane


def build_material(plane, effect_id):
    mat = bpy.data.materials.new("Forge_" + effect_id)
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
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    plane.data.materials.append(mat)
    return tree


def finish(forge, look):
    """Emission, and the mask drives the alpha."""
    tone = look.tone if look.tone is not None else 0.8
    rgb = forge.new("ShaderNodeCombineColor", "ToneRGB")
    for index in range(3):
        forge.plug(tone, rgb.inputs[index])
    emission = forge.new("ShaderNodeEmission", "Emit")
    forge.links.new(rgb.outputs[0], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.0
    clear = forge.new("ShaderNodeBsdfTransparent", "Clear")
    mix = forge.new("ShaderNodeMixShader", "Mix")
    forge.plug(look.mask, mix.inputs[0])
    forge.links.new(clear.outputs[0], mix.inputs[1])
    forge.links.new(emission.outputs[0], mix.inputs[2])
    out = forge.new("ShaderNodeOutputMaterial", "Out")
    forge.links.new(mix.outputs[0], out.inputs["Surface"])
