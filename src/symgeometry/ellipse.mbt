///|
/// Axis-aligned ellipse in the plane.
pub struct Ellipse {
  center_ : Point
  hradius_ : @symcore.Expr
  vradius_ : @symcore.Expr
} derive(Eq)

///|
/// Circle as the equal-radius specialization of `Ellipse`.
pub struct Circle {
  center_ : Point
  radius_ : @symcore.Expr
} derive(Eq)

///|
fn ellipse_major_on_x(hr : @symcore.Expr, vr : @symcore.Expr) -> Bool {
  match geo_expr_sign(hr * hr - vr * vr) {
    Some(sign) => sign >= 0
    None => true
  }
}

///|
fn ellipse_focus_distance_expr(
  hr : @symcore.Expr,
  vr : @symcore.Expr,
) -> @symcore.Expr {
  if ellipse_major_on_x(hr, vr) {
    @symelem.sqrt(hr * hr - vr * vr)
  } else {
    @symelem.sqrt(vr * vr - hr * hr)
  }
}

///|
fn quadratic_roots(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  if geo_expr_is_zero(a) {
    if geo_expr_is_zero(b) {
      return out
    }
    out.push(geo_div(geo_zero() - c, b))
    return out
  }
  let disc = geo_simplify(b * b - geo_int(4) * a * c)
  let two_a = geo_simplify(geo_int(2) * a)
  let neg_b = geo_zero() - b
  if geo_expr_is_zero(disc) {
    out.push(geo_div(neg_b, two_a))
    return out
  }
  let sqrt_disc = @symelem.sqrt(disc)
  out.push(geo_div(neg_b + sqrt_disc, two_a))
  out.push(geo_div(neg_b - sqrt_disc, two_a))
  out
}

///|
fn unique_push_point(points : Array[Point], pt : Point) -> Unit {
  for item in points {
    if item == pt {
      return
    }
  }
  points.push(pt)
}

///|
fn conic_points_from_linear_entity(
  entity : GeometryEntity,
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
) -> Array[GeometryEntity] raise GeometryError {
  let out : Array[GeometryEntity] = []
  for root in quadratic_roots(a, b, c) {
    let ok = linear_param_ok(linear_kind(entity), root) catch {
      GeometryError::Undecidable(_) => false
      e => raise e
    }
    if !ok {
      continue
    }
    let pt = linear_point_at(entity, root)
    let mut seen = false
    for item in out {
      match item {
        GeometryEntity::Point(prev) if prev == pt => seen = true
        _ => ()
      }
    }
    if !seen {
      out.push(geometry_point(pt))
    }
  }
  out
}

///|
pub fn ellipse(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
) -> GeometryEntity raise GeometryError {
  let center = center.with_dim(2)
  if geo_expr_is_zero(hradius) || geo_expr_is_zero(vradius) {
    return geometry_segment(
      segment(
        try! point2d(center.coords_[0] - hradius, center.coords_[1] - vradius),
        try! point2d(center.coords_[0] + hradius, center.coords_[1] + vradius),
      ),
    )
  }
  if geo_expr_eq(hradius, vradius) {
    return geometry_circle(Circle::{
      center_: center,
      radius_: geo_simplify(hradius),
    })
  }
  geometry_ellipse(Ellipse::{
    center_: center,
    hradius_: geo_simplify(hradius),
    vradius_: geo_simplify(vradius),
  })
}

///|
pub fn circle(
  center : Point,
  radius : @symcore.Expr,
) -> Circle raise GeometryError {
  let center = center.with_dim(2)
  if geo_expr_is_zero(radius) {
    raise GeometryError::ValueError("circle radius must be nonzero")
  }
  Circle::{ center_: center, radius_: geo_simplify(radius) }
}

///|
pub fn Ellipse::center(self : Ellipse) -> Point {
  self.center_
}

///|
pub fn Ellipse::hradius(self : Ellipse) -> @symcore.Expr {
  self.hradius_
}

///|
pub fn Ellipse::vradius(self : Ellipse) -> @symcore.Expr {
  self.vradius_
}

///|
pub fn Ellipse::ambient_dimension(self : Ellipse) -> Int {
  2
}

///|
pub fn Ellipse::repr(self : Ellipse) -> String {
  "Ellipse(" +
  self.center_.repr() +
  ", " +
  geo_expr_text(self.hradius_) +
  ", " +
  geo_expr_text(self.vradius_) +
  ")"
}

///|
pub fn Ellipse::area(self : Ellipse) -> @symcore.Expr {
  geo_simplify(@symcore.symbol("pi") * self.hradius_ * self.vradius_)
}

