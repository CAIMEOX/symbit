///|
/// A polygonal closed path in the plane.
pub struct Polygon {
  vertices_ : Array[Point]
} derive(Eq)

///|
/// Regular polygon determined by center, circumradius, side count and rotation.
pub struct RegularPolygon {
  center_ : Point
  radius_ : Expr
  n_ : Int
  rotation_ : Expr
} derive(Eq)

///|
/// Triangle specialization.
pub struct Triangle {
  vertices_ : Array[Point]
} derive(Eq)

///|
fn polygon_clean_vertices(
  vertices : Array[Point],
) -> Array[Point] raise GeometryError {
  if vertices.is_empty() {
    raise GeometryError::ValueError("polygon requires at least one point")
  }
  let normalized = geo_normalize_dim(vertices)
  let out : Array[Point] = []
  for item in normalized {
    let pt = item.with_dim(2)
    if out.is_empty() || out[out.length() - 1] != pt {
      out.push(pt)
    }
  }
  if out.length() > 1 && out[0] == out[out.length() - 1] {
    ignore(out.pop())
  }
  out
}

///|
pub fn polygon(vertices : Array[Point]) -> GeometryEntity raise GeometryError {
  let items = polygon_clean_vertices(vertices)
  match items.length() {
    1 => geometry_point(items[0])
    2 => geometry_segment(segment(items[0], items[1]))
    3 =>
      if point_are_collinear(items) {
        geometry_segment(segment(items[0], items[2]))
      } else {
        geometry_triangle(Triangle::{ vertices_: items })
      }
    _ => geometry_polygon(Polygon::{ vertices_: items })
  }
}

///|
pub fn regular_polygon(
  center : Point,
  radius : Expr,
  n : Int,
  rotation? : Expr = geo_zero(),
) -> RegularPolygon raise GeometryError {
  if n < 3 {
    raise GeometryError::ValueError(
      "regular polygon must have at least 3 sides",
    )
  }
  RegularPolygon::{
    center_: center.with_dim(2),
    radius_: geo_simplify(radius),
    n_: n,
    rotation_: rotation,
  }
}

///|
pub fn triangle(
  a : Point,
  b : Point,
  c : Point,
) -> Triangle raise GeometryError {
  let items = polygon_clean_vertices([a, b, c])
  if items.length() != 3 || point_are_collinear(items) {
    raise GeometryError::ValueError(
      "triangle requires three non-collinear points",
    )
  }
  Triangle::{ vertices_: items }
}

///|
fn polygon_area_expr(vertices : Array[Point]) -> Expr {
  let mut area = geo_zero()
  for i in 0..<vertices.length() {
    let p = vertices[i]
    let q = vertices[(i + 1) % vertices.length()]
    area = geo_simplify(
      area + p.coords_[0] * q.coords_[1] - q.coords_[0] * p.coords_[1],
    )
  }
  geo_div(area, geo_int(2))
}

///|
fn polygon_perimeter_expr(
  vertices : Array[Point],
) -> Expr raise GeometryError {
  let mut acc = geo_zero()
  for i in 0..<vertices.length() {
    acc = geo_simplify(
      acc + vertices[i].distance(vertices[(i + 1) % vertices.length()]),
    )
  }
  acc
}

///|
fn polygon_sides_array(
  vertices : Array[Point],
) -> Array[Segment] raise GeometryError {
  let out : Array[Segment] = []
  for i in 0..<vertices.length() {
    out.push(segment(vertices[i], vertices[(i + 1) % vertices.length()]))
  }
  out
}

///|
fn polygon_centroid_point(vertices : Array[Point]) -> Point raise GeometryError {
  let area2 = geo_simplify(geo_int(6) * polygon_area_expr(vertices))
  if geo_expr_is_zero(area2) {
    let avg = centroid(vertices) catch { _ => None }
    match avg {
      Some(pt) => return pt
      None =>
        raise GeometryError::ValueError(
          "cannot compute centroid of degenerate polygon",
        )
    }
  }
  let mut cx = geo_zero()
  let mut cy = geo_zero()
  for i in 0..<vertices.length() {
    let p = vertices[i]
    let q = vertices[(i + 1) % vertices.length()]
    let cross = geo_simplify(
      p.coords_[0] * q.coords_[1] - q.coords_[0] * p.coords_[1],
    )
    cx = geo_simplify(cx + (p.coords_[0] + q.coords_[0]) * cross)
    cy = geo_simplify(cy + (p.coords_[1] + q.coords_[1]) * cross)
  }
  point2d(geo_div(cx, area2), geo_div(cy, area2))
}

///|
fn polygon_point_on_boundary(
  vertices : Array[Point],
  pt : Point,
) -> Bool raise GeometryError {
  for side in polygon_sides_array(vertices) {
    if side.contains(pt) {
      return true
    }
  }
  false
}

///|
fn polygon_contains_point_impl(
  vertices : Array[Point],
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  if polygon_point_on_boundary(vertices, pt) {
    return true
  }
  let mut inside = false
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let ay = a.coords_[1]
    let by = b.coords_[1]
    let y_between = match
      (geo_expr_sign(ay - pt.coords_[1]), geo_expr_sign(by - pt.coords_[1])) {
      (Some(sa), Some(sb)) => (sa > 0) != (sb > 0)
      _ =>
        raise GeometryError::Undecidable(
          "cannot decide polygon containment crossing",
        )
    }
    if !y_between {
      continue
    }
    let x_cross = geo_simplify(
      a.coords_[0] +
      geo_div((pt.coords_[1] - ay) * (b.coords_[0] - a.coords_[0]), by - ay),
    )
    match geo_expr_sign(x_cross - pt.coords_[0]) {
      Some(sign) if sign > 0 => inside = !inside
      Some(_) => ()
      None =>
        raise GeometryError::Undecidable(
          "cannot decide polygon containment crossing",
        )
    }
  }
  inside
}

