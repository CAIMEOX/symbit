///|
type GeoComplex = (Double, Double)

///|
fn geo_rational_to_double(value : @symnum.BigRational) -> Double {
  value.numerator().to_int().to_double() /
  value.denominator().to_int().to_double()
}

///|
fn geo_expr_real_double(expr : Expr) -> Double? {
  match geo_simplify(expr) {
    Expr::Number(value) => Some(geo_rational_to_double(value))
    Expr::Float(value) =>
      try value.to_double() catch {
        _ => None
      } noraise {
        out => Some(out)
      }
    Expr::ComplexFloat(value) =>
      if @symnum.is_zero(value.to_mpc().imag) {
        try value.real_part().to_double() catch {
          _ => None
        } noraise {
          out => Some(out)
        }
      } else {
        None
      }
    Expr::Dummy(_, _)
    | Expr::Wild(_, _, _)
    | Expr::FunctionHead(_)
    | Expr::UndefinedFunction(_) => None
    Expr::Dict(_) => None
    Expr::Mod(_, _) => None
    Expr::NumberSymbol(kind) =>
      match kind {
        @symcore.NumberSymbolKind::Pi => Some(@math.PI)
        @symcore.NumberSymbolKind::Exp1 => Some(2.718281828459045)
        @symcore.NumberSymbolKind::EulerGamma => Some(0.5772156649015329)
        @symcore.NumberSymbolKind::GoldenRatio => Some(1.618033988749895)
        @symcore.NumberSymbolKind::Catalan => Some(0.915965594177219)
        _ => None
      }
    Expr::Symbol(name) =>
      match name {
        "pi" => Some(@math.PI)
        "E" => Some(2.718281828459045)
        _ => None
      }
    Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match geo_expr_real_double(arg) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match geo_expr_real_double(arg) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match (geo_expr_real_double(base), geo_expr_real_double(exp)) {
        (Some(lhs), Some(rhs)) => Some(@math.pow(lhs, rhs))
        _ => None
      }
    _ =>
      match (@symcore.application_name(expr), @symcore.application_args(expr)) {
        (Some(name), Some([arg])) =>
          match (name, geo_expr_real_double(arg)) {
            ("sqrt", Some(value)) => Some(@math.pow(value, 0.5))
            ("abs", Some(value)) => Some(value.abs())
            ("sin", Some(value)) => Some(@math.sin(value))
            ("cos", Some(value)) => Some(@math.cos(value))
            ("tan", Some(value)) => Some(@math.tan(value))
            ("asin", Some(value)) => Some(@math.asin(value))
            ("acos", Some(value)) => Some(@math.acos(value))
            ("atan", Some(value)) => Some(@math.atan(value))
            _ => None
          }
        _ => None
      }
  }
}

///|
fn geo_int_pow10(exp : Int) -> Int {
  let mut out = 1
  for _ in 0..<exp {
    out = out * 10
  }
  out
}

///|
fn geo_round_to_int(value : Double) -> Int {
  if value >= 0.0 {
    @math.floor(value + 0.5).to_int()
  } else {
    @math.ceil(value - 0.5).to_int()
  }
}

///|
fn geo_decimal_expr_from_double(value : Double, digits : Int) -> Expr {
  let prec = if digits < 0 { 0 } else { digits }
  let denom = geo_int_pow10(prec)
  let numer = geo_round_to_int(value * denom.to_double())
  match
    (
      try? @symcore.rational_from_ints(numer, denom) :
      Result[Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) =>
      @symcore.mul([
        @symcore.int(numer),
        @symcore.pow(@symcore.int(denom), @symcore.int(-1)),
      ])
  }
}

///|
fn geo_complex_add(lhs : GeoComplex, rhs : GeoComplex) -> GeoComplex {
  (lhs.0 + rhs.0, lhs.1 + rhs.1)
}

///|
fn geo_complex_sub(lhs : GeoComplex, rhs : GeoComplex) -> GeoComplex {
  (lhs.0 - rhs.0, lhs.1 - rhs.1)
}

