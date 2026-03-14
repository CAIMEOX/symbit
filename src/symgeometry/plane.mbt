///|
/// A plane in 3-dimensional Euclidean space.
pub struct Plane {
  point_ : Point
  normal_ : Array[@symcore.Expr]
} derive(Eq)

///|
pub fn plane_from_normal(
  point_value : Point,
  normal_vector : Array[@symcore.Expr],
) -> Plane raise GeometryError {
  let point_value = point_value.with_dim(3)
  if normal_vector.length() != 3 {
    raise GeometryError::ValueError("plane normal vector must have length 3")
  }
  let normal = normal_vector.map(geo_simplify)
  if geo_all_zero(normal) {
    raise GeometryError::ValueError("plane normal vector cannot be zero")
  }
  Plane::{ point_: point_value, normal_: normal }
}

///|
pub fn plane_from_points(
  p1 : Point,
  p2 : Point,
  p3 : Point,
) -> Plane raise GeometryError {
  let normalized = geo_normalize_dim([p1, p2, p3])
  let a = normalized[0].with_dim(3)
  let b = normalized[1].with_dim(3)
  let c = normalized[2].with_dim(3)
  let ab = geo_sub_coords(b.coords_, a.coords_)
  let ac = geo_sub_coords(c.coords_, a.coords_)
  let normal = geo_cross3(ab, ac)
  if geo_all_zero(normal) {
    raise GeometryError::ValueError("plane points must not be collinear")
  }
  plane_from_normal(a, normal)
}

///|
pub fn Plane::point(self : Plane) -> Point {
  self.point_
}

///|
pub fn Plane::normal_vector(self : Plane) -> Array[@symcore.Expr] {
  geo_clone_exprs(self.normal_)
}

///|
pub fn Plane::repr(self : Plane) -> String {
  "Plane(" + self.point_.repr() + ", " + geo_render_tuple(self.normal_) + ")"
}

///|
pub fn Plane::equation(
  self : Plane,
  x? : @symcore.Expr = @symcore.symbol("x"),
  y? : @symcore.Expr = @symcore.symbol("y"),
  z? : @symcore.Expr = @symcore.symbol("z"),
) -> @symcore.Expr {
  geo_simplify(
    self.normal_[0] * (x - self.point_.coords_[0]) +
    self.normal_[1] * (y - self.point_.coords_[1]) +
    self.normal_[2] * (z - self.point_.coords_[2]),
  )
}

///|
pub fn Plane::contains_point(
  self : Plane,
  other : Point,
) -> Bool raise GeometryError {
  let pt = other.with_dim(3)
  geo_expr_is_zero(
    geo_dot(self.normal_, geo_sub_coords(pt.coords_, self.point_.coords_)),
  )
}

///|
pub fn Plane::contains(
  self : Plane,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) => self.contains_point(point_obj)
    GeometryEntity::Line(line_obj) =>
      self.contains_point(line_obj.p1_) && self.contains_point(line_obj.p2_)
    GeometryEntity::Ray(ray_obj) =>
      self.contains_point(ray_obj.p1_) && self.contains_point(ray_obj.p2_)
    GeometryEntity::Segment(seg_obj) =>
      self.contains_point(seg_obj.p1_) && self.contains_point(seg_obj.p2_)
    GeometryEntity::Plane(plane_obj) =>
      self.contains_point(plane_obj.point_) &&
      geo_all_zero(geo_cross3(self.normal_, plane_obj.normal_))
    _ => false
  }
}

///|
pub fn Plane::distance(
  self : Plane,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let pt = other.with_dim(3)
  geo_div(
    @symelem.abs(
      geo_dot(self.normal_, geo_sub_coords(pt.coords_, self.point_.coords_)),
    ),
    geo_norm(self.normal_),
  )
}

