///|
/// Shared operations that every geometry entity supports in SymPy's geometry
/// surface: ambient dimension and geometric transforms.
pub fn geometry_point(entity : Point) -> GeometryEntity {
  Point(entity)
}

///|
pub fn geometry_line(entity : Line) -> GeometryEntity {
  Line(entity)
}

///|
pub fn geometry_ray(entity : Ray) -> GeometryEntity {
  Ray(entity)
}

///|
pub fn geometry_segment(entity : Segment) -> GeometryEntity {
  Segment(entity)
}

///|
pub fn geometry_plane(entity : Plane) -> GeometryEntity {
  Plane(entity)
}

///|
pub fn geometry_ellipse(entity : Ellipse) -> GeometryEntity {
  Ellipse(entity)
}

///|
pub fn geometry_circle(entity : Circle) -> GeometryEntity {
  Circle(entity)
}

///|
pub fn geometry_polygon(entity : Polygon) -> GeometryEntity {
  Polygon(entity)
}

///|
pub fn geometry_regular_polygon(entity : RegularPolygon) -> GeometryEntity {
  RegularPolygon(entity)
}

///|
pub fn geometry_triangle(entity : Triangle) -> GeometryEntity {
  Triangle(entity)
}

///|
pub fn geometry_parabola(entity : Parabola) -> GeometryEntity {
  Parabola(entity)
}

///|
pub fn geometry_curve(entity : Curve) -> GeometryEntity {
  Curve(entity)
}

///|
pub fn GeometryEntity::ambient_dimension(self : GeometryEntity) -> Int {
  match self {
    Point(point_obj) => point_obj.ambient_dimension()
    Line(line_obj) => line_obj.ambient_dimension()
    Ray(ray_obj) => ray_obj.ambient_dimension()
    Segment(seg_obj) => seg_obj.ambient_dimension()
    Plane(plane_obj) => plane_obj.ambient_dimension()
    Ellipse(ellipse_obj) => ellipse_obj.ambient_dimension()
    Circle(circle_obj) => circle_obj.ambient_dimension()
    Polygon(polygon_obj) => polygon_obj.ambient_dimension()
    RegularPolygon(poly_obj) => poly_obj.ambient_dimension()
    Triangle(triangle_obj) => triangle_obj.ambient_dimension()
    Parabola(parabola_obj) => parabola_obj.ambient_dimension()
    Curve(curve_obj) => curve_obj.ambient_dimension()
  }
}

///|
pub fn GeometryEntity::repr(
  self : GeometryEntity,
) -> String raise GeometryError {
  match self {
    Point(point_obj) => point_obj.repr()
    Line(line_obj) => line_obj.repr()
    Ray(ray_obj) => ray_obj.repr()
    Segment(seg_obj) => seg_obj.repr()
    Plane(plane_obj) => plane_obj.repr()
    Ellipse(ellipse_obj) => ellipse_obj.repr()
    Circle(circle_obj) => circle_obj.repr()
    Polygon(polygon_obj) => polygon_obj.repr()
    RegularPolygon(poly_obj) => poly_obj.repr()
    Triangle(triangle_obj) => triangle_obj.repr()
    Parabola(parabola_obj) => parabola_obj.repr()
    Curve(curve_obj) => curve_obj.repr()
  }
}

///|
pub fn GeometryEntity::translate(
  self : GeometryEntity,
  offsets : Array[Expr],
) -> GeometryEntity raise GeometryError {
  match self {
    Point(point_obj) => Point(point_obj.translate(offsets))
    Line(_) | Ray(_) | Segment(_) => linear_translate(self, offsets)
    Plane(plane_obj) => Plane(plane_obj.translate(offsets))
    Ellipse(ellipse_obj) => geometry_ellipse(ellipse_obj.translate(offsets))
    Circle(circle_obj) => geometry_circle(circle_obj.translate(offsets))
    Polygon(polygon_obj) => geometry_polygon(polygon_obj.translate(offsets))
    RegularPolygon(poly_obj) =>
      geometry_regular_polygon(poly_obj.translate(offsets))
    Triangle(triangle_obj) => geometry_triangle(triangle_obj.translate(offsets))
    Parabola(parabola_obj) => geometry_parabola(parabola_obj.translate(offsets))
    Curve(curve_obj) => geometry_curve(curve_obj.translate(offsets))
  }
}

