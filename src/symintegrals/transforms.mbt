///|
/// Stage-5 transform helpers.

///|
type LaplaceInfo = (Expr, Expr, Expr)

///|
type MellinInfo = (Expr, Expr, Expr, Expr)

///|
pub fn do_laplace_doit(expr : Expr, t : Expr, s : Expr) -> Expr? {
  match symbol_name(t) {
    Some(t_name) =>
      match laplace_info_doit(expr_simplify(expr), t_name, s) {
        Some(info) => Some(info.0)
        None => None
      }
    None => None
  }
}

///|
pub fn laplace_transform_result(
  expr : Expr,
  t : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match symbol_name(t) {
    Some(t_name) =>
      match laplace_info_doit(expr_simplify(expr), t_name, s) {
        Some((value, plane, cond)) =>
          if noconds {
            value
          } else {
            tuple_expr([value, plane, cond])
          }
        None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
      }
    None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
  }
}

///|
fn laplace_info_doit(expr : Expr, t_name : String, s : Expr) -> LaplaceInfo? {
  match expr {
    @symcore.Expr::Add(terms) => laplace_add_info(terms, t_name, s)
    _ => {
      let (coeff, factors) = split_mul(expr, t_name)
      match laplace_mul_term(factors, t_name, s) {
        Some((value, plane, cond)) =>
          Some((expr_mul(coeff, value), plane, cond))
        None => None
      }
    }
  }
}

///|
fn laplace_add_info(
  terms : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let values : Array[Expr] = []
  let mut plane : Expr? = None
  let mut cond = true_expr()
  for term in terms {
    match laplace_info_doit(term, t_name, s) {
      Some((value, roc, term_cond)) => {
        values.push(value)
        plane = Some(
          match plane {
            Some(prev) => max_expr(prev, roc)
            None => roc
          },
        )
        cond = and_expr(cond, term_cond)
      }
      None => return None
    }
  }
  Some(
    (expr_simplify(@symcore.add(values)), plane.unwrap_or(expr_zero()), cond),
  )
}

///|
fn laplace_mul_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() == 0 {
    return laplace_base_term(expr_one(), t_name, s)
  }
  match laplace_delta_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_heaviside_shift_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  let mut exp_coeff : Expr? = None
  let mut exp_const = expr_zero()
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match linear_coeffs(inner, t_name) {
          Some((a, b)) =>
            if exp_coeff is None {
              exp_coeff = Some(a)
              exp_const = b
            } else {
              return None
            }
          None => rest.push(factor)
        }
      _ => rest.push(factor)
    }
  }
  let shifted_s = match exp_coeff {
    Some(a) => expr_sub(s, a)
    None => s
  }
  let base_info = laplace_rest_term(rest, t_name, shifted_s, s)
  match base_info {
    Some((value, plane, cond)) =>
      match exp_coeff {
        Some(a) =>
          Some(
            (expr_mul(@symelem.exp(exp_const), value), expr_add(plane, a), cond),
          )
        None => Some((value, plane, cond))
      }
    None => None
  }
}

///|
fn laplace_rest_term(
  factors : Array[Expr],
  t_name : String,
  shifted_s : Expr,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() == 0 {
    return laplace_base_term(expr_one(), t_name, shifted_s)
  }
  if factors.length() == 1 {
    return laplace_base_term(factors[0], t_name, shifted_s)
  }
  match symbol_name(s) {
    Some(_) => laplace_power_times_term(factors, t_name, shifted_s, s)
    None => None
  }
}

///|
fn laplace_power_times_term(
  factors : Array[Expr],
  t_name : String,
  shifted_s : Expr,
  s : Expr,
) -> LaplaceInfo? {
  let mut total_power = 0
  let rest : Array[Expr] = []
  for factor in factors {
    match parse_power_factor(factor, t_name) {
      Some(power_expr) =>
        match expr_is_int_value(power_expr) {
          Some(power) if power >= 0 => total_power += power
          _ => return None
        }
      None => rest.push(factor)
    }
  }
  if total_power == 0 || rest.length() != 1 {
    return None
  }
  match laplace_base_term(rest[0], t_name, shifted_s) {
    Some((value, plane, cond)) => {
      let mut out = value
      for _ in 0..<total_power {
        out = expr_mul(expr_neg_one(), @symcalculus.diff(out, s))
      }
      Some((expr_simplify(out), plane, cond))
    }
    None => None
  }
}

///|
fn laplace_delta_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut delta_at : Expr? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("DiracDelta", [arg]) =>
        match linear_coeffs(arg, t_name) {
          Some((coeff, offset)) =>
            if delta_at is None &&
              (expr_is_one(coeff) || expr_is_minus_one(coeff)) {
              delta_at = Some(
                if expr_is_one(coeff) {
                  expr_mul(expr_neg_one(), offset)
                } else {
                  offset
                },
              )
            } else {
              return None
            }
          None => return None
        }
      _ => rest.push(factor)
    }
  }
  match delta_at {
    Some(at) =>
      if expr_is_negative(at) {
        Some((expr_zero(), neg_oo_expr(), true_expr()))
      } else {
        Some(
          (
            expr_simplify(
              expr_mul(
                subst_symbol(factors_expr(rest), t_name, at),
                @symelem.exp(expr_mul(expr_neg_one(), expr_mul(at, s))),
              ),
            ),
            neg_oo_expr(),
            nonnegative_condition(at),
          ),
        )
      }
    None => None
  }
}

///|
fn laplace_heaviside_shift_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut shift : Expr? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, t_name) {
          Some((bound, is_le)) =>
            if shift is None && !is_le {
              shift = Some(bound)
            } else {
              return None
            }
          None => return None
        }
      _ => rest.push(factor)
    }
  }
  match shift {
    Some(bound) =>
      if expr_is_negative(bound) {
        None
      } else {
        let shift_name = if t_name == "_laplace_u" {
          "_laplace_v"
        } else {
          "_laplace_u"
        }
        let shift_var = @symcore.symbol(shift_name)
        let shifted = subst_symbol(
          factors_expr(rest),
          t_name,
          expr_add(shift_var, bound),
        )
        match laplace_info_doit(expr_simplify(shifted), shift_name, s) {
          Some((value, plane, cond)) =>
            Some(
              (
                expr_simplify(
                  expr_mul(
                    @symelem.exp(expr_mul(expr_neg_one(), expr_mul(bound, s))),
                    value,
                  ),
                ),
                plane,
                and_expr(cond, nonnegative_condition(bound)),
              ),
            )
          None => None
        }
      }
    None => None
  }
}

