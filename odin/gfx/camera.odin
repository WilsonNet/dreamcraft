package gfx

import "core:c"
import "core:math/linalg"

// Screen/world projection and collision helpers (raylib rcore.c / rmodels.c semantics:
// OpenGL clip conventions, screen y down, logical window size).

@(private)
unproject :: proc(p: Vector3, proj, view: Matrix) -> Vector3 {
	inv := linalg.inverse(proj * view)
	v := inv * Vector4{p.x, p.y, p.z, 1}
	return v.xyz / v.w
}

GetWorldToScreenEx :: proc(position: Vector3, camera: Camera3D, width, height: c.int) -> Vector2 {
	proj := camera_projection(camera, f32(width) / f32(max(height, 1)))
	view := MatrixLookAt(camera.position, camera.target, camera.up)
	clip := proj * view * Vector4{position.x, position.y, position.z, 1}
	ndc := Vector3{clip.x / clip.w, -clip.y / clip.w, clip.z / clip.w}
	return {(ndc.x + 1) / 2 * f32(width), (ndc.y + 1) / 2 * f32(height)}
}

GetWorldToScreen :: proc(position: Vector3, camera: Camera3D) -> Vector2 {
	return GetWorldToScreenEx(position, camera, GetScreenWidth(), GetScreenHeight())
}

GetScreenToWorldRayEx :: proc(position: Vector2, camera: Camera3D, width, height: c.int) -> Ray {
	x := 2 * position.x / f32(width) - 1
	y := 1 - 2 * position.y / f32(height)
	view := MatrixLookAt(camera.position, camera.target, camera.up)
	proj: Matrix
	if camera.projection == .ORTHOGRAPHIC {
		aspect := f32(width) / f32(max(height, 1))
		top := camera.fovy / 2
		right := top * aspect
		proj = MatrixOrtho(-right, right, -top, top, 0.01, 1000)
	} else {
		proj = camera_projection(camera, f32(width) / f32(max(height, 1)))
	}
	near := unproject({x, y, 0}, proj, view)
	far := unproject({x, y, 1}, proj, view)
	ray: Ray
	ray.direction = Vector3Normalize(far - near)
	if camera.projection == .ORTHOGRAPHIC {
		ray.position = unproject({x, y, -1}, proj, view)
	} else {
		ray.position = camera.position
	}
	return ray
}

GetScreenToWorldRay :: proc(position: Vector2, camera: Camera3D) -> Ray {
	return GetScreenToWorldRayEx(position, camera, GetScreenWidth(), GetScreenHeight())
}

GetCameraMatrix :: proc(camera: Camera3D) -> Matrix {
	return MatrixLookAt(camera.position, camera.target, camera.up)
}

GetRayCollisionTriangle :: proc(ray: Ray, p1, p2, p3: Vector3) -> RayCollision {
	EPS :: 0.000001
	out: RayCollision
	e1 := p2 - p1
	e2 := p3 - p1
	p := Vector3CrossProduct(ray.direction, e2)
	det := Vector3DotProduct(e1, p)
	if det > -EPS && det < EPS {
		return out
	}
	inv := 1 / det
	tv := ray.position - p1
	u := Vector3DotProduct(tv, p) * inv
	if u < 0 || u > 1 {
		return out
	}
	q := Vector3CrossProduct(tv, e1)
	v := Vector3DotProduct(ray.direction, q) * inv
	if v < 0 || u + v > 1 {
		return out
	}
	t := Vector3DotProduct(e2, q) * inv
	if t > EPS {
		out.hit = true
		out.distance = t
		out.normal = Vector3Normalize(Vector3CrossProduct(e1, e2))
		out.point = ray.position + ray.direction * t
	}
	return out
}

GetRayCollisionQuad :: proc(ray: Ray, p1, p2, p3, p4: Vector3) -> RayCollision {
	col := GetRayCollisionTriangle(ray, p1, p2, p4)
	if !col.hit {
		col = GetRayCollisionTriangle(ray, p2, p3, p4)
	}
	return col
}

CheckCollisionPointRec :: proc(point: Vector2, rec: Rectangle) -> bool {
	return point.x >= rec.x && point.x < rec.x + rec.width && point.y >= rec.y && point.y < rec.y + rec.height
}

CheckCollisionRecs :: proc(rec1, rec2: Rectangle) -> bool {
	return rec1.x < rec2.x + rec2.width && rec1.x + rec1.width > rec2.x && rec1.y < rec2.y + rec2.height && rec1.y + rec1.height > rec2.y
}