///|
fn polygon_encloses_impl(
  vertices : Array[Point],
  other : GeometryEntity,
) -> Bool raise GeometryError {
  let poly = Polygon::{ vertices_: vertices }
  match other {
    GeometryEntity::Point(point_obj) => poly.encloses_point(point_obj)
    GeometryEntity::Segment(seg_obj) =>
      poly.encloses_point(seg_obj.p1()) &&
      poly.encloses_point(seg_obj.p2()) &&
      polygon_intersection_impl(vertices, geometry_segment(seg_obj)).is_empty()
    GeometryEntity::Line(_) | GeometryEntity::Ray(_) => false
    GeometryEntity::Circle(circle_obj) =>
      poly.encloses_point(circle_obj.center()) &&
      poly.encloses_point(
        try! point2d(
          circle_obj.center().coords_[0] + circle_obj.radius(),
          circle_obj.center().coords_[1],
        ),
      ) &&
      polygon_intersection_impl(vertices, geometry_circle(circle_obj)).is_empty()
    GeometryEntity::Ellipse(ellipse_obj) =>
      poly.encloses_point(ellipse_obj.center()) &&
      poly.encloses_point(
        try! point2d(
          ellipse_obj.center().coords_[0] + ellipse_obj.hradius(),
          ellipse_obj.center().coords_[1],
        ),
      ) &&
      polygon_intersection_impl(vertices, geometry_ellipse(ellipse_obj)).is_empty()
    GeometryEntity::Polygon(poly_obj) =>
      poly_obj
      .vertices()
      .all(fn(vertex) { poly.encloses_point(vertex) catch { _ => false } }) &&
      polygon_intersection_impl(vertices, geometry_polygon(poly_obj)).is_empty()
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly.encloses_point(poly_obj.center()) &&
      (try! poly_obj.vertices()).all(fn(vertex) {
        poly.encloses_point(vertex) catch {
          _ => false
        }
      }) &&
      polygon_intersection_impl(vertices, geometry_regular_polygon(poly_obj)).is_empty()
    GeometryEntity::Triangle(poly_obj) =>
      poly_obj
      .vertices()
      .all(fn(vertex) { poly.encloses_point(vertex) catch { _ => false } }) &&
      polygon_intersection_impl(vertices, geometry_triangle(poly_obj)).is_empty()
    _ => false
  }
}

///|
fn polygon_intersection_impl(
  vertices : Array[Point],
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  let out : Array[GeometryEntity] = []
  for side in polygon_sides_array(vertices) {
    for item in side.intersection(other) {
      match item {
        GeometryEntity::Point(pt) => {
          let mut seen = false
          for prev in out {
            match prev {
              GeometryEntity::Point(old) if old == pt => seen = true
              _ => ()
            }
          }
          if !seen {
            out.push(item)
          }
        }
        _ => out.push(item)
      }
    }
  }
  if out.is_empty() {
    match other {
      GeometryEntity::Point(pt) if polygon_contains_point_impl(vertices, pt) =>
        [geometry_point(pt.with_dim(2))]
      _ => []
    }
  } else {
    out
  }
}

///|
fn polygon_is_convex(vertices : Array[Point]) -> Bool raise GeometryError {
  if vertices.length() < 4 {
    return true
  }
  let mut sign = 0
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let c = vertices[(i + 2) % vertices.length()]
    let ab = geo_sub_coords(b.coords_, a.coords_)
    let bc = geo_sub_coords(c.coords_, b.coords_)
    match geo_expr_sign(geo_cross2(ab, bc)) {
      Some(0) => ()
      Some(cur) =>
        if sign == 0 {
          sign = cur
        } else if sign != cur {
          return false
        }
      None =>
        raise GeometryError::Undecidable("cannot decide polygon convexity")
    }
  }
  true
}

///|
fn polygon_bounds(
  vertices : Array[Point],
) -> (Point, Point) raise GeometryError {
  let mut min_x = vertices[0].coords_[0]
  let mut max_x = vertices[0].coords_[0]
  let mut min_y = vertices[0].coords_[1]
  let mut max_y = vertices[0].coords_[1]
  for item in vertices[1:] {
    if (match geo_expr_sign(item.coords_[0] - min_x) {
        Some(s) => s < 0
        None => false
      }) {
      min_x = item.coords_[0]
    }
    if (match geo_expr_sign(item.coords_[0] - max_x) {
        Some(s) => s > 0
        None => false
      }) {
      max_x = item.coords_[0]
    }
    if (match geo_expr_sign(item.coords_[1] - min_y) {
        Some(s) => s < 0
        None => false
      }) {
      min_y = item.coords_[1]
    }
    if (match geo_expr_sign(item.coords_[1] - max_y) {
        Some(s) => s > 0
        None => false
      }) {
      max_y = item.coords_[1]
    }
  }
  (point2d(min_x, min_y), point2d(max_x, max_y))
}

