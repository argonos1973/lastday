extends RefCounted

# ================================================================
# RIFLE STRAP - SISTEMA COMPLETO
# GODOT 4.x
#
# RECORRIDO:
#
# CAÑÓN DEL RIFLE
#      ↓
# DETRÁS DEL HOMBRO
#      ↓
# ENCIMA DEL HOMBRO
#      ↓
# CLAVÍCULA
#      ↓
# PECHO
#      ↓
# COSTILLAS
#      ↓
# COSTADO
#      ↓
# ESPALDA
#      ↓
# CULATA DEL RIFLE
#
# No usa Curve3D.
# No usa Bézier.
# No usa handles.
# No genera overshoot de curvas.
# ================================================================

var player: Node

# ================================================================
# CONFIGURACIÓN
# ================================================================

# Anchura física de la cinta: 5,5 cm.
const RIFLE_STRAP_WIDTH: float = 0.055

# Grosor físico: 3,5 mm.
const RIFLE_STRAP_THICKNESS: float = 0.0035

# Distancia aproximada desde el centro de los huesos
# hasta la superficie frontal de la camiseta.
const RIFLE_STRAP_FRONT_OFFSET: float = 0.31

# Separación en la espalda.
const RIFLE_STRAP_BACK_OFFSET: float = 0.175

# Anchura lateral para rodear las costillas.
const RIFLE_STRAP_SIDE_OFFSET: float = 0.165

# Distancia máxima razonable entre dos puntos consecutivos.
const RIFLE_STRAP_MAX_SEGMENT: float = 0.55

# Solo una pasada.
# Con los puntos actuales es suficiente.
const RIFLE_STRAP_SMOOTH_PASSES: int = 1

# ================================================================
# ACTUALIZAR CORREA
# ================================================================

