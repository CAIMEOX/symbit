///|
/// Find the unique symbol named `x` inside `equation`.
pub fn find(x : String, equation : Expr) -> Expr raise GeometryError {
  let seen : Map[String, Bool] = Map([])
  geo_collect_symbols(equation, seen)
  let matches : Array[String] = []
  for entry in seen {
    if entry.0 == x {
      matches.push(entry.0)
    }
  }
  if matches.is_empty() {
    raise GeometryError::ValueError("could not find " + x)
  }
  Expr::Symbol(matches[0])
}

///|
pub fn are_similar(
  lhs : GeometryEntity,
  rhs : GeometryEntity,
) -> Bool raise GeometryError {
  if lhs == rhs {
    return true
  }
  if lhs.is_similar(rhs) {
    return true
  }
  rhs.is_similar(lhs)
}

///|
pub fn ordered_points(points : Array[Point]) -> Array[Point] {
  let out = points[:].to_owned()
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      let cmp = point_order_cmp(out[i], out[j]) catch {
        _ => out[i].repr().compare(out[j].repr())
      }
      if cmp > 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn point_order_cmp(lhs : Point, rhs : Point) -> Int raise GeometryError {
  let pair = geo_normalize_dim([lhs, rhs])
  let a = pair[0].with_dim(2)
  let b = pair[1].with_dim(2)
  match geo_expr_sign(a.coords_[0] - b.coords_[0]) {
    Some(sign) if sign < 0 => -1
    Some(sign) if sign > 0 => 1
    _ =>
      match geo_expr_sign(a.coords_[1] - b.coords_[1]) {
        Some(sign) if sign < 0 => -1
        Some(sign) if sign > 0 => 1
        _ => a.repr().compare(b.repr())
      }
  }
}

///|
fn sort_points_lex(points : Array[Point]) -> Array[Point] raise GeometryError {
  let out = points[:].to_owned()
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if point_order_cmp(out[i], out[j]) > 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn ordered_pair(pair : (Point, Point)) -> (Point, Point) raise GeometryError {
  if point_order_cmp(pair.0, pair.1) <= 0 {
    pair
  } else {
    (pair.1, pair.0)
  }
}

///|
fn push_unique_point(points : Array[Point], pt : Point) -> Unit {
  for item in points {
    if item == pt {
      return
    }
  }
  points.push(pt)
}

///|
fn push_unique_pair(
  pairs : Array[(Point, Point)],
  pair : (Point, Point),
) -> Unit raise GeometryError {
  let pair = ordered_pair(pair)
  for item in pairs {
    if item == pair {
      return
    }
  }
  pairs.push(pair)
}

///|
fn geometry_entity_points(
  item : GeometryEntity,
) -> Array[Point] raise GeometryError {
  match item {
    GeometryEntity::Point(point_obj) => [point_obj.with_dim(2)]
    GeometryEntity::Segment(seg_obj) =>
      [seg_obj.p1().with_dim(2), seg_obj.p2().with_dim(2)]
    GeometryEntity::Polygon(poly_obj) => poly_obj.vertices()
    GeometryEntity::RegularPolygon(poly_obj) => poly_obj.vertices()
    GeometryEntity::Triangle(poly_obj) => poly_obj.vertices()
    _ =>
      raise GeometryError::TypeError(
        "convex hull currently supports Point/Segment/Polygon-like entities",
      )
  }
}

///|
fn hull_orientation(
  p : Point,
  q : Point,
  r : Point,
) -> Expr raise GeometryError {
  geo_cross2(
    geo_sub_coords(q.with_dim(2).coords_, p.with_dim(2).coords_),
    geo_sub_coords(r.with_dim(2).coords_, p.with_dim(2).coords_),
  )
}

///|
fn convex_hull_points(
  points : Array[Point],
) -> (Array[Point], Array[Point]) raise GeometryError {
  let dedup : Array[Point] = []
  for item in points {
    let pt = item.with_dim(2)
    push_unique_point(dedup, pt)
  }
  if dedup.is_empty() {
    raise GeometryError::ValueError("convex_hull requires at least one point")
  }
  let items = sort_points_lex(dedup)
  if items.length() == 1 {
    return (items, [])
  }
  if items.length() == 2 {
    return (items, [])
  }
  let upper : Array[Point] = []
  let lower : Array[Point] = []
  for pt in items {
    while upper.length() > 1 &&
          (match
            geo_expr_sign(
              hull_orientation(
                upper[upper.length() - 2],
                upper[upper.length() - 1],
                pt,
              ),
            ) {
            Some(sign) => sign <= 0
            None => false
          }) {
      ignore(upper.pop())
    }
    while lower.length() > 1 &&
          (match
            geo_expr_sign(
              hull_orientation(
                lower[lower.length() - 2],
                lower[lower.length() - 1],
                pt,
              ),
            ) {
            Some(sign) => sign >= 0
            None => false
          }) {
      ignore(lower.pop())
    }
    upper.push(pt)
    lower.push(pt)
  }
  (upper, lower)
}

///|
pub fn convex_hull(
  items : Array[GeometryEntity],
) -> GeometryEntity raise GeometryError {
  let points : Array[Point] = []
  for item in items {
    for pt in geometry_entity_points(item) {
      push_unique_point(points, pt)
    }
  }
  let (upper, lower) = convex_hull_points(points)
  if lower.is_empty() {
    if upper.length() == 1 {
      return geometry_point(upper[0])
    }
    return geometry_segment(segment(upper[0], upper[1]))
  }
  let hull : Array[Point] = []
  for pt in lower {
    hull.push(pt)
  }
  let reversed_upper : Array[Point] = []
  for i in 0..<upper.length() {
    reversed_upper.push(upper[upper.length() - 1 - i])
  }
  if reversed_upper.length() > 2 {
    for pt in reversed_upper[1:reversed_upper.length() - 1] {
      hull.push(pt)
    }
  }
  polygon(hull)
}

///|
pub fn convex_hull_chains(
  items : Array[GeometryEntity],
) -> (Array[Point], Array[Point]) raise GeometryError {
  let points : Array[Point] = []
  for item in items {
    for pt in geometry_entity_points(item) {
      push_unique_point(points, pt)
    }
  }
  convex_hull_points(points)
}

///|
pub fn closest_points(
  points : Array[Point],
) -> Array[(Point, Point)] raise GeometryError {
  let items = sort_points_lex(points)
  if items.length() < 2 {
    raise GeometryError::ValueError(
      "closest_points requires at least two points",
    )
  }
  let unique : Array[Point] = []
  for item in items {
    if unique.any(fn(prev) { prev == item }) {
      continue
    }
    unique.push(item)
  }
  if unique.length() < 2 {
    raise GeometryError::ValueError(
      "closest_points requires at least two distinct points",
    )
  }
  let mut best : Expr? = None
  let out : Array[(Point, Point)] = []
  for i in 0..<unique.length() {
    for j in (i + 1)..<unique.length() {
      let d2 = geo_norm_sq(geo_sub_coords(unique[i].coords_, unique[j].coords_))
      match best {
        None => {
          best = Some(d2)
          out.clear()
          push_unique_pair(out, (unique[i], unique[j]))
        }
        Some(current) =>
          match geo_expr_sign(d2 - current) {
            Some(sign) if sign < 0 => {
              best = Some(d2)
              out.clear()
              push_unique_pair(out, (unique[i], unique[j]))
            }
            Some(0) => push_unique_pair(out, (unique[i], unique[j]))
            Some(_) => ()
            None => ()
          }
      }
    }
  }
  sort_point_pairs(out)
}

///|
pub fn farthest_points(
  points : Array[Point],
) -> Array[(Point, Point)] raise GeometryError {
  let items = sort_points_lex(points)
  if items.length() < 2 {
    raise GeometryError::ValueError(
      "farthest_points requires at least two points",
    )
  }
  let unique : Array[Point] = []
  for item in items {
    if unique.any(fn(prev) { prev == item }) {
      continue
    }
    unique.push(item)
  }
  if unique.length() < 2 {
    raise GeometryError::ValueError(
      "farthest_points requires at least two distinct points",
    )
  }
  let mut best : Expr? = None
  let out : Array[(Point, Point)] = []
  for i in 0..<unique.length() {
    for j in (i + 1)..<unique.length() {
      let d2 = geo_norm_sq(geo_sub_coords(unique[i].coords_, unique[j].coords_))
      match best {
        None => {
          best = Some(d2)
          out.clear()
          push_unique_pair(out, (unique[i], unique[j]))
        }
        Some(current) =>
          match geo_expr_sign(d2 - current) {
            Some(sign) if sign > 0 => {
              best = Some(d2)
              out.clear()
              push_unique_pair(out, (unique[i], unique[j]))
            }
            Some(0) => push_unique_pair(out, (unique[i], unique[j]))
            Some(_) => ()
            None => ()
          }
      }
    }
  }
  sort_point_pairs(out)
}

///|
fn sort_point_pairs(
  pairs : Array[(Point, Point)],
) -> Array[(Point, Point)] raise GeometryError {
  let out = pairs[:].to_owned()
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      let lhs = out[i]
      let rhs = out[j]
      let first_cmp = point_order_cmp(lhs.0, rhs.0)
      let swap = if first_cmp > 0 {
        true
      } else if first_cmp == 0 {
        point_order_cmp(lhs.1, rhs.1) > 0
      } else {
        false
      }
      if swap {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
pub fn are_coplanar_points(points : Array[Point]) -> Bool raise GeometryError {
  point_are_coplanar(points)
}

///|
pub fn are_coplanar(items : Array[GeometryEntity]) -> Bool raise GeometryError {
  let points : Array[Point] = []
  for item in items {
    match item {
      GeometryEntity::Point(point_obj) => points.push(point_obj.with_dim(3))
      GeometryEntity::Line(line_obj) => {
        points.push(line_obj.p1_.with_dim(3))
        points.push(line_obj.p2_.with_dim(3))
      }
      GeometryEntity::Ray(ray_obj) => {
        points.push(ray_obj.p1_.with_dim(3))
        points.push(ray_obj.p2_.with_dim(3))
      }
      GeometryEntity::Segment(seg_obj) => {
        points.push(seg_obj.p1_.with_dim(3))
        points.push(seg_obj.p2_.with_dim(3))
      }
      GeometryEntity::Plane(plane_obj) =>
        if !items.all(fn(inner) {
            plane_obj.contains(inner) catch {
              _ => false
            }
          }) {
          return false
        }
      GeometryEntity::Ellipse(ellipse_obj) =>
        points.push(
          ellipse_obj.center().with_dim(3) catch {
            _ => return false
          },
        )
      GeometryEntity::Circle(circle_obj) =>
        points.push(circle_obj.center().with_dim(3) catch { _ => return false })
      GeometryEntity::Polygon(polygon_obj) =>
        for pt in polygon_obj.vertices() {
          points.push(pt.with_dim(3) catch { _ => return false })
        }
      GeometryEntity::RegularPolygon(poly_obj) => {
        let vertices = poly_obj.vertices()
        for pt in vertices {
          points.push(pt.with_dim(3) catch { _ => return false })
        }
      }
      GeometryEntity::Triangle(triangle_obj) =>
        for pt in triangle_obj.vertices() {
          points.push(pt.with_dim(3) catch { _ => return false })
        }
      GeometryEntity::Parabola(parabola_obj) =>
        points.push(
          parabola_obj.focus().with_dim(3) catch {
            _ => return false
          },
        )
      GeometryEntity::Curve(curve_obj) =>
        points.push(
          (curve_obj.arbitrary_point() catch { _ => return false }).with_dim(3) catch {
            _ => return false
          },
        )
    }
  }
  point_are_coplanar(points)
}

///|
pub fn centroid(items : Array[Point]) -> Point? raise GeometryError {
  if items.is_empty() {
    return None
  }
  let normalized = geo_normalize_dim(items)
  let dim = normalized[0].ambient_dimension()
  let acc = geo_zero_coords(dim)
  for item in normalized {
    for i in 0..<dim {
      acc[i] = geo_simplify(acc[i] + item.coords_[i])
    }
  }
  let n = geo_int(items.length())
  Some(point(acc.map(fn(coord) { geo_div(coord, n) }), dim~))
}

///|
pub fn intersection(
  lhs : GeometryEntity,
  rhs : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match (lhs, rhs) {
    (GeometryEntity::Point(point_obj), GeometryEntity::Point(other_obj)) =>
      if point_obj == other_obj {
        [GeometryEntity::Point(point_obj)]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Line(line_obj))
    | (GeometryEntity::Line(line_obj), GeometryEntity::Point(point_obj)) =>
      if line_obj.contains(point_obj) {
        [
          GeometryEntity::Point(
            point_obj.with_dim(line_obj.ambient_dimension()),
          ),
        ]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Ray(ray_obj))
    | (GeometryEntity::Ray(ray_obj), GeometryEntity::Point(point_obj)) =>
      if ray_obj.contains(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(ray_obj.ambient_dimension()))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Segment(seg_obj))
    | (GeometryEntity::Segment(seg_obj), GeometryEntity::Point(point_obj)) =>
      if seg_obj.contains(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(seg_obj.ambient_dimension()))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Plane(plane_obj))
    | (GeometryEntity::Plane(plane_obj), GeometryEntity::Point(point_obj)) =>
      if plane_obj.contains_point(point_obj) {
        [GeometryEntity::Point(point_obj.with_dim(3))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Ellipse(ellipse_obj))
    | (GeometryEntity::Ellipse(ellipse_obj), GeometryEntity::Point(point_obj)) =>
      if ellipse_obj.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Circle(circle_obj))
    | (GeometryEntity::Circle(circle_obj), GeometryEntity::Point(point_obj)) =>
      if circle_obj.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Polygon(polygon_obj))
    | (GeometryEntity::Polygon(polygon_obj), GeometryEntity::Point(point_obj)) =>
      if polygon_obj.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::RegularPolygon(poly_obj))
    | (
      GeometryEntity::RegularPolygon(poly_obj),
      GeometryEntity::Point(point_obj),
    ) =>
      if (regular_polygon_as_polygon(poly_obj) catch { _ => return [] }).contains_point(
          point_obj,
        ) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Triangle(triangle_obj))
    | (GeometryEntity::Triangle(triangle_obj), GeometryEntity::Point(point_obj)) =>
      if triangle_obj.contains_point(point_obj) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    (GeometryEntity::Point(point_obj), GeometryEntity::Parabola(parabola_obj))
    | (GeometryEntity::Parabola(parabola_obj), GeometryEntity::Point(point_obj)) =>
      parabola_obj.intersection(geometry_point(point_obj))
    (GeometryEntity::Point(_), GeometryEntity::Curve(_))
    | (GeometryEntity::Curve(_), GeometryEntity::Point(_)) => []
    (GeometryEntity::Line(line_obj), other) => line_obj.intersection(other)
    (GeometryEntity::Ray(ray_obj), other) => ray_obj.intersection(other)
    (GeometryEntity::Segment(seg_obj), other) => seg_obj.intersection(other)
    (GeometryEntity::Plane(plane_obj), other) => plane_obj.intersection(other)
    (GeometryEntity::Ellipse(ellipse_obj), other) =>
      ellipse_obj.intersection(other)
    (GeometryEntity::Circle(circle_obj), other) =>
      circle_obj.intersection(other)
    (GeometryEntity::Polygon(polygon_obj), other) =>
      polygon_obj.intersection(other)
    (GeometryEntity::RegularPolygon(poly_obj), other) =>
      poly_obj.intersection(other)
    (GeometryEntity::Triangle(triangle_obj), other) =>
      triangle_obj.intersection(other)
    (GeometryEntity::Parabola(parabola_obj), other) =>
      parabola_obj.intersection(other)
    (GeometryEntity::Curve(_), _) => []
  }
}
