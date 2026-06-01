///|
/// Shared public aliases for `symintegrals`.
///
/// Current Limits:
/// - This file only exposes lightweight aliases used by the public integration front doors.
/// - It does not define additional runtime objects.
pub type Expr = @symcore.Expr

///|
/// Describe one parsed integration limit.
///
/// - Does: Names one integration variable together with optional lower and upper bounds.
/// - Input: A tuple `(String, Expr?, Expr?)`.
/// - Returns: A `LimitSpec` alias value.
/// - Limits: Missing bounds represent indefinite or partially specified limits.
pub type LimitSpec = (String, Expr?, Expr?)

///|
fn expr_from_num(value : @symnum.BigRational) -> Expr {
  @symcore.Expr::Number(value)
}

///|
fn expr_rat(num : Int, den : Int) -> Expr {
  match
    (
      try? @symcore.rational_from_ints(num, den) :
      Result[Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) =>
      @symcore.function("Rational", [@symcore.int(num), @symcore.int(den)])
  }
}

///|
fn expr_simplify(expr : Expr) -> Expr {
  @symsimplify.simplify(expr)
}

///|
fn[T] retry_with_simplified(expr : Expr, parse : (Expr) -> T?) -> T? {
  match parse(expr) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(expr)
      if @symcore.compare_expr(simplified, expr) == 0 {
        None
      } else {
        parse(simplified)
      }
    }
  }
}

///|
fn expr_exact_int(expr : Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.is_integral() {
        Some(n.numerator().to_int())
      } else {
        None
      }
    _ =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, den)) =>
          if den.to_int() == 1 {
            Some(num.to_int())
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn expr_trivial_zero(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ =>
      match expr_exact_int(expr) {
        Some(0) => true
        _ => false
      }
  }
}

///|
fn expr_trivial_one(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ =>
      match expr_exact_int(expr) {
        Some(1) => true
        _ => false
      }
  }
}

///|
fn expr_trivial_minus_one(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_integral() && n.numerator().equal_int(-1)
    _ =>
      match expr_exact_int(expr) {
        Some(-1) => true
        _ => false
      }
  }
}

///|
fn expr_eval_special(expr : Expr) -> Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      expr_simplify(@symcore.add(args.map(expr_eval_special)))
    @symcore.Expr::Mul(args) =>
      expr_simplify(@symcore.mul(args.map(expr_eval_special)))
    @symcore.Expr::Pow(base, exp) =>
      expr_simplify(expr_eval_special(base) ^ expr_eval_special(exp))
    _ if @symcore.application_has_name(expr, "exp", arity=1) =>
      match @symcore.application_args(expr) {
        Some([inner]) => {
          let inner = expr_eval_special(inner)
          match @symcore.application_parts(inner) {
            Some((head, [arg])) if @symcore.function_head_name(head) ==
              Some("log") => expr_eval_special(arg)
            _ =>
              match inner {
                @symcore.Expr::Mul(args) if args.length() == 2 => {
                  let mut numeric : @symnum.BigRational? = None
                  let mut logged : Expr? = None
                  for arg in args {
                    match expr_num_value(arg) {
                      Some(value) => numeric = Some(value)
                      None =>
                        match @symcore.application_parts(arg) {
                          Some((head, [base])) =>
                            if @symcore.function_head_name(head) == Some("log") {
                              logged = Some(base)
                            }
                          _ => ()
                        }
                    }
                  }
                  match (numeric, logged) {
                    (Some(power), Some(base)) =>
                      match expr_num_value(base) {
                        Some(base_value) =>
                          if base_value.compare(@symnum.BigRational::zero()) > 0 {
                            expr_simplify(base ^ expr_from_num(power))
                          } else {
                            @symelem.exp(inner)
                          }
                        _ => @symelem.exp(inner)
                      }
                    _ => @symelem.exp(inner)
                  }
                }
                _ => @symelem.exp(inner)
              }
          }
        }
        _ => expr_simplify(expr)
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.function_head_name(head) {
            Some(name) =>
              @symcore.raw_function(name, args.map(expr_eval_special))
            None => expr_simplify(expr)
          }
        None => expr_simplify(expr)
      }
  }
}

///|
fn expr_add(lhs : Expr, rhs : Expr) -> Expr {
  if expr_trivial_zero(lhs) {
    rhs
  } else if expr_trivial_zero(rhs) {
    lhs
  } else {
    @symcore.add([lhs, rhs])
  }
}