///|
pub fn Ellipse::eccentricity(self : Ellipse) -> @symcore.Expr {
  if ellipse_major_on_x(self.hradius_, self.vradius_) {
    geo_div(
      ellipse_focus_distance_expr(self.hradius_, self.vradius_),
      self.hradius_,
    )
  } else {
    geo_div(
      ellipse_focus_distance_expr(self.hradius_, self.vradius_),
      self.vradius_,
    )
  }
}

///|
pub fn Ellipse::focus_distance(self : Ellipse) -> @symcore.Expr {
  ellipse_focus_distance_expr(self.hradius_, self.vradius_)
}

///|
pub fn Ellipse::foci(self : Ellipse) -> Array[Point] raise GeometryError {
  let fd = self.focus_distance()
  if ellipse_major_on_x(self.hradius_, self.vradius_) {
    [
      try! point2d(self.center_.coords_[0] - fd, self.center_.coords_[1]),
      try! point2d(self.center_.coords_[0] + fd, self.center_.coords_[1]),
    ]
  } else {
    [
      try! point2d(self.center_.coords_[0], self.center_.coords_[1] - fd),
      try! point2d(self.center_.coords_[0], self.center_.coords_[1] + fd),
    ]
  }
}

///|
pub fn Ellipse::equation(
  self : Ellipse,
  x? : @symcore.Expr = @symcore.symbol("x"),
  y? : @symcore.Expr = @symcore.symbol("y"),
) -> @symcore.Expr {
  geo_simplify(
    geo_div(
      (x - self.center_.coords_[0]) ^ geo_int(2),
      self.hradius_ ^ geo_int(2),
    ) +
    geo_div(
      (y - self.center_.coords_[1]) ^ geo_int(2),
      self.vradius_ ^ geo_int(2),
    ) -
    geo_one(),
  )
}

///|
pub fn Ellipse::arbitrary_point(
  self : Ellipse,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Point raise GeometryError {
  point2d(
    geo_simplify(
      self.center_.coords_[0] + self.hradius_ * @symelem.cos(parameter),
    ),
    geo_simplify(
      self.center_.coords_[1] + self.vradius_ * @symelem.sin(parameter),
    ),
  )
}

///|
pub fn Ellipse::contains_point(
  self : Ellipse,
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  geo_expr_is_zero(self.equation(x=pt.coords_[0], y=pt.coords_[1]))
}

///|
pub fn Ellipse::translate(
  self : Ellipse,
  offsets : Array[@symcore.Expr],
) -> Ellipse raise GeometryError {
  Ellipse::{
    center_: self.center_.translate(offsets),
    hradius_: self.hradius_,
    vradius_: self.vradius_,
  }
}

///|
pub fn Ellipse::scale(
  self : Ellipse,
  x : @symcore.Expr,
  y? : @symcore.Expr = geo_one(),
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  let factors = [x, y]
  let center = self.center_.scale(factors, pt~)
  ellipse(
    center,
    geo_simplify(self.hradius_ * x),
    geo_simplify(self.vradius_ * y),
  )
}

///|
pub fn Ellipse::rotate(
  self : Ellipse,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  let center = self.center_.rotate(angle, pt~)
  let pi = @symcore.symbol("pi")
  let half_pi = geo_div(pi, geo_int(2))
  if geo_expr_is_zero(angle) ||
    geo_expr_eq(angle, pi) ||
    geo_expr_eq(angle, geo_zero() - pi) {
    return ellipse(center, self.hradius_, self.vradius_)
  }
  if geo_expr_eq(angle, half_pi) || geo_expr_eq(angle, geo_zero() - half_pi) {
    return ellipse(center, self.vradius_, self.hradius_)
  }
  raise GeometryError::ValueError(
    "only rotations by multiples of pi/2 are currently supported for Ellipse",
  )
}

///|
pub fn Ellipse::intersection(
  self : Ellipse,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) =>
      if self.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => {
      let p1 = linear_p1(other).with_dim(2)
      let d = linear_direction_coords(other)
      let dx = d[0]
      let dy = d[1]
      let x0 = p1.coords_[0] - self.center_.coords_[0]
      let y0 = p1.coords_[1] - self.center_.coords_[1]
      let h2 = self.hradius_ ^ geo_int(2)
      let v2 = self.vradius_ ^ geo_int(2)
      let qa = geo_div(dx * dx, h2) + geo_div(dy * dy, v2)
      let qb = geo_int(2) * (geo_div(x0 * dx, h2) + geo_div(y0 * dy, v2))
      let qc = geo_div(x0 * x0, h2) + geo_div(y0 * y0, v2) - geo_one()
      conic_points_from_linear_entity(other, qa, qb, qc)
    }
    GeometryEntity::Circle(_) => []
    GeometryEntity::Ellipse(ellipse_obj) =>
      if self == ellipse_obj {
        [geometry_ellipse(self)]
      } else {
        []
      }
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj.intersection(geometry_ellipse(self))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.intersection(geometry_ellipse(self))
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj.intersection(geometry_ellipse(self))
    _ => []
  }
}

