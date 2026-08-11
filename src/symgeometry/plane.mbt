///|
/// A plane in 3-dimensional Euclidean space.
pub struct Plane {
  point_ : Point
  normal_ : Array[Expr]
} derive(Eq)

///|
pub fn plane_from_normal(
  point_value : Point,
  normal_vector : Array[Expr],
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
pub fn Plane::ambient_dimension(self : Plane) -> Int {
  let _ = self
  3
}

///|
pub fn Plane::normal_vector(self : Plane) -> Array[Expr] {
  geo_clone_exprs(self.normal_)
}

///|
pub fn Plane::repr(self : Plane) -> String {
  "Plane(" + self.point_.repr() + ", " + geo_render_tuple(self.normal_) + ")"
}

///|
fn plane_basis_vectors(plane_obj : Plane) -> (Array[Expr], Array[Expr]) {
  let x = plane_obj.normal_[0]
  let y = plane_obj.normal_[1]
  let z = plane_obj.normal_[2]
  let basis1 = if geo_expr_is_zero(x) && geo_expr_is_zero(y) {
    [int(1), int(0), int(0)]
  } else {
    [int(0) - y, x, int(0)]
  }
  let basis2 = geo_cross3([x, y, z], basis1)
  (basis1, basis2)
}

///|
fn plane_point_with_basis(
  base : Point,
  basis1 : Array[Expr],
  basis2 : Array[Expr],
  u : Expr,
  v : Expr,
) -> Point raise GeometryError {
  point(
    [
      geo_simplify(base.coords_[0] + basis1[0] * u + basis2[0] * v),
      geo_simplify(base.coords_[1] + basis1[1] * u + basis2[1] * v),
      geo_simplify(base.coords_[2] + basis1[2] * u + basis2[2] * v),
    ],
    dim=3,
  )
}

///|
fn plane_basis_coeffs(plane_obj : Plane, target : Point) -> (Expr, Expr)? {
  let delta = geo_sub_coords(target.coords_, plane_obj.point_.coords_)
  let (basis1, basis2) = plane_basis_vectors(plane_obj)
  let pairs = [(0, 1), (0, 2), (1, 2)]
  for pair in pairs {
    let det = geo_pair_determinant(basis1, basis2, pair.0, pair.1)
    if geo_expr_is_zero(det) {
      continue
    }
    let u_value = geo_div(
      delta[pair.0] * basis2[pair.1] - delta[pair.1] * basis2[pair.0],
      det,
    )
    let v_value = geo_div(
      basis1[pair.0] * delta[pair.1] - basis1[pair.1] * delta[pair.0],
      det,
    )
    let candidate = plane_point_with_basis(
      plane_obj.point_,
      basis1,
      basis2,
      u_value,
      v_value,
    ) catch {
      _ => continue
    }
    if candidate.equals(target) {
      return Some((geo_simplify(u_value), geo_simplify(v_value)))
    }
  }
  None
}

///|
pub fn Plane::equation(
  self : Plane,
  x? : Expr = Expr::Symbol("x"),
  y? : Expr = Expr::Symbol("y"),
  z? : Expr = Expr::Symbol("z"),
) -> Expr {
  geo_simplify(
    self.normal_[0] * (x - self.point_.coords_[0]) +
    self.normal_[1] * (y - self.point_.coords_[1]) +
    self.normal_[2] * (z - self.point_.coords_[2]),
  )
}

///|
pub fn Plane::arbitrary_point(
  self : Plane,
  u? : Expr? = None,
  v? : Expr? = None,
) -> Point raise GeometryError {
  let (basis1, basis2) = plane_basis_vectors(self)
  match v {
    Some(vsym) => {
      let usym = match u {
        Some(value) => value
        None => Expr::Symbol("u")
      }
      plane_point_with_basis(self.point_, basis1, basis2, usym, vsym)
    }
    None => {
      let tsym = match u {
        Some(value) => value
        None => Expr::Symbol("t")
      }
      let norm1 = geo_norm(basis1)
      let norm2 = geo_norm(basis2)
      point(
        [
          geo_simplify(
            self.point_.coords_[0] +
            geo_div(basis1[0], norm1) * @symelem.cos(tsym) +
            geo_div(basis2[0], norm2) * @symelem.sin(tsym),
          ),
          geo_simplify(
            self.point_.coords_[1] +
            geo_div(basis1[1], norm1) * @symelem.cos(tsym) +
            geo_div(basis2[1], norm2) * @symelem.sin(tsym),
          ),
          geo_simplify(
            self.point_.coords_[2] +
            geo_div(basis1[2], norm1) * @symelem.cos(tsym) +
            geo_div(basis2[2], norm2) * @symelem.sin(tsym),
          ),
        ],
        dim=3,
      )
    }
  }
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
pub fn Plane::distance(self : Plane, other : Point) -> Expr raise GeometryError {
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
  offsets : Array[Expr],
) -> Plane raise GeometryError {
  plane_from_normal(self.point_.translate(offsets), self.normal_)
}

///|
pub fn Plane::scale(
  self : Plane,
  factors : Array[Expr],
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
pub fn Plane::equals(
  self : Plane,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Plane(plane_obj) =>
      self.contains_point(plane_obj.point_) &&
      geo_all_zero(geo_cross3(self.normal_, plane_obj.normal_))
    _ => false
  }
}

///|
pub fn Plane::angle_between(
  self : Plane,
  other : GeometryEntity,
) -> Expr raise GeometryError {
  match other {
    GeometryEntity::Line(line_obj) =>
      @symelem.asin(
        geo_div(
          geo_dot(self.normal_, line_obj.direction().with_dim(3).coords()),
          geo_norm(self.normal_) *
          geo_norm(line_obj.direction().with_dim(3).coords()),
        ),
      )
    GeometryEntity::Ray(ray_obj) =>
      @symelem.asin(
        geo_div(
          geo_dot(self.normal_, ray_obj.direction().with_dim(3).coords()),
          geo_norm(self.normal_) *
          geo_norm(ray_obj.direction().with_dim(3).coords()),
        ),
      )
    GeometryEntity::Segment(seg_obj) =>
      @symelem.asin(
        geo_div(
          geo_dot(self.normal_, seg_obj.direction().with_dim(3).coords()),
          geo_norm(self.normal_) *
          geo_norm(seg_obj.direction().with_dim(3).coords()),
        ),
      )
    GeometryEntity::Plane(plane_obj) =>
      @symelem.acos(
        geo_div(
          geo_dot(self.normal_, plane_obj.normal_),
          geo_norm(self.normal_) * geo_norm(plane_obj.normal_),
        ),
      )
    _ =>
      raise GeometryError::TypeError(
        "angle_between expects a plane or linear entity",
      )
  }
}

///|
pub fn Plane::is_parallel(
  self : Plane,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(line_obj) => {
      let direction = line_obj.direction().with_dim(3).coords()
      geo_expr_is_zero(geo_dot(self.normal_, direction))
    }
    GeometryEntity::Ray(ray_obj) => {
      let direction = ray_obj.direction().with_dim(3).coords()
      geo_expr_is_zero(geo_dot(self.normal_, direction))
    }
    GeometryEntity::Segment(seg_obj) => {
      let direction = seg_obj.direction().with_dim(3).coords()
      geo_expr_is_zero(geo_dot(self.normal_, direction))
    }
    GeometryEntity::Plane(plane_obj) =>
      geo_all_zero(geo_cross3(self.normal_, plane_obj.normal_))
    _ => false
  }
}

///|
pub fn Plane::is_perpendicular(
  self : Plane,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(line_obj) => {
      let direction = line_obj.direction().with_dim(3).coords()
      geo_all_zero(geo_cross3(self.normal_, direction))
    }
    GeometryEntity::Ray(ray_obj) => {
      let direction = ray_obj.direction().with_dim(3).coords()
      geo_all_zero(geo_cross3(self.normal_, direction))
    }
    GeometryEntity::Segment(seg_obj) => {
      let direction = seg_obj.direction().with_dim(3).coords()
      geo_all_zero(geo_cross3(self.normal_, direction))
    }
    GeometryEntity::Plane(plane_obj) =>
      geo_expr_is_zero(geo_dot(self.normal_, plane_obj.normal_))
    _ => false
  }
}

///|
pub fn Plane::parallel_plane(
  self : Plane,
  pt : Point,
) -> Plane raise GeometryError {
  plane_from_normal(pt.with_dim(3), self.normal_)
}

///|
pub fn Plane::perpendicular_line(
  self : Plane,
  pt : Point,
) -> Line raise GeometryError {
  let p1 = pt.with_dim(3)
  let p2 = point(geo_add_coords(p1.coords_, self.normal_), dim=3)
  line(p1, p2)
}

///|
pub fn Plane::perpendicular_plane(
  self : Plane,
  pts? : Array[Point] = [],
) -> Plane raise GeometryError {
  if pts.length() > 2 {
    raise GeometryError::ValueError("no more than 2 points should be provided")
  }
  let items : Array[Point] = []
  for item in pts {
    items.push(item.with_dim(3))
  }
  if items.is_empty() {
    items.push(self.point_)
  }
  if items.length() == 1 {
    let dir = if geo_expr_is_zero(self.normal_[0]) &&
      geo_expr_is_zero(self.normal_[1]) {
      [int(0), int(1), int(0)]
    } else {
      [int(0), int(0), int(1)]
    }
    items.push(point(geo_add_coords(items[0].coords_, dir), dim=3))
  }
  let p1 = items[0]
  let p2 = items[1]
  let candidate_line = line(p1, p2)
  let along_normal = self.perpendicular_line(p1)
  let p3 = if along_normal.contains(p2) {
    let mut axis_point = if geo_expr_is_zero(self.normal_[0]) &&
      geo_expr_is_zero(self.normal_[1]) {
      point3d(int(0), int(1), int(0))
    } else {
      point3d(int(0), int(0), int(1))
    }
    if candidate_line.contains(axis_point) {
      axis_point = axis_point.mul(geo_int(2))
    }
    axis_point
  } else {
    point(geo_add_coords(p1.coords_, self.normal_), dim=3)
  }
  plane_from_points(p1, p2, p3)
}

