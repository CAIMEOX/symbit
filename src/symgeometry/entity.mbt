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
pub fn geometry_ellipse(entity : Ellipse) -> GeometryEntity {
  GeometryEntity::Ellipse(entity)
}

///|
pub fn geometry_circle(entity : Circle) -> GeometryEntity {
  GeometryEntity::Circle(entity)
}

///|
pub fn geometry_polygon(entity : Polygon) -> GeometryEntity {
  GeometryEntity::Polygon(entity)
}

///|
pub fn geometry_regular_polygon(entity : RegularPolygon) -> GeometryEntity {
  GeometryEntity::RegularPolygon(entity)
}

///|
pub fn geometry_triangle(entity : Triangle) -> GeometryEntity {
  GeometryEntity::Triangle(entity)
}

///|
pub fn geometry_parabola(entity : Parabola) -> GeometryEntity {
  GeometryEntity::Parabola(entity)
}

///|
pub fn geometry_curve(entity : Curve) -> GeometryEntity {
  GeometryEntity::Curve(entity)
}

///|
pub fn GeometryEntity::ambient_dimension(self : GeometryEntity) -> Int {
  match self {
    GeometryEntity::Point(point_obj) => point_obj.ambient_dimension()
    GeometryEntity::Line(line_obj) => line_obj.ambient_dimension()
    GeometryEntity::Ray(ray_obj) => ray_obj.ambient_dimension()
    GeometryEntity::Segment(seg_obj) => seg_obj.ambient_dimension()
    GeometryEntity::Plane(plane_obj) => plane_obj.ambient_dimension()
    GeometryEntity::Ellipse(ellipse_obj) => ellipse_obj.ambient_dimension()
    GeometryEntity::Circle(circle_obj) => circle_obj.ambient_dimension()
    GeometryEntity::Polygon(polygon_obj) => polygon_obj.ambient_dimension()
    GeometryEntity::RegularPolygon(poly_obj) => poly_obj.ambient_dimension()
    GeometryEntity::Triangle(triangle_obj) => triangle_obj.ambient_dimension()
    GeometryEntity::Parabola(parabola_obj) => parabola_obj.ambient_dimension()
    GeometryEntity::Curve(curve_obj) => curve_obj.ambient_dimension()
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
    GeometryEntity::Ellipse(ellipse_obj) => ellipse_obj.repr()
    GeometryEntity::Circle(circle_obj) => circle_obj.repr()
    GeometryEntity::Polygon(polygon_obj) => polygon_obj.repr()
    GeometryEntity::RegularPolygon(poly_obj) => poly_obj.repr()
    GeometryEntity::Triangle(triangle_obj) => triangle_obj.repr()
    GeometryEntity::Parabola(parabola_obj) => parabola_obj.repr()
    GeometryEntity::Curve(curve_obj) => curve_obj.repr()
  }
}

///|
pub fn GeometryEntity::translate(
  self : GeometryEntity,
  offsets : Array[Expr],
) -> GeometryEntity raise GeometryError {
  match self {
    GeometryEntity::Point(point_obj) =>
      GeometryEntity::Point(point_obj.translate(offsets))
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => linear_translate(self, offsets)
    GeometryEntity::Plane(plane_obj) =>
      GeometryEntity::Plane(plane_obj.translate(offsets))
    GeometryEntity::Ellipse(ellipse_obj) =>
      geometry_ellipse(ellipse_obj.translate(offsets))
    GeometryEntity::Circle(circle_obj) =>
      geometry_circle(circle_obj.translate(offsets))
    GeometryEntity::Polygon(polygon_obj) =>
      geometry_polygon(polygon_obj.translate(offsets))
    GeometryEntity::RegularPolygon(poly_obj) =>
      geometry_regular_polygon(poly_obj.translate(offsets))
    GeometryEntity::Triangle(triangle_obj) =>
      geometry_triangle(triangle_obj.translate(offsets))
    GeometryEntity::Parabola(parabola_obj) =>
      geometry_parabola(parabola_obj.translate(offsets))
    GeometryEntity::Curve(curve_obj) =>
      geometry_curve(curve_obj.translate(offsets))
  }
}