///|
fn laplace_base_term(expr : Expr, t_name : String, s : Expr) -> LaplaceInfo? {
  match expr {
    @symcore.Expr::Number(_) =>
      Some((expr_div(expr, s), expr_zero(), true_expr()))
    @symcore.Expr::Symbol(name) =>
      if name == t_name {
        Some(
          (
            expr_div(expr_one(), expr_pow(s, expr_int(2))),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
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
              Some(
                (
                  expr_div(
                    factorial_expr(expr_int(power)),
                    expr_pow(s, expr_int(power + 1)),
                  ),
                  expr_zero(),
                  true_expr(),
                ),
              )
            } else {
              None
            }
          None => None
        }
      }
    }
    @symcore.Expr::Function("sin", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, true) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("cos", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, false) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("sinh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_hyperbolic_term(a, b, s, true) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("cosh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_hyperbolic_term(a, b, s, false) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("Derivative", args) =>
      laplace_derivative_term(args, t_name, s)
    _ => None
  }
}

///|
fn laplace_derivative_term(
  args : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let order = match laplace_derivative_order(args, t_name) {
    Some(v) if v > 0 => v
    _ => return None
  }
  let base = args[0]
  let t_sym = @symcore.symbol(t_name)
  let (base_value, plane, cond) = match
    laplace_info_doit(expr_simplify(base), t_name, s) {
    Some(info) => info
    None =>
      (
        @symcore.raw_function("LaplaceTransform", [base, t_sym, s]),
        neg_oo_expr(),
        true_expr(),
      )
  }
  let leading = expr_mul(expr_pow(s, expr_int(order)), base_value)
  let init_terms : Array[Expr] = []
  for idx in 0..<order {
    let init = laplace_initial_value(base, t_sym, t_name, idx)
    let s_pow = order - idx - 1
    init_terms.push(
      if s_pow == 0 {
        init
      } else {
        expr_mul(expr_pow(s, expr_int(s_pow)), init)
      },
    )
  }
  Some(
    (
      expr_simplify(
        expr_sub(
          leading,
          if init_terms.length() == 1 {
            init_terms[0]
          } else {
            expr_simplify(@symcore.add(init_terms))
          },
        ),
      ),
      plane,
      cond,
    ),
  )
}

///|
fn laplace_derivative_order(args : Array[Expr], t_name : String) -> Int? {
  if args.length() < 2 {
    return None
  }
  let mut order = 0
  let mut saw_var = false
  for idx in 1..<args.length() {
    match args[idx] {
      @symcore.Expr::Symbol(name) if name == t_name => {
        order += 1
        saw_var = true
      }
      @symcore.Expr::Number(n) if saw_var &&
        n.is_integral() &&
        n.numerator().to_int() >= 1 => order += n.numerator().to_int() - 1
      _ => return None
    }
  }
  if saw_var {
    Some(order)
  } else {
    None
  }
}

///|
fn laplace_initial_value(
  base : Expr,
  t_sym : Expr,
  t_name : String,
  order : Int,
) -> Expr {
  if order == 0 {
    expr_simplify(subst_symbol(base, t_name, expr_zero()))
  } else {
    let mut deriv = base
    for _ in 0..<order {
      deriv = @symcalculus.diff(deriv, t_sym)
    }
    if expr_has_function_name(deriv, "Derivative") {
      @symcore.raw_function("Subs", [deriv, t_sym, expr_zero()])
    } else {
      expr_simplify(subst_symbol(deriv, t_name, expr_zero()))
    }
  }
}

///|
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
        expr_add(expr_mul(cb, expr_div(a, den)), expr_mul(sb, expr_div(s, den))),
      )
    } else {
      Some(
        expr_sub(expr_mul(cb, expr_div(s, den)), expr_mul(sb, expr_div(a, den))),
      )
    }
  }
}

///|
fn laplace_hyperbolic_term(
  a : Expr,
  b : Expr,
  s : Expr,
  is_sinh : Bool,
) -> Expr? {
  let a2 = expr_pow(a, expr_int(2))
  let den = expr_sub(expr_pow(s, expr_int(2)), a2)
  let cb = @symelem.cosh(b)
  let sb = @symelem.sinh(b)
  if is_sinh {
    Some(
      expr_add(expr_mul(cb, expr_div(a, den)), expr_mul(sb, expr_div(s, den))),
    )
  } else {
    Some(
      expr_add(expr_mul(cb, expr_div(s, den)), expr_mul(sb, expr_div(a, den))),
    )
  }
}

///|
pub fn do_inverse_laplace_doit(expr : Expr, s : Expr, t : Expr) -> Expr? {
  match symbol_name(s) {
    Some(s_name) => inverse_laplace_doit(expr_simplify(expr), s_name, t)
    None => None
  }
}

///|
fn inverse_laplace_doit(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, s_name, fn(term) {
        inverse_laplace_doit(term, s_name, t)
      })
    _ =>
      match inverse_laplace_delay_term(expr, s_name, t) {
        Some(v) => Some(v)
        None => {
          let (num_exprs, den_opt) = split_division(expr)
          match den_opt {
            None => None
            Some(den) => {
              let (coeff, var_expr_opt) = split_mul_factor(num_exprs, s_name)
              match var_expr_opt {
                None => inverse_laplace_no_var(coeff, den, t, s_name)
                Some(var_expr) =>
                  inverse_laplace_with_var(coeff, var_expr, den, t, s_name)
              }
            }
          }
        }
      }
  }
}

///|
fn inverse_laplace_delay_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let t_name = match symbol_name(t) {
    Some(v) => v
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut delay : Expr? = None
  let mut exp_const = expr_zero()
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match linear_coeffs(inner, s_name) {
          Some((coeff, offset)) if expr_is_negative(coeff) =>
            if delay is None {
              delay = Some(expr_mul(expr_neg_one(), coeff))
              exp_const = offset
            } else {
              return None
            }
          _ => rest.push(factor)
        }
      _ => rest.push(factor)
    }
  }
  match delay {
    Some(amount) =>
      match
        inverse_laplace_doit(
          expr_simplify(expr_mul(@symelem.exp(exp_const), factors_expr(rest))),
          s_name,
          t,
        ) {
        Some(value) =>
          Some(expr_simplify(subst_symbol(value, t_name, expr_sub(t, amount))))
        None => None
      }
    None => None
  }
}