///|
fn polygon_turn_is_clockwise(
  a : Point,
  b : Point,
  c : Point,
) -> Bool raise GeometryError {
  match geo_expr_sign(hull_orientation(a, b, c)) {
    Some(sign) => sign < 0
    None =>
      raise GeometryError::Undecidable(
        "cannot determine polygon turn orientation",
      )
  }
}

///|
fn polygon_angles_map(
  vertices : Array[Point],
) -> Map[Point, Expr] raise GeometryError {
  let n = vertices.length()
  let out : Map[Point, Expr] = {}
  let orientation = match geo_expr_sign(polygon_area_expr(vertices)) {
    Some(sign) if sign < 0 => -1
    Some(sign) if sign > 0 => 1
    _ => 0
  }
  for i in 0..<n {
    let a = vertices[(i + n - 1) % n]
    let b = vertices[i]
    let c = vertices[(i + 1) % n]
    let lhs = line(b, a)
    let rhs = line(b, c)
    let reflex = lhs.angle_between(geometry_line(rhs))
    let turn = match geo_expr_sign(hull_orientation(a, b, c)) {
      Some(sign) => sign
      None => 0
    }
    let angle = if orientation != 0 && turn != 0 && orientation * turn < 0 {
      geo_simplify(geo_two_pi() - reflex)
    } else {
      geo_simplify(reflex)
    }
    out.set(b, angle)
  }
  out
}

///|
fn line_from_segment(seg : Segment) -> Line raise GeometryError {
  line(seg.p1(), seg.p2())
}

///|
fn perpendicular_line_through(
  base : Line,
  pt : Point,
) -> Line raise GeometryError {
  let point_obj = pt.with_dim(2)
  let direction = geo_perp2(base.direction().coords())
  let next_pt = point2d(
    geo_simplify(point_obj.coords_[0] + direction[0]),
    geo_simplify(point_obj.coords_[1] + direction[1]),
  )
  line(point_obj, next_pt)
}

///|
fn segment_perpendicular_bisector(seg : Segment) -> Line raise GeometryError {
  let mid = seg.midpoint()
  let base = line_from_segment(seg)
  perpendicular_line_through(base, mid)
}

///|
fn segment_perpendicular_from_point(
  seg : Segment,
  pt : Point,
) -> Segment raise GeometryError {
  let base = line_from_segment(seg)
  segment(pt.with_dim(2), base.projection(pt))
}

fn polygon_bisectors_map(
  vertices : Array[Point],
  angles : Map[Point, Expr],
) -> Map[Point, Ray] raise GeometryError {
  let closed : Array[Point] = []
  for vertex in vertices {
    closed.push(vertex)
  }
  closed.push(vertices[0])
  let mut pts = closed
  if polygon_turn_is_clockwise(pts[0], pts[1], pts[2]) {
    let rev : Array[Point] = []
    for i in 0..<pts.length() {
      rev.push(pts[pts.length() - 1 - i])
    }
    pts = rev
  }
  let out : Map[Point, Ray] = {}
  for vertex in vertices {
    let angle = match angles.get(vertex) {
      Some(value) => value
      None =>
        raise GeometryError::ValueError("vertex missing from polygon angle map")
    }
    let mut idx = -1
    for i in 0..<pts.length() {
      if pts[i] == vertex {
        idx = i
        break
      }
    }
    guard idx >= 0 && idx + 1 < pts.length() else {
      raise GeometryError::ValueError("vertex missing from polygon cycle")
    }
    let base_ray = ray(pts[idx], pts[idx + 1])
    let rotated = base_ray.rotate(
      geo_div(angle, geo_int(2)),
      pt=Some(vertex),
    )
    let direction = rotated.direction()
    let unit = direction.truediv(direction.abs())
    out.set(vertex, ray(rotated.p1(), rotated.p1() + unit))
  }
  out
}

///|
fn polygon_distance_to_polygon(
  lhs_vertices : Array[Point],
  rhs_vertices : Array[Point],
) -> Expr raise GeometryError {
  let lhs_poly = Polygon::{ vertices_: lhs_vertices }
  let rhs_poly = Polygon::{ vertices_: rhs_vertices }
  if !lhs_poly.intersection(geometry_polygon(rhs_poly)).is_empty() ||
    lhs_poly.contains_point(rhs_vertices[0]) ||
    rhs_poly.contains_point(lhs_vertices[0]) {
    return geo_zero()
  }
  let mut best : Expr? = None
  for pt in lhs_vertices {
    for side in rhs_poly.sides() {
      let d = side.distance(pt)
      match best {
        None => best = Some(d)
        Some(current) =>
          match geo_expr_sign(d - current) {
            Some(sign) if sign < 0 => best = Some(d)
            _ => ()
          }
      }
    }
  }
  for pt in rhs_vertices {
    for side in lhs_poly.sides() {
      let d = side.distance(pt)
      match best {
        None => best = Some(d)
        Some(current) =>
          match geo_expr_sign(d - current) {
            Some(sign) if sign < 0 => best = Some(d)
            _ => ()
          }
      }
    }
  }
  match best {
    Some(value) => value
    None => geo_zero()
  }
}

///|
pub fn Polygon::vertices(self : Polygon) -> Array[Point] {
  self.vertices_[:].to_array()
}

///|
pub fn Polygon::repr(self : Polygon) -> String {
  "Polygon(" + self.vertices_.map(fn(pt) { pt.repr() }).join(", ") + ")"
}

///|
pub fn Polygon::ambient_dimension(_self : Polygon) -> Int {
  2
}

