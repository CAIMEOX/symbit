///|
/// A point in Euclidean space.
pub struct Point {
  coords_ : Array[Expr]
} derive(Eq, Hash)

///|
fn geo_point_eq(lhs : Point, rhs : Point) -> Bool {
  let normalized = geo_normalize_dim([lhs, rhs]) catch { _ => return false }
  let left = normalized[0]
  let right = normalized[1]
  for i in 0..<left.coords_.length() {
    if !geo_expr_eq(left.coords_[i], right.coords_[i]) {
      return false
    }
  }
  true
}

///|
pub impl Add for Point with add(self, other : Point) {
  let dim = if self.ambient_dimension() > other.ambient_dimension() {
    self.ambient_dimension()
  } else {
    other.ambient_dimension()
  }
  let lhs = self.with_dim(dim) catch { _ => self }
  let rhs = other.with_dim(dim) catch { _ => other }
  geo_point_from_coords(geo_add_coords(lhs.coords_, rhs.coords_))
}

///|
pub impl Sub for Point with sub(self, other : Point) {
  let dim = if self.ambient_dimension() > other.ambient_dimension() {
    self.ambient_dimension()
  } else {
    other.ambient_dimension()
  }
  let lhs = self.with_dim(dim) catch { _ => self }
  let rhs = other.with_dim(dim) catch { _ => other }
  geo_point_from_coords(geo_sub_coords(lhs.coords_, rhs.coords_))
}

///|
pub fn point(
  coords : Array[Expr],
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
  let out : Array[Expr] = []
  for i in 0..<actual_dim {
    let value = if i < coords.length() { coords[i] } else { geo_zero() }
    out.push(geo_simplify(value))
  }
  Point::{ coords_: out }
}

///|
pub fn point2d(x : Expr, y : Expr) -> Point raise GeometryError {
  point([x, y], dim=2)
}

///|
pub fn point3d(x : Expr, y : Expr, z : Expr) -> Point raise GeometryError {
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
pub fn Point::equals(self : Point, other : Point) -> Bool {
  if self.ambient_dimension() != other.ambient_dimension() {
    return false
  }
  for i in 0..<self.coords_.length() {
    if !geo_expr_eq(self.coords_[i], other.coords_[i]) {
      return false
    }
  }
  true
}

///|
pub fn Point::len(self : Point) -> Int {
  self.coords_.length()
}

///|
pub fn Point::length(self : Point) -> Int {
  self.coords_.length()
}

///|
pub fn Point::coords(self : Point) -> Array[Expr] {
  geo_clone_exprs(self.coords_)
}

///|
pub fn Point::with_dim(self : Point, dim : Int) -> Point raise GeometryError {
  point(self.coords_, dim~)
}

///|
pub fn Point::get(self : Point, index : Int) -> Expr raise GeometryError {
  if index < 0 || index >= self.coords_.length() {
    raise GeometryError::ValueError("point coordinate index out of range")
  }
  self.coords_[index]
}

///|
pub fn Point::x(self : Point) -> Expr raise GeometryError {
  self.get(0)
}

///|
pub fn Point::y(self : Point) -> Expr raise GeometryError {
  self.get(1)
}

///|
pub fn Point::z(self : Point) -> Expr raise GeometryError {
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
  offsets : Array[Expr],
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
  factors : Array[Expr],
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
  angle : Expr,
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
pub fn Point::distance(self : Point, other : Point) -> Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_norm(geo_sub_coords(lhs.coords_, rhs.coords_))
}

///|
pub fn Point::intersection(
  self : Point,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  intersection(geometry_point(self), other)
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
pub fn Point::dot(self : Point, other : Point) -> Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  geo_dot(lhs.coords_, rhs.coords_)
}

///|
pub fn Point::abs(self : Point) -> Expr raise GeometryError {
  self.distance(
    geo_point_from_coords(geo_zero_coords(self.ambient_dimension())),
  )
}

///|
pub fn Point::origin(self : Point) -> Point raise GeometryError {
  point_origin(self.ambient_dimension())
}

///|
pub fn Point::is_nonzero(self : Point) -> Bool {
  !self.is_zero()
}

///|
pub fn Point::mul(self : Point, factor : Expr) -> Point {
  geo_point_from_coords(geo_scale_coords(self.coords_, factor))
}

///|
pub fn Point::truediv(self : Point, divisor : Expr) -> Point {
  self.mul(geo_div(geo_one(), divisor))
}

///|
pub fn Point::subs(self : Point, env : Map[String, Expr]) -> Point {
  let out : Array[Expr] = []
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
pub fn Point::orthogonal_direction(self : Point) -> Point raise GeometryError {
  let dim = self.ambient_dimension()
  if geo_expr_is_zero(self.coords_[0]) {
    let coords = geo_zero_coords(dim)
    coords[0] = geo_one()
    return point(coords, dim~)
  }
  if geo_expr_is_zero(self.coords_[1]) {
    let coords = geo_zero_coords(dim)
    coords[1] = geo_one()
    return point(coords, dim~)
  }
  let coords = geo_zero_coords(dim)
  coords[0] = geo_zero() - self.coords_[1]
  coords[1] = self.coords_[0]
  point(coords, dim~)
}

///|
pub fn Point::project(self : Point, other : Point) -> Point raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  if rhs.is_zero() {
    raise GeometryError::ValueError("Cannot project to the zero vector.")
  }
  let scale = geo_div(lhs.dot(rhs), rhs.dot(rhs))
  rhs.mul(scale)
}

///|
pub fn Point::taxicab_distance(
  self : Point,
  other : Point,
) -> Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  let mut acc = geo_zero()
  for i in 0..<lhs.coords_.length() {
    acc = geo_simplify(acc + @symelem.abs(lhs.coords_[i] - rhs.coords_[i]))
  }
  acc
}

