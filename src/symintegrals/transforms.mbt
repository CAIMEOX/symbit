///|
/// Stage-5 transform helpers.

///|
pub fn do_laplace_doit(expr : Expr, t : Expr, s : Expr) -> Expr? {
  match symbol_name(t) {
    Some(t_name) => laplace_doit(expr_simplify(expr), t_name, s)
    None => None
  }
}

fn laplace_doit(expr : Expr, t_name : String, s : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(
        terms,
        t_name,
        fn (term) { laplace_doit(term, t_name, s) },
      )
    _ => {
      let (coeff, factors) = split_mul(expr, t_name)
      if factors.length() == 0 {
        match laplace_term(coeff, t_name, s) {
          Some(v) => Some(v)
          None => None
        }
      } else if factors.length() == 1 {
        match laplace_term(factors[0], t_name, s) {
          Some(v) => Some(expr_mul(coeff, v))
          None => None
        }
      } else {
        None
      }
    }
  }
}

fn laplace_term(expr : Expr, t_name : String, s : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Number(_) => Some(expr_div(expr, s))
    @symcore.Expr::Symbol(name) => {
      if name == t_name {
        Some(expr_div(expr_one(), expr_pow(s, expr_int(2))))
      } else {
        None
      }
    }
    @symcore.Expr::Pow(base, exp) => {
      let base_name = symbol_name(base)
      if base_name == None {
        None
      } else {
        let name = match base_name {
          Some(v) => v
          None => ""
        }
        match expr_is_int_value(exp) {
          Some(power) =>
            if name == t_name && power >= 0 {
              Some(expr_div(factorial_expr(expr_int(power)), expr_pow(s, expr_int(power + 1))))
            } else {
              None
            }
          None => None
        }
      }
    }
    @symcore.Expr::Function("exp", [inner]) => {
      match linear_coeffs(inner, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            Some(expr_mul(@symelem.exp(b), expr_div(expr_one(), expr_sub(s, a))))
          }
        }
        None => None
      }
    }
    @symcore.Expr::Function("sin", [arg]) => {
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            laplace_trig_term(a, b, s, true)
          }
        }
        None => None
      }
    }
    @symcore.Expr::Function("cos", [arg]) => {
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            laplace_trig_term(a, b, s, false)
          }
        }
        None => None
      }
    }
    _ => None
  }
}

fn laplace_trig_term(a : Expr, b : Expr, s : Expr, is_sin : Bool) -> Expr? {
  let a2 = expr_pow(a, expr_int(2))
  let den = expr_add(a2, expr_pow(s, expr_int(2)))
  if expr_is_zero(b) {
    if is_sin {
      Some(expr_div(a, den))
    } else {
      Some(expr_div(s, den))
    }
  } else {
    let cb = @symelem.cos(b)
    let sb = @symelem.sin(b)
    if is_sin {
      Some(
        expr_add(
          expr_mul(cb, expr_div(a, den)),
          expr_mul(sb, expr_div(s, den)),
        ),
      )
    } else {
      Some(
        expr_sub(
          expr_mul(cb, expr_div(s, den)),
          expr_mul(sb, expr_div(a, den)),
        ),
      )
    }
  }
}

///|
pub fn do_inverse_laplace_doit(expr : Expr, s : Expr, t : Expr) -> Expr? {
  match symbol_name(s) {
    Some(s_name) => inverse_laplace_doit(expr_simplify(expr), s_name, t)
    None => None
  }
}

fn inverse_laplace_doit(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(
        terms,
        s_name,
        fn (term) { inverse_laplace_doit(term, s_name, t) },
      )
    _ => {
      let (num_exprs, den_opt) = split_division(expr)
      match den_opt {
        None => None
        Some(den) => {
          let (coeff, var_expr_opt) = split_mul_factor(num_exprs, s_name)
          match var_expr_opt {
            None => inverse_laplace_no_var(coeff, den, t, s_name)
            Some(var_expr) => inverse_laplace_with_var(coeff, var_expr, den, t, s_name)
          }
        }
      }
    }
  }
}

