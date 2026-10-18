class_name Fx
## Small effects any node can call, for players, bosses and obstacles alike: sparks flying off a
## point, a shake of the camera, a squash and stretch. Each adds what it draws under the node it's
## given (and frees it when done), and needs nothing else.


# A burst of `count` little squares flying out of `point` (global) and fading, in shades of `color`
# toward white: blades clashing, a parry, a pogo.
static func sparks(owner: Node, point: Vector2, count: int, color: Color):
	for i in count:
		var spark = ColorRect.new()
		spark.top_level = true
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(4, 4)
		spark.color = color.lerp(Color.WHITE, randf() * 0.6)
		owner.add_child(spark)
		spark.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)


# Shakes the camera that `node` is seen through, if it's one that shakes (core/camera_shake.gd).
static func shake(node: Node, strength: float):
	var cam = node.get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


# `item` squashed or stretched to `shape` at once, springing back to its own over `time`. Returns
# the tween, so the next one can stop it.
static func squash(item: CanvasItem, shape: Vector2, time: float) -> Tween:
	item.scale = shape
	var tween = item.create_tween()
	tween.tween_property(item, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween
