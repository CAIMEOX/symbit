///|
/// A point in Euclidean space.
pub struct Point {
  coords_ : Array[@symcore.Expr]
} derive(Eq)

///|
pub impl Add for Point with add(self, other : Point) {
  let normalized = try! geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_point_from_coords(geo_add_coords(lhs.coords_, rhs.coords_))
}

///|
pub impl Sub for Point with sub(self, other : Point) {
  let normalized = try! geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_point_from_coords(geo_sub_coords(lhs.coords_, rhs.coords_))
}

///|
pub fn point(
  coords : Array[@symcore.Expr],
  dim? : Int = -1,
) -> Point raise GeometryError {
  let actual_dim = if dim > 0 { dim } else { coords.length() }
  if actual_dim < 2 {
    raise GeometryError::ValueError("Point requires at least two coordinates")
  }
  if coords.length() > actual_dim {
    for item in coords[actual_dim:] {
      if !geo_expr_is_zero(item) {
        raise GeometryError::ValueError("nonzero coordinates cannot be removed")
      }
    }
  }
  let out : Array[@symcore.Expr] = []
  for i in 0..<actual_dim {
    let value = if i < coords.length() { coords[i] } else { geo_zero() }
    out.push(geo_simplify(value))
  }
  Point::{ coords_: out }
}

///|
pub fn point2d(
  x : @symcore.Expr,
  y : @symcore.Expr,
) -> Point raise GeometryError {
  point([x, y], dim=2)
}

///|
pub fn point3d(
  x : @symcore.Expr,
  y : @symcore.Expr,
  z : @symcore.Expr,
) -> Point raise GeometryError {
  point([x, y, z], dim=3)
}

///|
pub fn point_origin(dim : Int) -> Point raise GeometryError {
  point(geo_zero_coords(dim), dim~)
}

///|
pub fn Point::ambient_dimension(self : Point) -> Int {
  self.coords_.length()
}

///|
pub fn Point::len(self : Point) -> Int {
  self.coords_.length()
}

///|
pub fn Point::coords(self : Point) -> Array[@symcore.Expr] {
  geo_clone_exprs(self.coords_)
}

///|
pub fn Point::with_dim(self : Point, dim : Int) -> Point raise GeometryError {
  point(self.coords_, dim~)
}

///|
pub fn Point::get(
  self : Point,
  index : Int,
) -> @symcore.Expr raise GeometryError {
  if index < 0 || index >= self.coords_.length() {
    raise GeometryError::ValueError("point coordinate index out of range")
  }
  self.coords_[index]
}

///|
pub fn Point::x(self : Point) -> @symcore.Expr raise GeometryError {
  self.get(0)
}

///|
pub fn Point::y(self : Point) -> @symcore.Expr raise GeometryError {
  self.get(1)
}

///|
pub fn Point::z(self : Point) -> @symcore.Expr raise GeometryError {
  if self.coords_.length() < 3 {
    raise GeometryError::ValueError("Point has no z coordinate")
  }
  self.coords_[2]
}

///|
pub fn Point::repr(self : Point) -> String {
  geo_point_name(self.ambient_dimension()) +
  "(" +
  geo_render_exprs(self.coords_) +
  ")"
}

///|
pub fn Point::translate(
  self : Point,
  offsets : Array[@symcore.Expr],
) -> Point raise GeometryError {
  if offsets.length() != self.coords_.length() {
    raise GeometryError::ValueError(
      "translation offsets must match point dimension",
    )
  }
  geo_point_from_coords(geo_add_coords(self.coords_, offsets))
}