///|
fn inverse_laplace_no_var(
  coeff : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match inverse_laplace_two_linear_factors(expr_zero(), coeff, den, t, s_name) {
    Some(v) => Some(v)
    None =>
      match split_shifted_square_denom(den, s_name) {
        Some((lead, shift, freq)) =>
          if expr_is_zero(freq) {
            None
          } else {
            Some(
              expr_simplify(
                expr_mul(
                  expr_mul(
                    expr_mul(
                      expr_div(coeff, expr_mul(lead, freq)),
                      @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
                    ),
                    @symelem.sin(expr_mul(freq, t)),
                  ),
                  @symspec.heaviside(t),
                ),
              ),
            )
          }
        None =>
          match denom_to_diff_square_freq(den, s_name) {
            Some(freq) =>
              Some(
                expr_simplify(
                  expr_mul(
                    expr_mul(
                      expr_div(coeff, freq),
                      @symelem.sinh(expr_mul(freq, t)),
                    ),
                    @symspec.heaviside(t),
                  ),
                ),
              )
            None =>
              match split_linear_power_denom(den, s_name) {
                Some((a, b, power)) =>
                  if expr_is_zero(a) {
                    None
                  } else {
                    let scale = expr_div(
                      coeff,
                      expr_mul(
                        expr_pow(a, expr_int(power)),
                        factorial_expr(expr_int(power - 1)),
                      ),
                    )
                    let tpow = if power == 1 {
                      expr_one()
                    } else {
                      expr_pow(t, expr_int(power - 1))
                    }
                    Some(
                      expr_simplify(
                        expr_mul(
                          expr_mul(expr_mul(scale, tpow), @symspec.heaviside(t)),
                          @symelem.exp(
                            expr_mul(
                              expr_div(expr_neg_one(), a),
                              expr_mul(b, t),
                            ),
                          ),
                        ),
                      ),
                    )
                  }
                None => None
              }
          }
      }
  }
}

///|
fn inverse_laplace_with_var(
  coeff : Expr,
  num_var : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_linear_coeff(num_var, s_name) {
    Some((lin_coeff, lin_const)) =>
      match
        inverse_laplace_two_linear_factors(
          expr_mul(coeff, lin_coeff),
          expr_mul(coeff, lin_const),
          den,
          t,
          s_name,
        ) {
        Some(v) => return Some(v)
        None => ()
      }
    None => ()
  }
  match split_shifted_square_denom(den, s_name) {
    Some((lead, shift, freq)) =>
      if expr_is_zero(freq) {
        None
      } else {
        match split_linear_coeff(num_var, s_name) {
          Some((lin_coeff, lin_const)) => {
            let centered_const = expr_sub(lin_const, expr_mul(lin_coeff, shift))
            let cos_part = if expr_is_zero(lin_coeff) {
              expr_zero()
            } else {
              expr_mul(lin_coeff, @symelem.cos(expr_mul(freq, t)))
            }
            let sin_part = if expr_is_zero(centered_const) {
              expr_zero()
            } else {
              expr_mul(
                expr_div(centered_const, freq),
                @symelem.sin(expr_mul(freq, t)),
              )
            }
            Some(
              expr_simplify(
                expr_mul(
                  expr_mul(
                    expr_mul(
                      expr_div(coeff, lead),
                      @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
                    ),
                    @symspec.heaviside(t),
                  ),
                  expr_add(cos_part, sin_part),
                ),
              ),
            )
          }
          None => None
        }
      }
    None =>
      match denom_to_diff_square_freq(den, s_name) {
        Some(freq) =>
          match split_linear_coeff(num_var, s_name) {
            Some((lin_coeff, lin_const)) =>
              Some(
                expr_simplify(
                  expr_mul(
                    @symspec.heaviside(t),
                    expr_add(
                      expr_mul(
                        expr_mul(coeff, lin_coeff),
                        @symelem.cosh(expr_mul(freq, t)),
                      ),
                      expr_mul(
                        expr_div(expr_mul(coeff, lin_const), freq),
                        @symelem.sinh(expr_mul(freq, t)),
                      ),
                    ),
                  ),
                ),
              )
            None => None
          }
        None => None
      }
  }
}

///|
fn inverse_laplace_two_linear_factors(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_two_linear_factors(den, s_name) {
    Some(((a1, b1), (a2, b2))) => {
      let det = expr_sub(expr_mul(a2, b1), expr_mul(a1, b2))
      if expr_is_zero(det) {
        None
      } else {
        let left_coeff = expr_div(
          expr_sub(expr_mul(num_linear, b1), expr_mul(num_const, a1)),
          det,
        )
        let right_coeff = expr_div(
          expr_sub(expr_mul(num_const, a2), expr_mul(num_linear, b2)),
          det,
        )
        Some(
          expr_simplify(
            expr_mul(
              @symspec.heaviside(t),
              expr_add(
                expr_mul(
                  expr_div(left_coeff, a1),
                  @symelem.exp(
                    expr_mul(expr_div(expr_neg_one(), a1), expr_mul(b1, t)),
                  ),
                ),
                expr_mul(
                  expr_div(right_coeff, a2),
                  @symelem.exp(
                    expr_mul(expr_div(expr_neg_one(), a2), expr_mul(b2, t)),
                  ),
                ),
              ),
            ),
          ),
        )
      }
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

///|
fn fourier_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { fourier_doit(term, x_name, k) })
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

///|
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

///|
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
            Some(
              expr_mul(
                coeff,
                @symelem.exp(
                  expr_mul(
                    expr_neg_one(),
                    expr_mul(scale, expr_pow(x, expr_int(2))),
                  ),
                ),
              ),
            )
          None => None
        }
      _ => None
    }
  }
}

///|
pub fn do_sine_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => sine_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

///|
fn sine_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { sine_doit(term, x_name, k) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      match sine_mul_term(factors, x_name, k) {
        Some(value) => Some(expr_mul(coeff, value))
        None => None
      }
    }
  }
}