func _update_rifle_strap(_delta: float) -> void:

	# ============================================================
	# VALIDACIONES
	# ============================================================

	if player._rifle_on_back_strap == null:
		return

	if not is_instance_valid(player._rifle_on_back_strap):
		return

	if player._strap_barrel_marker == null:
		return

	if not is_instance_valid(player._strap_barrel_marker):
		return

	if player._strap_stock_marker == null:
		return

	if not is_instance_valid(player._strap_stock_marker):
		return

	if player.third_person_model == null:
		return

	if not is_instance_valid(player.third_person_model):
		return

	# ============================================================
	# RAÍZ DE LA CORREA RIGGEADA
	# ============================================================

	var strap_root := player._rifle_on_back_strap as Node3D

	if strap_root == null:
		return

	# TODOS los puntos se calcularán en el espacio local del
	# third_person_model (padre del strap_root). Esto es estable
	# y no cambia cuando _position_strap_bones mueve el strap_root.
	var strap_space: Node3D = player.third_person_model

	# ============================================================
	# SKELETON DE LA CORREA
	# ============================================================

	var strap_skel: Skeleton3D = player._strap_skeleton

	if strap_skel == null \
	or not is_instance_valid(strap_skel):

		for child in strap_root.get_children():
			if child is Skeleton3D:
				strap_skel = child as Skeleton3D
				break

	if strap_skel == null:
		push_warning(
			"RIFLE STRAP: no Skeleton3D en la correa riggeada"
		)
		return

	# ============================================================
	# OBTENER SKELETON
	# ============================================================

	var skeleton: Skeleton3D = null

	if player._spine_skeleton != null \
	and is_instance_valid(player._spine_skeleton):

		skeleton = player._spine_skeleton as Skeleton3D

	if skeleton == null:

		skeleton = _strap_find_skeleton(
			player.third_person_model
		)

	if skeleton == null:

		push_warning(
			"RIFLE STRAP: no se encontró Skeleton3D"
		)
		return

	# ============================================================
	# ANCLAJES REALES DEL RIFLE
	# ============================================================

	var barrel_anchor: Vector3 = strap_space.to_local(
		player._strap_barrel_marker.global_position
	)

	var stock_anchor: Vector3 = strap_space.to_local(
		player._strap_stock_marker.global_position
	)

	# ============================================================
	# BUSCAR HUESOS
	# ============================================================

	var spine2_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_Spine2",
			"mixamorig:Spine2",
			"Spine2"
		]
	)

	var spine1_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_Spine1",
			"mixamorig:Spine1",
			"Spine1"
		]
	)

	var spine_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_Spine",
			"mixamorig:Spine",
			"Spine"
		]
	)

	var hips_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_Hips",
			"mixamorig:Hips",
			"Hips"
		]
	)

	var left_shoulder_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_LeftShoulder",
			"mixamorig:LeftShoulder",
			"LeftShoulder"
		]
	)

	var right_shoulder_idx: int = _strap_find_first_bone(
		skeleton,
		[
			"mixamorig_RightShoulder",
			"mixamorig:RightShoulder",
			"RightShoulder"
		]
	)

	# ============================================================
	# FALLBACKS
	# ============================================================

	if spine2_idx < 0:
		spine2_idx = spine1_idx

	if spine1_idx < 0:
		spine1_idx = spine2_idx

	if spine_idx < 0:
		spine_idx = spine1_idx

	if hips_idx < 0:
		hips_idx = spine_idx

	if spine2_idx < 0 or spine1_idx < 0:

		push_warning(
			"RIFLE STRAP: no se encontraron huesos Spine"
		)
		return

	# ============================================================
	# TRANSFORMS DE TORSO
	# ============================================================

	var spine2_tf: Transform3D = _strap_bone_transform(
		skeleton,
		spine2_idx,
		strap_space
	)

	var spine1_tf: Transform3D = _strap_bone_transform(
		skeleton,
		spine1_idx,
		strap_space
	)

	var spine_tf: Transform3D = _strap_bone_transform(
		skeleton,
		spine_idx,
		strap_space
	)

	var hips_tf: Transform3D = _strap_bone_transform(
		skeleton,
		hips_idx,
		strap_space
	)

	var chest_high: Vector3 = spine2_tf.origin
	var chest_mid: Vector3 = spine1_tf.origin
	var chest_low: Vector3 = spine_tf.origin
	var hips_pos: Vector3 = hips_tf.origin

	var torso_center: Vector3 = (
		chest_high
		+ chest_mid
		+ chest_low
	) / 3.0

	# ============================================================
	# CALCULAR ESPALDA Y DELANTE
	#
	# NO asumimos que Z positivo sea espalda.
	# Usamos la propia posición del rifle.
	# ============================================================

	var rifle_center: Vector3 = (
		barrel_anchor
		+ stock_anchor
	) * 0.5

	var back_dir: Vector3 = (
		rifle_center
		- torso_center
	)

	back_dir.y = 0.0

	if back_dir.length_squared() < 0.000001:

		back_dir = Vector3(
			0.0,
			0.0,
			1.0
		)

	back_dir = back_dir.normalized()

	var front_dir: Vector3 = -back_dir

	# ============================================================
	# DERECHA / IZQUIERDA
	# ============================================================

	var right_dir: Vector3 = (
		front_dir.cross(
			Vector3.UP
		)
	)

	if right_dir.length_squared() < 0.000001:

		right_dir = Vector3.RIGHT

	right_dir = right_dir.normalized()

	# ============================================================
	# ELEGIR EL HOMBRO MÁS CERCANO AL CAÑÓN
	# ============================================================

	var shoulder_tf: Transform3D
	var shoulder_found: bool = false

	if left_shoulder_idx >= 0 \
	and right_shoulder_idx >= 0:

		var left_tf: Transform3D = _strap_bone_transform(
			skeleton,
			left_shoulder_idx,
			strap_space
		)

		var right_tf: Transform3D = _strap_bone_transform(
			skeleton,
			right_shoulder_idx,
			strap_space
		)

		var left_distance: float = (
			barrel_anchor.distance_squared_to(
				left_tf.origin
			)
		)

		var right_distance: float = (
			barrel_anchor.distance_squared_to(
				right_tf.origin
			)
		)

		if left_distance < right_distance:

			shoulder_tf = left_tf

		else:

			shoulder_tf = right_tf

		shoulder_found = true

	elif left_shoulder_idx >= 0:

		shoulder_tf = _strap_bone_transform(
			skeleton,
			left_shoulder_idx,
			strap_space
		)

		shoulder_found = true

	elif right_shoulder_idx >= 0:

		shoulder_tf = _strap_bone_transform(
			skeleton,
			right_shoulder_idx,
			strap_space
		)

		shoulder_found = true

	if not shoulder_found:

		push_warning(
			"RIFLE STRAP: no se encontró hombro"
		)
		return

	var shoulder_pos: Vector3 = shoulder_tf.origin

	# ============================================================
	# DETERMINAR LADO DEL HOMBRO
	# ============================================================

	var shoulder_side_value: float = (
		shoulder_pos
		- torso_center
	).dot(
		right_dir
	)

	var shoulder_side: float = 1.0

	if shoulder_side_value < 0.0:

		shoulder_side = -1.0

	# Dirección hacia el lado CONTRARIO del cuerpo.
	# Esto crea la diagonal sobre el pecho.
	var opposite_dir: Vector3 = (
		-right_dir
		* shoulder_side
	)

	# ============================================================
	# PARTE BAJA DEL TORSO
	# ============================================================

	var lower_torso: Vector3 = chest_low.lerp(
		hips_pos,
		0.35
	)

	# ============================================================
	# PUNTOS DE CONTROL
	# ============================================================

	var points: Array[Vector3] = []

	# ============================================================
	# P0
	# ANCLAJE DEL CAÑÓN
	# ============================================================

	var p1: Vector3 = (
		shoulder_pos
		+ back_dir * 0.050
		+ Vector3.UP * 0.020
	)

	var p0a: Vector3 = barrel_anchor.lerp(p1, 0.33)
	var p0b: Vector3 = barrel_anchor.lerp(p1, 0.66)

	points.append(p0a)
	points.append(p0b)
	points.append(p1)

	# ============================================================
	# P2
	# ENCIMA DEL HOMBRO
	# ============================================================

	var p2: Vector3 = (
		shoulder_pos
		+ Vector3.UP * 0.045
		+ front_dir * 0.030
	)

	points.append(
		p2
	)

	# ============================================================
	# P3
	# PARTE DELANTERA DEL HOMBRO / CLAVÍCULA
	#
	# Este punto empieza la zona frontal visible.
	# ============================================================

	var p3: Vector3 = (
		chest_high
		+ right_dir
			* shoulder_side
			* 0.090
		+ Vector3.UP * 0.045
		+ front_dir
			* RIFLE_STRAP_FRONT_OFFSET
	)

	points.append(
		p3
	)

	# ============================================================
	# P4
	# PECHO ALTO
	# ============================================================

	var p4: Vector3 = (
		chest_high.lerp(
			chest_mid,
			0.38
		)
		+ right_dir
			* shoulder_side
			* 0.025
		+ front_dir
			* RIFLE_STRAP_FRONT_OFFSET
	)

	points.append(
		p4
	)

	# ============================================================
	# P5
	# CENTRO DEL PECHO
	#
	# Ya cruza ligeramente al lado contrario.
	# ============================================================

	var p5: Vector3 = (
		chest_mid
		+ opposite_dir * 0.060
		+ front_dir
			* (
				RIFLE_STRAP_FRONT_OFFSET
				+ 0.005
			)
		- Vector3.UP * 0.025
	)

	points.append(
		p5
	)

	# ============================================================
	# P6
	# COSTILLAS
	#
	# Aquí está uno de los cambios importantes:
	# la correa baja mucho más que antes.
	# ============================================================

	var p6: Vector3 = (
		chest_low
		+ opposite_dir * 0.120
		+ Vector3.UP * 0.050
		+ front_dir
			* (
				RIFLE_STRAP_FRONT_OFFSET
				- 0.010
			)
	)

	points.append(
		p6
	)

	# ============================================================
	# P7
	# LATERAL BAJO DEL TORSO
	#
	# NO debe tocar ni rodear el brazo.
	# ============================================================

	var p7: Vector3 = (
		lower_torso
		+ opposite_dir * 0.160
		+ front_dir * 0.250
	)

	points.append(
		p7
	)

	# ============================================================
	# P8
	# COSTADO PURO
	#
	# Ya estamos girando hacia la espalda.
	# ============================================================

	var p8: Vector3 = (
		lower_torso
		+ opposite_dir
			* (RIFLE_STRAP_SIDE_OFFSET + 0.020)
		+ front_dir * 0.080
	)

	points.append(
		p8
	)

	# ============================================================
	# P9
	# DETRÁS DEL COSTADO
	# ============================================================

	var p9: Vector3 = (
		lower_torso
		+ opposite_dir * 0.145
		+ back_dir * 0.105
	)

	points.append(
		p9
	)

	# ============================================================
	# P10
	# ESPALDA
	#
	# Punto intermedio antes de llegar a la culata.
	# ============================================================

	var back_point: Vector3 = (
		chest_low
		+ opposite_dir * 0.075
		+ back_dir
			* RIFLE_STRAP_BACK_OFFSET
	)

	var p10: Vector3 = back_point.lerp(
		stock_anchor,
		0.55
	)

	var p9b: Vector3 = p9.lerp(p10, 0.5)
	var p10b: Vector3 = p10.lerp(stock_anchor, 0.5)

	points.append(p9b)
	points.append(p10)
	points.append(p10b)
	points.append(stock_anchor)

	# ============================================================
	# COMPROBAR DISTANCIAS
	# ============================================================

	for i in range(
		points.size() - 1
	):

		var segment_length: float = (
			points[i].distance_to(
				points[i + 1]
			)
		)

		if segment_length > RIFLE_STRAP_MAX_SEGMENT:
			pass

	# ============================================================
	# DEBUG: ESFERAS EN CADA PUNTO DE CONTROL
	# ============================================================

	if player.has_method("_update_strap_debug_spheres") and player.get("_strap_diagnostic_mode") == true:
		player._update_strap_debug_spheres(points)

	# ============================================================
	# SUAVIZADO
	#
	# Una única pasada para evitar que la correa se convierta
	# en una curva demasiado redonda.
	# ============================================================

	var smooth_points: Array[Vector3] = (
		_strap_chaikin_smooth(
			points,
			RIFLE_STRAP_SMOOTH_PASSES
		)
	)

	# DEBUG: Imprimir puntos y rest pose (solo una vez)
	# ============================================================
	# PROCEDURAL RIBBON MESH (100% continuo, sin cortes ni brechas)
	# ============================================================

	_update_procedural_mesh(smooth_points, torso_center)

	# Posicionar huesos por compatibilidad
	_position_strap_bones(
		strap_skel,
		smooth_points,
		torso_center
	)