///|
pub fn Plane::projection(
  self : Plane,
  other : Point,
) -> Point raise GeometryError {
  let pt = other.with_dim(3)
  let offset = geo_div(
    geo_dot(self.normal_, geo_sub_coords(pt.coords_, self.point_.coords_)),
    geo_norm_sq(self.normal_),
  )
  point(
    [
      geo_simplify(pt.coords_[0] - offset * self.normal_[0]),
      geo_simplify(pt.coords_[1] - offset * self.normal_[1]),
      geo_simplify(pt.coords_[2] - offset * self.normal_[2]),
    ],
    dim=3,
  )
}

///|
pub fn Plane::translate(
  self : Plane,
  offsets : Array[@symcore.Expr],
) -> Plane raise GeometryError {
  plane_from_normal(self.point_.translate(offsets), self.normal_)
}

///|
pub fn Plane::scale(
  self : Plane,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Plane raise GeometryError {
  let moved = self.point_.scale(factors, pt~)
  let scaled_normal = [
    geo_div(self.normal_[0], factors[0]),
    geo_div(self.normal_[1], factors[1]),
    geo_div(self.normal_[2], factors[2]),
  ]
  plane_from_normal(moved.with_dim(3), scaled_normal)
}

///|
pub fn Plane::intersection(
  self : Plane,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) =>
      if self.contains_point(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(3))]
      } else {
        []
      }
    GeometryEntity::Line(line_obj) =>
      plane_intersection_linear(self, GeometryEntity::Line(line_obj))
    GeometryEntity::Ray(ray_obj) =>
      plane_intersection_linear(self, GeometryEntity::Ray(ray_obj))
    GeometryEntity::Segment(seg_obj) =>
      plane_intersection_linear(self, GeometryEntity::Segment(seg_obj))
    GeometryEntity::Plane(plane_obj) =>
      plane_intersection_plane(self, plane_obj)
    _ => []
  }
}

///|
fn plane_intersection_linear(
  plane_obj : Plane,
  entity : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  let p1 = linear_p1(entity).with_dim(3)
  let direction = linear_direction_coords(entity)
  let denom = geo_dot(plane_obj.normal_, direction)
  let numer = geo_dot(
    plane_obj.normal_,
    geo_sub_coords(plane_obj.point_.coords_, p1.coords_),
  )
  if geo_expr_is_zero(denom) {
    if plane_obj.contains(entity) {
      return [entity]
    }
    return []
  }
  let t = geo_div(numer, denom)
  if !linear_param_ok(linear_kind(entity), t) {
    return []
  }
  [GeometryEntity::Point(linear_point_at(entity, t))]
}

///|
fn plane_intersection_plane(
  lhs : Plane,
  rhs : Plane,
) -> Array[GeometryEntity] raise GeometryError {
  let direction = geo_cross3(lhs.normal_, rhs.normal_)
  if geo_all_zero(direction) {
    if lhs.contains_point(rhs.point_) {
      return [GeometryEntity::Plane(lhs)]
    }
    return []
  }
  let abs_dir = [
    @symelem.abs(direction[0]),
    @symelem.abs(direction[1]),
    @symelem.abs(direction[2]),
  ]
  let fixed_idx = match geo_dominant_index(abs_dir) {
    Some(idx) => idx
    None => 2
  }
  let vars = match fixed_idx {
    0 => (1, 2)
    1 => (0, 2)
    _ => (0, 1)
  }
  let c1 = geo_dot(lhs.normal_, lhs.point_.coords_)
  let c2 = geo_dot(rhs.normal_, rhs.point_.coords_)
  let det = geo_pair_determinant(lhs.normal_, rhs.normal_, vars.0, vars.1)
  let coord_a = geo_div(
    c1 * rhs.normal_[vars.1] - c2 * lhs.normal_[vars.1],
    det,
  )
  let coord_b = geo_div(
    lhs.normal_[vars.0] * c2 - rhs.normal_[vars.0] * c1,
    det,
  )
  let point_coords = [geo_zero(), geo_zero(), geo_zero()]
  point_coords[vars.0] = coord_a
  point_coords[vars.1] = coord_b
  point_coords[fixed_idx] = geo_zero()
  let pt = point(point_coords, dim=3)
  let next_pt = point(geo_add_coords(pt.coords_, direction), dim=3)
  [GeometryEntity::Line(line(pt, next_pt))]
}