///|
pub fn Polygon::area(self : Polygon) -> Expr {
  polygon_area_expr(self.vertices_)
}

///|
pub fn Polygon::perimeter(self : Polygon) -> Expr raise GeometryError {
  polygon_perimeter_expr(self.vertices_)
}

///|
pub fn Polygon::centroid(self : Polygon) -> Point raise GeometryError {
  polygon_centroid_point(self.vertices_)
}

///|
pub fn Polygon::sides(self : Polygon) -> Array[Segment] raise GeometryError {
  polygon_sides_array(self.vertices_)
}

///|
pub fn Polygon::bounds(self : Polygon) -> (Point, Point) raise GeometryError {
  polygon_bounds(self.vertices_)
}

///|
pub fn Polygon::angles(
  self : Polygon,
) -> Map[Point, Expr] raise GeometryError {
  polygon_angles_map(self.vertices_)
}

///|
pub fn Polygon::is_convex(self : Polygon) -> Bool raise GeometryError {
  polygon_is_convex(self.vertices_)
}

///|
pub fn Polygon::contains_point(
  self : Polygon,
  pt : Point,
) -> Bool raise GeometryError {
  polygon_contains_point_impl(self.vertices_, pt)
}

///|
pub fn Polygon::encloses_point(
  self : Polygon,
  pt : Point,
) -> Bool raise GeometryError {
  let pt = pt.with_dim(2)
  if pt == self.vertices_[0] || polygon_point_on_boundary(self.vertices_, pt) {
    return false
  }
  polygon_contains_point_impl(self.vertices_, pt)
}

///|
pub fn Polygon::encloses(
  self : Polygon,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  polygon_encloses_impl(self.vertices_, other)
}

///|
pub fn Polygon::plot_interval(
  _self : Polygon,
  parameter? : Expr = symbol("t"),
) -> Array[Expr] {
  [parameter, geo_zero(), geo_one()]
}

///|
pub fn Polygon::arbitrary_point(
  self : Polygon,
  parameter? : Expr = symbol("t"),
) -> Point raise GeometryError {
  let perimeter = self.perimeter()
  let x_cases : Array[Expr] = []
  let y_cases : Array[Expr] = []
  let mut start = geo_zero()
  let sides = self.sides()
  for side in sides {
    let side_len = side.length()
    let frac = geo_div(side_len, perimeter)
    let end_ = geo_simplify(start + frac)
    let u = geo_div(parameter - start, frac)
    let dx = side.p2().coords_[0] - side.p1().coords_[0]
    let dy = side.p2().coords_[1] - side.p1().coords_[1]
    let px = geo_simplify(side.p1().coords_[0] + u * dx)
    let py = geo_simplify(side.p1().coords_[1] + u * dy)
    let cond = if geo_expr_eq(end_, geo_one()) {
      @symcore.function("And", [
        @symcore.raw_function("LessThan", [start, parameter]),
        @symcore.raw_function("LessThan", [parameter, end_]),
      ])
    } else {
      @symcore.function("And", [
        @symcore.raw_function("LessThan", [start, parameter]),
        @symcore.raw_function("StrictLessThan", [parameter, end_]),
      ])
    }
    x_cases.push(px)
    x_cases.push(cond)
    y_cases.push(py)
    y_cases.push(cond)
    start = end_
  }
  x_cases.push(self.vertices_[0].coords_[0])
  x_cases.push(symbol("True"))
  y_cases.push(self.vertices_[0].coords_[1])
  y_cases.push(symbol("True"))
  point2d(
    @symcore.raw_function("Piecewise", x_cases),
    @symcore.raw_function("Piecewise", y_cases),
  )
}

///|
pub fn Polygon::parameter_value(
  self : Polygon,
  other : Point,
  t : Expr,
) -> Map[Expr, Expr] raise GeometryError {
  let point_obj = other.with_dim(2)
  let perimeter = self.perimeter()
  let out : Map[Expr, Expr] = {}
  let mut start = geo_zero()
  let sides = self.sides()
  for side in sides {
    if side.contains(point_obj) {
      let side_len = side.length()
      let frac = geo_div(side_len, perimeter)
      let u = linear_param_for_point(geometry_segment(side), point_obj)
      out.set(t, geo_simplify(start + u * frac))
      return out
    }
    start = geo_simplify(start + geo_div(side.length(), perimeter))
  }
  raise GeometryError::ValueError("point is not on polygon")
}

///|
pub fn Polygon::intersection(
  self : Polygon,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  polygon_intersection_impl(self.vertices_, other)
}

///|
pub fn Polygon::distance(
  self : Polygon,
  other : GeometryEntity,
) -> Expr raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) =>
      if self.contains_point(point_obj) {
        geo_zero()
      } else {
        let mut best : Expr? = None
        let sides = self.sides()
        for side in sides {
          let d = side.distance(point_obj)
          match best {
            None => best = Some(d)
            Some(current) =>
              match geo_expr_sign(d - current) {
                Some(sign) if sign < 0 => best = Some(d)
                _ => ()
              }
          }
        }
        match best {
          Some(value) => value
          None => geo_zero()
        }
      }
    GeometryEntity::Polygon(poly_obj) =>
      polygon_distance_to_polygon(self.vertices_, poly_obj.vertices())
    GeometryEntity::RegularPolygon(poly_obj) =>
      polygon_distance_to_polygon(self.vertices_, poly_obj.vertices())
    GeometryEntity::Triangle(poly_obj) =>
      polygon_distance_to_polygon(self.vertices_, poly_obj.vertices())
    _ =>
      raise GeometryError::TypeError(
        "polygon distance currently supports Point/Polygon-like entities",
      )
  }
}

