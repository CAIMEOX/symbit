///|
priv enum LinearKind {
  Line
  Ray
  Segment
}

///|
pub struct Line {
  p1_ : Point
  p2_ : Point
} derive(Eq, Hash)

///|
pub struct Ray {
  p1_ : Point
  p2_ : Point
} derive(Eq, Hash)

///|
pub struct Segment {
  p1_ : Point
  p2_ : Point
} derive(Eq, Hash)

///|
pub enum GeometryEntity {
  Point(Point)
  Line(Line)
  Ray(Ray)
  Segment(Segment)
  Plane(Plane)
  Ellipse(Ellipse)
  Circle(Circle)
  Polygon(Polygon)
  RegularPolygon(RegularPolygon)
  Triangle(Triangle)
  Parabola(Parabola)
  Curve(Curve)
} derive(Eq)

///|
fn linear_points(p1 : Point, p2 : Point) -> (Point, Point) raise GeometryError {
  let normalized = geo_normalize_dim([p1, p2])
  let lhs = normalized[0]
  let rhs = normalized[1]
  if lhs == rhs {
    raise GeometryError::ValueError("linear entity requires two unique points")
  }
  (lhs, rhs)
}

///|
pub fn line(p1 : Point, p2 : Point) -> Line raise GeometryError {
  let (lhs, rhs) = linear_points(p1, p2)
  Line::{ p1_: lhs, p2_: rhs }
}

///|
pub fn ray(p1 : Point, p2 : Point) -> Ray raise GeometryError {
  let (lhs, rhs) = linear_points(p1, p2)
  Ray::{ p1_: lhs, p2_: rhs }
}

///|
pub fn segment(p1 : Point, p2 : Point) -> Segment raise GeometryError {
  let (lhs, rhs) = linear_points(p1, p2)
  Segment::{ p1_: lhs, p2_: rhs }
}