# ================================================================
# BUSCAR SKELETON
# ================================================================

func _strap_find_skeleton(
	root: Node
) -> Skeleton3D:

	if root == null:
		return null

	if root is Skeleton3D:

		return root as Skeleton3D

	for child in root.get_children():

		var found: Skeleton3D = (
			_strap_find_skeleton(
				child
			)
		)

		if found != null:

			return found

	return null

# ================================================================
# BUSCAR HUESO
# ================================================================

func _strap_find_first_bone(
	skeleton: Skeleton3D,
	names: Array
) -> int:

	if skeleton == null:
		return -1

	for bone_name in names:

		var idx: int = skeleton.find_bone(
			str(bone_name)
		)

		if idx >= 0:

			return idx

	return -1

# ================================================================
# TRANSFORM DEL HUESO EN ESPACIO LOCAL DE LA CORREA
# ================================================================

func _strap_bone_transform(
	skeleton: Skeleton3D,
	bone_idx: int,
	strap_space: Node3D
) -> Transform3D:

	var bone_pose: Transform3D = (
		skeleton.get_bone_global_pose(
			bone_idx
		)
	)

	var bone_world: Transform3D = (
		skeleton.global_transform
		* bone_pose
	)

	return (
		strap_space.global_transform.affine_inverse()
		* bone_world
	)

