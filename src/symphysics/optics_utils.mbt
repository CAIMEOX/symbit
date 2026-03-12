///|
/// Scalar optics formulas aligned with the scalar branches of
/// `sympy.physics.optics.utils`.

///|
pub enum OpticsMediumArg {
  Medium(Medium)
  Index(@symcore.Expr)
} derive(Eq)

///|
fn oo_expr() -> @symcore.Expr {
  @symcore.symbol("oo")
}

///|
fn neg_oo_expr() -> @symcore.Expr {
  @symcore.int(-1) * oo_expr()
}

///|
fn is_infinite_expr(expr : @symcore.Expr) -> Bool {
  expr == oo_expr() || expr == neg_oo_expr()
}

///|
fn reciprocal_expr(expr : @symcore.Expr) -> @symcore.Expr {
  if is_infinite_expr(expr) {
    @symcore.int(0)
  } else {
    expr ^ @symcore.int(-1)
  }
}

///|
pub fn optics_medium_arg(medium : Medium) -> OpticsMediumArg {
  OpticsMediumArg::Medium(medium)
}

///|
pub fn optics_index_arg(index : @symcore.Expr) -> OpticsMediumArg {
  OpticsMediumArg::Index(index)
}

///|
pub fn refractive_index_of_medium(medium : OpticsMediumArg) -> @symcore.Expr {
  match medium {
    OpticsMediumArg::Medium(value) => value.refractive_index()
    OpticsMediumArg::Index(value) => value
  }
}