///|
fn sine_mul_term(factors : Array[Expr], x_name : String, k : Expr) -> Expr? {
  if factors.length() == 1 {
    return sine_base_term(factors[0], x_name, k)
  }
  let mut exp_quad : Expr? = None
  let mut x_pow = expr_zero()
  for factor in factors {
    match parse_power_factor(factor, x_name) {
      Some(power) => x_pow = expr_add(x_pow, power)
      None =>
        match factor {
          @symcore.Expr::Function("exp", [inner]) =>
            match parse_negative_quadratic_exp(inner, x_name) {
              Some(scale) =>
                if exp_quad is None {
                  exp_quad = Some(scale)
                } else {
                  return None
                }
              None => return None
            }
          _ => return None
        }
    }
  }
  match exp_quad {
    Some(scale) if expr_eq(x_pow, expr_one()) =>
      Some(
        expr_div(
          expr_mul(
            expr_mul(
              expr_mul(expr_sqrt_two(), k),
              @symelem.exp(
                expr_div(
                  expr_mul(expr_neg_one(), expr_pow(k, expr_int(2))),
                  expr_mul(expr_int(4), scale),
                ),
              ),
            ),
            expr_one(),
          ),
          expr_mul(expr_int(4), expr_pow(scale, expr_rat(3, 2))),
        ),
      )
    _ => None
  }
}

///|
fn sine_base_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match parse_negative_power(expr, x_name) {
    Some(a) =>
      Some(
        expr_div(
          expr_mul(
            expr_pow(
              expr_int(2),
              expr_add(
                expr_div(expr_one(), expr_int(2)),
                expr_mul(expr_neg_one(), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, expr_one())),
              @symspec.gamma(expr_sub(expr_one(), expr_div(a, expr_int(2)))),
            ),
          ),
          @symspec.gamma(expr_div(expr_add(a, expr_one()), expr_int(2))),
        ),
      )
    None =>
      match parse_negative_linear_exp(expr, x_name) {
        Some(a) =>
          Some(
            expr_div(
              expr_mul(expr_sqrt_two(), k),
              expr_mul(
                sqrt_pi(),
                expr_add(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
              ),
            ),
          )
        None => None
      }
  }
}

///|
pub fn do_inverse_sine_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_sine_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

///|
fn inverse_sine_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  if matches_negative_power_transform(expr, k_name, x, true) is Some(v) {
    return Some(v)
  }
  match inverse_sine_exp_term(expr, k_name, x) {
    Some(v) => Some(v)
    None => inverse_sine_gaussian_term(expr, k_name, x)
  }
}

///|
fn inverse_sine_exp_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, den_opt) = split_division(expr)
  match den_opt {
    Some(den) =>
      match coeff.length() {
        2 => {
          let mut k_seen = false
          let mut const_coeff = expr_one()
          for item in coeff {
            if expr_eq(item, @symcore.symbol(k_name)) {
              k_seen = true
            } else {
              const_coeff = expr_mul(const_coeff, item)
            }
          }
          if !k_seen {
            return None
          }
          match denom_to_square_freq(den, k_name) {
            Some(a) => {
              let expected = expr_div(expr_sqrt_two(), sqrt_pi())
              if expr_eq(const_coeff, expected) {
                Some(@symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))))
              } else {
                None
              }
            }
            None => None
          }
        }
        _ => None
      }
    None => None
  }
}

///|
fn inverse_sine_gaussian_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 2 {
    return None
  }
  let mut k_seen = false
  let mut exp_scale : Expr? = None
  for factor in factors {
    if expr_eq(factor, @symcore.symbol(k_name)) {
      k_seen = true
    } else {
      match factor {
        @symcore.Expr::Function("exp", [inner]) =>
          match parse_negative_quadratic_exp(inner, k_name) {
            Some(scale) => exp_scale = Some(scale)
            None => return None
          }
        _ => return None
      }
    }
  }
  if !k_seen {
    return None
  }
  match exp_scale {
    Some(scale) => {
      let a = expr_div(expr_one(), expr_mul(expr_int(4), scale))
      let expected = expr_div(
        expr_sqrt_two(),
        expr_mul(expr_int(4), expr_pow(a, expr_rat(3, 2))),
      )
      if expr_eq(coeff, expected) {
        Some(
          expr_mul(
            x,
            @symelem.exp(
              expr_mul(expr_neg_one(), expr_mul(a, expr_pow(x, expr_int(2)))),
            ),
          ),
        )
      } else {
        None
      }
    }
    None => None
  }
}

///|
pub fn do_cosine_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => cosine_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

///|
fn cosine_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { cosine_doit(term, x_name, k) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 1 {
        match cosine_base_term(factors[0], x_name, k) {
          Some(value) => Some(expr_mul(coeff, value))
          None => None
        }
      } else {
        None
      }
    }
  }
}

///|
fn cosine_base_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match parse_negative_power(expr, x_name) {
    Some(a) =>
      Some(
        expr_div(
          expr_mul(
            expr_pow(
              expr_int(2),
              expr_add(
                expr_div(expr_one(), expr_int(2)),
                expr_mul(expr_neg_one(), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, expr_one())),
              @symspec.gamma(expr_div(expr_sub(expr_one(), a), expr_int(2))),
            ),
          ),
          @symspec.gamma(expr_div(a, expr_int(2))),
        ),
      )
    None =>
      match parse_negative_linear_exp(expr, x_name) {
        Some(a) =>
          Some(
            expr_div(
              expr_mul(expr_sqrt_two(), a),
              expr_mul(
                sqrt_pi(),
                expr_add(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
              ),
            ),
          )
        None =>
          match parse_reciprocal_quadratic(expr, x_name) {
            Some(a) =>
              Some(
                expr_div(
                  expr_mul(
                    expr_mul(expr_sqrt_two(), sqrt_pi()),
                    @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, k))),
                  ),
                  expr_mul(expr_int(2), a),
                ),
              )
            None => None
          }
      }
  }
}

///|
pub fn do_inverse_cosine_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_cosine_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