fn inverse_laplace_no_var(
  coeff : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  if expr_eq(den, s_sym) {
    Some(expr_mul(coeff, @symspec.heaviside(t)))
  } else {
    match split_linear_coeff(den, s_name) {
      Some(pair) => {
        let a = pair.0
        let b = pair.1
        if expr_is_zero(a) {
          None
        } else {
          Some(
            expr_mul(
              expr_mul(
                expr_div(coeff, a),
                @symspec.heaviside(t),
              ),
              @symelem.exp(expr_mul(expr_div(expr_neg_one(), a), expr_mul(b, t))),
            ),
          )
        }
      }
      None => None
    }
  }
}

fn inverse_laplace_with_var(
  coeff : Expr,
  num_var : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  let freq_opt = denom_to_square_freq(den, s_name)
    match freq_opt {
      Some(freq) =>
        if expr_is_zero(freq) {
          None
        } else if expr_eq(num_var, expr_one()) {
          Some(
            expr_mul(
              expr_mul(
                expr_div(coeff, freq),
                @symspec.heaviside(t),
              ),
              @symelem.sin(expr_mul(freq, t)),
            ),
          )
        } else if expr_eq(num_var, s_sym) {
          Some(
            expr_mul(
              expr_mul(
                coeff,
                @symspec.heaviside(t),
              ),
              @symelem.cos(expr_mul(freq, t)),
            ),
          )
        } else {
          None
        }
    None => None
  }
}

///|
pub fn do_fourier_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => fourier_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

fn fourier_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(
        terms,
        x_name,
        fn (term) { fourier_doit(term, x_name, k) },
      )
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        match fourier_term(coeff, x_name, k) {
          Some(v) => Some(v)
          None => None
        }
      } else if factors.length() == 1 {
        match fourier_term(factors[0], x_name, k) {
          Some(v) => Some(expr_mul(coeff, v))
          None => None
        }
      } else {
        None
      }
    }
  }
}

fn fourier_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Function("exp", [inner]) =>
      match extract_fourier_coeff(inner, x_name) {
        Some(scale) =>
          Some(
                expr_mul(
                  expr_div(sqrt_pi(), expr_sqrt_positive(scale)),
                  @symelem.exp(
                    expr_mul(
                      expr_neg_one(),
                      expr_div(
                        expr_pow(expr_mul(@symcore.symbol("pi"), k), expr_int(2)),
                        scale,
                      ),
                    ),
                  ),
                ),
              )
        None => None
      }
    _ => None
  }
}

///|
pub fn do_inverse_fourier_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_fourier_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

fn inverse_fourier_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() == 0 {
    None
  } else if factors.length() != 1 {
    None
  } else {
    match factors[0] {
      @symcore.Expr::Function("exp", [inner]) =>
        match extract_inverse_fourier_coeff(inner, k_name) {
          Some(scale) =>
            Some(expr_mul(coeff, @symelem.exp(expr_mul(expr_neg_one(), expr_mul(scale, expr_pow(x, expr_int(2)))))))
          None => None
        }
      _ => None
    }
  }
}

///|
pub fn do_mellin_doit(_expr : Expr, x : Expr, s : Expr) -> Expr? {
  match (symbol_name(x), symbol_name(s)) {
    (Some(_), Some(_)) => None
    _ => None
  }
}

///|
pub fn do_inverse_mellin_doit(_expr : Expr, s : Expr, x : Expr) -> Expr? {
  match (symbol_name(s), symbol_name(x)) {
    (Some(_), Some(_)) => None
    _ => None
  }
}

fn transform_add(
  terms : Array[Expr],
  _var_name : String,
  map_term : (Expr) -> Expr?,
) -> Expr? {
  let mapped : Array[Expr] = []
  for term in terms {
    match map_term(term) {
      Some(v) => mapped.push(v)
      None => return None
    }
  }
  Some(expr_simplify(@symcore.add(mapped)))
}