///|
fn expr_sub(lhs : Expr, rhs : Expr) -> Expr {
  if expr_trivial_zero(rhs) {
    lhs
  } else if expr_trivial_zero(lhs) {
    @symcore.mul([@symcore.int(-1), rhs])
  } else {
    @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])
  }
}

///|
fn expr_mul(lhs : Expr, rhs : Expr) -> Expr {
  if expr_trivial_zero(lhs) || expr_trivial_zero(rhs) {
    @symcore.int(0)
  } else if expr_trivial_one(lhs) {
    rhs
  } else if expr_trivial_one(rhs) {
    lhs
  } else if expr_trivial_minus_one(lhs) {
    @symcore.mul([@symcore.int(-1), rhs])
  } else if expr_trivial_minus_one(rhs) {
    @symcore.mul([@symcore.int(-1), lhs])
  } else {
    @symcore.mul([lhs, rhs])
  }
}

///|
fn expr_div(lhs : Expr, rhs : Expr) -> Expr {
  if expr_trivial_zero(lhs) {
    @symcore.int(0)
  } else if expr_trivial_one(rhs) {
    lhs
  } else if expr_trivial_minus_one(rhs) {
    @symcore.mul([@symcore.int(-1), lhs])
  } else {
    @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
  }
}

///|
fn expr_pow(base : Expr, exp : Expr) -> Expr {
  if expr_trivial_zero(exp) {
    @symcore.int(1)
  } else if expr_trivial_one(exp) {
    base
  } else if expr_trivial_zero(base) {
    @symcore.int(0)
  } else if expr_trivial_one(base) {
    @symcore.int(1)
  } else {
    @symcore.pow(base, exp)
  }
}

///|
fn expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  @symcore.compare_expr(lhs, rhs) == 0 ||
  expr_simplify(lhs - rhs) == @symcore.int(0)
}

