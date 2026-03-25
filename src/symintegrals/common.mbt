///|
pub type Expr = @symcore.Expr

///|
pub type LimitSpec = (String, Expr?, Expr?)

///|
fn expr_zero() -> Expr {
  @symcore.int(0)
}

///|
fn expr_one() -> Expr {
  @symcore.int(1)
}

///|
fn expr_neg_one() -> Expr {
  @symcore.int(-1)
}

///|
fn expr_int(value : Int) -> Expr {
  @symcore.int(value)
}

///|
fn expr_from_num(value : @symnum.BigRational) -> Expr {
  @symcore.number(value)
}

///|
fn expr_rat(num : Int, den : Int) -> Expr {
  match
    (
      try? @symcore.rational_from_ints(num, den) :
      Result[Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => @symcore.function("Rational", [expr_int(num), expr_int(den)])
  }
}

///|
fn expr_simplify(expr : Expr) -> Expr {
  @symsimplify.simplify(expr)
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
    @symcore.Expr::Function("exp", [inner]) => {
      let inner = expr_eval_special(inner)
      match inner {
        @symcore.Expr::Function("log", [arg]) => expr_eval_special(arg)
        @symcore.Expr::Mul(args) if args.length() == 2 => {
          let mut numeric : @symnum.BigRational? = None
          let mut logged : Expr? = None
          for arg in args {
            match expr_num_value(arg) {
              Some(value) => numeric = Some(value)
              None =>
                match arg {
                  @symcore.Expr::Function("log", [base]) => logged = Some(base)
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
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(expr_eval_special))
    _ => expr_simplify(expr)
  }
}

///|
fn expr_add(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(lhs + rhs)
}

///|
fn expr_sub(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(lhs - rhs)
}

///|
fn expr_mul(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(lhs * rhs)
}

///|
fn expr_div(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(lhs * (rhs ^ expr_int(-1)))
}

///|
fn expr_pow(base : Expr, exp : Expr) -> Expr {
  expr_simplify(base ^ exp)
}

///|
fn expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  expr_simplify(lhs - rhs) == expr_zero()
}

///|
fn expr_num_value(expr : Expr) -> @symnum.BigRational? {
  match expr_simplify(expr) {
    @symcore.Expr::Number(n) => Some(n)
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
    _ => None
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
        Some(root) => expr_int(root)
        None => @symelem.sqrt(expr)
      }
    _ => @symelem.sqrt(expr)
  }
}

///|
fn expr_sqrt_positive(expr : Expr) -> Expr {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(@symcore.Expr::Function("exp", [arg]), exp) if expr_eq(
        exp,
        expr_int(2),
      ) => @symelem.exp(arg)
    @symcore.Expr::Mul(args) => {
      let mut numeric = expr_one()
      let mut exp_square : Expr? = None
      let rest : Array[Expr] = []
      for arg in args {
        match arg {
          _ if expr_num_value(arg) is Some(_) =>
            numeric = expr_mul(numeric, arg)
          @symcore.Expr::Pow(@symcore.Expr::Function("exp", [inner]), exp) =>
            if expr_eq(exp, expr_int(2)) && exp_square is None {
              exp_square = Some(@symelem.exp(inner))
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
fn tuple_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("Tuple", items)
}

///|
fn piecewise_expr(
  cases : Array[(Expr, Expr)],
  default? : Expr = expr_zero(),
) -> Expr {
  let args : Array[Expr] = []
  for item in cases {
    args.push(item.0)
    args.push(item.1)
  }
  args.push(default)
  args.push(@symcore.symbol("True"))
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
fn poly_coeffs_upto2(expr : Expr, var_name : String) -> Array[Expr]? {
  match expr_simplify(expr) {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_) =>
      Some([expr_simplify(expr), expr_zero(), expr_zero()])
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some([expr_zero(), expr_one(), expr_zero()])
      } else {
        Some([expr, expr_zero(), expr_zero()])
      }
    @symcore.Expr::Add(args) => {
      let coeffs = [expr_zero(), expr_zero(), expr_zero()]
      for arg in args {
        match poly_coeffs_upto2(arg, var_name) {
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
      let coeffs = [expr_one(), expr_zero(), expr_zero()]
      for arg in args {
        match poly_coeffs_upto2(arg, var_name) {
          Some(c) => {
            let next = [expr_zero(), expr_zero(), expr_zero()]
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
        Some(0) => Some([expr_one(), expr_zero(), expr_zero()])
        Some(1) => poly_coeffs_upto2(base, var_name)
        Some(2) =>
          match poly_coeffs_upto2(base, var_name) {
            Some(c) =>
              if !expr_is_zero(c[2]) {
                None
              } else {
                Some([
                  expr_mul(c[0], c[0]),
                  expr_mul(expr_int(2), expr_mul(c[0], c[1])),
                  expr_add(
                    expr_mul(c[1], c[1]),
                    expr_mul(expr_int(2), expr_mul(c[0], c[2])),
                  ),
                ])
              }
            None => None
          }
        _ =>
          if expr_depends_on(expr, var_name) {
            None
          } else {
            Some([expr, expr_zero(), expr_zero()])
          }
      }
    _ =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr, expr_zero(), expr_zero()])
      }
  }
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
        expr_one()
      } else {
        expr_simplify(@symcore.mul(num_parts))
      }
      let den = if den_parts.is_empty() {
        expr_one()
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
        Some((expr_one(), base))
      } else {
        None
      }
    _ => None
  }
}

///|
fn quadratic_discriminant(a : Expr, b : Expr, c : Expr) -> Expr {
  expr_sub(expr_mul(b, b), expr_mul(expr_int(4), expr_mul(a, c)))
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
