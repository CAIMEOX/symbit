///|
/// Planar parabola defined by a focus point and a directrix line.
pub struct Parabola {
  focus_ : Point
  directrix_ : Line
} derive(Eq)

///|
pub fn parabola(
  focus : Point,
  directrix : Line,
) -> Parabola raise GeometryError {
  let focus = focus.with_dim(2)
  let directrix = line(directrix.p1().with_dim(2), directrix.p2().with_dim(2))
  if directrix.contains(focus) {
    raise GeometryError::ValueError("focus must not lie on the directrix")
  }
  Parabola::{ focus_: focus, directrix_: directrix }
}

///|
fn line_coeffs_2d(
  line_obj : Line,
) -> (Expr, Expr, Expr) {
  let p1 = line_obj.p1()
  let p2 = line_obj.p2()
  let a = geo_simplify(p1.coords_[1] - p2.coords_[1])
  let b = geo_simplify(p2.coords_[0] - p1.coords_[0])
  let c = geo_simplify(
    p1.coords_[0] * p2.coords_[1] - p2.coords_[0] * p1.coords_[1],
  )
  (a, b, c)
}

///|
pub fn Parabola::repr(self : Parabola) -> String raise GeometryError {
  "Parabola(" + self.focus_.repr() + ", " + self.directrix_.repr() + ")"
}

///|
pub fn Parabola::ambient_dimension(self : Parabola) -> Int {
  2
}

///|
pub fn Parabola::focus(self : Parabola) -> Point {
  self.focus_
}

///|
pub fn Parabola::directrix(self : Parabola) -> Line {
  self.directrix_
}

///|
pub fn Parabola::eccentricity(self : Parabola) -> Expr {
  geo_one()
}

///|
pub fn Parabola::vertex(self : Parabola) -> Point raise GeometryError {
  self.focus_.midpoint(try! self.directrix_.projection(self.focus_))
}

///|
pub fn Line::projection(self : Line, pt : Point) -> Point raise GeometryError {
  let pt = pt.with_dim(self.ambient_dimension())
  let p1 = self.p1_
  let d = geo_sub_coords(self.p2_.coords_, self.p1_.coords_)
  let t = geo_div(
    geo_dot(geo_sub_coords(pt.coords_, p1.coords_), d),
    geo_norm_sq(d),
  )
  linear_point_at(geometry_line(self), t)
}

///|
pub fn Parabola::axis_of_symmetry(self : Parabola) -> Line raise GeometryError {
  line(self.vertex(), self.focus_)
}

///|
pub fn Parabola::focal_length(
  self : Parabola,
) -> Expr raise GeometryError {
  self.focus_.distance(self.vertex())
}

///|
pub fn Parabola::p_parameter(
  self : Parabola,
) -> Expr raise GeometryError {
  let foot = self.directrix_.projection(self.focus_)
  let dx = geo_simplify(self.focus_.coords_[0] - foot.coords_[0])
  let dy = geo_simplify(self.focus_.coords_[1] - foot.coords_[1])
  let sign = match geo_expr_sign(dx) {
    Some(0) | None =>
      match geo_expr_sign(dy) {
        Some(value) => value
        None => 1
      }
    Some(value) => value
  }
  geo_simplify(geo_int(sign) * self.focal_length())
}

///|
pub fn Parabola::equation(
  self : Parabola,
  x? : Expr = symbol("x"),
  y? : Expr = symbol("y"),
) -> Expr {
  let (a, b, c) = line_coeffs_2d(self.directrix_)
  geo_simplify(
    ((x - self.focus_.coords_[0]) ^ geo_int(2)) +
    ((y - self.focus_.coords_[1]) ^ geo_int(2)) -
    geo_div((a * x + b * y + c) ^ geo_int(2), a * a + b * b),
  )
}

///|
pub fn Parabola::intersection(
  self : Parabola,
  other : GeometryEntity,
) -> Array[GeometryEntity] raise GeometryError {
  match other {
    GeometryEntity::Point(point_obj) =>
      if geo_expr_is_zero(
          self.equation(
            x=point_obj.with_dim(2).coords_[0],
            y=point_obj.with_dim(2).coords_[1],
          ),
        ) {
        [geometry_point(point_obj.with_dim(2))]
      } else {
        []
      }
    GeometryEntity::Line(_)
    | GeometryEntity::Ray(_)
    | GeometryEntity::Segment(_) => {
      let p1 = linear_p1(other).with_dim(2)
      let d = linear_direction_coords(other)
      let (a, b, c) = line_coeffs_2d(self.directrix_)
      let q2 = a * a + b * b
      let x0 = p1.coords_[0] - self.focus_.coords_[0]
      let y0 = p1.coords_[1] - self.focus_.coords_[1]
      let dx = d[0]
      let dy = d[1]
      let qa = geo_simplify(
        q2 * (dx * dx + dy * dy) - ((a * dx + b * dy) ^ geo_int(2)),
      )
      let qb = geo_simplify(
        geo_int(2) * q2 * (x0 * dx + y0 * dy) -
        geo_int(2) *
        (a * p1.coords_[0] + b * p1.coords_[1] + c) *
        (a * dx + b * dy),
      )
      let qc = geo_simplify(
        q2 * (x0 * x0 + y0 * y0) -
        ((a * p1.coords_[0] + b * p1.coords_[1] + c) ^ geo_int(2)),
      )
      conic_points_from_linear_entity(other, qa, qb, qc)
    }
    _ => []
  }
}

///|
pub fn Parabola::translate(
  self : Parabola,
  offsets : Array[Expr],
) -> Parabola raise GeometryError {
  parabola(self.focus_.translate(offsets), self.directrix_.translate(offsets))
}

///|
pub fn Parabola::rotate(
  self : Parabola,
  angle : Expr,
  pt? : Point? = None,
) -> Parabola raise GeometryError {
  parabola(self.focus_.rotate(angle, pt~), self.directrix_.rotate(angle, pt~))
}

///|
pub fn Parabola::scale(
  self : Parabola,
  factors : Array[Expr],
  pt? : Point? = None,
) -> Parabola raise GeometryError {
  parabola(self.focus_.scale(factors, pt~), self.directrix_.scale(factors, pt~))
}
