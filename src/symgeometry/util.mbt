///|
/// Find the unique symbol named `x` inside `equation`.
pub fn find(
  x : String,
  equation : @symcore.Expr,
) -> @symcore.Expr raise GeometryError {
  let seen : Map[String, Bool] = {}
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
  @symcore.symbol(matches[0])
}

///|
pub fn ordered_points(points : Array[Point]) -> Array[Point] {
  let out = points[:].to_array()
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if out[i].repr().compare(out[j].repr()) > 0 {
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
    (GeometryEntity::Line(line_obj), other) => line_obj.intersection(other)
    (GeometryEntity::Ray(ray_obj), other) => ray_obj.intersection(other)
    (GeometryEntity::Segment(seg_obj), other) => seg_obj.intersection(other)
    (GeometryEntity::Plane(plane_obj), other) => plane_obj.intersection(other)
  }
}