///|
fn linear_kind(entity : GeometryEntity) -> LinearKind raise GeometryError {
  match entity {
    GeometryEntity::Line(_) => LinearKind::Line
    GeometryEntity::Ray(_) => LinearKind::Ray
    GeometryEntity::Segment(_) => LinearKind::Segment
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
fn linear_p1(entity : GeometryEntity) -> Point raise GeometryError {
  match entity {
    GeometryEntity::Line(item) => item.p1_
    GeometryEntity::Ray(item) => item.p1_
    GeometryEntity::Segment(item) => item.p1_
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
fn linear_p2(entity : GeometryEntity) -> Point raise GeometryError {
  match entity {
    GeometryEntity::Line(item) => item.p2_
    GeometryEntity::Ray(item) => item.p2_
    GeometryEntity::Segment(item) => item.p2_
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
fn linear_direction_coords(
  entity : GeometryEntity,
) -> Array[@symcore.Expr] raise GeometryError {
  let p1 = linear_p1(entity)
  let p2 = linear_p2(entity)
  geo_sub_coords(p2.coords_, p1.coords_)
}

///|
fn linear_repr(entity : GeometryEntity) -> String raise GeometryError {
  let kind = linear_kind(entity)
  let p1 = linear_p1(entity)
  let p2 = linear_p2(entity)
  geo_linear_name(kind, p1.ambient_dimension()) +
  "(" +
  p1.repr() +
  ", " +
  p2.repr() +
  ")"
}

///|
fn linear_param_ok(
  kind : LinearKind,
  value : @symcore.Expr,
) -> Bool raise GeometryError {
  match kind {
    LinearKind::Line => true
    LinearKind::Ray =>
      match geo_expr_sign(value) {
        Some(sign) => sign >= 0
        None =>
          raise GeometryError::Undecidable("cannot decide ray parameter sign")
      }
    LinearKind::Segment => {
      let lower = geo_expr_sign(value)
      let upper = geo_expr_sign(geo_one() - value)
      match (lower, upper) {
        (Some(ls), Some(us)) => ls >= 0 && us >= 0
        _ =>
          raise GeometryError::Undecidable(
            "cannot decide segment parameter bounds",
          )
      }
    }
  }
}

///|
fn linear_point_at(
  entity : GeometryEntity,
  t : @symcore.Expr,
) -> Point raise GeometryError {
  let p1 = linear_p1(entity)
  let direction = linear_direction_coords(entity)
  let out : Array[@symcore.Expr] = []
  for i in 0..<direction.length() {
    out.push(geo_simplify(p1.coords_[i] + t * direction[i]))
  }
  point(out, dim=p1.ambient_dimension())
}

///|
fn linear_param_for_point(
  entity : GeometryEntity,
  pt : Point,
) -> @symcore.Expr raise GeometryError {
  let p1 = linear_p1(entity)
  let target = pt.with_dim(p1.ambient_dimension())
  let diff = geo_sub_coords(target.coords_, p1.coords_)
  let direction = linear_direction_coords(entity)
  let pivot = match geo_dominant_index(direction) {
    Some(idx) => idx
    None => raise GeometryError::ValueError("degenerate linear entity")
  }
  let t = geo_div(diff[pivot], direction[pivot])
  for i in 0..<direction.length() {
    if !geo_expr_is_zero(diff[i] - t * direction[i]) {
      raise GeometryError::Undecidable("point is not on the supporting line")
    }
  }
  t
}

///|
fn linear_contains_point(
  entity : GeometryEntity,
  pt : Point,
) -> Bool raise GeometryError {
  let p1 = linear_p1(entity)
  let target = pt.with_dim(p1.ambient_dimension())
  let diff = geo_sub_coords(target.coords_, p1.coords_)
  let direction = linear_direction_coords(entity)
  let dim = p1.ambient_dimension()
  let on_line = if dim == 2 {
    geo_expr_is_zero(geo_cross2(direction, diff))
  } else if dim == 3 {
    geo_all_zero(geo_cross3(direction, diff))
  } else {
    let pivot = match geo_dominant_index(direction) {
      Some(idx) => idx
      None => return false
    }
    let t = geo_div(diff[pivot], direction[pivot])
    let mut ok = true
    for i in 0..<direction.length() {
      if !geo_expr_is_zero(diff[i] - t * direction[i]) {
        ok = false
      }
    }
    ok
  }
  if !on_line {
    return false
  }
  let t = linear_param_for_point(entity, target) catch {
    GeometryError::Undecidable(_) => return false
    e => raise e
  }
  linear_param_ok(linear_kind(entity), t)
}

///|
fn linear_entity_is_similar(
  entity : GeometryEntity,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => {
      let base = line(linear_p1(entity), linear_p2(entity))
      base.contains(linear_p1(other)) && base.contains(linear_p2(other))
    }
    _ => false
  }
}

///|
fn line_intersection_unique(
  lhs : GeometryEntity,
  rhs : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  let p = linear_p1(lhs)
  let q = linear_p1(rhs).with_dim(p.ambient_dimension())
  let r = linear_direction_coords(lhs)
  let s = linear_direction_coords(rhs)
  let diff = geo_sub_coords(q.coords_, p.coords_)
  let dim = p.ambient_dimension()
  let pairs = if dim == 2 { [(0, 1)] } else { [(0, 1), (0, 2), (1, 2)] }
  for pair in pairs {
    let det = geo_pair_determinant(r, s, pair.0, pair.1)
    if geo_expr_is_zero(det) {
      continue
    }
    let t = geo_div(diff[pair.0] * s[pair.1] - diff[pair.1] * s[pair.0], det)
    let u = geo_div(diff[pair.0] * r[pair.1] - diff[pair.1] * r[pair.0], det)
    if !linear_param_ok(linear_kind(lhs), t) ||
      !linear_param_ok(linear_kind(rhs), u) {
      return []
    }
    let pt = linear_point_at(lhs, t)
    if linear_contains_point(lhs, pt) && linear_contains_point(rhs, pt) {
      return [GeometryEntity::Point(pt)]
    }
  }
  []
}

///|
fn line_parallel_overlap(
  lhs : GeometryEntity,
  rhs : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  let p = linear_p1(lhs)
  let q = linear_p1(rhs).with_dim(p.ambient_dimension())
  let r = linear_direction_coords(lhs)
  let diff = geo_sub_coords(q.coords_, p.coords_)
  let dim = p.ambient_dimension()
  let collinear = if dim == 2 {
    geo_expr_is_zero(geo_cross2(r, diff))
  } else {
    geo_all_zero(geo_cross3(r, diff))
  }
  if !collinear {
    return []
  }
  if linear_contains_point(lhs, q) {
    match (lhs, rhs) {
      (GeometryEntity::Line(line_obj), _) =>
        return [GeometryEntity::Line(line_obj)]
      (_, GeometryEntity::Line(line_obj)) =>
        return [GeometryEntity::Line(line_obj)]
      _ => ()
    }
  }
  let q2 = linear_p2(rhs).with_dim(p.ambient_dimension())
  if linear_contains_point(lhs, q2) {
    match rhs {
      GeometryEntity::Segment(seg) => return [GeometryEntity::Segment(seg)]
      GeometryEntity::Ray(ray_obj) => return [GeometryEntity::Ray(ray_obj)]
      _ => ()
    }
  }
  if linear_contains_point(rhs, p) {
    match lhs {
      GeometryEntity::Segment(seg) => return [GeometryEntity::Segment(seg)]
      GeometryEntity::Ray(ray_obj) => return [GeometryEntity::Ray(ray_obj)]
      _ => ()
    }
  }
  let points : Array[Point] = []
  let candidates = [
    linear_p1(lhs),
    linear_p2(lhs),
    linear_p1(rhs),
    linear_p2(rhs),
  ]
  for item in candidates {
    if linear_contains_point(lhs, item) && linear_contains_point(rhs, item) {
      let mut seen = false
      for prev in points {
        if prev == item {
          seen = true
        }
      }
      if !seen {
        points.push(item)
      }
    }
  }
  if points.is_empty() {
    []
  } else if points.length() == 1 {
    [GeometryEntity::Point(points[0])]
  } else {
    [GeometryEntity::Segment(segment(points[0], points[1]))]
  }
}

///|
fn linear_intersection(
  lhs : GeometryEntity,
  rhs : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  let first = line_intersection_unique(lhs, rhs)
  if !first.is_empty() {
    return first
  }
  line_parallel_overlap(lhs, rhs)
}

///|
fn linear_translate(
  entity : GeometryEntity,
  offsets : Array[@symcore.Expr],
) -> GeometryEntity raise GeometryError {
  match entity {
    GeometryEntity::Line(item) =>
      GeometryEntity::Line(
        line(item.p1_.translate(offsets), item.p2_.translate(offsets)),
      )
    GeometryEntity::Ray(item) =>
      GeometryEntity::Ray(
        ray(item.p1_.translate(offsets), item.p2_.translate(offsets)),
      )
    GeometryEntity::Segment(item) =>
      GeometryEntity::Segment(
        segment(item.p1_.translate(offsets), item.p2_.translate(offsets)),
      )
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
fn linear_scale(
  entity : GeometryEntity,
  factors : Array[@symcore.Expr],
  pt : Point?,
) -> GeometryEntity raise GeometryError {
  match entity {
    GeometryEntity::Line(item) =>
      GeometryEntity::Line(
        line(item.p1_.scale(factors, pt~), item.p2_.scale(factors, pt~)),
      )
    GeometryEntity::Ray(item) =>
      GeometryEntity::Ray(
        ray(item.p1_.scale(factors, pt~), item.p2_.scale(factors, pt~)),
      )
    GeometryEntity::Segment(item) =>
      GeometryEntity::Segment(
        segment(item.p1_.scale(factors, pt~), item.p2_.scale(factors, pt~)),
      )
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
fn linear_rotate(
  entity : GeometryEntity,
  angle : @symcore.Expr,
  pt : Point?,
) -> GeometryEntity raise GeometryError {
  match entity {
    GeometryEntity::Line(item) =>
      GeometryEntity::Line(
        line(item.p1_.rotate(angle, pt~), item.p2_.rotate(angle, pt~)),
      )
    GeometryEntity::Ray(item) =>
      GeometryEntity::Ray(
        ray(item.p1_.rotate(angle, pt~), item.p2_.rotate(angle, pt~)),
      )
    GeometryEntity::Segment(item) =>
      GeometryEntity::Segment(
        segment(item.p1_.rotate(angle, pt~), item.p2_.rotate(angle, pt~)),
      )
    _ => raise GeometryError::TypeError("expected linear entity")
  }
}

///|
pub fn Line::p1(self : Line) -> Point {
  self.p1_
}

///|
pub fn Line::p2(self : Line) -> Point {
  self.p2_
}

///|
pub fn Line::ambient_dimension(self : Line) -> Int {
  self.p1_.ambient_dimension()
}

///|
pub fn Line::direction(self : Line) -> Point {
  geo_point_from_coords(geo_sub_coords(self.p2_.coords_, self.p1_.coords_))
}

///|
pub fn Line::equals(
  self : Line,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Line(line_obj) =>
      point_are_collinear([self.p1_, self.p2_, line_obj.p1_, line_obj.p2_])
    _ => false
  }
}

///|
pub fn Line::repr(self : Line) -> String raise GeometryError {
  linear_repr(GeometryEntity::Line(self))
}

///|
pub fn Line::arbitrary_point(
  self : Line,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Point raise GeometryError {
  linear_point_at(GeometryEntity::Line(self), parameter)
}

///|
pub fn Line::plot_interval(
  self : Line,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Array[@symcore.Expr] {
  let _ = self
  [parameter, geo_int(-5), geo_int(5)]
}

///|
pub fn Line::contains(self : Line, other : Point) -> Bool raise GeometryError {
  linear_contains_point(GeometryEntity::Line(self), other)
}

///|
pub fn Line::distance(
  self : Line,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let point_obj = other.with_dim(self.ambient_dimension())
  let diff = geo_sub_coords(point_obj.coords_, self.p1_.coords_)
  let direction = geo_sub_coords(self.p2_.coords_, self.p1_.coords_)
  if self.ambient_dimension() == 2 {
    geo_div(@symelem.abs(geo_cross2(direction, diff)), geo_norm(direction))
  } else if self.ambient_dimension() == 3 {
    geo_div(geo_norm(geo_cross3(direction, diff)), geo_norm(direction))
  } else {
    raise GeometryError::ValueError(
      "line distance is only implemented for 2D/3D",
    )
  }
}

///|
pub fn Line::translate(
  self : Line,
  offsets : Array[@symcore.Expr],
) -> Line raise GeometryError {
  match linear_translate(GeometryEntity::Line(self), offsets) {
    GeometryEntity::Line(value) => value
    _ => raise GeometryError::TypeError("expected line result")
  }
}

///|
pub fn Line::scale(
  self : Line,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Line raise GeometryError {
  match linear_scale(GeometryEntity::Line(self), factors, pt) {
    GeometryEntity::Line(value) => value
    _ => raise GeometryError::TypeError("expected line result")
  }
}

///|
pub fn Line::rotate(
  self : Line,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Line raise GeometryError {
  match linear_rotate(GeometryEntity::Line(self), angle, pt) {
    GeometryEntity::Line(value) => value
    _ => raise GeometryError::TypeError("expected line result")
  }
}

///|
pub fn Line::intersection(
  self : Line,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) =>
      linear_intersection(GeometryEntity::Line(self), other)
    GeometryEntity::Plane(plane_obj) =>
      plane_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Ellipse(ellipse_obj) =>
      ellipse_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Circle(circle_obj) =>
      circle_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Parabola(parabola_obj) =>
      parabola_obj.intersection(GeometryEntity::Line(self))
    GeometryEntity::Point(point_obj) =>
      if self.contains(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(self.ambient_dimension()))]
      } else {
        []
      }
    GeometryEntity::Curve(_) => []
  }
}

///|
pub fn Line::is_parallel(
  self : Line,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  let rhs = linear_direction_coords(other)
  let lhs = self.direction().coords_
  if lhs.length() == 2 {
    geo_expr_is_zero(geo_cross2(lhs, rhs))
  } else if lhs.length() == 3 {
    geo_all_zero(geo_cross3(lhs, rhs))
  } else {
    raise GeometryError::ValueError(
      "parallel test is only implemented for 2D/3D",
    )
  }
}

///|
pub fn Line::is_perpendicular(
  self : Line,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  geo_expr_is_zero(
    geo_dot(self.direction().coords_, linear_direction_coords(other)),
  )
}

///|
pub fn Line::angle_between(
  self : Line,
  other : GeometryEntity,
) -> @symcore.Expr raise GeometryError {
  let lhs = self.direction().coords_
  let rhs = linear_direction_coords(other)
  @symelem.acos(geo_div(geo_dot(lhs, rhs), geo_norm(lhs) * geo_norm(rhs)))
}

///|
pub fn Line::smallest_angle_between(
  self : Line,
  other : GeometryEntity,
) -> @symcore.Expr raise GeometryError {
  let lhs = self.direction().coords_
  let rhs = linear_direction_coords(other)
  @symelem.acos(
    geo_div(@symelem.abs(geo_dot(lhs, rhs)), geo_norm(lhs) * geo_norm(rhs)),
  )
}

///|
pub fn Line::is_similar(
  self : Line,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  linear_entity_is_similar(geometry_line(self), other)
}

///|
pub fn Ray::p1(self : Ray) -> Point {
  self.p1_
}

///|
pub fn Ray::p2(self : Ray) -> Point {
  self.p2_
}

///|
pub fn Ray::ambient_dimension(self : Ray) -> Int {
  self.p1_.ambient_dimension()
}

///|
pub fn Ray::direction(self : Ray) -> Point {
  geo_point_from_coords(geo_sub_coords(self.p2_.coords_, self.p1_.coords_))
}

///|
pub fn Ray::equals(
  self : Ray,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Ray(ray_obj) =>
      self.source().equals(ray_obj.source()) && self.contains(ray_obj.p2_)
    _ => false
  }
}

///|
pub fn Ray::repr(self : Ray) -> String raise GeometryError {
  linear_repr(GeometryEntity::Ray(self))
}

///|
pub fn Ray::plot_interval(
  self : Ray,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Array[@symcore.Expr] {
  let _ = self
  [parameter, geo_zero(), geo_int(10)]
}

///|
pub fn Ray::source(self : Ray) -> Point {
  self.p1_
}

///|
pub fn Ray::contains(self : Ray, other : Point) -> Bool raise GeometryError {
  linear_contains_point(GeometryEntity::Ray(self), other)
}

///|
pub fn Ray::intersection(
  self : Ray,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) =>
      linear_intersection(GeometryEntity::Ray(self), other)
    GeometryEntity::Plane(plane_obj) =>
      plane_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Ellipse(ellipse_obj) =>
      ellipse_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Circle(circle_obj) =>
      circle_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Parabola(parabola_obj) =>
      parabola_obj.intersection(GeometryEntity::Ray(self))
    GeometryEntity::Point(point_obj) =>
      if self.contains(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(self.ambient_dimension()))]
      } else {
        []
      }
    GeometryEntity::Curve(_) => []
  }
}

///|
pub fn Ray::translate(
  self : Ray,
  offsets : Array[@symcore.Expr],
) -> Ray raise GeometryError {
  match linear_translate(GeometryEntity::Ray(self), offsets) {
    GeometryEntity::Ray(value) => value
    _ => raise GeometryError::TypeError("expected ray result")
  }
}

///|
pub fn Ray::scale(
  self : Ray,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Ray raise GeometryError {
  match linear_scale(GeometryEntity::Ray(self), factors, pt) {
    GeometryEntity::Ray(value) => value
    _ => raise GeometryError::TypeError("expected ray result")
  }
}

///|
pub fn Ray::rotate(
  self : Ray,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Ray raise GeometryError {
  match linear_rotate(GeometryEntity::Ray(self), angle, pt) {
    GeometryEntity::Ray(value) => value
    _ => raise GeometryError::TypeError("expected ray result")
  }
}

///|
pub fn Ray::distance(
  self : Ray,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let target = other.with_dim(self.ambient_dimension())
  let direction = self.direction().coords_
  let diff = geo_sub_coords(target.coords_, self.p1_.coords_)
  let dot = geo_dot(direction, diff)
  match geo_expr_sign(dot) {
    Some(sign) if sign < 0 => target.distance(self.p1_)
    Some(_) | None =>
      if self.ambient_dimension() == 2 {
        geo_div(@symelem.abs(geo_cross2(direction, diff)), geo_norm(direction))
      } else if self.ambient_dimension() == 3 {
        geo_div(geo_norm(geo_cross3(direction, diff)), geo_norm(direction))
      } else {
        raise GeometryError::ValueError(
          "ray distance is only implemented for 2D/3D",
        )
      }
  }
}

///|
pub fn Ray::is_similar(
  self : Ray,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  linear_entity_is_similar(geometry_ray(self), other)
}

///|
pub fn Segment::p1(self : Segment) -> Point {
  self.p1_
}

///|
pub fn Segment::p2(self : Segment) -> Point {
  self.p2_
}

///|
pub fn Segment::ambient_dimension(self : Segment) -> Int {
  self.p1_.ambient_dimension()
}

///|
pub fn Segment::direction(self : Segment) -> Point {
  geo_point_from_coords(geo_sub_coords(self.p2_.coords_, self.p1_.coords_))
}

///|
pub fn Segment::equals(
  self : Segment,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    GeometryEntity::Segment(seg_obj) =>
      (self.p1_.equals(seg_obj.p1_) && self.p2_.equals(seg_obj.p2_)) ||
      (self.p1_.equals(seg_obj.p2_) && self.p2_.equals(seg_obj.p1_))
    _ => false
  }
}

///|
pub fn Segment::repr(self : Segment) -> String raise GeometryError {
  linear_repr(GeometryEntity::Segment(self))
}

///|
pub fn Segment::contains(
  self : Segment,
  other : Point,
) -> Bool raise GeometryError {
  linear_contains_point(GeometryEntity::Segment(self), other)
}

///|
pub fn Segment::length(self : Segment) -> @symcore.Expr raise GeometryError {
  self.p1_.distance(self.p2_)
}

///|
pub fn Segment::midpoint(self : Segment) -> Point raise GeometryError {
  self.p1_.midpoint(self.p2_)
}

///|
pub fn Segment::plot_interval(
  self : Segment,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Array[@symcore.Expr] {
  let _ = self
  [parameter, geo_zero(), geo_one()]
}

///|
pub fn Segment::perpendicular_bisector(
  self : Segment,
  p? : Point? = None,
) -> GeometryEntity raise GeometryError {
  let midpoint = try! self.midpoint()
  let direction = try! self.direction().orthogonal_direction()
  let bisector = try! line(midpoint, midpoint + direction)
  match p {
    Some(point_obj) => {
      let point_obj = point_obj.with_dim(midpoint.ambient_dimension())
      if bisector.contains(point_obj) {
        return geometry_segment(try! segment(point_obj, midpoint))
      }
      geometry_line(bisector)
    }
    None => geometry_line(bisector)
  }
}

///|
pub fn Segment::intersection(
  self : Segment,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) =>
      linear_intersection(GeometryEntity::Segment(self), other)
    GeometryEntity::Plane(plane_obj) =>
      plane_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Ellipse(ellipse_obj) =>
      ellipse_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Circle(circle_obj) =>
      circle_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Parabola(parabola_obj) =>
      parabola_obj.intersection(GeometryEntity::Segment(self))
    GeometryEntity::Point(point_obj) =>
      if self.contains(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(self.ambient_dimension()))]
      } else {
        []
      }
    GeometryEntity::Curve(_) => []
  }
}

///|
pub fn Segment::translate(
  self : Segment,
  offsets : Array[@symcore.Expr],
) -> Segment raise GeometryError {
  match linear_translate(GeometryEntity::Segment(self), offsets) {
    GeometryEntity::Segment(value) => value
    _ => raise GeometryError::TypeError("expected segment result")
  }
}

///|
pub fn Segment::scale(
  self : Segment,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Segment raise GeometryError {
  match linear_scale(GeometryEntity::Segment(self), factors, pt) {
    GeometryEntity::Segment(value) => value
    _ => raise GeometryError::TypeError("expected segment result")
  }
}

///|
pub fn Segment::rotate(
  self : Segment,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Segment raise GeometryError {
  match linear_rotate(GeometryEntity::Segment(self), angle, pt) {
    GeometryEntity::Segment(value) => value
    _ => raise GeometryError::TypeError("expected segment result")
  }
}

///|
pub fn Segment::distance(
  self : Segment,
  other : Point,
) -> @symcore.Expr raise GeometryError {
  let target = other.with_dim(self.ambient_dimension())
  let direction = self.direction().coords_
  let diff = geo_sub_coords(target.coords_, self.p1_.coords_)
  let denom = geo_norm_sq(direction)
  let t = geo_div(geo_dot(diff, direction), denom)
  match (geo_expr_sign(t), geo_expr_sign(geo_one() - t)) {
    (Some(ls), Some(us)) if ls >= 0 && us >= 0 => {
      let proj = linear_point_at(GeometryEntity::Segment(self), t)
      target.distance(proj)
    }
    (Some(ls), _) if ls < 0 => target.distance(self.p1_)
    (_, Some(us)) if us < 0 => target.distance(self.p2_)
    _ =>
      raise GeometryError::Undecidable("cannot decide segment distance branch")
  }
}

///|
pub fn Segment::is_similar(
  self : Segment,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  linear_entity_is_similar(geometry_segment(self), other)
}
