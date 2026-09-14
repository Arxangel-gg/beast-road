extends Node

## Every shader in the project, read for the mistakes a headless runner cannot see.
##
##   godot --headless --path game res://tools/shader_lint_check.tscn
##
## **Shaders do not compile under `--headless`.** The dummy renderer accepts the
## code and throws it away, so a shader with a syntax error loads clean, every
## gate stays green, and the thing it was supposed to draw is missing on a real
## machine with no error anywhere. CI is headless on every runner this project
## has, so no gate in the suite has ever compiled a single line of GLSL.
##
## That is not hypothetical. `town_health_ring.gdshader` shipped with
## `const float TAU = 6.28318530718;` in it. `TAU` is already a constant in
## Godot's shading language, so the whole shader failed with "Redefinition of
## 'TAU'" and **the city's health ring - which the owner had asked for by name -
## drew nothing.** It was found by running `night_check` on a real renderer for
## an unrelated reason and reading the log above the verdict.
##
## So this reads the source instead. It cannot replace a compiler and does not
## pretend to; what it holds are the traps this project has actually paid for,
## which are the ones that fail *silently* rather than loudly.
##
## **The other half of the answer is to run something windowed after touching a
## shader.** Any of the `*_shot` tools will do - they build real screens on a
## real renderer - and `SHADER ERROR` in the output is the whole test:
##
##   godot --path game res://tools/vfx_shot.tscn 2>&1 | grep "SHADER ERROR"
##
## `town_ring_shot.tscn` exists for the same reason and photographs the ring this
## gate was written for, at whatever share of the city's health you ask for.

## Names Godot's shading language already defines, which a shader may not
## redeclare. Doing so is a hard compile error and takes the whole file with it.
const RESERVED: Array[String] = ["PI", "TAU", "E"]

## Built-ins that are not values and cannot be handed to a function.
##
## Recorded because it costs a shader that *loads*: Godot asserts, reports that
## it "continues", and the shader draws wrong rather than not at all - which is
## far harder to notice than a blank screen.
const NOT_ARGUMENTS: Array[String] = ["TEXTURE", "SCREEN_TEXTURE",
	"NORMAL_TEXTURE", "DEPTH_TEXTURE"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _files: int = 0


func _ready() -> void:
	var sources: Dictionary = {}
	_gather_shader_files("res://", sources)
	_gather_embedded_shaders("res://", sources)
	_check(sources.size() >= 10,
		"only %d shaders found; this project has more than that" % sources.size())
	for where: String in sources:
		_read(where, String(sources[where]))
	if _failures.is_empty():
		print("[shader-lint] PASS - %d shaders, %d checks: no reserved name is "
			% [_files, _checks]
			+ "redeclared and no built-in sampler is passed as an argument")
	else:
		for failure: String in _failures:
			push_error("[shader-lint] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## Every `.gdshader` on disk.
func _gather_shader_files(from: String, into: Dictionary) -> void:
	var directory := DirAccess.open(from)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path: String = from.path_join(entry)
		if directory.current_is_dir():
			_gather_shader_files(path, into)
		elif entry.ends_with(".gdshader"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				into[path] = file.get_as_text()
		entry = directory.get_next()
	directory.list_dir_end()


## Shaders written inline in GDScript.
##
## Half of this project's shaders are `const SHADER_CODE: String = """..."""` in
## the system that owns them - the weather veil, the fog, the boss fall - and a
## lint that only walked `.gdshader` files would have had no opinion about any of
## them. They are found by the marker every one of them starts with rather than
## by parsing GDScript.
func _gather_embedded_shaders(from: String, into: Dictionary) -> void:
	var directory := DirAccess.open(from)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path: String = from.path_join(entry)
		if directory.current_is_dir():
			_gather_embedded_shaders(path, into)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text: String = file.get_as_text()
				if text.contains("shader_type "):
					into[path] = text
		entry = directory.get_next()
	directory.list_dir_end()


## One shader's source, line by line.
func _read(where: String, code: String) -> void:
	_files += 1
	var lines: PackedStringArray = code.split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		var bare: String = line.strip_edges()
		if bare.begins_with("//") or bare.begins_with("#") or bare.begins_with("##"):
			continue
		_read_declarations(where, index + 1, bare)
		_read_arguments(where, index + 1, bare)


## A declaration that shadows a name the language already owns.
func _read_declarations(where: String, line_number: int, line: String) -> void:
	for name: String in RESERVED:
		# `const float TAU =`, `uniform float PI;`, `float E = ...` - the shape is
		# always "some words, then the name, then = or ;".
		var at: int = line.find(name)
		while at >= 0:
			var before: String = line.substr(0, at).strip_edges()
			var after: String = line.substr(at + name.length()).strip_edges()
			var declared: bool = _is_type_word(before.get_slice(" ",
				maxi(before.get_slice_count(" ") - 1, 0))) \
				and (after.begins_with("=") or after.begins_with(";")
					or after.begins_with("["))
			_check(not declared,
				"%s:%d redeclares `%s`, which Godot's shading language already "
					% [where, line_number, name]
					+ "defines - the whole shader fails to compile and draws "
					+ "nothing, and no headless gate can see it")
			at = line.find(name, at + 1)


## A built-in sampler handed to a function, which asserts and draws wrong.
func _read_arguments(where: String, line_number: int, line: String) -> void:
	for name: String in NOT_ARGUMENTS:
		var at: int = line.find(name)
		while at >= 0:
			var after: String = line.substr(at + name.length()).strip_edges()
			# Inside an argument list it is followed by a comma or a closing
			# bracket, and preceded by an opening bracket or a comma. Texture
			# reads - `texture(TEXTURE, UV)` - are the legitimate case and are
			# the first argument of a *built-in*, so the call is what decides.
			var before: String = line.substr(0, at).strip_edges()
			var inside: bool = before.ends_with("(") or before.ends_with(",")
			var closing: bool = after.begins_with(",") or after.begins_with(")")
			var reading: bool = before.ends_with("texture(") \
				or before.ends_with("textureLod(") or before.ends_with("texelFetch(") \
				or before.ends_with("textureSize(")
			_check(not (inside and closing and not reading),
				"%s:%d passes `%s` to a function. It is not a value: Godot "
					% [where, line_number, name]
					+ "asserts, reports that it continues, and the shader draws "
					+ "wrong rather than failing")
			at = line.find(name, at + 1)


## Whether a word looks like a type, so `float TAU =` reads as a declaration and
## `something / TAU` does not.
func _is_type_word(word: String) -> bool:
	if word.is_empty():
		return false
	return word in ["float", "int", "uint", "bool", "vec2", "vec3", "vec4",
		"ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4", "bvec2", "bvec3",
		"bvec4", "mat2", "mat3", "mat4"]
