///|
fn ellipse_auxiliary_radius(hradius : Expr, vradius : Expr) -> Expr {
  match (geo_expr_sign(hradius), geo_expr_sign(vradius)) {
    (Some(hs), Some(vs)) if hs >= 0 && vs >= 0 =>
      @symelem.max([hradius, vradius])
    (Some(_), Some(_)) =>
      @symelem.max([@symelem.abs(hradius), @symelem.abs(vradius)])
    _ => @symelem.max([hradius, vradius])
  }
}

///|
fn reflect_point_across_line_2d(
  pt : Point,
  mirror : Line,
) -> Point raise GeometryError {
  let point_obj = pt.with_dim(2)
  let (a, b, c) = linear_line_coeffs_2d(geometry_line(mirror))
  let denom = geo_simplify(a * a + b * b)
  let offset = geo_div(
    a * point_obj.coords_[0] + b * point_obj.coords_[1] + c,
    denom,
  )
  point2d(
    geo_simplify(point_obj.coords_[0] - geo_int(2) * a * offset),
    geo_simplify(point_obj.coords_[1] - geo_int(2) * b * offset),
  )
}

///|
fn ellipse_second_moment_tuple(
  center : Point,
  hradius : Expr,
  vradius : Expr,
  point~ : Point?,
) -> (Expr, Expr, Expr) raise GeometryError {
  let i_xx = geo_simplify(
    geo_div(geo_pi() * hradius * (vradius ^ geo_int(3)), geo_int(4)),
  )
  let i_yy = geo_simplify(
    geo_div(geo_pi() * (hradius ^ geo_int(3)) * vradius, geo_int(4)),
  )
  let i_xy = int(0)
  match point {
    None => (i_xx, i_yy, i_xy)
    Some(point_obj) => {
      let shifted = point_obj.with_dim(2)
      let area = geo_simplify(geo_pi() * hradius * vradius)
      let dx = geo_simplify(shifted.coords_[0] - center.coords_[0])
      let dy = geo_simplify(shifted.coords_[1] - center.coords_[1])
      (
        geo_simplify(i_xx + area * (dy ^ geo_int(2))),
        geo_simplify(i_yy + area * (dx ^ geo_int(2))),
        geo_simplify(i_xy + area * dx * dy),
      )
    }
  }
}

///|
fn ellipse_section_modulus_tuple(
  center : Point,
  hradius : Expr,
  vradius : Expr,
  point~ : Point?,
) -> (Expr, Expr) raise GeometryError {
  let (i_xx, i_yy, _) = ellipse_second_moment_tuple(
    center,
    hradius,
    vradius,
    point=None,
  )
  let (x_dist, y_dist) = match point {
    None => (@symelem.abs(hradius), @symelem.abs(vradius))
    Some(point_obj) => {
      let pt = point_obj.with_dim(2)
      (
        geo_simplify(pt.coords_[0] - center.coords_[0]),
        geo_simplify(pt.coords_[1] - center.coords_[1]),
      )
    }
  }
  (geo_simplify(geo_div(i_xx, y_dist)), geo_simplify(geo_div(i_yy, x_dist)))
}

///|
pub fn Ellipse::evolute(
  self : Ellipse,
  x? : Expr = Symbol("x"),
  y? : Expr = Symbol("y"),
) -> Expr raise {
  let two_thirds = @symcore.rational_from_ints(2, 3)
  let first = (self.hradius_ * (x - self.center_.coords_[0])) ^ two_thirds
  let second = (self.vradius_ * (y - self.center_.coords_[1])) ^ two_thirds
  let offset = ((self.hradius_ ^ geo_int(2)) - (self.vradius_ ^ geo_int(2))) ^
    two_thirds
  geo_simplify(first + second - offset)
}

///|
pub fn Ellipse::auxiliary_circle(self : Ellipse) -> Circle raise GeometryError {
  circle(self.center_, ellipse_auxiliary_radius(self.hradius_, self.vradius_))
}

///|
pub fn Ellipse::director_circle(self : Ellipse) -> Circle raise GeometryError {
  circle(
    self.center_,
    @symelem.sqrt((self.hradius_ ^ geo_int(2)) + (self.vradius_ ^ geo_int(2))),
  )
}