///|
pub fn Polygon::bisectors(
  self : Polygon,
) -> Map[Point, Ray] raise GeometryError {
  let angles = self.angles()
  polygon_bisectors_map(self.vertices_, angles)
}

///|
pub fn Polygon::translate(
  self : Polygon,
  offsets : Array[Expr],
) -> Polygon raise GeometryError {
  let vertices : Array[Point] = []
  for pt in self.vertices_ {
    vertices.push(pt.translate(offsets))
  }
  Polygon::{ vertices_: vertices }
}

///|
pub fn Polygon::rotate(
  self : Polygon,
  angle : Expr,
  pt? : Point? = None,
) -> Polygon raise GeometryError {
  let vertices : Array[Point] = []
  for vertex in self.vertices_ {
    vertices.push(vertex.rotate(angle, pt~))
  }
  Polygon::{ vertices_: vertices }
}

///|
pub fn Polygon::scale(
  self : Polygon,
  factors : Array[Expr],
  pt? : Point? = None,
) -> Polygon raise GeometryError {
  let vertices : Array[Point] = []
  for vertex in self.vertices_ {
    vertices.push(vertex.scale(factors, pt~))
  }
  Polygon::{ vertices_: vertices }
}

///|
fn regular_polygon_vertices_of(
  poly : RegularPolygon,
) -> Array[Point] raise GeometryError {
  let out : Array[Point] = []
  for i in 0..<poly.n_ {
    let angle = geo_simplify(
      poly.rotation_ +
      geo_div(geo_int(2 * i), geo_int(poly.n_)) * symbol("pi"),
    )
    out.push(
      point2d(
        geo_simplify(
          poly.center_.coords_[0] + poly.radius_ * @symelem.cos(angle),
        ),
        geo_simplify(
          poly.center_.coords_[1] + poly.radius_ * @symelem.sin(angle),
        ),
      ),
    )
  }
  out
}

///|
fn regular_polygon_as_polygon(
  poly : RegularPolygon,
) -> Polygon raise GeometryError {
  Polygon::{ vertices_: regular_polygon_vertices_of(poly) }
}

///|
pub fn RegularPolygon::repr(self : RegularPolygon) -> String {
  "RegularPolygon(" +
  self.center_.repr() +
  ", " +
  geo_expr_text(self.radius_) +
  ", " +
  self.n_.to_string() +
  ", " +
  geo_expr_text(self.rotation_) +
  ")"
}

///|
pub fn RegularPolygon::ambient_dimension(_self : RegularPolygon) -> Int {
  2
}

///|
pub fn RegularPolygon::center(self : RegularPolygon) -> Point {
  self.center_
}

///|
pub fn RegularPolygon::args(
  self : RegularPolygon,
) -> (Point, Expr, Int, Expr) {
  (self.center_, self.radius_, self.n_, self.rotation_)
}

///|
pub fn RegularPolygon::radius(self : RegularPolygon) -> Expr {
  self.radius_
}

///|
pub fn RegularPolygon::rotation(self : RegularPolygon) -> Expr {
  self.rotation_
}

///|
pub fn RegularPolygon::vertices(
  self : RegularPolygon,
) -> Array[Point] raise GeometryError {
  regular_polygon_vertices_of(self)
}

///|
pub fn RegularPolygon::area(self : RegularPolygon) -> Expr {
  geo_div(
    geo_int(self.n_) *
    self.radius_ *
    self.radius_ *
    @symelem.sin(geo_div(geo_int(2), geo_int(self.n_)) * symbol("pi")),
    geo_int(2),
  )
}

///|
pub fn RegularPolygon::length(self : RegularPolygon) -> Expr {
  geo_simplify(
    geo_int(2) *
    self.radius_ *
    @symelem.sin(geo_div(symbol("pi"), geo_int(self.n_))),
  )
}

///|
pub fn RegularPolygon::perimeter(self : RegularPolygon) -> Expr {
  geo_simplify(geo_int(self.n_) * self.length())
}

///|
pub fn RegularPolygon::apothem(self : RegularPolygon) -> Expr {
  geo_simplify(
    self.radius_ *
    @symelem.cos(geo_div(symbol("pi"), geo_int(self.n_))),
  )
}

///|
pub fn RegularPolygon::inradius(self : RegularPolygon) -> Expr {
  self.apothem()
}

///|
pub fn RegularPolygon::interior_angle(self : RegularPolygon) -> Expr {
  geo_div(geo_int(self.n_ - 2) * geo_pi(), geo_int(self.n_))
}

///|
pub fn RegularPolygon::exterior_angle(self : RegularPolygon) -> Expr {
  geo_div(geo_two_pi(), geo_int(self.n_))
}

///|
pub fn RegularPolygon::circumradius(self : RegularPolygon) -> Expr {
  self.radius_
}

///|
pub fn RegularPolygon::circumcenter(self : RegularPolygon) -> Point {
  self.center_
}

///|
pub fn RegularPolygon::circumcircle(self : RegularPolygon) -> Circle {
  Circle::{ center_: self.center_, radius_: self.radius_ }
}

///|
pub fn RegularPolygon::incircle(self : RegularPolygon) -> Circle {
  Circle::{ center_: self.center_, radius_: self.apothem() }
}