///|
pub fn GeometryEntity::scale(
  self : GeometryEntity,
  factors : Array[Expr],
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
    GeometryEntity::Ellipse(ellipse_obj) =>
      ellipse_obj.scale(factors[0], y=factors[1], pt~)
    GeometryEntity::Circle(circle_obj) =>
      circle_obj.scale(factors[0], y=factors[1], pt~)
    GeometryEntity::Polygon(polygon_obj) =>
      geometry_polygon(polygon_obj.scale(factors, pt~))
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.scale(factors[0], y=factors[1], pt~)
    GeometryEntity::Triangle(triangle_obj) =>
      geometry_triangle(triangle_obj.scale(factors, pt~))
    GeometryEntity::Parabola(parabola_obj) =>
      geometry_parabola(parabola_obj.scale(factors, pt~))
    GeometryEntity::Curve(curve_obj) =>
      geometry_curve(curve_obj.scale(factors, pt~))
  }
}

///|
pub fn GeometryEntity::rotate(
  self : GeometryEntity,
  angle : Expr,
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
    GeometryEntity::Ellipse(ellipse_obj) => ellipse_obj.rotate(angle, pt~)
    GeometryEntity::Circle(circle_obj) => circle_obj.rotate(angle, pt~)
    GeometryEntity::Polygon(polygon_obj) =>
      geometry_polygon(polygon_obj.rotate(angle, pt~))
    GeometryEntity::RegularPolygon(poly_obj) =>
      geometry_regular_polygon(poly_obj.rotate(angle, pt~))
    GeometryEntity::Triangle(triangle_obj) =>
      geometry_triangle(triangle_obj.rotate(angle, pt~))
    GeometryEntity::Parabola(parabola_obj) =>
      geometry_parabola(parabola_obj.rotate(angle, pt~))
    GeometryEntity::Curve(curve_obj) =>
      geometry_curve(curve_obj.rotate(angle, pt~))
  }
}

///|
pub fn GeometryEntity::encloses(
  self : GeometryEntity,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match self {
    GeometryEntity::Ellipse(ellipse_obj) => ellipse_obj.encloses(other)
    GeometryEntity::Circle(circle_obj) => circle_obj.encloses(other)
    GeometryEntity::Polygon(polygon_obj) => polygon_obj.encloses(other)
    GeometryEntity::RegularPolygon(poly_obj) => poly_obj.encloses(other)
    GeometryEntity::Triangle(triangle_obj) => triangle_obj.encloses(other)
    _ => false
  }
}

///|
pub fn GeometryEntity::is_similar(
  self : GeometryEntity,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match self {
    GeometryEntity::Line(line_obj) => line_obj.is_similar(other)
    GeometryEntity::Ray(ray_obj) => ray_obj.is_similar(other)
    GeometryEntity::Segment(seg_obj) => seg_obj.is_similar(other)
    GeometryEntity::Triangle(triangle_obj) => triangle_obj.is_similar(other)
    _ => false
  }
}

///|
pub fn GeometryEntity::parameter_value(
  self : GeometryEntity,
  other : Point,
  t : Expr,
) -> Map[Expr, Expr] raise GeometryError {
  let out : Map[Expr, Expr] = Map([])
  match self {
    GeometryEntity::Line(line_obj) => {
      let value = linear_param_for_point(geometry_line(line_obj), other)
      out.set(t, geo_simplify(value))
      out
    }
    GeometryEntity::Ray(ray_obj) => {
      let value = linear_param_for_point(geometry_ray(ray_obj), other)
      if !linear_param_ok(LinearKind::Ray, value) {
        raise GeometryError::ValueError("point is not on ray")
      }
      out.set(t, geo_simplify(value))
      out
    }
    GeometryEntity::Segment(seg_obj) => {
      let value = linear_param_for_point(geometry_segment(seg_obj), other)
      if !linear_param_ok(LinearKind::Segment, value) {
        raise GeometryError::ValueError("point is not on segment")
      }
      out.set(t, geo_simplify(value))
      out
    }
    GeometryEntity::Plane(plane_obj) => plane_obj.parameter_value(other, t)
    GeometryEntity::Ellipse(ellipse_obj) =>
      ellipse_obj.parameter_value(other, t)
    GeometryEntity::Circle(circle_obj) => circle_obj.parameter_value(other, t)
    GeometryEntity::Polygon(polygon_obj) =>
      polygon_obj.parameter_value(other, t)
    GeometryEntity::RegularPolygon(poly_obj) =>
      poly_obj.parameter_value(other, t)
    GeometryEntity::Triangle(triangle_obj) =>
      triangle_as_polygon_of(triangle_obj).parameter_value(other, t)
    GeometryEntity::Curve(curve_obj) => curve_obj.parameter_value(other, t)
    _ =>
      raise GeometryError::TypeError(
        "parameter_value is not implemented for this geometry entity",
      )
  }
}