///|
fn inverse_cosine_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  if matches_negative_power_transform(expr, k_name, x, false) is Some(v) {
    return Some(v)
  }
  let (num, den_opt) = split_division(expr)
  match den_opt {
    Some(den) => {
      let coeff = if num.length() == 0 {
        expr_one()
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      match denom_to_square_freq(den, k_name) {
        Some(a) => {
          let expected = expr_div(expr_mul(expr_sqrt_two(), a), sqrt_pi())
          if expr_eq(coeff, expected) {
            Some(@symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))))
          } else {
            None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
pub fn do_hankel_doit(expr : Expr, r : Expr, k : Expr, nu : Expr) -> Expr? {
  match symbol_name(r) {
    Some(r_name) => hankel_doit(expr_simplify(expr), r_name, k, nu)
    None => None
  }
}

///|
fn hankel_doit(expr : Expr, r_name : String, k : Expr, nu : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, r_name)
  match hankel_mul_term(factors, r_name, k, nu) {
    Some(value) => Some(expr_mul(coeff, value))
    None => None
  }
}

///|
fn hankel_mul_term(
  factors : Array[Expr],
  r_name : String,
  k : Expr,
  nu : Expr,
) -> Expr? {
  if factors.length() == 1 {
    return hankel_base_term(factors[0], r_name, k, nu)
  }
  if factors.length() == 2 {
    let mut power : Expr? = None
    let mut decay : Expr? = None
    for factor in factors {
      match parse_power_factor(factor, r_name) {
        Some(p) => power = Some(p)
        None =>
          match factor {
            @symcore.Expr::Function("exp", [inner]) =>
              match parse_negative_linear_exp_raw(inner, r_name) {
                Some(a) => decay = Some(a)
                None => return None
              }
            _ => return None
          }
      }
    }
    match (power, decay) {
      (Some(p), Some(a)) if expr_eq(p, nu) =>
        Some(
          expr_div(
            expr_mul(
              expr_mul(expr_pow(expr_int(2), expr_add(nu, expr_one())), a),
              @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
            ) *
            expr_pow(k, expr_sub(expr_neg_one(), expr_add(nu, expr_int(2)))),
            expr_mul(
              sqrt_pi(),
              expr_pow(
                expr_add(
                  expr_div(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
                  expr_one(),
                ),
                expr_add(nu, expr_rat(3, 2)),
              ),
            ),
          ),
        )
      _ => None
    }
  } else {
    None
  }
}

///|
fn hankel_base_term(expr : Expr, r_name : String, k : Expr, nu : Expr) -> Expr? {
  match parse_negative_power(expr, r_name) {
    Some(m) =>
      Some(
        expr_mul(
          expr_pow(expr_int(2), expr_sub(expr_one(), m)),
          expr_div(
            expr_mul(
              expr_pow(k, expr_sub(m, expr_int(2))),
              @symspec.gamma(
                expr_add(
                  expr_sub(expr_one(), expr_div(m, expr_int(2))),
                  expr_div(nu, expr_int(2)),
                ),
              ),
            ),
            @symspec.gamma(
              expr_add(expr_div(m, expr_int(2)), expr_div(nu, expr_int(2))),
            ),
          ),
        ),
      )
    None => None
  }
}

///|
pub fn do_inverse_hankel_doit(
  expr : Expr,
  k : Expr,
  r : Expr,
  nu : Expr,
) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_hankel_doit(expr_simplify(expr), k_name, r, nu)
    None => None
  }
}

///|
fn inverse_hankel_doit(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  if matches_hankel_power_transform(expr, k_name, r, nu) is Some(v) {
    return Some(v)
  }
  inverse_hankel_exp_term(expr, k_name, r, nu)
}

///|
pub fn do_mellin_doit(_expr : Expr, x : Expr, s : Expr) -> Expr? {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(expr_simplify(_expr), x_name, @symcore.symbol(s_name)) {
        Some(info) => Some(info.0)
        None =>
          mellin_doit(expr_simplify(_expr), x_name, @symcore.symbol(s_name))
      }
    _ => None
  }
}

///|
pub fn do_inverse_mellin_doit(_expr : Expr, s : Expr, x : Expr) -> Expr? {
  match (symbol_name(s), symbol_name(x)) {
    (Some(s_name), Some(_)) =>
      inverse_mellin_doit(expr_simplify(_expr), s_name, x)
    _ => None
  }
}

///|
pub fn mellin_transform_result(
  expr : Expr,
  x : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(expr_simplify(expr), x_name, @symcore.symbol(s_name)) {
        Some((value, lower, upper, cond)) =>
          if noconds {
            value
          } else {
            tuple_expr([value, tuple_expr([lower, upper]), cond])
          }
        None => @symcore.raw_function("MellinTransform", [expr, x, s])
      }
    _ => @symcore.raw_function("MellinTransform", [expr, x, s])
  }
}

///|
fn mellin_doit(expr : Expr, x_name : String, s : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { mellin_doit(term, x_name, s) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        None
      } else {
        match mellin_mul_term(factors, x_name, s) {
          Some(v) => Some(expr_mul(coeff, v))
          None => None
        }
      }
    }
  }
}

///|
fn mellin_info_doit(expr : Expr, x_name : String, s : Expr) -> MellinInfo? {
  match expr {
    @symcore.Expr::Add(terms) => {
      let values : Array[Expr] = []
      let mut lower : Expr? = None
      let mut upper : Expr? = None
      let mut cond = true_expr()
      for term in terms {
        match mellin_info_doit(term, x_name, s) {
          Some((value, lo, up, term_cond)) => {
            values.push(value)
            lower = Some(
              match lower {
                Some(prev) => max_expr(prev, lo)
                None => lo
              },
            )
            upper = Some(
              match upper {
                Some(prev) => min_expr(prev, up)
                None => up
              },
            )
            cond = and_expr(cond, term_cond)
          }
          None => return None
        }
      }
      Some(
        (
          expr_simplify(@symcore.add(values)),
          lower.unwrap_or(expr_mul(expr_neg_one(), @symcore.symbol("oo"))),
          upper.unwrap_or(@symcore.symbol("oo")),
          cond,
        ),
      )
    }
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        None
      } else {
        match mellin_mul_info(factors, x_name, s) {
          Some((value, lower, upper, cond)) =>
            Some((expr_mul(coeff, value), lower, upper, cond))
          None => None
        }
      }
    }
  }
}

///|
fn mellin_mul_term(factors : Array[Expr], x_name : String, s : Expr) -> Expr? {
  let mut pow_opt : Expr? = None
  let mut exp_opt : (Expr, Int)? = None
  let mut heav_opt : (Expr, Bool)? = None
  let mut other_count = 0
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some((bound, is_le)) =>
            if heav_opt is None {
              heav_opt = Some((bound, is_le))
            } else {
              return None
            }
          None => other_count += 1
        }
      _ =>
        match parse_power_factor(factor, x_name) {
          Some(p) =>
            match pow_opt {
              None => pow_opt = Some(p)
              Some(prev) => pow_opt = Some(expr_add(prev, p))
            }
          None => other_count += 1
        }
    }
  }
  if other_count != 0 {
    return None
  }
  let pow = match pow_opt {
    Some(v) => v
    None => expr_zero()
  }
  match (exp_opt, heav_opt) {
    (Some((coef, degree)), None) =>
      Some(mellin_exp_formula(pow, coef, degree, s))
    (None, Some((bound, is_le))) =>
      Some(mellin_heaviside_term(pow, bound, is_le, s))
    _ => None
  }
}

