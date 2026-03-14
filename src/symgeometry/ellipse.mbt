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
    if geo_point_eq(item, pt) {
      return
    }
  }
  points.push(pt)
}

///|
fn ellipse_unit_coords(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  pt : Point,
) -> Array[@symcore.Expr] raise GeometryError {
  let pt = pt.with_dim(2)
  [
    geo_div(pt.coords_[0] - center.coords_[0], hradius),
    geo_div(pt.coords_[1] - center.coords_[1], vradius),
  ]
}

///|
fn ellipse_tangent_point_from_unit(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  unit_coords : Array[@symcore.Expr],
) -> Point raise GeometryError {
  point2d(
    geo_radsimp(center.coords_[0] + hradius * unit_coords[0]),
    geo_radsimp(center.coords_[1] + vradius * unit_coords[1]),
  )
}

///|
fn tangent_line_at_boundary_point(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  pt : Point,
) -> Line raise GeometryError {
  let pt = pt.with_dim(2)
  let normal = [
    geo_div(pt.coords_[0] - center.coords_[0], hradius ^ geo_int(2)),
    geo_div(pt.coords_[1] - center.coords_[1], vradius ^ geo_int(2)),
  ]
  let direction = try! geo_perp2(normal)
  let q = try! point2d(
    geo_simplify(pt.coords_[0] + direction[0]),
    geo_simplify(pt.coords_[1] + direction[1]),
  )
  line(pt, q)
}

