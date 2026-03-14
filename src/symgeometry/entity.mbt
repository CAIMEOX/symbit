///|
/// Shared operations that every geometry entity supports in SymPy's geometry
/// surface: ambient dimension and geometric transforms.
pub fn geometry_point(entity : Point) -> GeometryEntity {
  GeometryEntity::Point(entity)
}

///|
pub fn geometry_line(entity : Line) -> GeometryEntity {
  GeometryEntity::Line(entity)
}

///|
pub fn geometry_ray(entity : Ray) -> GeometryEntity {
  GeometryEntity::Ray(entity)
}

///|
pub fn geometry_segment(entity : Segment) -> GeometryEntity {
  GeometryEntity::Segment(entity)
}

///|
pub fn geometry_plane(entity : Plane) -> GeometryEntity {
  GeometryEntity::Plane(entity)
}

///|
pub fn GeometryEntity::ambient_dimension(self : GeometryEntity) -> Int {
  match self {
    GeometryEntity::Point(point_obj) => point_obj.ambient_dimension()
    GeometryEntity::Line(line_obj) => line_obj.ambient_dimension()
    GeometryEntity::Ray(ray_obj) => ray_obj.ambient_dimension()
    GeometryEntity::Segment(seg_obj) => seg_obj.ambient_dimension()
    GeometryEntity::Plane(_) => 3
  }
}

///|
pub fn GeometryEntity::repr(
  self : GeometryEntity,
) -> String raise GeometryError {
  match self {
    GeometryEntity::Point(point_obj) => point_obj.repr()
    GeometryEntity::Line(line_obj) => line_obj.repr()
    GeometryEntity::Ray(ray_obj) => ray_obj.repr()
    GeometryEntity::Segment(seg_obj) => seg_obj.repr()
    GeometryEntity::Plane(plane_obj) => plane_obj.repr()
  }
}

///|
pub fn GeometryEntity::translate(
  self : GeometryEntity,
  offsets : Array[@symcore.Expr],
) -> GeometryEntity raise GeometryError {
  match self {
    GeometryEntity::Point(point_obj) =>
      GeometryEntity::Point(point_obj.translate(offsets))
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => linear_translate(self, offsets)
    GeometryEntity::Plane(plane_obj) =>
      GeometryEntity::Plane(plane_obj.translate(offsets))
  }
}

///|
pub fn GeometryEntity::scale(
  self : GeometryEntity,
  factors : Array[@symcore.Expr],
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  match self {
    GeometryEntity::Point(point_obj) =>
      GeometryEntity::Point(point_obj.scale(factors, pt~))
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => linear_scale(self, factors, pt)
    GeometryEntity::Plane(plane_obj) =>
      GeometryEntity::Plane(plane_obj.scale(factors, pt~))
  }
}

///|
pub fn GeometryEntity::rotate(
  self : GeometryEntity,
  angle : @symcore.Expr,
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  match self {
    GeometryEntity::Point(point_obj) =>
      GeometryEntity::Point(point_obj.rotate(angle, pt~))
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => linear_rotate(self, angle, pt)
    GeometryEntity::Plane(_) =>
      raise GeometryError::ValueError(
        "plane rotation is not implemented in the first geometry slice",
      )
  }
}