///|
fn mellin_mul_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  let mut pow_opt : Expr? = None
  let mut exp_opt : (Expr, Int)? = None
  let mut heav_opt : (Expr, Bool)? = None
  let mut other_count = 0
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some((bound, is_le)) =>
            if heav_opt is None {
              heav_opt = Some((bound, is_le))
            } else {
              return None
            }
          None => other_count += 1
        }
      _ =>
        match parse_power_factor(factor, x_name) {
          Some(p) =>
            match pow_opt {
              None => pow_opt = Some(p)
              Some(prev) => pow_opt = Some(expr_add(prev, p))
            }
          None => other_count += 1
        }
    }
  }
  if other_count != 0 {
    return None
  }
  let pow = pow_opt.unwrap_or(expr_zero())
  match (exp_opt, heav_opt) {
    (Some((coef, degree)), None) => mellin_exp_info(pow, coef, degree, s)
    (None, Some((bound, is_le))) => {
      let value = mellin_heaviside_term(pow, bound, is_le, s)
      if is_le {
        Some(
          (
            value,
            expr_mul(expr_neg_one(), pow),
            @symcore.symbol("oo"),
            true_expr(),
          ),
        )
      } else {
        Some(
          (
            value,
            expr_mul(expr_neg_one(), @symcore.symbol("oo")),
            expr_mul(expr_neg_one(), pow),
            true_expr(),
          ),
        )
      }
    }
    _ => None
  }
}

///|
fn mellin_exp_info(
  pow : Expr,
  coef : Expr,
  degree : Int,
  s : Expr,
) -> MellinInfo? {
  if degree == 1 {
    if expr_is_negative(coef) {
      Some(
        (
          mellin_exp_formula(pow, coef, degree, s),
          expr_mul(expr_neg_one(), pow),
          @symcore.symbol("oo"),
          true_expr(),
        ),
      )
    } else {
      None
    }
  } else if degree == -1 {
    Some(
      (
        mellin_exp_formula(pow, coef, degree, s),
        expr_mul(expr_neg_one(), @symcore.symbol("oo")),
        expr_mul(expr_neg_one(), pow),
        true_expr(),
      ),
    )
  } else {
    None
  }
}