///|
pub fn GeometryEntity::scale(
  self : GeometryEntity,
  factors : Array[Expr],
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  match self {
    Point(point_obj) => Point(point_obj.scale(factors, pt~))
    Line(_) | Ray(_) | Segment(_) => linear_scale(self, factors, pt)
    Plane(plane_obj) => Plane(plane_obj.scale(factors, pt~))
    Ellipse(ellipse_obj) => ellipse_obj.scale(factors[0], y=factors[1], pt~)
    Circle(circle_obj) => circle_obj.scale(factors[0], y=factors[1], pt~)
    Polygon(polygon_obj) => geometry_polygon(polygon_obj.scale(factors, pt~))
    RegularPolygon(poly_obj) => poly_obj.scale(factors[0], y=factors[1], pt~)
    Triangle(triangle_obj) =>
      geometry_triangle(triangle_obj.scale(factors, pt~))
    Parabola(parabola_obj) =>
      geometry_parabola(parabola_obj.scale(factors, pt~))
    Curve(curve_obj) => geometry_curve(curve_obj.scale(factors, pt~))
  }
}

///|
pub fn GeometryEntity::rotate(
  self : GeometryEntity,
  angle : Expr,
  pt? : Point? = None,
) -> GeometryEntity raise GeometryError {
  match self {
    Point(point_obj) => Point(point_obj.rotate(angle, pt~))
    Line(_) | Ray(_) | Segment(_) => linear_rotate(self, angle, pt)
    Plane(_) =>
      raise ValueError(
        "plane rotation is not implemented in the first geometry slice",
      )
    Ellipse(ellipse_obj) => ellipse_obj.rotate(angle, pt~)
    Circle(circle_obj) => circle_obj.rotate(angle, pt~)
    Polygon(polygon_obj) => geometry_polygon(polygon_obj.rotate(angle, pt~))
    RegularPolygon(poly_obj) =>
      geometry_regular_polygon(poly_obj.rotate(angle, pt~))
    Triangle(triangle_obj) => geometry_triangle(triangle_obj.rotate(angle, pt~))
    Parabola(parabola_obj) => geometry_parabola(parabola_obj.rotate(angle, pt~))
    Curve(curve_obj) => geometry_curve(curve_obj.rotate(angle, pt~))
  }
}

///|
pub fn GeometryEntity::encloses(
  self : GeometryEntity,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match self {
    Ellipse(ellipse_obj) => ellipse_obj.encloses(other)
    Circle(circle_obj) => circle_obj.encloses(other)
    Polygon(polygon_obj) => polygon_obj.encloses(other)
    RegularPolygon(poly_obj) => poly_obj.encloses(other)
    Triangle(triangle_obj) => triangle_obj.encloses(other)
    _ => false
  }
}

///|
pub fn GeometryEntity::is_similar(
  self : GeometryEntity,
  other : GeometryEntity,
) -> Bool raise GeometryError {
  match self {
    Line(line_obj) => line_obj.is_similar(other)
    Ray(ray_obj) => ray_obj.is_similar(other)
    Segment(seg_obj) => seg_obj.is_similar(other)
    Triangle(triangle_obj) => triangle_obj.is_similar(other)
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
    Line(line_obj) => {
      let value = linear_param_for_point(geometry_line(line_obj), other)
      out.set(t, geo_simplify(value))
      out
    }
    Ray(ray_obj) => {
      let value = linear_param_for_point(geometry_ray(ray_obj), other)
      if !linear_param_ok(Ray, value) {
        raise ValueError("point is not on ray")
      }
      out.set(t, geo_simplify(value))
      out
    }
    Segment(seg_obj) => {
      let value = linear_param_for_point(geometry_segment(seg_obj), other)
      if !linear_param_ok(Segment, value) {
        raise ValueError("point is not on segment")
      }
      out.set(t, geo_simplify(value))
      out
    }
    Plane(plane_obj) => plane_obj.parameter_value(other, t)
    Ellipse(ellipse_obj) => ellipse_obj.parameter_value(other, t)
    Circle(circle_obj) => circle_obj.parameter_value(other, t)
    Polygon(polygon_obj) => polygon_obj.parameter_value(other, t)
    RegularPolygon(poly_obj) => poly_obj.parameter_value(other, t)
    Triangle(triangle_obj) =>
      triangle_as_polygon_of(triangle_obj).parameter_value(other, t)
    Curve(curve_obj) => curve_obj.parameter_value(other, t)
    _ =>
      raise TypeError(
        "parameter_value is not implemented for this geometry entity",
      )
  }
}