///|
pub fn refraction_angle(
  incident : @symcore.Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> @symcore.Expr {
  let n1 = refractive_index_of_medium(medium1)
  let n2 = refractive_index_of_medium(medium2)
  @symelem.asin(expr_div(n1 * @symelem.sin(incident), n2))
}

///|
pub fn fresnel_coefficients(
  angle_of_incidence : @symcore.Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Array[@symcore.Expr] {
  let angle_of_refraction = refraction_angle(
    angle_of_incidence, medium1, medium2,
  )
  let sum_angle = angle_of_incidence + angle_of_refraction
  let diff_angle = angle_of_incidence - angle_of_refraction
  let rs = expr_div(
    @symcore.int(-1) * @symelem.sin(diff_angle),
    @symelem.sin(sum_angle),
  )
  let rp = expr_div(@symelem.tan(diff_angle), @symelem.tan(sum_angle))
  let ts = expr_div(
    @symcore.int(2) *
    @symelem.sin(angle_of_refraction) *
    @symelem.cos(angle_of_incidence),
    @symelem.sin(sum_angle),
  )
  let tp = expr_div(
    @symcore.int(2) *
    @symelem.sin(angle_of_refraction) *
    @symelem.cos(angle_of_incidence),
    @symelem.sin(sum_angle) * @symelem.cos(diff_angle),
  )
  [rp, rs, tp, ts]
}

///|
pub fn deviation(
  incident : @symcore.Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> @symcore.Expr {
  refraction_angle(incident, medium1, medium2) - incident
}

///|
pub fn brewster_angle(
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> @symcore.Expr {
  @symelem.atan2(
    refractive_index_of_medium(medium2),
    refractive_index_of_medium(medium1),
  )
}

///|
pub fn critical_angle(
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> @symcore.Expr raise PhysicsError {
  let n1 = refractive_index_of_medium(medium1)
  let n2 = refractive_index_of_medium(medium2)
  match (expr_number_value(n1), expr_number_value(n2)) {
    (Some(lhs), Some(rhs)) if rhs.compare(lhs) > 0 =>
      raise PhysicsError::ValueError(
        "Total internal reflection impossible for n1 < n2",
      )
    _ => ()
  }
  @symelem.asin(expr_div(n2, n1))
}

///|
pub fn lens_makers_formula(
  n_lens : OpticsMediumArg,
  n_surr : OpticsMediumArg,
  r1 : @symcore.Expr,
  r2 : @symcore.Expr,
  d? : @symcore.Expr = @symcore.int(0),
) -> @symcore.Expr {
  let nl = refractive_index_of_medium(n_lens)
  let ns = refractive_index_of_medium(n_surr)
  let contrast = expr_div(nl - ns, ns)
  let curvature = reciprocal_expr(r1) -
    reciprocal_expr(r2) +
    expr_div((nl - ns) * d, nl * r1 * r2)
  expr_div(@symcore.int(1), contrast * curvature)
}

///|
pub fn mirror_formula(
  focal_length? : @symcore.Expr? = None,
  u? : @symcore.Expr? = None,
  v? : @symcore.Expr? = None,
) -> @symcore.Expr raise PhysicsError {
  let supplied = (if focal_length is Some(_) { 1 } else { 0 }) +
    (if u is Some(_) { 1 } else { 0 }) +
    (if v is Some(_) { 1 } else { 0 })
  guard supplied == 2 else {
    raise PhysicsError::ValueError("Please provide exactly two parameters")
  }
  match (focal_length, u, v) {
    (None, Some(uv), Some(vv)) =>
      if is_infinite_expr(uv) && is_infinite_expr(vv) {
        oo_expr()
      } else if is_infinite_expr(uv) {
        vv
      } else if is_infinite_expr(vv) {
        uv
      } else {
        expr_div(uv * vv, uv + vv)
      }
    (Some(ff), None, Some(vv)) =>
      if is_infinite_expr(vv) && is_infinite_expr(ff) {
        oo_expr()
      } else if is_infinite_expr(vv) {
        ff
      } else if is_infinite_expr(ff) {
        @symcore.int(-1) * vv
      } else {
        expr_div(ff * vv, vv - ff)
      }
    (Some(ff), Some(uv), None) =>
      if is_infinite_expr(uv) && is_infinite_expr(ff) {
        oo_expr()
      } else if is_infinite_expr(uv) {
        ff
      } else if is_infinite_expr(ff) {
        @symcore.int(-1) * uv
      } else {
        expr_div(ff * uv, uv - ff)
      }
    _ => raise PhysicsError::ValueError("Please provide exactly two parameters")
  }
}

///|
pub fn lens_formula(
  focal_length? : @symcore.Expr? = None,
  u? : @symcore.Expr? = None,
  v? : @symcore.Expr? = None,
) -> @symcore.Expr raise PhysicsError {
  let supplied = (if focal_length is Some(_) { 1 } else { 0 }) +
    (if u is Some(_) { 1 } else { 0 }) +
    (if v is Some(_) { 1 } else { 0 })
  guard supplied == 2 else {
    raise PhysicsError::ValueError("Please provide exactly two parameters")
  }
  match (focal_length, u, v) {
    (None, Some(uv), Some(vv)) =>
      if is_infinite_expr(uv) && is_infinite_expr(vv) {
        oo_expr()
      } else if is_infinite_expr(uv) {
        vv
      } else if is_infinite_expr(vv) {
        @symcore.int(-1) * uv
      } else {
        expr_div(uv * vv, uv - vv)
      }
    (Some(ff), None, Some(vv)) =>
      if is_infinite_expr(vv) && is_infinite_expr(ff) {
        neg_oo_expr()
      } else if is_infinite_expr(vv) {
        @symcore.int(-1) * ff
      } else if is_infinite_expr(ff) {
        vv
      } else {
        expr_div(ff * vv, ff - vv)
      }
    (Some(ff), Some(uv), None) =>
      if is_infinite_expr(uv) && is_infinite_expr(ff) {
        oo_expr()
      } else if is_infinite_expr(uv) {
        ff
      } else if is_infinite_expr(ff) {
        uv
      } else {
        expr_div(ff * uv, ff + uv)
      }
    _ => raise PhysicsError::ValueError("Please provide exactly two parameters")
  }
}

///|
pub fn hyperfocal_distance(
  f : @symcore.Expr,
  n : @symcore.Expr,
  c : @symcore.Expr,
) -> @symcore.Expr {
  expr_div(f ^ @symcore.int(2), n * c)
}

///|
pub fn transverse_magnification(
  si : @symcore.Expr,
  so : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.int(-1) * expr_div(si, so)
}