///|
fn expr_num_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    @symcore.Expr::Add(args) => {
      let mut acc = @symnum.BigRational::zero()
      for arg in args {
        match expr_num_value(arg) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = @symnum.BigRational::one()
      for arg in args {
        match expr_num_value(arg) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (expr_num_value(base), expr_exact_int(exp)) {
        (Some(base), Some(power)) => {
          let zero = @symnum.BigRational::zero()
          if power == 0 {
            Some(@symnum.BigRational::one())
          } else if power < 0 && base.compare(zero) == 0 {
            None
          } else {
            let mut out = @symnum.BigRational::one()
            let factor = if power < 0 {
              try? base.reciprocal()
            } else {
              Ok(base)
            }
            match factor {
              Err(_) => return None
              Ok(factor0) => {
                let mut factor = factor0
                let mut n = if power < 0 { -power } else { power }
                while n > 0 {
                  if (n & 1) == 1 {
                    out = out * factor
                  }
                  n = n / 2
                  if n > 0 {
                    factor = factor * factor
                  }
                }
                Some(out)
              }
            }
          }
        }
        _ => None
      }
    @symcore.Expr::Float(f) =>
      if !f.is_finite() {
        None
      } else {
        let pair : Result[(BigInt, BigInt), @symnum.MpfError] = try? f.to_rational()
        match pair {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
      }
    @symcore.Expr::ComplexFloat(z) =>
      if !z.is_finite() || !@symnum.is_zero(z.to_mpc().imag) {
        None
      } else {
        let pair : Result[(BigInt, BigInt), @symnum.MpfError] = try? z
          .real_part()
          .to_rational()
        match pair {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
      }
    _ =>
      match expr_simplify(expr) {
        simplified if @symcore.compare_expr(simplified, expr) == 0 => None
        simplified => expr_num_value(simplified)
      }
  }
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  match expr_num_value(expr) {
    Some(n) => n.is_zero()
    None => false
  }
}

///|
fn expr_is_one(expr : Expr) -> Bool {
  match expr_num_value(expr) {
    Some(n) => n.is_one()
    None => false
  }
}

///|
fn expr_is_minus_one(expr : Expr) -> Bool {
  match expr_num_value(expr) {
    Some(n) => n.compare(@symnum.BigRational::from_int(-1)) == 0
    None => false
  }
}

///|
fn expr_is_int_value(expr : Expr) -> Int? {
  match expr_num_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn int_sqrt_if_square(n : Int) -> Int? {
  if n < 0 {
    return None
  }
  let mut i = 0
  while i * i < n {
    i += 1
  }
  if i * i == n {
    Some(i)
  } else {
    None
  }
}

///|
fn expr_exact_sqrt(expr : Expr) -> Expr {
  match expr_num_value(expr) {
    Some(n) if n.is_integral() =>
      match int_sqrt_if_square(n.numerator().to_int()) {
        Some(root) => @symcore.int(root)
        None => @symelem.sqrt(expr)
      }
    _ => @symelem.sqrt(expr)
  }
}

///|
fn expr_sqrt_positive(expr : Expr) -> Expr {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) if expr_eq(exp, @symcore.int(2)) &&
      @symcore.application_has_name(base, "exp", arity=1) =>
      match @symcore.application_args(base) {
        Some([arg]) => @symelem.exp(arg)
        _ => @symelem.sqrt(expr)
      }
    @symcore.Expr::Mul(args) => {
      let mut numeric = @symcore.int(1)
      let mut exp_square : Expr? = None
      let rest : Array[Expr] = []
      for arg in args {
        match arg {
          _ if expr_num_value(arg) is Some(_) =>
            numeric = expr_mul(numeric, arg)
          @symcore.Expr::Pow(base, exp) =>
            if expr_eq(exp, @symcore.int(2)) &&
              exp_square is None &&
              @symcore.application_has_name(base, "exp", arity=1) {
              match @symcore.application_args(base) {
                Some([inner]) => exp_square = Some(@symelem.exp(inner))
                _ => rest.push(arg)
              }
            } else {
              rest.push(arg)
            }
          _ => rest.push(arg)
        }
      }
      match exp_square {
        Some(exp_part) if rest.is_empty() =>
          expr_simplify(expr_exact_sqrt(numeric) * exp_part)
        _ => @symelem.sqrt(expr)
      }
    }
    _ => @symelem.sqrt(expr)
  }
}

///|

///|
fn piecewise_expr(
  cases : Array[(Expr, Expr)],
  default? : Expr = @symcore.int(0),
) -> Expr {
  let args : Array[Expr] = []
  for item in cases {
    args.push(item.0)
    args.push(item.1)
  }
  args.push(default)
  args.push(@symcore.Expr::Boolean(true))
  @symcore.raw_function("Piecewise", args)
}

///|
fn subst_symbol(expr : Expr, var_name : String, value : Expr) -> Expr {
  let env : Map[String, Expr] = {}
  env[var_name] = value
  @symcore.subst(expr, env)
}

///|
fn expr_depends_on(expr : Expr, var_name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name == var_name
    _ => @symcore.children(expr).any(child => expr_depends_on(child, var_name))
  }
}

///|
fn collect_symbols(expr : Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_symbols(child, seen)
      }
  }
}

///|
fn infer_single_symbol(expr : Expr) -> String? {
  let seen : Map[String, Bool] = {}
  collect_symbols(expr, seen)
  let names : Array[String] = []
  for name, _ in seen {
    names.push(name)
  }
  if names.length() == 1 {
    Some(names[0])
  } else {
    None
  }
}

///|
fn parse_limit(limit : Expr) -> LimitSpec? {
  match limit {
    @symcore.Expr::Symbol(name) => Some((name, None, None))
    _ =>
      match @symcore.tuple_items(limit) {
        Some([@symcore.Expr::Symbol(name)]) => Some((name, None, None))
        Some([@symcore.Expr::Symbol(name), lower, upper]) =>
          Some((name, Some(lower), Some(upper)))
        _ => None
      }
  }
}