fn split_mul(expr : Expr, var_name : String) -> (Expr, Array[Expr]) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Mul(args) => {
      let mut coeff = expr_one()
      let vars : Array[Expr] = []
      for factor in args {
        if expr_depends_on(factor, var_name) {
          vars.push(factor)
        } else {
          coeff = expr_mul(coeff, factor)
        }
      }
      (coeff, vars)
    }
    _ =>
      if expr_depends_on(simplified, var_name) {
        (expr_one(), [simplified])
      } else {
        (simplified, [])
      }
  }
}

fn split_division(expr : Expr) -> (Array[Expr], Expr?) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Mul(args) => {
      let num : Array[Expr] = []
      let den : Array[Expr] = []
      for factor in args {
        match factor {
          @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
            den.push(base)
          _ => num.push(factor)
        }
      }
      if den.length() == 0 {
        (num, None)
      } else {
        let den_expr = if den.length() == 1 {
          den[0]
        } else {
          expr_simplify(@symcore.mul(den))
        }
        (num, Some(den_expr))
      }
    }
    _ => ([simplified], None)
  }
}

fn split_mul_factor(
  factors : Array[Expr],
  var_name : String,
) -> (Expr, Expr?) {
  let mut coeff = expr_one()
  let mut var_expr : Option[Expr] = None
  for item in factors {
    if expr_depends_on(item, var_name) {
      var_expr = Some(
        match var_expr {
          None => item
          Some(prev) => expr_mul(prev, item)
        },
      )
    } else {
      coeff = expr_mul(coeff, item)
    }
  }
  (coeff, var_expr)
}

fn split_linear_coeff(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match poly_coeffs_upto2(expr_simplify(expr), var_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[2]) {
        Some((coeffs[1], coeffs[0]))
      } else {
        None
      }
    _ => None
  }
}

fn denom_to_square_freq(den : Expr, s_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(expr_simplify(den), s_name)
  match coeffs {
    Some(c) =>
      if expr_is_zero(c[1]) &&
        !expr_depends_on(c[0], s_name) &&
        !expr_depends_on(c[2], s_name) {
        if expr_is_zero(c[2]) {
          None
        } else {
          let ratio = expr_div(c[0], c[2])
          if expr_is_negative(ratio) {
            None
          } else {
            Some(expr_sqrt_positive(ratio))
          }
        }
      } else {
        None
      }
    _ => None
  }
}

fn extract_fourier_coeff(inner : Expr, x_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(expr_simplify(inner), x_name)
  match coeffs {
    Some(c) =>
      if expr_is_zero(c[1]) && expr_is_zero(c[0]) && expr_is_negative(c[2]) {
        Some(expr_mul(expr_int(-1), c[2]))
      } else {
        None
      }
    _ => None
  }
}

fn extract_inverse_fourier_coeff(inner : Expr, k_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(expr_simplify(inner), k_name)
  match coeffs {
    Some(c) =>
      if expr_is_zero(c[1]) &&
        !expr_depends_on(c[0], k_name) &&
        !expr_depends_on(c[2], k_name) &&
        expr_is_negative(c[2]) {
        Some(expr_mul(expr_int(-1), c[2]))
      } else {
        None
      }
    _ => None
  }
}

fn factorial_expr(n : Expr) -> Expr {
  match expr_is_int_value(n) {
    Some(v) if v > 1 => {
      let mut i = 2
      let mut out = expr_int(1)
      while i <= v {
        out = expr_mul(out, expr_int(i))
        i += 1
      }
      out
    }
    Some(v) if v >= 0 => expr_int(1)
    _ => expr_zero()
  }
}

fn sqrt_pi() -> Expr {
  @symelem.sqrt(@symcore.symbol("pi"))
}

fn expr_is_negative(expr : Expr) -> Bool {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero()) < 0
    None => false
  }
}