///|
fn parse_power_factor(expr : Expr, x_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if name == x_name {
        Some(expr_one())
      } else {
        None
      }
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) =>
      if name == x_name {
        Some(exp)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_mellin_exp(inner : Expr, x_name : String) -> (Expr, Int)? {
  match parse_mellin_inverse_exp(inner, x_name) {
    Some(coef) => Some((coef, -1))
    None => parse_mellin_polynomial_exp(inner, x_name)
  }
}

///|
fn parse_mellin_polynomial_exp(inner : Expr, x_name : String) -> (Expr, Int)? {
  match poly_coeffs_upto2(inner, x_name) {
    Some(coeffs) =>
      if !expr_is_zero(coeffs[0]) {
        None
      } else if !expr_is_zero(coeffs[1]) && expr_is_zero(coeffs[2]) {
        if expr_is_constant(expr_simplify(coeffs[1]), x_name) {
          Some((coeffs[1], 1))
        } else {
          None
        }
      } else if !expr_is_zero(coeffs[2]) && expr_is_zero(coeffs[1]) {
        if expr_is_constant(expr_simplify(coeffs[2]), x_name) {
          Some((coeffs[2], 2))
        } else {
          None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_mellin_inverse_exp(inner : Expr, x_name : String) -> Expr? {
  let (coeff, vars) = split_mul(inner, x_name)
  match vars.length() {
    1 =>
      match vars[0] {
        @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) =>
          if name == x_name &&
            expr_is_minus_one(exp) &&
            expr_is_constant(expr_simplify(coeff), x_name) &&
            expr_is_negative(coeff) {
            Some(coeff)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_heaviside_limit(arg : Expr, x_name : String) -> (Expr, Bool)? {
  match linear_coeffs(arg, x_name) {
    Some((coeff, offset)) =>
      if expr_is_one(coeff) {
        Some((expr_mul(expr_neg_one(), offset), false))
      } else if expr_is_minus_one(coeff) {
        Some((offset, true))
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_exp_formula(pow : Expr, coef : Expr, degree : Int, s : Expr) -> Expr {
  let shifted = expr_add(s, pow)
  if degree == 1 {
    if expr_is_positive(expr_simplify(coef)) {
      let phase = expr_mul(
        expr_mul(
          expr_mul(expr_neg_one(), @symcore.symbol("I")),
          @symcore.symbol("pi"),
        ),
        shifted,
      )
      let gamma_factor = expr_pow(coef, expr_mul(expr_neg_one(), shifted))
      let lower = @symspec.lowergamma(shifted, neg_oo_expr())
      expr_mul(@symelem.exp(phase), expr_mul(gamma_factor, lower))
    } else {
      expr_mul(
        expr_pow(
          expr_mul(expr_neg_one(), coef),
          expr_mul(expr_neg_one(), shifted),
        ),
        @symspec.gamma(shifted),
      )
    }
  } else if degree == -1 {
    let norm = expr_mul(expr_neg_one(), coef)
    let coef_factor = if expr_eq(norm, expr_one()) {
      expr_one()
    } else {
      expr_pow(norm, shifted)
    }
    expr_mul(coef_factor, @symspec.gamma(expr_sub(expr_zero(), shifted)))
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          coef,
          expr_mul(expr_neg_one(), expr_div(shifted, expr_int(degree))),
        ),
        @symspec.gamma(expr_div(shifted, expr_int(degree))),
      ),
      expr_int(degree),
    )
  }
}

///|
fn mellin_heaviside_term(
  pow : Expr,
  bound : Expr,
  is_le : Bool,
  s : Expr,
) -> Expr {
  let scale = expr_div(expr_pow(bound, expr_add(s, pow)), expr_add(s, pow))
  if is_le {
    scale
  } else {
    expr_mul(expr_neg_one(), scale)
  }
}

///|
fn expr_is_constant(expr : Expr, symbol_name : String) -> Bool {
  !expr_depends_on(expr, symbol_name)
}

///|
fn inverse_mellin_doit(expr : Expr, s_name : String, x : Expr) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, s_name, fn(term) {
        inverse_mellin_doit(term, s_name, x)
      })
    _ => {
      let (num, den_opt) = split_division(expr)
      let numerator = if num.length() == 0 {
        expr_one()
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      let direct_gamma = match den_opt {
        None =>
          match numerator {
            @symcore.Expr::Function("gamma", [arg]) =>
              if expr_eq(arg, s_sym) {
                Some(@symelem.exp(expr_mul(expr_neg_one(), x)))
              } else if expr_eq(arg, expr_mul(expr_neg_one(), s_sym)) {
                Some(@symelem.exp(expr_div(expr_neg_one(), x)))
              } else {
                None
              }
            _ => None
          }
        Some(_) => None
      }
      if direct_gamma is Some(gamma_inv) {
        return Some(gamma_inv)
      }
      let (num_coeff, vars_opt) = split_mul(numerator, s_name)
      if vars_opt.length() != 0 {
        None
      } else {
        match den_opt {
          None =>
            match numerator {
              @symcore.Expr::Function("gamma", [arg]) =>
                if expr_eq(arg, s_sym) {
                  Some(@symelem.exp(expr_mul(expr_neg_one(), x)))
                } else if expr_eq(arg, expr_mul(expr_neg_one(), s_sym)) {
                  Some(@symelem.exp(expr_div(expr_neg_one(), x)))
                } else {
                  None
                }
              _ => None
            }
          Some(den) =>
            match linear_coeffs(den, s_name) {
              Some((s_coeff, shift)) =>
                if expr_is_zero(s_coeff) {
                  None
                } else {
                  let norm_shift = expr_div(shift, s_coeff)
                  let norm_num = expr_div(num_coeff, s_coeff)
                  let (side_is_le, coeff_abs) = if expr_is_negative(norm_num) {
                    (false, expr_mul(expr_neg_one(), norm_num))
                  } else {
                    (true, norm_num)
                  }
                  Some(
                    expr_mul(
                      coeff_abs,
                      inverse_mellin_term(norm_shift, side_is_le, x),
                    ),
                  )
                }
              _ => None
            }
        }
      }
    }
  }
}

///|
fn inverse_mellin_term(pow : Expr, is_le : Bool, x : Expr) -> Expr {
  let xpow = if expr_is_zero(pow) { expr_one() } else { expr_pow(x, pow) }
  if is_le {
    expr_mul(xpow, @symspec.heaviside(expr_sub(expr_one(), x)))
  } else {
    expr_mul(xpow, @symspec.heaviside(expr_sub(x, expr_one())))
  }
}

///|
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

///|
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

///|
fn split_division(expr : Expr) -> (Array[Expr], Expr?) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Pow(base, exp) if expr_is_int_value(exp) is Some(exp_int) &&
      exp_int < 0 => {
      let n = -exp_int
      if n == 1 {
        ([], Some(base))
      } else {
        ([], Some(base ^ @symcore.int(n)))
      }
    }
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

///|
fn split_mul_factor(factors : Array[Expr], var_name : String) -> (Expr, Expr?) {
  let mut coeff = expr_one()
  let mut var_expr : Expr? = None
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

///|
fn factors_expr(factors : Array[Expr]) -> Expr {
  if factors.length() == 0 {
    expr_one()
  } else if factors.length() == 1 {
    factors[0]
  } else {
    expr_simplify(@symcore.mul(factors))
  }
}

///|
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

///|
fn split_linear_power_denom(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 =>
          match split_linear_coeff(base, var_name) {
            Some((a, b)) => Some((a, b, power))
            None => None
          }
        _ => None
      }
    _ =>
      match split_linear_coeff(expr, var_name) {
        Some((a, b)) => Some((a, b, 1))
        None => None
      }
  }
}

///|
fn split_shifted_square_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match poly_coeffs_upto2(expr_simplify(den), s_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[2]) ||
        expr_depends_on(coeffs[0], s_name) ||
        expr_depends_on(coeffs[1], s_name) ||
        expr_depends_on(coeffs[2], s_name) {
        None
      } else {
        let lead = coeffs[2]
        let shift = expr_div(coeffs[1], expr_mul(expr_int(2), lead))
        let remainder = expr_sub(
          expr_div(coeffs[0], lead),
          expr_pow(shift, expr_int(2)),
        )
        if expr_is_negative(remainder) || expr_is_zero(remainder) {
          None
        } else {
          Some((lead, shift, expr_sqrt_positive(remainder)))
        }
      }
    None => None
  }
}

///|
fn split_two_linear_factors(
  den : Expr,
  s_name : String,
) -> ((Expr, Expr), (Expr, Expr))? {
  match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      match
        (
          split_linear_power_denom(args[0], s_name),
          split_linear_power_denom(args[1], s_name),
        ) {
        (Some((a1, b1, 1)), Some((a2, b2, 1))) => Some(((a1, b1), (a2, b2)))
        _ => None
      }
    _ => None
  }
}

///|
fn denom_to_diff_square_freq(den : Expr, s_name : String) -> Expr? {
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
            Some(expr_sqrt_positive(expr_mul(expr_neg_one(), ratio)))
          } else {
            None
          }
        }
      } else {
        None
      }
    _ => None
  }
}

///|
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

///|
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

///|
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

///|
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

///|
fn sqrt_pi() -> Expr {
  @symelem.sqrt(@symcore.symbol("pi"))
}

///|
fn expr_sqrt_two() -> Expr {
  @symelem.sqrt(expr_int(2))
}

///|
fn true_expr() -> Expr {
  @symcore.symbol("True")
}

///|
fn false_expr() -> Expr {
  @symcore.symbol("False")
}

///|
fn and_expr(lhs : Expr, rhs : Expr) -> Expr {
  if lhs == true_expr() {
    rhs
  } else if rhs == true_expr() {
    lhs
  } else if lhs == false_expr() || rhs == false_expr() {
    false_expr()
  } else if expr_eq(lhs, rhs) {
    lhs
  } else {
    @symcore.function("And", [lhs, rhs])
  }
}

///|
fn max_expr(lhs : Expr, rhs : Expr) -> Expr {
  match (expr_num_value(lhs), expr_num_value(rhs)) {
    (Some(ln), Some(rn)) => if ln.compare(rn) >= 0 { lhs } else { rhs }
    _ =>
      if expr_eq(lhs, rhs) {
        lhs
      } else {
        @symcore.function("Max", [lhs, rhs])
      }
  }
}

///|
fn min_expr(lhs : Expr, rhs : Expr) -> Expr {
  match (expr_num_value(lhs), expr_num_value(rhs)) {
    (Some(ln), Some(rn)) => if ln.compare(rn) <= 0 { lhs } else { rhs }
    _ =>
      if expr_eq(lhs, rhs) {
        lhs
      } else {
        @symcore.function("Min", [lhs, rhs])
      }
  }
}