///|
pub fn Point::scale(
  self : Point,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Point raise GeometryError {
  if factors.length() != self.coords_.length() {
    raise GeometryError::ValueError("scale factors must match point dimension")
  }
  let origin = match pt {
    Some(value) => value.with_dim(self.ambient_dimension())
    None => point_origin(self.ambient_dimension())
  }
  let shifted = geo_sub_coords(self.coords_, origin.coords_)
  origin + geo_point_from_coords(geo_scale_coords_axis(shifted, factors))
}

///|
pub fn Point::rotate(
  self : Point,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Point raise GeometryError {
  let pivot = match pt {
    Some(value) => value.with_dim(self.ambient_dimension())
    None => point_origin(self.ambient_dimension())
  }
  geo_point_from_coords(
    geo_rotate_coords_2d(self.coords_, angle, pivot.coords_),
  )
}

///|
pub fn Point::distance(
  self : Point,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_norm(geo_sub_coords(lhs.coords_, rhs.coords_))
}

///|
pub fn Point::midpoint(
  self : Point,
  other : Point,
) -> Point raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_point_from_coords(geo_midpoint_coords(lhs.coords_, rhs.coords_))
}

///|
pub fn Point::dot(
  self : Point,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_dot(lhs.coords_, rhs.coords_)
}

///|
pub fn Point::abs(self : Point) -> @symcore.Expr raise GeometryError {
  self.distance(try! point_origin(self.ambient_dimension()))
}

///|
pub fn Point::mul(self : Point, factor : @symcore.Expr) -> Point {
  geo_point_from_coords(geo_scale_coords(self.coords_, factor))
}

///|
pub fn Point::truediv(self : Point, divisor : @symcore.Expr) -> Point {
  self.mul(geo_div(geo_one(), divisor))
}

///|
pub fn Point::subs(self : Point, env : Map[String, @symcore.Expr]) -> Point {
  let out : Array[@symcore.Expr] = []
  for coord in self.coords_ {
    out.push(@symcore.subst(coord, env))
  }
  geo_point_from_coords(out)
}

///|
pub fn Point::is_zero(self : Point) -> Bool {
  geo_all_zero(self.coords_)
}

///|
pub fn Point::is_collinear(
  self : Point,
  others : Array[Point],
) -> Bool raise GeometryError {
  let items : Array[Point] = [self]
  for item in others {
    items.push(item)
  }
  let points = geo_normalize_dim(items)
  point_are_collinear(points)
}

///|
pub fn point_are_collinear(points : Array[Point]) -> Bool raise GeometryError {
  if points.length() < 3 {
    return true
  }
  let normalized = geo_normalize_dim(points)
  let anchor = normalized[0]
  let mut base : Array[@symcore.Expr]? = None
  for item in normalized[1:] {
    let diff = geo_sub_coords(item.coords_, anchor.coords_)
    if geo_all_zero(diff) {
      continue
    }
    match base {
      Some(direction) =>
        if anchor.ambient_dimension() == 2 {
          if !geo_expr_is_zero(geo_cross2(direction, diff)) {
            return false
          }
        } else if anchor.ambient_dimension() == 3 {
          if !geo_all_zero(geo_cross3(direction, diff)) {
            return false
          }
        } else {
          let pivot = match geo_dominant_index(direction) {
            Some(idx) => idx
            None => continue
          }
          let scalar = geo_div(diff[pivot], direction[pivot])
          for i in 0..<direction.length() {
            if !geo_expr_is_zero(diff[i] - scalar * direction[i]) {
              return false
            }
          }
        }
      None => base = Some(diff)
    }
  }
  true
}

///|
pub fn point_are_coplanar(points : Array[Point]) -> Bool raise GeometryError {
  if points.length() < 4 {
    return true
  }
  let normalized = geo_normalize_dim(points)
  let dim = normalized[0].ambient_dimension()
  if dim <= 2 {
    return true
  }
  if dim != 3 {
    raise GeometryError::ValueError(
      "coplanarity is only implemented for 2D/3D points",
    )
  }
  let p0 = normalized[0]
  let mut u : Array[@symcore.Expr]? = None
  let mut v : Array[@symcore.Expr]? = None
  for item in normalized[1:] {
    let diff = geo_sub_coords(item.coords_, p0.coords_)
    if geo_all_zero(diff) {
      continue
    }
    match u {
      None => u = Some(diff)
      Some(first) =>
        if geo_all_zero(geo_cross3(first, diff)) {
          ()
        } else {
          v = Some(diff)
          break
        }
    }
  }
  match (u, v) {
    (_, None) => true
    (Some(first), Some(second)) => {
      let normal = geo_cross3(first, second)
      for item in normalized[1:] {
        let diff = geo_sub_coords(item.coords_, p0.coords_)
        if !geo_expr_is_zero(geo_dot(normal, diff)) {
          return false
        }
      }
      true
    }
    _ => true
  }
}