///|
pub fn RegularPolygon::angles(
  self : RegularPolygon,
) -> Map[Point, Expr] raise GeometryError {
  let out : Map[Point, Expr] = {}
  let ang = self.interior_angle()
  let vertices = self.vertices()
  for vertex in vertices {
    out.set(vertex, ang)
  }
  out
}

///|
pub fn RegularPolygon::encloses_point(
  self : RegularPolygon,
  pt : Point,
) -> Bool raise GeometryError {
  let point_obj = pt.with_dim(2)
  let dist = self.center_.distance(point_obj)
  match geo_expr_sign(dist - self.inradius()) {
    Some(sign) if sign < 0 => true
    Some(sign) if sign > 0 =>
      match geo_expr_sign(dist - self.circumradius()) {
        Some(inner) =>
          inner < 0 &&
          regular_polygon_as_polygon(self).encloses_point(point_obj)
        None =>
          raise GeometryError::Undecidable(
            "cannot decide regular polygon containment",
          )
      }
    Some(_) => false
    None => regular_polygon_as_polygon(self).encloses_point(point_obj)
  }
}

///|
pub fn RegularPolygon::encloses(
  self : RegularPolygon,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  regular_polygon_as_polygon(self).encloses(other)
}

///|
pub fn RegularPolygon::spin(
  self : RegularPolygon,
  angle : Expr,
) -> RegularPolygon {
  RegularPolygon::{
    center_: self.center_,
    radius_: self.radius_,
    n_: self.n_,
    rotation_: geo_simplify(self.rotation_ + angle),
  }
}

///|
pub fn RegularPolygon::rotate(
  self : RegularPolygon,
  angle : Expr,
  pt? : Point? = None,
) -> RegularPolygon raise GeometryError {
  RegularPolygon::{
    center_: self.center_.rotate(angle, pt~),
    radius_: self.radius_,
    n_: self.n_,
    rotation_: geo_simplify(self.rotation_ + angle),
  }
}

///|
pub fn RegularPolygon::translate(
  self : RegularPolygon,
  offsets : Array[Expr],
) -> RegularPolygon raise GeometryError {
  RegularPolygon::{
    center_: self.center_.translate(offsets),
    radius_: self.radius_,
    n_: self.n_,
    rotation_: self.rotation_,
  }
}

///|
pub fn RegularPolygon::scale(
  self : RegularPolygon,
  x : Expr,
  y? : Expr = geo_one(),
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  if geo_expr_eq(x, y) {
    return geometry_regular_polygon(RegularPolygon::{
      center_: self.center_.scale([x, y], pt~),
      radius_: geo_simplify(self.radius_ * x),
      n_: self.n_,
      rotation_: self.rotation_,
    })
  }
  let poly = regular_polygon_as_polygon(self)
  geometry_polygon(poly.scale([x, y], pt~))
}

///|
pub fn RegularPolygon::intersection(
  self : RegularPolygon,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  regular_polygon_as_polygon(self).intersection(other)
}

///|
pub fn RegularPolygon::parameter_value(
  self : RegularPolygon,
  other : Point,
  t : Expr,
) -> Map[Expr, Expr] raise GeometryError {
  regular_polygon_as_polygon(self).parameter_value(other, t)
}

///|
pub fn Triangle::vertices(self : Triangle) -> Array[Point] {
  self.vertices_[:].to_array()
}

///|
pub fn Triangle::repr(self : Triangle) -> String {
  "Triangle(" + self.vertices_.map(fn(pt) { pt.repr() }).join(", ") + ")"
}

///|
pub fn Triangle::ambient_dimension(_self : Triangle) -> Int {
  2
}

///|
fn triangle_as_polygon_of(poly : Triangle) -> Polygon {
  Polygon::{ vertices_: poly.vertices_ }
}

///|
pub fn Triangle::area(self : Triangle) -> Expr {
  triangle_as_polygon_of(self).area()
}

///|
pub fn Triangle::perimeter(
  self : Triangle,
) -> Expr raise GeometryError {
  triangle_as_polygon_of(self).perimeter()
}

///|
pub fn Triangle::centroid(self : Triangle) -> Point raise GeometryError {
  triangle_as_polygon_of(self).centroid()
}

///|
pub fn Triangle::angles(
  self : Triangle,
) -> Map[Point, Expr] raise GeometryError {
  polygon_angles_map(self.vertices_)
}

///|
pub fn Triangle::sides(self : Triangle) -> Array[Segment] raise GeometryError {
  triangle_as_polygon_of(self).sides()
}

///|
pub fn Triangle::contains_point(
  self : Triangle,
  pt : Point,
) -> Bool raise GeometryError {
  triangle_as_polygon_of(self).contains_point(pt)
}

///|
pub fn Triangle::encloses(
  self : Triangle,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  triangle_as_polygon_of(self).encloses(other)
}

///|
pub fn Triangle::intersection(
  self : Triangle,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  triangle_as_polygon_of(self).intersection(other)
}

///|
pub fn Triangle::translate(
  self : Triangle,
  offsets : Array[Expr],
) -> Triangle raise GeometryError {
  let vertices : Array[Point] = []
  for vertex in self.vertices_ {
    vertices.push(vertex.translate(offsets))
  }
  Triangle::{ vertices_: vertices }
}

