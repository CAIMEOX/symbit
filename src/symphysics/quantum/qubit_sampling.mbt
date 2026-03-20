///|
/// One-shot measurement helpers for qubit states.
///
/// SymPy samples from the measurement distribution using Python's RNG. The
/// MoonBit port keeps that probabilistic behavior and also accepts an optional
/// `sample` in `[0, 1)` so tests can force a deterministic branch.

///|
let qubit_measure_random_source : @random.Rand = @random.Rand::new()

///|
fn expr_number_value_local(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_rational_to_double(value : @symnum.BigRational) -> Double {
  value.numerator().to_int().to_double() /
  value.denominator().to_int().to_double()
}

///|
fn complex_add(
  lhs : (Double, Double),
  rhs : (Double, Double),
) -> (Double, Double) {
  (lhs.0 + rhs.0, lhs.1 + rhs.1)
}

///|
fn complex_mul(
  lhs : (Double, Double),
  rhs : (Double, Double),
) -> (Double, Double) {
  (lhs.0 * rhs.0 - lhs.1 * rhs.1, lhs.0 * rhs.1 + lhs.1 * rhs.0)
}

///|
fn complex_inv(value : (Double, Double)) -> (Double, Double)? {
  let denom = value.0 * value.0 + value.1 * value.1
  if denom == 0.0 {
    None
  } else {
    Some((value.0 / denom, -value.1 / denom))
  }
}

///|
fn expr_complex_double(expr : Expr) -> (Double, Double)? {
  match expr {
    Expr::Number(n) => Some((expr_rational_to_double(n), 0.0))
    Expr::Symbol(name) =>
      match name {
        "I" => Some((0.0, 1.0))
        "pi" => Some((@math.PI, 0.0))
        _ => None
      }
    Expr::Add(args) => {
      let mut acc = (0.0, 0.0)
      for arg in args {
        match expr_complex_double(arg) {
          Some(value) => acc = complex_add(acc, value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = (1.0, 0.0)
      for arg in args {
        match expr_complex_double(arg) {
          Some(value) => acc = complex_mul(acc, value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match (expr_complex_double(base), expr_number_value_local(exp)) {
        (Some(base_value), Some(exp_value)) =>
          if base_value.1 != 0.0 {
            None
          } else if exp_value.is_integral() {
            let power = exp_value.numerator().to_int()
            if power == 0 {
              Some((1.0, 0.0))
            } else if power > 0 {
              let mut acc = (1.0, 0.0)
              for _ in 0..<power {
                acc = complex_mul(acc, base_value)
              }
              Some(acc)
            } else {
              let mut acc = (1.0, 0.0)
              for _ in 0..<-power {
                acc = complex_mul(acc, base_value)
              }
              complex_inv(acc)
            }
          } else {
            let exponent = expr_rational_to_double(exp_value)
            Some((@math.pow(base_value.0, exponent), 0.0))
          }
        _ => None
      }
    Expr::Function("sqrt", args) if args.length() == 1 =>
      match expr_complex_double(args[0]) {
        Some(value) if value.1 == 0.0 && value.0 >= 0.0 =>
          Some((value.0.sqrt(), 0.0))
        _ => None
      }
    Expr::Function("exp", args) if args.length() == 1 =>
      match expr_complex_double(args[0]) {
        Some(value) => {
          let factor = @math.exp(value.0)
          Some((factor * @math.cos(value.1), factor * @math.sin(value.1)))
        }
        None => None
      }
    Expr::Function("conjugate", args) if args.length() == 1 =>
      match expr_complex_double(args[0]) {
        Some(value) => Some((value.0, -value.1))
        None => None
      }
    _ => None
  }
}

///|
fn expr_real_probability(expr : Expr) -> Double? {
  match expr_complex_double(expr) {
    Some(value) if value.1.abs() <= 0.0000000001 => Some(value.0)
    _ => None
  }
}

///|
fn oneshot_sample_value(
  sample : Double,
) -> Double raise @symphysics.PhysicsError {
  if sample >= 0.0 {
    guard sample < 1.0 else {
      raise @symphysics.PhysicsError::ValueError(
        "measurement sample must lie in [0, 1)",
      )
    }
    sample
  } else {
    qubit_measure_random_source.double()
  }
}

///|
fn choose_measurement_state(
  states : Array[(Expr, Expr)],
  sample : Double,
) -> Expr raise @symphysics.PhysicsError {
  guard !states.is_empty() else {
    raise @symphysics.PhysicsError::ValueError(
      "measurement produced no possible outcomes",
    )
  }
  let cutoff = oneshot_sample_value(sample)
  let mut total = 0.0
  for item in states {
    let prob = match expr_real_probability(item.1) {
      Some(value) => value
      None =>
        raise @symphysics.PhysicsError::ValueError(
          "one-shot measurement needs numerically evaluable probabilities",
        )
    }
    total += prob
    if total > cutoff || (total - cutoff).abs() <= 0.000000000001 {
      return item.0
    }
  }
  states[states.length() - 1].0
}

///|
pub fn measure_partial_oneshot(
  expr : Expr,
  bits : Array[Int],
  nqubits? : Int = 0,
  sample? : Double = -1.0,
) -> Expr raise @symphysics.PhysicsError {
  choose_measurement_state(measure_partial(expr, bits, nqubits~), sample)
}

///|
pub fn measure_all_oneshot(
  expr : Expr,
  nqubits? : Int = 0,
  sample? : Double = -1.0,
) -> Expr raise @symphysics.PhysicsError {
  choose_measurement_state(measure_all(expr, nqubits~), sample)
}
