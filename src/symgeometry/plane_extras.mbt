///|
fn plane_has_xy_normal_only(plane_obj : Plane) -> Bool {
  geo_expr_is_zero(plane_obj.normal_[0]) &&
  geo_expr_is_zero(plane_obj.normal_[1])
}

///|
fn plane_unique_push(
  planes : Array[Plane],
  candidate : Plane,
) -> Unit raise GeometryError {
  for item in planes {
    if item.equals(geometry_plane(candidate)) {
      return
    }
  }
  planes.push(candidate)
}

///|
pub fn Plane::p1(self : Plane) -> Point {
  self.point_
}

///|
pub fn plane_are_concurrent(planes : Array[Plane]) -> Bool raise GeometryError {
  let unique : Array[Plane] = []
  for plane_obj in planes {
    plane_unique_push(unique, plane_obj)
  }
  if unique.length() < 2 {
    return false
  }
  let first = unique[0]
  let base = first.intersection(geometry_plane(unique[1]))
  if base.is_empty() {
    return false
  }
  let base_line = match base[0] {
    Line(line_obj) => line_obj
    _ => return false
  }
  for i in 2..<unique.length() {
    let hits = first.intersection(geometry_plane(unique[i]))
    if hits.is_empty() {
      return false
    }
    match hits[0] {
      Line(line_obj) =>
        if !(base_line.contains(line_obj.p1()) &&
          base_line.contains(line_obj.p2())) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
pub fn Plane::is_coplanar(
  self : Plane,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match other {
    Plane(plane_obj) =>
      self.contains_point(plane_obj.point_) &&
      geo_all_zero(geo_cross3(self.normal_, plane_obj.normal_))
    Point(point_obj) =>
      if point_obj.ambient_dimension() <= 2 {
        plane_has_xy_normal_only(self)
      } else {
        self.contains_point(point_obj)
      }
    Line(line_obj) =>
      if line_obj.ambient_dimension() <= 2 {
        plane_has_xy_normal_only(self)
      } else {
        self.contains_point(line_obj.p1_) && self.contains_point(line_obj.p2_)
      }
    Ray(ray_obj) =>
      if ray_obj.ambient_dimension() <= 2 {
        plane_has_xy_normal_only(self)
      } else {
        self.contains_point(ray_obj.p1_) && self.contains_point(ray_obj.p2_)
      }
    Segment(seg_obj) =>
      if seg_obj.ambient_dimension() <= 2 {
        plane_has_xy_normal_only(self)
      } else {
        self.contains_point(seg_obj.p1_) && self.contains_point(seg_obj.p2_)
      }
    _ =>
      if other.ambient_dimension() <= 2 {
        plane_has_xy_normal_only(self)
      } else {
        false
      }
  }
}

///|
pub fn Plane::random_point(
  self : Plane,
  seed? : Int? = None,
) -> Point raise GeometryError {
  let rng = match seed {
    Some(value) => geo_random_from_seed(value)
    None => geo_random_source
  }
  self.arbitrary_point(
    u=Some(geo_random_symmetric_rational(rng)),
    v=Some(geo_random_symmetric_rational(rng)),
  )
}