///|
pub fn Circle::center(self : Circle) -> Point {
  self.center_
}

///|
pub fn Circle::radius(self : Circle) -> @symcore.Expr {
  self.radius_
}

///|
pub fn Circle::ambient_dimension(self : Circle) -> Int {
  2
}

///|
pub fn Circle::repr(self : Circle) -> String {
  "Circle(" + self.center_.repr() + ", " + geo_expr_text(self.radius_) + ")"
}

///|
pub fn Circle::area(self : Circle) -> @symcore.Expr {
  geo_simplify(@symcore.symbol("pi") * self.radius_ * self.radius_)
}

///|
pub fn Circle::circumference(self : Circle) -> @symcore.Expr {
  geo_simplify(geo_int(2) * @symcore.symbol("pi") * self.radius_)
}

///|
pub fn Circle::equation(
  self : Circle,
  x? : @symcore.Expr = @symcore.symbol("x"),
  y? : @symcore.Expr = @symcore.symbol("y"),
) -> @symcore.Expr {
  geo_simplify(
    ((x - self.center_.coords_[0]) ^ geo_int(2)) +
    ((y - self.center_.coords_[1]) ^ geo_int(2)) -
    (self.radius_ ^ geo_int(2)),
  )
}

///|
pub fn Circle::arbitrary_point(
  self : Circle,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Point raise GeometryError {
  point2d(
    geo_simplify(
      self.center_.coords_[0] + self.radius_ * @symelem.cos(parameter),
    ),
    geo_simplify(
      self.center_.coords_[1] + self.radius_ * @symelem.sin(parameter),
    ),
  )
}

///|
pub fn Circle::contains_point(
  self : Circle,
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  geo_expr_is_zero(self.equation(x=pt.coords_[0], y=pt.coords_[1]))
}

///|
pub fn Circle::translate(
  self : Circle,
  offsets : Array[@symcore.Expr],
) -> Circle raise GeometryError {
  Circle::{ center_: self.center_.translate(offsets), radius_: self.radius_ }
}

///|
pub fn Circle::scale(
  self : Circle,
  x : @symcore.Expr,
  y? : @symcore.Expr = geo_one(),
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  let center = self.center_.scale([x, y], pt~)
  if geo_expr_eq(x, y) {
    return geometry_circle(Circle::{
      center_: center,
      radius_: geo_simplify(self.radius_ * x),
    })
  }
  ellipse(
    center,
    geo_simplify(self.radius_ * x),
    geo_simplify(self.radius_ * y),
  )
}

///|
pub fn Circle::rotate(
  self : Circle,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  geometry_circle(Circle::{
    center_: self.center_.rotate(angle, pt~),
    radius_: self.radius_,
  })
}

///|
fn circle_circle_intersection(
  lhs : Circle,
  rhs : Circle,
) -> Array[GeometryEntity] raise GeometryError {
  let c0 = lhs.center_
  let c1 = rhs.center_
  let dx = c1.coords_[0] - c0.coords_[0]
  let dy = c1.coords_[1] - c0.coords_[1]
  let d = c0.distance(c1)
  if geo_expr_is_zero(d) {
    if geo_expr_eq(lhs.radius_, rhs.radius_) {
      return [geometry_circle(lhs)]
    }
    return []
  }
  let a = geo_div(
    (lhs.radius_ ^ geo_int(2)) - (rhs.radius_ ^ geo_int(2)) + (d ^ geo_int(2)),
    geo_int(2) * d,
  )
  let h2 = geo_simplify((lhs.radius_ ^ geo_int(2)) - (a ^ geo_int(2)))
  let x2 = geo_simplify(c0.coords_[0] + geo_div(a * dx, d))
  let y2 = geo_simplify(c0.coords_[1] + geo_div(a * dy, d))
  if geo_expr_is_zero(h2) {
    return [geometry_point(try! point2d(x2, y2))]
  }
  let h = @symelem.sqrt(h2)
  let rx = geo_div(geo_zero() - dy * h, d)
  let ry = geo_div(dx * h, d)
  [
    geometry_point(try! point2d(x2 + rx, y2 + ry)),
    geometry_point(try! point2d(x2 - rx, y2 - ry)),
  ]
}

///|
pub fn Circle::intersection(
  self : Circle,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) =>
      if self.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => {
      let as_ellipse = Ellipse::{
        center_: self.center_,
        hradius_: self.radius_,
        vradius_: self.radius_,
      }
      as_ellipse.intersection(other)
    }
    GeometryEntity::Circle(circle_obj) =>
      circle_circle_intersection(self, circle_obj)
    GeometryEntity::Ellipse(_) => []
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj.intersection(geometry_circle(self))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.intersection(geometry_circle(self))
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj.intersection(geometry_circle(self))
    _ => []
  }
}
