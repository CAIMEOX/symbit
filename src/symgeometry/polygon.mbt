///|
/// A polygonal closed path in the plane.
pub struct Polygon {
  vertices_ : Array[Point]
} derive(Eq)

///|
/// Regular polygon determined by center, circumradius, side count and rotation.
pub struct RegularPolygon {
  center_ : Point
  radius_ : @symcore.Expr
  n_ : Int
  rotation_ : @symcore.Expr
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
  radius : @symcore.Expr,
  n : Int,
  rotation? : @symcore.Expr = geo_zero(),
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
fn polygon_area_expr(vertices : Array[Point]) -> @symcore.Expr {
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
) -> @symcore.Expr raise GeometryError {
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
  (try! point2d(min_x, min_y), try! point2d(max_x, max_y))
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
pub fn Polygon::ambient_dimension(self : Polygon) -> Int {
  2
}

///|
pub fn Polygon::area(self : Polygon) -> @symcore.Expr {
  polygon_area_expr(self.vertices_)
}

///|
pub fn Polygon::perimeter(self : Polygon) -> @symcore.Expr raise GeometryError {
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
pub fn Polygon::intersection(
  self : Polygon,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  polygon_intersection_impl(self.vertices_, other)
}

///|
pub fn Polygon::translate(
  self : Polygon,
  offsets : Array[@symcore.Expr],
) -> Polygon raise GeometryError {
  Polygon::{
    vertices_: self.vertices_.map(fn(pt) { try! pt.translate(offsets) }),
  }
}

///|
pub fn Polygon::rotate(
  self : Polygon,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Polygon raise GeometryError {
  Polygon::{
    vertices_: self.vertices_.map(fn(vertex) { try! vertex.rotate(angle, pt~) }),
  }
}

///|
pub fn Polygon::scale(
  self : Polygon,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Polygon raise GeometryError {
  Polygon::{
    vertices_: self.vertices_.map(fn(vertex) { try! vertex.scale(factors, pt~) }),
  }
}

///|
fn regular_polygon_vertices_of(
  poly : RegularPolygon,
) -> Array[Point] raise GeometryError {
  let out : Array[Point] = []
  for i in 0..<poly.n_ {
    let angle = geo_simplify(
      poly.rotation_ +
      geo_div(geo_int(2 * i), geo_int(poly.n_)) * @symcore.symbol("pi"),
    )
    out.push(
      try! point2d(
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
pub fn RegularPolygon::ambient_dimension(self : RegularPolygon) -> Int {
  2
}

///|
pub fn RegularPolygon::center(self : RegularPolygon) -> Point {
  self.center_
}

///|
pub fn RegularPolygon::radius(self : RegularPolygon) -> @symcore.Expr {
  self.radius_
}

///|
pub fn RegularPolygon::rotation(self : RegularPolygon) -> @symcore.Expr {
  self.rotation_
}

///|
pub fn RegularPolygon::vertices(
  self : RegularPolygon,
) -> Array[Point] raise GeometryError {
  regular_polygon_vertices_of(self)
}

///|
pub fn RegularPolygon::area(self : RegularPolygon) -> @symcore.Expr {
  geo_div(
    geo_int(self.n_) *
    self.radius_ *
    self.radius_ *
    @symelem.sin(geo_div(geo_int(2), geo_int(self.n_)) * @symcore.symbol("pi")),
    geo_int(2),
  )
}

///|
pub fn RegularPolygon::length(self : RegularPolygon) -> @symcore.Expr {
  geo_simplify(
    geo_int(2) *
    self.radius_ *
    @symelem.sin(geo_div(@symcore.symbol("pi"), geo_int(self.n_))),
  )
}

///|
pub fn RegularPolygon::perimeter(self : RegularPolygon) -> @symcore.Expr {
  geo_simplify(geo_int(self.n_) * self.length())
}

///|
pub fn RegularPolygon::apothem(self : RegularPolygon) -> @symcore.Expr {
  geo_simplify(
    self.radius_ *
    @symelem.cos(geo_div(@symcore.symbol("pi"), geo_int(self.n_))),
  )
}

///|
pub fn RegularPolygon::inradius(self : RegularPolygon) -> @symcore.Expr {
  self.apothem()
}

///|
pub fn RegularPolygon::circumradius(self : RegularPolygon) -> @symcore.Expr {
  self.radius_
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
pub fn RegularPolygon::spin(
  self : RegularPolygon,
  angle : @symcore.Expr,
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
  angle : @symcore.Expr,
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
  offsets : Array[@symcore.Expr],
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
  x : @symcore.Expr,
  y? : @symcore.Expr = geo_one(),
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
pub fn Triangle::vertices(self : Triangle) -> Array[Point] {
  self.vertices_[:].to_array()
}

///|
pub fn Triangle::repr(self : Triangle) -> String {
  "Triangle(" + self.vertices_.map(fn(pt) { pt.repr() }).join(", ") + ")"
}

///|
pub fn Triangle::ambient_dimension(self : Triangle) -> Int {
  2
}

///|
fn triangle_as_polygon_of(poly : Triangle) -> Polygon {
  Polygon::{ vertices_: poly.vertices_ }
}

///|
pub fn Triangle::area(self : Triangle) -> @symcore.Expr {
  triangle_as_polygon_of(self).area()
}

///|
pub fn Triangle::perimeter(
  self : Triangle,
) -> @symcore.Expr raise GeometryError {
  triangle_as_polygon_of(self).perimeter()
}

///|
pub fn Triangle::centroid(self : Triangle) -> Point raise GeometryError {
  triangle_as_polygon_of(self).centroid()
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
pub fn Triangle::intersection(
  self : Triangle,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  triangle_as_polygon_of(self).intersection(other)
}

///|
pub fn Triangle::translate(
  self : Triangle,
  offsets : Array[@symcore.Expr],
) -> Triangle raise GeometryError {
  Triangle::{
    vertices_: self.vertices_.map(fn(vertex) { try! vertex.translate(offsets) }),
  }
}

///|
pub fn Triangle::rotate(
  self : Triangle,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> Triangle raise GeometryError {
  Triangle::{
    vertices_: self.vertices_.map(fn(vertex) { try! vertex.rotate(angle, pt~) }),
  }
}

///|
pub fn Triangle::scale(
  self : Triangle,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> Triangle raise GeometryError {
  Triangle::{
    vertices_: self.vertices_.map(fn(vertex) { try! vertex.scale(factors, pt~) }),
  }
}

///|
fn triangle_side_lengths_of(
  poly : Triangle,
) -> Array[@symcore.Expr] raise GeometryError {
  let a = poly.vertices_[1].distance(poly.vertices_[2])
  let b = poly.vertices_[0].distance(poly.vertices_[2])
  let c = poly.vertices_[0].distance(poly.vertices_[1])
  [a, b, c]
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
  !(try! self.is_isosceles())
}

///|
pub fn Triangle::is_right(self : Triangle) -> Bool raise GeometryError {
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
pub fn Triangle::circumcenter(self : Triangle) -> Point raise GeometryError {
  let a = self.vertices_[0]
  let b = self.vertices_[1]
  let c = self.vertices_[2]
  let d = geo_int(2) *
    (
      a.coords_[0] * (b.coords_[1] - c.coords_[1]) +
      b.coords_[0] * (c.coords_[1] - a.coords_[1]) +
      c.coords_[0] * (a.coords_[1] - b.coords_[1])
    )
  point2d(
    geo_div(
      ((a.coords_[0] ^ geo_int(2)) + (a.coords_[1] ^ geo_int(2))) *
      (b.coords_[1] - c.coords_[1]) +
      ((b.coords_[0] ^ geo_int(2)) + (b.coords_[1] ^ geo_int(2))) *
      (c.coords_[1] - a.coords_[1]) +
      ((c.coords_[0] ^ geo_int(2)) + (c.coords_[1] ^ geo_int(2))) *
      (a.coords_[1] - b.coords_[1]),
      d,
    ),
    geo_div(
      ((a.coords_[0] ^ geo_int(2)) + (a.coords_[1] ^ geo_int(2))) *
      (c.coords_[0] - b.coords_[0]) +
      ((b.coords_[0] ^ geo_int(2)) + (b.coords_[1] ^ geo_int(2))) *
      (a.coords_[0] - c.coords_[0]) +
      ((c.coords_[0] ^ geo_int(2)) + (c.coords_[1] ^ geo_int(2))) *
      (b.coords_[0] - a.coords_[0]),
      d,
    ),
  )
}

///|
pub fn Triangle::circumradius(
  self : Triangle,
) -> @symcore.Expr raise GeometryError {
  self.circumcenter().distance(self.vertices_[0])
}

///|
pub fn Triangle::circumcircle(self : Triangle) -> Circle raise GeometryError {
  Circle::{ center_: self.circumcenter(), radius_: try! self.circumradius() }
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
pub fn Triangle::inradius(self : Triangle) -> @symcore.Expr raise GeometryError {
  geo_div(geo_simplify(geo_int(2) * self.area()), self.perimeter())
}

///|
pub fn Triangle::incircle(self : Triangle) -> Circle raise GeometryError {
  Circle::{ center_: self.incenter(), radius_: try! self.inradius() }
}