///|
pub fn Ellipse::random_point(
  self : Ellipse,
  seed? : Int? = None,
) -> Point raise GeometryError {
  let rng = match seed {
    Some(value) => geo_random_from_seed(value)
    None => geo_random_source
  }
  let u = geo_random_symmetric_rational(rng)
  let denom = geo_simplify(int(1) + (u ^ geo_int(2)))
  let c = geo_simplify(geo_div(int(1) - (u ^ geo_int(2)), denom))
  let s = geo_simplify(geo_div(geo_int(2) * u, denom))
  point2d(
    geo_simplify(self.center_.coords_[0] + self.hradius_ * c),
    geo_simplify(self.center_.coords_[1] + self.vradius_ * s),
  )
}

///|
pub fn Ellipse::reflect(
  self : Ellipse,
  line_obj : Line,
) -> GeometryEntity raise GeometryError {
  let direction = line_obj.direction().with_dim(2)
  if geo_expr_is_zero(direction.y()) || geo_expr_is_zero(direction.x()) {
    let center = reflect_point_across_line_2d(self.center_, line_obj)
    return geometry_ellipse({
      center_: center,
      hradius_: geo_simplify(int(0) - self.hradius_),
      vradius_: self.vradius_,
    })
  }
  raise ValueError(
    "general reflected ellipses are not supported without rotated ellipse support",
  )
}

///|
pub fn Ellipse::second_moment_of_area(
  self : Ellipse,
  point? : Point? = None,
) -> (Expr, Expr, Expr) raise GeometryError {
  ellipse_second_moment_tuple(
    self.center_,
    self.hradius_,
    self.vradius_,
    point~,
  )
}

///|
pub fn Ellipse::polar_second_moment_of_area(
  self : Ellipse,
) -> Expr raise GeometryError {
  let second = self.second_moment_of_area()
  geo_simplify(second.0 + second.1)
}

///|
pub fn Ellipse::section_modulus(
  self : Ellipse,
  point? : Point? = None,
) -> (Expr, Expr) raise GeometryError {
  ellipse_section_modulus_tuple(
    self.center_,
    self.hradius_,
    self.vradius_,
    point~,
  )
}

///|
pub fn Circle::auxiliary_circle(self : Circle) -> Circle {
  self
}

///|
pub fn Circle::director_circle(self : Circle) -> Circle raise GeometryError {
  circle(self.center_, @symelem.sqrt(geo_int(2) * (self.radius_ ^ geo_int(2))))
}

///|
pub fn Circle::random_point(
  self : Circle,
  seed? : Int? = None,
) -> Point raise GeometryError {
  Ellipse::{
    center_: self.center_,
    hradius_: self.radius_,
    vradius_: self.radius_,
  }.random_point(seed~)
}

///|
pub fn Circle::reflect(
  self : Circle,
  line_obj : Line,
) -> Circle raise GeometryError {
  {
    center_: reflect_point_across_line_2d(self.center_, line_obj),
    radius_: geo_simplify(int(0) - self.radius_),
  }
}

///|
pub fn Circle::second_moment_of_area(
  self : Circle,
  point? : Point? = None,
) -> (Expr, Expr, Expr) raise GeometryError {
  ellipse_second_moment_tuple(self.center_, self.radius_, self.radius_, point~)
}

///|
pub fn Circle::polar_second_moment_of_area(
  self : Circle,
) -> Expr raise GeometryError {
  let second = self.second_moment_of_area()
  geo_simplify(second.0 + second.1)
}

///|
pub fn Circle::section_modulus(
  self : Circle,
  point? : Point? = None,
) -> (Expr, Expr) raise GeometryError {
  ellipse_section_modulus_tuple(
    self.center_,
    self.radius_,
    self.radius_,
    point~,
  )
}

///|
pub fn Circle::evolute(
  self : Circle,
  x? : Expr = Symbol("x"),
  y? : Expr = Symbol("y"),
) -> Expr raise {
  Ellipse::{
    center_: self.center_,
    hradius_: self.radius_,
    vradius_: self.radius_,
  }.evolute(x~, y~)
}