///|
fn poly_coeffs_upto2_raw(expr : Expr, var_name : String) -> Array[Expr]? {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_) =>
      Some([expr, @symcore.int(0), @symcore.int(0)])
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some([@symcore.int(0), @symcore.int(1), @symcore.int(0)])
      } else {
        Some([expr, @symcore.int(0), @symcore.int(0)])
      }
    @symcore.Expr::Add(args) => {
      let coeffs = [@symcore.int(0), @symcore.int(0), @symcore.int(0)]
      for arg in args {
        match poly_coeffs_upto2_raw(arg, var_name) {
          Some(c) => {
            coeffs[0] = expr_add(coeffs[0], c[0])
            coeffs[1] = expr_add(coeffs[1], c[1])
            coeffs[2] = expr_add(coeffs[2], c[2])
          }
          None => return None
        }
      }
      Some(coeffs)
    }
    @symcore.Expr::Mul(args) => {
      let coeffs = [@symcore.int(1), @symcore.int(0), @symcore.int(0)]
      for arg in args {
        match poly_coeffs_upto2_raw(arg, var_name) {
          Some(c) => {
            let next = [@symcore.int(0), @symcore.int(0), @symcore.int(0)]
            for i in 0..<3 {
              for j in 0..<3 {
                if i + j > 2 {
                  if !(expr_is_zero(coeffs[i]) || expr_is_zero(c[j])) {
                    return None
                  }
                  continue
                }
                next[i + j] = expr_add(next[i + j], expr_mul(coeffs[i], c[j]))
              }
            }
            coeffs[0] = next[0]
            coeffs[1] = next[1]
            coeffs[2] = next[2]
          }
          None => return None
        }
      }
      Some(coeffs)
    }
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(0) => Some([@symcore.int(1), @symcore.int(0), @symcore.int(0)])
        Some(1) => poly_coeffs_upto2_raw(base, var_name)
        Some(2) =>
          match poly_coeffs_upto2_raw(base, var_name) {
            Some(c) =>
              if !expr_is_zero(c[2]) {
                None
              } else {
                Some([
                  expr_mul(c[0], c[0]),
                  expr_mul(@symcore.int(2), expr_mul(c[0], c[1])),
                  expr_add(
                    expr_mul(c[1], c[1]),
                    expr_mul(@symcore.int(2), expr_mul(c[0], c[2])),
                  ),
                ])
              }
            None => None
          }
        _ =>
          if expr_depends_on(expr, var_name) {
            None
          } else {
            Some([expr, @symcore.int(0), @symcore.int(0)])
          }
      }
    _ =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr, @symcore.int(0), @symcore.int(0)])
      }
  }
}

///|
fn poly_coeffs_upto2(expr : Expr, var_name : String) -> Array[Expr]? {
  retry_with_simplified(expr, expr => poly_coeffs_upto2_raw(expr, var_name))
}

///|
fn poly_coeffs_general_int(expr : Expr, var_name : String) -> Array[Expr]? {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::NumberSymbol(_)
    | @symcore.Expr::ComplexFloat(_) => Some([expr])
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some([@symcore.int(0), @symcore.int(1)])
      } else {
        Some([expr])
      }
    @symcore.Expr::Dummy(_, _)
    | @symcore.Expr::Wild(_, _, _)
    | @symcore.Expr::FunctionHead(_)
    | @symcore.Expr::UndefinedFunction(_) => Some([expr])
    @symcore.Expr::Apply(_, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Add(args) => {
      let acc : Array[Expr] = [@symcore.int(0)]
      for arg in args {
        match poly_coeffs_general_int(arg, var_name) {
          Some(coeffs) => poly_accum_general_int(acc, coeffs)
          None => return None
        }
      }
      Some(poly_trim_general_int(acc))
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[Expr] = [@symcore.int(1)]
      for arg in args {
        match poly_coeffs_general_int(arg, var_name) {
          Some(coeffs) => acc = poly_mul_general_int(acc, coeffs)
          None => return None
        }
      }
      Some(poly_trim_general_int(acc))
    }
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power >= 0 =>
          match poly_coeffs_general_int(base, var_name) {
            Some(coeffs) => Some(poly_pow_general_int(coeffs, power))
            None => None
          }
        _ => if expr_depends_on(expr, var_name) { None } else { Some([expr]) }
      }
    @symcore.Expr::Mod(_, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Derivative(_, _) | @symcore.Expr::Subs(_, _, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    _ if @symcore.application_parts(expr) is Some(_) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Boolean(_)
    | @symcore.Expr::Tuple(_)
    | @symcore.Expr::Dict(_)
    | @symcore.Expr::Relational(_, _, _)
    | @symcore.Expr::Lambda(_, _) => None
    _ => if expr_depends_on(expr, var_name) { None } else { Some([expr]) }
  }
}