///|
fn geo_complex_mul(lhs : GeoComplex, rhs : GeoComplex) -> GeoComplex {
  (lhs.0 * rhs.0 - lhs.1 * rhs.1, lhs.0 * rhs.1 + lhs.1 * rhs.0)
}

///|
fn geo_complex_abs(value : GeoComplex) -> Double {
  @math.pow(value.0 * value.0 + value.1 * value.1, 0.5)
}

///|
fn geo_complex_is_zero(value : GeoComplex, tol? : Double = 1.0e-12) -> Bool {
  geo_complex_abs(value) <= tol
}

///|
fn geo_complex_div(lhs : GeoComplex, rhs : GeoComplex) -> GeoComplex? {
  let denom = rhs.0 * rhs.0 + rhs.1 * rhs.1
  if denom <= 1.0e-24 {
    None
  } else {
    Some(
      (
        (lhs.0 * rhs.0 + lhs.1 * rhs.1) / denom,
        (lhs.1 * rhs.0 - lhs.0 * rhs.1) / denom,
      ),
    )
  }
}

///|
fn geo_poly_eval_complex(
  coeffs : Array[GeoComplex],
  value : GeoComplex,
) -> GeoComplex {
  let mut acc = (0.0, 0.0)
  for coeff in coeffs {
    acc = geo_complex_add(geo_complex_mul(acc, value), coeff)
  }
  acc
}

///|
fn geo_sort_complex_roots_in_place(roots : Array[GeoComplex]) -> Unit {
  for i in 0..<roots.length() {
    for j in (i + 1)..<roots.length() {
      let lhs = roots[i]
      let rhs = roots[j]
      if rhs.0 < lhs.0 || (rhs.0 == lhs.0 && rhs.1 < lhs.1) {
        roots[i] = rhs
        roots[j] = lhs
      }
    }
  }
}

///|
fn geo_poly_trim_leading_zeros(coeffs : Array[Double]) -> Array[Double] {
  let mut idx = 0
  while idx < coeffs.length() - 1 && coeffs[idx].abs() <= 1.0e-16 {
    idx += 1
  }
  coeffs[idx:].to_array()
}

///|
fn geo_poly_numeric_roots(coeffs0 : Array[Double]) -> Array[GeoComplex]? {
  if coeffs0.is_empty() {
    return Some([])
  }
  let coeffs = geo_poly_trim_leading_zeros(coeffs0)
  let degree = coeffs.length() - 1
  if degree <= 0 {
    return Some([])
  }
  if coeffs[0].abs() <= 1.0e-16 {
    return None
  }
  let lead = coeffs[0]
  let norm : Array[GeoComplex] = []
  for coeff in coeffs {
    norm.push((coeff / lead, 0.0))
  }
  let roots : Array[GeoComplex] = []
  let angle_step = 2.0 * @math.PI / degree.to_double()
  for i in 0..<degree {
    let angle = angle_step * i.to_double()
    let radius = 1.0 + 0.3 * i.to_double() / degree.to_double()
    roots.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  let tol = 1.0e-12
  for _ in 0..<250 {
    let mut max_delta = 0.0
    for i in 0..<roots.length() {
      let xi = roots[i]
      let mut denom = (1.0, 0.0)
      for j in 0..<roots.length() {
        if i != j {
          denom = geo_complex_mul(denom, geo_complex_sub(xi, roots[j]))
        }
      }
      if geo_complex_is_zero(denom) {
        denom = geo_complex_add(denom, (1.0e-9, 1.0e-9))
      }
      let px = geo_poly_eval_complex(norm, xi)
      let delta = match geo_complex_div(px, denom) {
        Some(value) => value
        None => return None
      }
      roots[i] = geo_complex_sub(xi, delta)
      let step = geo_complex_abs(delta)
      if step > max_delta {
        max_delta = step
      }
    }
    if max_delta < tol {
      break
    }
  }
  geo_sort_complex_roots_in_place(roots)
  Some(roots)
}