///|
fn ellipse_tangent_lines_from_point(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  pt : Point,
) -> Array[Line] raise GeometryError {
  let pt = pt.with_dim(2)
  let u = try! ellipse_unit_coords(center, hradius, vradius, pt)
  let d2 = geo_simplify(u[0] * u[0] + u[1] * u[1])
  match geo_expr_sign(d2 - geo_one()) {
    Some(sign) if sign < 0 => []
    Some(0) =>
      [try! tangent_line_at_boundary_point(center, hradius, vradius, pt)]
    Some(_) => {
      let scale = geo_div(@symelem.sqrt(d2 - geo_one()), d2)
      let base = [geo_div(u[0], d2), geo_div(u[1], d2)]
      let perp = try! geo_perp2(u)
      let q1 = [
        geo_simplify(base[0] + perp[0] * scale),
        geo_simplify(base[1] + perp[1] * scale),
      ]
      let q2 = [
        geo_simplify(base[0] - perp[0] * scale),
        geo_simplify(base[1] - perp[1] * scale),
      ]
      let t1 = try! ellipse_tangent_point_from_unit(
        center, hradius, vradius, q1,
      )
      let t2 = try! ellipse_tangent_point_from_unit(
        center, hradius, vradius, q2,
      )
      if t1 == t2 {
        [try! line(pt, t1)]
      } else {
        [try! line(pt, t1), try! line(pt, t2)]
      }
    }
    None =>
      raise GeometryError::Undecidable(
        "cannot decide tangent multiplicity for ellipse",
      )
  }
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
        GeometryEntity::Point(prev) if geo_point_eq(prev, pt) => seen = true
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
fn unique_intersection_points(hits : Array[GeometryEntity]) -> Array[Point] {
  let out : Array[Point] = []
  for hit in hits {
    match hit {
      GeometryEntity::Point(pt) => unique_push_point(out, pt)
      _ => ()
    }
  }
  out
}

///|
fn linear_line_coeffs_2d(
  entity : GeometryEntity,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise GeometryError {
  let p1 = linear_p1(entity).with_dim(2)
  let p2 = linear_p2(entity).with_dim(2)
  let a = geo_simplify(p1.coords_[1] - p2.coords_[1])
  let b = geo_simplify(p2.coords_[0] - p1.coords_[0])
  let c = geo_simplify(
    p1.coords_[0] * p2.coords_[1] - p2.coords_[0] * p1.coords_[1],
  )
  (a, b, c)
}

///|
fn ellipse_line_contact_point(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  entity : GeometryEntity,
) -> Point raise GeometryError {
  let (a, b, c) = linear_line_coeffs_2d(entity)
  let shifted_c = geo_simplify(
    a * center.coords_[0] + b * center.coords_[1] + c,
  )
  point2d(
    geo_simplify(
      center.coords_[0] - geo_div((hradius ^ geo_int(2)) * a, shifted_c),
    ),
    geo_simplify(
      center.coords_[1] - geo_div((vradius ^ geo_int(2)) * b, shifted_c),
    ),
  )
}

///|
fn ellipse_supporting_line_is_tangent(
  center : Point,
  hradius : @symcore.Expr,
  vradius : @symcore.Expr,
  entity : GeometryEntity,
) -> Bool raise GeometryError {
  let (a, b, c) = linear_line_coeffs_2d(entity)
  let shifted_c = geo_simplify(
    a * center.coords_[0] + b * center.coords_[1] + c,
  )
  geo_expr_is_zero(
    geo_simplify(
      (shifted_c ^ geo_int(2)) -
      (
        (a ^ geo_int(2)) * (hradius ^ geo_int(2)) +
        (b ^ geo_int(2)) * (vradius ^ geo_int(2))
      ),
    ),
  )
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
pub fn Ellipse::major(self : Ellipse) -> @symcore.Expr {
  if ellipse_major_on_x(self.hradius_, self.vradius_) {
    @symelem.abs(self.hradius_)
  } else {
    @symelem.abs(self.vradius_)
  }
}

///|
pub fn Ellipse::minor(self : Ellipse) -> @symcore.Expr {
  if ellipse_major_on_x(self.hradius_, self.vradius_) {
    @symelem.abs(self.vradius_)
  } else {
    @symelem.abs(self.hradius_)
  }
}

///|
pub fn Ellipse::circumference(self : Ellipse) -> @symcore.Expr {
  if geo_expr_eq(self.major(), self.minor()) {
    geo_simplify(geo_two_pi() * self.major())
  } else {
    geo_simplify(
      geo_int(4) *
      self.major() *
      @symcore.raw_function("elliptic_e", [self.eccentricity() ^ geo_int(2)]),
    )
  }
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
pub fn Ellipse::periapsis(self : Ellipse) -> @symcore.Expr {
  geo_simplify(self.major() * (geo_one() - self.eccentricity()))
}

///|
pub fn Ellipse::apoapsis(self : Ellipse) -> @symcore.Expr {
  geo_simplify(self.major() * (geo_one() + self.eccentricity()))
}

///|
pub fn Ellipse::semilatus_rectum(self : Ellipse) -> @symcore.Expr {
  geo_simplify(self.major() * (geo_one() - (self.eccentricity() ^ geo_int(2))))
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
  _slope? : @symcore.Expr? = None,
) -> @symcore.Expr {
  let dx = x - self.center_.coords_[0]
  let dy = y - self.center_.coords_[1]
  match _slope {
    Some(slope) => {
      let l = (slope * dy + dx) ^ geo_int(2)
      let big_l = (dy - slope * dx) ^ geo_int(2)
      let h = geo_one() + slope * slope
      let b = geo_simplify(h * (self.major() ^ geo_int(2)))
      let a = geo_simplify(h * (self.minor() ^ geo_int(2)))
      geo_simplify(geo_div(l, b) + geo_div(big_l, a) - geo_one())
    }
    None =>
      geo_simplify(
        geo_div(dx ^ geo_int(2), self.hradius_ ^ geo_int(2)) +
        geo_div(dy ^ geo_int(2), self.vradius_ ^ geo_int(2)) -
        geo_one(),
      )
  }
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
pub fn Ellipse::encloses_point(
  self : Ellipse,
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  if self.contains_point(pt) {
    return false
  }
  match geo_expr_sign(self.equation(x=pt.coords_[0], y=pt.coords_[1])) {
    Some(sign) => sign < 0
    None =>
      raise GeometryError::Undecidable(
        "cannot decide strict ellipse containment",
      )
  }
}

///|
pub fn Ellipse::bounds(self : Ellipse) -> (Point, Point) raise GeometryError {
  (
    try! point2d(
      self.center_.coords_[0] - self.hradius_,
      self.center_.coords_[1] - self.vradius_,
    ),
    try! point2d(
      self.center_.coords_[0] + self.hradius_,
      self.center_.coords_[1] + self.vradius_,
    ),
  )
}

///|
pub fn Ellipse::plot_interval(
  self : Ellipse,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Array[@symcore.Expr] {
  [parameter, geo_zero() - geo_pi(), geo_pi()]
}

///|
pub fn Ellipse::parameter_value(
  self : Ellipse,
  other : Point,
  t : @symcore.Expr,
) -> Map[@symcore.Expr, @symcore.Expr] raise GeometryError {
  let pt = other.with_dim(2)
  if !(try! self.contains_point(pt)) {
    raise GeometryError::ValueError("point is not on ellipse")
  }
  let ux = geo_div(pt.coords_[0] - self.center_.coords_[0], self.hradius_)
  let uy = geo_div(pt.coords_[1] - self.center_.coords_[1], self.vradius_)
  let out : Map[@symcore.Expr, @symcore.Expr] = {}
  out.set(t, geo_normalized_atan2(uy, ux))
  out
}

///|
pub fn Ellipse::encloses(
  self : Ellipse,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Ellipse(value) if self == value => return false
    _ => ()
  }
  if !(try! self.intersection(other)).is_empty() {
    return false
  }
  match other {
    GeometryEntity::Point(pt) => self.encloses_point(pt)
    GeometryEntity::Segment(seg) =>
      self.encloses_point(seg.p1()) && self.encloses_point(seg.p2())
    GeometryEntity::Polygon(poly) => {
      for pt in poly.vertices() {
        if !(try! self.encloses_point(pt)) {
          return false
        }
      }
      true
    }
    GeometryEntity::RegularPolygon(poly) => {
      let vertices = try! poly.vertices()
      for pt in vertices {
        if !(try! self.encloses_point(pt)) {
          return false
        }
      }
      true
    }
    GeometryEntity::Triangle(poly) => {
      for pt in poly.vertices() {
        if !(try! self.encloses_point(pt)) {
          return false
        }
      }
      true
    }
    _ => false
  }
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
pub fn Ellipse::tangent_lines(
  self : Ellipse,
  pt : Point,
) -> Array[Line] raise GeometryError {
  ellipse_tangent_lines_from_point(
    self.center_,
    self.hradius_,
    self.vradius_,
    pt,
  )
}

///|
pub fn Ellipse::is_tangent(
  self : Ellipse,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(_) =>
      ellipse_supporting_line_is_tangent(
        self.center_,
        self.hradius_,
        self.vradius_,
        other,
      )
    GeometryEntity::Ray(_) | GeometryEntity::Segment(_) => {
      if !ellipse_supporting_line_is_tangent(
          self.center_,
          self.hradius_,
          self.vradius_,
          other,
        ) {
        return false
      }
      linear_contains_point(
        other,
        try! ellipse_line_contact_point(
          self.center_,
          self.hradius_,
          self.vradius_,
          other,
        ),
      )
    }
    GeometryEntity::Circle(_) => {
      let hits = self.intersection(other)
      unique_intersection_points(hits).length() == 1
    }
    _ => false
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
pub fn Circle::vradius(self : Circle) -> @symcore.Expr {
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
pub fn Circle::bounds(self : Circle) -> (Point, Point) raise GeometryError {
  (
    try! point2d(
      self.center_.coords_[0] - self.radius_,
      self.center_.coords_[1] - self.radius_,
    ),
    try! point2d(
      self.center_.coords_[0] + self.radius_,
      self.center_.coords_[1] + self.radius_,
    ),
  )
}

///|
pub fn Circle::plot_interval(
  self : Circle,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Array[@symcore.Expr] {
  [parameter, geo_zero() - geo_pi(), geo_pi()]
}

///|
pub fn Circle::parameter_value(
  self : Circle,
  other : Point,
  t : @symcore.Expr,
) -> Map[@symcore.Expr, @symcore.Expr] raise GeometryError {
  let pt = other.with_dim(2)
  if !(try! self.contains_point(pt)) {
    raise GeometryError::ValueError("point is not on circle")
  }
  let ux = geo_div(pt.coords_[0] - self.center_.coords_[0], self.radius_)
  let uy = geo_div(pt.coords_[1] - self.center_.coords_[1], self.radius_)
  let out : Map[@symcore.Expr, @symcore.Expr] = {}
  out.set(t, geo_normalized_atan2(uy, ux))
  out
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
pub fn Circle::encloses_point(
  self : Circle,
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  if self.contains_point(pt) {
    return false
  }
  match geo_expr_sign(self.equation(x=pt.coords_[0], y=pt.coords_[1])) {
    Some(sign) => sign < 0
    None =>
      raise GeometryError::Undecidable(
        "cannot decide strict circle containment",
      )
  }
}

///|
pub fn Circle::encloses(
  self : Circle,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  let as_ellipse = Ellipse::{
    center_: self.center_,
    hradius_: self.radius_,
    vradius_: self.radius_,
  }
  as_ellipse.encloses(other)
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

///|
pub fn Circle::tangent_lines(
  self : Circle,
  pt : Point,
) -> Array[Line] raise GeometryError {
  ellipse_tangent_lines_from_point(self.center_, self.radius_, self.radius_, pt)
}

///|
pub fn Circle::is_tangent(
  self : Circle,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(_) =>
      ellipse_supporting_line_is_tangent(
        self.center_,
        self.radius_,
        self.radius_,
        other,
      )
    GeometryEntity::Ray(_) | GeometryEntity::Segment(_) => {
      if !ellipse_supporting_line_is_tangent(
          self.center_,
          self.radius_,
          self.radius_,
          other,
        ) {
        return false
      }
      linear_contains_point(
        other,
        try! ellipse_line_contact_point(
          self.center_,
          self.radius_,
          self.radius_,
          other,
        ),
      )
    }
    GeometryEntity::Circle(_) => {
      let hits = self.intersection(other)
      unique_intersection_points(hits).length() == 1
    }
    _ => false
  }
}