# ================================================================
# SUAVIZADO CHAIKIN
#
# No puede crear grandes overshoots como Bézier.
# ================================================================

func _strap_chaikin_smooth(
	input_points: Array[Vector3],
	passes: int
) -> Array[Vector3]:

	var result: Array[Vector3] = []

	for point in input_points:

		result.append(
			point
		)

	for _pass in range(
		passes
	):

		if result.size() < 3:
			break

		var next_points: Array[Vector3] = []

		# Mantener anclaje inicial EXACTO.
		next_points.append(
			result[0]
		)

		for i in range(
			result.size() - 1
		):

			var a: Vector3 = result[i]
			var b: Vector3 = result[i + 1]

			var q: Vector3 = a.lerp(
				b,
				0.25
			)

			var r: Vector3 = a.lerp(
				b,
				0.75
			)

			next_points.append(
				q
			)

			next_points.append(
				r
			)

		# Mantener anclaje final EXACTO.
		next_points.append(
			result[result.size() - 1]
		)

		result = next_points

	return result

# ================================================================
# POSICIONAR HUESOS DE LA CORREA RIGGEADA
#
# Distribuye 8 huesos (Strap_00..Strap_07) a lo largo del
# camino suavizado. Cada hueso se coloca en una posición
# equidistante en arco y se orienta siguiendo la tangente.
# ================================================================

