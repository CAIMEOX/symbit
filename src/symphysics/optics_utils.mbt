///|
/// Scalar optics formulas aligned with the scalar branches of
/// `sympy.physics.optics.utils`.

///|
pub enum OpticsMediumArg {
  Medium(Medium)
  Index(Expr)
} derive(Eq)

///|
fn oo_expr() -> Expr {
  @symcore.oo()
}

///|
fn neg_oo_expr() -> Expr {
  int(-1) * oo_expr()
}

///|
fn is_infinite_expr(expr : Expr) -> Bool {
  expr == oo_expr() || expr == neg_oo_expr()
}

///|
fn reciprocal_expr(expr : Expr) -> Expr {
  if is_infinite_expr(expr) {
    int(0)
  } else {
    expr ^ int(-1)
  }
}

///|
fn optics_rational_to_double(value : @symnum.BigRational) -> Double {
  value.numerator().to_int().to_double() /
  value.denominator().to_int().to_double()
}

///|
fn optics_expr_real_double(expr : Expr) -> Double? {
  match expr {
    Expr::Number(value) => Some(optics_rational_to_double(value))
    Expr::Symbol(name) if name == "pi" => Some(@math.PI)
    Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match optics_expr_real_double(arg) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match optics_expr_real_double(arg) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match (optics_expr_real_double(base), expr_number_value(exp)) {
        (Some(lhs), Some(rhs)) =>
          Some(@math.pow(lhs, optics_rational_to_double(rhs)))
        _ => None
      }
    _ => None
  }
}