///|
fn nonnegative_condition(expr : Expr) -> Expr {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) =>
      if value.compare(@symnum.BigRational::zero()) >= 0 {
        true_expr()
      } else {
        false_expr()
      }
    None => @symcore.function("Ge", [expr, expr_zero()])
  }
}

///|
fn parse_negative_power(expr : Expr, var_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) if name == var_name =>
      Some(expr_mul(expr_neg_one(), exp))
    _ => None
  }
}

///|
fn parse_negative_linear_exp(expr : Expr, var_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Function("exp", [inner]) =>
      parse_negative_linear_exp_raw(inner, var_name)
    _ => None
  }
}

///|
fn parse_negative_linear_exp_raw(inner : Expr, var_name : String) -> Expr? {
  match linear_coeffs(inner, var_name) {
    Some((a, b)) =>
      if expr_is_zero(b) && expr_is_negative(a) {
        Some(expr_mul(expr_neg_one(), a))
      } else {
        None
      }
    None => None
  }
}

///|
fn parse_negative_quadratic_exp(inner : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(inner, var_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[0]) &&
        expr_is_zero(coeffs[1]) &&
        expr_is_negative(coeffs[2]) {
        Some(expr_mul(expr_neg_one(), coeffs[2]))
      } else {
        None
      }
    None => None
  }
}

///|
fn parse_reciprocal_quadratic(expr : Expr, var_name : String) -> Expr? {
  match split_division(expr) {
    (num, Some(den)) =>
      if num.length() == 0 || (num.length() == 1 && expr_is_one(num[0])) {
        denom_to_square_freq(den, var_name)
      } else {
        None
      }
    _ => None
  }
}

///|
fn matches_negative_power_transform(
  expr : Expr,
  var_name : String,
  x : Expr,
  is_sine : Bool,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, var_name)
  if factors.length() != 1 {
    return None
  }
  let power = match parse_power_factor(factors[0], var_name) {
    Some(v) => v
    None => return None
  }
  let a = expr_add(power, expr_one())
  let expected = if is_sine {
    expr_div(
      expr_mul(
        expr_pow(
          expr_int(2),
          expr_add(
            expr_div(expr_one(), expr_int(2)),
            expr_mul(expr_neg_one(), a),
          ),
        ),
        @symspec.gamma(expr_sub(expr_one(), expr_div(a, expr_int(2)))),
      ),
      @symspec.gamma(expr_div(expr_add(a, expr_one()), expr_int(2))),
    )
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          expr_int(2),
          expr_add(
            expr_div(expr_one(), expr_int(2)),
            expr_mul(expr_neg_one(), a),
          ),
        ),
        @symspec.gamma(expr_div(expr_sub(expr_one(), a), expr_int(2))),
      ),
      @symspec.gamma(expr_div(a, expr_int(2))),
    )
  }
  if expr_eq(coeff, expected) {
    Some(expr_pow(x, expr_mul(expr_neg_one(), a)))
  } else {
    None
  }
}

///|
fn matches_hankel_power_transform(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  let power = match parse_power_factor(factors[0], k_name) {
    Some(v) => v
    None => return None
  }
  let m = expr_add(power, expr_int(2))
  let expected = expr_mul(
    expr_pow(expr_int(2), expr_sub(expr_one(), m)),
    expr_div(
      @symspec.gamma(
        expr_add(
          expr_sub(expr_one(), expr_div(m, expr_int(2))),
          expr_div(nu, expr_int(2)),
        ),
      ),
      @symspec.gamma(
        expr_add(expr_div(m, expr_int(2)), expr_div(nu, expr_int(2))),
      ),
    ),
  )
  if expr_eq(coeff, expected) {
    Some(expr_pow(r, expr_mul(expr_neg_one(), m)))
  } else {
    None
  }
}

///|
fn inverse_hankel_exp_term(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 2 {
    return None
  }
  let mut power_ok = false
  let mut kernel_a : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, k_name) {
      Some(power) =>
        if expr_eq(power, expr_sub(expr_neg_one(), expr_add(nu, expr_int(2)))) {
          power_ok = true
        } else {
          return None
        }
      None =>
        match factor {
          @symcore.Expr::Pow(base, exp) if expr_eq(
              exp,
              expr_mul(expr_neg_one(), expr_add(nu, expr_rat(3, 2))),
            ) =>
            match base {
              @symcore.Expr::Add(args) if args.length() == 2 => {
                let mut saw_one = false
                let mut other : Expr? = None
                for arg in args {
                  if expr_is_one(arg) {
                    saw_one = true
                  } else {
                    other = Some(arg)
                  }
                }
                if !saw_one || other is None {
                  return None
                }
                match other.unwrap() {
                  @symcore.Expr::Mul(parts) if parts.length() == 2 => {
                    let mut a_sq : Expr? = None
                    let mut k_sq_inv = false
                    for part in parts {
                      match part {
                        @symcore.Expr::Pow(base2, exp2) if expr_eq(
                            exp2,
                            expr_int(-2),
                          ) &&
                          expr_eq(base2, @symcore.symbol(k_name)) =>
                          k_sq_inv = true
                        _ => a_sq = Some(part)
                      }
                    }
                    if k_sq_inv {
                      kernel_a = a_sq
                    } else {
                      return None
                    }
                  }
                  _ => return None
                }
              }
              _ => return None
            }
          _ => return None
        }
    }
  }
  if !power_ok || kernel_a is None {
    return None
  }
  let a = expr_sqrt_positive(kernel_a.unwrap())
  let expected = expr_div(
    expr_mul(
      expr_mul(expr_pow(expr_int(2), expr_add(nu, expr_one())), a),
      @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
    ),
    sqrt_pi(),
  )
  if expr_eq(coeff, expected) {
    Some(
      expr_mul(
        expr_pow(r, nu),
        @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, r))),
      ),
    )
  } else {
    None
  }
}

///|
fn expr_has_function_name(expr : Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Function(func_name, args) =>
      func_name == name ||
      args.any(fn(arg) { expr_has_function_name(arg, name) })
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(fn(arg) { expr_has_function_name(arg, name) })
    @symcore.Expr::Pow(base, exp) =>
      expr_has_function_name(base, name) || expr_has_function_name(exp, name)
    _ => false
  }
}

///|
fn expr_is_negative(expr : Expr) -> Bool {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero()) < 0
    None => false
  }
}

///|
fn expr_is_positive(expr : Expr) -> Bool {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero()) > 0
    None => false
  }
}

///|
fn neg_oo_expr() -> Expr {
  @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
}