func _position_strap_bones(
	strap_skel: Skeleton3D,
	smooth_points: Array[Vector3],
	torso_center: Vector3
) -> void:

	if strap_skel == null:
		return

	if smooth_points.size() < 2:
		return

	var n_bones: int = strap_skel.get_bone_count()

	if n_bones < 2:
		return

	# ============================================================
	# CALCULAR DISTANCIAS ACUMULADAS (arc-length)
	# ============================================================

	var total_length: float = 0.0
	var cumul: Array[float] = []
	cumul.resize(smooth_points.size())
	cumul[0] = 0.0

	for i in range(1, smooth_points.size()):
		var d: float = smooth_points[i - 1].distance_to(smooth_points[i])
		total_length += d
		cumul[i] = total_length

	if total_length < 0.001:
		return

	# ============================================================
	# SAMPLEAR N POSICIONES A INTERVALOS IGUALES
	# ============================================================

	var bone_positions: Array[Vector3] = []
	bone_positions.resize(n_bones)

	for b in range(n_bones):
		var t: float = float(b) / float(n_bones - 1)
		var target_dist: float = total_length * t

		# Encontrar el segmento que contiene target_dist
		var seg_idx: int = 0
		for i in range(1, smooth_points.size()):
			if cumul[i] >= target_dist:
				seg_idx = i - 1
				break

		var seg_start: float = cumul[seg_idx]
		var seg_end: float = cumul[seg_idx + 1]
		var seg_len: float = seg_end - seg_start

		var local_t: float = 0.0
		if seg_len > 0.001:
			local_t = (target_dist - seg_start) / seg_len

		bone_positions[b] = smooth_points[seg_idx].lerp(
			smooth_points[seg_idx + 1],
			local_t
		)

	# ============================================================
	# CALCULAR TANGENTES Y NORMALES EN CADA PUNTO
	# ============================================================

	var tangents: Array[Vector3] = []
	tangents.resize(n_bones)

	var normals: Array[Vector3] = []
	normals.resize(n_bones)

	for b in range(n_bones):
		# Tangente: dirección a lo largo del camino
		var pos := bone_positions[b]

		if b == 0:
			tangents[b] = (bone_positions[1] - pos).normalized()
		elif b == n_bones - 1:
			tangents[b] = (pos - bone_positions[b - 1]).normalized()
		else:
			tangents[b] = (bone_positions[b + 1] - bone_positions[b - 1]).normalized()

		# Normal: dirección hacia fuera del cuerpo
		var normal: Vector3 = pos - torso_center
		normal.y = 0.0

		if normal.length_squared() < 0.000001:
			normal = Vector3.FORWARD

		normals[b] = normal.normalized()

	# ============================================================
	# COLOCAR HUESOS
	#
	# Los huesos forman una cadena padre-hijo.
	# Strap_00 es la raíz.
	# Cada hueso se coloca relativo a su padre.
	# ============================================================

	# El skeleton es hijo directo del strap_root.
	# Los smooth_points están en espacio local del third_person_model
	# (padre del strap_root), que es estable.
	# El mesh fue modelado centrado cerca del origen (AABB Y: -0.386 a 0.268).
	# Los smooth_points están a altura del cuerpo (Y ≈ 1.5-2.0m).
	#
	# SOLUCIÓN: Mover el strap_root al centro del camino, y poner los huesos
	# relativos a ese centro. Así los huesos quedan cerca del origen como en
	# el rest pose del mesh.
	var strap_root_node: Node3D = strap_skel.get_parent() as Node3D
	if strap_root_node == null:
		return

	# Calcular el centro del camino (en third_person_model space)
	var centroid: Vector3 = Vector3.ZERO
	for b in range(n_bones):
		centroid += bone_positions[b]
	centroid /= float(n_bones)

	# Calcular la longitud total del rest pose (suma de distancias padre-hijo)
	var rest_total_length: float = 0.0
	for b in range(n_bones):
		var parent_idx: int = strap_skel.get_bone_parent(b)
		if parent_idx >= 0:
			rest_total_length += strap_skel.get_bone_rest(b).origin.length()

	var path_rest_ratio: float = total_length / max(0.01, rest_total_length)

	# Mover el strap_root al centro del camino (dentro de third_person_model)
	# y escalarlo para que la malla cubra el path sin estirar los huesos
	strap_root_node.position = centroid
	strap_root_node.rotation = Vector3.ZERO
	strap_root_node.scale = Vector3.ONE * path_rest_ratio

	# Convertir posiciones de third_person_model space a strap_root local space
	# Como strap_root está en centroid con escala path_rest_ratio, dividimos por la escala
	var centered_positions: Array[Vector3] = []
	centered_positions.resize(n_bones)
	for b in range(n_bones):
		centered_positions[b] = (bone_positions[b] - centroid) / path_rest_ratio

	# Convertir al espacio local del skeleton (normalmente identity)
	var skel_local: Transform3D = strap_skel.transform
	var skel_local_inv: Transform3D = skel_local.affine_inverse()

	# El eje X = Y cross Z
	var local_rotations: Array[Quaternion] = []
	local_rotations.resize(n_bones)

	for b in range(n_bones):
		var tangent_local: Vector3 = (skel_local_inv.basis * tangents[b]).normalized()
		var normal_local: Vector3 = (skel_local_inv.basis * normals[b]).normalized()

		# Construir base: Y = tangent, Z = normal, X = Y cross Z
		var y_axis := tangent_local
		var z_axis := normal_local
		var x_axis := y_axis.cross(z_axis)

		if x_axis.length_squared() < 0.000001:
			x_axis = Vector3.RIGHT
		x_axis = x_axis.normalized()

		# Re-ortogonalizar Z
		z_axis = x_axis.cross(y_axis).normalized()

		var basis := Basis(x_axis, y_axis, z_axis)
		local_rotations[b] = basis.get_rotation_quaternion()

	# Construir transforms globales deseados (en espacio del skeleton)
	# y convertir a locales correctamente recorriendo la cadena
	var desired_globals: Array[Transform3D] = []
	desired_globals.resize(n_bones)

	for b in range(n_bones):
		var pos: Vector3 = skel_local_inv * centered_positions[b]
		var basis: Basis = Basis(local_rotations[b])
		desired_globals[b] = Transform3D(basis, pos)

	# Aplicar bones convirtiendo global -> local correctamente
	for b in range(n_bones):
		var parent_idx: int = strap_skel.get_bone_parent(b)

		if parent_idx < 0:
			# Hueso raíz: su local = su global
			strap_skel.set_bone_pose(b, desired_globals[b])
		else:
			# local = parent_global.inverse() * child_global
			var parent_global: Transform3D = desired_globals[parent_idx]
			var parent_inv: Transform3D = parent_global.affine_inverse()
			var local_transform: Transform3D = parent_inv * desired_globals[b]
			strap_skel.set_bone_pose(b, local_transform)

	# Forzar actualización
	strap_skel.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)

	# DEBUG: Verificar que los huesos se aplicaron (solo una vez)