///|
pub fn Plane::projection_line(
  self : Plane,
  other : GeometryEntity,
) -> GeometryEntity raise GeometryError {
  match other {
    GeometryEntity::Line(line_obj) => {
      let a = self.projection(line_obj.p1_)
      let b = self.projection(line_obj.p2_)
      if a.equals(b) {
        geometry_point(a)
      } else {
        geometry_line(line(a, b))
      }
    }
    GeometryEntity::Ray(ray_obj) => {
      let a = self.projection(ray_obj.p1_)
      let b = self.projection(ray_obj.p2_)
      if a.equals(b) {
        geometry_point(a)
      } else {
        geometry_ray(ray(a, b))
      }
    }
    GeometryEntity::Segment(seg_obj) => {
      let a = self.projection(seg_obj.p1_)
      let b = self.projection(seg_obj.p2_)
      if a.equals(b) {
        geometry_point(a)
      } else {
        geometry_segment(segment(a, b))
      }
    }
    _ =>
      raise GeometryError::TypeError("projection_line expects a linear entity")
  }
}

///|
pub fn Plane::parameter_value(
  self : Plane,
  other : Point,
  u : Expr,
  v? : Expr? = None,
) -> Map[Expr, Expr] raise GeometryError {
  let target = other.with_dim(3)
  let out : Map[Expr, Expr] = Map([])
  match v {
    None => {
      let delta = geo_sub_coords(target.coords_, self.point_.coords_)
      if geo_all_zero(delta) {
        out.set(u, int(0))
        return out
      }
      let (basis1, basis2) = plane_basis_vectors(self)
      match plane_basis_coeffs(self, target) {
        Some((u_value, v_value)) => {
          let alpha = geo_simplify(u_value * geo_norm(basis1))
          let beta = geo_simplify(v_value * geo_norm(basis2))
          out.set(u, geo_normalized_atan2(beta, alpha))
          out
        }
        None => raise GeometryError::ValueError("given point is not on plane")
      }
    }
    Some(vsym) =>
      match plane_basis_coeffs(self, target) {
        Some((u_value, v_value)) => {
          out.set(u, u_value)
          out.set(vsym, v_value)
          return out
        }
        None => raise GeometryError::ValueError("given point is not on plane")
      }
  }
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
  let point_coords = [int(0), int(0), int(0)]
  point_coords[vars.0] = coord_a
  point_coords[vars.1] = coord_b
  point_coords[fixed_idx] = int(0)
  let pt = point(point_coords, dim=3)
  let next_pt = point(geo_add_coords(pt.coords_, direction), dim=3)
  [GeometryEntity::Line(line(pt, next_pt))]
}
