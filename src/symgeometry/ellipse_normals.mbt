///|
fn ellipse_sort_points_in_place(points : Array[(Double, Double)]) -> Unit {
  for i in 0..<points.length() {
    for j in (i + 1)..<points.length() {
      let lhs = points[i]
      let rhs = points[j]
      if rhs.0 < lhs.0 || (rhs.0 == lhs.0 && rhs.1 < lhs.1) {
        points[i] = rhs
        points[j] = lhs
      }
    }
  }
}

///|
fn ellipse_normal_boundary_points_numeric(
  center : Point,
  hradius : Expr,
  vradius : Expr,
  pt : Point,
  digits : Int,
) -> Array[Point]? raise GeometryError {
  let cx = match geo_expr_real_double(center.coords_[0]) {
    Some(value) => value
    None => return None
  }
  let cy = match geo_expr_real_double(center.coords_[1]) {
    Some(value) => value
    None => return None
  }
  let a = match geo_expr_real_double(@symelem.abs(hradius)) {
    Some(value) => value
    None => return None
  }
  let b = match geo_expr_real_double(@symelem.abs(vradius)) {
    Some(value) => value
    None => return None
  }
  let px = match geo_expr_real_double(pt.coords_[0] - center.coords_[0]) {
    Some(value) => value
    None => return None
  }
  let py = match geo_expr_real_double(pt.coords_[1] - center.coords_[1]) {
    Some(value) => value
    None => return None
  }
  let delta = a * a - b * b
  let coeffs = [
    delta * delta,
    -2.0 * a * px * delta,
    a * a * px * px - delta * delta + b * b * py * py,
    2.0 * a * px * delta,
    -a * a * px * px,
  ]
  let roots = match geo_poly_numeric_roots(coeffs) {
    Some(value) => value
    None => return None
  }
  let tol = 1.0e-7
  let numeric_points : Array[(Double, Double)] = []
  for root in roots {
    if root.1.abs() > tol {
      continue
    }
    let c = root.0
    if c < -1.0 - 1.0e-6 || c > 1.0 + 1.0e-6 {
      continue
    }
    let clamped = if c < -1.0 { -1.0 } else if c > 1.0 { 1.0 } else { c }
    let y_term = 1.0 - clamped * clamped
    let x = cx + a * clamped
    let y = cy - b * @math.pow(if y_term < 0.0 { 0.0 } else { y_term }, 0.5)
    let mut seen = false
    for prev in numeric_points {
      if (prev.0 - x).abs() <= 1.0e-6 && (prev.1 - y).abs() <= 1.0e-6 {
        seen = true
        break
      }
    }
    if !seen {
      numeric_points.push((x, y))
    }
  }
  ellipse_sort_points_in_place(numeric_points)
  let out : Array[Point] = []
  let rounded_digits = if digits < 0 { 12 } else { digits }
  for pair in numeric_points {
    out.push(
      point2d(
        geo_decimal_expr_from_double(pair.0, rounded_digits),
        geo_decimal_expr_from_double(pair.1, rounded_digits),
      ),
    )
  }
  Some(out)
}

///|
fn ellipse_normal_lines_numeric(
  center : Point,
  hradius : Expr,
  vradius : Expr,
  pt : Point,
  digits : Int,
) -> Array[Line]? raise GeometryError {
  let cx = match geo_expr_real_double(center.coords_[0]) {
    Some(value) => value
    None => return None
  }
  let cy = match geo_expr_real_double(center.coords_[1]) {
    Some(value) => value
    None => return None
  }
  let a = match geo_expr_real_double(@symelem.abs(hradius)) {
    Some(value) => value
    None => return None
  }
  let b = match geo_expr_real_double(@symelem.abs(vradius)) {
    Some(value) => value
    None => return None
  }
  let rounded_digits = if digits < 0 { 12 } else { digits }
  match
    ellipse_normal_boundary_points_numeric(center, hradius, vradius, pt, digits) {
    Some(points) => {
      let tol = 1.0e-10
      let lines : Array[Line] = []
      for boundary in points {
        let x = match geo_expr_real_double(boundary.coords_[0]) {
          Some(value) => value
          None => return None
        }
        let y = match geo_expr_real_double(boundary.coords_[1]) {
          Some(value) => value
          None => return None
        }
        let x_rel = x - cx
        let y_rel = y - cy
        let next_pt = if x_rel.abs() <= tol {
          point2d(
            boundary.coords_[0],
            geo_simplify(boundary.coords_[1] + int(1)),
          ) catch {
            _ => return None
          }
        } else {
          let slope = a * a * y_rel / (b * b * x_rel)
          point2d(
            geo_simplify(boundary.coords_[0] + int(1)),
            geo_simplify(
              boundary.coords_[1] +
              geo_decimal_expr_from_double(slope, rounded_digits),
            ),
          ) catch {
            _ => return None
          }
        }
        lines.push(line(boundary, next_pt) catch { _ => return None })
      }
      Some(lines)
    }
    None => None
  }
}

///|
fn ellipse_normal_axis_lines(
  center : Point,
  pt : Point,
) -> Array[Line] raise GeometryError {
  let out : Array[Line] = []
  if geo_expr_is_zero(pt.coords_[0] - center.coords_[0]) {
    out.push(
      line(center, point2d(center.coords_[0], center.coords_[1] + int(1))),
    )
  }
  if geo_expr_is_zero(pt.coords_[1] - center.coords_[1]) {
    out.push(
      line(center, point2d(center.coords_[0] + int(1), center.coords_[1])),
    )
  }
  out
}

///|
pub fn Ellipse::normal_lines(
  self : Ellipse,
  p : Point,
  prec? : Int? = None,
) -> Array[Line] raise GeometryError {
  let point_obj = p.with_dim(2)
  let axis_lines = ellipse_normal_axis_lines(self.center_, point_obj)
  if !axis_lines.is_empty() {
    return axis_lines
  }
  let digits = match prec {
    Some(value) => value
    None => 12
  }
  match
    ellipse_normal_lines_numeric(
      self.center_,
      self.hradius_,
      self.vradius_,
      point_obj,
      digits,
    ) {
    Some(lines) => lines
    None =>
      raise GeometryError::ValueError(
        "general symbolic ellipse normal lines are not supported",
      )
  }
}

///|
pub fn Circle::normal_lines(
  self : Circle,
  p : Point,
  prec? : Int? = None,
) -> Array[Line] raise GeometryError {
  Ellipse::{
    center_: self.center_,
    hradius_: self.radius_,
    vradius_: self.radius_,
  }.normal_lines(p, prec~)
}