# ================================================================
# GENERAR MALLA PROCEDURAL CONTINUA (100% SIN CORTES)
# ================================================================

func _update_procedural_mesh(smooth_points: Array[Vector3], torso_center: Vector3) -> void:
	if player == null or player.third_person_model == null or not is_instance_valid(player.third_person_model):
		return
	if smooth_points.size() < 2:
		return

	var parent_node: Node3D = player.third_person_model

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var strap_width: float = RIFLE_STRAP_WIDTH # 0.055
	var n_pts: int = smooth_points.size()

	for i in range(n_pts):
		var p: Vector3 = smooth_points[i]

		var t: Vector3 = Vector3.FORWARD
		if i < n_pts - 1:
			t = (smooth_points[i + 1] - smooth_points[i]).normalized()
		elif i > 0:
			t = (smooth_points[i] - smooth_points[i - 1]).normalized()

		var n: Vector3 = (p - torso_center)
		n.y = 0.0
		if n.length_squared() < 0.0001:
			n = Vector3.UP
		else:
			n = n.normalized()

		var side: Vector3 = t.cross(n)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()

		var half_w: Vector3 = side * (strap_width * 0.5)
		var uv_y: float = float(i) / float(n_pts - 1) * 8.0

		st.set_normal(n)
		st.set_uv(Vector2(0.0, uv_y))
		st.add_vertex(p - half_w)

		st.set_normal(n)
		st.set_uv(Vector2(1.0, uv_y))
		st.add_vertex(p + half_w)

	for i in range(n_pts - 1):
		var idx: int = i * 2
		st.add_index(idx)
		st.add_index(idx + 1)
		st.add_index(idx + 2)

		st.add_index(idx + 1)
		st.add_index(idx + 3)
		st.add_index(idx + 2)

	var new_mesh: Mesh = st.commit()

	var proc_mi: MeshInstance3D = parent_node.find_child("ProceduralStrapMesh", true, false) as MeshInstance3D
	if proc_mi == null:
		proc_mi = MeshInstance3D.new()
		proc_mi.name = "ProceduralStrapMesh"
		parent_node.add_child(proc_mi)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.08, 1.0)
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		proc_mi.material_override = mat

	proc_mi.position = Vector3.ZERO
	proc_mi.rotation = Vector3.ZERO
	proc_mi.scale = Vector3.ONE
	proc_mi.mesh = new_mesh
	proc_mi.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	proc_mi.visible = true

	if player._rifle_on_back_strap != null and is_instance_valid(player._rifle_on_back_strap):
		player._rifle_on_back_strap.visible = false