///|
fn optics_numeric_tir(
  incident : Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Bool {
  match
    (
      optics_expr_real_double(incident),
      expr_number_value(refractive_index_of_medium(medium1)),
      expr_number_value(refractive_index_of_medium(medium2)),
    ) {
    (Some(angle), Some(n1), Some(n2)) => {
      let lhs = optics_rational_to_double(n1)
      let rhs = optics_rational_to_double(n2)
      if rhs > lhs {
        false
      } else {
        angle > @math.asin(rhs / lhs)
      }
    }
    _ => false
  }
}

///|
pub fn optics_medium_arg(medium : Medium) -> OpticsMediumArg {
  OpticsMediumArg::Medium(medium)
}

///|
pub fn optics_index_arg(index : Expr) -> OpticsMediumArg {
  OpticsMediumArg::Index(index)
}

///|
pub fn refractive_index_of_medium(medium : OpticsMediumArg) -> Expr {
  match medium {
    OpticsMediumArg::Medium(value) => value.refractive_index()
    OpticsMediumArg::Index(value) => value
  }
}

///|
pub fn refraction_angle(
  incident : Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Expr raise PhysicsError {
  match expr_number_value(incident) {
    Some(value) if value.compare(@symnum.BigRational::zero()) < 0 =>
      raise PhysicsError::ValueError("Angle of incidence not in range [0:pi/2)")
    _ => ()
  }
  match optics_expr_real_double(incident) {
    Some(value) if value < 0.0 || value >= @math.PI * 0.5 =>
      raise PhysicsError::ValueError("Angle of incidence not in range [0:pi/2)")
    _ => ()
  }
  if optics_numeric_tir(incident, medium1, medium2) {
    raise PhysicsError::ValueError("Ray undergoes total internal reflection")
  }
  let n1 = refractive_index_of_medium(medium1)
  let n2 = refractive_index_of_medium(medium2)
  @symelem.asin(expr_div(n1 * @symelem.sin(incident), n2))
}

///|
pub fn fresnel_coefficients(
  angle_of_incidence : Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Array[Expr] raise PhysicsError {
  match expr_number_value(angle_of_incidence) {
    Some(value) if value.compare(@symnum.BigRational::zero()) < 0 =>
      raise PhysicsError::ValueError("Angle of incidence not in range [0:pi/2)")
    _ => ()
  }
  match optics_expr_real_double(angle_of_incidence) {
    Some(value) if value < 0.0 || value >= @math.PI * 0.5 =>
      raise PhysicsError::ValueError("Angle of incidence not in range [0:pi/2)")
    _ => ()
  }
  if optics_numeric_tir(angle_of_incidence, medium1, medium2) {
    let n1 = refractive_index_of_medium(medium1)
    let n2 = refractive_index_of_medium(medium2)
    let n = expr_div(n2, n1)
    let radical = @symelem.sqrt(
      (@symelem.sin(angle_of_incidence) ^ int(2)) - (n ^ int(2)),
    )
    let rs = expr_div(
      @symelem.cos(angle_of_incidence) - i_expr() * radical,
      @symelem.cos(angle_of_incidence) + i_expr() * radical,
    )
    let rp = expr_div(
      (n ^ int(2)) * @symelem.cos(angle_of_incidence) - i_expr() * radical,
      (n ^ int(2)) * @symelem.cos(angle_of_incidence) + i_expr() * radical,
    )
    return [rp, rs]
  }
  let angle_of_refraction = refraction_angle(
    angle_of_incidence, medium1, medium2,
  )
  let sum_angle = angle_of_incidence + angle_of_refraction
  let diff_angle = angle_of_incidence - angle_of_refraction
  let rs = expr_div(int(-1) * @symelem.sin(diff_angle), @symelem.sin(sum_angle))
  let rp = expr_div(@symelem.tan(diff_angle), @symelem.tan(sum_angle))
  let ts = expr_div(
    int(2) *
    @symelem.sin(angle_of_refraction) *
    @symelem.cos(angle_of_incidence),
    @symelem.sin(sum_angle),
  )
  let tp = expr_div(
    int(2) *
    @symelem.sin(angle_of_refraction) *
    @symelem.cos(angle_of_incidence),
    @symelem.sin(sum_angle) * @symelem.cos(diff_angle),
  )
  [rp, rs, tp, ts]
}

///|
pub fn deviation(
  incident : Expr,
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Expr raise PhysicsError {
  refraction_angle(incident, medium1, medium2) - incident
}

///|
pub fn brewster_angle(
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Expr {
  @symelem.atan2(
    refractive_index_of_medium(medium2),
    refractive_index_of_medium(medium1),
  )
}

///|
pub fn critical_angle(
  medium1 : OpticsMediumArg,
  medium2 : OpticsMediumArg,
) -> Expr raise PhysicsError {
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
  r1 : Expr,
  r2 : Expr,
  d? : Expr = int(0),
) -> Expr {
  let nl = refractive_index_of_medium(n_lens)
  let ns = refractive_index_of_medium(n_surr)
  let contrast = expr_div(nl - ns, ns)
  let curvature = reciprocal_expr(r1) -
    reciprocal_expr(r2) +
    expr_div((nl - ns) * d, nl * r1 * r2)
  expr_div(int(1), contrast * curvature)
}

///|
pub fn mirror_formula(
  focal_length? : Expr? = None,
  u? : Expr? = None,
  v? : Expr? = None,
) -> Expr raise PhysicsError {
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
        int(-1) * vv
      } else {
        expr_div(ff * vv, vv - ff)
      }
    (Some(ff), Some(uv), None) =>
      if is_infinite_expr(uv) && is_infinite_expr(ff) {
        oo_expr()
      } else if is_infinite_expr(uv) {
        ff
      } else if is_infinite_expr(ff) {
        int(-1) * uv
      } else {
        expr_div(ff * uv, uv - ff)
      }
    _ => raise PhysicsError::ValueError("Please provide exactly two parameters")
  }
}

///|
pub fn lens_formula(
  focal_length? : Expr? = None,
  u? : Expr? = None,
  v? : Expr? = None,
) -> Expr raise PhysicsError {
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
        int(-1) * uv
      } else {
        expr_div(uv * vv, uv - vv)
      }
    (Some(ff), None, Some(vv)) =>
      if is_infinite_expr(vv) && is_infinite_expr(ff) {
        neg_oo_expr()
      } else if is_infinite_expr(vv) {
        int(-1) * ff
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
pub fn hyperfocal_distance(f : Expr, n : Expr, c : Expr) -> Expr {
  expr_div(f ^ int(2), n * c)
}

///|
pub fn transverse_magnification(si : Expr, so : Expr) -> Expr {
  int(-1) * expr_div(si, so)
}