///|
pub fn Point::canberra_distance(
  self : Point,
  other : Point,
) -> Expr raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  if lhs.is_zero() && rhs.is_zero() {
    raise GeometryError::ValueError("Cannot project to the zero vector.")
  }
  let mut acc = geo_zero()
  for i in 0..<lhs.coords_.length() {
    let numer = @symelem.abs(lhs.coords_[i] - rhs.coords_[i])
    let denom = geo_simplify(
      @symelem.abs(lhs.coords_[i]) + @symelem.abs(rhs.coords_[i]),
    )
    acc = geo_simplify(acc + geo_div(numer, denom))
  }
  acc
}

///|
pub fn Point::unit(self : Point) -> Point raise GeometryError {
  self.truediv(self.abs())
}

///|
pub fn Point::is_scalar_multiple(
  self : Point,
  other : Point,
) -> Bool raise GeometryError {
  let normalized = geo_normalize_dim([self, other])
  let lhs = normalized[0]
  let rhs = normalized[1]
  if lhs.ambient_dimension() == 2 {
    return geo_expr_is_zero(
      lhs.coords_[0] * rhs.coords_[1] - rhs.coords_[0] * lhs.coords_[1],
    )
  }
  if lhs.ambient_dimension() == 3 {
    return geo_all_zero(geo_cross3(lhs.coords_, rhs.coords_))
  }
  let pivot = match geo_dominant_index(rhs.coords_) {
    Some(idx) => idx
    None => return lhs.is_zero()
  }
  let scale = geo_div(lhs.coords_[pivot], rhs.coords_[pivot])
  for i in 0..<lhs.coords_.length() {
    if !geo_expr_is_zero(lhs.coords_[i] - scale * rhs.coords_[i]) {
      return false
    }
  }
  true
}

///|
pub fn Point::is_concyclic(
  self : Point,
  others : Array[Point],
) -> Bool raise GeometryError {
  let points : Array[Point] = [self]
  for item in others {
    points.push(item)
  }
  let normalized = geo_normalize_dim(points)
  if normalized[0].ambient_dimension() != 2 {
    raise GeometryError::ValueError(
      "concyclic test is only implemented for planar points",
    )
  }
  let unique : Array[Point] = []
  for item in normalized {
    if !unique.any(fn(prev) { geo_point_eq(prev, item) }) {
      unique.push(item.with_dim(2))
    }
  }
  if unique.length() < 3 {
    return true
  }
  let mut seed : Triangle? = None
  for i in 0..<unique.length() {
    for j in (i + 1)..<unique.length() {
      for k in (j + 1)..<unique.length() {
        if !point_are_collinear([unique[i], unique[j], unique[k]]) {
          seed = Some(triangle(unique[i], unique[j], unique[k]))
          break
        }
      }
      if seed is Some(_) {
        break
      }
    }
    if seed is Some(_) {
      break
    }
  }
  match seed {
    None => false
    Some(tri) => {
      let circle_obj = tri.circumcircle()
      for item in unique {
        if !circle_obj.contains_point(item) {
          return false
        }
      }
      true
    }
  }
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
  let mut base : Array[Expr]? = None
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
  let mut u : Array[Expr]? = None
  let mut v : Array[Expr]? = None
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