///|
pub fn Triangle::rotate(
  self : Triangle,
  angle : Expr,
  pt? : Point? = None,
) -> Triangle raise GeometryError {
  let vertices : Array[Point] = []
  for vertex in self.vertices_ {
    vertices.push(vertex.rotate(angle, pt~))
  }
  Triangle::{ vertices_: vertices }
}

///|
pub fn Triangle::scale(
  self : Triangle,
  factors : Array[Expr],
  pt? : Point? = None,
) -> Triangle raise GeometryError {
  let vertices : Array[Point] = []
  for vertex in self.vertices_ {
    vertices.push(vertex.scale(factors, pt~))
  }
  Triangle::{ vertices_: vertices }
}

///|
fn triangle_side_lengths_of(
  poly : Triangle,
) -> Array[Expr] raise GeometryError {
  let a = poly.vertices_[1].distance(poly.vertices_[2])
  let b = poly.vertices_[0].distance(poly.vertices_[2])
  let c = poly.vertices_[0].distance(poly.vertices_[1])
  [a, b, c]
}

///|
fn triangle_angles_of(
  poly : Triangle,
) -> Array[Expr] raise GeometryError {
  let angle_map = polygon_angles_map(poly.vertices_)
  let out : Array[Expr] = []
  for vertex in poly.vertices_ {
    match angle_map.get(vertex) {
      Some(value) => out.push(value)
      None =>
        raise GeometryError::ValueError(
          "vertex missing from triangle angle map",
        )
    }
  }
  out
}

///|
pub fn Triangle::is_equilateral(self : Triangle) -> Bool raise GeometryError {
  let s = triangle_side_lengths_of(self)
  geo_expr_eq(s[0], s[1]) && geo_expr_eq(s[1], s[2])
}

///|
pub fn Triangle::is_isosceles(self : Triangle) -> Bool raise GeometryError {
  let s = triangle_side_lengths_of(self)
  geo_expr_eq(s[0], s[1]) || geo_expr_eq(s[1], s[2]) || geo_expr_eq(s[0], s[2])
}

///|
pub fn Triangle::is_scalene(self : Triangle) -> Bool raise GeometryError {
  !self.is_isosceles()
}

///|
pub fn Triangle::is_right(self : Triangle) -> Bool {
  let pts = self.vertices_
  for i in 0..<3 {
    let a = pts[i]
    let b = pts[(i + 1) % 3]
    let c = pts[(i + 2) % 3]
    let ab = geo_sub_coords(b.coords_, a.coords_)
    let ac = geo_sub_coords(c.coords_, a.coords_)
    if geo_expr_is_zero(geo_dot(ab, ac)) {
      return true
    }
  }
  false
}

///|
pub fn Triangle::is_similar(
  self : Triangle,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  let rhs = match other {
    GeometryEntity::Triangle(value) => value
    _ => return false
  }
  let lhs = triangle_angles_of(self)
  let rhs_angles = triangle_angles_of(rhs)
  let rhs0 = rhs_angles[0]
  let rhs1 = rhs_angles[1]
  let rhs2 = rhs_angles[2]
  let similar_perm = fn(
    u1 : Expr,
    u2 : Expr,
    u3 : Expr,
  ) -> Bool {
    geo_expr_eq(u1, rhs0) && geo_expr_eq(u2, rhs1) && geo_expr_eq(u3, rhs2)
  }
  similar_perm(lhs[0], lhs[1], lhs[2]) ||
  similar_perm(lhs[0], lhs[2], lhs[1]) ||
  similar_perm(lhs[1], lhs[0], lhs[2]) ||
  similar_perm(lhs[1], lhs[2], lhs[0]) ||
  similar_perm(lhs[2], lhs[0], lhs[1]) ||
  similar_perm(lhs[2], lhs[1], lhs[0])
}

///|
pub fn Triangle::circumcenter(self : Triangle) -> Point raise GeometryError {
  let sides = self.sides()
  let a = segment_perpendicular_bisector(sides[0])
  let b = segment_perpendicular_bisector(sides[1])
  match a.intersection(geometry_line(b)) {
    [GeometryEntity::Point(pt), ..] => pt
    _ =>
      raise GeometryError::ValueError(
        "triangle circumcenter could not be determined",
      )
  }
}

///|
pub fn Triangle::circumradius(
  self : Triangle,
) -> Expr raise GeometryError {
  self.circumcenter().distance(self.vertices_[0])
}

///|
pub fn Triangle::circumcircle(self : Triangle) -> Circle raise GeometryError {
  Circle::{ center_: self.circumcenter(), radius_: self.circumradius() }
}

///|
pub fn Triangle::incenter(self : Triangle) -> Point raise GeometryError {
  let s = triangle_side_lengths_of(self)
  let sum = geo_simplify(s[0] + s[1] + s[2])
  point2d(
    geo_div(
      s[0] * self.vertices_[0].coords_[0] +
      s[1] * self.vertices_[1].coords_[0] +
      s[2] * self.vertices_[2].coords_[0],
      sum,
    ),
    geo_div(
      s[0] * self.vertices_[0].coords_[1] +
      s[1] * self.vertices_[1].coords_[1] +
      s[2] * self.vertices_[2].coords_[1],
      sum,
    ),
  )
}

///|
pub fn Triangle::inradius(self : Triangle) -> Expr raise GeometryError {
  geo_div(geo_simplify(geo_int(2) * self.area()), self.perimeter())
}

///|
pub fn Triangle::incircle(self : Triangle) -> Circle raise GeometryError {
  Circle::{ center_: self.incenter(), radius_: self.inradius() }
}