///|
fn poly_accum_general_int(acc : Array[Expr], coeffs : Array[Expr]) -> Unit {
  if coeffs.length() > acc.length() {
    let mut idx = acc.length()
    while idx < coeffs.length() {
      acc.push(@symcore.int(0))
      idx += 1
    }
  }
  for i in 0..<coeffs.length() {
    acc[i] = expr_add(acc[i], coeffs[i])
  }
}

///|
fn poly_mul_general_int(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  if lhs.is_empty() || rhs.is_empty() {
    return []
  }
  let out : Array[Expr] = []
  for _ in 0..<(lhs.length() + rhs.length() - 1) {
    out.push(@symcore.int(0))
  }
  for i in 0..<lhs.length() {
    for j in 0..<rhs.length() {
      out[i + j] = expr_add(out[i + j], expr_mul(lhs[i], rhs[j]))
    }
  }
  poly_trim_general_int(out)
}

///|
fn poly_pow_general_int(base : Array[Expr], exp : Int) -> Array[Expr] {
  if exp == 0 {
    return [@symcore.int(1)]
  }
  let mut result : Array[Expr] = [@symcore.int(1)]
  let mut factor = base
  let mut n = exp
  while n > 0 {
    if n % 2 == 1 {
      result = poly_mul_general_int(result, factor)
    }
    n = n / 2
    if n > 0 {
      factor = poly_mul_general_int(factor, factor)
    }
  }
  poly_trim_general_int(result)
}

///|
fn poly_trim_general_int(poly : Array[Expr]) -> Array[Expr] {
  let mut end = poly.length()
  while end > 0 && expr_is_zero(poly[end - 1]) {
    end -= 1
  }
  let out : Array[Expr] = []
  for i in 0..<end {
    out.push(poly[i])
  }
  out
}

///|
fn polynomial_horner_light_from_coeffs(
  coeffs : Array[Expr],
  var_name : String,
) -> Expr {
  if coeffs.is_empty() {
    return @symcore.int(0)
  }
  let x = @symcore.Expr::Symbol(var_name)
  let mut out = coeffs[coeffs.length() - 1]
  let mut idx = coeffs.length() - 1
  while idx > 0 {
    idx -= 1
    out = @symcore.add([@symcore.mul([out, x]), coeffs[idx]])
  }
  out
}

///|
fn polynomial_antiderivative(coeffs : Array[Expr], var_name : String) -> Expr {
  if coeffs.is_empty() {
    return @symcore.int(0)
  }
  let anti : Array[Expr] = [@symcore.int(0)]
  for i in 0..<coeffs.length() {
    anti.push(@symcore.mul([coeffs[i], expr_rat(1, i + 1)]))
  }
  polynomial_horner_light_from_coeffs(anti, var_name)
}

///|
fn linear_coeffs(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match poly_coeffs_upto2(expr, var_name) {
    Some(coeffs) if expr_is_zero(coeffs[2]) => Some((coeffs[1], coeffs[0]))
    _ => None
  }
}

///|
fn is_univariate_rational(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => {
      let num_parts : Array[Expr] = []
      let den_parts : Array[Expr] = []
      for arg in args {
        match arg {
          @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
            den_parts.push(base)
          _ => num_parts.push(arg)
        }
      }
      let num = if num_parts.is_empty() {
        @symcore.int(1)
      } else {
        expr_simplify(@symcore.mul(num_parts))
      }
      let den = if den_parts.is_empty() {
        @symcore.int(1)
      } else {
        expr_simplify(@symcore.mul(den_parts))
      }
      if poly_coeffs_upto2(num, var_name) is Some(_) &&
        poly_coeffs_upto2(den, var_name) is Some(_) {
        Some((num, den))
      } else {
        None
      }
    }
    @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
      if poly_coeffs_upto2(base, var_name) is Some(_) {
        Some((@symcore.int(1), base))
      } else {
        None
      }
    _ => None
  }
}

///|
fn quadratic_discriminant(a : Expr, b : Expr, c : Expr) -> Expr {
  expr_sub(expr_mul(b, b), expr_mul(@symcore.int(4), expr_mul(a, c)))
}

///|
fn symbol_name(expr : Expr) -> String? {
  match expr {
    @symcore.Expr::Symbol(name) => Some(name)
    _ => None
  }
}

///|
fn expr_is_symbol(expr : Expr, name : String) -> Bool {
  symbol_name(expr) == Some(name)
}