///|
pub fn Triangle::altitudes(
  self : Triangle,
) -> Map[Point, Segment] raise GeometryError {
  let sides = self.sides()
  let vertices = self.vertices_
  let out : Map[Point, Segment] = {}
  out.set(
    vertices[0],
    segment_perpendicular_from_point(sides[1], vertices[0]),
  )
  out.set(
    vertices[1],
    segment_perpendicular_from_point(sides[2], vertices[1]),
  )
  out.set(
    vertices[2],
    segment_perpendicular_from_point(sides[0], vertices[2]),
  )
  out
}

///|
pub fn Triangle::orthocenter(self : Triangle) -> Point raise GeometryError {
  let altitudes = self.altitudes()
  let vertices = self.vertices_
  let a = line_from_segment(altitudes[vertices[0]])
  let b = line_from_segment(altitudes[vertices[1]])
  match a.intersection(geometry_line(b)) {
    [GeometryEntity::Point(pt), ..] => pt
    _ =>
      raise GeometryError::ValueError(
        "triangle orthocenter could not be determined",
      )
  }
}

///|
pub fn Triangle::bisectors(
  self : Triangle,
) -> Map[Point, Segment] raise GeometryError {
  let sides = self.sides()
  let vertices = self.vertices_
  let center = self.incenter()
  let out : Map[Point, Segment] = {}
  let hit0 = match
    line(vertices[0], center).intersection(
      geometry_line(line_from_segment(sides[1])),
    ) {
    [GeometryEntity::Point(pt), ..] => pt
    _ => center
  }
  let hit1 = match
    line(vertices[1], center).intersection(
      geometry_line(line_from_segment(sides[2])),
    ) {
    [GeometryEntity::Point(pt), ..] => pt
    _ => center
  }
  let hit2 = match
    line(vertices[2], center).intersection(
      geometry_line(line_from_segment(sides[0])),
    ) {
    [GeometryEntity::Point(pt), ..] => pt
    _ => center
  }
  out.set(vertices[0], segment(vertices[0], hit0))
  out.set(vertices[1], segment(vertices[1], hit1))
  out.set(vertices[2], segment(vertices[2], hit2))
  out
}

///|
pub fn Triangle::exradii(
  self : Triangle,
) -> Map[Segment, Expr] raise GeometryError {
  let sides = self.sides()
  let a = sides[0].length()
  let b = sides[1].length()
  let c = sides[2].length()
  let s = geo_div(a + b + c, geo_int(2))
  let area = self.area()
  let out : Map[Segment, Expr] = {}
  out.set(sides[0], geo_simplify(geo_div(area, s - a)))
  out.set(sides[1], geo_simplify(geo_div(area, s - b)))
  out.set(sides[2], geo_simplify(geo_div(area, s - c)))
  out
}

///|
pub fn Triangle::excenters(
  self : Triangle,
) -> Map[Segment, Point] raise GeometryError {
  let sides = self.sides()
  let vertices = self.vertices_
  let a = sides[1].length()
  let b = sides[2].length()
  let c = sides[0].length()
  let x0 = vertices[0].coords_[0]
  let x1 = vertices[1].coords_[0]
  let x2 = vertices[2].coords_[0]
  let y0 = vertices[0].coords_[1]
  let y1 = vertices[1].coords_[1]
  let y2 = vertices[2].coords_[1]
  let out : Map[Segment, Point] = {}
  out.set(
    sides[0],
    point2d(
      geo_simplify(
        geo_div((geo_zero() - a) * x0 + b * x1 + c * x2, geo_zero() - a + b + c),
      ),
      geo_simplify(
        geo_div((geo_zero() - a) * y0 + b * y1 + c * y2, geo_zero() - a + b + c),
      ),
    ),
  )
  out.set(
    sides[1],
    point2d(
      geo_simplify(geo_div(a * x0 - b * x1 + c * x2, a - b + c)),
      geo_simplify(geo_div(a * y0 - b * y1 + c * y2, a - b + c)),
    ),
  )
  out.set(
    sides[2],
    point2d(
      geo_simplify(geo_div(a * x0 + b * x1 - c * x2, a + b - c)),
      geo_simplify(geo_div(a * y0 + b * y1 - c * y2, a + b - c)),
    ),
  )
  out
}

///|
pub fn Triangle::medians(
  self : Triangle,
) -> Map[Point, Segment] raise GeometryError {
  let sides = self.sides()
  let vertices = self.vertices_
  let out : Map[Point, Segment] = {}
  out.set(vertices[0], segment(vertices[0], sides[1].midpoint()))
  out.set(vertices[1], segment(vertices[1], sides[2].midpoint()))
  out.set(vertices[2], segment(vertices[2], sides[0].midpoint()))
  out
}

///|
pub fn Triangle::medial(self : Triangle) -> Triangle raise GeometryError {
  let sides = self.sides()
  triangle(
    sides[0].midpoint(),
    sides[1].midpoint(),
    sides[2].midpoint(),
  )
}

///|
pub fn Triangle::nine_point_circle(
  self : Triangle,
) -> Circle raise GeometryError {
  let medial = self.medial()
  medial.circumcircle()
}

///|
pub fn Triangle::eulerline(
  self : Triangle,
) -> GeometryEntity raise GeometryError {
  if self.is_equilateral() {
    return geometry_point(self.orthocenter())
  }
  geometry_line(line(self.orthocenter(), self.circumcenter()))
}
